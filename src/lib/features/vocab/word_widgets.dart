import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/vocab_providers.dart';
import '../../domain/entities/vocab.dart';

/// Dòng hiển thị 1 từ trong danh sách (tra cứu / bài học).
class WordTile extends StatelessWidget {
  const WordTile({super.key, required this.word, this.showChapter = false});

  final VocabWord word;
  final bool showChapter;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Flexible(
            child: Text(word.word,
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          if (word.phonetic.isNotEmpty) ...[
            const SizedBox(width: 8),
            Flexible(
              child: Text(word.phonetic,
                  style: TextStyle(color: scheme.primary, fontSize: 13)),
            ),
          ],
        ],
      ),
      subtitle: Text(
        [
          if (word.partOfSpeech.isNotEmpty) '(${word.partOfSpeech})',
          word.meaningVi,
        ].join(' '),
      ),
      trailing: showChapter && word.chapterTitle.isNotEmpty
          ? Text(word.chapterTitle,
              style: TextStyle(fontSize: 11, color: scheme.outline))
          : null,
      onTap: () => showWordDetail(context, word),
    );
  }
}

/// Mở chi tiết từ dạng bottom sheet (kèm ví dụ, nạp theo id).
void showWordDetail(BuildContext context, VocabWord word) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => WordDetailSheet(word: word),
  );
}

class WordDetailSheet extends ConsumerWidget {
  const WordDetailSheet({super.key, required this.word});
  final VocabWord word;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final examples = ref.watch(wordExamplesProvider(word.id));

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (context, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Text(word.word,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          if (word.phonetic.isNotEmpty)
            Text(word.phonetic,
                style: TextStyle(color: scheme.primary, fontSize: 16)),
          const SizedBox(height: 12),
          if (word.partOfSpeech.isNotEmpty)
            Chip(
              label: Text(word.partOfSpeech),
              visualDensity: VisualDensity.compact,
            ),
          const SizedBox(height: 8),
          Text('Nghĩa', style: Theme.of(context).textTheme.labelLarge),
          Text(word.meaningVi,
              style: Theme.of(context).textTheme.bodyLarge),
          if (word.chapterTitle.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.menu_book, size: 16, color: scheme.outline),
              const SizedBox(width: 6),
              Text(word.chapterTitle,
                  style: TextStyle(color: scheme.outline)),
            ]),
          ],
          const SizedBox(height: 16),
          examples.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Lỗi tải ví dụ: $e'),
            data: (list) {
              if (list.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ví dụ', style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 4),
                  for (final ex in list)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (ex.en.isNotEmpty)
                            Text(ex.en,
                                style: const TextStyle(
                                    fontStyle: FontStyle.italic)),
                          if (ex.vi.isNotEmpty)
                            Text(ex.vi,
                                style: TextStyle(color: scheme.outline)),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
