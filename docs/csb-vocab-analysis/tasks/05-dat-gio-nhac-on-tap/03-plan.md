# Task-Plan — Đặt giờ nhắc ôn tập tuỳ chỉnh

**Trạng thái:** Plan — chưa implement · **Input:** `01-analysis.md`, `02-brainstorm.md`

> **Quy đổi thuật ngữ:** dự án này offline-first, 1 người dùng, không có
> backend server/network API (xem `project-context`/`business-logic-flow`
> skill — viết cho web BE/FE, không khớp 100% stack ở đây). Mục "API
> Contract" bên dưới quy đổi thành **Provider/Service Contract**: hợp
> đồng giữa tầng UI (Frontend) và tầng `NotificationService` +
> `ReminderSettingsNotifier` (đóng vai trò "Backend" — service/data layer
> local). "BE-xx" = service/provider/persistence, "FE-xx" = UI Flutter,
> "INT-xx" = nối UI với provider + verify hành vi lên lịch thật.

## Requirement Summary

User tự chọn 1 giờ cố định + chọn nhiều thứ trong tuần (T2–CN) để nhận
thông báo hệ thống nhắc "đến giờ ôn tập" đúng vào các thứ đã chọn
(Android/iOS), bật/tắt được bằng công tắc tổng, cấu hình lưu bền qua các
lần mở app. Truy cập qua icon Cài đặt trong `AppBar`/nav-rail của
`HomeShell`. Windows chỉ hiển thị ghi chú giới hạn (không hỗ trợ nhắc
nền khi app đóng — kế thừa nguyên trạng, không đổi).

## Selected Approach

**Option 1** (từ `02-brainstorm.md`): thêm `shared_preferences` +
`ReminderSettingsNotifier` (Riverpod) lưu 4 giá trị cấu hình phẳng, UI
là `showModalBottomSheet` mở từ icon Cài đặt. Tầng `NotificationService`
viết lại phần lên lịch từ 1-lịch-cố-định (`id: 2001`) sang N-lịch-theo-
thứ (`id: 2001 + weekday`, dùng `matchDateTimeComponents:
DateTimeComponents.dayOfWeekAndTime`).

## Scope

- Thêm `shared_preferences` vào `pubspec.yaml`.
- `NotificationService`: thêm `scheduleWeeklyReminders(hour, minute,
  Set<int> weekdays)` + `cancelAllReminders()`, giữ nguyên
  `showDueReminder()` (không đổi, ngoài phạm vi task).
- `ReminderSettingsNotifier` (Riverpod `Notifier`): đọc/ghi
  `shared_preferences`, gọi `NotificationService` khi state đổi.
- `main.dart`: đọc cấu hình đã lưu (hoặc mặc định) rồi lên lịch tương ứng
  thay vì gọi `scheduleDailyReminder()` cố định như hiện tại.
- UI: icon Cài đặt trong `AppBar.actions` (mobile) + nav-rail footer
  (Windows) của `HomeShell`, mở `DailyReminderSheet` (BottomSheet) gồm:
  công tắc tổng, `ListTile` giờ (mở `showTimePicker`), 7 `FilterChip`
  T2–CN, ghi chú giới hạn khi `Platform.isWindows`.

## Out of Scope

- Giờ khác nhau theo từng thứ (đã chốt D3 — 1 giờ chung).
- Khôi phục `ThemeModeNotifier`/theme switching (khoảng trống tài liệu
  riêng, không thuộc task này).
- Thêm bảng `app_settings` vào `UserDatabase` (Option 2, chỉ dùng nếu
  Option 1 bị chặn).
- Route `go_router` mới — dùng BottomSheet, không phải màn điều hướng.
- Đổi nội dung text thông báo ngoài phạm vi giờ/thứ/bật-tắt (xem quyết
  định "giữ nguyên text" ở mục Quyết định áp dụng bên dưới).

## Quyết định áp dụng vào plan (chốt các câu hỏi mở còn treo)

