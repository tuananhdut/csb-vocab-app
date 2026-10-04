import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/translation_providers.dart';
import '../../data/repositories/vocab_providers.dart';
import '../../domain/entities/section.dart';
import '../../domain/entities/translation_direction.dart';
import '../../domain/entities/word.dart' show VocabWord;
import '../vocab/word_widgets.dart' show PosTag, WordDetailContent;

/// SCR-03 — Học: danh sách Section (chủ đề lớn của giáo trình), mỗi
/// Section xổ ra danh sách Chapter ngay bên dưới dạng accordion.
///
/// Xem docs/artifact-design/screens/screen-03-hoc-danh-sach-section.html.
/// Duyệt từ vựng theo bộ (giáo trình = bộ mặc định) nằm ở tab "Từ điển
/// của tôi", không còn ở đây — tab "Học" giờ chỉ chứa bài đọc.
class LessonsScreen extends ConsumerWidget {
  const LessonsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sections = ref.watch(sectionsProvider);
    return sections.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Lỗi: $e')),
      data: (list) => ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: list.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, i) => _SectionCard(section: list[i]),
      ),
    );
  }
}

/// 1 Section = 1 Card riêng biệt (nền trắng đục, che watermark phía sau)
/// — số thứ tự trong ô vuông bo góc màu brand để phân biệt cấp bậc với
/// Chapter con (số trong vòng tròn nhỏ, nhạt hơn, thụt lề).
class _SectionCard extends StatefulWidget {
  const _SectionCard({required this.section});
  final Section section;

  @override
  State<_SectionCard> createState() => _SectionCardState();
}

class _SectionCardState extends State<_SectionCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _SectionBadge(number: widget.section.sortOrder),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      widget.section.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: AppColors.inkSoft.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: _ChapterList(sectionId: widget.section.id),
            crossFadeState:
                _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
            sizeCurve: Curves.easeInOut,
          ),
        ],
      ),
    );
  }
}

class _SectionBadge extends StatelessWidget {
  const _SectionBadge({required this.number});
  final int number;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.brand,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$number',
        style: const TextStyle(
          color: AppColors.white,
          fontWeight: FontWeight.w800,
          fontSize: 15,
        ),
      ),
    );
  }
}

class _ChapterList extends ConsumerWidget {
  const _ChapterList({required this.sectionId});
  final int sectionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chapters = ref.watch(articleChaptersProvider(sectionId));
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.panel2,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: chapters.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Lỗi: $e', style: Theme.of(context).textTheme.bodySmall),
        ),
        data: (list) => Column(
          children: [
            for (final (i, chapter) in list.indexed) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  indent: 56,
                  color: Theme.of(context).dividerColor,
                ),
              _ChapterTile(chapter: chapter),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChapterTile extends StatelessWidget {
  const _ChapterTile({required this.chapter});
  final ArticleChapter chapter;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          // The title is already known here, so desktop's merged header
          // (see home_shell.dart's _SubtitleTrackingObserver) can show it
          // immediately instead of waiting on ChapterContentScreen's own
          // provider watch.
          settings: RouteSettings(arguments: chapter.title),
          builder: (_) => ChapterContentScreen(chapterId: chapter.id),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.brand.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Text(
                '${chapter.sortOrder}',
                style: const TextStyle(
                  color: AppColors.brand,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(chapter.title, style: Theme.of(context).textTheme.bodyMedium),
            ),
            Icon(
              Icons.chevron_right,
              size: 20,
              color: AppColors.inkSoft.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

/// SCR-03c — Học: nội dung bài đọc, hiển thị PDF gốc (tách thủ công từ
/// `TA_chuyen_nganh.docx`, giữ nguyên ảnh/heading/căn giữa của bản Word).
///
/// Xem docs/artifact-design/screens/screen-03c-hoc-noi-dung-bai.html và
/// docs/csb-vocab-analysis/tasks/04-seed-noi-dung-bai-doc/.
class ChapterContentScreen extends ConsumerWidget {
  const ChapterContentScreen({super.key, required this.chapterId});
  final int chapterId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chapter = ref.watch(articleChapterProvider(chapterId));
    final content = chapter.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Lỗi: $e')),
      data: (c) {
        if (c == null) return const Center(child: Text('Không tìm thấy bài đọc.'));
        if (c.pdfPath == null) {
          return const Center(child: Text('Chưa có nội dung cho bài này.'));
        }
        return _ChapterPdfBody(pdfPath: c.pdfPath!);
      },
    );

    // Desktop already gets a back+title bar from HomeShell's merged page
    // header (driven by this route's `arguments`, set in _ChapterTile), so
    // adding our own AppBar here would stack two bars — only mobile keeps
    // its own Scaffold/AppBar.
    final isDesktop =
        MediaQuery.sizeOf(context).width >= AppConstants.desktopBreakpoint;
    if (isDesktop) return content;

    return Scaffold(
      appBar: AppBar(title: Text(chapter.value?.title ?? '')),
      body: content,
    );
  }
}

/// Thử mở PDF asset; nếu file chưa tồn tại (chưa tách xong từ docx),
/// hiện thông báo thay vì crash/màn trắng.
class _ChapterPdfBody extends StatefulWidget {
  const _ChapterPdfBody({required this.pdfPath});
  final String pdfPath;

  @override
  State<_ChapterPdfBody> createState() => _ChapterPdfBodyState();
}

class _ChapterPdfBodyState extends State<_ChapterPdfBody> {
  late final Future<bool> _assetExists = _checkAssetExists(widget.pdfPath);

  static Future<bool> _checkAssetExists(String path) async {
    try {
      await rootBundle.load(path);
      return true;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _assetExists,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.data != true) {
          return const Center(child: Text('Chưa có nội dung cho bài này.'));
        }
        return _PdfAssetView(assetPath: widget.pdfPath);
      },
    );
  }
}

