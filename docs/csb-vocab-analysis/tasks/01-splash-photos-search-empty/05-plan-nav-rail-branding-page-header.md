# Task 01 (nhánh phụ) — Plan: Nav-rail có logo/brand + page-header theo mockup Windows

## Task-plan

> Input: `01-analysis.md` + so sánh trực tiếp app thật vs mockup do user
> chụp, đối chiếu thêm bản mobile
> (`docs/artifact-design/screens/screen-02-tra-cuu.html`,
> `docs/artifact-design/styles.css`). `HomeShell` hiện chỉ có
> `NavigationRail`/`NavigationBar` icon+label trần, không có logo/brand ở
> đầu (Windows), không có `page-header`/`appbar` riêng cho từng tab
> (đang dùng chung 1 `Scaffold.appBar`), không có badge Offline/Online.
>
> **Đối chiếu đã xác nhận (khác với bản plan trước):** badge `.net-badge`
> **có ở cả 2 nền tảng** — Windows đặt trong `page-header`
> (`styles.css` dòng 289–306), Mobile đặt trong `.appbar` (`docs/artifact-
> design/styles.css` dòng ~195–236, xem `screen-02-tra-cuu.html` mobile
> dòng 31–37). Chỉ riêng khối **logo/brand** (`nav-rail-brand`) là
> **chỉ có ở Windows** — mobile không có khái niệm này vì dùng
> `NavigationBar` ở đáy, không có rail để đặt brand.

## Requirement Summary

### Selected Approach

Tách rõ theo mức độ phụ thuộc:

1. **Nav-rail brand (chỉ Windows)** — thuần UI tĩnh, không cần dữ liệu/
   package mới. Thêm khối `nav-rail-brand` (icon la bàn trong khung bo góc
   + "CSB Vocab" + "Cảnh sát biển VN") lên đầu `NavigationRail` trên
   Windows. Mobile không đổi.
2. **Page-header/appbar riêng theo tab (cả 2 nền tảng)** — Windows đổi từ
   `Scaffold.appBar` sang widget `page-header` trong nội dung (giống cấu
   trúc mockup: tiêu đề nằm trong `page-body`, tách khỏi title bar cửa
   sổ). Mobile **giữ nguyên `Scaffold.appBar`** — cấu trúc thực tế đã
   tương đương `.appbar` trong mockup mobile (thanh trên cùng, tiêu đề +
   badge), không cần đổi kiến trúc, chỉ cần thêm badge (mục 3).
3. **Badge Offline/Online (cả 2 nền tảng)** — cần provider trạng thái
   mạng mới (gói `connectivity_plus`, đã chốt Q-CSB-06 ở `02_Search.md`
   nhưng **chưa có trong `pubspec.yaml`**). Đây là dependency mới + logic
   mới (khác 2 việc trước chỉ là UI/refactor) — tách thành subtask riêng,
   rủi ro cao hơn. Áp dụng cho **cả `page-header` (Windows) và
   `Scaffold.appBar` (Mobile)**.

### Scope

- `HomeShell`: thêm brand header phía trên `NavigationRail` khi
  `isDesktop` (Windows only).
- Windows: đổi `page-header` (tiêu đề tab) từ `Scaffold.appBar` sang
  widget riêng trong nội dung, khớp mockup (tiêu đề nằm trong `page-body`,
  không phải title bar toàn cửa sổ).
- Mobile: **không đổi cấu trúc** `Scaffold.appBar` — chỉ thêm badge (mục
  dưới) vào `actions` của `AppBar` hiện có.
- Thêm subtask riêng (rủi ro cao hơn, có thể làm sau) cho badge Offline/
  Online dùng `connectivity_plus`.

### Out of Scope

- Mobile: brand header (`nav-rail-brand`) — chỉ Windows có, không thêm gì
  tương đương cho mobile.
- Mobile: cấu trúc `Scaffold.appBar` — giữ nguyên, chỉ thêm badge vào
  `actions`, không đổi widget/layout khác.
- Title bar tuỳ biến Windows (nút minimize/maximize/close riêng, khác
  `titlebar` trong mockup) — gap khác, không thuộc phạm vi này.
- Nội dung badge "Online" hiển thị gì khi có mạng thật (gọi API từ điển
  ngoài) — đó là luồng nghiệp vụ Online đã bàn ở `02_Search.md`, phạm vi
  ở đây **chỉ hiển thị badge**, không gọi API ngoài.

## API Contract

Không áp dụng cho phần nav-rail/page-header (thuần UI). Phần badge cần
platform API nội bộ của `connectivity_plus` (không phải HTTP API) — xem
ghi chú trong BE-01 bên dưới.

