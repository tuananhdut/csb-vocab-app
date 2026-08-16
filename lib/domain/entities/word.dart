// Các thực thể miền cho từ vựng (đọc từ vocab.db).

class WordExample {
  const WordExample({required this.en, required this.vi});
  final String en;
  final String vi;
}

/// `id` sentinel cho kết quả tra Online (chưa lưu vào `words`, xem
/// [VocabWord.isOnline]) — không trùng bất kỳ `id` thật nào vì
/// `INTEGER PRIMARY KEY AUTOINCREMENT` của SQLite luôn > 0.
const onlineWordSentinelId = -1;

class VocabWord {
  const VocabWord({
    required this.id,
    required this.word,
    required this.phonetic,
    required this.partOfSpeech,
    required this.meaningVi,
    required this.chapterTitle,
    this.imagePath,
    this.isSubentry = false,
    this.isManual = false,
    this.isOnline = false,
    this.examples = const [],
  });

  final int id;
  final String word;
  final String phonetic;
  final String partOfSpeech;
  final String meaningVi;
  final String chapterTitle;
  final String? imagePath;
  final bool isSubentry;

  /// `true` nếu từ do người dùng tự thêm (`source=2`, xem
  /// `VocabRepository.insertManualWord`) — chỉ những từ này mới cho
  /// sửa/xoá trong [DictionaryDetailScreen], từ có sẵn trong giáo trình
  /// gốc là dữ liệu chung, không cho chỉnh sửa.
  final bool isManual;

  /// `true` nếu đây là kết quả tra qua API ngoài (MyMemory, xem
  /// `DictionaryApiService`), CHƯA có trong `words` — `id` là
  /// [onlineWordSentinelId], không dùng được với provider nào truy vấn
  /// theo id thật (`wordExamplesProvider`, `learnedStatusProvider`...).
  /// UI hiện badge "Online" và ẩn các hành động chỉ áp dụng cho từ đã
  /// lưu (đánh dấu đã học, xem ví dụ) — thay bằng nút "Thêm vào bộ".
  final bool isOnline;
  final List<WordExample> examples;
}
