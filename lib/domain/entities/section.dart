// Các thực thể miền cho bài đọc (Section/Chapter dạng bài báo, đọc từ
// vocab.db) — xem docs/db/schema.sql, docs/csb-vocab-analysis/tasks/
// 04-seed-noi-dung-bai-doc/.

/// Section — chủ đề lớn của giáo trình, chứa nhiều [ArticleChapter] (bài đọc).
class Section {
  const Section({required this.id, required this.name, required this.sortOrder});

  final int id;
  final String name;
  final int sortOrder;
}

/// Chapter dạng bài đọc (bảng `chapters` trong `docs/db/schema.sql`) —
/// khác entity `Chapter` ở `dictionary.dart` (nhóm từ). Đặt tên riêng
/// để tránh nhầm.
class ArticleChapter {
  const ArticleChapter({
    required this.id,
    required this.sectionId,
    required this.title,
    required this.sortOrder,
    this.pdfPath,
  });

  final int id;
  final int sectionId;
  final String title;
  final int sortOrder;

  /// Đường dẫn asset PDF của bài đọc (`assets/pdf/section-{id}-unit-{n}.pdf`)
  /// — tách thủ công từ `docs/source-materials/TA_chuyen_nganh.docx`, giữ
  /// nguyên định dạng gốc (ảnh, heading, căn giữa).
  final String? pdfPath;
}
