# CSB Vocab App — Tài Liệu Phân Tích Màn Hình (đã code)

> 📌 **Phạm vi:** phân tích **màn hình đã có code thật** trong `lib/features/` —
> khác với mockup thiết kế ở `docs/artifact-design/` (mobile) và
> `docs/artifact-design-windows/` (Windows), vốn đã đi trước một bước và có
> vài tính năng/luồng chưa được triển khai (xem mục "Trạng thái" bên dưới).
> Phiên bản: 1.6 | Cập nhật: 2026-09-17 | Nguồn: `docs/spec_history.md` [IMPL-002], [IMPL-005], [IMPL-017], [IMPL-021]–[IMPL-029].
>
> ⚠️ **Định hướng mới (chưa code, [IMPL-005]):** tra cứu 2 trạng thái
> Offline/Online, bộ từ điển (dictionary) quan hệ nhiều-nhiều với từ (mặc
> định + cá nhân), và Section chứa nhiều Chapter hiển thị dạng bài báo —
> xem [00_Overview.md](00_Overview.md) mục "Mô hình dữ liệu — định hướng
> mới". Đã cập nhật vào [02_Search.md](02_Search.md) và
> [03_Lessons-by-chapter.md](03_Lessons-by-chapter.md) dưới dạng phần riêng
> "định hướng mới — chưa code", tách biệt rõ với phần mô tả code thật.

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
| Bộ từ vựng cá nhân | ✅ Đã có code (`lib/features/my_dictionaries/`) — **chưa có tài liệu SCR phân tích riêng**, xem Q-CSB-10 | ✅ Đã thiết kế đầy đủ (tạo bộ, thêm từ tự nhập, ôn theo bộ) |
| Kiểu ôn tập | Trắc nghiệm + gõ chữ ([IMPL-015]), không tự chấm | 3 kiểu trộn ngẫu nhiên: lật thẻ, gõ chữ, trắc nghiệm |
| Dịch (FR-4) | ✅ Đã code — ưu tiên dịch Online (MyMemory), on-device (opus-mt) làm fallback khi mất mạng, xem [IMPL-017]/[IMPL-025] | Đã thiết kế UI đầy đủ 2 chiều |

Xem `docs/spec_history.md` mục Q-CSB-02/Q-CSB-10 — vẫn chưa có tài liệu SCR
chính thức cho "Từ điển của tôi" dù code đã có từ trước.

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
| SCR-04 | Dịch Anh⇄Việt | FR-4 | ✅ Xong — ưu tiên Online, on-device fallback | [04_Translate.md](04_Translate.md) |
| SCR-05 | Ôn tập — hàng đợi + phiên trắc nghiệm/gõ chữ | FR-5 | ✅ Xong (khách quan, tự chấm — không còn lật thẻ) | [05_Review.md](05_Review.md) |
| SCR-06 | ~~Cài đặt — chọn Sáng/Tối~~ (đã bị xoá) + Nhắc ôn tập | FR-7 | ⚠️ Màn Cài đặt gốc không còn tồn tại, xem Q-CSB-11 | [06_Settings.md](06_Settings.md) |
| — | Khung điều hướng chính (`HomeShell`) — không phải màn riêng | — | ✅ Xong | [07_Home-shell.md](07_Home-shell.md) |

> Không có mã `FR-6` trong code (xem `docs/spec_history.md` Q-CSB-01) — bỏ trống trong bảng để tránh nhầm với các FR khác.

---

## Quy ước

- **ID truy vết:** Màn hình `SCR-xx`; chức năng `FR-xx` (giữ nguyên số hiệu đã dùng trong comment code, không đổi số).
- **Nguồn:** Ghi rõ đường dẫn file code, ví dụ *(Nguồn: `lib/features/search/search_screen.dart`)*.
- **Giả định:** `> ⚠️ Giả định: ... — cần xác nhận`.
- **Ngôn ngữ:** Tiếng Việt.

> 🛠 **Lịch sử:** v1.0 (2026-07-18) — tạo mới theo yêu cầu, phân tích các màn hình đã code thật tại thời điểm này. Xem `docs/spec_history.md` [IMPL-002]. v1.1 (2026-07-18) — đổi tên toàn bộ file trong thư mục này sang tiếng Anh (nội dung bên trong vẫn tiếng Việt), xem `docs/spec_history.md` [IMPL-003]. v1.2 (2026-07-18) — thêm định hướng mới (tra cứu online/offline, bộ từ điển N-N, Section/Chapter dạng bài báo) vào `00_Overview.md`, `02_Search.md`, `03_Lessons-by-chapter.md`, `90_Traceability-matrix.md`, xem `docs/spec_history.md` [IMPL-005]/[IMPL-006]. v1.3 (2026-07-18) — lan tỏa định hướng mới vào mockup mobile `docs/artifact-design/` (màn 02b/02c, 03/03b/03c mới, cập nhật 07, slide ảnh CSB ở trạng thái chưa tìm kiếm), xem `docs/spec_history.md` [IMPL-008]/[IMPL-009]. v1.4 (2026-07-18) — đồng bộ toàn bộ thay đổi trên vào mockup Windows `docs/artifact-design-windows/`, xem `docs/spec_history.md` [IMPL-010]. v1.5 (2026-09-17) — cập nhật `02_Search.md` (Online thực ra đã code từ lâu, không còn "chưa code"; debounce + phân trang), `04_Translate.md` (đổi hướng lần 2: ưu tiên Online), `06_Settings.md` (thêm mục Nhắc ôn tập + gật quyền thông báo), `90_Traceability-matrix.md` (bỏ `review_logs`/`search_history` đã xoá, sửa các dòng "Bộ từ điển cá nhân"/"Tra cứu Online" từ ❌ sang ✅) cho khớp code thật — xem `docs/spec_history.md` [IMPL-021]–[IMPL-028]. v1.6 (2026-09-17) — audit + viết lại `01_Splash.md`, `05_Review.md` (ôn tập đã đổi hẳn sang trắc nghiệm/gõ chữ, không còn lật thẻ), `06_Settings.md` (phát hiện thêm: màn Cài đặt gốc đã bị xoá khỏi code), `07_Home-shell.md` (4 tab chứ không phải 5, thiếu 2 tính năng có thật), `00_Overview.md` (relabel bộ từ điển N-N/Section-Chapter từ "chưa code" sang "đã code") — xem `docs/spec_history.md` [IMPL-029]. **Vẫn còn thiếu:** tài liệu SCR riêng cho "Từ điển của tôi" (Q-CSB-10); xác nhận lý do màn Cài đặt biến mất (Q-CSB-11).
