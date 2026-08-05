import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/dictionary.dart';
import '../../domain/entities/section.dart';
import '../../domain/entities/word.dart';
import '../local/vocab_database.dart';
import 'vocab_repository.dart';

/// Mở DB một lần, tự đóng khi provider bị hủy.
final vocabDbProvider = FutureProvider<VocabDatabase>((ref) async {
  final db = await VocabDatabase.open();
  ref.onDispose(db.dispose);
  return db;
});

final vocabRepositoryProvider = FutureProvider<VocabRepository>((ref) async {
  final db = await ref.watch(vocabDbProvider.future);
  return VocabRepository(db.raw);
});

/// Kết quả tra cứu theo từ khóa (FR-2).
final searchProvider =
    FutureProvider.family<List<VocabWord>, String>((ref, query) async {
  if (query.trim().isEmpty) return const [];
  final repo = await ref.watch(vocabRepositoryProvider.future);
  return repo.search(query);
});

/// Danh sách chương (FR-3).
final chaptersProvider = FutureProvider<List<Chapter>>((ref) async {
  final repo = await ref.watch(vocabRepositoryProvider.future);
  return repo.chapters();
});

/// Từ trong một chương (FR-3).
final chapterWordsProvider =
    FutureProvider.family<List<VocabWord>, int>((ref, chapterId) async {
  final repo = await ref.watch(vocabRepositoryProvider.future);
  return repo.wordsByChapter(chapterId);
});

/// Ví dụ của một từ (nạp khi mở chi tiết).
final wordExamplesProvider =
    FutureProvider.family<List<WordExample>, int>((ref, wordId) async {
  final repo = await ref.watch(vocabRepositoryProvider.future);
  return repo.examplesFor(wordId);
});

/// Danh sách Section (SCR-03).
final sectionsProvider = FutureProvider<List<Section>>((ref) async {
  final repo = await ref.watch(vocabRepositoryProvider.future);
  return repo.sections();
});

/// Danh sách bài đọc (Chapter dạng bài báo) của 1 Section (SCR-03b).
final articleChaptersProvider =
    FutureProvider.family<List<ArticleChapter>, int>((ref, sectionId) async {
  final repo = await ref.watch(vocabRepositoryProvider.future);
  return repo.articleChaptersBySection(sectionId);
});

/// 1 bài đọc đầy đủ, kèm nội dung Markdown (SCR-03c).
final articleChapterProvider =
    FutureProvider.family<ArticleChapter?, int>((ref, chapterId) async {
  final repo = await ref.watch(vocabRepositoryProvider.future);
  return repo.articleChapterById(chapterId);
});
