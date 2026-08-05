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

  /// Chuẩn bị 1 phiên ôn tập khách quan từ hàng đợi đến hạn: cắt tối đa
  /// 4 từ (không độn thêm nếu hàng đợi ít hơn), random 50/50 kiểu câu
  /// hỏi (trắc nghiệm/gõ chữ) cho mỗi từ. Xem `docs/csb-vocab-analysis/
  /// tasks/02-review-multi-mode/03-plan.md` (BE-05, OQ-4).
  List<ReviewQuestion> buildSession(List<DueReviewItem> dueItems);
}
