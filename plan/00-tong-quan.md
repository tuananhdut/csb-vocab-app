# 00 — Tổng Quan Dự Án

## 1. Tên dự án
Ứng dụng **học từ vựng tiếng Anh** (tham khảo chức năng chính của **TFlat**) — hoạt động offline.
*(Tên hiển thị chính thức: chờ chốt — xem [06-cau-hoi-can-chot.md](./06-cau-hoi-can-chot.md) mục C2.)*

## 2. Tầm nhìn (Vision)
Xây dựng ứng dụng giúp người học tra cứu, học và ôn tập từ vựng tiếng Anh **offline** sau khi dữ liệu được tạo từ file PDF nguồn. Tham khảo các chức năng chính của TFlat (tra từ, học theo bài, ôn tập nhắc lịch) — **không sao chép toàn bộ**.

## 3. Mục tiêu chính (Goals)
1. **Tra cứu từ vựng** nhanh, hiển thị nghĩa Việt, phiên âm, loại từ, ví dụ, hình ảnh (nếu có).
2. **Học theo bài học/chương** — dữ liệu chia thành các chương (ví dụ 11 chương), chọn chương nào chỉ hiện nội dung chương đó.
3. **Dịch Anh↔Việt** ở mức cơ bản (giao diện tương tự Google Translate).
4. **Ôn tập từ vựng** — đánh dấu từ đã học, lập lịch ôn, thông báo nhắc học (tham khảo cơ chế TFlat).
5. **Offline** — hoạt động không cần internet sau khi tạo dữ liệu.
6. **Đa nền tảng** — ưu tiên chạy ổn định trên **Windows** trước, sau đó mở rộng **iOS**.

## 4. Đối tượng người dùng (Target Users)
- Người học tiếng Anh theo giáo trình/bộ từ vựng có sẵn (nguồn PDF).
- Người cần tra từ và ôn tập offline trên máy tính Windows.

## 5. Phạm vi (Scope)

### ✅ Trong phạm vi (In-scope)
- Splash screen với ảnh Cảnh sát biển Việt Nam, hiệu ứng slide/carousel, tự chuyển vào màn chính.
- Tra cứu từ vựng offline.
- Học theo chương/bài học.
- Dịch Anh↔Việt cơ bản (offline — xem giới hạn ở mục 6 & Q&A B1).
- Ôn tập: đánh dấu đã học, lịch ôn tập, thông báo nhắc.
- Lưu dữ liệu cục bộ bằng SQLite.
- Báo cáo bàn giao bằng Microsoft Word.

### ❌ Ngoài phạm vi (Out-of-scope, giai đoạn đầu)
- Đăng nhập tài khoản / đồng bộ đám mây.
- Dịch cả câu chất lượng cao offline (rất nặng — xem Q&A B1).
- Thông báo nền khi app đã đóng trên Windows (hạn chế kỹ thuật — xem Q&A D2).
- Luyện nghe-nói hội thoại, AI chatbot.

> 💡 Nhiều điểm phạm vi phụ thuộc câu trả lời trong [06-cau-hoi-can-chot.md](./06-cau-hoi-can-chot.md).

## 6. Ràng buộc & rủi ro đã biết
- **Dữ liệu phụ thuộc file PDF** — chưa có file thì chưa tạo được DB (rủi ro cao nhất).
- **Dịch offline** — chất lượng dịch câu offline rất hạn chế; mặc định làm kiểu tra từ/cụm từ.
- **iOS cần máy Mac** + tài khoản Apple Developer để build/publish.
- **Thông báo trên Windows** yếu hơn mobile.

## 7. Nguyên tắc thiết kế cốt lõi
- **Offline-first:** chức năng cốt lõi chạy không cần mạng.
- **Windows-first:** chạy ổn định trên Windows trước, kiến trúc sẵn sàng cho iOS.
- **Đơn giản, đúng nhu cầu khách**, không tự thêm/bớt tính năng ngoài yêu cầu khi chưa chốt.
