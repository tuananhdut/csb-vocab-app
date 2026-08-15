import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../domain/entities/translation_direction.dart';

/// URL gốc GitHub Release chứa model dịch đã quantize (xem
/// `tools/onnx-model-conversion/README.md`, [IMPL-017]).
const _releaseBaseUrl =
    'https://github.com/tuananhdut/csb-vocab-app/releases/download/mt-models-v1';

class ModelManifest {
  const ModelManifest({required this.file, required this.sizeBytes, required this.sha256});

  factory ModelManifest.fromJson(Map<String, dynamic> json) => ModelManifest(
        file: json['file'] as String,
        sizeBytes: json['sizeBytes'] as int,
        sha256: json['sha256'] as String,
      );

  final String file;
  final int sizeBytes;
  final String sha256;
}

/// Báo checksum sai sau khi tải xong — dấu hiệu file tải hỏng/bị can
/// thiệp, không dùng được, phải tải lại (không tự động retry ở tầng này).
class ChecksumMismatchException implements Exception {
  ChecksumMismatchException(this.expected, this.actual);
  final String expected;
  final String actual;

  @override
  String toString() => 'Checksum không khớp: kỳ vọng $expected, thực tế $actual';
}

/// Tải + xác minh + giải nén model dịch on-device theo yêu cầu (FR-4,
/// [IMPL-017]) — không bundle sẵn trong app, chỉ tải khi user bật tính
/// năng dịch cho 1 chiều cụ thể. Mỗi chiều tải/xoá độc lập.
///
/// Lưu ở `getApplicationSupportDirectory()/models/<modelName>/`, cùng
/// pattern với [VocabDatabase] (copy asset ra thư mục ghi được), nhưng
/// nguồn là tải mạng thay vì asset đóng gói sẵn.
class ModelDownloadService {
  ModelDownloadService._();
  static final ModelDownloadService instance = ModelDownloadService._();

  final _dio = Dio();

  Future<Directory> _modelsRootDir() async {
    final dir = await getApplicationSupportDirectory();
    return Directory(p.join(dir.path, 'models'));
  }

  Future<Directory> directoryFor(TranslationDirection direction) async {
    final root = await _modelsRootDir();
    return Directory(p.join(root.path, direction.modelName));
  }

  /// File đánh dấu "đã tải và giải nén xong" — tránh việc thư mục có mặt
  /// nhưng dở dang (crash giữa lúc giải nén) bị coi nhầm là đã sẵn sàng.
  Future<File> _readyMarkerFor(TranslationDirection direction) async {
    final dir = await directoryFor(direction);
    return File(p.join(dir.path, '.ready'));
  }

  Future<bool> isDirectionDownloaded(TranslationDirection direction) async {
    final marker = await _readyMarkerFor(direction);
    return marker.existsSync();
  }

  Future<ModelManifest> _fetchManifest(TranslationDirection direction) async {
    final url = '$_releaseBaseUrl/${direction.modelName}.manifest.json';
    final response = await _dio.get<String>(url);
    final json = jsonDecode(response.data!) as Map<String, dynamic>;
    return ModelManifest.fromJson(json);
  }

  /// Tải + giải nén 1 chiều. Ném [ChecksumMismatchException] nếu file
  /// tải về không khớp SHA-256 trong manifest — gọi lại hàm này để retry
  /// (không tự resume phần đã tải, xem ghi chú "Resume" trong kế hoạch
  /// FR-4 — đánh đổi có chủ đích cho v1).
  Future<void> downloadDirection(
    TranslationDirection direction, {
    required void Function(int received, int total) onProgress,
    CancelToken? cancelToken,
  }) async {
    final manifest = await _fetchManifest(direction);
    final root = await _modelsRootDir();
    if (!root.existsSync()) root.createSync(recursive: true);

    final partFile = File(p.join(root.path, '${direction.modelName}.part'));
    final zipFile = File(p.join(root.path, '${direction.modelName}.zip'));

    await _dio.download(
      '$_releaseBaseUrl/${manifest.file}',
      partFile.path,
      onReceiveProgress: onProgress,
      cancelToken: cancelToken,
      deleteOnError: true,
    );

    final actualSha256 = await _sha256Of(partFile);
    if (actualSha256 != manifest.sha256) {
      await partFile.delete();
      throw ChecksumMismatchException(manifest.sha256, actualSha256);
    }

    if (zipFile.existsSync()) await zipFile.delete();
    await partFile.rename(zipFile.path);

    final destDir = await directoryFor(direction);
    await _extract(zipFile, destDir);
    await zipFile.delete();

    final marker = await _readyMarkerFor(direction);
    await marker.writeAsString(DateTime.now().toIso8601String());
  }

  Future<void> deleteDirection(TranslationDirection direction) async {
    final dir = await directoryFor(direction);
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
