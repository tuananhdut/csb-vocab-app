// Các thực thể miền cho ôn tập từ vựng (SM-2, FR-5).

import 'word.dart';

/// Mức đánh giá trí nhớ khi ôn 1 từ (theo thang SM-2 gốc: q = 0..5).
/// Từ khi đổi sang câu hỏi khách quan (trắc nghiệm/gõ chữ, xem
/// `docs/csb-vocab-analysis/tasks/02-review-multi-mode/`), hệ thống tự
/// chấm sai → `forgot`; đúng → `good` hoặc `easy` tuỳ đã đúng liên tiếp
/// ổn định qua nhiều phiên hay chưa (xem `_stableStreakThreshold` ở
/// `SqliteReviewRepository.submitReview`) — `hard` giữ lại trong enum
/// (không xoá) vì không ảnh hưởng hành vi hiện tại, chỉ đơn giản không
/// còn đường gọi tới.
enum ReviewRating {
  forgot(1, 'Quên'),
  hard(3, 'Khó'),
  good(4, 'Tốt'),
  easy(5, 'Dễ');

  const ReviewRating(this.quality, this.label);

  /// Giá trị q truyền vào công thức SM-2.
  final int quality;
  final String label;
}

/// Kiểu câu hỏi trong 1 phiên ôn tập khách quan — chỉ dùng ở runtime để
/// UI biết render đúng dạng, KHÔNG có cột DB tương ứng (đã chốt không
/// thêm `review_logs.question_mode`, xem OQ-6 ở `01-analysis.md`).
enum QuestionMode { multipleChoice, typing }

/// 1 câu hỏi đã "chuẩn bị sẵn" cho phiên ôn — [choices] có 4 phần tử
/// (1 đúng + 3 nhiễu, đã xáo trộn vị trí) khi [mode] là
/// [QuestionMode.multipleChoice], `null` khi [QuestionMode.typing].
class ReviewQuestion {
  const ReviewQuestion({required this.word, required this.mode, this.choices});

  final VocabWord word;
  final QuestionMode mode;
  final List<String>? choices;
}

/// Trạng thái SRS của một từ đã đánh dấu học (bảng `learned_words`).
class SrsCardState {
  const SrsCardState({
    required this.wordId,
    this.isLearned = true,
    this.easeFactor = 2.5,
    this.intervalDays = 0,
    this.repetitions = 0,
    this.dueDate,
    this.lastReviewed,
  });

  final int wordId;
  final bool isLearned;
  final double easeFactor;
  final int intervalDays;
  final int repetitions;
  final DateTime? dueDate;
  final DateTime? lastReviewed;

  SrsCardState copyWith({
    bool? isLearned,
    double? easeFactor,
    int? intervalDays,
    int? repetitions,
    DateTime? dueDate,
    DateTime? lastReviewed,
  }) {
    return SrsCardState(
      wordId: wordId,
      isLearned: isLearned ?? this.isLearned,
      easeFactor: easeFactor ?? this.easeFactor,
      intervalDays: intervalDays ?? this.intervalDays,
      repetitions: repetitions ?? this.repetitions,
      dueDate: dueDate ?? this.dueDate,
      lastReviewed: lastReviewed ?? this.lastReviewed,
    );
  }
}

/// Một mục trong hàng đợi "ôn hôm nay": ghép từ vựng + trạng thái SRS.
class DueReviewItem {
  const DueReviewItem({required this.word, required this.state});

  final VocabWord word;
  final SrsCardState state;
}
