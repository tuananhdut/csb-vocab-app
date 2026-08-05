import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/user_database.dart';
import '../../data/repositories/my_dictionaries_repository.dart';
import '../../data/repositories/review_repository.dart';
import '../../data/repositories/vocab_providers.dart';
import '../../domain/entities/dictionary.dart';
import '../../domain/entities/review.dart';
import '../../domain/entities/word.dart';
import '../../domain/repositories/review_repository.dart' as domain;
import '../../domain/srs/srs_scheduler.dart';

/// Mở `user.db` một lần, tự đóng khi provider bị hủy.
final userDbProvider = FutureProvider<UserDatabase>((ref) async {
  final db = await UserDatabase.open();
  ref.onDispose(db.dispose);
  return db;
});

final reviewRepositoryProvider = FutureProvider<domain.ReviewRepository>(
  (ref) async {
    final userDb = await ref.watch(userDbProvider.future);
    final vocabRepo = await ref.watch(vocabRepositoryProvider.future);
    return SqliteReviewRepository(userDb.raw, vocabRepo, const SrsScheduler());
  },
);

/// Hàng đợi "ôn hôm nay" (FR-5.2).
final dueReviewsProvider = FutureProvider<List<DueReviewItem>>((ref) async {
  final repo = await ref.watch(reviewRepositoryProvider.future);
  return repo.dueToday();
});

/// Số từ cần ôn hôm nay — dùng cho badge trên màn chính.
final dueReviewCountProvider = FutureProvider<int>((ref) async {
  final repo = await ref.watch(reviewRepositoryProvider.future);
  return repo.dueCount();
});

/// Hàng đợi "ôn hôm nay" CHỈ tính từ thuộc 1 bộ từ điển — dùng cho nút
/// "Ôn tập" trên từng card ở SCR-07 (thay cho hàng đợi due chung).
final dueReviewsForDictionaryProvider =
    FutureProvider.family<List<DueReviewItem>, int>((ref, dictionaryId) async {
  final repo = await ref.watch(reviewRepositoryProvider.future);
  return repo.dueTodayForDictionary(dictionaryId);
});

/// Danh sách bộ từ điển kèm số liệu ôn tập (SCR-07 "Từ điển của tôi") —
/// ghép `vocab.db` (dictionaries) với `user.db` (learned_words), xem
/// [MyDictionariesRepository].
final myDictionariesProvider = FutureProvider<List<Dictionary>>((ref) async {
  final vocabRepo = await ref.watch(vocabRepositoryProvider.future);
  final userDb = await ref.watch(userDbProvider.future);
  return MyDictionariesRepository(vocabRepo, userDb.raw).dictionaries();
});

/// Tối đa 4 từ chưa học của 1 bộ — dùng cho phiên "Học từ mới".
final newWordsToLearnProvider =
    FutureProvider.family<List<VocabWord>, int>((ref, dictionaryId) async {
  final vocabRepo = await ref.watch(vocabRepositoryProvider.future);
  final userDb = await ref.watch(userDbProvider.future);
  return MyDictionariesRepository(vocabRepo, userDb.raw).newWordsToLearn(dictionaryId);
});

/// Đánh dấu nhiều từ đã học cùng lúc (phiên "Học từ mới") — làm mới các
/// provider phụ thuộc sau khi xong.
Future<void> markWordsLearnedBatch(WidgetRef ref, List<int> wordIds) async {
  final repo = await ref.read(reviewRepositoryProvider.future);
  for (final wordId in wordIds) {
    await repo.markLearned(wordId);
  }
  ref.invalidate(dueReviewsProvider);
  ref.invalidate(dueReviewCountProvider);
  ref.invalidate(myDictionariesProvider);
  ref.invalidate(newWordsToLearnProvider);
}

/// Câu hỏi trắc nghiệm củng cố ngay cho [words] — dùng trong phiên "Học
/// từ mới" sau khi xem overview từng cặp từ (xem
/// [MyDictionariesRepository.multipleChoiceQuestionsFor]).
Future<List<ReviewQuestion>> buildQuickQuiz(WidgetRef ref, List<VocabWord> words) async {
  final vocabRepo = await ref.read(vocabRepositoryProvider.future);
  final userDb = await ref.read(userDbProvider.future);
  return MyDictionariesRepository(vocabRepo, userDb.raw).multipleChoiceQuestionsFor(words);
}

