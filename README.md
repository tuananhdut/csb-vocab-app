# CSB Vocab App — App Học Từ Vựng Tiếng Anh (Cảnh Sát Biển VN)

Ứng dụng học từ vựng + tra cứu + dịch tiếng Anh **offline**, tham khảo chức năng chính của TFlat.
Xây dựng bằng **Flutter**. Ưu tiên nền tảng: **Windows → Android → iOS**. Lưu dữ liệu bằng **SQLite**.

## 📁 Cấu trúc thư mục dự án

```
csb-vocab-app/
├── plan/       # 📋 Tài liệu đặc tả (specs) — ĐỌC TRƯỚC. Bắt đầu ở plan/README.md
├── src/        # 💻 Mã nguồn Flutter (sẽ tạo ở Giai đoạn 0 bằng `flutter create`)
├── tools/      # 🔧 Script tạo dữ liệu: parse PDF → SQLite (Python/Dart)
├── assets/     # 🖼️ Tài nguyên nguồn: ảnh splash, logo, file PDF gốc, DB sinh ra
├── docs/       # 📄 Báo cáo Microsoft Word & tài liệu bàn giao
└── README.md   # (file này)
```

## 🚦 Trạng thái hiện tại

- ✅ Đã có bộ **specs** đầy đủ trong `plan/`.
- ✅ Đã chốt hầu hết yêu cầu (xem `plan/06-cau-hoi-can-chot.md`).
- ⏳ **Đang chờ khách cung cấp:**
  1. File PDF gốc (giáo trình từ vựng) → đặt vào `assets/`.
  2. File PDF định nghĩa chương → đặt vào `assets/`.
  3. Xác nhận có máy Mac (để build iOS).
  4. Logo Cảnh sát biển độ phân giải cao (nếu có).

## ▶️ Bước tiếp theo

1. Nhận 2 file PDF → bỏ vào `assets/`.
2. Viết script `tools/` parse PDF → `vocab.db`.
3. `flutter create` project trong `src/` (Giai đoạn 0 — xem `plan/05-lo-trinh-phat-trien.md`).

> Chi tiết công nghệ, kiến trúc, DB, roadmap: xem thư mục **`plan/`**.
