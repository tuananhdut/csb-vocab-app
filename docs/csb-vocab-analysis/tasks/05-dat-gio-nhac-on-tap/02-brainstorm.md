# Task-Brainstorm — Đặt giờ nhắc ôn tập tuỳ chỉnh

**Trạng thái:** Brainstorm — chưa implement · **Input:** `01-analysis.md`

> **Cập nhật 2026-08-16 (sau khi brainstorm lần 1 xong):** Yêu cầu mở
> rộng thêm chọn theo thứ trong tuần (D3 trong `01-analysis.md`, thay
> D2 cũ). Đánh giá lựa chọn Option 1 dưới đây **vẫn giữ nguyên** (không
> đổi phương án lưu trữ), nhưng phần thiết kế service/provider bên
> trong Option 1 đã cập nhật cho đúng cơ chế N-lịch-theo-thứ. Các mục
> Option 2/3 và bảng so sánh không đổi kết luận, chỉ thêm ghi chú nơi
> bị ảnh hưởng.

## Requirement Recap

User tự chọn 1 giờ cố định + **chọn nhiều thứ trong tuần** để nhận
thông báo nhắc ôn tập (Android/iOS) vào đúng các thứ đó, bật/tắt được,
giữ nguyên sau khi tắt/mở lại app. Entry point = icon Cài đặt trong
`AppBar`/nav-rail (D1), không thêm tab (đã chốt). Windows chỉ hiển thị
ghi chú giới hạn, ngoài phạm vi lên lịch nền (đã chốt D2 cũ,
`00_Overview.md` — không phải D2 của task này, xem ghi chú đổi số hiệu
ở `01-analysis.md`).

**Phát hiện kỹ thuật quan trọng** (xem chi tiết ở `01-analysis.md` mục
Backend/Service-layer Gap Analysis): `flutter_local_notifications`
không hỗ trợ "1 lịch khớp nhiều thứ" — `matchDateTimeComponents:
DateTimeComponents.dayOfWeekAndTime` chỉ khớp đúng 1 thứ/lần gọi
`zonedSchedule`. Nhắc nhiều thứ đòi hỏi **nhiều lịch song song, mỗi thứ
1 `id` thông báo riêng**. Đây là thay đổi kiến trúc ở tầng
`NotificationService`, không chỉ thêm tham số như đánh giá ban đầu.

Điểm phân nhánh chính giữa các phương án: **nơi lưu 3 giá trị cấu hình**
(`enabled: bool`, `time: hour+minute`, `weekdays: Set<int>`) — vì
`shared_preferences` được tài liệu cũ nhắc tới nhưng **đã xác nhận
không còn trong `pubspec.yaml` lẫn code** (grep toàn repo chỉ thấy
trong docs, không có trong `pubspec.yaml`/`lib/`). Dự án đã có sẵn
`UserDatabase` (SQLite read-write, `lib/data/local/user_database.dart`)
làm phương án lưu trữ thay thế không cần thêm dependency.

---

## Option 1: Minimal Safe Implementation — `shared_preferences` mới + BottomSheet

### Description

Thêm lại `shared_preferences` vào `pubspec.yaml` (gói rất nhẹ, phổ biến,
đúng như tài liệu cũ từng dùng cho `ThemeModeNotifier`). Lưu 4 key
(`daily_reminder_enabled`, `daily_reminder_hour`, `daily_reminder_minute`,
`daily_reminder_weekdays`) qua 1 `Notifier` Riverpod mới
(`DailyReminderNotifier`). UI là 1 `showModalBottomSheet` mở từ icon Cài
đặt — không phải route/màn riêng.

### Backend Changes (service-layer)

- `notification_service.dart`: **viết lại phần lên lịch** — đổi
  `scheduleDailyReminder(hour, minute)` (1 `id` cố định `2001`) thành
  `scheduleWeeklyReminders(hour, minute, Set<int> weekdays)`: lặp qua
  từng `weekday` trong `weekdays`, gọi `zonedSchedule` riêng với
  `matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime`, `id:
  2001 + weekday` (range `2002`–`2008`, theo `DateTime.weekday` 1=T2..7=CN).
  Thêm `cancelAllReminders()` — lặp `_plugin.cancel(id: ...)` cho cả 7
  `id` có thể có (an toàn dù `id` đó chưa từng được lên lịch).
- File mới `lib/data/services/reminder_settings_provider.dart`:
  `Notifier<ReminderSettings>` (record/class gồm `enabled`, `hour`,
  `minute`, `weekdays: Set<int>`) đọc/ghi `shared_preferences`, gọi
  `NotificationService` khi state đổi (huỷ hết rồi lên lịch lại theo
  state mới — đơn giản hơn tính diff, chấp nhận được vì tối đa 7 lệnh
  `zonedSchedule`).
