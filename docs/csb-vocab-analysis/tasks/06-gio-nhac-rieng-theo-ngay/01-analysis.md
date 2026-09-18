# Task-Analysis — Đặt giờ nhắc riêng theo từng ngày + làm mới UI

**Trạng thái:** Phân tích — chưa implement · **Liên quan:** FR-5 (Ôn tập), FR-7 (Cài đặt — số hiệu cũ), kế thừa trực tiếp `05-dat-gio-nhac-on-tap/`

> **Quy đổi thuật ngữ:** dự án offline-first, 1 người dùng, không có
> backend server/network API (xem `project-context`/`business-logic-flow`
> skill — viết cho web BE/FE, không khớp 100% stack ở đây). Mục "API
> Impact" quy đổi thành **Provider/Service Contract**: hợp đồng giữa
> tầng UI (Frontend, Flutter) và tầng `NotificationService` +
> `ReminderSettingsNotifier` (đóng vai trò "Backend" — service/data layer
> local).

## Yêu cầu

Nguyên văn: *"tôi muốn setting thông báo của giờ theo từng ngày, UI hiện
đại dễ dùng"* — hiểu là 2 yêu cầu gộp:

1. Cho phép đặt **giờ nhắc khác nhau cho từng ngày trong tuần** (ví dụ
   T2 nhắc 19:00, T7 nhắc 09:00), thay vì 1 giờ chung áp dụng cho tất cả
   các thứ đã chọn như hiện tại.
2. Làm mới UI của màn cấu hình nhắc ôn tập theo hướng "hiện đại, dễ
   dùng" hơn bản `DailyReminderSheet` hiện tại (bottom sheet đơn giản,
   thiên về chức năng, chưa được thiết kế thị giác).

## Requirement Summary

### Business Goal

Tăng tỉ lệ tuân thủ lịch ôn tập bằng cách cho user đặt giờ nhắc phù hợp
thói quen riêng của **từng ngày** (ví dụ ngày đi làm nhắc buổi tối muộn,
cuối tuần nhắc sớm hơn) thay vì 1 khung giờ cứng cho mọi ngày đã chọn;
đồng thời nâng trải nghiệm màn cấu hình để user cảm nhận app được đầu tư
kỹ hơn ở các màn phụ, không chỉ màn chính.

### Scope

- Đổi mô hình dữ liệu cấu hình nhắc từ `{hour, minute, weekdays: Set<int>}`
  dùng chung 1 giờ → mỗi thứ trong tuần có **giờ riêng độc lập**
  (`Map<int weekday, TimeOfDay>` hoặc tương đương), giữ nguyên công tắc
  bật/tắt tổng.
- Thiết kế lại `DailyReminderSheet` (hoặc thay bằng UI mới) hiển thị 7
  dòng (T2–CN), mỗi dòng có: công tắc bật/tắt riêng cho ngày đó + giờ đã
  chọn (bấm để đổi) — thay cho dãy `FilterChip` + 1 time picker chung
  hiện tại.
- Cải thiện thẩm mỹ theo `AppColors`/`AppFonts` đã có (card, spacing,
  icon, trạng thái rỗng/đang tải rõ ràng hơn) — "hiện đại" trong phạm vi
  design token sẵn có của app, không đổi theme tổng thể.
- Giữ nguyên: entry point qua icon Cài đặt trong `AppBar`/nav-rail của
  `HomeShell`; hành vi Windows (ẩn hoàn toàn, không hỗ trợ nhắc nền);
  nội dung text thông báo (`title`/`body`); cơ chế xin quyền
  (`permission_handler`).

### Out of Scope

- Thêm loại nhắc mới ngoài "nhắc ôn tập" (âm thanh riêng, nhiều lần nhắc
  1 ngày, action button trên notification).
- Xây màn "Cài đặt" tổng (theme Sáng/Tối, ngôn ngữ, tài khoản...) — vẫn
  chỉ có đúng 1 mục cấu hình (nhắc ôn tập) như hiện tại, trừ khi user
  quyết định khác ở bước brainstorm/plan.
