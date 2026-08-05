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
  final List<WordExample> examples;
}
