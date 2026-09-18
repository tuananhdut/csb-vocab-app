# SCR-07 — Khung điều hướng chính (HomeShell)

**FR:** — (hạ tầng chung, không gắn 1 FR cụ thể) · **Trạng thái:** ✅ Đã code xong · **Nguồn:** `lib/features/home/home_shell.dart`

> ⚠️ **Viết lại toàn bộ (2026-09-17, xem `docs/spec_history.md` [IMPL-028])**
> — bản trước ghi 5 tab (có "Ôn tập", "Cài đặt") và thiếu hẳn 2 tính năng có
> thật (nút "Cài đặt nhắc ôn tập", badge Online/Offline). Nội dung dưới đây
> đã đối chiếu lại trực tiếp với code.

## Mục đích

Không phải 1 "màn hình" nghiệp vụ mà là khung chứa các tab chính, chịu
trách nhiệm điều hướng thích ứng (mobile vs. desktop), phát thông báo nhắc
ôn tập tức thời khi mở app, và chứa lối vào cho "Nhắc ôn tập theo lịch"
(SCR-06) + chỉ báo mạng.

## Hành vi

- **4 destination cố định** (hàm `_destinations(isDesktop)`, hardcode
  trong `_HomeShellState`): **Tra cứu, Học, Dịch, Từ điển của tôi** — mỗi
  mục là 1 tuple `(label, icon, screen)`. **Không có tab "Ôn tập" hay
  "Cài đặt" riêng** — Ôn tập được vào từ trong "Từ điển của tôi" (theo
  từng bộ), Cài đặt (theme Sáng/Tối, SCR-06) là màn riêng ngoài
  `HomeShell` (không rõ đường vào chính xác từ `home_shell.dart` — cần rà
  soát thêm, không thuộc phạm vi audit này).
- Tab "Học" trên desktop được bọc trong 1 `Navigator` con riêng
  (`_lessonsNavigatorKey`) — vào chi tiết 1 chương chỉ đổi phần nội dung
  bên phải, không che mất sidebar (khác mobile, `push` thẳng lên
  `Navigator` gốc che toàn màn).
- `IndexedStack` giữ cả 4 widget con sống cùng lúc (chuyển tab không mất
  state/scroll position của tab khác), chỉ đổi `index` hiển thị. Có thêm
  `_ContentWatermark` (logo CSB mờ 5% opacity) làm nền chung cho mọi tab.
- **Responsive layout** — đo `MediaQuery.sizeOf(context).width` so với
  `AppConstants.desktopBreakpoint` (700px):
  - `>= 700px` (desktop/Windows): `Row` gồm sidebar tự dựng (`Container`
    width 220 + `ListView` các `_NavRailItem`) bên trái + nội dung. **Đây
    là widget tự dựng, không phải `NavigationRail`/`VerticalDivider` của
    Flutter** (khớp mockup `.nav-item`, tô nền full-width khi active thay
    vì chỉ khoanh vùng quanh icon). Trên desktop, `Scaffold.appBar` là
    `null` — tiêu đề trang hiện qua `_PageHeader` (widget riêng, không
    phải `AppBar`) đặt phía trên nội dung.
  - `< 700px` (mobile): `_BottomNavBar` tự dựng ở đáy — **không phải
    `NavigationBar` mặc định của Flutter** (tô nền navy full-khối khi
    active thay vì pill quanh icon). Có `AppBar` chuẩn ở trên, tiêu đề
    lấy từ `destinations[_index].label`.
- Badge đỏ số từ đến hạn ôn (`dueReviewCountProvider`) hiện trên icon tab
  **"Từ điển của tôi"** (`_myDictionariesDestinationIndex = 3`) ở cả 2
  layout — cùng 1 hàm `_destinationIcon()` dùng chung.
- `ref.listen(dueReviewCountProvider, ...)` trong `build()`: nếu có từ đến
  hạn và chưa nhắc lần nào trong phiên này (`_dueNotified`), gọi
  `NotificationService.instance.showDueReminder(count)` — chỉ nhắc 1 lần
  mỗi lần mở app, không nhắc lặp lại khi rebuild.
- **Nút "Cài đặt nhắc ôn tập"** (mở `DailyReminderSheet`, SCR-06) — icon
  trong `AppBar.actions` (mobile) hoặc `_NavRailSettingsButton` riêng dưới
  danh sách tab (desktop). **Ẩn hoàn toàn trên Windows**
  (`if (!Platform.isWindows)`) — Windows không hỗ trợ lên lịch nhắc nền,
  chỉ có nhắc tức thời lúc app đang mở (mục trên).
- **Chỉ báo mạng Online/Offline** (`connectivityProvider`) — dạng pill
  bo tròn trong `AppBar.actions` (mobile, `_ConnectivityAppBarBadge`) hoặc
  chấm màu + nhãn cuối sidebar (desktop, `_NavRailConnectivityFooter`).

## Phụ thuộc

- `AppConstants.desktopBreakpoint`.
- `dueReviewCountProvider` (`lib/features/review/review_providers.dart`).
- `NotificationService` (`lib/data/services/notification_service.dart`).
- `connectivityProvider` (`lib/data/services/connectivity_service.dart`).
- `showDailyReminderSheet` (`lib/features/settings/widgets/daily_reminder_sheet.dart`, SCR-06).
- 4 widget con: `SearchScreen`, `LessonsScreen`, `TranslateScreen`, `MyDictionariesScreen`.

## Giả định / hạn chế

- Danh sách 4 destination hardcode ngay trong `_HomeShellState` — không
  đọc từ cấu hình/provider nào.
- Chưa xác nhận chính xác đường vào màn "Cài đặt" (SCR-06, theme
  Sáng/Tối) từ `HomeShell` — không thấy tham chiếu `SettingsScreen` trong
  `home_shell.dart`, cần rà soát riêng (không thuộc phạm vi lần cập nhật
  này).
- Mockup Windows (`docs/artifact-design-windows/`) thiết kế title bar
  riêng kiểu cửa sổ Windows (nút minimize/maximize/close) — **chưa có
  trong code**, desktop vẫn không có `Scaffold.appBar` (dùng `_PageHeader`
  thay thế) nhưng đó không phải title bar cửa sổ thật.
