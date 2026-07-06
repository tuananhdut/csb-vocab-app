import 'package:sqlite3/sqlite3.dart';

import '../../domain/entities/review.dart';
import '../../domain/repositories/review_repository.dart' as domain;
import '../../domain/srs/srs_scheduler.dart';
import 'vocab_repository.dart';

/// Implementation SQLite của [domain.ReviewRepository], dùng `user.db`
/// (bảng learned_words, review_logs) ghép với `vocab.db` qua [VocabRepository].
class SqliteReviewRepository implements domain.ReviewRepository {
  SqliteReviewRepository(this._userDb, this._vocabRepository, this._scheduler);

  final Database _userDb;
  final VocabRepository _vocabRepository;
  final SrsScheduler _scheduler;

  SrsCardState _stateFromRow(Row r) => SrsCardState(
        wordId: r['word_id'] as int,
        isLearned: (r['is_learned'] as int? ?? 0) == 1,
        easeFactor: (r['ease_factor'] as num? ?? 2.5).toDouble(),
        intervalDays: r['interval_days'] as int? ?? 0,
        repetitions: r['repetitions'] as int? ?? 0,
        dueDate: _fromMillis(r['due_date'] as int?),
        lastReviewed: _fromMillis(r['last_reviewed'] as int?),
      );

  static DateTime? _fromMillis(int? millis) =>
      millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);

  @override
  Future<void> markLearned(int wordId) async {
    final today = DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);
    _userDb.execute(
      '''INSERT INTO learned_words (word_id, is_learned, due_date)
         VALUES (?, 1, ?)
         ON CONFLICT(word_id) DO UPDATE SET is_learned = 1''',
      [wordId, todayMidnight.millisecondsSinceEpoch],
    );
  }

  @override
  Future<bool> isLearned(int wordId) async {
    final rows = _userDb.select(
      'SELECT is_learned FROM learned_words WHERE word_id = ?',
      [wordId],
    );
    if (rows.isEmpty) return false;
    return (rows.first['is_learned'] as int? ?? 0) == 1;
  }

  @override
  Future<void> submitReview(int wordId, ReviewRating rating) async {
    final rows = _userDb.select(
      'SELECT * FROM learned_words WHERE word_id = ?',
      [wordId],
    );
    if (rows.isEmpty) return;

    final current = _stateFromRow(rows.first);
    final updated = _scheduler.review(current, rating);

    _userDb.execute(
      '''UPDATE learned_words
         SET ease_factor = ?, interval_days = ?, repetitions = ?,
             due_date = ?, last_reviewed = ?
         WHERE word_id = ?''',
      [
        updated.easeFactor,
        updated.intervalDays,
        updated.repetitions,
        updated.dueDate?.millisecondsSinceEpoch,
        updated.lastReviewed?.millisecondsSinceEpoch,
        wordId,
      ],
    );
    _userDb.execute(
      'INSERT INTO review_logs (word_id, reviewed_at, rating) VALUES (?, ?, ?)',
      [wordId, DateTime.now().millisecondsSinceEpoch, rating.quality],
    );
  }

  int _endOfTodayMillis() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day, 23, 59, 59, 999)
        .millisecondsSinceEpoch;
  }

  @override
  Future<List<DueReviewItem>> dueToday() async {
    final rows = _userDb.select(
      '''SELECT * FROM learned_words
         WHERE is_learned = 1 AND due_date <= ?
         ORDER BY due_date ASC''',
      [_endOfTodayMillis()],
    );
    final items = <DueReviewItem>[];
    for (final row in rows) {
      final state = _stateFromRow(row);
      final word = _vocabRepository.wordById(state.wordId);
      if (word != null) items.add(DueReviewItem(word: word, state: state));
    }
    return items;
  }

  @override
  Future<int> dueCount() async {
    final rows = _userDb.select(
      'SELECT COUNT(*) AS cnt FROM learned_words WHERE is_learned = 1 AND due_date <= ?',
      [_endOfTodayMillis()],
    );
    return rows.first['cnt'] as int? ?? 0;
  }
}
