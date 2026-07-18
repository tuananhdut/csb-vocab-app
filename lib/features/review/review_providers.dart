import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/local/user_database.dart';
import '../../data/repositories/review_repository.dart';
import '../../data/repositories/vocab_providers.dart';
import '../../domain/entities/review.dart';
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
