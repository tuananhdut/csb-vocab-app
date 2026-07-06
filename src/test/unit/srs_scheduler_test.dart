// Unit test thuật toán SM-2 (plan 04-thiet-ke-du-lieu.md mục 3).

import 'package:flutter_test/flutter_test.dart';

import 'package:csb_vocab_app/domain/entities/review.dart';
import 'package:csb_vocab_app/domain/srs/srs_scheduler.dart';

void main() {
  const scheduler = SrsScheduler();
  final now = DateTime(2026, 1, 10, 9);

  SrsCardState newCard() => const SrsCardState(wordId: 1);

  group('interval theo số lần lặp', () {
    test('lần ôn đầu tiên (repetitions=0) -> interval=1', () {
      final result = scheduler.review(newCard(), ReviewRating.good, now: now);
      expect(result.repetitions, 1);
      expect(result.intervalDays, 1);
      expect(result.dueDate, DateTime(2026, 1, 11));
    });

    test('lần ôn thứ 2 (repetitions=1) -> interval=6', () {
      final card = newCard().copyWith(repetitions: 1, intervalDays: 1);
      final result = scheduler.review(card, ReviewRating.good, now: now);
      expect(result.repetitions, 2);
      expect(result.intervalDays, 6);
    });

    test('lần ôn thứ 3+ -> interval = round(interval * easeFactor)', () {
      final card = newCard()
          .copyWith(repetitions: 2, intervalDays: 6, easeFactor: 2.5);
      final result = scheduler.review(card, ReviewRating.good, now: now);
      expect(result.repetitions, 3);
      expect(result.intervalDays, 15); // round(6 * 2.5)
    });
  });

  group('quên (q<3) reset tiến độ', () {
    test('repetitions về 0, interval về 1 dù đang ở lần lặp cao', () {
      final card = newCard()
          .copyWith(repetitions: 5, intervalDays: 30, easeFactor: 2.5);
      final result = scheduler.review(card, ReviewRating.forgot, now: now);
      expect(result.repetitions, 0);
      expect(result.intervalDays, 1);
    });
  });

  group('ease factor', () {
    test('Dễ (q=5) tăng ease thêm 0.1', () {
      final card = newCard().copyWith(easeFactor: 2.5);
      final result = scheduler.review(card, ReviewRating.easy, now: now);
      expect(result.easeFactor, closeTo(2.6, 1e-9));
    });

    test('Tốt (q=4) giữ nguyên ease', () {
      final card = newCard().copyWith(easeFactor: 2.5);
      final result = scheduler.review(card, ReviewRating.good, now: now);
      expect(result.easeFactor, closeTo(2.5, 1e-9));
    });

    test('Khó (q=3) giảm ease', () {
      final card = newCard().copyWith(easeFactor: 2.5);
      final result = scheduler.review(card, ReviewRating.hard, now: now);
      expect(result.easeFactor, closeTo(2.36, 1e-9));
    });

    test('Quên (q=1) giảm ease mạnh', () {
      final card = newCard().copyWith(easeFactor: 2.5);
      final result = scheduler.review(card, ReviewRating.forgot, now: now);
      expect(result.easeFactor, closeTo(1.96, 1e-9));
    });

    test('ease factor không xuống dưới 1.3', () {
      var card = newCard().copyWith(easeFactor: 1.35);
      final result = scheduler.review(card, ReviewRating.forgot, now: now);
      expect(result.easeFactor, greaterThanOrEqualTo(1.3));
      expect(result.easeFactor, closeTo(1.3, 1e-9));
    });
  });

  test('lastReviewed = thời điểm ôn', () {
    final result = scheduler.review(newCard(), ReviewRating.good, now: now);
    expect(result.lastReviewed, now);
  });
}
