import 'package:sqlite3/sqlite3.dart';

import '../../domain/entities/dictionary.dart';
import '../../domain/entities/section.dart';
import '../../domain/entities/word.dart';

/// Mã số `part_of_speech` (0-4, xem `docs/db/schema.sql`) -> nhãn viết
/// tắt hiển thị trong UI (giữ đúng nhãn gốc từ nguồn biên soạn, trước
/// khi chuẩn hoá sang mã số lúc migrate).
const _posLabels = {0: 'dt', 1: 'đt', 2: 'tt', 3: 'trt', 4: 'gt'};

/// Truy vấn dữ liệu từ vựng (read-only) từ vocab.db.
class VocabRepository {
  VocabRepository(this._db);
  final Database _db;

  VocabWord _wordFromRow(Row r) => VocabWord(
        id: r['id'] as int,
        word: r['word'] as String? ?? '',
        phonetic: r['phonetic'] as String? ?? '',
        partOfSpeech: _posLabels[r['part_of_speech'] as int?] ?? '',
        meaningVi: r['meaning_vi'] as String? ?? '',
        chapterTitle: r['chapter_title'] as String? ?? '',
        imagePath: r['image_path'] as String?,
        isSubentry: (r['is_subentry'] as int? ?? 0) == 1,
        isManual: (r['source'] as int? ?? 0) == 2,
      );

  // "chapter_title" o day la ten bo tu dien (dictionaries) - giu ten
  // cot alias cu de khong phai sua VocabWord/word_widgets.dart hien co.
  // 1 word co the thuoc nhieu dictionaries (N-N) nhung UI hien tai chi
  // hien thi 1 nhan -> lay bo dau tien theo dictionary_id tang dan.
  static const _selectWord = '''
    SELECT w.id, w.word, w.phonetic, w.part_of_speech, w.meaning_vi,
           w.image_path, w.is_subentry, w.source,
           (SELECT d.name FROM word_dictionaries wd
              JOIN dictionaries d ON d.id = wd.dictionary_id
              WHERE wd.word_id = w.id
              ORDER BY wd.dictionary_id LIMIT 1) AS chapter_title
    FROM words w
  ''';

