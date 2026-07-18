# Task 01 — Đối ứng mockup Win/Mobile: Ảnh Splash + Trạng thái rỗng Tra cứu

## Implementation Plan

> Task-plan only — **không sửa code**. Input: `01-analysis.md` (cùng thư
> mục), làm rõ phạm vi qua câu trả lời user: "thêm ảnh vào nữa" → gộp 2
> việc liên quan chặt: (1) thay placeholder `Icon(Icons.anchor)` ở Splash
> (SCR-01) bằng 3 ảnh CSB thật, (2) thêm màn trạng thái rỗng mới cho Tra
> cứu (SCR-02c mockup) dùng cùng 3 ảnh, thay thế `_Hint` hiện tại. Cả 2
> dùng chung 1 bộ ảnh và chung 1 pattern carousel.

## Requirement Summary

### Selected Approach

Dùng carousel ảnh thật (đã có sẵn ở
`docs/artifact-design/assets/images/csb-slide-0{1,2,3}.jpg`, nguồn từ user
cung cấp — xem [IMPL-009]) ở 2 nơi:

1. **Splash (SCR-01):** thay `Icon(Icons.anchor)` placeholder trong mỗi
   slide gradient bằng ảnh thật tương ứng (giữ nguyên gradient + tiêu đề/phụ
   đề, chỉ đổi phần icon → ảnh — đúng tinh thần mockup: `docs/artifact-
   design/screens/screen-01-splash.html` vẫn dùng icon la bàn SVG minh hoạ,
   nhưng comment code Flutter đã ghi rõ ý định thay bằng ảnh thật).
2. **Tra cứu — trạng thái rỗng (SCR-02c):** thêm carousel autoplay 3 ảnh
   thay cho `_Hint` khi `_query` rỗng, theo đúng mockup `screen-02c-tra-cuu-
   trong.html` (dùng lại `carousel_slider` đã có trong `pubspec.yaml`, không
   cần dependency mới).

Không đổi bộ ảnh khác nhau cho Windows vs Mobile — cùng 3 ảnh, cùng
`CarouselSlider` config, chỉ khác kích thước/vị trí theo layout desktop
2 cột (`pane-detail-empty`) vs mobile full-screen (đã thấy rõ trong 2 bộ
mockup, giống hệt cách `HomeShell` đã tách layout hiện tại).

### Scope

- Đưa 3 ảnh CSB thật vào runtime asset (`assets/images/`), khai báo trong
  `pubspec.yaml`.
- `SplashScreen`: đổi placeholder icon → ảnh thật trong từng slide.
- `SearchScreen`: thêm trạng thái rỗng mới (carousel ảnh) thay cho `_Hint`,
  áp dụng cho cả Windows và Mobile (cùng logic, khác style bao ngoài theo
  breakpoint đã có).

### Out of Scope

- Badge Offline/Online (`.net-badge`), banner "online" (`screen-02b`) —
  thuộc gap khác trong `01-analysis.md`, không nằm trong yêu cầu "thêm
  ảnh" lần này.
- Section/Chapter dạng bài báo, tab "Từ điển của tôi" — không liên quan.
- Xác nhận bản quyền/nguồn ảnh chính thức (Q mở ở [IMPL-009]) — **đây là
  rủi ro cần xử lý trước khi merge**, xem mục Risks bên dưới, nhưng không
  phải việc "code" nên không tách subtask riêng.
- Title bar tuỳ biến Windows — không liên quan.

## API Contract

Không áp dụng — đây là task thuần UI/asset nội bộ app, không có API
HTTP/backend nào liên quan (offline-first, không có tầng gọi mạng ở cả 2
màn này).

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

Không có Backend subtask (app không có tầng backend/API riêng cho 2 màn
này). Toàn bộ việc là Frontend (Flutter) + 1 subtask chuẩn bị asset dùng
chung.

### Backend Subtasks

Không có — N/A cho task này.

### Frontend Subtasks

