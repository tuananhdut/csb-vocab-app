# 02 — Yêu Cầu Phi Chức Năng (Non-Functional Requirements)

## NFR-1. Ưu tiên nền tảng (Platform Priority) — ✅ đã chốt E3
- **Ưu tiên 1: Windows** — chạy ổn định, là mục tiêu chính giai đoạn đầu.
- **Ưu tiên 2: Android** — mở rộng sau, cùng codebase Flutter (thêm ít công).
- **Ưu tiên 3: iOS (iPhone)** — chỉ cần **chạy được trên iPhone** ở chế độ Developer (chưa cần App Store).
- Tùy chọn: macOS.
- ⚠️ iOS cần máy Mac + Xcode để build — xem Q&A E1 (chưa cần tài khoản Apple Developer trả phí).

## NFR-2. Offline
- Sau khi **tạo dữ liệu từ PDF**, ứng dụng hoạt động **offline** cho các chức năng cốt lõi (tra cứu, học theo chương, ôn tập).
- Dữ liệu lưu **cục bộ bằng SQLite** trên máy.
- Kiểm thử: ngắt mạng → tra từ / học / ôn tập / dịch vẫn chạy.
- ✅ (đã chốt B1=a) Dịch cũng **offline 100%** (tra từ/cụm từ trong DB) — không có chức năng nào cần internet ở MVP.

## NFR-3. Hiệu năng (Performance)
- Tra 1 từ hiển thị kết quả: **< 100ms** (cần index cột `word` trong SQLite).
- Khởi động app (sau splash): nhanh, mượt.
- Cuộn danh sách từ trong chương mượt.

## NFR-4. Dung lượng (Storage)
- App + dữ liệu từ PDF: tùy số lượng từ, thường vài MB–vài chục MB.
- ✅ (đã chốt A5) Có **hình ảnh minh họa trích từ PDF** → nén ảnh (WebP/JPEG) khi đóng gói để kiểm soát dung lượng.

## NFR-5. Thông báo (Notifications) — ✅ đã chốt D2
- iOS/Android: local notification đầy đủ (nhắc học/ôn kể cả khi app đóng).
- **Windows:** thông báo hạn chế hơn, đặc biệt **khi app đã đóng**. Chỉ nhắc khi app đang mở (in-app + system notification). Nhắc nền khi tắt hẳn app = ngoài phạm vi MVP.

## NFR-6. Bảo mật & Riêng tư
- Không thu thập dữ liệu người dùng, không gửi lên server.
- Dữ liệu học nằm hoàn toàn trên máy (offline 100%, kể cả chức năng dịch).

## NFR-7. Khả năng bảo trì
- Kiến trúc phân lớp rõ ràng (xem [03](./03-kien-truc-ky-thuat.md)).
- Logic ôn tập (SRS) tách riêng, có unit test.
- Tách rõ tầng tạo dữ liệu (PDF → SQLite) và tầng app đọc dữ liệu.

## NFR-8. Bản địa hóa
- Giao diện: tiếng Việt (mặc định).

## NFR-9. Bàn giao (Deliverables)
- Mã nguồn Flutter chạy được trên Windows (và cấu hình sẵn cho Android, iOS).
- Bộ dữ liệu SQLite tạo từ PDF + script tạo dữ liệu.
- **Báo cáo Microsoft Word** (xem [05](./05-lo-trinh-phat-trien.md) — Giai đoạn phát hành).
