import 'dart:io' show Platform;
import 'dart:typed_data' show Uint8List;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfx/pdfx.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../data/repositories/vocab_providers.dart';
import '../../domain/entities/section.dart';

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

class _PdfAssetView extends StatefulWidget {
  const _PdfAssetView({required this.assetPath});
  final String assetPath;

  @override
  State<_PdfAssetView> createState() => _PdfAssetViewState();
}

class _PdfAssetViewState extends State<_PdfAssetView> {
  // pdfx's pinch viewer (PdfViewPinch) throws UnimplementedError on
  // Windows. Its paged PdfView (PageView-based) is an alternative, but
  // pages snap to the full viewport instead of scrolling continuously,
  // so mouse-wheel scrolling still feels stuck. Windows instead renders
  // pages to images and lays them out in a plain ListView, which scrolls
  // like any other Flutter list.
  final bool _usePinch = !Platform.isWindows;

  PdfControllerPinch? _controllerPinch;
  Future<PdfDocument>? _documentFuture;

  @override
  void initState() {
    super.initState();
    if (_usePinch) {
      _controllerPinch = PdfControllerPinch(
        document: PdfDocument.openAsset(widget.assetPath),
      );
    } else {
      _documentFuture = PdfDocument.openAsset(widget.assetPath);
    }
  }

  @override
  void dispose() {
    _controllerPinch?.dispose();
    _documentFuture?.then((document) => document.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_usePinch) {
      return PdfViewPinch(controller: _controllerPinch!);
    }
    return FutureBuilder<PdfDocument>(
      future: _documentFuture,
      builder: (context, snapshot) {
        final document = snapshot.data;
        if (document == null) {
          return const Center(child: CircularProgressIndicator());
        }
        return _PdfPageScrollList(document: document);
      },
    );
  }
}

/// Continuous, mouse-wheel-friendly page list used on Windows in place of
/// pdfx's PdfView/PdfViewPinch (see [_PdfAssetViewState]). Pages are capped
/// to a reading-width column on a grey backdrop instead of stretching
/// edge-to-edge, so each page reads like a sheet of paper.
class _PdfPageScrollList extends StatelessWidget {
  const _PdfPageScrollList({required this.document});
  final PdfDocument document;

  static const _maxPageWidth = 820.0;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.pageBg,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        itemCount: document.pagesCount,
        separatorBuilder: (_, _) => const SizedBox(height: 16),
        itemBuilder: (_, index) => Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxPageWidth),
            child: _PdfPageImage(document: document, pageNumber: index + 1),
          ),
        ),
      ),
    );
  }
}

class _PdfPageImage extends StatefulWidget {
  const _PdfPageImage({required this.document, required this.pageNumber});
  final PdfDocument document;
  final int pageNumber;

  @override
  State<_PdfPageImage> createState() => _PdfPageImageState();
}

class _PdfPageImageState extends State<_PdfPageImage>
    with AutomaticKeepAliveClientMixin<_PdfPageImage> {
  Uint8List? _bytes;
  double _aspectRatio = 1 / 1.4142; // A4 fallback while the page renders.

  // Without this, ListView disposes pages once they scroll past the cache
  // extent and re-renders them from scratch (a fresh pdfx render call)
  // every time they scroll back into view — the jank the user reported.
  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _render();
  }

  Future<void> _render() async {
    final page = await widget.document.getPage(widget.pageNumber);
    try {
      final image = await page.render(
        width: page.width * 2,
        height: page.height * 2,
        format: PdfPageImageFormat.jpeg,
        backgroundColor: '#ffffff',
      );
      if (mounted && image != null) {
        setState(() {
          _bytes = image.bytes;
          _aspectRatio = page.width / page.height;
        });
      }
    } finally {
      await page.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.panel,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: AspectRatio(
          aspectRatio: _aspectRatio,
          child: _bytes == null
              ? const Center(child: CircularProgressIndicator())
              : Image.memory(_bytes!, fit: BoxFit.contain),
        ),
      ),
    );
  }
}
