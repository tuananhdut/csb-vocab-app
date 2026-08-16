import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/dictionary.dart';
import '../../domain/entities/section.dart';
import '../../domain/entities/word.dart';
import '../local/vocab_database.dart';
import '../services/connectivity_service.dart';
import '../services/dictionary_api_service.dart';
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

final dictionaryApiServiceProvider = Provider<DictionaryApiService>((ref) {
  return DictionaryApiService();
});

/// Kết quả tra cứu theo từ khóa (FR-2) — offline trước (`vocab.db`
/// local), rồi bổ sung 1 kết quả Online (MyMemory, xem
/// `DictionaryApiService`) ở CUỐI danh sách nếu: có mạng, query không
/// rỗng, và không có từ nào trong kết quả local khớp *chính xác* query
/// (tránh trùng lặp — chỉ bổ sung khi local thực sự chưa có, không
/// phải mọi lần tìm kiếm đều tốn quota API). Lỗi/timeout khi gọi Online
/// chỉ ghi log (`DictionaryApiService._translate`), không chặn kết quả
/// local hiển thị bình thường (Q-CSB-06 — fallback êm).
final searchProvider =
    FutureProvider.family<List<VocabWord>, String>((ref, query) async {
  final trimmedQuery = query.trim();
  if (trimmedQuery.isEmpty) return const [];

  final repo = await ref.watch(vocabRepositoryProvider.future);
  final localResults = repo.search(query);

  final hasExactMatch = localResults.any(
    (w) => w.word.toLowerCase() == trimmedQuery.toLowerCase() ||
        w.meaningVi.toLowerCase() == trimmedQuery.toLowerCase(),
  );
  final isOnline = ref.watch(connectivityProvider).value ?? false;
  if (hasExactMatch || !isOnline) return localResults;

  final apiService = ref.watch(dictionaryApiServiceProvider);
  final onlineResult = await apiService.lookup(trimmedQuery);
  if (onlineResult == null) return localResults;

  return [
    ...localResults,
    VocabWord(
      id: onlineWordSentinelId,
      word: onlineResult.word,
      phonetic: '',
      partOfSpeech: '',
      meaningVi: onlineResult.meaningVi,
      chapterTitle: '',
      isOnline: true,
    ),
  ];
});

/// Các bộ đã chứa 1 từ tra Online theo tên (so khớp `word_lower`) —
/// dùng để tích sẵn checkbox khi mở lại modal "Thêm vào bộ" cho cùng 1
/// kết quả tra (xem `VocabRepository.findOnlineWordId`).
final onlineWordDictionaryIdsProvider =
    FutureProvider.family<List<int>, String>((ref, word) async {
  final repo = await ref.watch(vocabRepositoryProvider.future);
  final wordId = repo.findOnlineWordId(word);
  if (wordId == null) return const [];
  return repo.dictionaryIdsContaining(wordId);
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
