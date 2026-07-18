import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

/// Cơ sở dữ liệu người dùng (đọc-ghi): tiến độ học, lịch ôn (SRS),
/// lịch sử tra cứu. Tách riêng khỏi `vocab.db` (read-only) để cập nhật
/// dữ liệu từ vựng không ảnh hưởng tiến độ học (xem plan 04 mục 2.2).
class UserDatabase {
  UserDatabase._(this._db);

  final Database _db;
  Database get raw => _db;

  static const _fileName = 'user.db';

  static Future<UserDatabase> open() async {
    final dir = await getApplicationSupportDirectory();
    final dbPath = p.join(dir.path, _fileName);
    final db = sqlite3.open(dbPath);
    _createSchema(db);
    return UserDatabase._(db);
  }

  static void _createSchema(Database db) {
    db.execute('''
      CREATE TABLE IF NOT EXISTS learned_words (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        word_id INTEGER NOT NULL UNIQUE,
        is_learned INTEGER NOT NULL DEFAULT 1,
        ease_factor REAL NOT NULL DEFAULT 2.5,
        interval_days INTEGER NOT NULL DEFAULT 0,
        repetitions INTEGER NOT NULL DEFAULT 0,
        due_date INTEGER,
        last_reviewed INTEGER
      );
    ''');
    db.execute(
      'CREATE INDEX IF NOT EXISTS idx_learned_words_due ON learned_words(due_date);',
    );
    db.execute('''
      CREATE TABLE IF NOT EXISTS search_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        word TEXT NOT NULL,
        searched_at INTEGER NOT NULL
      );
    ''');
    db.execute('''
      CREATE TABLE IF NOT EXISTS review_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        word_id INTEGER NOT NULL,
        reviewed_at INTEGER NOT NULL,
        rating INTEGER NOT NULL
      );
    ''');
  }

  void dispose() => _db.close();
}
