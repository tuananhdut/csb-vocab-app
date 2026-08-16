import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/entities/review.dart';
import '../../domain/srs/srs_scheduler.dart';
import 'review_providers.dart';
import 'review_session_screen.dart';

/// Số ngày trễ hạn kể từ khi coi 1 từ là "tồn đọng lâu" — chỉ dùng để
/// hiển thị cảnh báo, không ảnh hưởng `ORDER BY`/lịch ôn SM-2 (giống
/// [isDifficult], xem `srs_scheduler.dart`).
const _overdueWarningDays = 7;

int _daysOverdue(DueReviewItem item, DateTime now) {
  final due = item.state.dueDate;
  if (due == null) return 0;
  final today = DateTime(now.year, now.month, now.day);
  final dueDay = DateTime(due.year, due.month, due.day);
  return today.difference(dueDay).inDays;
}

/// FR-5 — Ôn tập từ vựng: hàng đợi "ôn hôm nay" theo thuật toán SM-2.
///
/// Truyền [dictionaryId] để chỉ ôn từ thuộc 1 bộ từ điển cụ thể (SCR-07,
/// nút "Ôn tập" trên từng card) — bỏ trống thì dùng hàng đợi due chung
/// (toàn bộ từ đã học, không phân biệt bộ).
class ReviewScreen extends ConsumerWidget {
  const ReviewScreen({super.key, this.dictionaryId});

  final int? dictionaryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final due = dictionaryId == null
        ? ref.watch(dueReviewsProvider)
        : ref.watch(dueReviewsForDictionaryProvider(dictionaryId!));

    return due.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Lỗi: $e')),
      data: (items) => items.isEmpty
          ? const _EmptyDue()
          : _DueQueue(items: items, dictionaryId: dictionaryId),
    );
  }
}

class _EmptyDue extends StatelessWidget {
  const _EmptyDue();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.task_alt, size: 72, color: scheme.primary),
            const SizedBox(height: 16),
            Text('Không có từ cần ôn hôm nay',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              'Đánh dấu "Đã học" ở màn Tra cứu / Học để thêm từ vào hàng đợi ôn tập.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: scheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _DueQueue extends ConsumerWidget {
  const _DueQueue({required this.items, this.dictionaryId});
  final List<DueReviewItem> items;
  final int? dictionaryId;

  Future<void> _startSession(BuildContext context, WidgetRef ref) async {
    final questions = await buildReviewSession(ref, items);
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReviewSessionScreen(questions: questions, dictionaryId: dictionaryId),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final overdueCount =
        items.where((item) => _daysOverdue(item, now) >= _overdueWarningDays).length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Có ${items.length} từ cần ôn hôm nay',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              FilledButton.icon(
                onPressed: () => _startSession(context, ref),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Bắt đầu ôn tập'),
              ),
            ],
          ),
        ),
        if (overdueCount > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: _OverdueBanner(count: overdueCount),
          ),
        Expanded(
          child: ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final item = items[i];
              final daysOverdue = _daysOverdue(item, now);
              return ListTile(
                title: Text(item.word.word,
                    style: Theme.of(context).textTheme.bodyLarge),
                subtitle: Text(item.word.meaningVi),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (daysOverdue >= _overdueWarningDays) ...[
                      Chip(
                        label: Text('Trễ ${daysOverdue}d'),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: AppColors.signalRed.withValues(alpha: 0.12),
                        labelStyle: const TextStyle(color: AppColors.signalRed),
                      ),
                      const SizedBox(width: 6),
                    ],
                    if (isDifficult(item.state))
                      Chip(
                        label: const Text('Từ khó'),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: Theme.of(context).colorScheme.errorContainer,
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Cảnh báo khi có từ trễ hạn ôn từ [_overdueWarningDays] ngày trở lên —
/// hàng đợi due chỉ hiện tổng số chung, không tự nổi bật phần tồn đọng
/// lâu ngày nên dễ bị bỏ sót nếu người dùng không mở app thường xuyên.
class _OverdueBanner extends StatelessWidget {
  const _OverdueBanner({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.signalRed.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.signalRed.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: AppColors.signalRed, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$count từ đã trễ hạn ôn từ $_overdueWarningDays ngày trở lên',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.signalRed, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
