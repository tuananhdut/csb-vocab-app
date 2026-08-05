import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/entities/dictionary.dart';
import '../review/review_providers.dart';
import '../review/review_screen.dart';
import 'learn_new_words_screen.dart';

/// SCR-07 — Từ điển của tôi: danh sách bộ từ điển (mặc định + cá nhân)
/// dạng card, kèm số liệu tổng/đã học/đến hạn ôn theo từng bộ.
///
/// Xem docs/artifact-design/screens/screen-07-tu-dien-cua-toi.html. Phạm
/// vi hiện tại: chỉ danh sách bộ — "Xem" (chi tiết bộ, SCR-07c), "Ôn tập
/// ngay" (phiên ôn theo bộ, SCR-07d/e/f) và "Tạo bộ mới" (SCR-07b) chưa
/// implement, để dành phase sau.
class MyDictionariesScreen extends ConsumerWidget {
  const MyDictionariesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dictionaries = ref.watch(myDictionariesProvider);
    return dictionaries.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Lỗi: $e')),
      data: (list) => LayoutBuilder(
        builder: (context, constraints) {
          final crossAxisCount = (constraints.maxWidth / 280).floor().clamp(1, 4);
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              mainAxisExtent: 208,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: list.length,
            itemBuilder: (_, i) => _DictionaryCard(dictionary: list[i]),
          );
        },
      ),
    );
  }
}

const _cardColors = [
  AppColors.brand,
  AppColors.snapDeep,
  AppColors.teal,
  AppColors.seaBlue,
  AppColors.brandDeep,
  AppColors.signalRed,
];

class _DictionaryCard extends ConsumerWidget {
  const _DictionaryCard({required this.dictionary});
  final Dictionary dictionary;

  Future<void> _startLearningNewWords(BuildContext context, WidgetRef ref) async {
    final words = await ref.read(newWordsToLearnProvider(dictionary.id).future);
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LearnNewWordsScreen(dictionaryId: dictionary.id, words: words),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final color = _cardColors[dictionary.id % _cardColors.length];
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: dictionary.isDefault ? color.withValues(alpha: 0.4) : AppColors.border,
          style: dictionary.isDefault ? BorderStyle.solid : BorderStyle.solid,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(width: 4, height: 18, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    dictionary.name,
                    style: Theme.of(context).textTheme.bodyLarge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text('${dictionary.wordCount} từ', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.check_circle_outline, size: 14, color: Theme.of(context).colorScheme.outline),
                const SizedBox(width: 4),
                Text('${dictionary.learnedCount} đã học', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(width: 12),
                Icon(Icons.radar, size: 14, color: Theme.of(context).colorScheme.outline),
                const SizedBox(width: 4),
                Text('${dictionary.dueCount} đến hạn', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const Spacer(),
            if (!dictionary.isDeletable)
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.border),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text('Mặc định · không thể xoá', style: Theme.of(context).textTheme.labelSmall),
                ),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: dictionary.newWordsCount > 0
                    ? () => _startLearningNewWords(context, ref)
                    : null,
                icon: const Icon(Icons.auto_stories_outlined, size: 16),
                label: Text('Học từ mới (${dictionary.newWordsCount})'),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    // Mo thang ReviewScreen toan cuc (hang doi due chung,
                    // KHONG loc theo bo nay) - phien on theo tung bo
                    // (SCR-07d/e/f) chua implement, xem module doc.
                    onPressed: dictionary.dueCount > 0
                        ? () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => Scaffold(
                                  appBar: AppBar(title: const Text('Ôn tập')),
                                  body: const ReviewScreen(),
                                ),
                              ),
                            )
                        : null,
                    icon: const Icon(Icons.radar, size: 16),
                    label: Text('Ôn tập (${dictionary.dueCount})'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Chi tiết bộ từ điển chưa implement.')),
                  ),
                  child: const Text('Xem'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