- `main.dart`: đọc `ReminderSettings` đã lưu trước khi gọi
  `scheduleWeeklyReminders`/bỏ qua nếu tắt hoặc `weekdays` rỗng.

### Frontend Changes

- Icon `Icons.settings_outlined` trong `AppBar.actions` (mobile) + nav-rail footer (Windows).
- 1 widget `DailyReminderSheet` (BottomSheet): `SwitchListTile` bật/tắt
  tổng + `ListTile` hiện giờ đã chọn → bấm mở `showTimePicker` + hàng 7
  `FilterChip` T2–CN chọn nhiều + text ghi chú Windows.

### UI Completion

Toàn bộ UI mới, không tái sử dụng gì (đúng như UI Gap Analysis đã ghi) — nhưng nhỏ, gói gọn 1 file widget.

### Execution Order

Backend-first: viết `cancelDailyReminder()` + `ReminderSettings` provider trước (có thể tự kiểm bằng cách gọi tay), rồi mới nối UI.

### Pros

- Đúng pattern quen thuộc (`shared_preferences` là lựa chọn tiêu chuẩn cho cấu hình đơn giản dạng key-value, đã từng dùng trong dự án này trước đây).
- Tách biệt hoàn toàn khỏi `UserDatabase`/`VocabDatabase` — không đụng schema SQLite đang chạy, rủi ro thấp nhất cho phần dữ liệu học tập hiện có.
- BottomSheet nhẹ, không cần thêm route `go_router`.

### Cons

- Thêm 1 dependency mới (dù nhẹ) — phải cập nhật `pubspec.yaml`, chạy `flutter pub get`.
- 2 cơ chế lưu trữ local song song trong app (SQLite cho dữ liệu học + `shared_preferences` cho cấu hình) — nhất quán về mặt phân loại (đúng use-case từng loại), nhưng thêm 1 khái niệm mới vào codebase.

### Risks

- Thấp-trung bình. Rủi ro về `shared_preferences` **đã được giải quyết**
  (xác nhận 2026-08-16: gỡ trước đây chỉ là dọn code, không có vấn đề kỹ
  thuật). Rủi ro còn lại: đổi từ 1-lịch sang N-lịch-theo-thứ là thay đổi
  logic thật sự (không chỉ thêm tham số) — cần test tay kỹ hơn bản gốc
  để chắc mỗi thứ được lên lịch đúng `id`, và huỷ/lên lịch lại đúng khi
  user đổi lựa chọn (tránh còn sót lịch cũ của thứ đã bị bỏ chọn).

---

## Option 2: Structured Implementation — Bảng `app_settings` trong `UserDatabase`

### Description

Không thêm dependency mới. Thêm 1 bảng key-value đơn giản `app_settings (key TEXT PRIMARY KEY, value TEXT)` vào `UserDatabase._createSchema()`, dùng chung hạ tầng SQLite đã có. 1 `SettingsRepository` đọc/ghi qua bảng này. UI vẫn là BottomSheet (giống Option 1) hoặc 1 màn riêng nhỏ (`SettingsScreen`) mở qua `Navigator.push` (không cần thêm route `go_router` cấp cao, chỉ push nội bộ).

### Backend Changes

- `user_database.dart`: thêm `CREATE TABLE IF NOT EXISTS app_settings (...)` vào `_createSchema()`.
- File mới `lib/data/repositories/settings_repository.dart`: `get(key)`/`set(key, value)` dạng string, parse riêng ở tầng provider (bao gồm serialize `Set<int> weekdays` thành chuỗi, vd CSV).
- `notification_service.dart`: **cùng thay đổi N-lịch-theo-thứ như Option 1** (`scheduleWeeklyReminders` + `cancelAllReminders`) — việc này độc lập với nơi lưu trữ, áp dụng như nhau ở cả 2 Option.
- 1 `Notifier` Riverpod đọc từ `SettingsRepository` thay vì `shared_preferences`.

### Frontend Changes

Giống Option 1 (BottomSheet hoặc màn riêng nhỏ).

### UI Completion

Giống Option 1.

### Execution Order

Backend-first bắt buộc hơn Option 1: phải thêm cột/bảng DB trước, verify migration chạy được trên DB đã tồn tại (user cũ đã có `user.db` từ trước — `CREATE TABLE IF NOT EXISTS` an toàn, nhưng vẫn cần test tay trên 1 bản `user.db` cũ).

### Pros

