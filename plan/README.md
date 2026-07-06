# 📚 App Học Từ Vựng Tiếng Anh (tham khảo TFlat) — Offline

> Bộ tài liệu đặc tả (specs) cho ứng dụng **học từ vựng + tra cứu + dịch tiếng Anh**, tham khảo các chức năng chính của **TFlat**, hoạt động **offline** sau khi tạo dữ liệu.
> Xây dựng bằng **Flutter**, ưu tiên **Windows → Android → iPhone (iOS)**. Lưu dữ liệu bằng **SQLite**.

## 📂 Cấu trúc tài liệu

| File | Nội dung |
|------|----------|
| [00-tong-quan.md](./00-tong-quan.md) | Tầm nhìn, mục tiêu, đối tượng, phạm vi |
| [01-yeu-cau-chuc-nang.md](./01-yeu-cau-chuc-nang.md) | Đặc tả chi tiết từng chức năng |
| [02-yeu-cau-phi-chuc-nang.md](./02-yeu-cau-phi-chuc-nang.md) | Offline, hiệu năng, đa nền tảng (Windows→Android→iOS), thông báo |
| [03-kien-truc-ky-thuat.md](./03-kien-truc-ky-thuat.md) | Tech stack, kiến trúc, thư viện, cấu trúc thư mục |
| [04-thiet-ke-du-lieu.md](./04-thiet-ke-du-lieu.md) | Xử lý PDF → SQLite, schema DB, chương/bài học, cơ chế ôn tập |
| [05-lo-trinh-phat-trien.md](./05-lo-trinh-phat-trien.md) | Roadmap theo giai đoạn (Windows → Android → iOS) |
| [06-cau-hoi-can-chot.md](./06-cau-hoi-can-chot.md) | ✅ **Các câu hỏi đã chốt** (còn chờ khách gửi 2 file PDF & xác nhận máy Mac) |

## 🎯 Tóm tắt nhanh

- **Nền tảng:** **Windows (chính) → Android → iOS**. Một codebase Flutter.
- **Offline:** Toàn bộ chức năng (kể cả dịch) chạy offline 100%; dữ liệu lưu SQLite trên máy.
- **Công nghệ chính:** Flutter + SQLite (Drift / sqflite_ffi) + flutter_tts + flutter_local_notifications.
- **Chức năng cốt lõi (tham khảo TFlat):**
  1. Splash screen chủ đề Cảnh sát biển VN (carousel 3–5 ảnh tự dựng).
  2. Tra cứu từ vựng (nghĩa, phiên âm, loại từ, ví dụ, ảnh) — phạm vi từ trong PDF.
  3. Học theo bài học/chương (dự kiến 11 chương).
  4. Dịch Anh↔Việt (offline, tra từ/cụm ghép lại).
  5. Ôn tập **SM-2**: đánh dấu đã học, lịch ôn, thông báo nhắc.
- **Bàn giao:** kèm **báo cáo Microsoft Word** mô tả công nghệ, kiến trúc, DB, chức năng, hướng dẫn dùng & triển khai.

## ✅ Trạng thái hiện tại
Các câu hỏi trong [06-cau-hoi-can-chot.md](./06-cau-hoi-can-chot.md) **đã chốt**. Có thể bắt đầu **Giai đoạn 0 — khởi tạo project Flutter trên Windows** ngay. Còn chờ khách gửi:
1. **File PDF gốc** (giáo trình từ vựng) — để sinh `vocab.db`.
2. **File PDF thứ 2** định nghĩa chương — cho chức năng "Học theo chương".
3. Xác nhận **có máy Mac** — quyết định thời điểm làm iOS.
4. (Tùy chọn) **File logo** Cảnh sát biển độ phân giải cao, **deadline**.
