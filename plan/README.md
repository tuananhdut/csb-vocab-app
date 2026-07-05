# 📚 App Học Từ Vựng Tiếng Anh (tham khảo TFlat) — Offline

> Bộ tài liệu đặc tả (specs) cho ứng dụng **học từ vựng + tra cứu + dịch tiếng Anh**, tham khảo các chức năng chính của **TFlat**, hoạt động **offline** sau khi tạo dữ liệu.
> Xây dựng bằng **Flutter**, **ưu tiên chạy trên Windows**, sau đó mở rộng sang **iPhone (iOS)**. Lưu dữ liệu bằng **SQLite**.

## 📂 Cấu trúc tài liệu

| File | Nội dung |
|------|----------|
| [00-tong-quan.md](./00-tong-quan.md) | Tầm nhìn, mục tiêu, đối tượng, phạm vi |
| [01-yeu-cau-chuc-nang.md](./01-yeu-cau-chuc-nang.md) | Đặc tả chi tiết từng chức năng |
| [02-yeu-cau-phi-chuc-nang.md](./02-yeu-cau-phi-chuc-nang.md) | Offline, hiệu năng, đa nền tảng (Windows-first), thông báo |
| [03-kien-truc-ky-thuat.md](./03-kien-truc-ky-thuat.md) | Tech stack, kiến trúc, thư viện, cấu trúc thư mục |
| [04-thiet-ke-du-lieu.md](./04-thiet-ke-du-lieu.md) | Xử lý PDF → SQLite, schema DB, chương/bài học, cơ chế ôn tập |
| [05-lo-trinh-phat-trien.md](./05-lo-trinh-phat-trien.md) | Roadmap theo giai đoạn (Windows trước, iOS sau) |
| [06-cau-hoi-can-chot.md](./06-cau-hoi-can-chot.md) | ⚠️ **Các câu hỏi cần bạn/khách chốt** trước khi code |

## 🎯 Tóm tắt nhanh

- **Nền tảng:** Windows (ưu tiên) → iOS (mở rộng). Một codebase Flutter.
- **Offline:** Dữ liệu từ vựng (tạo từ PDF) lưu SQLite trên máy, không cần internet.
- **Công nghệ chính:** Flutter + SQLite (Drift / sqflite_ffi) + flutter_tts + flutter_local_notifications.
- **Chức năng cốt lõi (tham khảo TFlat):**
  1. Splash screen ảnh Cảnh sát biển VN (carousel).
  2. Tra cứu từ vựng (nghĩa, phiên âm, loại từ, ví dụ, ảnh nếu có).
  3. Học theo bài học/chương (ví dụ 11 chương).
  4. Dịch Anh↔Việt (cơ bản).
  5. Ôn tập: đánh dấu đã học, lịch ôn, thông báo nhắc.
- **Bàn giao:** kèm **báo cáo Microsoft Word** mô tả công nghệ, kiến trúc, DB, chức năng, hướng dẫn dùng & triển khai.

## ⚠️ Trước khi bắt đầu
👉 Đọc [06-cau-hoi-can-chot.md](./06-cau-hoi-can-chot.md) và trả lời các câu hỏi (đặc biệt: **file PDF**, **phạm vi tra cứu**, **mức độ dịch offline**, **máy Mac cho iOS**). Đây là các điểm chặn cần chốt trước khi code.