/// Renders the PDF with a real text layer (selectable, copyable) on every
/// platform including Windows — unlike pdfx (previous library), which only
/// rasterizes pages to bitmaps and has no text API at all. pdfrx already
/// ships a default long-press/selection context menu with "Copy" wired to
/// the clipboard; we append a "Dịch" button to it (`customizeContextMenuItems`
/// runs after pdfrx builds its own Copy/Select All items, so this only adds
/// to the default menu instead of replacing it).
class _PdfAssetView extends ConsumerWidget {
  const _PdfAssetView({required this.assetPath});
  final String assetPath;

  Future<void> _handleTranslateSelection(
    BuildContext context,
    WidgetRef ref,
    PdfViewerContextMenuBuilderParams params,
  ) async {
    final text = (await params.textSelectionDelegate.getSelectedText()).trim();
    // anchorB (anchor phụ) là mốc "dưới vùng chọn" AdaptiveTextSelectionToolbar
    // dùng để lật toolbar xuống dưới khi không đủ chỗ phía trên — dùng lại
    // đúng mốc đó để neo popup dịch ngay dưới chữ vừa bôi đen thay vì ở
    // đáy màn hình như bottom sheet trước đây.
    final anchor = params.anchorB ?? params.anchorA;
    params.dismissContextMenu();
    if (text.isEmpty || !context.mounted) return;
    _showInlineTranslatePopup(context, anchor: anchor, text: text);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PdfViewer.asset(
      assetPath,
      params: PdfViewerParams(
        backgroundColor: AppColors.pageBg,
        // Clamp zoom-out at "cover the viewport" (the page's larger-fit
        // dimension matches the screen) instead of pdfrx's plain default
        // (min zoom 0.1, page can shrink well below screen size) - user
        // asked for the page to never end up smaller than the screen.
        sizeDelegateProvider: const PdfViewerSizeDelegateProviderLegacy(
          useAlternativeFitScaleAsMinScale: true,
        ),
        customizeContextMenuItems: (params, items) {
          if (params.isTextSelectionEnabled && params.textSelectionDelegate.hasSelectedText) {
            items.add(
              ContextMenuButtonItem(
                label: 'Dịch',
                onPressed: () => _handleTranslateSelection(context, ref, params),
              ),
            );
          }
        },
      ),
    );
  }
}

/// Chiều cao tối đa dùng chung cho popup dịch nhanh — cả lúc dành chỗ
/// đặt popup ([_showInlineTranslatePopup]) lẫn lúc giới hạn nội dung bên
/// trong ([_InlineTranslateCardState]), xem ghi chú tại nơi dùng.
const _popupMaxHeight = 420.0;

