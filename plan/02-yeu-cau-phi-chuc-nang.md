# 02 — Yêu Cầu Phi Chức Năng (Non-Functional Requirements)

## NFR-1. Ưu tiên nền tảng (Platform Priority)
- **Ưu tiên 1: Windows** — chạy ổn định, là mục tiêu chính giai đoạn đầu.
- **Ưu tiên 2: iOS (iPhone)** — mở rộng sau, cùng codebase Flutter.
- Tùy chọn: macOS, Android (gần như không tốn thêm công khi đã dùng Flutter).
- ⚠️ iOS cần máy Mac + Apple Developer — xem Q&A E1.

## NFR-2. Offline
- Sau khi **tạo dữ liệu từ PDF**, ứng dụng hoạt động **offline** cho các chức năng cốt lõi (tra cứu, học theo chương, ôn tập).
- Dữ liệu lưu **cục bộ bằng SQLite** trên máy.
- Kiểm thử: ngắt mạng → tra từ / học / ôn tập vẫn chạy.
- ⚠️ Chức năng **dịch câu chất lượng cao** có thể cần internet — tùy quyết định Q&A B1.

## NFR-3. Hiệu năng (Performance)
- Tra 1 từ hiển thị kết quả: **< 100ms** (cần index cột `word` trong SQLite).
- Khởi động app (sau splash): nhanh, mượt.
- Cuộn danh sách từ trong chương mượt.

## NFR-4. Dung lượng (Storage)
- App + dữ liệu từ PDF: tùy số lượng từ, thường nhỏ (vài MB–vài chục MB nếu không kèm ảnh/audio).
- Nếu có nhiều hình ảnh minh họa → cân nhắc nén và dung lượng.

## NFR-5. Thông báo (Notifications)
- iOS: local notification đầy đủ (nhắc học/ôn).
- **Windows:** thông báo hạn chế hơn, đặc biệt **khi app đã đóng**. Mặc định chỉ nhắc khi app đang mở. ⚠️ Xem Q&A D2.

## NFR-6. Bảo mật & Riêng tư
- Không thu thập dữ liệu người dùng, không gửi lên server.
- Dữ liệu học nằm hoàn toàn trên máy (trừ khi khách chọn dịch online cho FR-4).

## NFR-7. Khả năng bảo trì
- Kiến trúc phân lớp rõ ràng (xem [03](./03-kien-truc-ky-thuat.md)).
- Logic ôn tập (SRS) tách riêng, có unit test.
- Tách rõ tầng tạo dữ liệu (PDF → SQLite) và tầng app đọc dữ liệu.

## NFR-8. Bản địa hóa
- Giao diện: tiếng Việt (mặc định).

## NFR-9. Bàn giao (Deliverables)
- Mã nguồn Flutter chạy được trên Windows (và cấu hình sẵn cho iOS).
- Bộ dữ liệu SQLite tạo từ PDF + script tạo dữ liệu.
- **Báo cáo Microsoft Word** (xem [05](./05-lo-trinh-phat-trien.md) — Giai đoạn phát hành).
