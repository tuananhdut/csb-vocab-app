/// Hằng số dùng chung toàn app.
class AppConstants {
  AppConstants._();

  /// Tên hiển thị tạm (chờ khách chốt — xem plan 06 mục C2).
  static const String appName = 'CSB Vocab';
  static const String appFullName = 'Học Từ Vựng — Cảnh Sát Biển VN';

  /// Thời gian hiển thị splash trước khi vào màn chính.
  static const Duration splashDuration = Duration(seconds: 5);

  /// Thời gian tự chuyển ảnh trong carousel splash.
  static const Duration splashSlideInterval = Duration(milliseconds: 1500);

  /// Breakpoint phân biệt desktop (rộng) và mobile (hẹp).
  static const double desktopBreakpoint = 700;

  /// Ảnh minh hoạ mặc định khi từ vựng không có `image_path` riêng (hầu
  /// hết các từ hiện tại, vì `vocab.db` chưa có dữ liệu ảnh) — dùng ở
  /// card giới thiệu/trắc nghiệm từ mới thay vì để trống.
  static const String defaultWordImage = 'assets/images/default.png';
}
