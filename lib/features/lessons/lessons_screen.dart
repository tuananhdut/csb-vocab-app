import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

/// SCR-03c — Học: nội dung bài đọc (Markdown thô, không highlight từ
/// vựng — cách liên kết từ ↔ vị trí trong bài chưa chốt, xem
/// docs/artifact-design/screens/screen-03c-hoc-noi-dung-bai.html và
/// docs/csb-vocab-analysis/tasks/04-seed-noi-dung-bai-doc/).
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
          return Markdown(
            data: _breakIntoParagraphs(c.content ?? ''),
            padding: const EdgeInsets.all(20),
          );
        },
      ),
    );
  }
}

/// `content_md` là 1 khối text liên tục không có dấu ngắt đoạn "\n\n"
/// (đúng scope "Markdown thô gộp khối" đã chốt ở task 04 — script
/// extract không tự thêm dấu ngắt). `flutter_markdown_plus` render mỗi
/// đoạn bằng 1 `Wrap` chứa 1 `Text.rich` duy nhất khi đoạn không có
/// định dạng riêng — `Wrap` đo kích thước "muốn" của `Text.rich` theo
/// intrinsic width (không bị giới hạn theo widget cha), nên 1 đoạn dài
/// không dấu ngắt render tràn ngang thay vì xuống dòng. Chèn "\n\n" sau
/// mỗi câu và trước các heading UNIT đã biết để buộc mỗi đoạn ngắn lại
/// — chỉ ở tầng hiển thị, không sửa dữ liệu DB/CSV gốc.
String _breakIntoParagraphs(String text) {
  // Chi ngat sau dau cham/hoi/than khi truoc do la 1 CAU thuc su (ky tu
  // thuong/so/dong mo don ngay truoc dau cham) - tranh cat nham so La
  // Ma/de muc ngan kieu "I." "1." "IV." theo sau boi chu hoa dau cau ke.
  var result = text.replaceAllMapped(
    RegExp(r'(?<=[a-z0-9\)])([.?!])\s+(?=[A-Z])'),
    (m) => '${m[1]}\n\n',
  );
  result = result.replaceAllMapped(
    RegExp(r'(UNIT\s*\d+\s*:|I\.\s*INTRODUCTION|II\.\s*TEXT|III\.\s*GRAMMAR|IV\.\s*VOCABULARY|Exercise\s*\d+)'),
    (m) => '\n\n${m[1]}',
  );
  // Nhieu doan (lich trinh, danh sach gach dau dong noi bang "-"/":")
  // khong co dau cham cau nen khong duoc ngat o buoc tren, van con qua
  // dai gay trang ngang (da xac nhan: 14/14 chapter co it nhat 1 doan
  // >400 ky tu). Lop phong ve cuoi: voi tung doan (tach theo "\n\n" da
  // co), neu van dai hon 200 ky tu, chen them "\n\n" tai khoang trang
  // gan nhat sau moi 200 ky tu.
  return result.split('\n\n').map(_hardWrapLongParagraph).join('\n\n');
}

String _hardWrapLongParagraph(String paragraph) {
  const maxLen = 200;
  if (paragraph.length <= maxLen) return paragraph;

  final buffer = StringBuffer();
  var start = 0;
  while (start < paragraph.length) {
    var end = start + maxLen;
    if (end >= paragraph.length) {
      buffer.write(paragraph.substring(start));
      break;
    }
    final breakAt = paragraph.lastIndexOf(' ', end);
    end = (breakAt > start) ? breakAt : end;
    buffer.write(paragraph.substring(start, end));
    buffer.write('\n\n');
    start = end + 1;
  }
  return buffer.toString();
}