| Subtask ID | Title | Files/Modules | Description | Depends On | Risk |
|---|---|---|---|---|---|
| FE-01 | Đưa 3 ảnh CSB vào runtime asset + khai báo pubspec | `assets/images/coast_guard/` (mới), `pubspec.yaml` | Copy 3 file từ `docs/artifact-design/assets/images/csb-slide-0{1,2,3}.jpg` sang thư mục asset runtime mới (tách khỏi `docs/` — vốn chỉ dùng cho mockup tĩnh); thêm khai báo `assets:` trong `pubspec.yaml` | None | Thấp — thuần copy file + khai báo, nhưng **chặn bởi câu hỏi bản quyền ảnh** (xem Risks) trước khi merge chính thức |
| FE-02 | Splash: thay icon placeholder bằng ảnh thật | `lib/features/splash/splash_screen.dart` | Sửa `_buildSlide()`: thay `Icon(Icons.anchor, ...)` bằng `Image.asset(...)` tương ứng từng slide (giữ nguyên gradient nền + tiêu đề/phụ đề, chỉ đổi phần hình minh hoạ). Cân nhắc `BoxFit`/kích thước để không vỡ layout trên cả khung Windows (rộng) và Mobile (hẹp) | FE-01 | Thấp — thay đổi cục bộ 1 widget, không đổi luồng điều hướng/timer |
| FE-03 | Tra cứu: thêm trạng thái rỗng carousel ảnh (thay `_Hint`) | `lib/features/search/search_screen.dart` | Thêm widget mới (vd `_SearchEmptyCarousel`) dùng `CarouselSlider` autoplay 3 ảnh + dots indicator, hiện khi `_query.trim().isEmpty`, thay thế `_Hint` hiện tại. Giữ logic search không đổi (chỉ đổi UI trạng thái rỗng) | FE-01 | Trung bình — cần đảm bảo layout desktop 2 cột (`pane-list`/`pane-detail`, theo mockup Windows `screen-02c`) khác mobile full-screen (theo mockup `screen-02c` mobile); `SearchScreen` hiện dùng chung 1 code path cho cả 2 nền tảng, cần kiểm tra `HomeShell`/breakpoint có truyền đủ context để phân biệt layout không |

### Integration Subtasks

| Subtask ID | Title | Files/Modules | Description | Depends On | Risk |
|---|---|---|---|---|---|
| INT-01 | Verify hiển thị đúng trên cả Windows và Mobile | `lib/features/splash/`, `lib/features/search/` | Chạy app trên Windows (`flutter run -d windows`) và ít nhất 1 target mobile (emulator/thiết bị Android), xác nhận ảnh hiện đúng, không vỡ layout, không tăng thời gian khởi động app đáng kể (ảnh JPEG cỡ vừa) | FE-02, FE-03 | Thấp |

## Recommended Execution Order

### Option A: Backend First

Không áp dụng — không có backend subtask trong task này.

### Option B: Frontend First

Order:

1. FE-01 (chuẩn bị asset dùng chung — bắt buộc làm trước)
2. FE-02 (Splash — độc lập, rủi ro thấp, có thể làm song song hoặc trước FE-03)
3. FE-03 (Tra cứu — phức tạp hơn 1 chút vì phải khớp 2 layout Windows/Mobile)
4. INT-01

### Recommended Option

Recommend: **Option B (Frontend-only, vì không có backend)** — thứ tự
FE-01 → FE-02 → FE-03 → INT-01.

Reason:

- Không có API/backend nào liên quan, nên "Backend first vs Frontend first"
  không áp dụng theo đúng nghĩa — toàn bộ là Frontend.
- FE-01 là điều kiện tiên quyết kỹ thuật (không có ảnh thì không code được
  gì ở FE-02/FE-03).
- FE-02 (Splash) đơn giản hơn FE-03 (Tra cứu, cần khớp 2 layout) — làm trước
  để xác nhận pattern `Image.asset` hoạt động đúng trước khi áp dụng tiếp
  cho carousel phức tạp hơn ở Tra cứu.

## User Decision Required

Trước khi implement, user cần chọn:

```text
Implement frontend first: use task-implement-frontend with FE-01
```

(Không có lựa chọn backend-first hay integration-first độc lập vì task này
chỉ có Frontend + 1 bước verify cuối.)

## Manual Verification Plan

### Main Flow

- [ ] Mở app → Splash hiện đủ 3 slide, mỗi slide có ảnh thật thay vì icon
      la bàn, tự chuyển sau đúng khoảng thời gian đã cấu hình
      (`AppConstants.splashSlideInterval`), tự chuyển sang `/home` sau
      `AppConstants.splashDuration`.
