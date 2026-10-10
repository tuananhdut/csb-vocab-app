import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/dictionary.dart';
import '../../domain/entities/section.dart';
import '../../domain/entities/translation_direction.dart';
import '../../domain/entities/word.dart';
import '../local/vocab_database.dart';
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
final chapterWordsProvider = FutureProvider.family<List<VocabWord>, int>((
  ref,
  chapterId,
) async {
  final repo = await ref.watch(vocabRepositoryProvider.future);
  return repo.wordsByChapter(chapterId);
});

/// Tra CHÍNH XÁC 1 từ/cụm Anh trong từ điển giáo trình (không phải tìm
/// gần đúng như [chapterWordsProvider]) — dùng cho dịch nhanh từ chọn
/// trong PDF (`lessons_screen.dart`): nếu từ đã có sẵn trong giáo trình
/// thì ưu tiên lấy nghĩa đã biên soạn thay vì gọi máy dịch ngoài.
final exactWordLookupProvider = FutureProvider.family<VocabWord?, String>((
  ref,
  text,
) async {
  final repo = await ref.watch(vocabRepositoryProvider.future);
  return repo.findExactMatch(text, direction: SearchDirection.enToVi);
});

/// Same exact-match lookup as [exactWordLookupProvider] but for the
/// Translate tab, where the direction can be flipped: Vietnamese input
/// matches `meaning_vi`, so the dictionary entry can still win over the
/// machine translator.
final exactTranslateLookupProvider =
    FutureProvider.family<VocabWord?, (TranslationDirection, String)>((ref, args) async {
  final (direction, text) = args;
  final repo = await ref.watch(vocabRepositoryProvider.future);
  return repo.findExactMatch(
    text,
    direction: direction == TranslationDirection.viToEn
        ? SearchDirection.viToEn
        : SearchDirection.enToVi,
  );
});

/// Các từ đồng nghĩa (cùng `meaning_vi`) của 1 từ — key là
/// `(wordId, meaningVi)` vì [VocabRepository.synonymsOf] cần cả 2 (loại
/// trừ chính nó + so khớp nghĩa), xem ghi chú tại đó.
final synonymsProvider =
    FutureProvider.family<List<VocabWord>, (int, String)>((ref, args) async {
      final (wordId, meaningVi) = args;
      final repo = await ref.watch(vocabRepositoryProvider.future);
      return repo.synonymsOf(meaningVi, excludeWordId: wordId);
    });

/// Ví dụ của một từ (nạp khi mở chi tiết).
final wordExamplesProvider = FutureProvider.family<List<WordExample>, int>((
  ref,
  wordId,
) async {
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
final articleChapterProvider = FutureProvider.family<ArticleChapter?, int>((
  ref,
  chapterId,
) async {
  final repo = await ref.watch(vocabRepositoryProvider.future);
  return repo.articleChapterById(chapterId);
});
