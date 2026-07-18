# 00 — Tổng Quan

## Bối cảnh

CSB Vocab App là ứng dụng học từ vựng tiếng Anh chuyên ngành, phục vụ lực
lượng Cảnh sát biển Việt Nam. Nguồn từ vựng lấy từ giáo trình
*"Tiếng Anh chuyên ngành Cảnh sát biển"* (tài liệu gốc: `assets/TA_chuyen_nganh.docx`,
`assets/TA_chuyen_nganh_2.pdf`, `assets/Tu_dien.pdf`), được xử lý thành
`assets/db/vocab.db` (script xử lý đã chạy xong và không còn giữ trong repo —
xem `docs/spec_history.md` [IMPL-002]).

## Kiến trúc kỹ thuật

- **Flutter** (Dart), state management bằng **Riverpod**.
- **Điều hướng:** `go_router` — chỉ 2 route cấp cao:
  - `/splash` → `SplashScreen`, tự chuyển sang `/home` sau
    `AppConstants.splashDuration` (5 giây) hoặc khi bấm "Bỏ qua".
  - `/home` → `HomeShell`, chứa toàn bộ 5 tab chính qua `IndexedStack`
    (không phải route riêng — chuyển tab không rebuild lại từ đầu).
- **Layout thích ứng (adaptive):** `HomeShell` đo `MediaQuery.sizeOf(context).width`
  so với `AppConstants.desktopBreakpoint` (700px):
  - **Desktop (Windows, cửa sổ rộng):** `NavigationRail` cố định bên trái.
  - **Mobile (Android/iOS, hẹp):** `NavigationBar` ở đáy.
- **Dữ liệu:** 2 SQLite tách biệt (tài liệu thiết kế DB riêng đã bị xoá — xem
  `../spec_history.md` [IMPL-003] — schema hiện suy ra từ code):
  - `vocab.db` — từ vựng, chương, ví dụ. Read-only, đóng gói sẵn trong assets.
    Cài đặt tại `../../lib/data/local/vocab_database.dart`.
  - `user.db` — tiến độ học, trạng thái SM-2, lịch sử ôn tập. Read-write, tạo
    rỗng lần đầu chạy app. Cài đặt tại `../../lib/data/local/user_database.dart`.
- **Thông báo:** `NotificationService` (singleton) dùng
  `flutter_local_notifications` — nhắc trong-app khi có từ đến hạn ôn (mọi nền
  tảng), cộng thêm lịch nhắc hàng ngày cho Android/iOS (Windows không hỗ trợ
  nhắc nền khi app đã đóng — giới hạn đã chốt, ngoài phạm vi MVP).
- **Cài đặt:** `ThemeModeNotifier` lưu lựa chọn Sáng/Tối/Theo hệ thống bằng
  `shared_preferences`, áp dụng ngay lập tức qua `MaterialApp.themeMode`.

## Ràng buộc

- **Offline hoàn toàn** — không gọi API mạng, không đăng nhập, không đồng bộ
  đa thiết bị. Toàn bộ tính năng phải hoạt động không cần Internet.
- **1 người dùng / 1 thiết bị** — không có khái niệm vai trò hay phân quyền.
- **Ưu tiên nền tảng:** Windows → Android → iOS (thứ tự phát triển/kiểm thử).
- **Windows không hỗ trợ nhắc nền khi app đóng hẳn** — chỉ nhắc trong lúc app
  đang mở (in-app + system notification tức thời). Đã chốt (plan Q&A D2, xem
  comment trong `notification_service.dart`).

## Glossary

| Thuật ngữ | Nghĩa |
|---|---|
| SM-2 | Thuật toán lặp lại ngắt quãng (spaced repetition) gốc của SuperMemo, dùng để tính lịch ôn tập tiếp theo dựa trên độ khó tự đánh giá |
| `q` (quality) | Giá trị 1–5 truyền vào công thức SM-2; app dùng 4 mức: Quên=1, Khó=3, Tốt=4, Dễ=5 |
| Subentry | Một mục từ vựng là cụm từ/biến thể liên quan đến 1 từ gốc (vd: `anchor buoy` là subentry của `buoy`), đánh dấu bằng cột `is_subentry` |
| Due (đến hạn) | Từ đã đánh dấu học và có `due_date <= hôm nay` — xuất hiện trong hàng đợi ôn tập |
| `HomeShell` | Widget khung chính chứa 5 tab, tự chọn `NavigationRail` hay `NavigationBar` tuỳ độ rộng cửa sổ |

## Quyết định đã chốt (trích từ code/comment, `plan/` gốc đã xoá)

| # | Quyết định | Nguồn |
|---|---|---|
| D1 | Thuật toán ôn tập = SM-2 (không dùng khoảng cố định 1-3-7-14-30 ngày) | `lib/domain/srs/srs_scheduler.dart` |
| D2 | Windows: nhắc chỉ khi app đang mở; Android/iOS: nhắc được cả khi app đóng | `lib/data/services/notification_service.dart` |
| — | Bảng màu app lấy từ logo Cảnh sát biển VN (navy + vàng phù hiệu + đỏ) | `lib/core/theme/app_theme.dart`, `docs/artifact-design/bang-mau-ung-dung.md` |

## Câu hỏi mở

Xem `docs/spec_history.md` mục "Điểm chờ xác nhận còn mở" (Q-CSB-01, Q-CSB-02).
