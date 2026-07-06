import 'dart:math' as math;

import '../entities/review.dart';

/// Thuật toán lặp lại ngắt quãng SM-2 (đã chốt D1 = Phương án A, xem
/// plan 04-thiet-ke-du-lieu.md mục 3). Thuần Dart, không phụ thuộc
/// Flutter/DB nên dễ unit test độc lập.
class SrsScheduler {
  const SrsScheduler();

  /// Tính trạng thái SRS mới sau khi người dùng đánh giá 1 lượt ôn.
  /// [now] cho phép truyền giờ cố định khi test; mặc định là hiện tại.
  SrsCardState review(SrsCardState card, ReviewRating rating, {DateTime? now}) {
    final q = rating.quality;
    var repetitions = card.repetitions;
    var interval = card.intervalDays;

    if (q < 3) {
      repetitions = 0;
      interval = 1;
    } else {
      if (repetitions == 0) {
        interval = 1;
      } else if (repetitions == 1) {
        interval = 6;
      } else {
        interval = (interval * card.easeFactor).round();
      }
      repetitions += 1;
    }

    final easeFactor = math.max(
      1.3,
      card.easeFactor + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02)),
    );

    final today = now ?? DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);
    final dueDate = todayMidnight.add(Duration(days: interval));

    return card.copyWith(
      repetitions: repetitions,
      intervalDays: interval,
      easeFactor: easeFactor,
      dueDate: dueDate,
      lastReviewed: today,
    );
  }
}
