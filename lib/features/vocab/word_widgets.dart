import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/vocab_providers.dart';
import '../../data/services/tts_service.dart';
import '../../domain/entities/word.dart';
import 'add_to_dictionary_sheet.dart';

/// Ảnh minh hoạ 1 từ vựng — tự nhận diện nguồn: [imagePath] tuyệt đối
/// (từ tự thêm, ảnh do user upload, xem `AddWordScreen`) dùng
/// [Image.file]; đường dẫn tương đối `assets/...` (từ có sẵn trong
/// giáo trình) dùng [Image.asset]; `null`/lỗi -> [AppConstants.defaultWordImage].
///
/// Mặc định ép `width: double.infinity` (lấp đầy chiều ngang, dùng
/// [fit] để crop/scale) — phù hợp ảnh minh hoạ nhỏ trong thẻ ôn tập.
/// Truyền [naturalSize] = true để bỏ ép kích thước, hiện ảnh đúng tỉ lệ
/// gốc (chỉ giới hạn `height` tối đa), dùng ở màn chi tiết từ
/// ([WordDetailContent]) nơi không muốn ảnh bị crop.
class WordImage extends StatelessWidget {
  const WordImage({
    super.key,
    required this.imagePath,
    required this.height,
    this.fit = BoxFit.contain,
    this.naturalSize = false,
  });

  final String? imagePath;
  final double height;
  final BoxFit fit;
  final bool naturalSize;

  bool get _isAbsoluteFile => imagePath != null && p.isAbsolute(imagePath!);

  @override
  Widget build(BuildContext context) {
    final width = naturalSize ? null : double.infinity;
    final fallback = Image.asset(AppConstants.defaultWordImage, height: height, width: width, fit: fit);
    if (imagePath == null || imagePath!.isEmpty) return fallback;

    if (_isAbsoluteFile) {
      return Image.file(
        File(imagePath!),
        height: height,
        width: width,
        fit: fit,
        errorBuilder: (_, _, _) => fallback,
      );
    }
    return Image.asset(
      imagePath!,
      height: height,
      width: width,
      fit: fit,
      errorBuilder: (_, _, _) => fallback,
    );
  }
}

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
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontFamily: AppFonts.mono,
              color: color,
            ),
      ),
    );
  }
}

/// Nhãn phân biệt kết quả tra qua API ngoài (MyMemory) — chưa lưu vào
/// `words`, xem [VocabWord.isOnline]. Màu cam accent để dễ nhận ra
/// ngay trong danh sách trộn chung với kết quả local.
class _OnlineBadge extends StatelessWidget {
  const _OnlineBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.snap.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi, size: 10, color: AppColors.snapDeep),
          const SizedBox(width: 3),
          Text(
            'Online',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.snapDeep,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
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
    this.trailing,
  });

  final VocabWord word;
  final bool showChapter;
  final VoidCallback? onTap;
  final bool selected;

  /// Widget tuỳ chọn đặt bên phải, giữa chiều cao dòng — dùng cho menu
  /// sửa/xoá của từ tự thêm (xem `_ManagedWordTile` trong
  /// `dictionary_detail_screen.dart`). Đặt ở cấp Row ngoài cùng (không
  /// chồng đè lên chữ) để nghĩa tiếng Việt vẫn co giãn/ellipsis đúng.
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
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
          padding: EdgeInsets.only(left: 13, right: trailing != null ? 4 : 13, top: 11, bottom: 11),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 3,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Flexible(
                          child: Text(word.word, style: textTheme.bodyLarge),
                        ),
                        if (word.phonetic.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              word.phonetic,
                              style: textTheme.labelLarge?.copyWith(
                                fontFamily: AppFonts.serif,
                                color: ipaColor,
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
                            style: textTheme.bodySmall?.copyWith(
                              color: scheme.outline,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (word.isOnline) ...[
                          const SizedBox(width: 8),
                          const _OnlineBadge(),
                        ] else if (showChapter && word.chapterTitle.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 96),
                            child: Text(
                              word.chapterTitle,
                              textAlign: TextAlign.right,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              softWrap: false,
                              style: textTheme.labelSmall?.copyWith(
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
              ?trailing,
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
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.7,
      child: WordDetailContent(
        word: word,
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
    this.leadingAction,
  });

  final VocabWord word;
  final ScrollController? scrollController;
  final EdgeInsets padding;

  /// Widget tuỳ chọn hiện ở góc trên bên phải (hàng riêng, canh phải) —
  /// dùng cho nút sửa/xoá của từ tự thêm ở pane chi tiết desktop, xem
  /// `_DesktopWordDetail` trong `dictionary_detail_screen.dart`.
  final Widget? leadingAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    const ipaColor = AppColors.brand;
    // Kết quả Online chưa có id thật trong `words` (xem
    // VocabWord.onlineWordSentinelId) -> không watch provider nào truy
    // vấn theo id, tránh lỗi/dữ liệu rác từ id sentinel.
    final examples = word.isOnline
        ? const AsyncValue<List<WordExample>>.data([])
        : ref.watch(wordExamplesProvider(word.id));

    return ListView(
      controller: scrollController,
      padding: padding,
      children: [
        if (leadingAction != null) ...[
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [leadingAction!]),
          const SizedBox(height: 20),
        ],
        if (word.isOnline) ...[
          const Align(alignment: Alignment.centerLeft, child: _OnlineBadge()),
          const SizedBox(height: 10),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(word.word, style: textTheme.headlineMedium),
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
                style: textTheme.bodyMedium?.copyWith(
                  fontFamily: AppFonts.mono,
                  color: ipaColor,
                ),
              ),
              const SizedBox(width: 8),
              Text('UK',
                  style: textTheme.bodySmall?.copyWith(color: scheme.outline)),
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
        const SizedBox(height: 16),
        Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: WordImage(imagePath: word.imagePath, height: 220, naturalSize: true),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Icon(Icons.translate, size: 14, color: scheme.outline),
            const SizedBox(width: 6),
            Text('NGHĨA TIẾNG VIỆT',
                style: textTheme.labelMedium?.copyWith(color: scheme.outline)),
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
              style: textTheme.bodyLarge
                  ?.copyWith(fontWeight: FontWeight.normal, height: 1.4)),
        ),
        if (word.chapterTitle.isNotEmpty) ...[
          const SizedBox(height: 12),
          Row(children: [
            Icon(Icons.menu_book, size: 15, color: scheme.outline),
            const SizedBox(width: 6),
            Text(word.chapterTitle,
                style:
                    textTheme.bodySmall?.copyWith(color: scheme.outline)),
          ]),
        ],
        if (word.isOnline) ...[
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => showAddToDictionarySheet(
                context,
                word: word.word,
                meaningVi: word.meaningVi,
                phonetic: word.phonetic.isEmpty ? null : word.phonetic,
                partOfSpeech: word.partOfSpeech.isEmpty ? null : word.partOfSpeech,
              ),
              icon: const Icon(Icons.bookmark_add_outlined),
              label: const Text('Thêm vào bộ'),
            ),
          ),
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
                        style: textTheme.labelMedium
                            ?.copyWith(color: scheme.outline)),
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
                              style: textTheme.bodySmall
                                  ?.copyWith(fontStyle: FontStyle.italic)),
                        if (ex.vi.isNotEmpty)
                          Text(ex.vi,
                              style: textTheme.bodySmall
                                  ?.copyWith(color: scheme.outline)),
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
