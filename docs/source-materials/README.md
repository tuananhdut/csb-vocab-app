# docs/source-materials/ — Tài liệu nguồn

Tài liệu gốc dùng để biên soạn nội dung từ vựng của app. **Không phải asset
runtime** — không được `pubspec.yaml` khai báo, không được code Dart nào đọc.
Chỉ giữ lại để tham khảo/đối chiếu khi cần bổ sung hoặc sửa lỗi dữ liệu trong
`assets/db/vocab.db`.

## Nội dung

- `TA_chuyen_nganh.docx`, `TA_chuyen_nganh_2.pdf` — giáo trình *"Tiếng Anh
  chuyên ngành Cảnh sát biển"*, nguồn gốc của 6 chương từ vựng trong
  `vocab.db` (Quân sự chung, Hàng hải, Thông tin ra đa, Vũ khí, Cơ điện,
  Cảnh sát biển).
- `Tu_dien.pdf` — từ điển tham khảo dùng đối chiếu nghĩa/phiên âm khi biên
  soạn.

## Lịch sử

Trước đây các file này nằm ở `assets/`, cùng chỗ với tài nguyên runtime thật
(`db/vocab.db`, `images/words/`) — gây lẫn lộn giữa "thứ app đóng gói khi
chạy" và "tài liệu chỉ dùng lúc biên soạn dữ liệu". Đã tách sang đây, xem
`../spec_history.md` [IMPL-004].
