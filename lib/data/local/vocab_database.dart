import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

/// Mở cơ sở dữ liệu từ vựng đóng gói trong assets.
///
/// Lần đầu chạy: copy `assets/db/vocab.db` ra thư mục dữ liệu app
/// (assets là read-only nên không mở trực tiếp được). Copy lại nếu
/// kích thước khác (khi cập nhật DB trong lúc phát triển).
///
/// Mở READ-WRITE (không còn `OpenMode.readOnly`): dù phần lớn dữ liệu
/// (words/examples/sections/chapters...) chỉ đọc, bảng `dictionaries`
/// cần ghi được để user tự tạo "bộ từ điển cá nhân" (SCR-07, nút "Tạo
/// bộ mới") — file đã copy ra `ApplicationSupportDirectory` riêng cho
/// từng máy, không phải asset gốc trong app bundle, nên ghi vào đây an
/// toàn, không ảnh hưởng bản đóng gói sẵn.
class VocabDatabase {
  VocabDatabase._(this._db);

  final Database _db;
  Database get raw => _db;

  static const _assetPath = 'assets/db/vocab.db';
  static const _fileName = 'vocab.db';

  static Future<VocabDatabase> open() async {
    final dir = await getApplicationSupportDirectory();
    final dbPath = p.join(dir.path, _fileName);
    final file = File(dbPath);

    final data = await rootBundle.load(_assetPath);
    final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

    final needCopy = !file.existsSync() || file.lengthSync() != bytes.length;
    if (needCopy) {
      await file.writeAsBytes(bytes, flush: true);
    }

    final db = sqlite3.open(dbPath);
    return VocabDatabase._(db);
  }

  void dispose() => _db.close();
}