- [ ] Vào tab Tra cứu khi chưa gõ gì → hiện carousel 3 ảnh CSB tự chuyển,
      có dots chỉ báo, thay cho gợi ý chữ `_Hint` cũ.
- [ ] Gõ 1 ký tự vào ô tìm kiếm → carousel biến mất, kết quả tìm kiếm hiện
      bình thường như code hiện tại (không đổi hành vi search).
- [ ] Xoá hết chữ đã gõ → carousel trạng thái rỗng hiện lại đúng.

### UI Verification

- [ ] Trên Windows (cửa sổ rộng): carousel ở Tra cứu hiển thị đúng trong
      khu vực `pane-detail`/toàn bộ nội dung theo đúng bố cục mockup
      `docs/artifact-design-windows/screens/screen-02c-tra-cuu-trong.html`
      (không có `pane-list`/`pane-detail` tách đôi khi ở trạng thái rỗng).
- [ ] Trên Mobile (cửa sổ hẹp/thiết bị thật): carousel chiếm toàn bộ
      `page-content` theo `docs/artifact-design/screens/screen-02c-tra-cuu-
      trong.html`.
- [ ] Ảnh không bị vỡ tỉ lệ/kéo dãn xấu ở cả 2 kích thước màn hình khác
      nhau (thử resize cửa sổ Windows từ hẹp sang rộng qua breakpoint 700px).
- [ ] Splash: ảnh không đè lên tiêu đề/phụ đề, đọc được rõ trên cả 3 nền
      gradient (navy/sea/gold).

### API Verification

Không áp dụng — không có API trong scope task này.

### Error / Edge Case

- [ ] Ảnh thiếu/lỗi load (giả lập bằng cách đổi tên file tạm thời) — xác
      nhận không crash app, có fallback hợp lý (ví dụ giữ placeholder cũ
      hoặc icon thay vì màn trắng/lỗi đỏ).
- [ ] Bấm "Bỏ qua ➜" ở Splash giữa lúc carousel đang autoplay — vẫn điều
      hướng ngay, không bị timer ảnh hưởng (hành vi đã có, chỉ verify lại
      không bị phá vỡ bởi thay đổi FE-02).

### SPA / Browser Behavior

Không áp dụng — app Flutter desktop/mobile, không phải web SPA.

### Regression

- [ ] Toàn bộ luồng tìm kiếm hiện tại (gõ → kết quả → mở `WordDetailSheet`
      → đánh dấu đã học) không bị ảnh hưởng bởi thay đổi ở `_Hint` cũ.
- [ ] Thời gian khởi động app (Splash) không tăng đáng kể do load thêm ảnh
      (so sánh nhanh trước/sau trên cùng thiết bị).

## Risks / TODO

- **Bản quyền/nguồn ảnh chưa xác nhận chính thức** (mở từ [IMPL-009]): 3
  ảnh CSB (diễu binh đội danh dự, trụ sở Bộ Tư lệnh) hiện chỉ dùng minh hoạ
  mockup tĩnh, **chưa xác nhận được phép dùng chính thức trong app thật**.
  Cần user xác nhận trước khi merge FE-01/FE-02/FE-03 vào nhánh chính —
  nếu chưa xác nhận kịp, có thể tạm hoãn phần ảnh thật và giữ nguyên
  placeholder cho tới khi rõ.
- Dung lượng file ảnh JPEG thật (khác icon vector) sẽ tăng kích thước app
  build — kiểm tra nhanh dung lượng 3 file trước khi thêm vào `pubspec.yaml`
  assets, cân nhắc nén/resize nếu quá lớn cho splash/empty-state (không cần
  ảnh độ phân giải cao).
- `SearchScreen` hiện là 1 widget dùng chung cho cả Windows/Mobile (không
  tách 2 file riêng như mockup) — cần xác nhận cách phân biệt layout rỗng
  2 cột (Windows) vs full-screen (Mobile) sẽ dựa vào breakpoint nào (có thể
  tái dùng `AppConstants.desktopBreakpoint`/logic đã có trong `HomeShell`),
  tránh tạo thêm 1 cách phát hiện layout mới trùng lặp.