- Không thêm dependency mới — giữ `pubspec.yaml` gọn, tránh câu hỏi "vì sao lại thêm lại gói đã từng bị gỡ" chưa có lời giải.
- Tận dụng đúng hạ tầng SQLite đã có sẵn, nhất quán với các repository khác trong dự án (`ReviewRepository`, v.v.).

### Cons

- Over-engineering nhẹ cho 2-3 giá trị cấu hình đơn giản — dùng SQLite (kèm serialize/deserialize string) cho việc mà `shared_preferences` xử lý trực tiếp bằng API gõ sẵn (`getBool`, `getInt`).
- Thêm 1 bảng mới vào `UserDatabase` đi ngược tinh thần dọn dẹp gần đây của dự án ([IMPL-016] vừa bỏ hẳn `review_logs`/`search_history` vì "không ai đọc lại" — bảng `app_settings` mới thì có đọc/ghi thật nên không phạm nguyên tắc đó, nhưng cần lưu ý xu hướng ưu tiên tối giản schema).
- Không tái dùng được cho các cấu hình tương lai kiểu client-only đơn giản mà không muốn đụng SQLite (vd nếu sau này cần lưu 1 flag onboarding).

### Risks

- Trung bình-thấp. Rủi ro là schema `UserDatabase` đang có kế hoạch thay đổi lớn (Drift, gộp DB — xem `91_DB-design-new-model.md`, D3 đã chốt) — thêm bảng mới vào schema **sắp bị thay thế** có thể là công sức bỏ đi khi migrate sang Drift sau này.

---

## Option 3: Long-term Refactor-Oriented Implementation — Gộp vào định hướng Settings/Drift tương lai

### Description

Chờ/đi trước một bước: dựng lại hẳn 1 `SettingsScreen` đầy đủ (route riêng qua `go_router`, không chỉ BottomSheet), thiết kế provider tổng `AppSettingsNotifier` bao quát cả giờ nhắc **lẫn** khôi phục lại theme Sáng/Tối (đã mất theo cùng đợt xoá màn Settings cũ) và chỗ trống cho các mục tương lai (`06_Settings.md` từng liệt kê "giọng đọc, số từ mới/ngày, quản lý dữ liệu"). Dùng `shared_preferences` (như Option 1) nhưng thiết kế provider theo interface tổng quát, sẵn sàng chuyển sang Drift table khi dự án migrate DB theo D3.

### Backend Changes

- Thêm `shared_preferences` (như Option 1).
- 1 `AppSettingsNotifier` tổng hợp nhiều field (`themeMode`, `dailyReminderEnabled`, `dailyReminderTime`, ...) thay vì 1 notifier riêng cho từng tính năng.
- `notification_service.dart`: thêm `cancelDailyReminder()`.

### Frontend Changes

- 1 `SettingsScreen` đầy đủ, thêm route `/settings` vào `go_router`.
- Khôi phục lại `RadioGroup<ThemeMode>` (Sáng/Tối/Theo hệ thống) — **vượt phạm vi yêu cầu hiện tại** (task chỉ xin đặt giờ nhắc).
- Thêm mục giờ nhắc + công tắc bật/tắt.

### UI Completion

Lớn nhất trong 3 phương án — dựng lại toàn bộ những gì `06_Settings.md` từng mô tả, không chỉ phần giờ nhắc.

### Execution Order

Cần quyết định phạm vi rõ trước khi bắt đầu — dễ lấn sang việc khôi phục cả theme switching, vốn không nằm trong yêu cầu gốc.

### Pros

- "Làm 1 lần cho xong" — nếu biết chắc sắp cần thêm nhiều mục cấu hình khác, tránh phải mở rộng `AppSettingsNotifier` nhiều lần.
- Khôi phục lại tính năng đổi theme đã bị mất âm thầm (không có ghi chú lý do trong `spec_history.md`) — có thể là điều user muốn nhân tiện sửa luôn.

### Cons

- **Vi phạm rõ ràng nguyên tắc "không mở rộng phạm vi task"** (`business-logic-flow` skill: *"Do not broaden task scope"*) — yêu cầu gốc chỉ là đặt giờ nhắc, không phải khôi phục toàn bộ màn Cài đặt.
- Rủi ro cao hơn hẳn: động vào nhiều thứ hơn (route mới, theme provider) trong khi mục tiêu thật chỉ cần 1 giờ + 1 công tắc.
- Việc theme Sáng/Tối bị mất là một bí ẩn tài liệu riêng (không rõ vì sao) — nên xử lý như 1 task/quyết định độc lập, không gộp ngầm vào task này.

### Risks

- Cao nhất. Trộn 2 mối quan tâm không liên quan (giờ nhắc vs. theme) vào 1 lần thay đổi, khó rollback/review riêng nếu 1 phần có vấn đề.

---

# Comparison

