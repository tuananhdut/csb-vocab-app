import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;

import '../../domain/entities/translation_direction.dart';
import '../services/connectivity_service.dart';
import '../services/llm_model_download_service.dart';
import '../services/llm_translation_service.dart';
import '../services/mlkit_translation_service.dart';
import '../services/model_download_service.dart';
import '../services/translation_service.dart';
import 'vocab_providers.dart' show dictionaryApiServiceProvider;

/// Model AI cục bộ (Qwen2.5-3B) chỉ hỗ trợ Windows desktop ở bản này
/// (xem `tools/translation-eval/results/SUMMARY.md`) — chưa test/tối ưu
/// cho macOS/Linux dù `llamadart` hỗ trợ đa nền tảng, và không dùng
/// trên mobile (RAM/CPU không phù hợp, xem brainstorm).
bool get isLlmTranslationSupportedPlatform => !kIsWeb && Platform.isWindows;

/// ML Kit Translation (Google, on-device) — offline fallback cho mobile,
/// thay thế vai trò của [isLlmTranslationSupportedPlatform] trên desktop
/// nhưng dùng SDK dịch chuyên biệt nhỏ gọn thay vì LLM (RAM/pin di động
/// không phù hợp chạy LLM, xem brainstorm).
bool get isMlKitTranslationSupportedPlatform =>
    !kIsWeb && (Platform.isAndroid || Platform.isIOS);

/// Trạng thái tải model dịch cho 1 chiều — sealed vì cần phân biệt rõ
/// "đang tải X/Y byte" là 1 trạng thái riêng, khác data/error/loading mà
/// `AsyncValue` không tự nhiên biểu diễn được (xem kế hoạch FR-4 mục
/// "Provider Riverpod").
sealed class ModelDownloadState {
  const ModelDownloadState();
}

class ModelNotDownloaded extends ModelDownloadState {
  const ModelNotDownloaded();
}

class ModelDownloading extends ModelDownloadState {
  const ModelDownloading(this.receivedBytes, this.totalBytes);
  final int receivedBytes;
  final int totalBytes;

  double get progress => totalBytes <= 0 ? 0 : receivedBytes / totalBytes;
}

class ModelDownloadFailed extends ModelDownloadState {
  const ModelDownloadFailed(this.message);
  final String message;
}

class ModelReady extends ModelDownloadState {
  const ModelReady();
}

/// Trạng thái tải hiện tại của 1 chiều — mặc định [ModelNotDownloaded]
/// cho tới khi [modelExistsOnDiskProvider] xác nhận đã tải từ trước
/// (seed lúc mở màn Dịch, xem `translate_screen.dart`) hoặc user bấm tải.
final modelDownloadStateProvider =
    StateProvider.family<ModelDownloadState, TranslationDirection>(
  (ref, direction) => const ModelNotDownloaded(),
);

/// Kiểm tra đĩa 1 lần khi mở màn Dịch — phân biệt "chưa từng tải" với
/// "đã tải từ phiên trước, không cần tải lại".
final modelExistsOnDiskProvider =
    FutureProvider.family<bool, TranslationDirection>((ref, direction) {
  return ModelDownloadService.instance.isDirectionDownloaded(direction);
});

/// Tải model cho [direction], cập nhật [modelDownloadStateProvider] theo
/// từng mốc tiến độ. Gọi lại để retry sau khi [ModelDownloadFailed].
Future<void> downloadTranslationModel(
  WidgetRef ref,
  TranslationDirection direction, {
  CancelToken? cancelToken,
}) async {
  final notifier = ref.read(modelDownloadStateProvider(direction).notifier);
  notifier.state = const ModelDownloading(0, 0);
  try {
    await ModelDownloadService.instance.downloadDirection(
      direction,
      onProgress: (received, total) {
        notifier.state = ModelDownloading(received, total);
      },
      cancelToken: cancelToken,
    );
    notifier.state = const ModelReady();
  } on ChecksumMismatchException catch (e) {
    notifier.state = ModelDownloadFailed(e.toString());
  } on DioException catch (e) {
    if (e.type == DioExceptionType.cancel) {
      notifier.state = const ModelNotDownloaded();
      return;
    }
    notifier.state = ModelDownloadFailed(e.message ?? 'Lỗi tải model');
  } catch (e) {
    notifier.state = ModelDownloadFailed(e.toString());
  }
}

/// Xoá model đã tải của [direction] (giải phóng dung lượng) và đưa
/// trạng thái về [ModelNotDownloaded].
Future<void> deleteTranslationModel(WidgetRef ref, TranslationDirection direction) async {
  await TranslationService.instance.unloadDirection(direction);
  await ModelDownloadService.instance.deleteDirection(direction);
  ref.read(modelDownloadStateProvider(direction).notifier).state = const ModelNotDownloaded();
  // Invalidate cache "đã có file trên đĩa" - không làm bước này thì
  // `FutureProvider` vẫn giữ kết quả cũ (true, từ trước khi xoá), khiến
  // logic seed-từ-đĩa ở `translate_screen.dart` tự set NGƯỢC lại
  // ModelReady ngay sau khi vừa xoá xong (bug đã gặp thực tế: bấm Xoá
  // như không có tác dụng gì).
  ref.invalidate(modelExistsOnDiskProvider(direction));
}

