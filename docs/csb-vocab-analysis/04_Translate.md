# SCR-04 — Dịch Anh ⇄ Việt

**FR:** FR-4 · **Trạng thái:** ⏳ Placeholder — chưa code logic · **Nguồn:** `lib/features/translate/translate_screen.dart`

## Mục đích (theo comment trong code)

Dịch Anh ⇄ Việt offline bằng cách tra ghép từ/cụm từ có sẵn trong DB (không
phải máy dịch câu/AI) — giống kiểu Google Translate về giao diện nhưng cơ chế
dịch hoàn toàn dựa trên từ điển nội bộ.

## Hiện trạng thật

Toàn bộ màn hình chỉ là `FeaturePlaceholder` dùng chung
(`lib/core/widgets/feature_placeholder.dart`) — icon + tiêu đề + tag "FR-4" +
mô tả tĩnh:

> *"Giao diện kiểu Google Translate, dịch offline bằng tra từ/cụm từ. Sẽ hoàn
> thiện ở Giai đoạn 3."*

**Không có bất kỳ logic dịch, ô nhập liệu, hay truy vấn DB nào được cài đặt.**

## So với mockup

Mockup (`docs/artifact-design/screens/screen-06-dich-nhanh.html`) đã thiết kế
đầy đủ UI: 2 khung nguồn/kết quả, chip hiển thị từng cặp từ đã ghép nghĩa
(vd: `buoy → phao`), ghi chú "Ghép nghĩa offline từ N mục từ điển". Đây là
**thiết kế UI**, chưa có code Dart tương ứng.

## Việc cần làm khi triển khai

- Quyết định thuật toán ghép từ/cụm (tokenize câu → tra từng từ/cụm trong
  `words` → ghép lại theo thứ tự, xử lý cụm nhiều từ trước từ đơn).
- Xử lý chiều Việt → Anh (tra ngược `meaning_vi`) — phức tạp hơn vì
  `meaning_vi` không unique/chuẩn hoá như `word_lower`.
- Quyết định UI khi có từ không tìm thấy trong DB (giữ nguyên từ gốc? đánh
  dấu highlight?).

## Giả định / hạn chế

> ⚠️ Chưa có quyết định kỹ thuật nào được chốt cho việc parse câu — cần
> phân tích riêng (task-analysis) trước khi implement, vì đây là phần phức
> tạp nhất trong 4 chức năng tra cứu/học/ôn tập/dịch.
