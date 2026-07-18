# CSB Vocab App — Tài Liệu Phân Tích Màn Hình (đã code)

> 📌 **Phạm vi:** phân tích **màn hình đã có code thật** trong `lib/features/` —
> khác với mockup thiết kế ở `docs/artifact-design/` (mobile) và
> `docs/artifact-design-windows/` (Windows), vốn đã đi trước một bước và có
> vài tính năng/luồng chưa được triển khai (xem mục "Trạng thái" bên dưới).
> Phiên bản: 1.0 | Cập nhật: 2026-07-18 | Nguồn: `docs/spec_history.md` [IMPL-002].

---

## Giới thiệu

**CSB Vocab App** là ứng dụng học từ vựng tiếng Anh chuyên ngành cho lực lượng
Cảnh sát biển Việt Nam — tra cứu, học theo chương, dịch, và ôn tập theo thuật
toán lặp lại ngắt quãng (SM-2). Chạy **offline hoàn toàn**, không có backend
hay tài khoản người dùng — mỗi máy cài đặt là một không gian dữ liệu độc lập.

### Kiến trúc sản phẩm

- **1 người dùng, 1 thiết bị** — không có vai trò (role), không đăng nhập,
  không đồng bộ nhiều máy. Khác hẳn mô hình nhiều vai trò/Web admin của các
  dự án doanh nghiệp khác — tài liệu này **không có phần "Vai trò người dùng"**
  vì không áp dụng.
- **Flutter, chạy trên Windows → Android → iOS** (thứ tự ưu tiên nền tảng).
- **2 SQLite riêng biệt:** `vocab.db` (từ vựng, đóng gói sẵn, read-only) +
  `user.db` (tiến độ học, read-write) — tài liệu thiết kế DB riêng đã bị xoá
  (xem `docs/spec_history.md` [IMPL-003]); schema hiện chỉ suy ra được từ
  code (`../../lib/data/local/`, `../../lib/domain/srs/srs_scheduler.dart`).
- **State management:** Riverpod (`ConsumerWidget`/`ConsumerStatefulWidget` +
  `Notifier`/`FutureProvider`).
- **Điều hướng:** `go_router`, chỉ 2 route cấp cao (`/splash`, `/home`) —
  điều hướng giữa các tab trong `/home` xử lý bằng `IndexedStack` nội bộ
  trong `HomeShell`, không phải route riêng.

### Trạng thái: code thật vs. mockup thiết kế

| | Code thật (`lib/features/`) | Mockup (`docs/artifact-design*/`) |
|---|---|---|
| Điều hướng chính | 5 tab: Tra cứu, Học, Dịch, Ôn tập, Cài đặt | 5 tab: Tra cứu, Học, Dịch, **Từ điển của tôi**, Cài đặt (Ôn tập đã gộp vào) |
| Màn Học | Chỉ danh sách chương → danh sách từ | Thêm chế độ flashcard "học từ mới" (đã bỏ theo yêu cầu sau đó — xem mockup mới nhất) |
| Bộ từ vựng cá nhân | ❌ Chưa có | ✅ Đã thiết kế đầy đủ (tạo bộ, thêm từ tự nhập, ôn theo bộ) |
| Kiểu ôn tập | 1 kiểu: lật thẻ tự chấm (Quên/Khó/Tốt/Dễ) | 3 kiểu trộn ngẫu nhiên: lật thẻ, gõ chữ, trắc nghiệm |
| Dịch (FR-4) | Placeholder — chưa có logic dịch | Đã thiết kế UI đầy đủ 2 chiều |

Xem `docs/spec_history.md` mục Q-CSB-02 — chưa chốt việc có triển khai code
theo đúng hướng mockup mới hay không.

---

## Danh sách tài liệu

### Tổng quan & truy vết

- [00_Overview.md](00_Overview.md) — Bối cảnh, kiến trúc, ràng buộc, glossary, quyết định đã chốt, câu hỏi mở.
- [90_Traceability-matrix.md](90_Traceability-matrix.md) — Truy vết FR ↔ màn hình ↔ file code.

### Màn hình (toàn bộ chạy trên 1 thiết bị, không phân vai trò)

| Mã | Màn hình | FR | Trạng thái | File |
|----|----------|----|----|------|
| SCR-01 | Splash — carousel giới thiệu | FR-1 | ✅ Xong | [01_Splash.md](01_Splash.md) |
| SCR-02 | Tra cứu — song ngữ Anh⇄Việt | FR-2 | ✅ Xong | [02_Search.md](02_Search.md) |
| SCR-03 | Học theo chương + chi tiết từ | FR-3 | ✅ Xong | [03_Lessons-by-chapter.md](03_Lessons-by-chapter.md) |
| SCR-04 | Dịch Anh⇄Việt | FR-4 | ⏳ Placeholder, chưa code logic | [04_Translate.md](04_Translate.md) |
| SCR-05 | Ôn tập — hàng đợi + phiên flashcard | FR-5 | ✅ Xong (1 kiểu: lật thẻ) | [05_Review.md](05_Review.md) |
| SCR-06 | Cài đặt — chọn giao diện Sáng/Tối | FR-7 | ✅ Xong (rút gọn, còn thiếu mục khác) | [06_Settings.md](06_Settings.md) |
| — | Khung điều hướng chính (`HomeShell`) — không phải màn riêng | — | ✅ Xong | [07_Home-shell.md](07_Home-shell.md) |

> Không có mã `FR-6` trong code (xem `docs/spec_history.md` Q-CSB-01) — bỏ trống trong bảng để tránh nhầm với các FR khác.

---

## Quy ước

- **ID truy vết:** Màn hình `SCR-xx`; chức năng `FR-xx` (giữ nguyên số hiệu đã dùng trong comment code, không đổi số).
- **Nguồn:** Ghi rõ đường dẫn file code, ví dụ *(Nguồn: `lib/features/search/search_screen.dart`)*.
- **Giả định:** `> ⚠️ Giả định: ... — cần xác nhận`.
- **Ngôn ngữ:** Tiếng Việt.

> 🛠 **Lịch sử:** v1.0 (2026-07-18) — tạo mới theo yêu cầu, phân tích các màn hình đã code thật tại thời điểm này. Xem `docs/spec_history.md` [IMPL-002]. v1.1 (2026-07-18) — đổi tên toàn bộ file trong thư mục này sang tiếng Anh (nội dung bên trong vẫn tiếng Việt), xem `docs/spec_history.md` [IMPL-003].
