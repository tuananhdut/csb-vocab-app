# tools/ — Script tạo dữ liệu (PDF → SQLite)

Chứa script chạy **một lần** để phân tích file PDF và sinh cơ sở dữ liệu `vocab.db`.

## Luồng xử lý (dự kiến)
```
assets/<giáo-trình>.pdf ──► parse ──► vocab.db ──► copy sang src/assets/db/
                         (pdfplumber / PyMuPDF)
```

## Sẽ tạo ở đây (sau khi có file PDF)
- `pdf_to_sqlite/` — script parse (Python khuyến nghị: `pdfplumber` hoặc `PyMuPDF`).
- Trích các trường: từ tiếng Anh, phiên âm, loại từ, nghĩa tiếng Việt, ví dụ, hình ảnh.
- Trích ảnh minh họa từ PDF → lưu và gắn `image_path`.
- Gán mỗi từ vào **chương** (theo file PDF định nghĩa chương — đang chờ).

## Schema đích
Xem `../plan/04-thiet-ke-du-lieu.md` (bảng `chapters`, `words`, `examples`).

> ⏳ **Chờ khách gửi 2 file PDF** (giáo trình + định nghĩa chương) rồi mới viết script cụ thể.
