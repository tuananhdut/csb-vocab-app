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
- Ảnh minh hoạ hiện là placeholder tự dựng bằng `Icon(Icons.anchor)` — chưa có
  bộ ảnh chính thức từ khách hàng (ghi chú trong code: *"sẽ thay bằng ảnh thật
  khi khách cung cấp"*).

## Phụ thuộc

- `AppConstants.splashDuration`, `AppConstants.splashSlideInterval` (`lib/core/constants/app_constants.dart`).
- `AppTheme`/`AppColors` (`lib/core/theme/app_theme.dart`) cho gradient màu.
- `go_router` (`context.go`).

## Giả định / hạn chế

> ⚠️ Giả định: thứ tự nội dung 3 slide chỉ mang tính minh hoạ ban đầu — cần
> khách hàng xác nhận nội dung/ảnh chính thức trước khi hoàn thiện.

Không có test riêng cho màn này ngoài `widget_test.dart` (đã xoá — xem
`docs/spec_history.md` [IMPL-002] mục 4) vốn chỉ smoke-test việc app khởi
động và hiển thị splash.
