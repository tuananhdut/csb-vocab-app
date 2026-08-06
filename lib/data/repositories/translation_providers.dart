import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show StateProvider;

import '../../domain/entities/translation_direction.dart';
import '../services/model_download_service.dart';
import '../services/translation_service.dart';

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
}

final translationServiceProvider = Provider<TranslationService>((ref) {
  return TranslationService.instance;
});

/// Kết quả dịch [text] theo [direction] — `FutureProvider.family` tận
/// dụng cache tự nhiên của Riverpod (dịch lại cùng câu không chạy lại
/// inference). Model được nạp lười (lazy) trong lần dịch đầu tiên; ném
/// [ModelNotLoadedException] nếu chưa tải xong — UI (`translate_screen.
/// dart`) phải kiểm tra [modelDownloadStateProvider] là [ModelReady]
/// trước khi gọi provider này.
///
/// Suy luận ONNX không rẻ như tra DB — UI phải debounce input trước khi
/// invalidate provider này, không gọi lại mỗi keystroke.
final translateProvider =
    FutureProvider.family<String, (TranslationDirection, String)>((ref, args) async {
  final (direction, text) = args;
  if (text.trim().isEmpty) return '';
  final service = ref.watch(translationServiceProvider);
  await service.loadDirection(direction);
  return service.translate(direction, text);
});
