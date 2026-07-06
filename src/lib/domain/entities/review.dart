// Các thực thể miền cho ôn tập từ vựng (SM-2, FR-5).

import 'vocab.dart';

/// Mức đánh giá trí nhớ khi ôn 1 từ (theo thang SM-2 gốc: q = 0..5).
/// Dùng 4 nút theo plan 04: Quên / Khó / Tốt / Dễ.
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
