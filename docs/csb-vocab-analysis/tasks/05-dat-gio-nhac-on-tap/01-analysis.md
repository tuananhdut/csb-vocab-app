# Task-Analysis — Đặt giờ nhắc ôn tập tuỳ chỉnh

**Trạng thái:** Phân tích — chưa implement · **Liên quan:** FR-5 (Ôn tập), FR-7 (Cài đặt — số hiệu cũ)

> **Cập nhật 2026-08-16 (sau khi brainstorm xong lần 1):** Mở rộng yêu
> cầu — user muốn chọn **theo thứ trong tuần** (ví dụ chỉ nhắc T2/T3/T4,
> các thứ khác không nhắc), không chỉ 1 giờ áp dụng mọi ngày như bản gốc
> đã chốt trước đó. Đã hỏi lại và chốt: **1 giờ chung cho mọi thứ được
> chọn** (không cần giờ riêng từng thứ) — xem D3 mới. Toàn bộ mục bên
> dưới đã cập nhật theo scope mới; D2 (bản cũ, "1 giờ áp dụng mọi ngày")
> đã bị thay thế, giữ lại có gạch ngang để lưu vết quyết định đổi hướng.

## Yêu cầu

Cho phép user tự đặt giờ + chọn các thứ trong tuần để app gửi thông báo
hệ thống nhắc "đến giờ ôn tập", thay vì giờ cố định `20:00` mọi ngày
đang hardcode trong code hiện tại.

## Requirement Summary

### Business Goal

Tăng tỉ lệ user quay lại ôn tập đúng lịch SM-2 bằng cách để họ tự chọn
khung giờ **và ngày trong tuần** phù hợp thói quen cá nhân (ví dụ: chỉ
nhắc các ngày đi làm, nghỉ cuối tuần không nhắc), thay vì 1 lịch cố định
áp cho mọi người mỗi ngày.

### Scope

- UI chọn giờ nhắc (time picker) + chọn nhiều thứ trong tuần (7 công
  tắc/chip T2–CN), truy cập qua **icon Cài đặt trong AppBar (mobile) /
  nav-rail (Windows)** — không thêm tab thứ 5 (quyết định 2026-08-16,
  xem D1).
- Lưu lựa chọn (giờ + tập hợp thứ) persistent qua các lần mở app.
- **1 giờ chung áp dụng cho tất cả các thứ được chọn** — không hỗ trợ
  giờ khác nhau theo từng thứ (quyết định 2026-08-16, xem D3).
- Công tắc bật/tắt tổng để tắt hẳn nhắc hàng ngày (độc lập với việc chọn
  thứ nào — tắt tổng thì dù có chọn thứ nào cũng không nhắc).
- Áp dụng cho Android/iOS qua `flutter_local_notifications`.

### Out of Scope

- **Windows**: không hỗ trợ nhắc nền khi app đóng (đã chốt D2 cũ trong
  `00_Overview.md`, giữ nguyên không đổi) — đặt giờ/thứ tuỳ chỉnh không
  áp dụng cho lịch nền Windows; chỉ hiển thị ghi chú giới hạn trong UI.
- Giờ nhắc khác nhau theo từng thứ trong tuần (đã hỏi lại, chốt dùng 1
  giờ chung — xem D3).
- Nội dung/kiểu thông báo nâng cao (âm thanh riêng, action button).
- Đổi lại giao diện Sáng/Tối (không liên quan task này).

### Acceptance Criteria

- User mở màn cấu hình (qua icon Cài đặt), chọn giờ + chọn ít nhất 1
  thứ trong tuần, lưu → đúng giờ đã chọn, vào đúng các thứ đã chọn, có
  thông báo hệ thống nhắc ôn tập (Android/iOS); các thứ không chọn thì
  không có thông báo.
- Tắt app hoàn toàn, mở lại → giờ + tập hợp thứ đã lưu giữ nguyên, không
  reset về mặc định.
- Có công tắc bật/tắt tổng; tắt thì không còn thông báo nào được lên
  lịch bất kể đã chọn thứ nào.