| # | Câu hỏi (từ `01-analysis.md`/`02-brainstorm.md`) | Quyết định |
|---|---|---|
| 1 | UX khi bỏ chọn hết tất cả các thứ | **Cho phép** — không có chip nào được chọn thì `scheduleWeeklyReminders` không lên lịch gì (tương đương tắt), dù công tắc tổng vẫn hiển thị bật. Không cần validate/chặn ở UI. |
| 2 | Định dạng lưu tập hợp thứ | **`List<String>` qua `setStringList`/`getStringList`** — mỗi phần tử là `weekday.toString()` (`'1'`..`'7'`, theo `DateTime.weekday`), không cần tự viết serialize. |
| 3 | Giá trị mặc định khi chưa từng cấu hình | Giữ `enabled=true`, `hour=20`, `minute=0`, `weekdays={1,2,3,4,5,6,7}` (cả 7 thứ) — đúng hành vi hiện tại "nhắc mọi ngày lúc 20:00" cho user chưa từng vào màn cấu hình, tránh thay đổi hành vi ngầm khi lên bản có tính năng mới. |
| 4 | Nội dung text thông báo | **Giữ nguyên** `title`/`body` hiện tại (`'Đến giờ ôn từ vựng'` / `'Đừng quên ôn lại các từ đã học hôm nay nhé!'`) — không cần đổi theo giờ/thứ đã chọn, ngoài phạm vi acceptance criteria gốc. |

---

# Provider/Service Contract

*(Quy đổi từ "API Contract" — không có network, đây là hợp đồng nội bộ
giữa Frontend (BottomSheet) và Backend/service-layer
(`ReminderSettingsNotifier` + `NotificationService`).)*

