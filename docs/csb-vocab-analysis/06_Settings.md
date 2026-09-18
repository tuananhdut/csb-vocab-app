# SCR-06 — Cài đặt

**FR:** FR-7 · **Trạng thái:** ⚠️ **Màn "Cài đặt" (chọn Sáng/Tối) đã bị xoá khỏi code** — chỉ còn modal "Nhắc ôn tập" · **Nguồn:** `lib/features/settings/widgets/daily_reminder_sheet.dart`

> ⚠️ **Phát hiện quan trọng (2026-09-17)**: `lib/features/settings/settings_screen.dart`
> và `lib/features/settings/theme_mode_provider.dart` — nguồn gốc của
> toàn bộ nội dung SCR-06 trong bản tài liệu trước — **không còn tồn tại
> trong code**. `grep` toàn bộ `lib/` không tìm thấy `ThemeMode`/
> `themeModeProvider`/`ThemeModeNotifier` ở đâu cả; `lib/app.dart` dùng
> `theme: AppTheme.theme` **cố định**, không có `themeMode` — khớp với
> chính comment trong `app_theme.dart`: *"Theme cố định duy nhất dùng
> chung toàn app... không có biến thể Sáng/Tối"*. Tính năng chọn giao
> diện Sáng/Tối/Theo hệ thống mô tả ở bản tài liệu trước **đã bị gỡ bỏ
> hoàn toàn**, không rõ thời điểm/lý do (không có entry nào trong
> `docs/spec_history.md` ghi lại việc này — xem Q-CSB-11).
>
> Thư mục `lib/features/settings/` giờ chỉ còn 1 file:
> `widgets/daily_reminder_sheet.dart` (modal "Nhắc ôn tập", xem mục dưới)
> — **không có màn hình "Cài đặt" nào để điều hướng tới nữa**, "Cài đặt"
> không còn là 1 destination/route thực sự trong app (xác nhận: không có
> `SettingsScreen` được tham chiếu ở bất kỳ đâu trong `lib/`, kể cả
> `home_shell.dart`).

## Nhắc ôn tập — đặt giờ + thứ trong tuần (FR-5.3)

**Nguồn:** `lib/features/settings/widgets/daily_reminder_sheet.dart`,
`lib/data/services/reminder_settings_provider.dart`,
`lib/data/services/notification_service.dart`.

Modal `DailyReminderSheet` (bottom sheet) — implement theo plan ở
`docs/spec_history.md` [IMPL-018]/[IMPL-019]/[IMPL-020], gia cố thêm
quyền thông báo ở [IMPL-026]. Mở từ 1 icon riêng trên `AppBar`/nav-rail
của `HomeShell` (xem `07_Home-shell.md`), **không phải 1 mục trong màn
Cài đặt** (vì màn đó không còn tồn tại — xem cảnh báo ở trên). Không hiện
trên Windows (không hỗ trợ lên lịch nhắc nền, chỉ nhắc tức thời lúc app
đang mở).

### Hành vi

- **Công tắc bật/tắt** nhắc ôn tập tổng thể (`SwitchListTile`).
- **Giờ nhắc**: 1 `ListTile` mở `showTimePicker` — chung 1 giờ áp dụng
  cho mọi thứ đã chọn (không đặt giờ riêng theo từng thứ).
- **Thứ trong tuần**: `Wrap` các `FilterChip` (T2–CN, theo
  `DateTime.weekday`) — có thể bỏ chọn hết (công tắc tổng vẫn bật, kết
  quả không có lịch nào được tạo, không validate/chặn ở UI — quyết định
  đã chốt ở [IMPL-020]).
- **Gật quyền thông báo ([IMPL-026])**: trước khi cho thấy phần điều
  khiển ở trên, kiểm tra `notificationPermissionGrantedProvider`
  (`FutureProvider<bool>`, đọc `Permission.notification.status` qua
  `permission_handler`). Quyền bị từ chối → thay hẳn bằng
  `_PermissionDeniedPrompt` (icon + giải thích + nút "Mở Cài đặt" gọi
  `openAppSettings()`). Quay lại app sau khi cấp quyền ở Cài đặt hệ
  thống → tự kiểm tra lại ngay (`WidgetsBindingObserver.didChangeAppLifecycleState`,
  `AppLifecycleState.resumed` → `ref.invalidate(...)`), không cần tự
  đóng/mở lại sheet.

### Lưu trữ & lên lịch thật

- `ReminderSettingsNotifier` (`Notifier<ReminderSettings>`) đọc/ghi qua
  `shared_preferences` (giờ/phút/công tắc/tập thứ đã chọn, thứ lưu dạng
  `List<String>` qua `setStringList`/`getStringList`).
- Mỗi lần đổi → `NotificationService.cancelAllReminders()` rồi
  `scheduleWeeklyReminders(hour, minute, weekdays)` — lên lại **N lịch
  song song**, mỗi thứ 1 `id` riêng (`flutter_local_notifications` chỉ
  khớp được 1 thứ/lịch qua `DateTimeComponents.dayOfWeekAndTime`).

## Giả định / hạn chế

- Đây là mã FR-7 — không có FR-6 nào được dùng trong code (xem
  `docs/spec_history.md` Q-CSB-01), số hiệu FR không liên tục. Gán FR-7
  cho tài liệu này giờ có phần gượng ép vì không còn màn "Cài đặt" thật
  để gắn vào — chỉ còn modal nhắc ôn tập vốn thuộc FR-5.3.
- Chưa xác nhận: theme Sáng/Tối/giọng đọc TTS/số từ mới/ngày/quản lý dữ
  liệu (backup `user.db`...) — tất cả đều **không có trong code hiện
  tại**, kể cả UI cơ bản nhất (chọn Sáng/Tối) từng có trước đây.

> **Q-CSB-11**: Tính năng chọn giao diện Sáng/Tối (từng ✅ code xong, mô
> tả ở bản tài liệu trước) đã biến mất khỏi code mà không có entry nào
> trong `docs/spec_history.md` ghi lại quyết định này — cố ý gỡ bỏ, hay
> mất do lỗi merge/rebase? Cần xác nhận. Nếu cố ý gỡ, cần quyết định có
> viết lại tính năng "Cài đặt" (theme, hoặc các mục khác) hay chính thức
> đóng SCR-06/FR-7 lại và gộp nội dung modal nhắc ôn tập này sang tài
> liệu khác (vd gộp vào `07_Home-shell.md` hoặc `05_Review.md`, vì đó là
> nơi nó thực sự thuộc về theo cả điều hướng lẫn chức năng — FR-5.3).
