import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../data/repositories/vocab_providers.dart';
import '../../data/services/tts_service.dart';
import '../../domain/entities/vocab.dart';
import '../review/review_providers.dart';

/// Nhãn loại từ (dt/đt/tt...) kiểu viền bo góc nhỏ, monospace — khớp
/// `.pos-tag` trong mockup (`docs/artifact-design-windows/styles.css`).
class PosTag extends StatelessWidget {
  const PosTag(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) {
    const color = AppColors.brand;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      margin: const EdgeInsets.only(right: 4),
      decoration: BoxDecoration(
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: AppFonts.mono,
          fontSize: 10,
          color: color,
        ),
      ),
    );
  }
}

/// Dòng hiển thị 1 từ trong danh sách (tra cứu / bài học).
///
/// [onTap] mặc định mở [WordDetailSheet] (bottom sheet) — truyền tuỳ chỉnh
/// để đổi hành vi (vd: chọn dòng hiển thị inline trên layout desktop 2 cột).
/// [selected] tô viền trái + nền nhạt khi dòng đang được chọn (khớp
/// `.word-row.selected` trong mockup Windows) — chỉ có ý nghĩa ở layout
/// desktop 2 cột, mobile (mở bottom sheet) không truyền.
class WordTile extends StatelessWidget {
  const WordTile({
    super.key,
    required this.word,
    this.showChapter = false,
    this.onTap,
    this.selected = false,
  });

  final VocabWord word;
  final bool showChapter;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const ipaColor = AppColors.brand;

    return Container(
      decoration: BoxDecoration(
        color: selected ? AppColors.brand.withValues(alpha: 0.06) : null,
        border: Border(
          left: BorderSide(
            color: selected ? AppColors.brand : Colors.transparent,
            width: 3,
          ),
        ),
      ),
      child: InkWell(
        onTap: onTap ?? () => showWordDetail(context, word),
        hoverColor: AppColors.pageBg,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 3,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Flexible(
                    child: Text(
                      word.word,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15.5,
                      ),
                    ),
                  ),
                  if (word.phonetic.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        word.phonetic,
                        style: TextStyle(
                          fontFamily: AppFonts.mono,
                          color: ipaColor,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              Row(
                children: [
                  if (word.partOfSpeech.isNotEmpty) PosTag(word.partOfSpeech),
                  Expanded(
                    child: Text(
                      word.meaningVi,
                      style: TextStyle(color: scheme.outline, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (showChapter && word.chapterTitle.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 96),
                      child: Text(
                        word.chapterTitle,
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        softWrap: false,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: scheme.outline.withValues(alpha: 0.7),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
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

class WordDetailSheet extends StatelessWidget {
  const WordDetailSheet({super.key, required this.word});
  final VocabWord word;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (context, controller) => WordDetailContent(
        word: word,
        scrollController: controller,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      ),
    );
  }
}

/// Nội dung chi tiết 1 từ (tiêu đề, phiên âm, nghĩa, ví dụ, nút hành động)
/// — dùng chung cho [WordDetailSheet] (mobile, bọc trong bottom sheet) và
/// pane chi tiết inline trên layout desktop 2 cột.
class WordDetailContent extends ConsumerWidget {
  const WordDetailContent({
    super.key,
    required this.word,
    this.scrollController,
    this.padding = const EdgeInsets.all(20),
  });

  final VocabWord word;
  final ScrollController? scrollController;
  final EdgeInsets padding;

  static const _labelStyle = TextStyle(
    fontSize: 11.5,
    fontWeight: FontWeight.bold,
    letterSpacing: 0.6,
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    const ipaColor = AppColors.brand;
    const accentColor = AppColors.brand;
    final examples = ref.watch(wordExamplesProvider(word.id));
    final learned = ref.watch(learnedStatusProvider(word.id));

    return ListView(
      controller: scrollController,
      padding: padding,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            OutlinedButton.icon(
              onPressed: null,
              icon: const Icon(Icons.playlist_add, size: 16),
              label: const Text('Add to deck'),
              style: OutlinedButton.styleFrom(
                foregroundColor: accentColor,
                side: BorderSide(color: accentColor, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(width: 10),
            learned.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(8),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              error: (_, _) => const SizedBox.shrink(),
              data: (isLearned) => FilledButton.icon(
                onPressed:
                    isLearned ? null : () => markWordLearned(ref, word.id),
                icon: Icon(isLearned
                    ? Icons.check_circle
                    : Icons.bookmark_add_outlined),
                label: Text(isLearned ? 'Learned' : 'Mark as learned'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.brandDeep,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                word.word,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 32,
                ),
              ),
            ),
            if (word.partOfSpeech.isNotEmpty) PosTag(word.partOfSpeech),
          ],
        ),
        if (word.phonetic.isNotEmpty) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                word.phonetic,
                style: TextStyle(
                  fontFamily: AppFonts.mono,
                  fontSize: 15,
                  color: ipaColor,
                ),
              ),
              const SizedBox(width: 8),
              Text('UK',
                  style: TextStyle(color: scheme.outline, fontSize: 12)),
              const SizedBox(width: 6),
              IconButton(
                onPressed: () => TtsService.instance.speak(word.word),
                icon: const Icon(Icons.volume_up_outlined, size: 20),
                color: ipaColor,
                visualDensity: VisualDensity.compact,
                tooltip: 'Phát âm',
              ),
            ],
          ),
        ],
        const SizedBox(height: 20),
        Row(
          children: [
            Icon(Icons.translate, size: 14, color: scheme.outline),
            const SizedBox(width: 6),
            Text('NGHĨA TIẾNG VIỆT',
                style: _labelStyle.copyWith(color: scheme.outline)),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.panel2,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(word.meaningVi,
              style: const TextStyle(fontSize: 18, height: 1.4)),
        ),
        if (word.chapterTitle.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(children: [
            Icon(Icons.menu_book, size: 15, color: scheme.outline),
            const SizedBox(width: 6),
            Text(word.chapterTitle,
                style: TextStyle(color: scheme.outline, fontSize: 13)),
          ]),
        ],
        const SizedBox(height: 20),
        examples.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Lỗi tải ví dụ: $e'),
          data: (list) {
            if (list.isEmpty) return const SizedBox.shrink();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.format_quote, size: 14, color: scheme.outline),
                    const SizedBox(width: 6),
                    Text('VÍ DỤ THỰC TẾ',
                        style: _labelStyle.copyWith(color: scheme.outline)),
                  ],
                ),
                const SizedBox(height: 10),
                for (final ex in list)
                  Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.panel2,
                      border: Border(
                        left: BorderSide(color: AppColors.brand, width: 3),
                      ),
                      borderRadius: const BorderRadius.horizontal(
                        right: Radius.circular(6),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (ex.en.isNotEmpty)
                          Text(ex.en,
                              style: const TextStyle(
                                  fontStyle: FontStyle.italic,
                                  fontSize: 14.5)),
                        if (ex.vi.isNotEmpty)
                          Text(ex.vi,
                              style: TextStyle(
                                  color: scheme.outline, fontSize: 13.5)),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
