import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'github_release_trust.dart';

/// Model VietAI/envit5-translation (T5-base), export ONNX cộng đồng
/// (`phatjk/envit5-translation-onnx`) — tự quantize INT8
/// (`tools/translation-eval/quantize_envit5.py`) rồi host lại trên
/// GitHub Release riêng (`envit5-v1`, KHÔNG dùng chung tag `mt-models-v1`
/// của opus-mt). Benchmark (`tools/translation-eval/results/`): vượt
/// trội Qwen2.5-3B cả về chất lượng (chrF 73.66 vs 51.7, term accuracy
/// 67.5% vs 50%) lẫn tốc độ (~2s vs ~3.4s) — thay thế Qwen làm offline
/// fallback chính trên desktop.
///
/// 1 file zip duy nhất (không per-direction như [ModelDownloadService] -
/// T5 dùng chung 1 model cho cả 2 chiều qua prefix "en: "/"vi: "), cùng
/// pattern zip+SHA-256 như opus-mt nhưng manifest khai báo tĩnh trong
/// code (như [LlmModelManifest]) thay vì fetch `.manifest.json` - artifact
/// cố định, không cần tra cứu động.
class Envit5ModelManifest {
  const Envit5ModelManifest({
    required this.fileName,
    required this.url,
    required this.sizeBytes,
    required this.sha256,
  });

  final String fileName;
  final String url;
  final int sizeBytes;
  final String sha256;

  static const v1 = Envit5ModelManifest(
    fileName: 'envit5-v1.zip',
    url: 'https://github.com/tuananhdut/csb-vocab-app/releases/download/envit5-v1/envit5-v1.zip',
    sizeBytes: 351694685,
    sha256: '89d782c047159e100a25decbf6bc06656909eed018fdfb40e49775e7c57dd1a8',
  );
}

/// Cùng ngữ nghĩa [ChecksumMismatchException]/[LlmChecksumMismatchException]
/// của 2 service kia — tách riêng vì độc lập, không dùng chung base.
class Envit5ChecksumMismatchException implements Exception {
  Envit5ChecksumMismatchException(this.expected, this.actual);
  final String expected;
  final String actual;

  @override
  String toString() => 'Checksum không khớp: kỳ vọng $expected, thực tế $actual';
}

class Envit5ModelDownloadService {
  Envit5ModelDownloadService._() {
    trustGitHubReleaseAssetHosts(_dio);
  }
  static final Envit5ModelDownloadService instance = Envit5ModelDownloadService._();

  // connectTimeout/receiveTimeout dùng để bắt kết nối treo (mạng chập
  // chờn: TCP vẫn mở nhưng ngừng gửi dữ liệu) - không có thì tải có thể
  // đứng vô thời hạn ở ModelDownloading mà không bao giờ báo lỗi (đã gặp
  // thực tế trên máy khác). receiveTimeout là khoảng nghỉ tối đa GIỮA 2
  // lần nhận dữ liệu (không phải tổng thời gian tải), nên an toàn cho
  // file lớn miễn dữ liệu còn chảy đều.
  final _dio = Dio(
    BaseOptions(connectTimeout: const Duration(seconds: 30), receiveTimeout: const Duration(seconds: 30)),
  );
  static const _manifest = Envit5ModelManifest.v1;

  Future<Directory> _modelDir() async {
    final dir = await getApplicationSupportDirectory();
    return Directory(p.join(dir.path, 'models', 'envit5'));
  }

  Future<Directory> get modelDir => _modelDir();

  Future<File> _readyMarker() async {
    final dir = await _modelDir();
    return File(p.join(dir.path, '.ready'));
  }

  Future<bool> isDownloaded() async => (await _readyMarker()).existsSync();

  /// Tải + xác minh SHA-256 + giải nén. Ném [Envit5ChecksumMismatchException]
  /// nếu sai — gọi lại để retry (không tự resume phần đã tải, cùng đánh đổi
  /// có chủ đích như 2 service tải model kia).
  Future<void> download({
    required void Function(int received, int total) onProgress,
    CancelToken? cancelToken,
  }) async {
    final dir = await _modelDir();
    if (!dir.existsSync()) dir.createSync(recursive: true);

    final root = dir.parent;
    final partFile = File(p.join(root.path, '${_manifest.fileName}.part'));
    final zipFile = File(p.join(root.path, _manifest.fileName));

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
      throw Envit5ChecksumMismatchException(_manifest.sha256, actualSha256);
    }

    if (zipFile.existsSync()) await zipFile.delete();
    await partFile.rename(zipFile.path);

    await _extract(zipFile, dir);
    await zipFile.delete();

    final marker = await _readyMarker();
    await marker.writeAsString(DateTime.now().toIso8601String());
  }

  Future<void> delete() async {
    final dir = await _modelDir();
    if (dir.existsSync()) await dir.delete(recursive: true);
  }

  Future<String> _sha256Of(File file) async {
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString();
  }

  Future<void> _extract(File zipFile, Directory destDir) async {
    if (destDir.existsSync()) await destDir.delete(recursive: true);
    destDir.createSync(recursive: true);

    final bytes = await zipFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);
    for (final entry in archive) {
      if (!entry.isFile) continue;
      final outFile = File(p.join(destDir.path, entry.name));
      outFile.createSync(recursive: true);
      await outFile.writeAsBytes(entry.content as List<int>);
    }
  }
}
