import 'package:sqlite3/sqlite3.dart';

import '../../domain/entities/dictionary.dart';
import '../../domain/entities/section.dart';
import '../../domain/entities/word.dart';

/// Mã số `part_of_speech` (0-4, xem `docs/db/schema.sql`) -> nhãn viết
/// tắt hiển thị trong UI (giữ đúng nhãn gốc từ nguồn biên soạn, trước
/// khi chuẩn hoá sang mã số lúc migrate).
const _posLabels = {0: 'dt', 1: 'đt', 2: 'tt', 3: 'trt', 4: 'gt'};

/// Chiều ngược lại của [_posLabels] — dùng khi lưu từ tra Online
/// ([VocabRepository.insertOnlineWord]), nơi UI chỉ có sẵn nhãn viết
/// tắt (từ `DictionaryApiService`/`VocabWord.partOfSpeech`), chưa có
/// mã số.
const _posCodeByLabel = {'dt': 0, 'đt': 1, 'tt': 2, 'trt': 3, 'gt': 4};

/// Truy vấn dữ liệu từ vựng (read-only) từ vocab.db.
class VocabRepository {
  VocabRepository(this._db);
  final Database _db;

  VocabWord _wordFromRow(Row r) {
    final source = r['source'] as int? ?? 0;
    return VocabWord(
      id: r['id'] as int,
      word: r['word'] as String? ?? '',
      phonetic: r['phonetic'] as String? ?? '',
      partOfSpeech: _posLabels[r['part_of_speech'] as int?] ?? '',
      meaningVi: r['meaning_vi'] as String? ?? '',
      chapterTitle: r['chapter_title'] as String? ?? '',
      imagePath: r['image_path'] as String?,
      isSubentry: (r['is_subentry'] as int? ?? 0) == 1,
      isManual: source == 2,
      // Theo TỪNG TỪ, không theo bộ chứa — source=0 (SEED) luôn khoá dù
      // nằm trong bộ nào; source=1 (ONLINE)/source=2 (MANUAL) luôn sửa/
      // xoá được kể cả khi đã thêm vào 1 bộ mặc định.
      isEditable: source != 0,
    );
  }

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
  ///
  /// [direction] BẮT BUỘC (không có mặc định đoán tự động) — user chủ
  /// động chọn qua dropdown ở [SearchScreen], chỉ so khớp đúng 1 cột
  /// theo đúng hướng đã chọn, tránh nhầm lẫn từ trùng cả 2 ngôn ngữ.
  List<VocabWord> search(
    String query, {
    required SearchDirection direction,
    int limit = 50,
  }) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    final like = '%$q%';
    final prefix = '$q%';

    final matchColumn = switch (direction) {
      SearchDirection.enToVi => 'w.word_lower LIKE ?',
      SearchDirection.viToEn => 'lower(w.meaning_vi) LIKE ?',
    };
    final matchParams = [like];