/// Chèn 1 popup dịch nhanh nổi ngay dưới vùng chữ vừa bôi đen trong PDF
/// (neo tại [anchor], cùng toạ độ `anchorA`/`anchorB` mà pdfrx dùng để
/// đặt context menu mặc định — xem `PdfViewerContextMenuBuilderParams`).
/// Dùng [Overlay] thay vì `showModalBottomSheet` vì bottom sheet luôn
/// dính ở đáy màn hình, không bám theo vị trí chữ đã chọn.
///
/// Bấm ra ngoài popup (lớp [GestureDetector] trong suốt phủ toàn màn
/// hình) hoặc bấm nút đóng sẽ gỡ [OverlayEntry] khỏi cây widget.
void _showInlineTranslatePopup(
  BuildContext hostContext, {
  required Offset anchor,
  required String text,
}) {
  final overlay = Overlay.of(hostContext);
  // Chiều rộng chung cho popup — đủ cho cả 2 chế độ (dịch nhanh / chi
  // tiết từ đầy đủ) vì 2 chế độ dùng chung 1 Positioned, chỉ đổi NỘI
  // DUNG bên trong (xem [_InlineTranslateCardState]), không mở thêm popup
  // mới chồng lên.
  // [anchor] đến từ pdfrx tính SẴN theo toạ độ cục bộ của Overlay gần nhất
  // (cùng Overlay mà `Positioned` bên dưới dùng) — ở layout desktop, màn
  // "Học" dùng 1 `Navigator` lồng riêng (`_lessonsNavigatorKey` trong
  // `home_shell.dart`), Overlay của Navigator đó chỉ rộng bằng phần pane
  // bên phải, KHÔNG bằng toàn cửa sổ. Dùng `MediaQuery.of(context).size`
  // (kích thước toàn cửa sổ) để clamp sẽ sai khung tham chiếu và vẫn để
  // popup tràn ra ngoài pane — phải lấy đúng kích thước của chính Overlay
  // đang chèn vào.
  final overlayBox = overlay.context.findRenderObject() as RenderBox;
  final overlaySize = overlayBox.size;
  const cardWidth = 320.0;
  // Chiều cao tối đa DÀNH SẴN cho popup — phải khớp với
  // `_popupMaxHeight` (ConstrainedBox trong [_InlineTranslateCardState])
  // vì [top] bên dưới chỉ được tính 1 LẦN lúc chèn popup (không tính lại
  // khi người dùng chuyển từ xem bản dịch sang xem chi tiết từ, nội dung
  // dài hơn). Khớp đúng 2 giá trị này đảm bảo dù ở chế độ nào, popup
  // cũng không bao giờ tràn qua đáy Overlay — phần nội dung dài hơn sẽ tự
  // cuộn bên trong thay vì tràn ra ngoài.
  const estimatedMaxHeight = _popupMaxHeight;

  final left = (anchor.dx - cardWidth / 2).clamp(12.0, (overlaySize.width - cardWidth - 12.0).clamp(12.0, double.infinity));
  final top = (anchor.dy + 8).clamp(12.0, (overlaySize.height - estimatedMaxHeight - 12.0).clamp(12.0, double.infinity));

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: entry.remove,
          ),
        ),
        Positioned(
          left: left,
          top: top,
          width: cardWidth,
          child: _InlineTranslateCard(text: text, onClose: entry.remove),
        ),
      ],
    ),
  );
  overlay.insert(entry);
}

/// Thẻ nổi hiển thị kết quả dịch nhanh (Anh → Việt) của [text] vừa bôi
/// đen trong PDF — xem [_showInlineTranslatePopup]. Ưu tiên tra
/// [exactWordLookupProvider] (khớp chính xác trong từ điển giáo trình)
/// trước — nếu đã có sẵn thì dùng nghĩa đã biên soạn thay vì gọi máy
/// dịch ngoài; chỉ fallback sang [translateProvider] khi không khớp từ
/// nào (vd cụm từ/câu dài, hoặc từ không có trong giáo trình).
///
/// Khi bấm "Xem chi tiết", CHUYỂN nội dung của CHÍNH popup này sang hiện
/// [WordDetailContent] đầy đủ thay vì mở thêm `showWordDetail` (bottom
/// sheet riêng) — 2 popup chồng lên nhau trông rối mắt (đã gặp trong
/// thực tế); người dùng chỉ cần thấy 1 popup duy nhất, có thể quay lại
/// phần dịch bằng nút mũi tên.
class _InlineTranslateCard extends ConsumerStatefulWidget {
  const _InlineTranslateCard({required this.text, required this.onClose});
  final String text;
  final VoidCallback onClose;

  @override
  ConsumerState<_InlineTranslateCard> createState() => _InlineTranslateCardState();
}