  /// Tra cứu 2 chiều: khớp từ tiếng Anh HOẶC nghĩa tiếng Việt.
  ///
  /// Loại trừ `source=2` (MANUAL — từ tự thêm ở SCR-07b): theo đúng
  /// mockup "Từ tự thêm chỉ hiển thị trong bộ từ điển cá nhân — không
  /// xuất hiện khi Tra cứu trong giáo trình gốc".
  List<VocabWord> search(String query, {int limit = 50}) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final like = '%$q%';
    final prefix = '$q%';
    final rows = _db.select(
      '''$_selectWord
         WHERE w.source != 2 AND (w.word_lower LIKE ? OR lower(w.meaning_vi) LIKE ?)
         ORDER BY
           CASE WHEN w.word_lower = ? THEN 0
                WHEN w.word_lower LIKE ? THEN 1 ELSE 2 END,
           length(w.word), w.word_lower
         LIMIT ?''',
      [like, like, q, prefix, limit],
    );
    return rows.map(_wordFromRow).toList();
  }

  /// Tra 1 từ theo id (dùng khi ghép dữ liệu ôn tập từ `user.db`).
  VocabWord? wordById(int id) {
    final rows = _db.select('$_selectWord WHERE w.id = ?', [id]);
    if (rows.isEmpty) return null;
    return _wordFromRow(rows.first);
  }

  /// Danh sách bộ từ điển giáo trình gốc (`is_default=1`) — bỏ "Chưa
  /// phân loại" (`is_deletable=0`) vì màn "Học" hiện tại chỉ duyệt các
  /// bộ chuyên ngành, không có khái niệm từ mồ côi.
  List<Chapter> chapters() {
    final rows = _db.select('''
      SELECT d.id, d.sort_order, d.name,
             (SELECT COUNT(*) FROM word_dictionaries wd WHERE wd.dictionary_id = d.id) AS cnt
      FROM dictionaries d
      WHERE d.is_deletable = 1
      ORDER BY d.sort_order
    ''');
    return rows
        .map((r) => Chapter(
              id: r['id'] as int,
              chapterNo: r['sort_order'] as int? ?? 0,
              title: r['name'] as String? ?? '',
              wordCount: r['cnt'] as int? ?? 0,
            ))
        .toList();
  }

  List<VocabWord> wordsByChapter(int chapterId, {bool includeSub = true}) {
    final rows = _db.select(
      '''$_selectWord
         JOIN word_dictionaries wd ON wd.word_id = w.id
         WHERE wd.dictionary_id = ? ${includeSub ? '' : 'AND w.is_subentry = 0'}
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

  /// Danh sách Section (SCR-03) — chủ đề lớn của giáo trình, chứa các
  /// bài đọc (`ArticleChapter`). Xem `docs/db/schema.sql`.
  List<Section> sections() {
    final rows = _db.select('SELECT id, name, sort_order FROM sections ORDER BY sort_order');
    return rows
        .map((r) => Section(
              id: r['id'] as int,
              name: r['name'] as String? ?? '',
              sortOrder: r['sort_order'] as int? ?? 0,
            ))
        .toList();
  }

  /// Danh sách bài đọc (SCR-03b) của 1 Section, KHÔNG kèm `content` đầy
  /// đủ (danh sách chỉ cần tiêu đề) — dùng [articleChapterById] khi mở
  /// bài đọc cụ thể.
  List<ArticleChapter> articleChaptersBySection(int sectionId) {
    final rows = _db.select(
      'SELECT id, section_id, title, sort_order FROM chapters WHERE section_id = ? ORDER BY sort_order',
      [sectionId],
    );
    return rows
        .map((r) => ArticleChapter(
              id: r['id'] as int,
              sectionId: r['section_id'] as int,
              title: r['title'] as String? ?? '',
              sortOrder: r['sort_order'] as int? ?? 0,
            ))
        .toList();
  }

  /// 1 bài đọc đầy đủ (SCR-03c), kèm `content` Markdown thô.
  ArticleChapter? articleChapterById(int id) {
    final rows = _db.select(
      'SELECT id, section_id, title, sort_order, content FROM chapters WHERE id = ?',
      [id],
    );
    if (rows.isEmpty) return null;
    final r = rows.first;
    return ArticleChapter(
      id: r['id'] as int,
      sectionId: r['section_id'] as int,
      title: r['title'] as String? ?? '',
      sortOrder: r['sort_order'] as int? ?? 0,
      content: r['content'] as String?,
    );
  }

  /// Toàn bộ bộ từ điển (SCR-07, kể cả "Chưa phân loại") kèm danh sách
  /// `word_id` — dùng để ghép với `learned_words` ở `user.db` (2 file
  /// SQLite riêng, không JOIN được bằng SQL, phải ghép ở tầng Dart, xem
  /// [MyDictionariesRepository]).
  List<({int id, String name, bool isDefault, bool isDeletable, List<int> wordIds})>
      dictionariesWithWordIds() {
    final dictRows = _db.select(
      'SELECT id, name, is_default, is_deletable FROM dictionaries ORDER BY sort_order',
    );
    return dictRows.map((d) {
      final dictionaryId = d['id'] as int;
      final wordRows = _db.select(
        'SELECT word_id FROM word_dictionaries WHERE dictionary_id = ?',
        [dictionaryId],
      );
      return (
        id: dictionaryId,
        name: d['name'] as String? ?? '',
        isDefault: (d['is_default'] as int? ?? 0) == 1,
        isDeletable: (d['is_deletable'] as int? ?? 0) == 1,
        wordIds: wordRows.map((w) => w['word_id'] as int).toList(),
      );
    }).toList();
  }

  /// `dictionary_id` đại diện của 1 từ — lấy bộ đầu tiên nếu từ thuộc
  /// nhiều bộ (nhất quán cách `chapter_title` ở [_selectWord] đã làm).
  /// Trả `null` nếu từ không thuộc bộ nào (chỉ "Chưa phân loại").
  int? primaryDictionaryId(int wordId) {
    final rows = _db.select(
      'SELECT dictionary_id FROM word_dictionaries WHERE word_id = ? ORDER BY dictionary_id LIMIT 1',
      [wordId],
    );
    if (rows.isEmpty) return null;
    return rows.first['dictionary_id'] as int;
  }

  /// [count] nghĩa tiếng Việt ngẫu nhiên khác [wordId] — dùng làm đáp án
  /// nhiễu trắc nghiệm (xem `docs/csb-vocab-analysis/tasks/
  /// 02-review-multi-mode/03-plan.md` BE-04). Ưu tiên lấy trong cùng
  /// [dictionaryId] để đáp án nhiễu cùng chủ đề; nếu không đủ [count] từ
  /// khác trong bộ đó, fallback lấy ngẫu nhiên trên toàn bộ `words`.
  List<String> randomDistractors(int wordId, int? dictionaryId, {int count = 3}) {
    if (dictionaryId != null) {
      final rows = _db.select(
        '''SELECT DISTINCT w.meaning_vi FROM words w
           JOIN word_dictionaries wd ON wd.word_id = w.id
           WHERE wd.dictionary_id = ? AND w.id != ?
           ORDER BY RANDOM() LIMIT ?''',
        [dictionaryId, wordId, count],
      );
      final meanings = rows.map((r) => r['meaning_vi'] as String).toList();
      if (meanings.length >= count) return meanings;
    }

    final rows = _db.select(
      'SELECT DISTINCT meaning_vi FROM words WHERE id != ? ORDER BY RANDOM() LIMIT ?',
      [wordId, count],
    );
    return rows.map((r) => r['meaning_vi'] as String).toList();
  }

  /// Tạo 1 bộ từ điển cá nhân mới (rỗng, `is_default=0, is_deletable=1`)
  /// — SCR-07 nút "Tạo bộ mới". Xếp cuối danh sách (`sort_order` lớn
  /// nhất hiện có + 1).
  int createDictionary(String name) {
    final maxSortRow = _db.select('SELECT MAX(sort_order) AS m FROM dictionaries').first;
    final nextSortOrder = (maxSortRow['m'] as int? ?? 0) + 1;
    final now = DateTime.now().millisecondsSinceEpoch;

    _db.execute(
      'INSERT INTO dictionaries (name, is_default, is_deletable, sort_order, created_at) VALUES (?, 0, 1, ?, ?)',
      [name, nextSortOrder, now],
    );
    return _db.lastInsertRowId;
  }

  /// Thêm 1 từ tự nhập tay (SCR-07b, `source=2` MANUAL — không có trong
  /// giáo trình gốc), gán thẳng vào [dictionaryId]. [phonetic]/
  /// [partOfSpeechCode]/[imagePath] để `null` nếu người dùng bỏ trống
  /// (tuỳ chọn). [imagePath] là đường dẫn tuyệt đối đã copy vào thư mục
  /// lưu trữ của app (xem `AddWordScreen._pickImage`), khác đường dẫn
  /// asset tương đối (`assets/images/words/...`) của từ có sẵn.
  int insertManualWord({
    required String word,
    required String meaningVi,
    required int dictionaryId,
    String? phonetic,
    int? partOfSpeechCode,
    String? imagePath,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    _db.execute(
      '''INSERT INTO words (word, word_lower, phonetic, meaning_vi,
                             part_of_speech, is_subentry, image_path, source, created_at)
         VALUES (?, ?, ?, ?, ?, 0, ?, 2, ?)''',
      [word, word.toLowerCase(), phonetic, meaningVi, partOfSpeechCode, imagePath, now],
    );
    final wordId = _db.lastInsertRowId;

    _db.execute(
      'INSERT INTO word_dictionaries (word_id, dictionary_id, added_at) VALUES (?, ?, ?)',
      [wordId, dictionaryId, now],
    );
    return wordId;
  }

  /// Sửa 1 từ tự thêm (SCR-07c "Sửa từ") — chỉ áp dụng cho `source=2`,
  /// gọi từ UI đã kiểm tra [VocabWord.isManual] trước đó nên không lọc
  /// lại điều kiện `source` ở đây.
  void updateManualWord({
    required int wordId,
    required String word,
    required String meaningVi,
    String? phonetic,
    int? partOfSpeechCode,
    String? imagePath,
  }) {
    _db.execute(
      '''UPDATE words SET word = ?, word_lower = ?, phonetic = ?, meaning_vi = ?,
                           part_of_speech = ?, image_path = ?
         WHERE id = ?''',
      [word, word.toLowerCase(), phonetic, meaningVi, partOfSpeechCode, imagePath, wordId],
    );
  }

  /// Xoá hẳn 1 từ tự thêm (SCR-07c "Xoá từ") khỏi `words`, kèm dọn các
  /// bảng phụ thuộc thủ công — `VocabDatabase.open()` không bật
  /// `PRAGMA foreign_keys`, nên `ON DELETE CASCADE` khai báo trong
  /// `docs/db/schema.sql` không tự chạy ở runtime.
  void deleteWord(int wordId) {
    _db.execute('DELETE FROM word_dictionaries WHERE word_id = ?', [wordId]);
    _db.execute('DELETE FROM examples WHERE word_id = ?', [wordId]);
    _db.execute('DELETE FROM words WHERE id = ?', [wordId]);
  }
}