final translationServiceProvider = Provider<TranslationService>((ref) {
  return TranslationService.instance;
});

/// Trạng thái tải model AI cục bộ (Qwen2.5-3B, Windows only) — tái dùng
/// [ModelDownloadState] vì cùng hình dạng trạng thái với opus-mt, nhưng
/// KHÔNG family theo [TranslationDirection]: model này dùng chung cho cả
/// 2 chiều dịch (khác opus-mt cần model riêng/chiều), chỉ đổi prompt.
final llmModelDownloadStateProvider = StateProvider<ModelDownloadState>(
  (ref) => const ModelNotDownloaded(),
);

final llmModelExistsOnDiskProvider = FutureProvider<bool>((ref) {
  return LlmModelDownloadService.instance.isDownloaded();
});

Future<void> downloadLlmModel(WidgetRef ref, {CancelToken? cancelToken}) async {
  final notifier = ref.read(llmModelDownloadStateProvider.notifier);
  notifier.state = const ModelDownloading(0, 0);
  try {
    await LlmModelDownloadService.instance.download(
      onProgress: (received, total) {
        notifier.state = ModelDownloading(received, total);
      },
      cancelToken: cancelToken,
    );
    // Warm-up: nạp model ngay sau khi tải xong thay vì đợi lần dịch đầu
    // tiên mới nạp (lazy) - tránh cold-start (~vài giây load 2.1GB GGUF)
    // làm chậm bản dịch đầu tiên. Không chặn luồng "tải xong" nếu warm-up
    // lỗi - `LlmTranslationService.translate()` vẫn tự nạp lại (lazy)
    // khi cần, đây chỉ là tối ưu, không phải bắt buộc. Không kiểm tra RAM
    // trước khi thử (theo yêu cầu: bỏ kiểm tra RAM trên Windows).
    try {
      await LlmTranslationService.instance.load();
    } catch (e) {
      debugPrint('[downloadLlmModel] warm-up load thất bại (sẽ nạp lười khi dịch): $e');
    }
    notifier.state = const ModelReady();
  } on LlmChecksumMismatchException catch (e) {
    notifier.state = ModelDownloadFailed(e.toString());
  } on DioException catch (e) {
    if (e.type == DioExceptionType.cancel) {
      notifier.state = const ModelNotDownloaded();
      return;
    }
    notifier.state = ModelDownloadFailed(e.message ?? 'Lỗi tải model');
  } catch (e) {
    notifier.state = ModelDownloadFailed(e.toString());
  }
}

Future<void> deleteLlmModel(WidgetRef ref) async {
  try {
    await LlmTranslationService.instance.unload();
  } catch (e) {
    // Không để lỗi unload (vd llama.cpp đang dở 1 generation) chặn việc
    // xoá file - user bấm Xoá là muốn giải phóng dung lượng, ưu tiên đó
    // hơn unload "sạch sẽ" engine đang chạy.
    debugPrint('[deleteLlmModel] unload lỗi (vẫn tiếp tục xoá file): $e');
  }
  await LlmModelDownloadService.instance.delete();
  ref.read(llmModelDownloadStateProvider.notifier).state = const ModelNotDownloaded();
  // Cùng lý do như [deleteTranslationModel] - tránh logic seed-từ-đĩa ở
  // `LlmModelRow` tự set ngược lại ModelReady bằng cache cũ.
  ref.invalidate(llmModelExistsOnDiskProvider);
}

/// Trạng thái tải model ML Kit (mobile) — KHÔNG family theo
/// [TranslationDirection] cùng lý do như [llmModelDownloadStateProvider]:
/// ML Kit tải model theo NGÔN NGỮ (Anh, Việt), dùng chung cho cả 2 chiều.
final mlkitModelDownloadStateProvider = StateProvider<ModelDownloadState>(
  (ref) => const ModelNotDownloaded(),
);

final mlkitModelExistsOnDiskProvider = FutureProvider<bool>((ref) {
  return MlKitTranslationService.instance.isDownloaded();
});

/// ML Kit không báo tiến độ theo byte (chỉ trả về xong/lỗi) - khác
/// opus-mt/LLM có callback `onProgress`, nên giữ nguyên [ModelDownloading]
/// ở dạng "không xác định" (0, 0) suốt quá trình tải, UI tự hiển thị
/// spinner không có % (xem `LlmModelRow`/`ModelStatusRow` đã xử lý case
/// `progress <= 0` sẵn).
Future<void> downloadMlKitModel(WidgetRef ref) async {
  final notifier = ref.read(mlkitModelDownloadStateProvider.notifier);
  notifier.state = const ModelDownloading(0, 0);
  try {
    await MlKitTranslationService.instance.download();
    notifier.state = const ModelReady();
  } catch (e) {
    notifier.state = ModelDownloadFailed(e.toString());
  }
}

