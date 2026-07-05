# 05 — Lộ Trình Phát Triển (Roadmap)

**Ưu tiên: chạy ổn định trên Windows trước → mở rộng iOS sau.** Mỗi giai đoạn cho ra một bản chạy được.

> ⚠️ Trước khi bắt đầu Giai đoạn 1 cần trả lời các câu hỏi chặn ở [06-cau-hoi-can-chot.md](./06-cau-hoi-can-chot.md) — nhất là **file PDF (A1)**, **phạm vi tra cứu (A4)**, **mức độ dịch (B1)**, **máy Mac cho iOS (E1)**.

---

## 🏁 Giai đoạn 0 — Chuẩn bị (Setup)
- [ ] Cài Flutter SDK (stable), bật Windows desktop, `flutter doctor`.
- [ ] Tạo project, cấu hình chạy trên **Windows** trước.
- [ ] Thêm dependencies: `riverpod`, `go_router`, `drift`, `flutter_tts`, `flutter_local_notifications`, `carousel_slider`, `path_provider`, `shared_preferences`.
- [ ] Dựng cấu trúc thư mục ([03](./03-kien-truc-ky-thuat.md)), theme tông xanh biển.
- [ ] Chạy thử app rỗng trên Windows.

**Đầu ra:** app rỗng chạy trên Windows.

---

## 🥇 Giai đoạn 1 — Dữ liệu + Splash + Tra cứu (P0)
**Mục tiêu:** có dữ liệu offline và tra được từ.

- [ ] **Nhận file PDF** từ khách (Q&A A1).
- [ ] Viết script `tools/pdf_to_sqlite/` parse PDF → `vocab.db` (words, chapters, examples).
- [ ] Rà soát chất lượng parse, sửa lỗi, kiểm tra số chương/số từ.
- [ ] Đóng gói `vocab.db` vào `assets/db/`, copy ra thư mục app lần đầu chạy.
- [ ] **FR-1 Splash screen**: carousel ảnh Cảnh sát biển → tự vào màn chính.
- [ ] **FR-2 Tra cứu**: ô tìm + nút tìm + màn kết quả (từ, nghĩa, phiên âm, loại từ, ví dụ, ảnh nếu có).
- [ ] Kiểm thử **offline** (ngắt mạng) → tra từ vẫn chạy. ✅

**Đầu ra:** app tra từ điển offline trên Windows.

---

## 🥈 Giai đoạn 2 — Học theo chương + Ôn tập (P0)
- [ ] **FR-3 Học theo chương**: danh sách chương → chọn chương → danh sách từ của chương.
- [ ] **FR-5 Ôn tập**: đánh dấu đã học, tạo `user.db`.
- [ ] Cài `srs_scheduler.dart` (SM-2 hoặc khoảng cố định — theo Q&A D1) + unit test.
- [ ] Hàng đợi "ôn hôm nay" trên màn chính.
- [ ] **FR-5.3 Thông báo** nhắc học (theo phạm vi Q&A D2).

**Đầu ra:** vòng lặp học hoàn chỉnh (tra → học theo chương → đánh dấu → ôn lại).

---

## 🥉 Giai đoạn 3 — Dịch + Phát âm + Cài đặt (P1)
- [ ] **FR-4 Dịch** Anh↔Việt (giao diện kiểu Google Translate; offline tra từ/cụm — theo Q&A B1).
- [ ] **FR-6 Phát âm** TTS (`flutter_tts`).
- [ ] **FR-7 Cài đặt**: sáng/tối, giọng đọc, số từ mới/ngày, quản lý dữ liệu.
- [ ] Tinh chỉnh responsive cho cửa sổ Windows rộng.

**Đầu ra:** đủ chức năng chính, trải nghiệm hoàn chỉnh trên Windows.

---

## 📱 Giai đoạn 4 — Mở rộng iOS
> Chỉ làm được nếu có **máy Mac + Apple Developer** (Q&A E1).
- [ ] Build & chạy trên iOS Simulator / iPhone thật.
- [ ] Kiểm tra TTS, thông báo, SQLite trên iOS.
- [ ] Điều chỉnh UI cho màn hình điện thoại (bottom nav, 1 cột).
- [ ] Kiểm thử offline trên iOS.

**Đầu ra:** app chạy trên iPhone.

---

## 📄 Giai đoạn 5 — Báo cáo & Bàn giao
- [ ] Hoàn thiện icon, splash, tên app.
- [ ] Đóng gói Windows (MSIX/bộ cài — Q&A E2).
- [ ] Viết **Báo cáo Microsoft Word** gồm:
  - Công nghệ sử dụng.
  - Kiến trúc ứng dụng.
  - Thiết kế cơ sở dữ liệu.
  - Vị trí lưu trữ dữ liệu.
  - Giải thích các chức năng chính.
  - Hướng dẫn sử dụng & triển khai.
- [ ] Bàn giao mã nguồn + `vocab.db` + script tạo dữ liệu + báo cáo.

---

## 📌 Việc rủi ro nhất — làm/kiểm tra sớm
1. **Nhận và phân tích file PDF** (Giai đoạn 1) — quyết định toàn bộ dữ liệu.
2. **Chốt mức độ dịch offline** (Q&A B1) — ảnh hưởng độ khó FR-4.
3. **Xác nhận khả năng làm iOS** (Q&A E1).

---

## 👉 Việc tiếp theo ngay bây giờ
1. Bạn/khách trả lời [06-cau-hoi-can-chot.md](./06-cau-hoi-can-chot.md) (ưu tiên các câu chặn).
2. Gửi **file PDF** để tôi phân tích cấu trúc dữ liệu.
3. Sau đó tôi cập nhật plan (nếu cần) và khởi tạo project Flutter chạy trên Windows (Giai đoạn 0).
