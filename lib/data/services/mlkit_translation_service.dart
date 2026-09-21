import 'dart:async';

import 'package:google_mlkit_translation/google_mlkit_translation.dart';

import '../../domain/entities/translation_direction.dart';

const _enBcp = 'en';
const _viBcp = 'vi';

// ML Kit mac dinh cho isWifiRequired=true VA khong tu timeout - offline
// hoan toan (khong chi thieu WiFi) khien cuoc goi native cu treo vo thoi
// han thay vi bao loi, UI ket spinner mai (bug gap thuc te). Chan bang
// timeout o day + isWifiRequired: false (cho dung mobile data).
const _downloadTimeout = Duration(seconds: 60);

TranslateLanguage _langFor(TranslationDirection direction, {required bool source}) {
  final isEnToVi = direction == TranslationDirection.enToVi;
  final wantEnglish = source ? isEnToVi : !isEnToVi;
  return wantEnglish ? TranslateLanguage.english : TranslateLanguage.vietnamese;
}

/// Suy luận dịch bằng Google ML Kit Translation (on-device) — lựa chọn
/// offline fallback cho mobile (Android/iOS), độc lập với
/// [TranslationService] (opus-mt, vẫn là fallback mặc định khi ML Kit
/// chưa tải) và [LlmTranslationService] (chỉ desktop). ML Kit tự quản lý
/// việc tải/lưu model ngôn ngữ (~30-150MB/ngôn ngữ đã nạp), không cần tự
/// viết download/checksum như 2 service kia.
///
/// Xem hội thoại brainstorm dẫn tới quyết định này — chưa có benchmark
/// số liệu thực tế như opus-mt/Qwen (không có binding Python cho ML Kit,
/// SDK chỉ chạy qua Android/iOS native), chỉ có suy luận có căn cứ (cùng
/// công nghệ nền với Google Translate offline).
class MlKitTranslationService {
  MlKitTranslationService._();
  static final MlKitTranslationService instance = MlKitTranslationService._();

  final _modelManager = OnDeviceTranslatorModelManager();
  final _translators = <TranslationDirection, OnDeviceTranslator>{};

  /// Không nhận [TranslationDirection] - ML Kit tải model theo NGÔN NGỮ,
  /// dùng chung cho cả 2 chiều (khớp [download]/[delete] bên dưới), nên
  /// luôn kiểm tra đủ cả Anh lẫn Việt bất kể đang hỏi chiều nào.
  Future<bool> isDownloaded() async {
    final en = await _modelManager.isModelDownloaded(_enBcp);
    final vi = await _modelManager.isModelDownloaded(_viBcp);
    return en && vi;
  }

  /// Tải model 2 ngôn ngữ (Anh + Việt) — dùng chung cho cả 2 chiều dịch
  /// (khác opus-mt cần model riêng/chiều), ML Kit chỉ cần model theo
  /// NGÔN NGỮ chứ không theo CHIỀU. Ném [TimeoutException] nếu quá
  /// [_downloadTimeout] - caller (`downloadMlKitModel`) bắt lỗi chung,
  /// hiển thị [ModelDownloadFailed] cho user thử lại thay vì kẹt spinner.
  Future<void> download() async {
    await _modelManager
        .downloadModel(_enBcp, isWifiRequired: false)
        .timeout(_downloadTimeout);
    await _modelManager
        .downloadModel(_viBcp, isWifiRequired: false)
        .timeout(_downloadTimeout);
  }

  Future<void> delete() async {
    for (final t in _translators.values) {
      await t.close();
    }
    _translators.clear();
    await _modelManager.deleteModel(_enBcp);
    await _modelManager.deleteModel(_viBcp);
  }

  Future<String> translate(TranslationDirection direction, String text) async {
    if (text.trim().isEmpty) return '';
    final translator = _translators.putIfAbsent(
      direction,
      () => OnDeviceTranslator(
        sourceLanguage: _langFor(direction, source: true),
        targetLanguage: _langFor(direction, source: false),
      ),
    );
    return translator.translateText(text);
  }
}