- Nếu user bỏ chọn hết tất cả các thứ (nhưng vẫn bật công tắc tổng): coi
  như không có lịch nào active — cần quyết định UX cụ thể ở task-plan
  (chặn không cho bỏ chọn hết, hay cho phép và ngầm hiểu là tắt).
- Windows: UI hiển thị ghi chú rõ ràng về giới hạn (không nhắc nền khi
  app đóng), không hứa hẹn hành vi không hỗ trợ được.

## Existing UI Analysis

| Item | Trạng thái hiện tại | File/Module | Ghi chú |
|---|---|---|---|
| Màn "Cài đặt" | **Không tồn tại trong code** | — | `docs/csb-vocab-analysis/06_Settings.md` mô tả `lib/features/settings/settings_screen.dart` + `ThemeModeNotifier`, nhưng **cả 2 file không có trong repo hiện tại** (xác nhận bằng glob `lib/features/settings/**` → không khớp file nào). Tài liệu đã lỗi thời so với code thật. |
| Điều hướng chính (`HomeShell`) | 4 tab: Tra cứu / Học / Dịch / Từ điển của tôi | `lib/features/home/home_shell.dart` | Không có entry point nào tới màn cấu hình hiện tại |
| Giờ nhắc hàng ngày | Hardcode `hour: 20, minute: 0` (giá trị mặc định tham số, gọi không truyền override) | `lib/data/services/notification_service.dart:96`, gọi tại `lib/main.dart:10` | — |
| Bật/tắt nhắc | Không có — tự động luôn bật khi mở app lần đầu | `lib/main.dart:10` | Không có cách nào để user tắt |
| `shared_preferences` | **Không có trong `pubspec.yaml` hiện tại** | `pubspec.yaml` | Tài liệu cũ (`06_Settings.md`) nhắc gói này cho `ThemeModeNotifier`, nhưng đã kiểm tra danh sách dependencies hiện tại — không còn. Có thể đã bị gỡ cùng đợt xoá màn Settings, nhưng **không có entry `spec_history.md` nào ghi lại việc này** — khoảng trống tài liệu, nêu trong Open Questions. |

## UI Gap Analysis

| Thiếu / chưa hoàn chỉnh | Cần cho task | Đề xuất | Rủi ro |
|---|---|---|---|
| Entry point vào cấu hình | Bắt buộc | Icon bánh răng trong `AppBar.actions` (mobile, cạnh `_ConnectivityAppBarBadge`) và trong nav-rail footer (Windows, cạnh `_NavRailConnectivityFooter`) — mở 1 màn/BottomSheet riêng, không đổi bố cục 4 tab hiện có | Thấp — quyết định đã chốt, tránh phá bố cục bottom nav mobile |
| Time picker | Bắt buộc | `showTimePicker` chuẩn Material, không cần thư viện thêm | Thấp |
| **Chọn thứ trong tuần** | **Bắt buộc (yêu cầu mới)** | 7 `FilterChip`/`ChoiceChip` dạng T2–CN (nhãn ngắn, kiểu "T2 T3 T4 T5 T6 T7 CN"), cho phép chọn nhiều — không cần thư viện thêm | Thấp — UI đơn giản, nhưng cần quyết định UX khi bỏ chọn hết (xem Risk Analysis) |
| Công tắc bật/tắt | Acceptance criteria | `SwitchListTile` | Thấp |
| Ghi chú giới hạn Windows | Cần, tránh hiểu lầm | Text nhỏ hiển thị khi `Platform.isWindows`, giải thích chỉ nhắc được lúc app đang mở | Thấp |
| Xác nhận đã lưu | UX | `SnackBar` sau khi lưu (pattern đã dùng ở `review_session_screen.dart`) | Thấp |

## Backend/Service-layer Gap Analysis

*(Dự án offline-first, không backend server — "backend" ở đây tương đương tầng service/data local.)*

