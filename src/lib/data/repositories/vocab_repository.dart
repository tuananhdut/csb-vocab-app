import 'package:sqlite3/sqlite3.dart';

import '../../domain/entities/vocab.dart';

/// Truy vấn dữ liệu từ vựng (read-only) từ vocab.db.
class VocabRepository {
  VocabRepository(this._db);
  final Database _db;

  VocabWord _wordFromRow(Row r) => VocabWord(
        id: r['id'] as int,
        word: r['word'] as String? ?? '',
        phonetic: r['phonetic'] as String? ?? '',
        partOfSpeech: r['part_of_speech'] as String? ?? '',
        meaningVi: r['meaning_vi'] as String? ?? '',
        chapterTitle: r['chapter_title'] as String? ?? '',
        imagePath: r['image_path'] as String?,
        isSubentry: (r['is_subentry'] as int? ?? 0) == 1,
      );

  static const _selectWord = '''
    SELECT w.id, w.word, w.phonetic, w.part_of_speech, w.meaning_vi,
           w.image_path, w.is_subentry, c.title AS chapter_title
    FROM words w LEFT JOIN chapters c ON c.id = w.chapter_id
  ''';

  /// Tra cứu 2 chiều: khớp từ tiếng Anh HOẶC nghĩa tiếng Việt.
  List<VocabWord> search(String query, {int limit = 50}) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final like = '%$q%';
    final prefix = '$q%';
    final rows = _db.select(
      '''$_selectWord
         WHERE w.word_lower LIKE ? OR lower(w.meaning_vi) LIKE ?
         ORDER BY
           CASE WHEN w.word_lower = ? THEN 0
                WHEN w.word_lower LIKE ? THEN 1 ELSE 2 END,
           length(w.word), w.word_lower
         LIMIT ?''',
      [like, like, q, prefix, limit],
    );
    return rows.map(_wordFromRow).toList();
  }

  List<Chapter> chapters() {
    final rows = _db.select('''
      SELECT c.id, c.chapter_no, c.title,
             (SELECT COUNT(*) FROM words w WHERE w.chapter_id = c.id) AS cnt
      FROM chapters c ORDER BY c.chapter_no
    ''');
    return rows
        .map((r) => Chapter(
              id: r['id'] as int,
              chapterNo: r['chapter_no'] as int? ?? 0,
              title: r['title'] as String? ?? '',
              wordCount: r['cnt'] as int? ?? 0,
            ))
        .toList();
  }

  List<VocabWord> wordsByChapter(int chapterId, {bool includeSub = true}) {
    final rows = _db.select(
      '''$_selectWord
         WHERE w.chapter_id = ? ${includeSub ? '' : 'AND w.is_subentry = 0'}
         ORDER BY w.is_subentry, w.word_lower''',
      [chapterId],
    );
    return rows.map(_wordFromRow).toList();
  }

  List<WordExample> examplesFor(int wordId) {
    final rows = _db.select(
      'SELECT example_en, example_vi FROM examples WHERE word_id = ?',
      [wordId],
    );
    return rows
        .map((r) => WordExample(
              en: r['example_en'] as String? ?? '',
              vi: r['example_vi'] as String? ?? '',
            ))
        .toList();
  }
}
