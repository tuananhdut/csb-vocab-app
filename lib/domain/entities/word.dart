// Các thực thể miền cho từ vựng (đọc từ vocab.db).

class WordExample {
  const WordExample({required this.en, required this.vi});
  final String en;
  final String vi;
}

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
  final List<WordExample> examples;
}