**Phát hiện kỹ thuật quan trọng** (đọc source `flutter_local_notifications-22.0.1`,
`lib/src/flutter_local_notifications_plugin.dart` + Android
`FlutterLocalNotificationsPlugin.java`): `matchDateTimeComponents:
DateTimeComponents.dayOfWeekAndTime` chỉ khớp **đúng 1 thứ cụ thể** mỗi
lần gọi `zonedSchedule` (lặp lại hàng tuần vào 1 ngày/giờ cố định) —
**không có cơ chế "khớp nhiều thứ trong 1 lịch"**. Để nhắc nhiều thứ
(vd T2/T3/T4), phải **lên nhiều lịch song song, mỗi thứ 1 `id` thông
báo riêng** — khác hẳn thiết kế 1-lịch-1-`id` (`id: 2001`) hiện tại của
`scheduleDailyReminder()`.

| Tầng | Trạng thái hiện tại | File/Module | Khoảng trống |
|---|---|---|---|
| Service thông báo | Có `scheduleDailyReminder(hour, minute)` dùng `matchDateTimeComponents: DateTimeComponents.time` (lặp mọi ngày, 1 `id` cố định) | `lib/data/services/notification_service.dart:96-116` | Cần viết lại thành hàm nhận **tập hợp thứ** (`Set<int>` — 1–7, theo `DateTime.weekday`) + giờ/phút, bên trong lặp gọi `zonedSchedule` với `matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime`, mỗi thứ 1 `id` riêng (ví dụ `2001 + weekday`, range `2002`–`2008`) để huỷ/sửa từng thứ độc lập được. Cần thêm hàm huỷ toàn bộ (`cancelDailyReminder()` lặp `_plugin.cancel()` cho từng `id` trong range đó) |
| Lưu trữ lựa chọn | Không có | — | Cần provider kiểu `Notifier` + persistence, lưu **cả tập hợp thứ chứ không chỉ giờ**. Phải xác nhận lại `shared_preferences` có được thêm lại vào `pubspec.yaml` không (xem Open Questions) |
| Khởi tạo lúc mở app | `main.dart` gọi thẳng `scheduleDailyReminder()` không tham số | `lib/main.dart:10` | Cần đổi sang đọc giờ + tập hợp thứ + trạng thái bật-tắt đã lưu rồi gọi hàm lên lịch mới/bỏ qua nếu tắt |
| State management | Riverpod dùng xuyên suốt (`ConsumerWidget`, `Notifier`, `FutureProvider`) | toàn bộ `lib/features/*` | Cấu hình giờ nhắc nên theo đúng pattern hiện có (giống `dueReviewCountProvider`, `connectivityProvider`) |

## API/Data Impact

Không có network API — quy đổi tương đương local persistence + local
notification scheduling:

| Item | Giá trị |
|---|---|
| Cơ chế lưu | `shared_preferences` (cần xác nhận thêm lại vào `pubspec.yaml`) — 3 key: `daily_reminder_enabled` (bool, mặc định `true`), `daily_reminder_hour`/`daily_reminder_minute` (int, mặc định 20/0), `daily_reminder_weekdays` (tập hợp thứ đã chọn, lưu dạng chuỗi CSV các số 1–7 hoặc bitmask int — quyết định cụ thể ở task-plan; mặc định = cả 7 thứ để giữ đúng hành vi hiện tại "nhắc mọi ngày" cho user chưa từng cấu hình) |
| Cơ chế lên lịch | Viết lại `NotificationService`: N lịch `zonedSchedule` song song (1 lịch/thứ được chọn, `matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime`), mỗi lịch 1 `id` riêng trong range cố định (vd `2002`–`2008` cho T2–CN) + hàm huỷ toàn bộ/huỷ theo thứ |
| Nền tảng áp dụng | Android, iOS — Windows out of scope cho phần lên lịch nền (đã chốt D2 cũ) |
| Input | `TimeOfDay` từ `showTimePicker` + `Set<int>` các thứ được chọn (chip/checkbox 7 ngày) |
| Output | 1–7 lịch thông báo hệ thống active (tuỳ số thứ được chọn), hoặc toàn bộ bị huỷ nếu tắt |
| Lỗi cần xử lý | Android 13+ cần quyền `POST_NOTIFICATIONS` — đã xin quyền sẵn trong `NotificationService.init()`; nếu user từ chối, cần thông báo rõ lịch đã lưu nhưng sẽ không hiện thông báo thật. Thêm case mới: **user bỏ chọn hết tất cả các thứ** — cần quyết định UX (chặn hay cho phép ngầm hiểu là tắt) |
| Quyền yêu cầu | Không có khái niệm auth/role (app 1 người dùng offline) — chỉ có quyền hệ thống (notification permission), đã xử lý sẵn |

