import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/vocab_providers.dart';
import '../../domain/entities/vocab.dart';
import '../vocab/word_widgets.dart';

/// FR-3 — Học theo chương: danh sách chương (chuyên ngành).
class LessonsScreen extends ConsumerWidget {
  const LessonsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chapters = ref.watch(chaptersProvider);
    return chapters.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Lỗi: $e')),
      data: (list) => ListView.separated(
        itemCount: list.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final ch = list[i];
          return ListTile(
            leading: CircleAvatar(child: Text('${ch.chapterNo}')),
            title: Text(ch.title),
            subtitle: Text('${ch.wordCount} từ'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ChapterWordsScreen(chapter: ch)),
            ),
          );
        },
      ),
    );
  }
}

/// Danh sách từ trong một chương.
class ChapterWordsScreen extends ConsumerWidget {
  const ChapterWordsScreen({super.key, required this.chapter});
  final Chapter chapter;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final words = ref.watch(chapterWordsProvider(chapter.id));
    return Scaffold(
      appBar: AppBar(title: Text(chapter.title)),
      body: words.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (list) => ListView.separated(
          itemCount: list.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (_, i) => WordTile(word: list[i]),
        ),
      ),
    );
  }
}
