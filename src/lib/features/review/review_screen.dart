import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/review.dart';
import 'review_providers.dart';
import 'review_session_screen.dart';

/// FR-5 — Ôn tập từ vựng: hàng đợi "ôn hôm nay" theo thuật toán SM-2.
class ReviewScreen extends ConsumerWidget {
  const ReviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final due = ref.watch(dueReviewsProvider);

    return due.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Lỗi: $e')),
      data: (items) =>
          items.isEmpty ? const _EmptyDue() : _DueQueue(items: items),
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
              style: TextStyle(color: scheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}

class _DueQueue extends StatelessWidget {
  const _DueQueue({required this.items});
  final List<DueReviewItem> items;

  @override
  Widget build(BuildContext context) {
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
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ReviewSessionScreen(items: items),
                  ),
                ),
                icon: const Icon(Icons.play_arrow),
                label: const Text('Bắt đầu ôn tập'),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final item = items[i];
              return ListTile(
                title: Text(item.word.word,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(item.word.meaningVi),
              );
            },
          ),
        ),
      ],
    );
  }
}
