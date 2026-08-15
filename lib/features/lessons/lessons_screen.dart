import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdfx/pdfx.dart';

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
        MaterialPageRoute(builder: (_) => ChapterContentScreen(chapterId: chapter.id)),
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
    return Scaffold(
      appBar: AppBar(title: Text(chapter.value?.title ?? '')),
      body: chapter.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (c) {
          if (c == null) return const Center(child: Text('Không tìm thấy bài đọc.'));
          if (c.pdfPath == null) {
            return const Center(child: Text('Chưa có nội dung cho bài này.'));
          }
          return _ChapterPdfBody(pdfPath: c.pdfPath!);
        },
      ),
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
  late final PdfControllerPinch _controller;

  @override
  void initState() {
    super.initState();
    _controller = PdfControllerPinch(
      document: PdfDocument.openAsset(widget.assetPath),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PdfViewPinch(controller: _controller);
  }
}