/// Ghi nhận 1 lượt ôn và làm mới hàng đợi + badge. Truyền [dictionaryId]
/// khi phiên ôn đang mở từ 1 bộ cụ thể (SCR-07) để làm mới đúng hàng đợi
/// riêng của bộ đó ([dueReviewsForDictionaryProvider]).
Future<void> submitWordReview(
  WidgetRef ref,
  int wordId,
  ReviewRating rating, {
  int? dictionaryId,
}) async {
  final repo = await ref.read(reviewRepositoryProvider.future);
  await repo.submitReview(wordId, rating);
  ref.invalidate(dueReviewsProvider);
  ref.invalidate(dueReviewCountProvider);
  if (dictionaryId != null) ref.invalidate(dueReviewsForDictionaryProvider(dictionaryId));
}

/// Chuẩn bị phiên ôn tập khách quan (tối đa 4 câu, trộn 50/50 trắc
/// nghiệm/gõ chữ) từ hàng đợi đến hạn — xem
/// `docs/csb-vocab-analysis/tasks/02-review-multi-mode/03-plan.md`.
Future<List<ReviewQuestion>> buildReviewSession(
  WidgetRef ref,
  List<DueReviewItem> dueItems,
) async {
  final repo = await ref.read(reviewRepositoryProvider.future);
  return repo.buildSession(dueItems);
}

/// Tạo 1 bộ từ điển cá nhân mới (SCR-07, nút "Tạo bộ mới") và làm mới
/// danh sách bộ.
Future<void> createDictionary(WidgetRef ref, String name) async {
  final vocabRepo = await ref.read(vocabRepositoryProvider.future);
  vocabRepo.createDictionary(name);
  ref.invalidate(myDictionariesProvider);
}

/// Xoá 1 bộ từ điển cá nhân (SCR-07, nút "Xoá bộ") — dọn luôn trạng
/// thái ôn tập ở `user.db` cho các từ bị xoá hẳn theo bộ rồi làm mới
/// danh sách bộ.
Future<void> deleteDictionary(WidgetRef ref, int dictionaryId) async {
  final vocabRepo = await ref.read(vocabRepositoryProvider.future);
  final userDb = await ref.read(userDbProvider.future);
  final deletedWordIds = vocabRepo.deleteDictionary(dictionaryId);
  for (final wordId in deletedWordIds) {
    userDb.raw.execute('DELETE FROM learned_words WHERE word_id = ?', [wordId]);
  }
  ref.invalidate(myDictionariesProvider);
}

/// Thêm 1 từ tự nhập tay vào [dictionaryId] (SCR-07b "Tự thêm từ mới")
/// và làm mới danh sách bộ (đổi `wordCount`).
Future<void> addManualWord(
  WidgetRef ref, {
  required String word,
  required String meaningVi,
  required int dictionaryId,
  String? phonetic,
  int? partOfSpeechCode,
  String? imagePath,
}) async {
  final vocabRepo = await ref.read(vocabRepositoryProvider.future);
  vocabRepo.insertManualWord(
    word: word,
    meaningVi: meaningVi,
    dictionaryId: dictionaryId,
    phonetic: (phonetic == null || phonetic.trim().isEmpty) ? null : phonetic.trim(),
    partOfSpeechCode: partOfSpeechCode,
    imagePath: imagePath,
  );
  ref.invalidate(myDictionariesProvider);
}

/// Sửa 1 từ tự thêm (SCR-07c) và làm mới danh sách từ + bộ (đổi
/// `word`/`meaningVi` hiển thị trên card).
Future<void> editWord(
  WidgetRef ref, {
  required int wordId,
  required int dictionaryId,
  required String word,
  required String meaningVi,
  String? phonetic,
  int? partOfSpeechCode,
  String? imagePath,
}) async {
  final vocabRepo = await ref.read(vocabRepositoryProvider.future);
  vocabRepo.updateManualWord(
    wordId: wordId,
    word: word,
    meaningVi: meaningVi,
    phonetic: (phonetic == null || phonetic.trim().isEmpty) ? null : phonetic.trim(),
    partOfSpeechCode: partOfSpeechCode,
    imagePath: imagePath,
  );
  ref.invalidate(chapterWordsProvider(dictionaryId));
  ref.invalidate(myDictionariesProvider);
}

/// Xoá 1 từ tự thêm (SCR-07c) khỏi bộ [dictionaryId] — dọn luôn trạng
/// thái ôn tập ở `user.db` (nếu từ đã từng được đánh dấu học) rồi làm
/// mới danh sách từ + bộ.
Future<void> deleteWord(WidgetRef ref, {required int wordId, required int dictionaryId}) async {
  final vocabRepo = await ref.read(vocabRepositoryProvider.future);
  final userDb = await ref.read(userDbProvider.future);
  vocabRepo.deleteWord(wordId);
  userDb.raw.execute('DELETE FROM learned_words WHERE word_id = ?', [wordId]);
  ref.invalidate(chapterWordsProvider(dictionaryId));
  ref.invalidate(myDictionariesProvider);
}