| Option | Scope | Safety | Speed | Maintainability | Risk | Recommendation |
|---|---|---|---|---|---|---|
| 1. `shared_preferences` + BottomSheet (7 chip thứ) | Nhỏ-vừa, đúng yêu cầu mới | Cao | Nhanh nhất | Tốt (pattern quen thuộc) | Thấp-trung bình (đổi cơ chế lịch sang N-lịch-theo-thứ, cần test tay kỹ) | **Khuyến nghị** |
| 2. Bảng `app_settings` trong `UserDatabase` | Nhỏ-vừa, đúng yêu cầu mới | Cao | Chậm hơn nhẹ (đổi schema) | Trung bình (schema sắp đổi sang Drift) | Trung bình | Dự phòng nếu Option 1 bị chặn |
| 3. `SettingsScreen` đầy đủ + khôi phục theme | Lớn, vượt yêu cầu gốc | Trung bình | Chậm nhất | Tốt về lâu dài, xấu cho task này | Cao | Không khuyến nghị cho task này |

---

# Recommended Approach

Recommend: **Option 1 — `shared_preferences` mới + BottomSheet**

Reason:

- Đúng đủ phạm vi acceptance criteria đã chốt trong `01-analysis.md`,
  không động vào schema SQLite đang chạy dữ liệu học tập thật của user
  (`learned_words`).
- `shared_preferences` là lựa chọn kỹ thuật đúng bản chất dữ liệu (4
  giá trị cấu hình phẳng: bật/tắt, giờ, phút, tập hợp thứ — không quan
  hệ) — Option 2 dùng SQLite cho việc này là dùng sai công cụ so với
  đúng use-case.
- Không lặp lại vấn đề của Option 3 (lấn phạm vi sang khôi phục theme —
  một quyết định khác, cần task riêng nếu user muốn).
- ~~Điều kiện đi kèm: phải hỏi lại user trước khi thêm gói~~ — **đã xác
  nhận (2026-08-16): việc gỡ `shared_preferences`/màn Settings cũ trước
  đây chỉ là dọn code không dùng, không có vấn đề kỹ thuật.** Option 1
  an toàn để tiến hành thẳng.
- Việc mở rộng chọn theo thứ (D3) không đổi lựa chọn Option — vẫn là
  vấn đề lưu trữ 4 giá trị phẳng, chỉ đổi *cách* tầng service dùng
  chúng để lên lịch (N-lịch thay vì 1-lịch).

# Recommended Execution Order

Recommend: **Backend/service-layer first**

Reason:

- `cancelDailyReminder()` và `ReminderSettings` Notifier có thể viết và
  tự kiểm độc lập (gọi tay qua debug console/log) trước khi có UI —
  đúng nguyên tắc "Backend First" khi hành vi lên lịch cần verify riêng
  (khó test tự động, đã ghi trong Risk Analysis của `01-analysis.md`).
- UI (BottomSheet + time picker) chỉ là lớp mỏng gọi vào provider đã có
  sẵn — làm sau giảm rủi ro phải sửa lại UI khi phát hiện vấn đề ở tầng
  lên lịch thật.

# Things Not To Do

- Không khôi phục lại `ThemeModeNotifier`/theme switching trong task
  này — đó là một khoảng trống tài liệu riêng, xử lý như quyết định độc
  lập nếu user muốn (Option 3 đã chỉ ra rủi ro trộn lẫn).
- Không thêm bảng mới vào `UserDatabase` (Option 2) trừ khi Option 1 bị
  chặn — schema này đang có kế hoạch thay thế bằng Drift (D3), tránh
  thêm công sức vào phần sắp bị viết lại.
- Không thêm route `go_router` mới cho 1 BottomSheet đơn giản — giữ
  đúng quyết định D1 đã chốt (icon mở sheet, không phải màn điều hướng
  riêng).
- Không đổi nội dung text thông báo hệ thống ngoài phạm vi giờ/bật-tắt
  trừ khi task-plan quyết định khác (câu hỏi mở đã ghi ở `01-analysis.md`).

# TODO / Need Confirmation

- ~~Xác nhận với user lý do gỡ `shared_preferences`/màn Settings cũ~~ —
  **đã xác nhận (2026-08-16): chỉ là dọn code không dùng, không có vấn
  đề kỹ thuật.** Chốt đi theo **Option 1**.
- Xác nhận giá trị mặc định khi chưa từng cấu hình (đề xuất giữ `20:00`
  + bật sẵn, đã nêu ở `01-analysis.md`) — quyết định ở bước `task-plan`.
- Nội dung text thông báo có đổi theo giờ user chọn hay giữ nguyên câu
  hiện tại — quyết định ở bước `task-plan`.