## Risk Analysis

- [x] UI chưa có — cần tạo mới hoàn toàn (không có gì để tái sử dụng)
- [ ] API contract không rõ — không áp dụng (local only, đơn giản)
- [ ] DB schema không rõ — không áp dụng
- [x] Dependency có thể thiếu — cần xác nhận `shared_preferences` còn/mất khỏi `pubspec.yaml`
- [x] Ảnh hưởng luồng hiện tại — sửa `main.dart` + **viết lại** phần lên lịch trong `notification_service.dart` (không chỉ mở rộng tham số như đánh giá ban đầu — đổi từ 1-lịch-1-`id` sang N-lịch-N-`id` theo thứ), rủi ro trung bình vì đổi cấu trúc dữ liệu lịch, không chỉ thêm tham số
- [x] Cần xác minh thủ công — lên lịch hệ thống theo nhiều thứ (Android `AlarmManager`/`WorkManager` qua plugin) khó test tự động hơn bản gốc (phải verify từng thứ được chọn có bắn đúng, thứ không chọn không bắn); phải kiểm tra tay trên thiết bị thật/emulator qua nhiều ngày, hoặc đổi ngày+giờ hệ thống để verify nhanh
- [ ] Permission rule không rõ — không áp dụng, cơ chế xin quyền đã có sẵn
- [x] **UX chưa rõ khi bỏ chọn hết các thứ** — cần chốt ở task-plan (chặn thao tác, hay tự hiểu là tắt nhắc)

## Quyết định đã chốt (2026-08-16)

| # | Quyết định |
|---|---|
| D1 | Entry point vào cấu hình = icon Cài đặt trong `AppBar.actions` (mobile) / nav-rail footer (Windows) — **không** thêm tab thứ 5, giữ nguyên bố cục 4 tab hiện tại của `HomeShell` |
| ~~D2~~ | ~~Chỉ hỗ trợ 1 giờ nhắc cố định áp dụng mọi ngày~~ — **đã thay thế bởi D3** sau khi user yêu cầu mở rộng chọn theo thứ (cùng ngày 2026-08-16, sau lần brainstorm đầu) |
| D3 | Hỗ trợ **chọn nhiều thứ trong tuần** (vd chỉ T2/T3/T4), dùng **1 giờ chung cho tất cả các thứ được chọn** — không hỗ trợ giờ riêng từng thứ, giữ mức phức tạp UI vừa phải |

## Open Questions / TODO

- ~~`shared_preferences` còn hay đã bị gỡ khỏi `pubspec.yaml`?~~ — **đã
  xác nhận (2026-08-16, trong bước brainstorm)**: chỉ là dọn code không
  dùng, không có vấn đề kỹ thuật, an toàn để thêm lại.
- Nội dung text thông báo (`'Đến giờ ôn từ vựng'` / body) có cần đổi để
  phản ánh giờ do user chọn không, hay giữ nguyên câu hiện tại — quyết
  định ở bước task-plan.
- Giá trị mặc định khi user chưa từng cấu hình: đề xuất giữ giờ `20:00`,
  **cả 7 thứ được chọn sẵn**, và bật sẵn (giữ đúng hành vi hiện tại
  "nhắc mọi ngày" cho user chưa từng vào màn cấu hình), cần xác nhận
  lại ở task-plan.
- **UX khi bỏ chọn hết tất cả các thứ** (nhưng công tắc tổng vẫn bật):
  chặn không cho bỏ chọn thứ cuối cùng (luôn giữ tối thiểu 1 thứ), hay
  cho phép và ngầm hiểu tương đương tắt nhắc? Cần chốt ở task-plan.
- Định dạng lưu tập hợp thứ trong `shared_preferences`: chuỗi CSV
  (`"1,2,3"`) hay bitmask int (`0b0000111`)? Ảnh hưởng cách đọc/ghi ở
  provider, quyết định cụ thể ở task-plan.
