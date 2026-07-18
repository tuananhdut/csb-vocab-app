import '../entities/review.dart';

/// Interface cho dữ liệu ôn tập (FR-5) — impl cụ thể ở `data/repositories`.
abstract class ReviewRepository {
  /// Đánh dấu 1 từ là đã học, thêm vào hàng đợi ôn tập (nếu chưa có).
  Future<void> markLearned(int wordId);

  Future<bool> isLearned(int wordId);

  /// Ghi nhận 1 lượt ôn và tính lại lịch ôn tiếp theo theo SM-2.
  Future<void> submitReview(int wordId, ReviewRating rating);

  /// Các từ đến hạn ôn tính đến cuối ngày hôm nay, sắp theo hạn ôn gần nhất.
  Future<List<DueReviewItem>> dueToday();

  Future<int> dueCount();
}
