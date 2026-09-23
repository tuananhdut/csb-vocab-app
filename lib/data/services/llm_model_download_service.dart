import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Tải model GGUF (Qwen2.5-3B-Instruct, quantize Q4_K_M) trực tiếp từ
/// repo chính chủ Qwen trên Hugging Face — KHÁC cách làm của
/// [ModelDownloadService] (opus-mt tự host + zip trên GitHub Release):
/// file GGUF đơn (không cần giải nén), và dùng thẳng nguồn gốc thay vì
/// tự mirror, tránh vấn đề license redistribution (Qwen2.5 Apache-2.0
/// nhưng đơn giản hơn khi trỏ thẳng nguồn chính chủ). Chỉ dùng làm
/// fallback offline trên desktop (xem `llm_translation_service.dart`,
/// [ModelDownloadState] tái dùng ở `translation_providers.dart`) — CHƯA
/// thay thế opus-mt, chỉ là lựa chọn bổ sung khi user chủ động tải.
///
/// Kết quả benchmark (`tools/translation-eval/results/SUMMARY.md`):
/// term accuracy 50% (Qwen2.5-3B) so với 20% (opus-mt hiện tại), RAM
/// đỉnh thực đo ~3.36GB — khả thi trên máy 8GB.
class LlmModelManifest {
  const LlmModelManifest({
    required this.fileName,
    required this.url,
    required this.sizeBytes,
    required this.sha256,
  });

  final String fileName;
  final String url;
  final int sizeBytes;
  final String sha256;

  static const qwen25_3bInstructQ4 = LlmModelManifest(
    fileName: 'qwen2.5-3b-instruct-q4_k_m.gguf',
    url:
        'https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF/resolve/main/qwen2.5-3b-instruct-q4_k_m.gguf',
    sizeBytes: 2104932768,
    sha256: '626b4a6678b86442240e33df819e00132d3ba7dddfe1cdc4fbb18e0a9615c62d',
  );
}

/// Ném khi checksum sau khi tải không khớp — cùng ngữ nghĩa với
/// [ChecksumMismatchException] của `model_download_service.dart`, tách
/// riêng class vì 2 service độc lập, không dùng chung base.
class LlmChecksumMismatchException implements Exception {
  LlmChecksumMismatchException(this.expected, this.actual);
  final String expected;
  final String actual;

  @override
  String toString() => 'Checksum không khớp: kỳ vọng $expected, thực tế $actual';
}

class LlmModelDownloadService {
  LlmModelDownloadService._();
  static final LlmModelDownloadService instance = LlmModelDownloadService._();

  // Cùng lý do như Envit5ModelDownloadService - bắt kết nối treo thay vì
  // đứng vô thời hạn ở ModelDownloading. receiveTimeout là khoảng nghỉ
  // tối đa GIỮA 2 lần nhận dữ liệu, an toàn cho file 2.1GB miễn dữ liệu
  // còn chảy đều.
  final _dio = Dio(
    BaseOptions(connectTimeout: const Duration(seconds: 30), receiveTimeout: const Duration(seconds: 30)),
  );
  static const _manifest = LlmModelManifest.qwen25_3bInstructQ4;

  Future<Directory> _modelsDir() async {
    final dir = await getApplicationSupportDirectory();
    return Directory(p.join(dir.path, 'models', 'llm'));
  }

  Future<File> modelFile() async {
    final dir = await _modelsDir();
    return File(p.join(dir.path, _manifest.fileName));
  }

  Future<File> _readyMarker() async {
    final dir = await _modelsDir();
    return File(p.join(dir.path, '${_manifest.fileName}.ready'));
  }

  Future<bool> isDownloaded() async => (await _readyMarker()).existsSync();

  /// Tải + xác minh SHA-256. Ném [LlmChecksumMismatchException] nếu
  /// sai — gọi lại để retry (không tự resume phần đã tải, cùng đánh đổi
  /// có chủ đích như `ModelDownloadService`).
  Future<void> download({
    required void Function(int received, int total) onProgress,
    CancelToken? cancelToken,
  }) async {
    final dir = await _modelsDir();
    if (!dir.existsSync()) dir.createSync(recursive: true);

    final partFile = File(p.join(dir.path, '${_manifest.fileName}.part'));
    await _dio.download(
      _manifest.url,
      partFile.path,
      onReceiveProgress: onProgress,
      cancelToken: cancelToken,
      deleteOnError: true,
    );

    final actualSha256 = await _sha256Of(partFile);
    if (actualSha256 != _manifest.sha256) {
      await partFile.delete();
      throw LlmChecksumMismatchException(_manifest.sha256, actualSha256);
    }

    final dest = await modelFile();
    if (dest.existsSync()) await dest.delete();
    await partFile.rename(dest.path);

    final marker = await _readyMarker();
    await marker.writeAsString(DateTime.now().toIso8601String());
  }

  Future<void> delete() async {
    final dest = await modelFile();
    if (dest.existsSync()) await dest.delete();
    final marker = await _readyMarker();
    if (marker.existsSync()) await marker.delete();
  }

  Future<String> _sha256Of(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }
}
