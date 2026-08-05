import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/repositories/vocab_providers.dart';
import '../../domain/entities/section.dart';

/// SCR-03 — Học: danh sách Section (chủ đề lớn của giáo trình).
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
        itemCount: list.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final section = list[i];
          return ListTile(
            leading: CircleAvatar(child: Text('${section.sortOrder}')),
            title: Text(section.name),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ChapterListScreen(section: section)),
            ),
          );
        },
      ),
    );
  }
}

/// SCR-03b — Học: danh sách Chapter (bài đọc) của 1 Section.
///
/// Xem docs/artifact-design/screens/screen-03b-hoc-danh-sach-chapter.html.
class ChapterListScreen extends ConsumerWidget {
  const ChapterListScreen({super.key, required this.section});
  final Section section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chapters = ref.watch(articleChaptersProvider(section.id));
    return Scaffold(
      appBar: AppBar(title: Text(section.name)),
      body: chapters.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (list) => ListView.separated(
          itemCount: list.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final chapter = list[i];
            return ListTile(
              leading: CircleAvatar(child: Text('${chapter.sortOrder}')),
              title: Text(chapter.title),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => ChapterContentScreen(chapterId: chapter.id)),
              ),
            );
          },
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