    final rows = _db.select(
      '''$_selectWord
         WHERE w.source != 2 AND $matchColumn
         ORDER BY
           CASE WHEN w.word_lower = ? THEN 0
                WHEN w.word_lower LIKE ? THEN 1 ELSE 2 END,
           length(w.word), w.word_lower
         LIMIT ?''',
      [...matchParams, q, prefix, limit],
    );
    return rows.map(_wordFromRow).toList();
  }

  /// Khớp CHÍNH XÁC (không phải `LIKE` gần đúng) 1 từ theo [direction] —
  /// dùng cho tự điền form thêm từ (SCR-07b "Tự điền từ dữ liệu") và dò
  /// trùng lặp lúc lưu, nơi điền/link nhầm dữ liệu của 1 từ khác gần
  /// giống là hành vi tệ hơn nhiều so với không tìm thấy gì. KHÔNG loại
  /// trừ `source=2` (MANUAL) như [search] — mục đích ở đây là chống tạo
  /// bản ghi trùng lặp (kể cả trùng với từ MANUAL user đã tự thêm trước
  /// đó), khác với Tra cứu giáo trình chỉ muốn thấy từ gốc. Trả về từ
  /// đầu tiên khớp (ưu tiên `sort_order`/`id` tăng dần) nếu có nhiều bản
  /// ghi trùng.
  VocabWord? findExactMatch(
    String query, {
    required SearchDirection direction,
  }) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return null;

    final matchColumn = switch (direction) {
      SearchDirection.enToVi => 'w.word_lower = ?',
      SearchDirection.viToEn => 'lower(w.meaning_vi) = ?',
    };

    final rows = _db.select(
      '''$_selectWord
         WHERE $matchColumn
         ORDER BY w.id
         LIMIT 1''',
      [q],
    );
    if (rows.isEmpty) return null;
    return _wordFromRow(rows.first);
  }

  /// Tra 1 từ theo id (dùng khi ghép dữ liệu ôn tập từ `user.db`).
  VocabWord? wordById(int id) {
    final rows = _db.select('$_selectWord WHERE w.id = ?', [id]);
    if (rows.isEmpty) return null;
    return _wordFromRow(rows.first);
  }

  /// Danh sách bộ từ điển giáo trình gốc — bỏ "Chưa phân loại" (id cố
  /// định = 1, luôn là dòng đầu tiên insert khi seed/migrate DB) vì màn
  /// "Học" hiện tại chỉ duyệt các bộ chuyên ngành, không có khái niệm
  /// từ mồ côi.
  List<Chapter> chapters() {
    final rows = _db.select('''
      SELECT d.id, d.sort_order, d.name,
             (SELECT COUNT(*) FROM word_dictionaries wd WHERE wd.dictionary_id = d.id) AS cnt
      FROM dictionaries d
      WHERE d.id != 1
      ORDER BY d.sort_order
    ''');
    return rows
        .map(
          (r) => Chapter(
            id: r['id'] as int,
            chapterNo: r['sort_order'] as int? ?? 0,
            title: r['name'] as String? ?? '',
            wordCount: r['cnt'] as int? ?? 0,
          ),
        )
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
        .map(
          (r) => WordExample(
            en: r['example_en'] as String? ?? '',
            vi: r['example_vi'] as String? ?? '',
          ),
        )
        .toList();
  }

  /// Danh sách Section (SCR-03) — chủ đề lớn của giáo trình, chứa các
  /// bài đọc (`ArticleChapter`). Xem `docs/db/schema.sql`.
  List<Section> sections() {
    final rows = _db.select(
      'SELECT id, name, sort_order FROM sections ORDER BY sort_order',
    );
    return rows
        .map(
          (r) => Section(
            id: r['id'] as int,
            name: r['name'] as String? ?? '',
            sortOrder: r['sort_order'] as int? ?? 0,
          ),
        )
        .toList();
  }

  /// Danh sách bài đọc (SCR-03b) của 1 Section.
  List<ArticleChapter> articleChaptersBySection(int sectionId) {
    final rows = _db.select(
      'SELECT id, section_id, title, sort_order, pdf_path FROM chapters WHERE section_id = ? ORDER BY sort_order',
      [sectionId],
    );
    return rows
        .map(
          (r) => ArticleChapter(
            id: r['id'] as int,
            sectionId: r['section_id'] as int,
            title: r['title'] as String? ?? '',
            sortOrder: r['sort_order'] as int? ?? 0,
            pdfPath: r['pdf_path'] as String?,
          ),
        )
        .toList();
  }

  /// 1 bài đọc đầy đủ (SCR-03c), kèm `pdf_path`.
  ArticleChapter? articleChapterById(int id) {
    final rows = _db.select(
      'SELECT id, section_id, title, sort_order, pdf_path FROM chapters WHERE id = ?',
      [id],
    );
    if (rows.isEmpty) return null;
    final r = rows.first;
    return ArticleChapter(
      id: r['id'] as int,
      sectionId: r['section_id'] as int,
      title: r['title'] as String? ?? '',
      sortOrder: r['sort_order'] as int? ?? 0,
      pdfPath: r['pdf_path'] as String?,
    );
  }

  /// Toàn bộ bộ từ điển (SCR-07, kể cả "Chưa phân loại") kèm danh sách
  /// `word_id` — dùng để ghép với `learned_words` ở `user.db` (2 file
  /// SQLite riêng, không JOIN được bằng SQL, phải ghép ở tầng Dart, xem
  /// [MyDictionariesRepository]).
  List<({int id, String name, bool isDefault, List<int> wordIds})>
  dictionariesWithWordIds() {
    final dictRows = _db.select(
      'SELECT id, name, is_default FROM dictionaries ORDER BY sort_order',
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
  List<String> randomDistractors(
    int wordId,
    int? dictionaryId, {
    int count = 3,
  }) {
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

  /// Tạo 1 bộ từ điển cá nhân mới (rỗng, `is_default=0` — xoá được) —
  /// SCR-07 nút "Tạo bộ mới". Xếp cuối danh sách (`sort_order` lớn nhất
  /// hiện có + 1).
  int createDictionary(String name) {
    final maxSortRow = _db
        .select('SELECT MAX(sort_order) AS m FROM dictionaries')
        .first;
    final nextSortOrder = (maxSortRow['m'] as int? ?? 0) + 1;
    final now = DateTime.now().millisecondsSinceEpoch;

    _db.execute(
      'INSERT INTO dictionaries (name, is_default, sort_order, created_at) VALUES (?, 0, ?, ?)',
      [name, nextSortOrder, now],
    );
    return _db.lastInsertRowId;
  }

  /// Xoá 1 bộ từ điển cá nhân (SCR-07, nút "Xoá bộ") — gọi từ UI đã
  /// kiểm tra `Dictionary.isDeletable` trước đó nên không lọc lại điều
  /// kiện này ở đây. Xoá luôn các từ CHỈ thuộc bộ này (không thuộc bộ
  /// nào khác) vì `word_dictionaries` yêu cầu mọi từ có >=1 bộ (xem
  /// `docs/db/schema.sql`) — hiện tại từ tự thêm luôn gán đúng 1 bộ lúc
  /// tạo ([insertManualWord]) nên trong thực tế xoá bộ = xoá sạch từ
  /// trong bộ đó. Trả về `word_id` của các từ đã xoá hẳn để tầng gọi
  /// dọn thêm `learned_words` bên `user.db` (2 file SQLite riêng,
  /// không xoá chéo được ở đây).
  List<int> deleteDictionary(int dictionaryId) {
    final orphanRows = _db.select(
      '''SELECT word_id FROM word_dictionaries WHERE dictionary_id = ?
         AND word_id NOT IN (
           SELECT word_id FROM word_dictionaries WHERE dictionary_id != ?
         )''',
      [dictionaryId, dictionaryId],
    );
    final orphanWordIds = orphanRows.map((r) => r['word_id'] as int).toList();

    _db.execute('DELETE FROM word_dictionaries WHERE dictionary_id = ?', [
      dictionaryId,
    ]);
    for (final wordId in orphanWordIds) {
      _db.execute('DELETE FROM examples WHERE word_id = ?', [wordId]);
      _db.execute('DELETE FROM words WHERE id = ?', [wordId]);
    }
    _db.execute('DELETE FROM dictionaries WHERE id = ?', [dictionaryId]);
    return orphanWordIds;
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
    String? exampleEn,
    String? exampleVi,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    _db.execute(
      '''INSERT INTO words (word, word_lower, phonetic, meaning_vi,
                             part_of_speech, is_subentry, image_path, source, created_at)
         VALUES (?, ?, ?, ?, ?, 0, ?, 2, ?)''',
      [
        word,
        word.toLowerCase(),
        phonetic,
        meaningVi,
        partOfSpeechCode,
        imagePath,
        now,
      ],
    );
    final wordId = _db.lastInsertRowId;

    _db.execute(
      'INSERT INTO word_dictionaries (word_id, dictionary_id, added_at) VALUES (?, ?, ?)',
      [wordId, dictionaryId, now],
    );

    if (exampleEn != null && exampleVi != null) {
      _db.execute(
        'INSERT INTO examples (word_id, example_en, example_vi) VALUES (?, ?, ?)',
        [wordId, exampleEn, exampleVi],
      );
    }
    return wordId;
  }

  /// `id` của từ tra Online (`source=1`) đã lưu khớp [word] (so khớp
  /// `word_lower`, không phân biệt hoa/thường), `null` nếu chưa từng
  /// lưu. Dùng để: (1) tích sẵn checkbox bộ đã chứa từ này khi mở lại
  /// modal "Thêm vào bộ" cho cùng 1 kết quả tra, (2) tránh
  /// [insertOnlineWord] tạo dòng `words` trùng lặp ở lần thêm sau.
  int? findOnlineWordId(String word) {
    final rows = _db.select(
      'SELECT id FROM words WHERE word_lower = ? AND source = 1',
      [word.trim().toLowerCase()],
    );
    if (rows.isEmpty) return null;
    return rows.first['id'] as int;
  }

  /// `dictionary_id` của các bộ đã chứa [wordId] — dùng để tích sẵn
  /// checkbox trong modal "Thêm vào bộ" (xem [findOnlineWordId]).
  List<int> dictionaryIdsContaining(int wordId) {
    final rows = _db.select(
      'SELECT dictionary_id FROM word_dictionaries WHERE word_id = ?',
      [wordId],
    );
    return rows.map((r) => r['dictionary_id'] as int).toList();
  }

  /// Lưu 1 từ tra được qua API ngoài (SCR-02 "Chế độ Online", `source=1`
  /// ONLINE_LOOKUP — khác `source=2` MANUAL của [insertManualWord]) vào
  /// 1 hoặc nhiều [dictionaryIds] cùng lúc (mockup `screen-04b`, checkbox
  /// chọn nhiều bộ). Không tự động lưu khi chỉ *tra* — chỉ gọi hàm này
  /// khi user chủ động bấm "Thêm vào bộ" (đã chốt Q-CSB-05, xem
  /// `02_Search.md`). [dictionaryIds] rỗng -> gán vào "Chưa phân loại"
  /// (id cố định = 1, nguyên tắc #2 trong `91_DB-design-new-model.md`).
  ///
  /// Nếu [word] đã từng được lưu qua đường này trước đó (xem
  /// [findOnlineWordId]), TÁI SỬ DỤNG dòng `words` cũ thay vì insert
  /// mới — tránh tạo bản ghi trùng lặp khi user thêm cùng 1 từ vào
  /// nhiều bộ ở các lần bấm khác nhau; chỉ những bộ CHƯA có từ này mới
  /// được thêm dòng `word_dictionaries` mới.
  int insertOnlineWord({
    required String word,
    required String meaningVi,
    required List<int> dictionaryIds,
    String? phonetic,
    String? partOfSpeech,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    final existingWordId = findOnlineWordId(word);

    final int wordId;
    if (existingWordId != null) {
      wordId = existingWordId;
    } else {
      final partOfSpeechCode = partOfSpeech == null
          ? null
          : _posCodeByLabel[partOfSpeech];
      _db.execute(
        '''INSERT INTO words (word, word_lower, phonetic, meaning_vi,
                               part_of_speech, is_subentry, image_path, source, created_at)
           VALUES (?, ?, ?, ?, ?, 0, NULL, 1, ?)''',
        [word, word.toLowerCase(), phonetic, meaningVi, partOfSpeechCode, now],
      );
      wordId = _db.lastInsertRowId;
    }

    final alreadyIn = existingWordId == null
        ? const <int>{}
        : dictionaryIdsContaining(existingWordId).toSet();
    final targetIds = dictionaryIds.isEmpty ? const [1] : dictionaryIds;
    for (final dictionaryId in targetIds) {
      if (alreadyIn.contains(dictionaryId)) continue;
      _db.execute(
        'INSERT INTO word_dictionaries (word_id, dictionary_id, added_at) VALUES (?, ?, ?)',
        [wordId, dictionaryId, now],
      );
    }
    return wordId;
  }

  /// Liên kết 1 từ ĐÃ CÓ SẴN (bất kỳ `source` nào — giáo trình gốc,
  /// online-lookup, hay tự thêm ở bộ khác) vào [dictionaryId], KHÔNG
  /// tạo dòng `words` mới — dùng khi form "Tự thêm từ mới" tự điền
  /// (SCR-07b) khớp trúng 1 từ đã tồn tại: liên kết tránh trùng lặp dữ
  /// liệu thay vì insert 1 bản ghi MANUAL riêng có cùng nội dung. Không
  /// làm gì nếu [wordId] đã có sẵn trong [dictionaryId] (idempotent).
  void linkWordToDictionary({required int wordId, required int dictionaryId}) {
    final alreadyIn = dictionaryIdsContaining(wordId).contains(dictionaryId);
    if (alreadyIn) return;
    _db.execute(
      'INSERT INTO word_dictionaries (word_id, dictionary_id, added_at) VALUES (?, ?, ?)',
      [wordId, dictionaryId, DateTime.now().millisecondsSinceEpoch],
    );
  }

  /// Sửa 1 từ trong bộ có thể sửa/xoá (SCR-07c "Sửa từ") — áp dụng cho
  /// `source=1` (ONLINE_LOOKUP) hoặc `source=2` (MANUAL). UI đã kiểm
  /// tra [DictionaryDetailScreen.isDictionaryDeletable] trước khi cho
  /// vào màn sửa (quyết định theo BỘ chứa từ, không phải nguồn gốc
  /// từng từ), nhưng vẫn chặn lại ở đây (`WHERE source != 0`) để từ
  /// giáo trình gốc (SEED) không thể bị sửa dù gọi từ đường nào — dữ
  /// liệu đó dùng chung cho Tra cứu, không phải của riêng user.
  void updateManualWord({
    required int wordId,
    required String word,
    required String meaningVi,
    String? phonetic,
    int? partOfSpeechCode,
    String? imagePath,
    String? exampleEn,
    String? exampleVi,
  }) {
    _assertNotSeedWord(wordId, action: 'sửa');
    _db.execute(
      '''UPDATE words SET word = ?, word_lower = ?, phonetic = ?, meaning_vi = ?,
                           part_of_speech = ?, image_path = ?
         WHERE id = ? AND source != 0''',
      [
        word,
        word.toLowerCase(),
        phonetic,
        meaningVi,
        partOfSpeechCode,
        imagePath,
        wordId,
      ],
    );

    // Form chỉ hỗ trợ đúng 1 cặp ví dụ EN/VI cho từ tự thêm -> xoá hết
    // dòng cũ rồi insert lại (thay vì UPDATE) để không phải phân biệt
    // "sửa dòng có sẵn" và "thêm dòng mới" ở đây.
    _db.execute('DELETE FROM examples WHERE word_id = ?', [wordId]);
    if (exampleEn != null && exampleVi != null) {
      _db.execute(
        'INSERT INTO examples (word_id, example_en, example_vi) VALUES (?, ?, ?)',
        [wordId, exampleEn, exampleVi],
      );
    }
  }

  /// Gỡ 1 từ khỏi ĐÚNG [dictionaryId] đang xem (SCR-07c "Xoá từ") — chỉ
  /// xoá hẳn dòng `words`/`examples` (kèm dọn bảng phụ thuộc thủ công,
  /// `VocabDatabase.open()` không bật `PRAGMA foreign_keys` nên `ON
  /// DELETE CASCADE` không tự chạy) NẾU đây là bộ CUỐI CÙNG còn tham
  /// chiếu từ đó. Một từ `source=1` (ONLINE_LOOKUP) có thể được lưu vào
  /// nhiều bộ cùng lúc (xem [insertOnlineWord]) — xoá ở 1 bộ không được
  /// làm mất từ đó ở các bộ khác đang dùng chung dòng `words`.
  ///
  /// Cho phép gỡ `source=0` (SEED) khỏi bộ TỰ TẠO — "xoá" ở đây chỉ gỡ
  /// liên kết khỏi 1 bộ, không xoá nội dung từ dùng chung, và từ SEED
  /// còn liên kết ở bộ giáo trình gốc nên không mất hẳn. Nhưng CHẶN nếu
  /// [dictionaryId] chính là bộ giáo trình gốc (`is_default=1`) — nếu
  /// đó là bộ mặc định duy nhất còn liên kết, gỡ ở đây sẽ khiến từ mất
  /// hẳn khỏi mọi danh sách (mồ côi trong `words`, `source != 0` chặn
  /// xoá hẳn dòng đó nhưng không cứu được liên kết đã mất) — phát hiện
  /// bug thật do user báo cáo, xem `docs/spec_history.md`.
  ///
  /// Trả về `true` nếu từ đã bị xoá HẲN (không còn bộ nào tham chiếu) —
  /// tầng gọi dùng giá trị này để quyết định có dọn `learned_words` ở
  /// `user.db` hay không (chỉ dọn khi từ thực sự không còn tồn tại ở
  /// bất kỳ bộ nào, xem `review_providers.dart` `deleteWord`).
  bool deleteWord(int wordId, {required int dictionaryId}) {
    _assertNotSeedWordInDefaultDictionary(wordId, dictionaryId: dictionaryId);

    _db.execute(
      'DELETE FROM word_dictionaries WHERE word_id = ? AND dictionary_id = ?',
      [wordId, dictionaryId],
    );

    final remaining = _db.select(
      'SELECT COUNT(*) AS cnt FROM word_dictionaries WHERE word_id = ?',
      [wordId],
    );
    final stillReferenced = (remaining.first['cnt'] as int? ?? 0) > 0;
    if (stillReferenced) return false;

    _db.execute('DELETE FROM examples WHERE word_id = ?', [wordId]);
    _db.execute('DELETE FROM words WHERE id = ? AND source != 0', [wordId]);
    return true;
  }

  /// Chặn sửa/xoá từ giáo trình gốc (`source=0` SEED) — bảo vệ dữ liệu
  /// dùng chung dù lời gọi có bỏ qua kiểm tra [VocabWord.isEditable] ở
  /// tầng UI hay không. Từ `source=1`/`source=2` luôn được phép sửa/xoá
  /// (sửa luôn đồng bộ mọi bộ chứa từ đó; xoá chỉ gỡ khỏi 1 bộ, xem
  /// [deleteWord]).
  void _assertNotSeedWord(int wordId, {required String action}) {
    final rows = _db.select('SELECT source FROM words WHERE id = ?', [wordId]);
    if (rows.isEmpty) return;
    final source = rows.first['source'] as int? ?? 0;
    if (source == 0) {
      throw StateError(
        'Không thể $action từ mặc định (id=$wordId, source=$source).',
      );
    }
  }

  /// Chặn gỡ 1 từ SEED (`source=0`) khỏi chính bộ giáo trình gốc
  /// (`dictionaries.is_default=1`) — nếu đó là bộ mặc định duy nhất còn
  /// liên kết, gỡ sẽ khiến từ mất hẳn khỏi mọi danh sách hiển thị dù
  /// dòng `words` vẫn còn (mồ côi, không thuộc bộ nào). Vẫn cho phép gỡ
  /// SEED khỏi bộ TỰ TẠO (`is_default=0`) như thiết kế ban đầu.
  void _assertNotSeedWordInDefaultDictionary(
    int wordId, {
    required int dictionaryId,
  }) {
    final wordRows = _db.select(
      'SELECT source FROM words WHERE id = ?',
      [wordId],
    );
    if (wordRows.isEmpty) return;
    final source = wordRows.first['source'] as int? ?? 0;
    if (source != 0) return;

    final dictRows = _db.select(
      'SELECT is_default FROM dictionaries WHERE id = ?',
      [dictionaryId],
    );
    if (dictRows.isEmpty) return;
    final isDefault = (dictRows.first['is_default'] as int? ?? 0) == 1;
    if (isDefault) {
      throw StateError(
        'Không thể xoá từ giáo trình gốc (id=$wordId) khỏi bộ mặc định '
        '(dictionaryId=$dictionaryId).',
      );
    }
  }
}
