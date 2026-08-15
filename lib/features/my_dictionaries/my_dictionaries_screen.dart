import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../domain/entities/dictionary.dart';
import '../review/review_providers.dart';
import '../review/review_screen.dart';
import 'add_word_screen.dart';
import 'dictionary_detail_screen.dart';
import 'learn_new_words_screen.dart';

/// SCR-07 — Từ điển của tôi: danh sách bộ từ điển (mặc định + cá nhân)
/// dạng card, kèm số liệu tổng/đã học/đến hạn ôn theo từng bộ.
///
/// Xem docs/artifact-design/screens/screen-07-tu-dien-cua-toi.html.
/// Nút "Ôn tập" mở [ReviewScreen] đã lọc theo đúng [Dictionary.id] của
/// card (SCR-07d/e/f) — chỉ ôn từ thuộc bộ đó, xem
/// [dueReviewsForDictionaryProvider].
class MyDictionariesScreen extends ConsumerWidget {
  const MyDictionariesScreen({super.key});

  Future<void> _createDictionary(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tạo bộ từ điển mới'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Tên bộ từ điển'),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Tạo'),
          ),
        ],
      ),
    );

    final trimmedName = name?.trim();
    if (trimmedName == null || trimmedName.isEmpty) return;
    await createDictionary(ref, trimmedName);
  }

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
              mainAxisExtent: 256,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: list.length + 1,
            itemBuilder: (_, i) => i < list.length
                ? _DictionaryCard(dictionary: list[i])
                : _NewDictionaryCard(onTap: () => _createDictionary(context, ref)),
          );
        },
      ),
    );
  }
}

/// Thẻ "+ Tạo bộ mới" ở cuối lưới (khớp `.new-deck-card` trong mockup).
class _NewDictionaryCard extends StatelessWidget {
  const _NewDictionaryCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: AppColors.border, style: BorderStyle.solid),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_circle_outline, size: 32, color: scheme.outline),
              const SizedBox(height: 8),
              Text('Tạo bộ mới', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: scheme.outline)),
            ],
          ),
        ),
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

  Future<void> _addWord(BuildContext context, WidgetRef ref) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddWordScreen(dictionaryId: dictionary.id, dictionaryName: dictionary.name),
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xoá bộ từ điển này?'),
        content: Text(
          'Bộ "${dictionary.name}" cùng toàn bộ ${dictionary.wordCount} từ bên trong sẽ bị xoá. '
          'Hành động này không thể hoàn tác.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Huỷ'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.signalRed),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await deleteDictionary(ref, dictionary.id);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Đã xoá bộ "${dictionary.name}".')),
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
                if (dictionary.isDeletable)
                  PopupMenuButton<_DictionaryCardAction>(
                    icon: Icon(Icons.more_vert, size: 18, color: Theme.of(context).colorScheme.outline),
                    tooltip: 'Tuỳ chọn',
                    padding: EdgeInsets.zero,
                    onSelected: (action) {
                      switch (action) {
                        case _DictionaryCardAction.addWord:
                          _addWord(context, ref);
                        case _DictionaryCardAction.delete:
                          _delete(context, ref);
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: _DictionaryCardAction.addWord,
                        child: ListTile(
                          leading: Icon(Icons.add),
                          title: Text('Thêm từ mới'),
                          contentPadding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      PopupMenuItem(
                        value: _DictionaryCardAction.delete,
                        child: ListTile(
                          leading: Icon(Icons.delete_outline, color: AppColors.signalRed),
                          title: Text('Xoá bộ', style: TextStyle(color: AppColors.signalRed)),
                          contentPadding: EdgeInsets.zero,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                    ],
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
                    onPressed: dictionary.dueCount > 0
                        ? () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => Scaffold(
                                  appBar: AppBar(title: Text('Ôn tập · ${dictionary.name}')),
                                  body: ReviewScreen(dictionaryId: dictionary.id),
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
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DictionaryDetailScreen(
                        dictionaryId: dictionary.id,
                        dictionaryName: dictionary.name,
                      ),
                    ),
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

enum _DictionaryCardAction { addWord, delete }