- Windows: vẫn ngoài phạm vi cho lên lịch nền (giữ nguyên constraint đã
  chốt nhiều lần trước đây, gần nhất ở `05-dat-gio-nhac-on-tap`).
- Đổi route `go_router` mới — trừ khi bước brainstorm/plan quyết định
  đổi từ BottomSheet sang full-screen (xem UI Gap Analysis, mục "quyết
  định cần chốt").

### Acceptance Criteria

- Màn cấu hình hiển thị 7 dòng (T2–CN), mỗi dòng cho phép: bật/tắt riêng
  ngày đó, chọn giờ riêng cho ngày đó (không còn 1 giờ áp dụng chung cho
  tất cả).
- Đổi giờ/bật-tắt 1 ngày không ảnh hưởng cấu hình của các ngày khác.
- Tắt app hoàn toàn, mở lại → cấu hình từng ngày (giờ + bật/tắt) được
  giữ nguyên, không reset.
- Công tắc tổng (nếu giữ) tắt hết toàn bộ nhắc bất kể cấu hình từng ngày
  đang là gì; bật lại → khôi phục đúng cấu hình từng ngày đã lưu trước
  đó (không reset về mặc định).
- Người dùng chưa từng cấu hình (nâng cấp từ bản cũ) → nhận đúng hành vi
  mặc định hiện tại quy đổi sang mô hình mới (đề xuất: áp giờ chung cũ
  đã lưu — nếu có — cho tất cả 7 ngày làm giá trị khởi tạo, không mất
  cấu hình cũ; xem Risk Analysis).
- UI mới dùng đúng `AppColors`/`AppFonts` hiện có, không phá vỡ thiết kế
  tổng thể của app; hoạt động tốt trên mobile (kích thước bottom sheet
  hiện tại) — cần quyết định thêm nếu chuyển sang full-screen (xem UI
  Gap Analysis).

## Existing UI Analysis

| Item | Trạng thái hiện tại | File/Module | Ghi chú |
|---|---|---|---|
| Entry point | Icon `Icons.settings_outlined` trong `AppBar.actions` (mobile) / nav-rail footer (desktop, ẩn trên Windows) | `lib/features/home/home_shell.dart` | Giữ nguyên, không đổi trong task này |
| UI cấu hình nhắc | `showModalBottomSheet` (`DailyReminderSheet`) — `SwitchListTile` tổng + `ListTile` 1 giờ chung (mở `showTimePicker`) + `Wrap` 7 `FilterChip` T2–CN (chọn/bỏ ngày, không có giờ riêng) | `lib/features/settings/widgets/daily_reminder_sheet.dart` | Đây chính là UI cần thay đổi cấu trúc (thêm giờ/ngày) và làm mới thẩm mỹ |
| Model dữ liệu hiển thị | `ReminderSettings { enabled, hour, minute, weekdays: Set<int> }` — 1 cặp giờ/phút dùng chung cho mọi `weekday` trong `weekdays` | `lib/data/services/reminder_settings_provider.dart` | Cần đổi cấu trúc — giờ phải gắn theo từng `weekday`, không còn là field top-level dùng chung |
| Trạng thái quyền thông báo | `_PermissionDeniedPrompt` thay thế toàn bộ phần điều khiển khi quyền bị từ chối, tự re-check khi app resume | `daily_reminder_sheet.dart` (`_PermissionDeniedPrompt`, `WidgetsBindingObserver`) | Giữ nguyên, không đổi |
| Theme/design token | `AppColors` (navy brand, `panel2`, `border`...), `AppFonts` (serif/mono) đã định nghĩa sẵn; không có widget "card cấu hình" tái sử dụng được ngoài style viết tay trong `_PermissionDeniedPrompt` | `lib/core/theme/app_theme.dart` | UI mới nên tái dùng token màu sẵn có, có thể cần thêm 1 widget dùng chung kiểu "row cấu hình ngày" nếu muốn nhất quán |

## UI Gap Analysis

| Thiếu / chưa hoàn chỉnh | Cần cho task | Đề xuất | Rủi ro |
|---|---|---|---|
| UI chọn giờ **theo từng ngày** | Bắt buộc (yêu cầu chính) | Thay `Wrap` 7 `FilterChip` bằng danh sách 7 dòng dạng `ListTile`/card, mỗi dòng: tên ngày + `Switch` bật/tắt riêng + giờ đã chọn (bấm mở `showTimePicker` cho riêng ngày đó) | Trung bình — 7 dòng thay vì 1 hàng chip ngắn, chiều cao nội dung tăng đáng kể, cần quyết định bottom sheet (`isScrollControlled` đã có) có đủ hay nên chuyển route riêng |
| **Quyết định UI cần chốt trước khi code**: giữ BottomSheet hay chuyển route `go_router` full-screen | Ảnh hưởng trực tiếp cách trình bày 7 dòng + "hiện đại, dễ dùng" | Đề xuất chuyển sang **full-screen** (route `go_router` mới, ví dụ `/settings/reminders`) — 7 dòng cấu hình + mô tả + trạng thái quyền cần nhiều không gian dọc hơn BottomSheet co giãn theo nội dung; full-screen cũng dễ áp dụng bố cục "hiện đại" (header, section, card) hơn modal | Trung bình — đây là thay đổi kiến trúc điều hướng (route mới), khác quyết định "không thêm route" đã chốt ở task trước; cần user xác nhận lại (xem Open Questions) |
| Thẩm mỹ "hiện đại" | Yêu cầu trực tiếp nhưng mơ hồ (không có mockup) | Kiểm tra `docs/artifact-design/` xem có mockup nào gần đúng ý (mockup hiện tại **chưa có file nào cho màn Cài đặt/nhắc ôn tập** — đã glob không thấy) trước khi tự thiết kế; nếu không có, áp dụng card `AppColors.panel2` + `border` + icon + spacing nhất quán với `_PermissionDeniedPrompt` hiện tại làm điểm khởi đầu | Trung bình — "hiện đại, dễ dùng" là yêu cầu định tính, dễ lệch kỳ vọng nếu không có mockup hoặc ví dụ tham chiếu cụ thể từ user trước khi code |
| Hiển thị nhanh tổng quan (ví dụ "6/7 ngày đang bật, trung bình 20:00") | Không bắt buộc, tăng UX | Thêm dòng tóm tắt ở đầu bottom sheet/màn hình | Thấp — có thể để ở phase sau nếu muốn giảm scope |
| Ghi chú giới hạn Windows | Giữ nguyên | Không đổi | — |

## Backend/Service-layer Gap Analysis

*(Dự án offline-first, không backend server — "backend" ở đây tương đương tầng service/data local: `ReminderSettingsNotifier` + `NotificationService`.)*

**Phát hiện quan trọng có lợi:** kiến trúc lên lịch hiện tại **đã sẵn N
lịch độc lập theo từng thứ** (`id = 2001 + weekday`, mỗi thứ 1
`zonedSchedule` riêng) — đây chính là nền tảng cần thiết để hỗ trợ giờ
riêng theo ngày, khác với tình huống ở task trước (`05-`) khi phải đổi
từ 1-lịch sang N-lịch. Lần này **không cần đổi cơ chế lên lịch ở tầng
plugin**, chỉ cần đổi input truyền vào (giờ/phút giờ đây đi kèm theo
từng `weekday` thay vì 1 cặp giờ/phút dùng chung cho toàn bộ tập hợp).

| Tầng | Trạng thái hiện tại | File/Module | Khoảng trống |
|---|---|---|---|
| Model cấu hình | `ReminderSettings { enabled, hour, minute, weekdays: Set<int> }` | `lib/data/services/reminder_settings_provider.dart` | Đổi thành `ReminderSettings { enabled, perDay: Map<int weekday, DayReminder> }` với `DayReminder { bool enabled, int hour, int minute }` (hoặc tương đương) — thay đổi cấu trúc, không phải thêm field |
| Persistence (`shared_preferences`) | 4 key phẳng: `daily_reminder_enabled` (bool), `daily_reminder_hour`/`daily_reminder_minute` (int dùng chung), `daily_reminder_weekdays` (`List<String>` qua `setStringList`) | `reminder_settings_provider.dart` | Không còn lưu được bằng key phẳng đơn giản cho "giờ theo từng ngày" — cần đổi sang **JSON encode 1 key duy nhất** (ví dụ `daily_reminder_per_day` lưu chuỗi JSON `{"1": {"enabled": true, "hour": 19, "minute": 0}, ...}`) qua `SharedPreferences.setString`/`getString` + `dart:convert`, hoặc 21 key rời (`reminder_1_enabled`, `reminder_1_hour`... x7) — quyết định cụ thể ở task-plan |
| Migration dữ liệu cũ | Không áp dụng (tính năng mới) | — | **Áp dụng ở đây**: user đã cấu hình theo mô hình cũ (`daily_reminder_hour/minute` dùng chung + `weekdays`) cần được đọc và quy đổi 1 lần sang mô hình mới khi nâng cấp app, tránh mất cấu hình đã lưu — đây là khoảng trống thật sự cần xử lý, không có sẵn cơ chế migration nào trong `reminder_settings_provider.dart` hiện tại |
| `NotificationService.scheduleWeeklyReminders` | Nhận `{hour, minute, Set<int> weekdays}` — áp 1 cặp giờ/phút cho toàn bộ `weekdays` khi gọi `zonedSchedule` theo từng thứ | `lib/data/services/notification_service.dart` | Đổi signature nhận **danh sách/map (weekday → giờ/phút/bật-tắt)** thay vì 1 cặp giờ/phút dùng chung + tập hợp thứ tách rời — vòng lặp lên lịch nội bộ giữ nguyên cơ chế `id = 2001 + weekday`, chỉ đổi nguồn `hour`/`minute` truyền vào mỗi lần gọi `zonedSchedule` (lấy theo từng ngày thay vì 1 giá trị chung) |
| `NotificationService.cancelAllReminders` | Huỷ toàn bộ `id` 2002–2008 | không đổi | Không đổi — vẫn dùng nguyên khi tắt công tắc tổng |
| Khởi tạo lúc mở app | Đọc `ReminderSettings` (mô hình cũ) rồi gọi `scheduleWeeklyReminders` | `lib/main.dart` | Cần đổi theo model mới; đây là nơi migration dữ liệu cũ (nếu chọn hướng migrate) nên chạy trước khi lên lịch lần đầu sau khi cập nhật app |

## Provider/Service Contract (quy đổi từ API Impact)

| Item | Value |
|---|---|
| Tên | `ReminderSettingsNotifier` (Riverpod `Notifier<ReminderSettings>`) — giữ nguyên tên, đổi shape state bên trong |
| Provider | `reminderSettingsProvider` — không đổi |
| Đọc | `ref.watch(reminderSettingsProvider)` → `ReminderSettings` mới, dạng `{ enabled: bool, perDay: Map<int, DayReminder> }` |
| Ghi | Đề xuất API mới: `ref.read(reminderSettingsProvider.notifier).updateDay(weekday, {bool? enabled, int? hour, int? minute})` (ghi 1 ngày) + giữ `update({bool? enabled})` cho công tắc tổng — cụ thể hoá ở task-plan |
| Request params | `weekday: int (1-7)`, `enabled: bool`, `hour: int (0-23)`, `minute: int (0-59)` — theo từng lời gọi (1 ngày/lần), khác bản cũ ghi cả tập hợp thứ cùng lúc |
| Response (state trả về) | `ReminderSettings` mới sau khi ghi, UI đọc lại qua `ref.watch` |
| Validation | `hour`/`minute` đảm bảo hợp lệ bởi `showTimePicker`; không có ràng buộc nghiệp vụ phức tạp khác |
| Business error | Không áp dụng |
| Lỗi hệ thống cần xử lý | Kế thừa nguyên trạng: quyền `POST_NOTIFICATIONS` bị từ chối → lịch vẫn tạo được (không lỗi) nhưng không hiện thông báo thật, đã có `_PermissionDeniedPrompt` xử lý ở tầng UI |
| Auth/permission | Không áp dụng (app 1 người dùng, không role) |
| Frontend caller | UI mới (BottomSheet làm mới hoặc màn full-screen — quyết định ở task-plan) |
| Backend handler | `ReminderSettingsNotifier` (sửa) → `NotificationService.instance.scheduleWeeklyReminders()` (sửa signature) / `cancelAllReminders()` (không đổi) |

## Risk Analysis

- [x] UI incomplete — UI hiện tại (`DailyReminderSheet`) không hỗ trợ giờ riêng theo ngày, phải viết lại phần lớn, có thể cả đổi loại điều hướng (BottomSheet → route)
- [ ] API contract unclear — không áp dụng (local only), nhưng Provider/Service Contract cần cụ thể hoá ở task-plan (API ghi theo ngày vs ghi cả object)
- [ ] DB schema unclear — không áp dụng (không dùng SQLite cho cấu hình)
- [ ] Permission rule unclear — không áp dụng, cơ chế đã có sẵn và không đổi
- [x] Existing flow may be affected — đổi cấu trúc `ReminderSettings` là **breaking change** cho toàn bộ chỗ đang đọc field `hour`/`minute` cũ (`daily_reminder_sheet.dart`, `main.dart`); bắt buộc phải xử lý migration dữ liệu `shared_preferences` cũ, nếu không user nâng cấp app sẽ mất cấu hình đã lưu (hoặc tệ hơn, đọc lỗi/exception nếu không có `try/catch` khi parse)
- [x] Manual verification required — kế thừa đúng khó khăn đã ghi ở task trước (`05-`, `INT-02`): verify lên lịch thật theo từng ngày+giờ riêng cần vài ngày thật hoặc đổi giờ/ngày hệ thống trên thiết bị test; lần này còn phải verify riêng từng ngày có giờ khác nhau đều đúng, không bị lẫn giữa các ngày

## Open Questions / TODO

- **Giữ BottomSheet hay chuyển sang route full-screen mới?** — ảnh hưởng
  trực tiếp cách trình bày 7 dòng cấu hình + mức độ "hiện đại" đạt được;
  đề xuất full-screen nhưng cần user xác nhận trước khi vào task-plan
  (xem UI Gap Analysis).
- **"UI hiện đại, dễ dùng" cụ thể là gì?** — yêu cầu định tính, không có
  mockup tham chiếu (`docs/artifact-design/` chưa có file nào cho màn
  này). Cần user cung cấp ảnh/mô tả ví dụ ưa thích, hoặc chấp nhận đề
  xuất "card + spacing theo `AppColors`/`AppFonts` hiện có" làm baseline.
- **Chiến lược migration dữ liệu cũ**: quy đổi cấu hình cũ (1 giờ chung +
  tập hợp thứ) sang mô hình mới (giờ riêng từng thứ) bằng cách áp giờ
  chung cũ cho toàn bộ 7 ngày làm giá trị khởi tạo — cần xác nhận đây là
  hành vi mong muốn, hay chấp nhận reset về mặc định (đơn giản hơn
  nhưng làm mất cấu hình user đã lưu).
- **Có cần giữ công tắc bật/tắt tổng** hay bỏ hẳn, chỉ dùng 7 công tắc
  riêng từng ngày (ngày nào tắt hết thì tương đương tắt tổng)? Ảnh hưởng
  UI Gap Analysis và Provider/Service Contract.
- Định dạng lưu `shared_preferences` cho model mới (1 key JSON string
  hay nhiều key rời) — quyết định cụ thể ở task-plan.
