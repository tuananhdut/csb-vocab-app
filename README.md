# CSB Vocab App — App Học Từ Vựng Tiếng Anh (Cảnh Sát Biển VN)

Ứng dụng học từ vựng chuyên ngành + tra cứu + dịch tiếng Anh **offline** cho lực lượng Cảnh sát biển
Việt Nam. Xây dựng bằng **Flutter**. Ưu tiên nền tảng: **Windows → Android → iOS**. Lưu dữ liệu bằng
**SQLite** (`vocab.db` chỉ đọc + `user.db` đọc/ghi cho tiến độ học).

Đây là project Flutter chuẩn — chạy trực tiếp bằng `flutter run`/`flutter build` từ thư mục gốc này,
không có lớp thư mục con nào khác.

## 📁 Cấu trúc thư mục dự án

```text
csb-vocab-app/
├── lib/        # 💻 Mã nguồn Flutter (features, data, domain, core)
├── android/    # Cấu hình build Android
├── ios/        # Cấu hình build iOS
├── windows/    # Cấu hình build Windows
├── test/       # Unit test
├── assets/     # 🖼️ Tài nguyên: ảnh, logo, PDF/tài liệu nguồn, vocab.db đã sinh sẵn
├── docs/       # 📄 Tài liệu thiết kế DB, mockup UI (mobile + Windows), báo cáo bàn giao
├── pubspec.yaml
└── README.md   # (file này)
```

## 🚦 Trạng thái hiện tại

Đã triển khai xong các tính năng chính: Tra cứu song ngữ (FR-2), Học theo chương (FR-3), Ôn tập theo
thuật toán lặp lại ngắt quãng SM-2 kèm nhắc nhở (FR-5). Xem phân tích chi tiết từng màn hình tại
[`docs/csb-vocab-analysis/`](docs/csb-vocab-analysis/) và mockup giao diện tại
[`docs/artifact-design/`](docs/artifact-design/) (mobile) và [`docs/artifact-design-windows/`](docs/artifact-design-windows/) (Windows desktop).

## ▶️ Chạy dự án

```sh
flutter pub get
flutter run -d windows   # hoặc -d chrome / -d <device_id>
```
