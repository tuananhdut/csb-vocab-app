# SCR-01 — Splash

**FR:** FR-1 · **Trạng thái:** ✅ Đã code xong · **Nguồn:** `lib/features/splash/splash_screen.dart`

## Mục đích

Màn khởi động, giới thiệu chủ đề Cảnh sát biển Việt Nam trước khi vào màn
chính. Không có logic nghiệp vụ (không đọc DB, không kiểm tra trạng thái nào).

## Hành vi

- Carousel 3 slide tự động chuyển (`carousel_slider`), mỗi slide đổi màu nền
  gradient (navy / xanh biển / vàng) + tiêu đề + phụ đề khác nhau, khoảng cách
  `AppConstants.splashSlideInterval` (1.5 giây).
- Sau `AppConstants.splashDuration` (5 giây) tự động điều hướng sang `/home`
  bằng `context.go('/home')`.
- Nút "Bỏ qua ➜" ở góc dưới phải cho phép vào `/home` ngay lập tức, huỷ timer.
- Mỗi slide hiện **ảnh thật Cảnh sát biển** (`Image.asset`, 3 file
  `assets/images/coast_guard/csb-slide-01/02/03.jpg` — đã thay từ
  placeholder theo `docs/spec_history.md` [IMPL-009]). Gradient màu
  (navy/xanh biển/vàng) giờ chỉ còn là nền `errorBuilder` — hiện ra nếu
  load ảnh lỗi, không còn là nội dung hiển thị chính.

## Phụ thuộc

- `AppConstants.splashDuration`, `AppConstants.splashSlideInterval` (`lib/core/constants/app_constants.dart`).
- `AppTheme`/`AppColors` (`lib/core/theme/app_theme.dart`) — gradient màu, chỉ dùng khi ảnh lỗi.
- `assets/images/coast_guard/` — 3 ảnh slide thật.
- `go_router` (`context.go`).

## Giả định / hạn chế

Không có test riêng cho màn này ngoài `widget_test.dart` (đã xoá — xem
`docs/spec_history.md` [IMPL-002] mục 4) vốn chỉ smoke-test việc app khởi
động và hiển thị splash.
