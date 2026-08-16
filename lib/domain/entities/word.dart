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
    this.isEditable = false,
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
  /// `VocabRepository.insertManualWord`).
  final bool isManual;

  /// `true` nếu từ này cho phép sửa/xoá trong [DictionaryDetailScreen]
  /// — theo TỪNG TỪ (`source != 0`), không theo bộ chứa nó: từ giáo
  /// trình gốc (`source=0` SEED) luôn khoá dù nằm trong bộ nào; từ tự
  /// thêm (`source=2`) hoặc lưu qua Tra Online (`source=1`) luôn sửa/
  /// xoá được, kể cả khi đã thêm vào 1 bộ mặc định (bộ mặc định chỉ
  /// khoá xoá CẢ BỘ, không khoá riêng từ user tự thêm vào đó).
  final bool isEditable;

  /// `true` nếu đây là kết quả tra qua API ngoài (MyMemory, xem
  /// `DictionaryApiService`), CHƯA có trong `words` — `id` là
  /// [onlineWordSentinelId], không dùng được với provider nào truy vấn
  /// theo id thật (`wordExamplesProvider`, `learnedStatusProvider`...).
  /// UI hiện badge "Online" và ẩn các hành động chỉ áp dụng cho từ đã
  /// lưu (đánh dấu đã học, xem ví dụ) — thay bằng nút "Thêm vào bộ".
  final bool isOnline;
  final List<WordExample> examples;
}

/// Chiều tra cứu ở màn Search (SCR-02) — user BẮT BUỘC chọn thủ công
/// qua dropdown (không có lựa chọn "Tự động" đoán bằng ký tự tiếng
/// Việt — dễ đoán sai với từ mượn/tên riêng không dấu, và người dùng
/// luôn biết rõ mình đang gõ tiếng gì hơn app đoán). Ảnh hưởng cả tra
/// cứu local (`VocabRepository.search`, chỉ so khớp đúng 1 cột) lẫn
/// tra Online (`DictionaryApiService.lookup`, quyết định hướng dịch
/// gọi MyMemory + có tra thêm Free Dictionary API cho phiên âm/loại từ
/// hay không).
enum SearchDirection {
  enToVi(label: 'Anh → Việt'),
  viToEn(label: 'Việt → Anh');

  const SearchDirection({required this.label});
  final String label;
}