class _InlineTranslateCardState extends ConsumerState<_InlineTranslateCard> {
  /// `null` = đang hiện phần dịch nhanh; có giá trị = đang hiện chi tiết
  /// đầy đủ của từ đó (xem [_showDetail]).
  VocabWord? _detailWord;

  void _showDetail(VocabWord word) => setState(() => _detailWord = word);
  void _backToTranslate() => setState(() => _detailWord = null);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final detailWord = _detailWord;

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      color: AppColors.panel,
      child: ConstrainedBox(
        // Phải khớp [_popupMaxHeight] dùng để dành chỗ lúc chèn popup
        // (xem [_showInlineTranslatePopup]) — nội dung dài hơn (vd từ có
        // nhiều ví dụ) tự cuộn bên trong nhờ `WordDetailContent`'s
        // `shrinkWrap`, không tràn ra ngoài khung đã dành sẵn.
        constraints: const BoxConstraints(maxHeight: _popupMaxHeight),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (detailWord != null)
                    InkWell(
                      onTap: _backToTranslate,
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Icon(Icons.arrow_back, size: 16, color: scheme.outline),
                      ),
                    )
                  else
                    Icon(Icons.translate, size: 14, color: scheme.outline),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      detailWord == null ? 'ANH → VIỆT' : 'CHI TIẾT TỪ',
                      style: textTheme.labelMedium?.copyWith(color: scheme.outline),
                    ),
                  ),
                  InkWell(
                    onTap: widget.onClose,
                    borderRadius: BorderRadius.circular(12),
                    child: Icon(Icons.close, size: 16, color: scheme.outline),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Flexible(
                child: detailWord == null
                    ? _buildTranslateBody(context)
                    : WordDetailContent(
                        word: detailWord,
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTranslateBody(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final dictMatch = ref.watch(exactWordLookupProvider(widget.text));

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.panel2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: SelectableText(widget.text, style: textTheme.bodyMedium),
        ),
        const SizedBox(height: 12),
        dictMatch.when(
          loading: () => Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.panel2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: const SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
          // Tra từ điển lỗi (vd DB chưa mở xong) không nên chặn người
          // dùng xem bản dịch — rơi về máy dịch ngoài như khi không
          // khớp từ nào.
          error: (_, _) => _OnlineTranslateResult(text: widget.text),
          data: (word) => word == null
              ? _OnlineTranslateResult(text: widget.text)
              : _DictionaryMatchResult(word: word, onShowDetail: _showDetail),
        ),
      ],
    );
  }
}

/// Khối kết quả khi [text] đã khớp CHÍNH XÁC 1 từ trong từ điển giáo
/// trình — ưu tiên nghĩa đã biên soạn (chuẩn hơn máy dịch), kèm huy hiệu
/// để người dùng biết đây không phải máy dịch, và nút chuyển popup sang
/// xem chi tiết đầy đủ (ví dụ thực tế, phát âm...) qua [onShowDetail].
class _DictionaryMatchResult extends StatelessWidget {
  const _DictionaryMatchResult({required this.word, required this.onShowDetail});
  final VocabWord word;
  final ValueChanged<VocabWord> onShowDetail;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.panel2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (word.partOfSpeech.isNotEmpty) ...[
                PosTag(word.partOfSpeech),
                const SizedBox(width: 8),
              ],
              Icon(Icons.verified_outlined, size: 14, color: AppColors.brand),
              const SizedBox(width: 4),
              Text(
                'Có trong từ điển',
                style: textTheme.labelSmall?.copyWith(color: AppColors.brand),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SelectableText(word.meaningVi, style: textTheme.bodyMedium),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              onPressed: () => onShowDetail(word),
              child: const Text('Xem chi tiết'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Khối kết quả dịch qua [translateProvider] (MyMemory online, fallback
/// model on-device) — dùng khi [text] không khớp từ nào trong từ điển
/// giáo trình.
class _OnlineTranslateResult extends ConsumerWidget {
  const _OnlineTranslateResult({required this.text});
  final String text;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final result = ref.watch(translateProvider((TranslationDirection.enToVi, text)));

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.panel2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: result.when(
        loading: () => const Center(
          child: SizedBox(
            height: 16,
            width: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        error: (e, _) => Text('Lỗi dịch: $e', style: TextStyle(color: scheme.error)),
        data: (translated) => SelectableText(translated, style: textTheme.bodyMedium),
      ),
    );
  }
}