Future<void> deleteMlKitModel(WidgetRef ref) async {
  await MlKitTranslationService.instance.delete();
  ref.read(mlkitModelDownloadStateProvider.notifier).state = const ModelNotDownloaded();
  // Cùng lý do như [deleteTranslationModel]/[deleteLlmModel].
  ref.invalidate(mlkitModelExistsOnDiskProvider);
}

/// Kết quả dịch [text] theo [direction] — `FutureProvider.family` tận
/// dụng cache tự nhiên của Riverpod (dịch lại cùng câu không chạy lại
/// inference). Model được nạp lười (lazy) trong lần dịch đầu tiên; ném
/// [ModelNotLoadedException] nếu chưa tải xong — UI (`translate_screen.
/// dart`) phải kiểm tra [modelDownloadStateProvider] là [ModelReady]
/// trước khi gọi provider này.
///
/// Suy luận ONNX không rẻ như tra DB — UI phải debounce input trước khi
/// invalidate provider này, không gọi lại mỗi keystroke.
///
/// Có mạng -> ưu tiên dịch qua MyMemory (miễn phí, độ chính xác cao hơn
/// model on-device đã quantize) trước, chỉ rơi về model on-device nếu
/// MyMemory lỗi/timeout hoặc không có mạng — theo yêu cầu user: model
/// offline hiện tại độ chính xác còn thấp, muốn ưu tiên online khi có
/// thể. Không cần tải model trước nếu đang online (xem gating tương ứng
/// ở `translate_screen.dart`).
final translateProvider =
    FutureProvider.family<String, (TranslationDirection, String)>((ref, args) async {
  final (direction, text) = args;
  if (text.trim().isEmpty) return '';

  final isOnline = ref.watch(connectivityProvider).value ?? false;
  if (isOnline) {
    final api = ref.watch(dictionaryApiServiceProvider);
    final online = await api.translate(
      text,
      from: direction == TranslationDirection.viToEn ? 'vi' : 'en',
      to: direction == TranslationDirection.viToEn ? 'en' : 'vi',
    );
    if (online != null) return online;
  }

  // Offline (hoặc MyMemory lỗi) trên desktop, nếu user đã chủ động tải
  // model AI cục bộ (Qwen2.5-3B) -> ưu tiên dùng thay vì opus-mt (chất
  // lượng cao hơn rõ rệt, xem SUMMARY.md), nhưng CHƯA bắt buộc tải: nếu
  // chưa tải, rơi về opus-mt như hành vi cũ, không đổi gì cho user chưa
  // biết tới tính năng mới này. Không kiểm tra RAM trước khi dùng (theo
  // yêu cầu: bỏ kiểm tra RAM trên Windows) - lỗi tải/dịch (nếu có, vd
  // OOM) vẫn được bắt bên dưới và rơi về opus-mt.
  if (isLlmTranslationSupportedPlatform && ref.watch(llmModelDownloadStateProvider) is ModelReady) {
    try {
      await LlmTranslationService.instance.load();
      final result = await LlmTranslationService.instance.translate(direction, text);
      debugPrint('[translateProvider] served by LLM: "$text" -> "$result"');
      return result;
    } catch (e) {
      // Bắt MỌI lỗi từ LLM (không chỉ LlmDegenerateOutputException) -
      // model có thể bị xoá ngoài ý muốn dù marker `.ready` còn (đĩa
      // hỏng/antivirus quarantine), lỗi native llama.cpp lúc load/gen,
      // v.v. Đây là lưới an toàn, không rơi về opus-mt sẽ để lỗi lọt
      // thẳng lên UI như crash trước đây (LlamaException hiện trực
      // tiếp cho user) thay vì tự phục hồi.
      debugPrint('[translateProvider] LLM lỗi, fallback opus-mt: $e');
    }
  }

  // Cùng logic ở trên nhưng cho mobile (ML Kit thay vì LLM) - 2 nhánh
  // loại trừ lẫn nhau theo platform (isLlmTranslationSupportedPlatform
  // chỉ true trên Windows, isMlKitTranslationSupportedPlatform chỉ true
  // trên Android/iOS) nên không có trường hợp cả 2 cùng chạy.
  if (isMlKitTranslationSupportedPlatform &&
      ref.watch(mlkitModelDownloadStateProvider) is ModelReady) {
    try {
      final result = await MlKitTranslationService.instance.translate(direction, text);
      debugPrint('[translateProvider] served by ML Kit: "$text" -> "$result"');
      return result;
    } catch (e) {
      // Cùng lý do như nhánh LLM - model ML Kit có thể bị hệ điều hành tự
      // xoá (dọn dẹp bộ nhớ khi thiếu dung lượng) dù state provider vẫn
      // nghĩ là ModelReady, không nên để lỗi lọt thẳng lên UI.
      debugPrint('[translateProvider] ML Kit lỗi, fallback opus-mt: $e');
    }
  }

  final service = ref.watch(translationServiceProvider);
  await service.loadDirection(direction);
  final result = await service.translate(direction, text);
  debugPrint('[translateProvider] served by opus-mt: "$text" -> "$result"');
  return result;
});
