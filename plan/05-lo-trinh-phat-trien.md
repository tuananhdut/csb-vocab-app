# 05 — Lộ Trình Phát Triển (Roadmap)

**Ưu tiên: Windows (chính) → Android → iOS.** Mỗi giai đoạn cho ra một bản chạy được.

> ✅ Các câu hỏi chặn ở [06-cau-hoi-can-chot.md](./06-cau-hoi-can-chot.md) **đã chốt**. Chỉ còn chờ khách gửi **2 file PDF** (giáo trình + định nghĩa chương) để bắt đầu Giai đoạn 1, và xác nhận **máy Mac** cho iOS (Giai đoạn 4).

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
- [ ] Cài `srs_scheduler.dart` (**SM-2** — đã chốt D1) + unit test.
- [ ] Hàng đợi "ôn hôm nay" trên màn chính.
- [ ] **FR-5.3 Thông báo** nhắc học (Windows: khi app mở; Android/iOS: đầy đủ — đã chốt D2).

**Đầu ra:** vòng lặp học hoàn chỉnh (tra → học theo chương → đánh dấu → ôn lại).

---

## 🥉 Giai đoạn 3 — Dịch + Phát âm + Cài đặt (P1)
- [ ] **FR-4 Dịch** Anh↔Việt (giao diện kiểu Google Translate; offline tra từ/cụm — đã chốt B1=a).
- [ ] **FR-6 Phát âm** TTS (`flutter_tts`).
- [ ] **FR-7 Cài đặt**: sáng/tối, giọng đọc, số từ mới/ngày, quản lý dữ liệu.
- [ ] Tinh chỉnh responsive cho cửa sổ Windows rộng.

**Đầu ra:** đủ chức năng chính, trải nghiệm hoàn chỉnh trên Windows.

---

## 📱 Giai đoạn 4 — Mở rộng Android (ưu tiên trước iOS)
- [ ] Cài Android SDK (qua Android Studio), bật Android trong Flutter.
- [ ] Build & chạy trên máy ảo Android / điện thoại thật.
- [ ] Điều chỉnh UI cho điện thoại (bottom nav, 1 cột).
- [ ] Kiểm tra TTS, thông báo (local notification đầy đủ), SQLite trên Android.
- [ ] Kiểm thử offline trên Android.
- [ ] Đóng gói APK/AAB.

**Đầu ra:** app chạy trên điện thoại Android.

---

## 🍏 Giai đoạn 5 — Mở rộng iOS
> Chỉ làm được nếu có **máy Mac + Xcode** (Q&A E1). Chỉ cần **chạy trên iPhone** ở chế độ Developer — chưa cần tài khoản Apple Developer trả phí.
- [ ] Build & chạy trên iOS Simulator / iPhone thật.
- [ ] Kiểm tra TTS, thông báo, SQLite trên iOS.
- [ ] Tinh chỉnh UI iOS (bottom nav, 1 cột).
- [ ] Kiểm thử offline trên iOS.

**Đầu ra:** app chạy trên iPhone.

---

## 📄 Giai đoạn 6 — Báo cáo & Bàn giao
- [ ] Hoàn thiện icon, splash, tên app.
- [ ] Đóng gói Windows: **bộ cài MSIX** + **bản portable** (thư mục chạy trực tiếp) — đã chốt E2.
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
1. **Nhận và phân tích 2 file PDF** (giáo trình + định nghĩa chương) — quyết định toàn bộ dữ liệu. ⏳ Đang chờ khách gửi.
2. **Xác nhận có máy Mac** cho iOS (Q&A E1) — quyết định thời điểm Giai đoạn 5.
   *(Mức độ dịch offline đã chốt B1=a; cơ chế ôn tập đã chốt D1=SM-2.)*

---

## 👉 Việc tiếp theo ngay bây giờ
1. ✅ Câu hỏi cần chốt đã trả lời xong ([06](./06-cau-hoi-can-chot.md)).
2. **Khởi tạo project Flutter chạy trên Windows (Giai đoạn 0)** — có thể làm ngay, không cần chờ PDF (dùng dữ liệu mẫu tạm để dựng giao diện).
3. Song song: khách gửi **2 file PDF** để mình viết script parse → sinh `vocab.db` thật (Giai đoạn 1).