| Item | Value |
|---|---|
| API name | N/A |
| Endpoint | N/A |
| Method | N/A |
| Auth required | N/A |
| Permission rule | N/A |
| Request params | N/A |
| Request body | N/A |
| Success response | N/A |
| Validation error response | N/A |
| Business error response | N/A |
| Auth/session error response | N/A |
| Permission error response | N/A |
| Frontend caller | N/A |
| Backend handler | N/A |

## Subtask Breakdown

### Backend Subtasks

Không có backend thật (app offline-first, không server) — nhưng thêm
provider trạng thái mạng liệt kê ở đây vì đây là tầng "hạ tầng" dùng
chung, không phải UI thuần.

| Subtask ID | Title | Files/Modules | Description | Depends On | Risk |
|---|---|---|---|---|---|
| BE-01 | Thêm `connectivity_plus` + `connectivityProvider` | `pubspec.yaml`, `lib/data/services/connectivity_service.dart` (mới), `lib/core/providers/` (mới hoặc chỗ phù hợp) | Thêm dependency `connectivity_plus` vào `pubspec.yaml`. Tạo provider Riverpod (`StreamProvider<bool>` hoặc tương đương) bọc `Connectivity().onConnectivityChanged`, trả về `true`/`false` (có mạng hay không) — theo đúng quyết định Q-CSB-06 (`docs/spec_history.md` [IMPL-013]) | None | Trung bình — dependency mới, cần test trên cả Windows/mobile vì hành vi `connectivity_plus` khác nhau giữa nền tảng |

### Frontend Subtasks

| Subtask ID | Title | Files/Modules | Description | Depends On | Risk |
|---|---|---|---|---|---|
| FE-07 | `HomeShell`: thêm brand header trên nav-rail (Windows) | `lib/features/home/home_shell.dart` | Thêm widget `_NavRailBrand` (icon la bàn trong `Container` bo góc màu navy + tên "CSB Vocab" + phụ đề "Cảnh sát biển VN", font serif cho tên chính giống mockup) hiện phía trên `NavigationRail` khi `isDesktop`, bọc cả 2 trong 1 `Column` thay vì chỉ render `NavigationRail` trực tiếp | None | Thấp — thuần thêm widget tĩnh, không đổi logic điều hướng |
| FE-08 | `HomeShell`: `page-header` riêng cho mỗi tab (Windows) | `lib/features/home/home_shell.dart` | Khi `isDesktop`: bỏ `Scaffold.appBar`, thay bằng `Column` gồm 1 header riêng (tiêu đề tab bằng font serif, giữ badge số ôn tập nếu cần) + `Expanded(child: body)`. Mobile giữ nguyên `Scaffold.appBar` như cũ (không đổi) | None | Trung bình — cần đảm bảo `AppBar` hiện đang cho `SafeArea`/status bar đúng trên Windows không bị mất khi bỏ `Scaffold.appBar` |
| FE-09 | Badge Offline/Online — cả Windows lẫn Mobile | `lib/features/home/home_shell.dart` | Đọc `connectivityProvider` (từ BE-01), hiện badge bo tròn "Online"/"Offline" (icon wifi tương ứng, màu xanh lá/xám giống mockup `.net-badge`) — Windows: đặt ở góc phải `page-header` (từ FE-08); Mobile: đặt trong `actions` của `Scaffold.appBar` hiện có (đã xác nhận mockup mobile `screen-02-tra-cuu.html` cũng có `.net-badge` trong `.appbar`, không phải chỉ Windows) | FE-08, BE-01 | Trung bình — phụ thuộc BE-01 xong trước; cần thêm 1 widget badge dùng chung cho cả 2 nơi đặt khác nhau (page-header vs AppBar actions) để tránh viết trùng code |

### Integration Subtasks

| Subtask ID | Title | Files/Modules | Description | Depends On | Risk |
|---|---|---|---|---|---|
| INT-03 | Verify brand/header trên Windows, không phá Mobile | `lib/features/home/home_shell.dart` | Chạy Windows: xác nhận brand header hiện đúng phía trên nav-rail, mỗi tab có tiêu đề riêng khớp tên tab, không bị lặp tiêu đề (title bar hệ điều hành + page-header). Chạy Mobile: xác nhận `AppBar` không đổi, không có brand header thừa | FE-07, FE-08 | Thấp |
| INT-04 | Verify badge Offline/Online cả 2 nền tảng | `lib/features/home/home_shell.dart` | Bật/tắt mạng thật, xác nhận badge đổi trạng thái đúng trên cả Windows và 1 thiết bị mobile, không crash khi mất mạng đột ngột giữa lúc dùng app | FE-09 | Trung bình |

## Recommended Execution Order

### Option A: "Backend" (connectivity provider) First

Order: BE-01 → FE-09 (badge) song song hoặc sau FE-07/FE-08 → FE-07 → FE-08 → INT-03 → INT-04

