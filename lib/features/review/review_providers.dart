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

/// Từ [wordId] đã được đánh dấu học chưa (hiển thị trạng thái nút).
final learnedStatusProvider =
    FutureProvider.family<bool, int>((ref, wordId) async {
  final repo = await ref.watch(reviewRepositoryProvider.future);
  return repo.isLearned(wordId);
});

/// Đánh dấu 1 từ đã học và làm mới các provider phụ thuộc.
Future<void> markWordLearned(WidgetRef ref, int wordId) async {
  final repo = await ref.read(reviewRepositoryProvider.future);
  await repo.markLearned(wordId);
  ref.invalidate(learnedStatusProvider(wordId));
  ref.invalidate(dueReviewsProvider);
  ref.invalidate(dueReviewCountProvider);
}

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

/// Ghi nhận 1 lượt ôn và làm mới hàng đợi + badge.
Future<void> submitWordReview(
  WidgetRef ref,
  int wordId,
  ReviewRating rating,
) async {
  final repo = await ref.read(reviewRepositoryProvider.future);
  await repo.submitReview(wordId, rating);
  ref.invalidate(dueReviewsProvider);
  ref.invalidate(dueReviewCountProvider);
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
