// Các thực thể miền cho bộ từ điển (bảng `dictionaries`, đọc từ vocab.db).

/// Bộ từ điển (trước đây gọi là "chương" — nhóm từ theo chuyên ngành).
/// Tên `Chapter` giữ nguyên để không phải sửa các màn hình đang dùng
/// (`LessonsScreen`, `search_screen.dart`...) — ứng với bảng
/// `dictionaries` sau khi migrate sang `docs/db/schema.sql`.
class Chapter {
  const Chapter({
    required this.id,
    required this.chapterNo,
    required this.title,
    required this.wordCount,
  });

  final int id;
  final int chapterNo;
  final String title;
  final int wordCount;
}

/// Bộ từ điển (SCR-07 "Từ điển của tôi") — cùng bảng `dictionaries` với
/// [Chapter] nhưng đủ số liệu ôn tập để hiển thị dạng card (khác
/// [Chapter], vốn chỉ phục vụ danh sách từ đơn giản ở search/lessons cũ).
class Dictionary {
  const Dictionary({
    required this.id,
    required this.name,
    required this.isDefault,
    required this.isDeletable,
    required this.wordCount,
    required this.learnedCount,
    required this.dueCount,
    required this.newWordsCount,
  });

  final int id;
  final String name;
  final bool isDefault;
  final bool isDeletable;
  final int wordCount;
  final int learnedCount;
  final int dueCount;

  /// Số từ trong bộ CHƯA có trong `learned_words` — dùng cho nút "Học
  /// từ mới" (SCR-07, phiên giới thiệu từ theo lô).
  final int newWordsCount;
}
