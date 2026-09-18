# CSB Vocab App — Spec Change History (spec_history)

Lịch sử thay đổi đặc tả. Mỗi entry: bối cảnh → nội dung thay đổi → tài liệu bị ảnh hưởng → điểm chờ xác nhận.

---

## [IMPL-030] 2026-09-18 — Giờ nhắc riêng theo từng ngày, chuyển màn Cài đặt sang full-screen

**Người yêu cầu:** User · **Người thực hiện:** Claude

### Nội dung

Yêu cầu ban đầu: *"tôi muốn setting thông báo của giờ theo từng ngày,
UI hiện đại dễ dùng"* — mở rộng trực tiếp từ tính năng nhắc ôn tập đã
implement ở `05-dat-gio-nhac-on-tap/` (IMPL-018 đến IMPL-020, IMPL-026),
đảo ngược quyết định D3 đã chốt trước đó ("1 giờ chung cho mọi thứ được
chọn") sang **giờ riêng độc lập cho từng ngày trong tuần**.

Bắt đầu bằng task-analysis (`06-gio-nhac-rieng-theo-ngay/01-analysis.md`),
nêu 4 điểm chờ; user chốt ngay cả 4 rồi yêu cầu implement thẳng (không
qua brainstorm/plan riêng, không làm mockup HTML):

1. **Chuyển từ `BottomSheet` sang route full-screen** (`/settings/reminders`).
2. **UI "hiện đại, dễ dùng"**: tự nghiên cứu — không có mockup tham
   chiếu nào cho màn này trong `docs/artifact-design/` (bộ mockup đó
   còn dùng bảng màu navy/brass aspirational khác `AppColors` thật
   trong code, và giả định bố cục 5-tab có tab "Cài đặt" riêng — mâu
   thuẫn với quyết định D1 cũ là icon trong AppBar, không phải tab).
   Quyết định dùng thẳng design token thật đang chạy trong app
   (`AppColors`/`AppFonts`/`CardTheme` ở `app_theme.dart`) thay vì bám
   theo bộ mockup cũ, tránh lệch thêm với code.
3. **Không migrate dữ liệu cũ — chấp nhận reset về mặc định.**
4. **Giữ công tắc bật/tắt tổng.**

**Thay đổi kiến trúc:**

- `NotificationService.scheduleWeeklyReminders`: đổi tham số từ `{hour,
  minute, Set<int> weekdays}` (1 giờ dùng chung) sang `{Map<int weekday,
  ({int hour, int minute})> dayTimes}` (giờ riêng từng thứ) — vòng lặp
  lên lịch nội bộ (`id = 2001 + weekday`) giữ nguyên, chỉ đổi nguồn
  giờ/phút truyền vào mỗi lần gọi `zonedSchedule`.
- `ReminderSettings`: đổi từ `{enabled, hour, minute, weekdays}` sang
  `{enabled, perDay: Map<int weekday, DayReminder>}` (`DayReminder =
  {enabled, hour, minute}`). Lưu `shared_preferences` bằng **1 khoá JSON
  mới** `reminder_per_day_v2` (khác hẳn 4 khoá phẳng cũ
  `daily_reminder_*`) — đổi tên khoá là chủ đích để user nâng cấp nhận
  đúng giá trị mặc định mới thay vì đọc nhầm dữ liệu cũ sai định dạng
  (đúng quyết định #3, không cần code migrate).
- `ReminderSettingsNotifier`: thêm `setEnabled(bool)` (công tắc tổng) +
  `updateDay(weekday, {enabled, hour, minute})` (ghi từng ngày), thay
  cho `update({enabled, hour, minute, weekdays})` cũ.

**Thay đổi UI/điều hướng:**

- File mới `lib/features/settings/reminder_settings_screen.dart` thay
  hẳn `lib/features/settings/widgets/daily_reminder_sheet.dart` (đã
  xoá) — full-screen: `SwitchListTile` tổng trong `Card` ở đầu, tiếp
  theo 7 `Card`/`ListTile` (1 dòng/thứ) gồm huy hiệu tên ngày (`CircleAvatar`
  đổi màu theo trạng thái bật/tắt), giờ đã chọn hiển thị mono
  (`AppFonts.mono`, bấm mở `showTimePicker` riêng cho ngày đó), `Switch`
  bật/tắt riêng ngày — disable khi công tắc tổng tắt. Giữ nguyên
  `_PermissionDeniedPrompt` (quyền thông báo bị từ chối) từ bản cũ.
- Route mới `/settings/reminders` trong `lib/core/router/app_router.dart`.
- `home_shell.dart`: 2 chỗ mở cấu hình (icon `AppBar.actions` mobile +
  nút nav-rail Windows — vẫn ẩn trên Windows như cũ) đổi từ
  `showDailyReminderSheet(context)` sang `context.push('/settings/reminders')`.

`flutter analyze lib/` sạch sau khi sửa (không lỗi/warning mới).

### Tài liệu tạo mới

| File | Nội dung |
|---|---|
| `docs/csb-vocab-analysis/tasks/06-gio-nhac-rieng-theo-ngay/01-analysis.md` | Task-analysis: Requirement Summary, UI/Backend Gap, Provider/Service Contract, Risk Analysis, 4 Open Questions (đã chốt, xem trên) |
| `lib/features/settings/reminder_settings_screen.dart` | Màn full-screen mới thay `DailyReminderSheet` |

### Tài liệu đã cập nhật

| File | Thay đổi |
|---|---|
| `lib/data/services/notification_service.dart` | `scheduleWeeklyReminders` nhận `Map<weekday, {hour, minute}>` thay vì 1 cặp giờ/phút dùng chung |
| `lib/data/services/reminder_settings_provider.dart` | Viết lại `ReminderSettings`/`ReminderSettingsNotifier` theo model giờ riêng từng ngày, đổi khoá `shared_preferences` sang `reminder_per_day_v2` (JSON, không migrate khoá cũ) |
| `lib/core/router/app_router.dart` | Thêm route `/settings/reminders` |
| `lib/features/home/home_shell.dart` | 2 điểm mở cấu hình đổi sang `context.push('/settings/reminders')` |

### File đã xoá

| File | Lý do |
|---|---|
| `lib/features/settings/widgets/daily_reminder_sheet.dart` | Thay hẳn bởi `reminder_settings_screen.dart` (full-screen) |

### Điểm chờ xác nhận còn mở

Không phát sinh câu hỏi mới — cả 4 điểm treo ở task-analysis đã được
user chốt trực tiếp trước khi implement (xem trên). Ghi nhận 1 điểm
nhỏ chưa xử lý: khoá `shared_preferences` cũ (`daily_reminder_enabled`/
`hour`/`minute`/`weekdays`) không còn được đọc nhưng cũng chưa bị xoá
khỏi máy user cũ — rác vô hại (không tốn bộ nhớ đáng kể), có thể dọn ở
lần sửa `reminder_settings_provider.dart` tiếp theo nếu cần.

Chưa verify tay trên thiết bị thật (lên lịch theo giờ riêng từng ngày
khó test tự động, kế thừa đúng khó khăn đã ghi ở IMPL-020/INT-02) — cần
làm trước khi coi task này hoàn tất.

---

## [IMPL-029] 2026-09-17 — Audit toàn bộ doc màn hình còn lại (01/05/06/07/00_Overview)

**Người yêu cầu:** User · **Người thực hiện:** Claude (4 subagent song song kiểm tra, Claude tự sửa)

### Nội dung

Theo yêu cầu trực tiếp "kiểm tra cho tôi doc từng màn hình" — dùng 4
subagent song song đối chiếu `01_Splash.md`, `05_Review.md`,
`07_Home-shell.md`, `00_Overview.md` với code thật (3 file
`02_Search.md`/`04_Translate.md`/`06_Settings.md` đã kiểm tra thủ công ở
[IMPL-028]). Kết quả: lệch nặng hơn dự kiến, viết lại toàn bộ 4 file.

- **`05_Review.md` (nặng nhất)**: bản cũ mô tả "1 kiểu: lật thẻ tự chấm"
  4 mức Quên/Khó/Tốt/Dễ — **đã bị bỏ hoàn toàn**, thay bằng ôn tập khách
  quan (trắc nghiệm + gõ chữ, hệ thống tự chấm đúng/sai,
  `ReviewResultScreen` riêng, giới hạn 4 câu/phiên, hàng đợi theo từng
  bộ từ điển, banner "trễ hạn 7+ ngày"/chip "từ khó") — không có dòng
  nào trong nội dung cũ còn đúng ngoài thuật toán SM-2 gốc và 2 hàm truy
  vấn cơ bản (`dueToday`/`markLearned`). `submitReview` cũng không còn
  ghi `review_logs` (bảng đã bỏ từ [IMPL-016], bản cũ vẫn ghi có ghi).
- **`07_Home-shell.md`**: bản cũ ghi 5 tab (có "Ôn tập", "Cài đặt") —
  thực tế chỉ 4 tab (không có 2 tab đó). Badge số từ đến hạn gắn sai vào
  "Ôn tập" thay vì "Từ điển của tôi". Nhầm `NavigationRail`/`NavigationBar`
  của Flutter — thực tế là widget tự dựng. Desktop không dùng
  `Scaffold.appBar` (dùng `_PageHeader` riêng) — bản cũ ghi sai là dùng
  chung `AppBar` cho cả 2 layout. Thiếu hẳn 2 tính năng có thật: nút "Cài
  đặt nhắc ôn tập" (ẩn trên Windows) và badge Online/Offline.
- **`06_Settings.md` (phát hiện thêm khi audit lại chính bản mình vừa
  sửa ở [IMPL-028])**: `settings_screen.dart` và `theme_mode_provider.dart`
  — nguồn gốc toàn bộ nội dung "chọn Sáng/Tối" — **đã bị xoá khỏi code**,
  `app.dart` dùng theme cố định. Viết lại: bỏ hẳn mục theme, giữ nguyên
  mục "Nhắc ôn tập" đã thêm ở [IMPL-028] (vẫn đúng), thêm cảnh báo rõ về
  việc màn Cài đặt không còn tồn tại.
- **`01_Splash.md` (nhẹ)**: vẫn ghi ảnh slide là placeholder chờ khách
  cung cấp — thực tế đã dùng ảnh CSB thật từ lâu ([IMPL-009]).
- **`00_Overview.md`**: 2 mục lớn "Bộ từ điển N-N" và "Section/Chapter
  dạng bài báo" từng ghi "[ĐỊNH HƯỚNG MỚI — CHƯA CODE]" nhưng **đã code
  xong từ trước** (`lib/features/my_dictionaries/`,
  `lib/features/lessons/` với `ChapterContentScreen` đọc PDF) — relabel
  lại thành `[ĐÃ CODE]`. Sửa: `vocab.db` không còn read-only (mở
  read-write cho bảng `dictionaries`); LibreTranslate (dự kiến ban đầu)
  → MyMemory (thực tế dùng, đã đổi từ [IMPL-013] nhưng tài liệu này
  chưa cập nhật theo); "5 tab" → "4 tab"; mục "Cài đặt" cập nhật theo
  phát hiện ở `06_Settings.md`.

### Tài liệu đã cập nhật

| File | Thay đổi |
|---|---|
| `docs/csb-vocab-analysis/01_Splash.md` | Sửa đoạn ảnh placeholder |
| `docs/csb-vocab-analysis/05_Review.md` | Viết lại toàn bộ cho khớp ôn tập trắc nghiệm/gõ chữ |
| `docs/csb-vocab-analysis/06_Settings.md` | Viết lại — bỏ mục theme đã xoá, giữ mục Nhắc ôn tập |
| `docs/csb-vocab-analysis/07_Home-shell.md` | Viết lại toàn bộ cho khớp 4 tab + các tính năng còn thiếu |
| `docs/csb-vocab-analysis/00_Overview.md` | Relabel 2 mục lớn CHƯA CODE → ĐÃ CODE, sửa LibreTranslate/vocab.db/5 tab/Cài đặt |

### Điểm chờ xác nhận còn mở

| # | Câu hỏi |
|---|---|
| Q-CSB-11 | Màn "Cài đặt" (chọn Sáng/Tối, `settings_screen.dart`/`theme_mode_provider.dart`) đã biến mất khỏi code mà không có entry nào trong `spec_history.md` ghi lại quyết định này — cố ý gỡ bỏ hay mất do lỗi merge/rebase? Nếu cố ý, có cần viết lại tính năng này hay chính thức đóng SCR-06/FR-7? |

Kế thừa Q-CSB-10 từ [IMPL-028] (chưa viết tài liệu SCR riêng cho "Từ
điển của tôi") — vẫn chưa làm trong đợt audit này, cùng lý do đã nêu (cần
1 lượt phân tích đầy đủ riêng).

---

## [IMPL-028] 2026-09-17 — Cập nhật `docs/csb-vocab-analysis/` cho khớp code thật

**Người yêu cầu:** User · **Người thực hiện:** Claude

### Nội dung

Theo yêu cầu trực tiếp "cập nhật specs lại cho tôi" — rà lại toàn bộ tài
liệu phân tích màn hình, phát hiện độ lệch với code thật lớn hơn dự kiến
ban đầu (hỏi lại user, chọn phạm vi "Toàn bộ"):

- `02_Search.md` từng ghi chế độ Online là "[CHƯA CODE]" — **sai với
  thực tế**, tính năng này đã code từ trước, chỉ chưa cập nhật tài liệu.
  Viết lại toàn bộ mục Hành vi/Chế độ Online/Truy vấn dữ liệu cho khớp
  code thật hôm nay, gồm cả debounce + phân trang mới thêm
  ([IMPL-023]/[IMPL-024]).
- `04_Translate.md` cập nhật cho luồng online-first mới ([IMPL-025]).
- `06_Settings.md` **thiếu hẳn** mục "Nhắc ôn tập" (đặt giờ + thứ trong
  tuần, implement từ [IMPL-018]-[IMPL-020], gia cố quyền thông báo ở
  [IMPL-026]) — chưa từng được ghi vào tài liệu này dù đã có code. Thêm
  mới toàn bộ mục này.
- `90_Traceability-matrix.md`: bỏ 2 dòng `review_logs`/`search_history`
  (đã bỏ hẳn khỏi schema từ [IMPL-016], bảng vẫn ghi như còn tồn tại);
  sửa 2 dòng "Bộ từ điển cá nhân"/"Tra cứu Online" từ ❌ sang ✅ (đã có
  code, tài liệu ghi sai).
- `README.md`: cập nhật bảng trạng thái (SCR-04 done, "Bộ từ vựng cá
  nhân" đã có code), bump version log.
- **`03_Lessons-by-chapter.md` (SCR-03) — không sửa**: ban đầu định gán
  nhầm phần phân trang "Chi tiết bộ từ điển" vào đây, rà lại phát hiện
  file này chỉ nói về `lib/features/lessons/` (duyệt theo chương giáo
  trình gốc) — hoàn toàn khác `lib/features/my_dictionaries/` (nơi thực
  sự có phân trang mới thêm). Đã sửa lại đúng chỗ trong `spec_history.md`
  ([IMPL-023]) thay vì viết nhầm vào SCR-03.

**Việc cố tình không làm trong đợt này** (phát sinh trong lúc rà soát,
nhưng vượt quá phạm vi "cập nhật theo thay đổi trong phiên" — cần 1 lượt
phân tích riêng, đầy đủ, thay vì viết vội):

- Chưa viết tài liệu SCR mới cho "Từ điển của tôi"
  (`lib/features/my_dictionaries/`: danh sách bộ, chi tiết bộ, tự thêm
  từ, tự điền dữ liệu) — feature này tồn tại đầy đủ trong code nhưng
  **chưa từng có tài liệu phân tích riêng nào**, kể cả trước phiên này.
- Chưa rà lại `00_Overview.md`, `05_Review.md`, `07_Home-shell.md`,
  `91_DB-design-new-model.md` — có thể còn độ lệch tương tự nhưng chưa
  kiểm tra kỹ trong đợt này (chỉ đọc lướt để xác nhận 2 điểm liên quan
  trực tiếp tới các mục đã sửa).

### Tài liệu đã cập nhật

| File | Thay đổi |
|---|---|
| `docs/csb-vocab-analysis/02_Search.md` | Viết lại mục Hành vi/Chế độ Online/Truy vấn dữ liệu cho khớp code thật |
| `docs/csb-vocab-analysis/04_Translate.md` | Cập nhật luồng online-first ([IMPL-025]) |
| `docs/csb-vocab-analysis/06_Settings.md` | Thêm mới mục "Nhắc ôn tập — đặt giờ + thứ trong tuần" |
| `docs/csb-vocab-analysis/90_Traceability-matrix.md` | Bỏ `review_logs`/`search_history`; sửa 2 dòng ❌→✅ |
| `docs/csb-vocab-analysis/README.md` | Cập nhật bảng trạng thái, bump version log lên 1.5 |

### Điểm chờ xác nhận còn mở

| # | Câu hỏi |
|---|---|
| Q-CSB-10 | "Từ điển của tôi" (`lib/features/my_dictionaries/`) chưa có tài liệu SCR phân tích riêng dù đã có code đầy đủ (danh sách bộ, chi tiết bộ có phân trang, tự thêm từ, tự điền dữ liệu) — có cần viết 1 tài liệu SCR-08 riêng cho màn này không, và nếu có thì ưu tiên khi nào? |

---

## [IMPL-027] 2026-09-17 — CI build tự động cho iOS/Windows/Android + nhánh release

**Người yêu cầu:** User · **Người thực hiện:** Claude

### Nội dung

Máy dev là Windows, không có Xcode để tự verify build iOS, và bản Windows
build ra là 1 thư mục (exe + DLL + data) không tiện gửi khách. Thêm 3
GitHub Actions workflow (`.github/workflows/`), mỗi cái build + đóng gói
thành 1 artifact tải về được:

- **`ios-build.yml`** (`macos-latest`) — `flutter build ios --no-codesign`
  (chỉ verify build pass, không ký code) rồi đóng gói `Payload/Runner.app`
  thành `.ipa` upload artifact — để tự ký lại bằng Apple ID cá nhân qua
  Sideloadly/AltStore (miễn phí, hết hạn 7 ngày) hoặc Apple Developer
  Program ($99/năm, hiệu lực 1 năm) khi cần cài lâu dài.
  - Phát sinh lỗi thật khi chạy thử: `flutter_onnxruntime` yêu cầu tối
    thiểu iOS 16.0 (xác nhận: **mọi** version đã publish của package này,
    kể cả bản 1.0.0 đầu tiên, đều yêu cầu 16.0 — không phải lỗi cấu hình
    của app) nhưng `ios/Runner.xcodeproj/project.pbxproj` vẫn đang set
    13.0 → nâng `IPHONEOS_DEPLOYMENT_TARGET` lên 16.0 ở cả 3 build config
    (Debug/Release/Profile). Hệ quả: app không cài được trên iOS < 16.
- **`windows-build.yml`** (`windows-latest`) — `flutter build windows
  --release` rồi đóng gói bằng **Inno Setup** thành 1 file
  `csb-vocab-app-setup-<version>.exe` duy nhất (cài vào Program Files, có
  shortcut Start Menu, uninstaller) — script tại
  `windows/installer/csb_vocab_app.iss`.
  - 2 lỗi toolchain phát sinh khi chạy thử, cả 2 đều do phiên bản công cụ
    mới trên runner chứ không phải lỗi code app: (1) `pdfx` tải `pdfium`
    qua 1 sub-project CMake khai `cmake_minimum_required` quá cũ, CMake
    4.x trên runner từ chối thẳng — fix bằng biến môi trường
    `CMAKE_POLICY_VERSION_MINIMUM=3.5` (cơ chế chính thức CMake ≥3.31 cho
    đúng tình huống này); (2) `permission_handler_windows` dùng C++/WinRT
    (`winrt::fire_and_forget`) kéo theo header `<experimental/coroutine>`
    cũ, MSVC mới trên runner nâng cảnh báo này thành lỗi cứng — fix bằng
    biến môi trường `CL=/D_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS`
    (MSVC tự đọc biến `CL` cho mọi lệnh `cl.exe`, không cần sửa CMake của
    plugin bên thứ 3).
- **`android-build.yml`** (`ubuntu-latest`) — `flutter build apk
  --release` upload thẳng `app-release.apk` làm artifact. Pass ngay lần
  đầu, không gặp lỗi toolchain nào. Ký bằng debug key (cấu hình mặc định
  có sẵn từ trước trong `android/app/build.gradle.kts`, chưa đổi) — dùng
  để cài thử/gửi khách được, **chưa nộp được lên Google Play** (cần
  keystore release riêng, ngoài phạm vi việc này).

Cả 3 workflow trigger trên `push`/`pull_request` vào `main` + thủ công
qua `workflow_dispatch`.

Ngoài ra, tạo nhánh **`release/phase-1-2026-09`** từ `main` theo yêu cầu
trực tiếp — quy ước đặt tên nhánh trong `.claude/rules/git-conventions.md`
chỉ định nghĩa cho `feature.<type>.<mô tả>`, không có mục riêng cho nhánh
release nên đặt theo style tương tự (tiếng Anh, chữ thường,
`release/<mô tả>`).

### Tài liệu tạo mới

| File | Nội dung |
|---|---|
| `.github/workflows/ios-build.yml` | Build + đóng gói `.ipa` chưa ký trên `macos-latest` |
| `.github/workflows/windows-build.yml` | Build + đóng gói installer `.exe` (Inno Setup) trên `windows-latest` |
| `.github/workflows/android-build.yml` | Build `.apk` (debug-signed) trên `ubuntu-latest` |
| `windows/installer/csb_vocab_app.iss` | Script Inno Setup — cấu hình cài đặt/shortcut/uninstaller |

### Tài liệu đã cập nhật

| File | Thay đổi |
|---|---|
| `ios/Runner.xcodeproj/project.pbxproj` | `IPHONEOS_DEPLOYMENT_TARGET`: 13.0 → 16.0 (cả 3 build config) |

### Điểm chờ xác nhận còn mở

| # | Câu hỏi |
|---|---|
| Q-CSB-08 | Nâng min iOS lên 16.0 (bắt buộc bởi `flutter_onnxruntime`) có chấp nhận được lâu dài không, hay cần tính phương án khác (bỏ dịch on-device trên iOS, tự build lại ONNX Runtime binary min-OS thấp hơn...) nếu sau này cần hỗ trợ máy iOS cũ? |
| Q-CSB-09 | Bản Android/Windows hiện chỉ ký bằng debug key/không ký — có cần thiết lập keystore release thật + ký code Windows (certificate) khi tiến tới bản phát hành chính thức cho khách hàng, không chỉ bản test? |

---

## [IMPL-026] 2026-09-16 — Gật quyền thông báo trước khi cho đặt lịch nhắc ôn tập

**Người yêu cầu:** User · **Người thực hiện:** Claude

### Nội dung

Phát hiện qua báo cáo trực tiếp: nếu user từ chối quyền thông báo hệ
thống, `DailyReminderSheet` (modal đặt giờ/thứ nhắc ôn tập, implement từ
plan [IMPL-020]) vẫn cho đặt lịch bình thường — lịch được lưu trong app
nhưng **không bao giờ hiện thông báo thật ra ngoài**, không có gì báo cho
user biết vì sao.

Thêm dependency `permission_handler` (mới, chưa có trong `pubspec.yaml`
trước đó). `NotificationService.areNotificationsEnabled()` kiểm tra
`Permission.notification.status` (Windows luôn trả `true` — không có khái
niệm quyền thông báo kiểu Android/iOS trong luồng này, và nút mở
`DailyReminderSheet` vốn đã bị ẩn trên Windows từ trước). Provider
`notificationPermissionGrantedProvider` (`FutureProvider<bool>`) gate UI:
quyền bị từ chối → `DailyReminderSheet` thay hẳn phần điều khiển giờ/thứ
bằng `_PermissionDeniedPrompt` (giải thích + nút "Mở Cài đặt" gọi
`openAppSettings()`). `DailyReminderSheet` đổi sang
`ConsumerStatefulWidget` + `WidgetsBindingObserver` để tự
`ref.invalidate(notificationPermissionGrantedProvider)` khi app resume —
user cấp quyền xong quay lại app không cần tự đóng/mở lại sheet.

### Tài liệu đã cập nhật

| File | Thay đổi |
|---|---|
| `pubspec.yaml` | Thêm `permission_handler: ^11.3.1` |
| `lib/data/services/notification_service.dart` | Thêm `areNotificationsEnabled()` |
| `lib/data/services/reminder_settings_provider.dart` | Thêm `notificationPermissionGrantedProvider` |
| `lib/features/settings/widgets/daily_reminder_sheet.dart` | Chuyển `ConsumerWidget` → `ConsumerStatefulWidget` + `WidgetsBindingObserver`; thêm `_PermissionDeniedPrompt` |

### Điểm chờ xác nhận còn mở

Không phát sinh câu hỏi mới.

---

## [IMPL-025] 2026-09-16 — Đổi hướng Dịch (FR-4) lần 2: ưu tiên Online khi có mạng

**Người yêu cầu:** User · **Người thực hiện:** Claude

### Nội dung

Theo phản ánh trực tiếp: model on-device (opus-mt, [IMPL-017]) độ chính
xác còn thấp so với dịch vụ online thật. Trong khi đó `DictionaryApiService`
(dùng cho Tra cứu — SCR-02) đã có sẵn tích hợp **MyMemory Translation
API** miễn phí — tái dùng luôn cho màn Dịch thay vì thêm dịch vụ mới:

- `DictionaryApiService._translate` đổi thành method public
  `translate(text, {from, to})`.
- `translateProvider` (`translation_providers.dart`): có mạng
  (`connectivityProvider`) → gọi MyMemory **trước**; chỉ rơi về model
  on-device nếu API lỗi/timeout hoặc không có mạng. Không còn bắt buộc
  tải model trước khi dịch nếu đang online (`canTranslate = downloadState
  is ModelReady || isOnline` ở `translate_screen.dart`).
- Vì `ModelDownloadPrompt` (chặn cả màn, chỉ hiện khi offline + chưa tải)
  giờ bị bỏ qua lúc online, user mất hẳn nút tải model để dùng offline
  sau này — thêm `ModelStatusRow` (widget mới, cố định dưới thanh chọn
  chiều dịch) hiện trạng thái tải/nút Tải khi đang online mà model chưa
  sẵn sàng; tự ẩn khi `ModelReady`.
- Sửa kèm 2 lỗi UI phát hiện qua ảnh chụp: tràn layout ~5px khi bàn phím
  mở (bọc `SingleChildScrollView`) và spinner loading trơ trọi lúc đang
  dịch (đổi thành spinner nhỏ + chữ "Đang dịch…" cùng style placeholder).
- Tách widget dùng chung **`DismissKeyboardOnTap`**
  (`lib/core/widgets/dismiss_keyboard_on_tap.dart`, chạm ra ngoài ô nhập
  để đóng bàn phím) — áp dụng cho cả màn Dịch và "Tự thêm từ mới"
  (trước đó chỉ viết tay riêng cho màn Dịch, "Tự thêm từ mới" chưa có).

### Tài liệu đã cập nhật

| File | Thay đổi |
|---|---|
| `docs/csb-vocab-analysis/04_Translate.md` | Cập nhật lại toàn bộ mục Hành vi/Kiến trúc cho luồng online-first, xem entry này |
| `lib/data/services/dictionary_api_service.dart` | `_translate` → `translate` (public) |
| `lib/data/repositories/translation_providers.dart` | `translateProvider` ưu tiên online |
| `lib/features/translate/translate_screen.dart` | Bỏ ép buộc tải model khi online; thêm `ModelStatusRow` |
| `lib/features/translate/widgets/model_status_row.dart` | Mới |
| `lib/features/translate/widgets/translate_panels.dart` | Sửa tràn layout, loading indicator, dùng `DismissKeyboardOnTap` |
| `lib/core/widgets/dismiss_keyboard_on_tap.dart` | Mới — widget dùng chung |
| `lib/features/my_dictionaries/add_word_screen.dart` | Áp dụng `DismissKeyboardOnTap` |

### Điểm chờ xác nhận còn mở

Không phát sinh câu hỏi mới — kế thừa 2 hạn chế đã ghi ở [IMPL-017]
(model tổng quát không fine-tune thuật ngữ chuyên ngành, greedy decoding
không ổn định tuyệt đối) — nay chỉ còn áp dụng cho nhánh fallback
offline.

---

## [IMPL-024] 2026-09-15 — Sửa UI Tra cứu/Dịch, nén ảnh PDF bài đọc, log lỗi API chi tiết hơn

**Người yêu cầu:** User · **Người thực hiện:** Claude

### Nội dung

Gộp nhiều sửa lỗi/tinh chỉnh UI nhỏ phát hiện qua phản ánh trực tiếp và
ảnh chụp màn hình:

- **Kết quả tra Online trong SCR-02**: đổi vị trí hiện ở **cuối** danh
  sách kết quả (không phải đầu) — giữ nguyên khi phân trang thêm (chèn
  ngay trước phần tử online thay vì `addAll` đơn thuần). Thêm chỉ báo
  loading (`_checkingOnline`) trong lúc đang gọi API online, tránh hiện
  "Không tìm thấy" rồi lại có kết quả ngay sau đó (nhấp nháy mâu thuẫn).
- **Log lỗi Free Dictionary API** (`dictionary_api_service.dart`): thay
  `debugPrint('...— $e')` chung chung bằng log có từ đang tra + loại lỗi
  (`DioExceptionType`) + status code + URL — dễ phân biệt lượt tra nào
  lỗi khi nhiều log liền nhau.
- **Nén ảnh trong `assets/pdf/section-1-unit-1.pdf` và
  `section-1-unit-3.pdf`** (PyMuPDF, giảm 35-40%) — chỉ thay ảnh nếu bản
  nén thực sự nhỏ hơn bản gốc, và bắt buộc `use_objstms=1` lúc lưu (thiếu
  cờ này thì resave lại làm phình file dù từng ảnh đã nhỏ hơn).
- **Status bar Android** đổi nền trắng + icon tối (`SystemUiOverlayStyle`
  trong `AppTheme.appBarTheme`) thay vì mặc định trong suốt tràn lên nền
  navy của AppBar.

### Tài liệu đã cập nhật

| File | Thay đổi |
|---|---|
| `lib/features/search/search_screen.dart` | Vị trí kết quả online, loading indicator |
| `lib/data/services/dictionary_api_service.dart` | Log lỗi chi tiết hơn |
| `assets/pdf/section-1-unit-1.pdf`, `section-1-unit-3.pdf` | Nén ảnh |
| `lib/core/theme/app_theme.dart` | `systemOverlayStyle` cho status bar |

### Điểm chờ xác nhận còn mở

Không phát sinh câu hỏi mới.

---

## [IMPL-023] 2026-09-15 — Tối ưu hiệu năng: debounce tìm kiếm, phân trang Tra cứu + Chi tiết bộ từ điển

**Người yêu cầu:** User · **Người thực hiện:** Claude

### Nội dung

Sau khi gộp thêm ~31.000 từ từ `Tu_dien.pdf` vào `vocab.db` ([IMPL-021]),
tốc độ tra cứu/duyệt danh sách chậm hẳn đi — 2 nguyên nhân:

1. **Gõ tới đâu query DB ngay tới đó** (không debounce) — thêm debounce
   300ms (`search_screen.dart`) trước khi gọi `VocabRepository.search()`.
2. **Tải hết 1 lần** — cả kết quả tìm kiếm (trước đó cắt cứng `LIMIT 50`,
   không phân trang thêm được) lẫn danh sách từ trong 1 bộ từ điển
   (`DictionaryDetailScreen`, có thể lên tới ~32.000 từ với bộ "Military
   Dictionary" mới) đều nạp toàn bộ vào `ListView` cùng lúc.

Thêm phân trang kiểu cuộn vô hạn (infinite scroll, ngưỡng gần cuối danh
sách tự nạp thêm) cho cả 2 màn — dùng chung pattern
`ScrollController` + `_loadGeneration` (bộ đếm tăng dần, chặn kết quả
async trễ từ 1 lượt tải cũ ghi đè lên danh sách đã bị reset bởi lượt tải
mới hơn, vd khi user đổi hướng tìm kiếm ngay khi 1 request cũ chưa kịp
trả về). `VocabRepository.search()`/`wordsByChapterPage()` thêm tham số
`limit`/`offset`; `ORDER BY` thêm `w.id` làm tie-breaker cuối để đảm bảo
thứ tự ổn định giữa các trang (nhiều headword trùng nhau, vd "RA", có thể
đổi thứ tự giữa 2 lần gọi nếu không có tie-breaker).

Benchmark trước/sau (trang đầu, bộ 31.000 từ): 251ms → 15ms.

### Tài liệu đã cập nhật

| File | Thay đổi |
|---|---|
| `docs/csb-vocab-analysis/02_Search.md` | Thêm debounce + phân trang vào mục Hành vi/Truy vấn dữ liệu, xem entry này |
| `lib/data/repositories/vocab_repository.dart` | `search()` thêm `offset`; thêm `wordsByChapterPage()`, `countWordsByChapter()` |
| `lib/features/search/search_screen.dart` | Debounce 300ms, bỏ `searchProvider`, quản lý phân trang bằng state cục bộ |
| `lib/features/my_dictionaries/dictionary_detail_screen.dart` | Quản lý phân trang bằng state cục bộ (trước đó dùng `chapterWordsProvider` tải hết 1 lần) |
| `lib/data/repositories/vocab_providers.dart` | Xoá `searchProvider`/`SearchQuery` (không còn dùng) |

### Điểm chờ xác nhận còn mở

Không phát sinh câu hỏi mới — đã tự rà lại 2 lần theo yêu cầu trực tiếp
(phát hiện + sửa 1 race condition giữa `_loadInitial`/`_loadMore` và 1
race condition giữa debounce/đổi hướng tìm kiếm, cả 2 đã fix trước khi
merge).

---

## [IMPL-022] 2026-09-15 — Sửa UI hiển thị từ + bug "Tự điền" ở Tự thêm từ mới

**Người yêu cầu:** User · **Người thực hiện:** Claude

### Nội dung

2 sửa lỗi UI phát hiện qua ảnh chụp màn hình gửi trực tiếp:

- **`WordDetailContent`**: bỏ khung "NO PHOTO" hiện mặc định khi từ không
  có ảnh (phần lớn ~31.000 từ gộp từ `Tu_dien.pdf` không có ảnh minh
  hoạ) — chỉ hiện khối ảnh khi `word.imagePath` thực sự có giá trị. Nút
  "Thêm vào bộ" đổi từ full-width cố định sang giới hạn tối đa 360px
  trên pane rộng (desktop), vẫn full-width trên mobile hẹp.
- **`AddWordScreen` ("Tự thêm từ mới")**: bug — bấm "Tự điền" tra ra dữ
  liệu theo từ A, rồi đổi ý sửa lại ô nguồn thành từ B, nhưng
  nghĩa/phiên âm/loại từ hiển thị **vẫn giữ nguyên của từ A** (chỉ mất
  liên kết `_linkedWordId`, không xoá dữ liệu suy ra sai). Thêm
  `_autofillSourceDirection` theo dõi ô nào là nguồn của lần tự điền gần
  nhất — sửa ô đó sau khi đã tự điền thì xoá luôn 3 ô suy ra
  (nghĩa/phiên âm/loại từ), kèm snackbar giải thích. Thêm: nút "Tự điền"
  tự disable khi cả 2 ô Từ tiếng Anh + Nghĩa tiếng Việt đã có chữ (không
  còn gì để tự điền).

### Tài liệu đã cập nhật

| File | Thay đổi |
|---|---|
| `lib/features/vocab/word_widgets.dart` | Ẩn khung ảnh khi không có `imagePath`; giới hạn width nút "Thêm vào bộ" |
| `lib/features/my_dictionaries/add_word_screen.dart` | `_autofillSourceDirection`, `_onWordEdited`/`_onMeaningEdited`, disable nút "Tự điền" khi cả 2 ô đã điền |

### Điểm chờ xác nhận còn mở

Không phát sinh câu hỏi mới.

---

## [IMPL-021] 2026-09-14 — Gộp từ điển scan `Tu_dien.pdf` (Cảnh sát biển/quân sự) vào `vocab.db`

**Người yêu cầu:** User · **Người thực hiện:** Claude (+ 1 phiên song song, cùng hội thoại)

### Nội dung

`Tu_dien.pdf` (977 trang, từ điển quân sự/hàng hải scan) được transcribe
bằng đọc-trực-tiếp-bằng-vision (không dùng OCR, để phân biệt chính xác
chữ đậm = tiếng Anh / chữ nhạt = nghĩa tiếng Việt) qua nhiều subagent
chạy song song — kết quả 2 phần (phần chính + phần phụ lục viết tắt)
được merge thành 1 CSV chuẩn duy nhất (`Tu_dien_full.csv`, 31.997 dòng),
rồi merge tiếp vào `assets/db/vocab.db` thực tế đang dùng trong app:

- Dedup với dữ liệu cũ (so khớp `word` không phân biệt hoa/thường, bỏ
  qua nếu trùng) và dedup nội bộ (trùng cả `word` lẫn `meaning`).
- `image_path` để trống (dữ liệu scan không có ảnh minh hoạ).
- Tạo bộ từ điển mới **"Military Dictionary"** (8 bộ tổng, trước đó 7 —
  6 chương gốc + "Chưa phân loại").
- Backup `vocab.db` bản cũ trước khi ghi đè
  (`docs/db/import/vocab.db.backup-before-tudien-merge`).

Kết quả: 33.019 từ tổng (từ ~2.450 trước đó) — kéo theo nhu cầu tối ưu
hiệu năng tra cứu/duyệt danh sách ở [IMPL-023].

### Tài liệu tạo mới

| File | Nội dung |
|---|---|
| `docs/source-materials/Tu_dien_full.csv` | 31.997 dòng, kết quả transcribe đầy đủ `Tu_dien.pdf` |
| `docs/db/import/build_combined_vocab_db.py` | Script build `vocab.db` cuối (cũ + Tu_dien, dedup, chuẩn hoá) |

### Tài liệu đã cập nhật

| File | Thay đổi |
|---|---|
| `assets/db/vocab.db` | 33.019 từ, 8 bộ từ điển (thêm "Military Dictionary") |

### Điểm chờ xác nhận còn mở

| # | Câu hỏi |
|---|---|
| Q-CSB-07 (bổ sung) | Chưa xác nhận lại chính sách dedup/chuẩn hoá đã dùng (case-insensitive theo `word`, giữ nguyên nếu `meaning` khác) có đúng ý muốn lâu dài không — hiện chỉ là lựa chọn mặc định hợp lý được disclose công khai, không phải quyết định user chốt trực tiếp câu chữ. |

---

## [IMPL-020] 2026-08-16 — Task-plan: đặt giờ nhắc ôn tập tuỳ chỉnh (chưa implement)

**Người yêu cầu:** User · **Người thực hiện:** Claude

### Nội dung

Hoàn thành `task-plan` cho task đặt giờ nhắc ôn tập (kế thừa
[IMPL-018]/[IMPL-019]), chốt kế hoạch implement cụ thể dựa trên Option 1
đã khuyến nghị ở bước brainstorm.

Trước khi lập plan, đã hỏi lại và chốt 2 điểm còn treo:

1. **UX khi bỏ chọn hết tất cả 7 thứ** (công tắc tổng vẫn bật): **cho
   phép** — không chặn thao tác, kết quả không có lịch nào được tạo
   (tương đương tắt), không cần validate ở UI.
2. **Định dạng lưu tập hợp thứ**: `List<String>` qua
   `setStringList`/`getStringList` của `shared_preferences` (mỗi phần
   tử là `weekday.toString()`, `'1'`–`'7'` theo `DateTime.weekday`) —
   không tự viết serialize/CSV/bitmask thủ công.

Nội dung chính của `03-plan.md`:

- **Quy đổi "API Contract" sang "Provider/Service Contract"** — dự án
  không có network API, hợp đồng thật sự là giữa UI và
  `ReminderSettingsNotifier`/`NotificationService` (local service
  layer). Ghi rõ contract 2 tầng: state Riverpod (`ReminderSettings`
  entity, `reminderSettingsProvider`) và service method
  (`scheduleWeeklyReminders`, `cancelAllReminders` — thay hẳn
  `scheduleDailyReminder` cũ, không giữ song song).
- **4 subtask Backend** (BE-01 thêm dependency, BE-02 viết lại lên lịch
  N-thứ trong `NotificationService`, BE-03 `ReminderSettingsNotifier`,
  BE-04 nối `main.dart`), **2 subtask Frontend** (FE-01 icon Cài đặt,
  FE-02 `DailyReminderSheet`), **2 subtask Integration** (INT-01 nối
  provider thật, INT-02 verify lịch thật theo thứ — đánh dấu rủi ro
  trung bình vì khó test tự động).
- **Khuyến nghị thứ tự Backend First** — rủi ro kỹ thuật lớn nhất nằm ở
  BE-02 (đổi cơ chế lên lịch 1→N), cần verify độc lập trước khi ràng
  buộc UI lên trên.
- Manual Verification Plan đầy đủ 6 mục (Main Flow, UI, Service, Error/
  Edge Case, SPA/Browser — ghi rõ không áp dụng vì là app Flutter
  native, Regression).

### Tài liệu tạo mới

| File | Nội dung |
|---|---|
| `docs/csb-vocab-analysis/tasks/05-dat-gio-nhac-on-tap/03-plan.md` | Task-plan đầy đủ: Provider/Service Contract, 8 subtask BE/FE/INT, thứ tự thực hiện khuyến nghị (Backend First), Manual Verification Plan, Risks |

### Điểm chờ xác nhận còn mở

Không phát sinh câu hỏi mới — 2 điểm treo từ [IMPL-019] (UX bỏ chọn hết
thứ, định dạng lưu) đã chốt ở bước này. Còn 1 quyết định nhỏ để lúc code
(không chặn tiến độ): `DailyReminderSheet` có disable trực quan phần
giờ/chip khi công tắc tổng tắt hay không.

Chưa implement — bước tiếp theo là user chọn thứ tự thực hiện
(khuyến nghị Backend First, bắt đầu từ BE-01) rồi dùng
`task-implement`/`task-implement-app` để code.

---

## [IMPL-019] 2026-08-16 — Mở rộng scope đặt giờ nhắc: thêm chọn theo thứ trong tuần

**Người yêu cầu:** User · **Người thực hiện:** Claude

### Nội dung

Ngay sau khi hoàn thành task-brainstorm cho [IMPL-018] (đặt giờ nhắc ôn
tập, khuyến nghị Option 1 — `shared_preferences` + BottomSheet, 1 giờ
cố định áp dụng mọi ngày), user yêu cầu mở rộng: **cho chọn theo thứ
trong tuần** (ví dụ chỉ nhắc T2/T3/T4, các thứ khác không nhắc), không
chỉ 1 giờ cố định mọi ngày như đã chốt trước đó (D2 cũ trong
`01-analysis.md`).

Đã hỏi lại và chốt: **1 giờ chung áp dụng cho tất cả các thứ được
chọn** — không hỗ trợ giờ khác nhau theo từng thứ (giữ mức phức tạp UI
vừa phải, tránh trở thành "1 lịch/thứ độc lập"). Ghi nhận thành D3
trong `01-analysis.md`, thay thế D2 cũ (giữ lại D2 dạng gạch ngang để
lưu vết lịch sử quyết định đổi hướng).

**Phát hiện kỹ thuật quan trọng khi rà lại thiết kế:** đọc source
`flutter_local_notifications-22.0.1` (`lib/src/flutter_local_
notifications_plugin.dart` + Android `FlutterLocalNotificationsPlugin.
java`) xác nhận `matchDateTimeComponents: DateTimeComponents.
dayOfWeekAndTime` chỉ khớp **đúng 1 thứ cụ thể** mỗi lần gọi
`zonedSchedule` — không có cơ chế "khớp nhiều thứ trong 1 lịch". Nhắc
nhiều thứ đòi hỏi **lên nhiều lịch song song, mỗi thứ 1 `id` thông báo
riêng** (đề xuất: `id = 2001 + weekday`, range `2002`–`2008`). Đây là
thay đổi kiến trúc thật ở tầng `NotificationService` (đổi từ
`scheduleDailyReminder(hour, minute)` 1-lịch sang
`scheduleWeeklyReminders(hour, minute, Set<int> weekdays)` N-lịch),
không chỉ thêm tham số như đánh giá ban đầu ở [IMPL-018].

Đã cập nhật lại toàn bộ `01-analysis.md` (Scope, Acceptance Criteria,
UI Gap — thêm 7 `FilterChip` chọn thứ, Backend Gap, API/Data Impact,
Risk Analysis, Quyết định đã chốt, Open Questions) và `02-brainstorm.md`
(Requirement Recap, thiết kế Backend Changes của Option 1 và Option 2)
cho khớp scope mới. Kết luận chọn **Option 1** ở bước brainstorm **không
đổi** — vẫn là vấn đề lưu trữ giá trị cấu hình phẳng qua
`shared_preferences`, chỉ đổi cách tầng service dùng chúng để lên lịch.

### Tài liệu đã cập nhật

| File | Thay đổi |
|---|---|
| `docs/csb-vocab-analysis/tasks/05-dat-gio-nhac-on-tap/01-analysis.md` | Cập nhật Scope/Acceptance Criteria cho chọn theo thứ; thêm phát hiện kỹ thuật N-lịch vào Backend Gap + API/Data Impact; thêm D3 thay D2; thêm Open Questions mới (UX bỏ chọn hết thứ, định dạng lưu tập hợp thứ) |
| `docs/csb-vocab-analysis/tasks/05-dat-gio-nhac-on-tap/02-brainstorm.md` | Cập nhật Requirement Recap; viết lại Backend Changes của Option 1/2 theo cơ chế N-lịch-theo-thứ; cập nhật Risks, Comparison, Recommended Approach |

### Điểm chờ xác nhận còn mở

| # | Câu hỏi |
|---|---|
| — | UX khi user bỏ chọn hết tất cả các thứ (công tắc tổng vẫn bật): chặn thao tác (luôn giữ ≥1 thứ) hay cho phép và ngầm hiểu tương đương tắt nhắc? Quyết định ở `task-plan` |
| — | Định dạng lưu tập hợp thứ trong `shared_preferences`: chuỗi CSV hay bitmask int? Quyết định ở `task-plan` |
| — | Kế thừa các điểm chờ chưa đổi từ [IMPL-018]: nội dung text thông báo có đổi theo giờ/thứ đã chọn không, giá trị mặc định khi chưa từng cấu hình |

Chưa implement — bước tiếp theo là `task-plan`.

---

## [IMPL-018] 2026-08-16 — Task-analysis: đặt giờ nhắc ôn tập tuỳ chỉnh (chưa implement)

**Người yêu cầu:** User · **Người thực hiện:** Claude

### Nội dung

Task-analysis (chỉ phân tích, không sửa code) cho yêu cầu: cho phép user
tự đặt giờ để app thông báo nhắc "đến giờ ôn tập", thay vì giờ cố định
`20:00` đang hardcode ở `lib/main.dart:10` (gọi
`NotificationService.instance.scheduleDailyReminder()` không truyền
tham số, dùng default `hour: 20, minute: 0` của
`lib/data/services/notification_service.dart:96`).

**Phát hiện quan trọng khi khảo sát code thật:** `docs/csb-vocab-
analysis/06_Settings.md` (và `README.md` mục "Danh sách tài liệu",
dòng SCR-06) mô tả có sẵn `lib/features/settings/settings_screen.dart`
+ `ThemeModeNotifier` (chọn giao diện Sáng/Tối/Theo hệ thống, lưu qua
`shared_preferences`) — nhưng **cả 2 file này không còn tồn tại trong
code hiện tại** (xác nhận bằng glob `lib/features/settings/**` → không
khớp), và `shared_preferences` **không có trong `pubspec.yaml`**.
**Không có entry nào trong file này ghi lại việc xoá màn Settings** —
đây là khoảng trống tài liệu, tài liệu phân tích màn hình (`06_Settings.md`,
`README.md`) đã lỗi thời so với code thật, chưa rõ xoá từ khi nào hay lý
do — cần lưu ý khi cập nhật lại các tài liệu đó và khi implement task
này (có thể phải thêm lại `shared_preferences` từ đầu).

Quyết định đã chốt cùng user trong phiên phân tích:

1. **Entry point vào UI cấu hình** = icon Cài đặt trong `AppBar.actions`
   (mobile) / nav-rail footer (Windows) của `HomeShell` — **không** thêm
   tab thứ 5, giữ nguyên bố cục 4 tab hiện tại (Tra cứu/Học/Dịch/Từ điển
   của tôi) để tránh làm chật bottom nav mobile.
2. **Chỉ 1 giờ nhắc cố định áp dụng mọi ngày** — không hỗ trợ nhiều
   khung giờ hay khác nhau theo ngày trong tuần, giữ đúng tinh thần MVP.
3. **Windows ngoài phạm vi** cho phần lên lịch nền — kế thừa đúng ràng
   buộc D2 đã chốt trước đó (`00_Overview.md`): Windows chỉ nhắc được
   lúc app đang mở, không hỗ trợ nhắc nền khi app đóng hẳn. UI trên
   Windows chỉ cần hiển thị ghi chú giới hạn, không hứa hẹn hành vi
   không hỗ trợ được.

### Tài liệu tạo mới

| File | Nội dung |
|---|---|
| `docs/csb-vocab-analysis/tasks/05-dat-gio-nhac-on-tap/01-analysis.md` | Task-analysis đầy đủ: Requirement Summary, Existing UI Analysis, UI/Backend Gap, API/Data Impact (quy đổi local persistence + local notification scheduling), Risk Analysis, quyết định đã chốt, Open Questions |

### Điểm chờ xác nhận còn mở

| # | Câu hỏi |
|---|---|
| — | `shared_preferences` cần thêm lại vào `pubspec.yaml` — xác nhận không xung đột với lý do (chưa rõ) mà màn Settings cũ từng bị gỡ |
| — | Nội dung text thông báo có cần đổi theo giờ user chọn không, hay giữ nguyên câu hiện tại — quyết định ở bước task-plan |
| — | Giá trị mặc định khi user chưa từng cấu hình — đề xuất giữ `20:00` + bật sẵn (giữ đúng hành vi hiện tại), cần xác nhận lại ở task-plan |

Chưa implement — bước tiếp theo (nếu user đồng ý) là `task-brainstorm`
rồi `task-plan` trước khi code.

---

## [IMPL-017] 2026-08-06 — Đổi hướng Dịch (FR-4): máy dịch neural on-device thay vì ghép từ/cụm

**Người yêu cầu:** User · **Người thực hiện:** Claude

### Nội dung

Đảo ngược thiết kế đã ghi ở `04_Translate.md` (dịch bằng tra ghép từ/cụm
offline trong `vocab.db`, chưa từng code) sang **máy dịch neural chạy
on-device** — ONNX Runtime + Helsinki-NLP/opus-mt-en-vi và opus-mt-vi-en
(Apache-2.0), quantize INT8, tải model về máy **sau khi cài đặt** (không
đóng gói sẵn trong app — giữ kích thước cài đặt như hiện tại ~30-40MB,
model ~130-140MB/chiều tải riêng khi user bật tính năng dịch).

Bối cảnh quyết định: khảo sát các phương án model dịch nhẹ cho mobile/
desktop trước khi chốt hướng — Google ML Kit bị loại vì không chạy được
trên Windows (nền tảng ưu tiên #1 theo `00_Overview.md`); NLLB-200 bị
loại vì license CC-BY-NC cấm dùng thương mại. Helsinki-NLP/opus-mt được
chọn vì Apache-2.0 rõ ràng, kích thước chấp nhận được sau quantize, và
có thể tự convert/kiểm soát toàn bộ pipeline.

Quyết định chốt (theo đúng thứ tự triển khai):

1. **Tải model sau khi cài, không bundle sẵn** — giữ app nhẹ, chỉ user
   thực sự bật tính năng dịch mới tải thêm.
2. **Cả 2 chiều En→Vi và Vi→En ngay từ đầu, tải độc lập từng chiều** (2
   nút tải riêng) — ai chỉ cần 1 chiều không phải tải cả 2.
3. **Tự convert ONNX từ checkpoint gốc Helsinki-NLP** bằng `optimum-cli`
   (không dùng bản convert cộng đồng nhỏ, không rõ quy trình) — đảm bảo
   license Apache-2.0 rõ ràng và kiểm soát chất lượng quantize. Script
   convert + hướng dẫn đầy đủ tại `tools/onnx-model-conversion/`.
4. **POC Windows bắt buộc là bước đầu tiên** trước khi code phần còn
   lại — đã chạy, **PASS**: `flutter_onnxruntime` build/link đúng trên
   Windows với kiến trúc MarianMT (encoder/decoder + KV-cache đầy đủ 24
   tensor past-key-value); kết quả dịch khớp 100% với inference bằng
   `transformers`/PyTorch gốc cho câu test tiếng Anh chuyên ngành hàng
   hải/quân sự.
5. **Model host trên GitHub Releases của chính repo này**, tag
   `mt-models-v1`: <https://github.com/tuananhdut/csb-vocab-app/releases/tag/mt-models-v1>
   — `en-vi-v1.zip` (136.7MB) + `vi-en-v1.zip` (133.3MB), kèm
   `*.manifest.json` (size + SHA-256) để app verify integrity lúc tải.

Phát hiện kỹ thuật quan trọng trong lúc implement (ghi vào
`tools/onnx-model-conversion/README.md` để không lặp lại sai lầm khi
convert lại/mở rộng thêm chiều dịch khác sau này):

- **Marian/opus-mt dùng bảng `vocab.json` riêng** để map piece↔id,
  **khác hoàn toàn** thứ tự id nội bộ trong file `.spm` gốc — dùng
  thư viện SentencePiece thuần chỉ để segment câu thành piece, không
  dùng id thô của thư viện đó (đã thử, cho kết quả dịch hoàn toàn sai/
  rác dù model đúng).
- Quantize graph MarianMT bằng `onnxruntime.quantization.quantize_dynamic`
  trực tiếp (không dùng `optimum.onnxruntime.ORTQuantizer.quantize()`,
  API đó lỗi trên graph MarianMT) + `extra_options={'DefaultTensorType': 1}`,
  **không** chạy `quant_pre_process` trước (graph nhiều nhánh past-KV
  khiến symbolic shape inference lỗi).
- Sau khi lên production với model đã tải qua mạng: kết quả dịch **đúng
  ngữ pháp nhưng có thể khác nhau nhẹ giữa các lần chạy cùng 1 câu** —
  đã điều tra kỹ (so khớp checksum SHA-256 của cả 3 file model giữa 2
  lần build khác nhau, khớp tuyệt đối — loại trừ lỗi data/code). Nguyên
  nhân: ONNX Runtime CPU đa luồng không đảm bảo bit-exact reproducibility
  giữa các lần chạy khác tiến trình; ở một vài bước decode, 2 token có
  logit rất gần nhau (chênh lệch ~0.03-0.4), sai số floating-point tích
  luỹ đủ để đảo thứ hạng argmax — hạn chế cố hữu của **greedy decoding**
  kết hợp suy luận đa luồng, không phải bug. **Chấp nhận cho MVP**,
  không ép single-thread hay nâng cấp beam search ở giai đoạn này.

### Tài liệu đã cập nhật

| File | Thay đổi |
|---|---|
| `docs/csb-vocab-analysis/04_Translate.md` | Viết lại — cơ chế neural on-device tải theo yêu cầu, thay "tra ghép từ/cụm" |
| `docs/csb-vocab-analysis/90_Traceability-matrix.md` | Cập nhật dòng FR-4: trạng thái, mô tả cơ chế, cột "So với mockup" |
| `tools/onnx-model-conversion/README.md`, `convert.py`, `package.py`, `requirements.txt` | Mới — pipeline convert/quantize/đóng gói model, đã test end-to-end |
| `pubspec.yaml` | Thêm `flutter_onnxruntime`, `dart_sentencepiece_tokenizer`, `dio`, `crypto`, `archive` |

Code Dart mới: `lib/domain/entities/translation_direction.dart`,
`lib/data/services/model_download_service.dart`,
`lib/data/services/translation_service.dart`,
`lib/data/repositories/translation_providers.dart`,
`lib/features/translate/translate_screen.dart` (viết lại),
`lib/features/translate/widgets/model_download_prompt.dart`,
`lib/features/translate/widgets/translate_panels.dart`.

### Điểm chờ xác nhận còn mở

- Chưa test chiều Vi→En end-to-end trên UI thật (chỉ tự động test
  chiều En→Vi khi debug) — nên tự thử tay trước khi coi FR-4 là hoàn
  thiện đầy đủ cả 2 chiều.
- Resumable download bị hoãn sang v2 (mất mạng giữa chừng thì tải lại
  từ đầu) — nếu feedback thực tế cho thấy cần thiết, làm lại thành điểm
  chờ xác nhận riêng.
- Chất lượng dịch thuật ngữ chuyên ngành (cấp bậc, loại tàu, thuật ngữ
  quân sự/hàng hải riêng) chưa được đánh giá có hệ thống — model gốc là
  model tổng quát, không fine-tune riêng cho domain này.

---

## [IMPL-016] 2026-07-19 — Bỏ hẳn bảng `review_logs` và `search_history`

**Người yêu cầu:** User · **Người thực hiện:** Claude

### Nội dung

Trong lúc rà lại `docs/db/schema.sql` (bản SQL đối chiếu trực quan cho
[IMPL-015]), phát hiện `review_logs` chỉ được `INSERT` trong code hiện
tại (`review_repository.dart`), **không có bất kỳ `SELECT` nào đọc
lại** — không màn hình, provider, hay thống kê nào từng dùng dữ liệu này.
Áp dụng đúng nguyên tắc đã chốt ở [IMPL-015] cho cột `question_mode`
("không giữ dữ liệu chưa ai dùng"), quyết định mở rộng thêm: bỏ **toàn
bộ bảng** `review_logs`, không chỉ dừng ở việc từ chối thêm cột mới.

Rà soát tiếp theo cùng nguyên tắc phát hiện `search_history` ở tình
trạng tương tự (thậm chí rõ hơn): không có cả `INSERT` lẫn `SELECT`
trong toàn bộ code, và `docs/csb-vocab-analysis/02_Search.md` đã ghi
nhận từ trước đây là gap ("chưa được đọc/ghi ở bất kỳ đâu") — không
mockup nào (kể cả `screen-02-tra-cuu.html`) thiết kế UI "lịch sử tra
cứu" đi kèm. Quyết định: bỏ hẳn luôn bảng này, cùng đợt với
`review_logs`.

Phân biệt rõ với `learned_words` (**không** bỏ) — đó là bảng lưu trạng
thái hiện tại của SM-2, được đọc liên tục để tính hàng đợi ôn tập; khác
bản chất với `review_logs`/`search_history` vốn chỉ là audit trail lịch
sử chưa từng có nhu cầu thống kê/hiển thị thật đi kèm. Hệ quả:
`submitReview()` sau khi implement chỉ còn `UPDATE learned_words`, bỏ
câu `INSERT INTO review_logs`.

Nếu sau này thực sự cần audit trail ôn tập hoặc tính năng "lịch sử tra
cứu gần đây", tạo lại bảng tương ứng khi đó bằng 1 migration đơn giản —
chấp nhận đánh đổi mất dữ liệu lịch sử trong giai đoạn không ghi, đổi
lấy việc không phải duy trì bảng không ai dùng trong lúc chờ.

### Tài liệu đã cập nhật

| File | Thay đổi |
|---|---|
| `docs/csb-vocab-analysis/91_DB-design-new-model.md` | Bỏ `review_logs` khỏi sơ đồ tổng quan quan hệ, khỏi bước 5 migration dữ liệu ban đầu (sửa luôn câu ghi sai trước đó nhắc `search_history` có `word_id`); đổi mục "Không thêm cột `review_logs.question_mode`" thành "Bỏ hẳn bảng `review_logs`/`search_history`" (lý do đầy đủ cho cả 2 bảng + phân biệt với `learned_words`); cập nhật "Việc cần làm khi implement" — `submitReview()` bỏ `INSERT INTO review_logs` |
| `docs/csb-vocab-analysis/02_Search.md` | Cập nhật mục "Giả định/hạn chế" — `search_history` từ "gap chưa làm" thành "đã bỏ hẳn khỏi thiết kế", trỏ sang [IMPL-016] |
| `docs/db/schema.sql` | Xoá `CREATE TABLE review_logs` và `search_history` + index liên quan; ghi chú ở đầu file giải thích lý do bỏ từng bảng (khác với `chapter_words` — dời sang phase sau chứ không bỏ hẳn) |

### Điểm chờ xác nhận còn mở

Không phát sinh điểm mới — kế thừa các điểm chờ đã có ở [IMPL-014]/
[IMPL-015].

---

## [IMPL-015] 2026-07-19 — Ôn tập khách quan (trắc nghiệm + gõ chữ), bỏ tự chấm, thêm nhãn "từ khó"

**Người yêu cầu:** User · **Người thực hiện:** Claude

### Nội dung

Mở rộng quyết định "Ôn tập bằng trắc nghiệm" đã chốt trước đó (dựng lại
từ 1 phiên phân tích trước, chưa từng ghi vào `spec_history.md`) thành 1
task-analysis đầy đủ (`docs/csb-vocab-analysis/tasks/02-review-multi-
mode/01-analysis.md`), sau khi xác nhận lại 6 điểm mở:

1. **Bỏ hẳn** kiểu lật thẻ tự chấm chủ quan (`ReviewRating` 4 mức
   Quên/Khó/Tốt/Dễ do người dùng tự bấm) — không giữ song song.
2. **Thêm 2 kiểu câu hỏi khách quan trộn ngẫu nhiên đều 50/50** trong 1
   phiên: **trắc nghiệm** (chọn 1/4 đáp án nghĩa tiếng Việt) và **gõ chữ**
   (nhập lại từ tiếng Anh, so khớp `trim().toLowerCase()` tuyệt đối,
   không fuzzy). Cả 2 đều tự động map Đúng→`q=4`, Sai→`q=1` vào
   `SrsScheduler` (SM-2) hiện có, không đổi thuật toán.
3. **Giới hạn 1 phiên tối đa 4 từ** — nếu hàng đợi hôm nay ít hơn 4 từ
   đến hạn thì phiên chỉ gồm đúng số từ đó, không độn thêm.
4. **"Từ khó"**: nhãn suy luận tự động, `ease_factor <= 1.5` (gần sàn
   1.3 của SM-2) — **chỉ dùng để hiển thị/thống kê**, không đổi thứ tự
   hàng đợi hay bất kỳ logic chọn từ nào (giữ nguyên nguyên tắc trước đó:
   không thêm tầng ưu tiên chồng lên SM-2, tránh phạt trùng 1 sự kiện
   sai 2 lần).
5. Thêm màn **kết quả cuối phiên** (tổng đúng/sai), thay `SnackBar` đơn
   giản hiện tại.
6. Thêm cột `review_logs.question_mode` (`0=MULTIPLE_CHOICE`,
   `1=TYPING`) vì nay giữ song song 2 kiểu câu hỏi, cần phân biệt nguồn
   gốc mỗi lượt ôn khi thống kê sau này.

Đã xác nhận **đợi migrate xong** sang schema mới (`dictionaries`/
`word_dictionaries` N-N, [IMPL-014]) mới implement — `randomDistractors`
viết theo `dictionary_id` mới, không viết tạm theo `chapter_id` cũ.

### Tài liệu đã cập nhật

| File | Thay đổi |
|---|---|
| `docs/csb-vocab-analysis/91_DB-design-new-model.md` | Viết lại mục "Ôn tập bằng trắc nghiệm" thành "Ôn tập khách quan: trắc nghiệm + gõ chữ" — thêm kiểu gõ chữ, giới hạn 4 từ/phiên, nhãn "từ khó" (`ease_factor<=1.5`, chỉ hiển thị), cột `review_logs.question_mode`, màn kết quả cuối phiên |
| `docs/csb-vocab-analysis/tasks/02-review-multi-mode/01-analysis.md` | Tạo mới — task-analysis đầy đủ (Requirement Summary, UI/Backend Gap, Risk Analysis), 6 Open Question đã chốt ghi trong mục "Quyết định đã chốt" |

### Điểm chờ xác nhận còn mở

- Chi tiết UI màn kết quả cuối phiên (bố cục, có hiện lại danh sách từ
  sai không) — để quyết định ở bước `task-plan`.
- Chi tiết UI kiểu gõ chữ ở trạng thái "đã submit" — mockup
  `screen-07e-phien-on-tap-cau-go-chu.html` chỉ có CSS state
  (`.type-input-row.correct/.wrong`, `.answer-reveal`) nhưng không có
  khung hình minh hoạ trực quan, cần tự thiết kế thêm khi vào task-plan.
- Kế thừa toàn bộ điểm chờ xác nhận của [IMPL-014] (Q-CSB-02, UX xoá từ
  khỏi bộ cá nhân, cơ chế cập nhật seed data) — vẫn chưa chốt, độc lập
  với thay đổi lần này.

---

## [IMPL-014] 2026-07-18 — Bỏ ranh giới vocab.db/user.db, gộp 1 DB, thêm bộ "Chưa phân loại"

**Người yêu cầu:** User · **Người thực hiện:** Claude

### Nội dung

Đổi hướng thiết kế DB mới ([IMPL-013]/`91_DB-design-new-model.md`) theo 3
yêu cầu:

1. **Bỏ ranh giới `vocab.db` (read-only) / `user.db` (read-write)** — không
   còn giữ nguyên 2 file SQLite tách biệt như dự tính ban đầu ở [IMPL-005].
   Thiết kế lại thành **1 database duy nhất**: 1 bảng `words` hợp nhất
   chứa mọi từ bất kể nguồn gốc (giáo trình gốc `source='seed'`, tự nhập
   tay `source='manual'`, tra online rồi lưu `source='online_lookup'`).
   Loại bỏ hoàn toàn vấn đề "N-N xuyên 2 file SQLite" (`ATTACH DATABASE`)
   từng nêu ở thiết kế trước. Phân biệt mặc định/cá nhân nay chỉ còn ở tầng
   bộ từ điển (`dictionaries.is_default`), không phải ở tầng file DB.
2. **Từ không thuộc bộ nào → gom vào 1 bộ đặc biệt "Chưa phân loại"** — bổ
   sung ràng buộc nghiệp vụ: mọi từ luôn phải có ít nhất 1 dòng trong
   `word_dictionaries`. Nếu thêm từ (tự nhập, hoặc lưu từ tra online) mà
   không chỉ định bộ cụ thể, tự động gán vào bộ "Chưa phân loại"
   (`is_deletable=0`, không thể xoá) — tránh dữ liệu "mồ côi" không thuộc
   bộ nào, khó hiển thị ở màn "Từ điển của tôi".
3. **Search vẫn ra kết quả bình thường dù từ thuộc bộ nào** — xác nhận rõ:
   `search(query)` không lọc theo bộ từ điển, luôn quét toàn bộ bảng
   `words` — giữ đúng hành vi FR-2 hiện tại (tìm mọi từ có trong hệ thống,
   không phân biệt nguồn/bộ).

Viết lại toàn bộ `91_DB-design-new-model.md` theo hướng mới (thay bản
[IMPL-013] cũ vốn vẫn giữ 2 file `vocab.db`/`user.db` song song).

### Tài liệu đã cập nhật

| File | Thay đổi |
|---|---|
| `docs/csb-vocab-analysis/91_DB-design-new-model.md` | Viết lại hoàn toàn: 1 bảng `words` hợp nhất (bỏ `custom_words` riêng), bảng `dictionaries` thêm cột `is_deletable` + dòng "Chưa phân loại" cố định, ràng buộc "mọi từ luôn có ≥1 bộ", xác nhận search không lọc theo bộ, cập nhật migration/Repository tương ứng |
| `docs/csb-vocab-analysis/00_Overview.md` | Cập nhật mục Kiến trúc kỹ thuật — ghi rõ không còn giữ 2 file `vocab.db`/`user.db` như dự tính ban đầu, trỏ sang `91_DB-design-new-model.md` |

### Điểm chờ xác nhận còn mở

Kế thừa các câu hỏi ở `91_DB-design-new-model.md` mục "Câu hỏi còn mở":
Q-CSB-02 (xác nhận lại "Từ điển của tôi"), UX xoá từ khỏi bộ cá nhân (xoá
hẳn hay chuyển về "Chưa phân loại"), và cơ chế cập nhật seed data giáo
trình gốc sau khi gộp 1 DB duy nhất (không còn cơ chế copy asset riêng như
`vocab.db` cũ).

---

## [IMPL-013] 2026-07-18 — Chốt Q-CSB-04/05/06, dời Q-CSB-07, thêm thiết kế DB mô hình mới

**Người yêu cầu:** User · **Người thực hiện:** Claude

### Nội dung

Trả lời trực tiếp 4 câu hỏi mở đã ghi ở [IMPL-005]/[IMPL-011]:

1. **Q-CSB-04 (nhà cung cấp dictionary API)** — chốt **Free Dictionary API**
   (`https://api.dictionaryapi.dev`, miễn phí, không cần API key) cho định
   nghĩa/phiên âm/ví dụ tiếng Anh. Vì API này chỉ trả tiếng Anh (không có
   nghĩa tiếng Việt, khác hành vi song ngữ hiện tại của `vocab.db`), ghép
   thêm **LibreTranslate** để dịch nghĩa sang tiếng Việt trước khi hiển thị.
2. **Q-CSB-06 (cơ chế phát hiện mạng)** — đồng ý dùng **`connectivity_plus`**
   như đã đề xuất; lỗi mạng chập chờn (có kết nối nhưng API không phản hồi/
   timeout) → **fallback êm về kết quả offline**, không chặn UI bằng lỗi đỏ.
3. **Q-CSB-05 (từ tra online có lưu lại không)** — chốt **không tự động lưu
   lại local**. Chỉ ghi vào `user.db` khi user **chủ động bấm "Thêm vào bộ"**
   (gắn vào 1 bộ từ điển cá nhân do user chọn/tạo) — đơn giản hoá luồng ghi
   dữ liệu, không có khái niệm "cache tự động".
4. **Q-CSB-07 (quy trình `.docx` → dữ liệu Section/Chapter)** — chốt
   **thực hiện ở một bước phân tích/implement riêng**, tách khỏi việc thiết
   kế schema DB. Nghĩa là schema `sections`/`chapters`/`chapter_words` có
   thể thiết kế và tạo bảng trước, nhưng UI đọc bài thật (`screen-03c`) vẫn
   phải chờ bước `.docx` riêng đó xong mới có dữ liệu để code.

Dựa trên các quyết định trên, viết tài liệu thiết kế DB mới
(`91_DB-design-new-model.md`) mô tả đầy đủ schema cho mô hình N-N bộ từ
điển (mặc định + cá nhân), Section/Chapter, và luồng ghi dữ liệu tra cứu
Online — theo Drift (đã chốt D3, [IMPL-007]). Đây **không phải bản thiết
kế DB tương đương file cũ đã xoá ở [IMPL-003]** (vốn mô tả schema hiện tại
đang chạy thật, mô hình cũ) — đây là thiết kế cho **định hướng mới chưa
code**, làm nền cho việc implement Section/Chapter và bộ từ điển cá nhân
sau này. Trả lời gián tiếp Q-CSB-02 (không tự chốt, nhưng thiết kế bảng đã
giả định "có triển khai" bộ từ điển cá nhân để có cơ sở thiết kế — vẫn cần
xác nhận lại 1 lần trước khi code UI 7 màn `screen-07*`).

### Tài liệu tạo mới / cập nhật

| File | Thay đổi |
|---|---|
| `docs/csb-vocab-analysis/91_DB-design-new-model.md` | **Mới** — thiết kế DB mô hình mới: bảng `dictionaries`/`word_dictionaries` (N-N, thay `chapters` cũ), `sections`/`chapters` (định nghĩa lại)/`chapter_words`, `personal_dictionaries`/`personal_dictionary_words`/`custom_words` (bộ từ điển cá nhân), ghi chú ràng buộc N-N xuyên 2 file DB, migration tóm tắt |
| `docs/csb-vocab-analysis/00_Overview.md` | Cập nhật mục "Trạng thái tra cứu Online/Offline" (API + lưu dữ liệu + xử lý lỗi mạng theo quyết định mới), mục Section/Chapter (ghi chú Q-CSB-07 dời bước riêng), thêm D4 vào bảng "Quyết định đã chốt", cập nhật mục "Câu hỏi mở" |
| `docs/csb-vocab-analysis/02_Search.md` | Viết lại mục "Chế độ Online" theo quyết định Free Dictionary API + LibreTranslate + `connectivity_plus` + không tự cache |
| `docs/csb-vocab-analysis/tasks/01-splash-photos-search-empty/01-analysis.md` | Cập nhật bảng câu hỏi mở: tách "Đã chốt" riêng, trỏ tới `91_DB-design-new-model.md` |

### Điểm chờ xác nhận còn mở

| # | Câu hỏi |
|---|---|
| Q-CSB-02 | Mockup "Từ điển của tôi" (7 màn `screen-07*`) — schema đã thiết kế giả định có triển khai, nhưng chưa tự chốt chính thức; cần xác nhận lại trước khi code UI |
| — | Xoá 1 từ khỏi bộ cá nhân có xoá luôn `custom_words` (nếu từ nguồn online không còn nằm trong bộ nào khác) hay giữ lại? Xem `91_DB-design-new-model.md` mục câu hỏi còn mở |
| — | Instance LibreTranslate cụ thể dùng public hay self-host — chưa chọn, ảnh hưởng độ ổn định/rate limit khi implement thật |

---

## [IMPL-012] 2026-07-18 — Tạo thư mục task riêng cho quy trình task-analysis/task-plan

**Người yêu cầu:** User · **Người thực hiện:** Claude

### Nội dung

Chuyển từ đặt file phân tích/kế hoạch task rời rạc kiểu `9x_*.md` phẳng
trong `docs/csb-vocab-analysis/` sang cấu trúc thư mục riêng theo task:
`docs/csb-vocab-analysis/tasks/<số>-<slug>/`, mỗi task có `01-analysis.md`
(task-analysis) và `02-plan.md` (task-plan), đánh số tiếp nếu có thêm bước
(brainstorm, v.v.). Giữ nguyên `docs/csb-vocab-analysis/00-07, 90` (tài
liệu phân tích màn hình cố định, không theo task).

Task đầu tiên áp dụng cấu trúc mới: `tasks/01-splash-photos-search-empty/`
— gộp phân tích tác động mốc mockup 01 (đối ứng Win/Mobile) và kế hoạch
implement phần đã chốt hẹp (ảnh thật Splash + trạng thái rỗng Tra cứu).

### Tài liệu tạo mới / xoá

| File | Thay đổi |
|---|---|
| `docs/csb-vocab-analysis/tasks/01-splash-photos-search-empty/01-analysis.md` | **Mới** — task-analysis (nội dung tương đương entry [IMPL-011] cũ, vốn không được ghi xuống đĩa thành công — viết lại lần này) |
| `docs/csb-vocab-analysis/tasks/01-splash-photos-search-empty/02-plan.md` | **Mới** — task-plan (chuyển từ `92_Plan-01-splash-photos-and-search-empty-state.md` đã xoá) |
| `docs/csb-vocab-analysis/92_Plan-01-splash-photos-and-search-empty-state.md` | **Xoá** — chuyển vào thư mục task ở trên |

### Điểm chờ xác nhận còn mở

Không phát sinh câu hỏi mới. Các câu hỏi mở của task 01 (bản quyền ảnh
CSB, Q-CSB-04..07) không đổi — xem `01-analysis.md`/`02-plan.md` trong thư
mục task mới.

---

## [IMPL-010] 2026-07-18 — Cập nhật mockup Windows (docs/artifact-design-windows/) theo định hướng mới

**Người yêu cầu:** User · **Người thực hiện:** Claude

### Nội dung

Áp cùng thay đổi đã làm cho mockup mobile ([IMPL-008]/[IMPL-009]) vào bản
Windows desktop (`docs/artifact-design-windows/`), giữ đúng ngôn ngữ layout
riêng của bản này (`nav-rail`, `page-header`, layout 2 cột
`pane-list`/`pane-detail` thay bottom nav/bottom sheet của mobile).

1. **Trạng thái Offline/Online** — thêm `.net-badge` vào `page-header` của
   `screen-02-tra-cuu.html` (Offline). Tạo `screen-02b-tra-cuu-online.html`:
   badge Online, `.net-note`, kết quả gắn `.source-tag` "Online" ở cả
   `pane-list` và `pane-detail`.
2. **Trạng thái chưa tìm kiếm — slide ảnh CSB** — tạo
   `screen-02c-tra-cuu-trong.html`: slide 3 ảnh (tái dùng từ
   `docs/artifact-design/assets/images/`, copy sang
   `docs/artifact-design-windows/assets/images/`) chiếm toàn bộ
   `page-content` (khác mobile — không có `pane-list`/`pane-detail` khi ở
   trạng thái này), autoplay bằng cùng đoạn `<script>` minh hoạ.
3. **Section → Chapter dạng bài báo** — thay `screen-03-hoc-danh-sach-
   chuong.html` bằng `screen-03-hoc-danh-sach-section.html` (danh sách
   Section trong `pane-list`, gợi ý trong `pane-detail-empty`); thay
   `screen-03b-hoc-danh-sach-tu-a-z.html` bằng `screen-03b-hoc-danh-sach-
   chapter.html` (danh sách Chapter dùng `.lesson-list` mới trong
   `pane-list`); thêm `screen-03c-hoc-noi-dung-bai.html` — khác biệt so với
   mobile: giữ layout 2 cột, `pane-list` bên trái vẫn hiện danh sách Chapter
   để chuyển bài nhanh, `pane-detail` bên phải là nội dung bài
   (`.article-*`). Xoá 2 file cũ.
4. **`screen-07-tu-dien-cua-toi.html`** — đổi "Giáo trình (6 chương)" →
   "Giáo trình (mặc định)", bổ sung câu giải thích duyệt theo bộ mặc định
   nay cũng ở đây.
5. **`index.html`** — cập nhật/thêm thẻ 02/02b/02c/03/03b/03c/07, thêm đoạn
   banner "Định hướng mới — chưa code" vào masthead.
6. **`styles.css`** — thêm class mới tương ứng bản mobile nhưng theo kích
   thước/khoảng cách desktop: `.net-badge`, `.net-note`, `.source-tag`,
   `.search-empty` (+ `.slide`/`.slide-caption`/`.dots`), `.lesson-list`/
   `.lesson-row`, `.article-wrap`/`.article-title`/`.article-body`/
   `.vocab-hl`. Không sửa class cũ đang dùng ở màn khác.

Toàn bộ màn mới/sửa đều ghi banner "⚠️ Định hướng mới — chưa code" trong
`frame-desc`, nhất quán với bản mobile.

### Tài liệu đã cập nhật

| File | Thay đổi |
|---|---|
| `docs/artifact-design-windows/screens/screen-02-tra-cuu.html` | Thêm badge Offline, sửa link điều hướng |
| `docs/artifact-design-windows/screens/screen-02b-tra-cuu-online.html` | **Mới** — trạng thái Online |
| `docs/artifact-design-windows/screens/screen-02c-tra-cuu-trong.html` | **Mới** — trạng thái chưa tìm kiếm, slide ảnh CSB |
| `docs/artifact-design-windows/screens/screen-03-hoc-danh-sach-section.html` | **Mới** — thay `screen-03-hoc-danh-sach-chuong.html` (đã xoá) |
| `docs/artifact-design-windows/screens/screen-03b-hoc-danh-sach-chapter.html` | **Mới** — thay `screen-03b-hoc-danh-sach-tu-a-z.html` (đã xoá) |
| `docs/artifact-design-windows/screens/screen-03c-hoc-noi-dung-bai.html` | **Mới** — bài đọc dạng article, layout 2 cột |
| `docs/artifact-design-windows/screens/screen-01-splash.html` | Sửa link cuối trang trỏ sang 02c |
| `docs/artifact-design-windows/screens/screen-04-chi-tiet-tu.html` | Sửa link điều hướng trỏ về 03c |
| `docs/artifact-design-windows/screens/screen-07-tu-dien-cua-toi.html` | Bỏ nhắc "6 chương" cứng |
| `docs/artifact-design-windows/index.html` | Cập nhật/thêm thẻ màn hình, banner định hướng mới |
| `docs/artifact-design-windows/styles.css` | Thêm class mới cho badge mạng, danh sách bài học, bài đọc article |
| `docs/artifact-design-windows/assets/images/csb-slide-01/02/03.jpg` | **Mới** — copy từ `docs/artifact-design/assets/images/` |

### Điểm chờ xác nhận còn mở

Không phát sinh câu hỏi mới — cùng các điểm mở đã ghi ở [IMPL-005]/[IMPL-009].
Bộ mobile và Windows nay đồng bộ hoàn toàn về nội dung định hướng mới, chỉ
khác khung layout theo đúng quy ước đã có của từng bộ.

---

## [IMPL-009] 2026-07-18 — Thêm trạng thái "chưa tìm kiếm" cho màn Tra cứu (slide ảnh CSB)

**Người yêu cầu:** User · **Người thực hiện:** Claude

### Nội dung

Bổ sung 1 trạng thái nữa cho màn Tra cứu (SCR-02, mockup) — khi vừa vào màn,
chưa gõ gì, hiện slide ảnh Cảnh sát biển Việt Nam tự động lướt qua lại
(autoplay carousel), có dots chỉ báo cùng ngôn ngữ thị giác với màn Splash
(01). Trước đây trạng thái rỗng chỉ có gợi ý dạng chữ đơn giản (`_Hint`,
theo mô tả trong `02_Search.md` mục code thật) — mockup nay minh hoạ thêm
phương án trực quan hơn.

Nguồn ảnh: 3 ảnh do user cung cấp từ
`C:\Users\anhnt\Desktop\csb\ẢNH LÀM PHẦN MỀM\slide\` — 2 ảnh diễu binh đội
danh dự Cảnh sát biển và 1 ảnh trụ sở Bộ Tư lệnh Cảnh sát biển Việt Nam.
Copy vào `docs/artifact-design/assets/images/` (đặt tên lại
`csb-slide-01/02/03.jpg`, kể cả file gốc `.jfif` cũng đổi đuôi `.jpg` vì
cùng là dữ liệu JPEG) để mockup tự chứa, không phụ thuộc đường dẫn ngoài
repo.

Tạo màn mới `screen-02c-tra-cuu-trong.html`, chèn vào **trước** 02 trong
luồng điều hướng (01 Splash → 02c chưa tìm kiếm → 02 có kết quả → 02b
online). CSS carousel (`.search-empty`, `.slide`, `.dots` dùng lại) thêm vào
`styles.css`, có đoạn `<script>` nhỏ chỉ để minh hoạ hiệu ứng autoplay trong
mockup tĩnh — không phải code thật, không đại diện cho cách Flutter sẽ cài
đặt animation này.

### Tài liệu đã cập nhật

| File | Thay đổi |
|---|---|
| `docs/artifact-design/screens/screen-02c-tra-cuu-trong.html` | **Mới** — trạng thái chưa tìm kiếm, slide ảnh CSB autoplay |
| `docs/artifact-design/screens/screen-02-tra-cuu.html` | Sửa link điều hướng, cập nhật mô tả nhắc tới 02c |
| `docs/artifact-design/screens/screen-01-splash.html` | Sửa link cuối trang trỏ sang 02c thay vì 02 |
| `docs/artifact-design/index.html` | Thêm thẻ 02c |
| `docs/artifact-design/styles.css` | Thêm `.search-empty`, `.slide`, `.slide-caption`, dùng lại `.dots` |
| `docs/artifact-design/assets/images/csb-slide-01/02/03.jpg` | **Mới** — 3 ảnh CSB do user cung cấp |

### Điểm chờ xác nhận còn mở

Không phát sinh câu hỏi mới. Lưu ý: ảnh dùng ở đây (diễu binh đội danh dự,
trụ sở Bộ Tư lệnh) khác nội dung với `assets/csb-logo.png` đang dùng cho
theme màu app — chưa xác nhận ảnh này có được dùng chính thức trong app thật
(bản quyền/nguồn ảnh) hay chỉ minh hoạ ý tưởng bố cục cho mockup.

---

## [IMPL-008] 2026-07-18 — Cập nhật mockup mobile (docs/artifact-design/) theo định hướng mới

**Người yêu cầu:** User · **Người thực hiện:** Claude

### Nội dung

Lan tỏa định hướng mới ([IMPL-005]/[IMPL-006]) vào mockup HTML tĩnh mobile
(`docs/artifact-design/`) — Windows (`docs/artifact-design-windows/`) chưa
làm, để ở bước riêng theo yêu cầu.

1. **Trạng thái Offline/Online ở màn Tra cứu** — thêm chỉ báo mạng
   (`.net-badge`) trên appbar của `screen-02-tra-cuu.html` (Offline).
   Tạo mới `screen-02b-tra-cuu-online.html`: badge Online, banner giải
   thích, và 2 kết quả mẫu gắn nhãn nguồn "Online" (`.source-tag`) cho từ
   không có trong CSDL local.
2. **Section → Chapter dạng bài báo** — thay hoàn toàn luồng "danh sách
   chương → danh sách từ A-Z" cũ bằng 3 màn mới: `screen-03-hoc-danh-sach-
   section.html` (danh sách Section, tái dùng `.chapter-list`), `screen-03b-
   hoc-danh-sach-chapter.html` (danh sách Chapter/bài học trong 1 Section,
   layout mới `.lesson-list`/`.lesson-row`), `screen-03c-hoc-noi-dung-
   bai.html` (bài đọc dạng article — `.article-*`, từ vựng highlight lồng
   trong đoạn văn bằng `.vocab-hl`, bấm vào mở chung `WordDetailSheet` với
   màn 04). **Xoá** 2 file cũ `screen-03-hoc-danh-sach-chuong.html` và
   `screen-03b-danh-sach-tu-a-z.html` (đã hỏi ý kiến — không giữ song song
   để tránh 2 mô hình mâu thuẫn cùng tồn tại trong mockup).
3. **Duyệt theo bộ từ điển mặc định chuyển hẳn sang tab "Từ điển của tôi"**
   (quyết định của user) — tab "Học" từ nay chỉ còn Section/Chapter dạng bài
   báo, không có đường vào khác để browse từ theo bộ mặc định. Cập nhật
   `screen-07-tu-dien-cua-toi.html`: bỏ nhắc cứng "6 chương", đổi tên thẻ
   "Giáo trình (6 chương)" → "Giáo trình (mặc định)", làm rõ quan hệ N-N.
4. **`index.html`** — cập nhật thẻ 02/03/07, thêm thẻ 02b/03c, thêm đoạn
   banner "Định hướng mới — chưa code" vào masthead.
5. **`styles.css`** — thêm class mới: `.net-badge`, `.net-note`,
   `.source-tag` (trạng thái mạng); `.lesson-list`/`.lesson-row` (danh sách
   Chapter); `.article-wrap`/`.article-title`/`.article-body`/`.vocab-hl`
   (bài đọc dạng article). Không sửa class cũ đang dùng ở màn khác.

Toàn bộ màn mới/sửa đều ghi rõ banner "⚠️ Định hướng mới — chưa code" trong
`frame-desc`, trỏ về `docs/csb-vocab-analysis/00_Overview.md` và
`docs/spec_history.md` — nhất quán với cách đã làm ở [IMPL-006] cho tài liệu
phân tích.

### Tài liệu đã cập nhật

| File | Thay đổi |
|---|---|
| `docs/artifact-design/screens/screen-02-tra-cuu.html` | Thêm badge Offline, sửa link điều hướng cuối trang |
| `docs/artifact-design/screens/screen-02b-tra-cuu-online.html` | **Mới** — trạng thái Online |
| `docs/artifact-design/screens/screen-03-hoc-danh-sach-section.html` | **Mới** — thay `screen-03-hoc-danh-sach-chuong.html` (đã xoá) |
| `docs/artifact-design/screens/screen-03b-hoc-danh-sach-chapter.html` | **Mới** — thay `screen-03b-danh-sach-tu-a-z.html` (đã xoá) |
| `docs/artifact-design/screens/screen-03c-hoc-noi-dung-bai.html` | **Mới** — bài đọc dạng article |
| `docs/artifact-design/screens/screen-04-chi-tiet-tu.html` | Sửa link điều hướng trỏ về 03c thay vì 03b cũ |
| `docs/artifact-design/screens/screen-07-tu-dien-cua-toi.html` | Bỏ nhắc "6 chương" cứng, đổi tên thẻ bộ mặc định |
| `docs/artifact-design/index.html` | Cập nhật/thêm thẻ màn hình, thêm banner định hướng mới |
| `docs/artifact-design/styles.css` | Thêm class mới cho badge mạng, danh sách bài học, bài đọc article |

### Điểm chờ xác nhận còn mở

Không phát sinh câu hỏi mới — mockup minh hoạ trực quan cho Q-CSB-04..07 đã
ghi ở [IMPL-005], chưa tự ý chốt các điểm đó (ví dụ: API cụ thể, có lưu từ
tra online hay không, cách trích xuất `.docx`). `docs/artifact-design-
windows/` (bản Windows) **chưa cập nhật** — làm ở bước sau theo yêu cầu.

---

## [IMPL-007] 2026-07-18 — Chốt dùng Drift thay cho sqlite3 raw cho schema mới

**Người yêu cầu:** User · **Người thực hiện:** Claude

### Nội dung

Trao đổi về việc truy vấn SQLite sẽ phức tạp hơn khi thêm bộ từ điển N-N,
Section/Chapter, và các truy vấn ôn tập mở rộng trong tương lai — có nên gọi
`sqlite3` trực tiếp hay qua một lớp nữa, và có cần ORM không.

**Đã chốt:** chuyển sang **Drift** (type-safe query builder + code gen cho
SQLite trên Flutter, dùng `build_runner`) thay cho gọi `sqlite3` package
trực tiếp như hiện tại (`lib/data/local/vocab_database.dart`,
`user_database.dart`). Áp dụng **ngay từ bước thiết kế schema mới** (bảng
N-N `word_dictionaries`, Section/Chapter), không chờ đổi sau — chấp nhận chi
phí viết lại data layer hiện tại một lần thay vì đổi 2 lần (raw → raw mới →
Drift). Việc dùng Repository pattern làm lớp trung gian (đã có sẵn qua
`VocabRepository`) vẫn giữ nguyên — Drift không thay thế Repository, mà thay
thế cách Repository nói chuyện với SQLite bên trong.

Lý do chính: schema dự kiến đổi nhiều lần trong thời gian ngắn (N-N bộ từ
điển, Section/Chapter dạng bài báo, có thể thêm bảng ôn tập mở rộng sau) —
Drift cho type-safe query + migration kiểm tra được lúc compile, giảm rủi ro
lỗi runtime khi cột/bảng đổi so với viết SQL string tay.

### Tài liệu đã cập nhật

| File | Thay đổi |
|---|---|
| `docs/csb-vocab-analysis/00_Overview.md` | Thêm ghi chú Drift vào mục Dữ liệu (Kiến trúc kỹ thuật); thêm dòng D3 vào bảng "Quyết định đã chốt" |

### Điểm chờ xác nhận còn mở

Không phát sinh câu hỏi mới. Việc thiết kế schema Drift cụ thể (bảng, cột,
migration) sẽ làm ở bước implement sau, sau khi Q-CSB-04..07 ([IMPL-005])
được trả lời.

---

## [IMPL-006] 2026-07-18 — Lan tỏa định hướng mới vào 02_Search.md, 03_Lessons-by-chapter.md, bảng truy vết

**Người yêu cầu:** User · **Người thực hiện:** Claude

### Nội dung

Tiếp nối [IMPL-005] (chốt định hướng mới ở `00_Overview.md`), cập nhật các
tài liệu phân tích màn hình còn lại theo cùng định hướng — tra cứu 2 trạng
thái Offline/Online, bộ từ điển N-N (mặc định + cá nhân), Section chứa nhiều
Chapter hiển thị dạng bài báo. Nguyên tắc áp dụng: **giữ nguyên nội dung mô
tả code thật hiện có**, chỉ gắn nhãn `[ĐÃ CODE]` rõ ràng, và thêm phần mới
riêng biệt mô tả định hướng `[CHƯA CODE]` — không xoá hay viết đè thông tin
về hành vi thật đang chạy.

1. **`02_Search.md`** — tách "Hành vi"/"Truy vấn dữ liệu"/"Phụ thuộc" hiện
   có thành "...— Chế độ Offline [ĐÃ CODE]"; thêm mục mới "Chế độ Online —
   định hướng mới [CHƯA CODE]" mô tả cơ chế phát hiện mạng, hành vi gọi
   thêm API ngoài, câu hỏi về lưu từ mới tra được, và ảnh hưởng tới
   `searchProvider`/`VocabRepository`.
2. **`03_Lessons-by-chapter.md`** — đây là thay đổi mô hình lớn nhất: khái
   niệm "chương" (nhóm từ, 1-N) sẽ trở thành "bộ từ điển mặc định"; "Chapter"
   được định nghĩa lại thành 1 bài học dạng bài báo, nằm trong "Section" (cấp
   mới). Thêm mục "Mô hình mới: Section / Chapter dạng bài báo [CHƯA CODE]"
   với bảng đối chiếu ý nghĩa cũ/mới, hành vi điều hướng dự kiến (tối thiểu
   3 cấp: Section → Chapter → nội dung bài), và ảnh hưởng tầng dữ liệu
   (`chapter_words`, quy trình từ `.docx`). Ghi rõ đây **không phải chỉnh
   sửa nhỏ** — màn hình sẽ cần viết lại gần như hoàn toàn khi mô hình mới
   được code.
3. **`90_Traceability-matrix.md`** — thêm banner nói rõ bảng phản ánh code
   thật (mô hình cũ); thêm 2 dòng vào bảng "Truy vết mockup ↔ code" cho 2
   khoảng cách mới (tra cứu online, Section/Chapter dạng bài báo).
4. **`README.md`** — nâng phiên bản lên 1.2, thêm banner định hướng mới ở
   đầu trỏ tới `00_Overview.md`, cập nhật dòng lịch sử.

### Tài liệu đã cập nhật

| File | Thay đổi |
|---|---|
| `docs/csb-vocab-analysis/02_Search.md` | Gắn nhãn `[ĐÃ CODE]` cho hành vi hiện tại; thêm mục "Chế độ Online — định hướng mới [CHƯA CODE]" |
| `docs/csb-vocab-analysis/03_Lessons-by-chapter.md` | Gắn nhãn `[ĐÃ CODE]` cho mô hình cũ; thêm mục "Mô hình mới: Section / Chapter dạng bài báo [CHƯA CODE]" |
| `docs/csb-vocab-analysis/90_Traceability-matrix.md` | Thêm banner cảnh báo phạm vi; thêm 2 dòng khoảng cách mockup↔code mới |
| `docs/csb-vocab-analysis/README.md` | Nâng phiên bản 1.2, thêm banner định hướng mới, cập nhật lịch sử |

### Điểm chờ xác nhận còn mở

Không phát sinh câu hỏi mở mới — vẫn dùng Q-CSB-04..07 đã ghi ở [IMPL-005].
Xem thêm ghi chú trong `03_Lessons-by-chapter.md` mục "Hành vi dự kiến": vị
trí chính xác của "duyệt theo bộ từ điển mặc định" trong điều hướng chính
(tab nào) chưa chốt, cần rà soát cùng `07_Home-shell.md` và mockup "Từ điển
của tôi" khi bước sang cập nhật `docs/artifact-design/`.

---

## [IMPL-005] 2026-07-18 — Định hướng mới: tra cứu online/offline, bộ từ điển N-N, Section/Chapter dạng bài báo

**Người yêu cầu:** User · **Người thực hiện:** Claude

### Nội dung

User đưa ra định hướng mở rộng đáng kể so với code thật hiện tại (chưa
triển khai, mới cập nhật tài liệu phân tích):

1. **Tra cứu 2 trạng thái** — Offline: chỉ `vocab.db` local (giữ nguyên hành
   vi hiện tại). Online: `vocab.db` local **+** gọi thêm API từ điển ngoài
   cho từ không có sẵn. Ràng buộc "Offline hoàn toàn" đổi thành
   "Offline-first, online tùy chọn" — toàn bộ tính năng cốt lõi vẫn phải
   chạy được không cần mạng.
2. **Bộ từ điển (dictionary), quan hệ N-N với từ** — khái niệm "chương" hiện
   tại (bảng `chapters`, 6 chương cố định, quan hệ 1-N với từ qua
   `chapter_id`) được diễn giải lại thành **1 bộ từ điển mặc định**. Một từ
   có thể thuộc **nhiều** bộ từ điển cùng lúc (cần bảng trung gian N-N thay
   cột `chapter_id` đơn). 2 loại: mặc định (đóng gói sẵn, read-only) và cá
   nhân (user tự tạo **nhiều** bộ, tự thêm/bỏ từ — giống playlist, xác nhận
   lại hướng đã có ở mockup cũ Q-CSB-02).
3. **Section → Chapter, Chapter là bài học dạng bài báo** — Section là cấp
   mới, đứng trên Chapter (1 Section nhiều Chapter). Chapter được định nghĩa
   lại: không còn là nhóm từ vựng (vai trò đó nay thuộc "bộ từ điển mặc
   định" ở mục 2) mà là **1 bài học hiển thị dạng bài báo/bài đọc chuyên
   ngành**, từ vựng lồng trong nội dung bài thay vì liệt kê trần. Nguồn nội
   dung hiện là file Word (`.docx`).

Đây là **thay đổi mô hình dữ liệu + kiến trúc lớn**, ảnh hưởng dây chuyền
tới `vocab.db` schema, `VocabRepository`, các provider, và toàn bộ UI của
SCR-02 (Tra cứu) và SCR-03 (Học theo chương). Bước này **chỉ cập nhật
`00_Overview.md`** để chốt khung khái niệm chung; các file `01`–`07` và
`docs/artifact-design/` sẽ cập nhật ở bước kế tiếp theo yêu cầu của user.

### Tài liệu đã cập nhật

| File | Thay đổi |
|---|---|
| `docs/csb-vocab-analysis/00_Overview.md` | Thêm banner định hướng mới ở đầu file; thêm mục "Mô hình dữ liệu — định hướng mới" (trạng thái online/offline, bộ từ điển N-N, Section/Chapter); cập nhật Ràng buộc, Glossary, Câu hỏi mở |

### Điểm chờ xác nhận còn mở

| # | Câu hỏi |
|---|---|
| Q-CSB-04 | API từ điển ngoài dùng khi online là nhà cung cấp nào cụ thể (Oxford, Free Dictionary API, Google...)? Ảnh hưởng chi phí, giới hạn rate, và cách xử lý lỗi mạng chập chờn. |
| Q-CSB-05 | Từ tra được qua API ngoài khi online có được lưu lại vào DB local để dùng khi offline không? Nếu có, lưu vào bộ từ điển nào (mặc định hay tự tạo 1 bộ "đã tra online" riêng)? |
| Q-CSB-06 | Cơ chế phát hiện trạng thái online/offline dùng gói nào (`connectivity_plus`?) và có xử lý trường hợp "có kết nối mạng nhưng API đích không phản hồi" (khác với offline hẳn) không? |
| Q-CSB-07 | Quy trình chuyển nội dung bài học từ file Word (`.docx`) sang dữ liệu có cấu trúc (Section → Chapter → nội dung bài + từ vựng liên kết) sẽ làm thủ công, bán tự động (script + soát lại), hay tự động hoàn toàn? Ảnh hưởng trực tiếp tới việc có tách bảng `chapter_words` riêng hay suy ra từ nội dung bài lúc hiển thị. |

---

## [IMPL-004] 2026-07-18 — Tách tài liệu nguồn (docx/pdf) ra khỏi assets/

**Người yêu cầu:** User · **Người thực hiện:** Claude

### Nội dung

`assets/` trước đây lẫn giữa tài nguyên runtime thật (những gì
`pubspec.yaml` đóng gói vào app: `db/vocab.db`, cộng `images/words/` dự
phòng) và tài liệu nguồn chỉ dùng lúc biên soạn dữ liệu
(`TA_chuyen_nganh.docx`, `TA_chuyen_nganh_2.pdf`, `Tu_dien.pdf`) — không file
nào trong 3 file này được `pubspec.yaml` khai báo hay code Dart đọc.

Chuyển 3 file đó (bằng `git mv`, giữ lịch sử) sang
`docs/source-materials/`, kèm `README.md` giải thích. **Giữ nguyên
`assets/csb-logo.png` trong `assets/`** theo yêu cầu — dù cũng chưa được
`pubspec.yaml` khai báo, logo có thể dùng làm app icon/splash chính thức
trong tương lai nên hợp lý để gần code hơn là tài liệu tham khảo thuần tuý.

### Tài liệu đã cập nhật / tạo mới

| File | Thay đổi |
|---|---|
| `assets/README.md` | Viết lại — chỉ liệt kê tài nguyên runtime thật, ghi rõ file nào chưa khai báo trong `pubspec.yaml` |
| `docs/source-materials/README.md` | Tạo mới — giải thích 3 file tài liệu nguồn vừa chuyển tới |

---

## [IMPL-003] 2026-07-18 — Xoá tài liệu thiết kế DB, đổi tên file phân tích sang tiếng Anh

**Người yêu cầu:** User · **Người thực hiện:** Claude

### Nội dung

1. **Xoá `docs/03-thiet-ke-co-so-du-lieu.md`** (tạo ở [IMPL-002] mục 7) theo
   yêu cầu trực tiếp — nội dung schema `vocab.db`/`user.db` + cơ chế SM-2
   **không được chuyển đi đâu khác**, chỉ còn suy ra được từ code thật
   (`lib/data/local/`, `lib/domain/srs/srs_scheduler.dart`).
2. **Đổi tên toàn bộ file trong `docs/csb-vocab-analysis/` sang tiếng Anh**
   (giữ nguyên nội dung tiếng Việt bên trong, chỉ đổi tên file) — xem bảng
   đối chiếu trong `docs/csb-vocab-analysis/README.md`.
3. Cập nhật mọi liên kết ở `README.md`, `docs/README.md`, `assets/README.md`
   trỏ tới file đã xoá — trỏ sang `docs/csb-vocab-analysis/` hoặc thẳng vào
   file code nguồn thay thế.

### Điểm chờ xác nhận còn mở

| # | Câu hỏi |
|---|---|
| Q-CSB-03 | Tài liệu thiết kế DB cho báo cáo bàn giao (mục 3 trong `docs/README.md`) hiện chưa có bản nháp nào — cần viết lại khi nào, và có cần giữ định dạng cũ (bảng schema, sơ đồ quan hệ, công thức SM-2) hay chỉ cần bản tóm tắt ngắn? |

---

## [IMPL-002] 2026-07-18 — Tái cấu trúc thư mục dự án + bổ sung tài liệu phân tích

**Người yêu cầu:** User · **Người thực hiện:** Claude

### Nội dung

Dọn dẹp cấu trúc repo sau khi phần khung ứng dụng (Giai đoạn 0–1) đã ổn định:

1. **Đưa project Flutter ra khỏi lớp `src/` trung gian** — `csb-vocab-app/` giờ
   là project Flutter chạy trực tiếp (`flutter run`/`flutter build` từ root),
   không cần `cd src/` trước.
2. **Xoá `plan/`** (7 file đặc tả ban đầu — yêu cầu chức năng, kiến trúc, thiết
   kế dữ liệu, roadmap, Q&A chốt) vì nội dung đã lỗi thời so với code thật và
   được thay thế bởi tài liệu trong `docs/` (thiết kế DB, mockup UI) cùng
   thư mục phân tích mới `docs/csb-vocab-analysis/`.
3. **Xoá `tools/pdf_to_sqlite/`** (script Python parse PDF → `vocab.db`) — đã
   chạy xong, `vocab.db` sinh ra đã đóng gói sẵn trong `assets/db/`, không cần
   giữ script trong repo ứng dụng.
4. **Xoá `test/`** (unit test SM-2 scheduler + widget smoke test) theo yêu cầu
   trực tiếp của user.
5. **Thêm `.claude/skills/`** — copy các skill Flutter/quản lý task dùng
   chung từ một project khác (`Sato/agent`): `app-flutter-skill`,
   `business-logic-flow`, `context-engineering`, `project-context`,
   `task-analysis`, `task-brainstorm`, `task-implement`,
   `task-implement-app`, `task-manager-project`, `task-plan`.
6. **Thêm mockup UI tĩnh** cho cả mobile (`docs/artifact-design/`) và Windows
   desktop (`docs/artifact-design-windows/`) — 13 màn/bản, dùng bảng màu lấy
   trực tiếp từ `assets/csb-logo.png` (xem
   `docs/artifact-design/bang-mau-ung-dung.md`). **Lưu ý:** mockup này đã đi
   trước code thật một bước — có tính năng mới chưa code (bộ từ điển cá nhân,
   ôn tập trộn 3 dạng câu) và đổi cấu trúc điều hướng (gộp "Ôn tập" vào "Từ
   điển của tôi", bỏ chế độ flashcard học-từ-mới ở màn Học). Xem
   `docs/csb-vocab-analysis/README.md` mục trạng thái để phân biệt phần đã
   code với phần mới ở mockup.
7. **Thêm `docs/03-thiet-ke-co-so-du-lieu.md`** — tài liệu thiết kế DB viết
   lại theo đúng schema thực tế của `vocab.db`/`user.db` (khác với bản kế
   hoạch ban đầu trong `plan/04-thiet-ke-du-lieu.md`, vốn có vài chỗ lệch so
   với lúc triển khai thật).
8. **Thêm `docs/csb-vocab-analysis/`** (entry này) — phân tích từng màn hình
   *đã code thật* trong `lib/features/`, theo format rút gọn từ
   `Sato/agent/docs/cloud-print-analysis/` (bỏ phần vai trò nhiều tầng/Web
   admin vì csb-vocab-app là app 1 người dùng, offline, không backend).

### Tài liệu tạo mới

| File | Nội dung |
|---|---|
| `docs/03-thiet-ke-co-so-du-lieu.md` | Schema `vocab.db`/`user.db` thực tế + cơ chế SM-2. **Đã xoá ở [IMPL-003].** |
| `docs/artifact-design/` | Mockup UI mobile, 13 màn, + ảnh chụp + PDF gộp |
| `docs/artifact-design-windows/` | Mockup UI Windows desktop, 13 màn tương ứng |
| `docs/csb-vocab-analysis/README.md` | Tổng quan + bảng danh sách màn hình đã code |
| `docs/csb-vocab-analysis/00_Tong-quan.md` | Bối cảnh, kiến trúc, ràng buộc, glossary. **Đổi tên thành `00_Overview.md` ở [IMPL-003].** |
| `docs/csb-vocab-analysis/01..07_*.md` | Phân tích từng màn hình thật. **Đổi tên sang tiếng Anh ở [IMPL-003]** (xem `docs/csb-vocab-analysis/README.md`) |
| `docs/csb-vocab-analysis/90_Bang-truy-vet.md` | Truy vết FR ↔ màn hình ↔ file code. **Đổi tên thành `90_Traceability-matrix.md` ở [IMPL-003].** |

### Điểm chờ xác nhận còn mở

| # | Câu hỏi |
|---|---|
| Q-CSB-01 | FR-6 không xuất hiện trong bất kỳ comment code nào (FR-1, 2, 3, 4, 5, 7 đều có) — số hiệu này có từng được gán cho một yêu cầu đã bỏ/gộp trong `plan/` cũ không, hay chỉ là khoảng trống trong đánh số gốc? Không thể xác minh vì `plan/` đã bị xoá ở mục 2. |
| Q-CSB-02 | Mockup (`docs/artifact-design/`) đã thiết kế "Từ điển của tôi" (bộ từ vựng cá nhân, 3 kiểu ôn trộn lẫn) và bỏ segmented control Học theo chương/Từ mới — có chốt triển khai code theo đúng hướng mockup này không, hay mockup chỉ mang tính tham khảo? |

---

## [SPEC-BASE] (không rõ ngày — trước phiên làm việc này) — Spec gốc

Đặc tả ban đầu từng nằm ở `plan/00-tong-quan.md` → `plan/06-cau-hoi-can-chot.md`
(đã xoá ở [IMPL-002] mục 2). Tóm tắt còn giữ lại được qua comment trong code:
ứng dụng học từ vựng chuyên ngành Cảnh sát biển Việt Nam, offline-first,
Windows → Android → iOS, SQLite (`vocab.db` read-only + `user.db` read-write),
ôn tập theo thuật toán SM-2 (Phương án A đã chốt tại Q&A 06, xem
`docs/03-thiet-ke-co-so-du-lieu.md` mục 3).