### Option B: Frontend First (UI tĩnh trước, badge sau)

Order: FE-07 → FE-08 → INT-03 → **(điểm dừng, xác nhận UI khớp mockup)** → BE-01 → FE-09 → INT-04

### Recommended Option

Recommend: **Option B — làm UI tĩnh (FE-07, FE-08) trước, xác nhận khớp
mockup qua INT-03, rồi mới thêm badge (BE-01, FE-09) ở lượt sau.**

Reason:

- FE-07/FE-08 là thuần UI, rủi ro thấp, không phụ thuộc gì — nên làm
  trước để nhanh chóng khớp phần lớn khoảng cách trực quan nhất (logo,
  tiêu đề trang).
- Badge Offline/Online kéo theo dependency mới (`connectivity_plus`) —
  tách thành lượt riêng để không trộn 1 thay đổi UI đơn giản với 1 thay
  đổi có rủi ro dependency/platform-behavior cao hơn. Nếu gộp chung, khó
  xác định lỗi (nếu có) đến từ UI hay từ provider mạng mới.
- Cho phép dừng lại xác nhận với user sau INT-03 trước khi thêm
  dependency mới — tôn trọng nguyên tắc "giữ scope nhỏ".

## User Decision Required

```text
Implement frontend first (UI tĩnh trước): use task-implement-frontend with FE-07
Implement backend/provider first (badge trước): use task-implement-backend with BE-01
```

## Manual Verification Plan

### Main Flow

- [ ] Windows: mở app, nav-rail bên trái có khối brand (icon + "CSB
      Vocab" + "Cảnh sát biển VN") phía trên danh sách 5 tab.
- [ ] Chuyển giữa các tab (Tra cứu/Học/Dịch/Ôn tập/Cài đặt) — mỗi tab có
      tiêu đề riêng đúng tên, không lặp 2 lần tiêu đề trên cùng màn hình.
- [ ] (Sau khi làm FE-09) Bật/tắt Wi-Fi thật — badge đổi Online ⇄ Offline
      đúng theo trạng thái mạng thực tế.

### UI Verification

- [ ] Brand header không đè/chồng lên `nav-item` đầu tiên, khoảng cách
      giống tỉ lệ mockup.
- [ ] Page-header không bị mất khoảng cách an toàn (safe area) trên
      Windows — so sánh với `AppBar` cũ để không bị giật layout khi
      chuyển đổi.
- [ ] Mobile: xác nhận không có brand header/page-header mới xuất hiện
      ngoài ý muốn — `AppBar` giữ nguyên y hệt trước khi đổi.

### API Verification

Không áp dụng (không phải HTTP API) — riêng BE-01: xác nhận
`connectivityProvider` trả đúng giá trị bool khi test thủ công bật/tắt
mạng (xem Error/Edge Case).

### Error / Edge Case

- [ ] Mất mạng đột ngột giữa lúc app đang chạy — `connectivityProvider`
      không throw lỗi làm crash `HomeShell`.
- [ ] Windows không hỗ trợ 1 số API mạng giống mobile (cần kiểm tra tài
      liệu `connectivity_plus` cho desktop) — nếu có giới hạn, ghi chú lại
      trong code.

### SPA / Browser Behavior

Không áp dụng.

### Regression

- [ ] Toàn bộ điều hướng tab, badge số từ đến hạn ôn tập (`dueCount`)
      hiện tại không bị ảnh hưởng bởi việc thêm brand header/page-header
      mới.
- [ ] `SearchScreen` (2 cột vừa code ở subtask trước) vẫn hoạt động đúng
      sau khi `HomeShell` đổi cấu trúc `Scaffold.appBar` → `page-header`
      riêng.

## Risks / TODO

- **Đã xác nhận** (đối chiếu `docs/artifact-design/screens/screen-02-tra-
  cuu.html` + `docs/artifact-design/styles.css`): mockup mobile **cũng có**
  `.net-badge` trong `.appbar` — badge Offline/Online áp dụng cho **cả 2
  nền tảng**, không chỉ Windows. Kế hoạch ở trên đã cập nhật theo đúng
  phát hiện này (không còn là điểm mở).
- Đổi `Scaffold.appBar` → widget `page-header` tự viết trên Windows có
  thể ảnh hưởng tới các thành phần Material mặc định dựa vào `AppBar`
  (vd `Scaffold.of(context).appBarMaxHeight`, `SliverAppBar` nếu có nơi
  nào dùng) — cần rà lại toàn bộ `lib/features/*/*.dart` xem có phụ thuộc
  ngầm vào `AppBar` hiện tại không trước khi bỏ hẳn trên Windows.
- `connectivity_plus` là dependency mới — cần chạy `flutter pub get` và
  xác nhận build Windows/Android không phát sinh lỗi native plugin trước
  khi coi BE-01 là xong.
