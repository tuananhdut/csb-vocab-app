import 'dart:math';

import 'package:sqlite3/sqlite3.dart';

import '../../domain/entities/dictionary.dart';
import '../../domain/entities/review.dart';
import '../../domain/entities/word.dart';
import 'vocab_repository.dart';

/// Ghép bộ từ điển (`vocab.db`) với trạng thái học (`learned_words` ở
/// `user.db`) cho SCR-07 "Từ điển của tôi" — 2 file SQLite riêng, không
/// JOIN được bằng SQL nên đếm ở tầng Dart theo tập `word_id`.
class MyDictionariesRepository {
  MyDictionariesRepository(this._vocabRepository, this._userDb);

  final VocabRepository _vocabRepository;
  final Database _userDb;

  List<Dictionary> dictionaries() {
    final rows = _vocabRepository.dictionariesWithWordIds();
    final endOfToday = _endOfTodayMillis();

    return rows.map((r) {
      if (r.wordIds.isEmpty) {
        return Dictionary(
          id: r.id,
          name: r.name,
          isDefault: r.isDefault,
          isDeletable: r.isDeletable,
          wordCount: 0,
          learnedCount: 0,
          dueCount: 0,
          newWordsCount: 0,
        );
      }

      final placeholders = List.filled(r.wordIds.length, '?').join(',');
      final learnedRows = _userDb.select(
        '''SELECT COUNT(*) AS cnt FROM learned_words
           WHERE is_learned = 1 AND word_id IN ($placeholders)''',
        r.wordIds,
      );
      final dueRows = _userDb.select(
        '''SELECT COUNT(*) AS cnt FROM learned_words
           WHERE is_learned = 1 AND due_date <= ? AND word_id IN ($placeholders)''',
        [endOfToday, ...r.wordIds],
      );
      final learnedCount = learnedRows.first['cnt'] as int? ?? 0;

      return Dictionary(
        id: r.id,
        name: r.name,
        isDefault: r.isDefault,
        isDeletable: r.isDeletable,
        wordCount: r.wordIds.length,
        learnedCount: learnedCount,
        dueCount: dueRows.first['cnt'] as int? ?? 0,
        newWordsCount: r.wordIds.length - learnedCount,
      );
    }).toList();
  }

  /// [count] từ đầu tiên của bộ [dictionaryId] mà người dùng CHƯA học
  /// (không có trong `learned_words`), kèm ví dụ — dùng cho phiên "Học
  /// từ mới" (thẻ giới thiệu từ/nghĩa/phiên âm/ví dụ).
  List<VocabWord> newWordsToLearn(int dictionaryId, {int count = 4}) {
    final allWords = _vocabRepository.wordsByChapter(dictionaryId);
    if (allWords.isEmpty) return const [];

    final wordIds = allWords.map((w) => w.id).toList();
    final placeholders = List.filled(wordIds.length, '?').join(',');
    final learnedRows = _userDb.select(
      'SELECT word_id FROM learned_words WHERE word_id IN ($placeholders)',
      wordIds,
    );
    final learnedIds = learnedRows.map((r) => r['word_id'] as int).toSet();

    final selected = allWords.where((w) => !learnedIds.contains(w.id)).take(count);
    return selected
        .map((w) => VocabWord(
              id: w.id,
              word: w.word,
              phonetic: w.phonetic,
              partOfSpeech: w.partOfSpeech,
              meaningVi: w.meaningVi,
              chapterTitle: w.chapterTitle,
              imagePath: w.imagePath,
              isSubentry: w.isSubentry,
              examples: _vocabRepository.examplesFor(w.id),
            ))
        .toList();
  }

  /// Câu hỏi trắc nghiệm củng cố ngay cho [words] (khớp nghĩa tiếng
  /// Việt) — dùng trong phiên "Học từ mới" sau khi xem overview từng
  /// cặp từ, tái dùng đúng cơ chế đáp án nhiễu của
  /// [VocabRepository.randomDistractors].
  List<ReviewQuestion> multipleChoiceQuestionsFor(List<VocabWord> words) {
    final random = Random();
    return words.map((word) {
      final dictionaryId = _vocabRepository.primaryDictionaryId(word.id);
      final distractors = _vocabRepository.randomDistractors(word.id, dictionaryId);
      final choices = [word.meaningVi, ...distractors]..shuffle(random);
      return ReviewQuestion(word: word, mode: QuestionMode.multipleChoice, choices: choices);
    }).toList();
  }

  int _endOfTodayMillis() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 23, 59, 59, 999)
        .millisecondsSinceEpoch;
  }
}