| Item | Value |
|---|---|
| Tên | `ReminderSettingsNotifier` (Riverpod `Notifier<ReminderSettings>`) |
| Provider | `reminderSettingsProvider` (`NotifierProvider<ReminderSettingsNotifier, ReminderSettings>`) |
| Đọc | `ref.watch(reminderSettingsProvider)` → trả `ReminderSettings { enabled, hour, minute, weekdays }` (đồng bộ, không phải `FutureProvider` — đọc từ `SharedPreferences` cached sau `init()`) |
| Ghi | `ref.read(reminderSettingsProvider.notifier).update({bool? enabled, int? hour, int? minute, Set<int>? weekdays})` — ghi `shared_preferences` + gọi lại `NotificationService` để huỷ-và-lên-lịch-lại theo state mới |
| Request params (từ UI) | `enabled: bool`, `hour: int (0-23)`, `minute: int (0-59)`, `weekdays: Set<int>` (giá trị 1-7, theo `DateTime.weekday`) |
| "Response" (state trả về) | `ReminderSettings` mới sau khi ghi — UI đọc lại qua `ref.watch` để cập nhật hiển thị |
| Validation | `hour`/`minute` đã được `showTimePicker` đảm bảo hợp lệ; `weekdays` không giới hạn rỗng (xem Quyết định #1) — không cần validate lỗi phía provider |
| Business error | Không áp dụng (không có quy tắc nghiệp vụ phức tạp, chỉ lưu + lên lịch) |
| Lỗi hệ thống cần xử lý | Quyền `POST_NOTIFICATIONS` (Android 13+) bị từ chối → `NotificationService.init()` đã xin quyền từ trước lúc `main()`; nếu bị từ chối, lịch vẫn được tạo (API không lỗi) nhưng thông báo sẽ không hiện — không có cách phát hiện lại quyền đã bị từ chối từ trong `scheduleWeeklyReminders` (giới hạn plugin), chấp nhận cho MVP |
| Auth/permission | Không áp dụng — app 1 người dùng, không role |
| Frontend caller | `DailyReminderSheet` widget (mới) |
| Backend handler | `ReminderSettingsNotifier` (mới) → gọi `NotificationService.instance.scheduleWeeklyReminders()`/`cancelAllReminders()` (mở rộng file có sẵn) |

## Service method contract — `NotificationService`

| Method | Input | Output | Ghi chú |
|---|---|---|---|
| `scheduleWeeklyReminders({required int hour, required int minute, required Set<int> weekdays})` | `hour`, `minute`, `weekdays` (1-7) | `Future<void>` | Mới. Với mỗi `weekday` trong `weekdays`: gọi `_plugin.zonedSchedule(id: 2001 + weekday, ..., matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime)`. Bỏ qua toàn bộ nếu `Platform.isWindows` (giữ nguyên hành vi cũ) hoặc `weekdays.isEmpty`. |
| `cancelAllReminders()` | — | `Future<void>` | Mới. Lặp `_plugin.cancel(id: 2001 + w)` cho `w` từ 1 đến 7 (an toàn dù `id` chưa từng được lên lịch — plugin không lỗi khi cancel `id` không tồn tại). |
| `scheduleDailyReminder(...)` | — | — | **Xoá** — thay hoàn toàn bởi `scheduleWeeklyReminders` (không giữ song song 2 hàm, tránh 2 cách lên lịch dễ nhầm). |
| `showDueReminder(int count)` | giữ nguyên | giữ nguyên | Không đổi — ngoài phạm vi task. |

---

# Subtask Breakdown

## Backend Subtasks (service/data layer)

| Subtask ID | Title | Files/Modules | Description | Depends On | Risk |
|---|---|---|---|---|---|
| BE-01 | Thêm `shared_preferences` | `pubspec.yaml` | Thêm dependency, chạy `flutter pub get` | None | Thấp |
| BE-02 | Viết lại lên lịch theo thứ trong `NotificationService` | `lib/data/services/notification_service.dart` | Xoá `scheduleDailyReminder`, thêm `scheduleWeeklyReminders(hour, minute, weekdays)` (N lịch, `id: 2001+weekday`) + `cancelAllReminders()` | None (độc lập, có thể viết + tự gọi tay để kiểm trước khi có UI) | Trung bình — đổi từ 1 lịch sang N lịch là thay đổi logic, không chỉ thêm tham số |
| BE-03 | `ReminderSettings` entity + `ReminderSettingsNotifier` | File mới `lib/data/services/reminder_settings_provider.dart` | Định nghĩa `ReminderSettings` (record hoặc class immutable: `enabled`, `hour`, `minute`, `weekdays: Set<int>`); `Notifier<ReminderSettings>` đọc/ghi `shared_preferences` (`daily_reminder_enabled`, `daily_reminder_hour`, `daily_reminder_minute`, `daily_reminder_weekdays` qua `setStringList`/`getStringList`), gọi `NotificationService` sau mỗi lần ghi | BE-01, BE-02 | Thấp |
| BE-04 | Khởi tạo đúng lịch lúc mở app | `lib/main.dart` | Thay `NotificationService.instance.scheduleDailyReminder()` bằng: đọc `ReminderSettings` đã lưu (khởi tạo `ProviderContainer` tạm hoặc đọc trực tiếp `SharedPreferences` trước `runApp`), gọi `scheduleWeeklyReminders` nếu `enabled`, else `cancelAllReminders()` | BE-02, BE-03 | Thấp-trung bình — cần xử lý đọc state trước khi có `ProviderScope` sẵn sàng, tương tự cách `NotificationService.instance.init()` đã gọi trước `runApp` hiện tại |

## Frontend Subtasks (UI)

| Subtask ID | Title | Files/Modules | Description | Depends On | Risk |
|---|---|---|---|---|---|
| FE-01 | Icon Cài đặt trong `HomeShell` | `lib/features/home/home_shell.dart` | Thêm `IconButton(Icons.settings_outlined)` vào `AppBar.actions` (mobile, cạnh `_ConnectivityAppBarBadge`) và vào nav-rail footer (Windows, cạnh `_NavRailConnectivityFooter`) — `onTap` mở `DailyReminderSheet` qua `showModalBottomSheet` | Provider/Service Contract (BE-03 để biết đúng type `ReminderSettings`, có thể code UI song song rồi nối sau) | Thấp |
| FE-02 | Widget `DailyReminderSheet` | File mới `lib/features/settings/widgets/daily_reminder_sheet.dart` | `SwitchListTile` (công tắc tổng) + `ListTile` hiện giờ đã chọn (bấm mở `showTimePicker`) + `Wrap` 7 `FilterChip` T2–CN (chọn nhiều) + `Text` ghi chú khi `Platform.isWindows` ("Windows chỉ nhắc được khi ứng dụng đang mở") + `SnackBar` xác nhận sau khi lưu | FE-01, Provider/Service Contract | Thấp |

## Integration Subtasks

| Subtask ID | Title | Files/Modules | Description | Depends On | Risk |
|---|---|---|---|---|---|
| INT-01 | Nối `DailyReminderSheet` với `ReminderSettingsNotifier` | `daily_reminder_sheet.dart`, `reminder_settings_provider.dart` | Thay dữ liệu tĩnh/giả trong FE-02 bằng `ref.watch(reminderSettingsProvider)` để hiển thị + `ref.read(...).update(...)` khi user đổi giờ/thứ/công tắc | BE-03, FE-02 | Thấp |
| INT-02 | Verify lên lịch thật hoạt động đúng theo thứ đã chọn | Toàn bộ luồng | Test tay: đổi giờ hệ thống/ngày hệ thống trên emulator hoặc chờ thật, xác nhận đúng thứ được chọn có thông báo, thứ không chọn thì không; đổi lựa chọn thì lịch cũ bị huỷ đúng (không còn thông báo "sót" từ thứ đã bỏ chọn) | BE-04, INT-01 | Trung bình — khó test tự động (đã ghi trong Risk Analysis của `01-analysis.md`), là bước xác minh quan trọng nhất của cả task |

---

# Recommended Execution Order

## Option A: Backend First

Use this when:

- Hành vi lên lịch (N-lịch-theo-thứ) là phần rủi ro kỹ thuật cao nhất,
  cần verify độc lập trước khi ràng buộc UI.
- Provider/Service Contract đã rõ (đã chốt ở trên) — UI chỉ là lớp mỏng
  gọi vào.

Order:

1. BE-01 (thêm dependency)
2. BE-02 (viết lại `NotificationService`) — tự gọi tay qua debug console để kiểm tra `id` lên lịch đúng trước khi đi tiếp
3. BE-03 (`ReminderSettingsNotifier`)
4. BE-04 (nối `main.dart`)
5. FE-01, FE-02 (UI, có thể song song với bước 2-4 nếu muốn, dùng dữ liệu giả tạm)
6. INT-01 (nối thật)
7. INT-02 (verify tay)

## Option B: Frontend First

Use this when:

- Muốn thấy UI (BottomSheet, chip chọn thứ) trước để duyệt UX, vì đây
  là UI hoàn toàn mới, không có gì để tham chiếu trực quan.

Order:

1. FE-01, FE-02 (UI với dữ liệu giả/state cục bộ tạm, chưa nối provider thật)
2. BE-01, BE-02, BE-03, BE-04
3. INT-01
4. INT-02

## Recommended Option

Recommend: **Option A — Backend/service-layer first**

Reason:

- Rủi ro kỹ thuật lớn nhất của task nằm ở BE-02 (đổi cơ chế lên lịch từ
  1-lịch sang N-lịch-theo-thứ) — nguyên tắc "Backend First" áp dụng rõ
  ràng: cần xác minh cơ chế lên lịch hoạt động đúng trước khi xây UI lên
  trên nó, tránh phải sửa lại UI nếu phát hiện vấn đề ở tầng service.
- Provider/Service Contract đã đủ rõ ràng ngay từ bây giờ (không cần chờ
  UI để hiểu rõ hơn) — không rơi vào trường hợp cần Frontend First ("UI
  gap đang chặn hiểu yêu cầu").
- UI (FE-01, FE-02) đơn giản, ít rủi ro, không phụ thuộc kết quả thật
  của Backend để viết code (chỉ cần biết đúng shape của `ReminderSettings`)
  — có thể làm song song nếu muốn tăng tốc, nhưng bước INT-02 (verify)
  luôn phải chờ toàn bộ BE xong.

---

# User Decision Required

Before implementation, user must choose one:

```text
Implement backend first: use task-implement-backend with BE-01
Implement frontend first: use task-implement-frontend with FE-01
Implement integration: use task-implement-integration with INT-01
```

---

# Manual Verification Plan

## Main Flow

- [ ] Mở icon Cài đặt → `DailyReminderSheet` hiện đúng giá trị mặc định lần đầu (20:00, cả 7 thứ được chọn, công tắc bật).
- [ ] Đổi giờ qua `showTimePicker`, chọn/bỏ chọn vài thứ (vd chỉ giữ T2/T3/T4), đóng sheet → giá trị hiển thị lại đúng khi mở lại sheet.
- [ ] Tắt hẳn app (kill process), mở lại → cấu hình vừa lưu vẫn giữ nguyên (không reset về mặc định).

## UI Verification

- [ ] `FilterChip` phản ánh đúng trạng thái đã chọn/chưa chọn (màu sắc, icon check).
- [ ] `SwitchListTile` tắt → các phần điều khiển giờ/chip có thể disable trực quan (nếu team quyết định UX này) hoặc vẫn cho sửa nhưng không áp dụng — quyết định nhỏ ở lúc code, không ảnh hưởng acceptance criteria.
- [ ] Trên Windows: ghi chú giới hạn hiển thị rõ, không gây hiểu lầm là sẽ nhắc nền được.
- [ ] `SnackBar` xác nhận hiện sau khi lưu thay đổi.

## API/Service Verification

- [ ] Gọi tay `NotificationService.instance.scheduleWeeklyReminders(hour: ..., minute: ..., weekdays: {1,3,5})` qua debug console → xác nhận 3 lịch được tạo với `id` đúng (`2002`, `2004`, `2006`).
- [ ] Gọi `cancelAllReminders()` → xác nhận cả 7 `id` khả dĩ đều bị huỷ (dùng `_plugin.pendingNotificationRequests()` để liệt kê, kiểm tra rỗng).
- [ ] Đổi lựa chọn thứ (vd từ {1,3,5} sang {2,4}) → xác nhận lịch cũ của thứ 1,3,5 bị huỷ, chỉ còn lịch của thứ 2,4.

## Error / Edge Case

- [ ] Bỏ chọn hết tất cả 7 chip (công tắc tổng vẫn bật) → không có lịch nào được tạo, không crash, `SnackBar` vẫn xác nhận lưu bình thường.
- [ ] Tắt công tắc tổng → toàn bộ lịch bị huỷ dù `weekdays` đang chọn gì.
- [ ] Từ chối quyền `POST_NOTIFICATIONS` (Android 13+) lúc cài app → cấu hình vẫn lưu/hiển thị bình thường, chỉ thông báo thật sự không hiện (giới hạn đã biết, không phải lỗi).
- [ ] Trên Windows: xác nhận `scheduleWeeklyReminders` bị bỏ qua hoàn toàn (không lỗi, không side-effect), giữ đúng hành vi D2 cũ.

## SPA / Browser Behavior

Không áp dụng — ứng dụng Flutter native (Windows/Android/iOS), không phải web SPA.

## Regression

- [ ] `showDueReminder()` (nhắc tức thời khi có từ đến hạn, hiện tại đang dùng ở `HomeShell`) vẫn hoạt động bình thường, không bị ảnh hưởng bởi việc xoá `scheduleDailyReminder`.
- [ ] Các tab khác (Tra cứu/Học/Dịch/Từ điển của tôi) không bị ảnh hưởng bởi việc thêm icon Cài đặt vào `AppBar`/nav-rail.
- [ ] User nâng cấp từ bản cũ (đã có `user.db` nhưng chưa từng cấu hình `shared_preferences`) → nhận đúng giá trị mặc định (20:00, cả 7 thứ, bật) thay vì crash hoặc rơi vào trạng thái rỗng.

---

# Risks / TODO

- BE-02 là subtask rủi ro kỹ thuật cao nhất — đổi cấu trúc lên lịch thật sự, không chỉ thêm tham số; nên implement và tự verify tay (INT-02 rút gọn) ngay sau BE-02, trước khi đi tiếp BE-03/04, để phát hiện sớm nếu `matchDateTimeComponents.dayOfWeekAndTime` có hành vi bất ngờ trên thiết bị thật.
- INT-02 (verify lịch thật theo thứ) khó rút ngắn thời gian test — cần ít nhất vài ngày thật hoặc thao tác đổi ngày/giờ hệ thống trên thiết bị test để xác nhận đủ các thứ trong tuần.
- Chưa quyết định: `DailyReminderSheet` có disable trực quan phần giờ/chip khi công tắc tổng tắt hay không — quyết định nhỏ, để lúc code, không chặn tiến độ.
- Kế thừa từ `01-analysis.md`: định nghĩa `weekday` dùng theo `DateTime.weekday` chuẩn Dart (1=Thứ Hai...7=Chủ Nhật) — cần nhất quán xuyên suốt `NotificationService`, `ReminderSettingsNotifier`, và UI (nhãn hiển thị T2..CN phải map đúng chiều với giá trị int lưu trữ).
