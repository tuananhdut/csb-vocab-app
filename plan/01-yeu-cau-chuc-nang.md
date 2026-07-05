# 01 — Yêu Cầu Chức Năng (Functional Requirements)

Mã `FR-x`, ưu tiên: **P0** (bắt buộc), **P1** (quan trọng), **P2** (nâng cao). Các mục có ⚠️ đang chờ chốt ở [06-cau-hoi-can-chot.md](./06-cau-hoi-can-chot.md).

---

## FR-1. Màn hình khởi động — Splash Screen (P0)

- Hiển thị hình ảnh **Cảnh sát biển Việt Nam**.
- Hiệu ứng chuyển ảnh dạng **Slide / Carousel** (nhiều ảnh chuyển tự động).
- Sau vài giây **tự động** chuyển vào giao diện chính.
- ⚠️ Nguồn ảnh & số lượng ảnh: chờ chốt (Q&A C1).

---

## FR-2. Tra cứu từ vựng (P0)

### FR-2.1 Tìm kiếm
- Ô nhập từ + nút **Tìm kiếm**.
- Gợi ý khi gõ (autocomplete) — nếu khả thi với dữ liệu.

### FR-2.2 Hiển thị kết quả
- **Từ tiếng Anh**.
- **Nghĩa tiếng Việt**.
- **Phiên âm** (nếu có).
- **Loại từ** (nếu có).
- **Ví dụ** (nếu có).
- **Hình ảnh minh họa** (nếu có — không bắt buộc).
- Nút **phát âm** (TTS) — P1.
- Nút **đánh dấu đã học / thêm ôn tập** — liên kết FR-5.
- Bố cục theo mẫu giao diện khách cung cấp. ⚠️ (cần mẫu giao diện — Q&A).

### FR-2.3 Phạm vi tra cứu
- ⚠️ Tra trong phạm vi từ của PDF **hay** từ điển đầy đủ: chờ chốt (Q&A A4).

---

## FR-3. Học theo bài học / chương (P0)

- Dữ liệu chia theo **chương** (ví dụ 11 chương).
- Màn danh sách chương → chọn 1 chương → **chỉ hiển thị nội dung chương đó**.
- Mỗi bài học: danh sách **từ + nghĩa**, bổ sung phiên âm / ví dụ / hình ảnh nếu dữ liệu hỗ trợ.
- Có thể lướt qua từng từ trong chương (dạng danh sách hoặc thẻ).
- ⚠️ Cách chia chương lấy từ PDF hay tự chia: chờ chốt (Q&A A3).

---

## FR-4. Dịch Anh ↔ Việt (P1)

- Dịch **Anh → Việt** và **Việt → Anh**.
- Giao diện tương tự **Google Translate** ở mức cơ bản (ô nhập, chọn chiều dịch, nút đổi chiều, kết quả).
- ⚠️ Mức độ dịch (tra từ/cụm từ offline **vs** dịch câu) — chờ chốt (Q&A B1). Mặc định: tra từ/cụm từ trong DB để giữ offline.

---

## FR-5. Ôn tập từ vựng (P0)

### FR-5.1 Đánh dấu đã học
- Đánh dấu từ **đã học** từ màn tra cứu / bài học.
- Danh sách các từ đã học.

### FR-5.2 Lập lịch ôn tập
- Hệ thống tính thời điểm ôn lại cho từng từ.
- Hàng đợi "**ôn hôm nay**" trên màn chính.
- ⚠️ Cơ chế: SM-2 (lặp lại ngắt quãng) **vs** khoảng cố định — chờ chốt (Q&A D1). Mặc định: SM-2.

### FR-5.3 Thông báo nhắc học
- Thông báo nhắc học/ôn lại (tham khảo TFlat).
- ⚠️ Phạm vi thông báo trên Windows hạn chế — chờ chốt (Q&A D2).

---

## FR-6. Phát âm (Text-to-Speech) (P1)

- Nút loa phát âm từ, dùng TTS offline của hệ điều hành (`flutter_tts`).

---

## FR-7. Cài đặt (P1)

- Chế độ Sáng/Tối.
- Chọn giọng phát âm (nếu hỗ trợ).
- Cấu hình ôn tập (số từ mới/ngày).
- Quản lý dữ liệu (xóa lịch sử, tạo lại DB nếu cần).

---

## Bảng tổng hợp ưu tiên

| Mã | Chức năng | Ưu tiên |
|----|-----------|---------|
| FR-1 | Splash screen (Cảnh sát biển) | **P0** |
| FR-2 | Tra cứu từ vựng | **P0** |
| FR-3 | Học theo chương | **P0** |
| FR-5 | Ôn tập + thông báo | **P0** |
| FR-4 | Dịch Anh↔Việt | P1 |
| FR-6 | Phát âm TTS | P1 |
| FR-7 | Cài đặt | P1 |
