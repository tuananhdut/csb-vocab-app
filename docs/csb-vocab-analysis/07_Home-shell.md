# SCR-07 — Khung điều hướng chính (HomeShell)

**FR:** — (hạ tầng chung, không gắn 1 FR cụ thể) · **Trạng thái:** ✅ Đã code xong · **Nguồn:** `lib/features/home/home_shell.dart`

## Mục đích

Không phải 1 "màn hình" nghiệp vụ mà là khung chứa 5 tab chính, chịu trách
nhiệm điều hướng thích ứng (mobile vs. desktop) và phát thông báo nhắc ôn tập.

## Hành vi

- 5 destination cố định (`_destinations`, hardcode): Tra cứu, Học, Dịch,
  Ôn tập, Cài đặt — mỗi mục là 1 tuple `(label, icon, screen)`.
- `IndexedStack` giữ cả 5 widget con sống cùng lúc (chuyển tab không mất
  state/scroll position của tab khác), chỉ đổi `index` hiển thị.
- **Responsive layout** — đo `MediaQuery.sizeOf(context).width` so với
  `AppConstants.desktopBreakpoint` (700px):
  - `>= 700px` (Windows, cửa sổ rộng): `Row` gồm `NavigationRail` (label luôn
    hiện, `NavigationRailLabelType.all`) bên trái + `VerticalDivider` +
    nội dung.
  - `< 700px` (mobile): `NavigationBar` ở đáy `Scaffold`, không có rail.
- Badge đỏ số từ đến hạn ôn (`dueReviewCountProvider`) hiện trên icon tab Ôn
  tập (`_reviewDestinationIndex = 3`) ở **cả 2 layout** — cùng 1 hàm
  `_destinationIcon()` dùng chung.
- `ref.listen(dueReviewCountProvider, ...)` trong `build()`: nếu có từ đến
  hạn và chưa nhắc lần nào trong phiên này (`_dueNotified`), gọi
  `NotificationService.instance.showDueReminder(count)` — chỉ nhắc 1 lần mỗi
  lần mở app, không nhắc lặp lại khi rebuild.

## Phụ thuộc

- `AppConstants.desktopBreakpoint`.
- `dueReviewCountProvider` (`lib/features/review/review_providers.dart`).
- `NotificationService` (`lib/data/services/notification_service.dart`).
- 5 widget con: `SearchScreen`, `LessonsScreen`, `TranslateScreen`, `ReviewScreen`, `SettingsScreen`.

## Giả định / hạn chế

- Danh sách 5 destination hardcode ngay trong `_HomeShellState` — không đọc
  từ cấu hình/provider nào, nên **mockup thiết kế 5 tab khác** (Tra cứu, Học,
  Dịch, **Từ điển của tôi**, Cài đặt — gộp Ôn tập vào Từ điển của tôi) sẽ cần
  sửa trực tiếp mảng `_destinations` và `_reviewDestinationIndex` khi triển
  khai, không phải chỉ thêm màn hình mới.
- `AppBar` phía trên dùng chung cho cả layout desktop và mobile
  (`Scaffold.appBar`), tiêu đề lấy từ `_destinations[_index].label` — mockup
  Windows (`docs/artifact-design-windows/`) thiết kế title bar riêng kiểu
  cửa sổ Windows (nút minimize/maximize/close), **chưa có trong code** (code
  thật vẫn dùng `AppBar` Material chuẩn, không có custom title bar).
