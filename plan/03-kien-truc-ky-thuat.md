# 03 — Kiến Trúc Kỹ Thuật (Technical Architecture)

## 1. Tech Stack

| Thành phần | Công nghệ | Ghi chú |
|-----------|-----------|---------|
| Framework | **Flutter** (stable mới nhất) | Một codebase — ưu tiên **Windows → Android → iOS** (đã chốt E3) |
| Ngôn ngữ | **Dart 3+** | |
| Local Database | **SQLite** — qua **Drift** *hoặc* **sqflite + sqflite_common_ffi** | ⚠️ Trên **Windows/desktop**, `sqflite` cần `sqflite_common_ffi` (hoặc dùng Drift hỗ trợ desktop sẵn). **Drift được khuyến nghị** vì hỗ trợ đa nền tảng gọn hơn |
| State Management | **Riverpod** | Gọn, dễ test |
| Điều hướng | **go_router** | Responsive, deep-link |
| Phát âm | **flutter_tts** | TTS offline của OS |
| Thông báo | **flutter_local_notifications** | iOS/Android đầy đủ; Windows chỉ khi app mở (đã chốt D2) |
| Carousel splash | **carousel_slider** (hoặc PageView tự làm) | Slide ảnh Cảnh sát biển |
| Cài đặt nhẹ | **shared_preferences** | Theme, giọng đọc... |
| Đường dẫn file | **path_provider** | Vị trí lưu DB |
| Xử lý PDF (tạo dữ liệu) | script riêng — **Python** (`pdfplumber`/`PyMuPDF`) hoặc Dart | Chạy 1 lần lúc build dữ liệu, không nằm trong app |

> **Quyết định SQLite:** khuyến nghị **Drift** (SQLite ORM) vì chạy tốt trên cả Windows và iOS mà ít cấu hình. Nếu quen SQL thuần có thể dùng `sqflite` + `sqflite_common_ffi` cho desktop.

## 2. Kiến trúc phân lớp

```
┌─────────────────────────────────────────┐
│  Presentation (UI)                        │
│  - Screens: Splash, Search, Lessons,      │
│    Translate, Review, Settings            │
│  - Riverpod Providers (state)             │
├─────────────────────────────────────────┤
│  Domain (Business Logic)                  │
│  - Entities: Word, Chapter, Lesson,       │
│    ReviewCard                             │
│  - Use cases: Search, StudyChapter,       │
│    Translate, ReviewSession               │
│  - SRS scheduler (thuần Dart, có test)    │
├─────────────────────────────────────────┤
│  Data                                     │
│  - Repositories (interface + impl)        │
│  - SQLite (Drift): vocab + user data      │
│  - Services: TTS, Notification            │
└─────────────────────────────────────────┘
```

Ngoài app, có **pipeline tạo dữ liệu** riêng: `PDF → parser → sinh file SQLite (.db)` → đóng gói vào `assets/`.

## 3. Cấu trúc thư mục đề xuất

```
lib/
├── main.dart
├── app.dart                      # MaterialApp, theme, router
├── core/
│   ├── theme/                    # màu (tông xanh biển), dark/light
│   ├── router/                   # go_router
│   ├── constants/
│   └── utils/
├── data/
│   ├── local/
│   │   └── app_database.dart     # Drift: bảng vocab + user
│   ├── models/
│   ├── services/
│   │   ├── tts_service.dart
│   │   └── notification_service.dart
│   └── repositories/
├── domain/
│   ├── entities/
│   ├── repositories/             # interface
│   └── srs/
│       └── srs_scheduler.dart
├── features/
│   ├── splash/                   # FR-1 carousel Cảnh sát biển
│   ├── search/                   # FR-2 tra cứu
│   ├── lessons/                  # FR-3 học theo chương
│   ├── translate/                # FR-4 dịch
│   ├── review/                   # FR-5 ôn tập + thông báo
│   └── settings/                 # FR-7
└── l10n/

assets/
├── db/vocab.db                   # DB tạo từ PDF (đóng gói sẵn)
├── images/coast_guard/           # 3–5 ảnh splash (tự dựng — đã chốt C1)
└── images/words/                 # ảnh minh họa trích từ PDF (đã chốt A5)

tools/
└── pdf_to_sqlite/                # script tạo dữ liệu (Python/Dart)
```

## 4. Chiến lược dữ liệu 2 nhóm bảng (trong 1 file SQLite hoặc 2 file)
1. **Dữ liệu từ vựng (read-only):** words, chapters, lessons — tạo từ PDF, đóng gói sẵn.
2. **Dữ liệu người dùng (read-write):** trạng thái đã học, lịch ôn (SRS), lịch sử.

> Nên tách 2 file DB (`vocab.db` read-only + `user.db` read-write) để cập nhật dữ liệu từ vựng không ảnh hưởng tiến độ học. (Chi tiết ở [04](./04-thiet-ke-du-lieu.md).)

## 5. Đóng gói & vị trí lưu dữ liệu
- `vocab.db` đặt trong `assets/db/`, **copy ra thư mục dữ liệu app** lần đầu chạy (assets read-only).
- Vị trí lưu: `getApplicationSupportDirectory()` (package `path_provider`).
  - Windows: thường ở `C:\Users\<user>\AppData\Roaming\<app>\...`
  - iOS: thư mục sandbox của app.
- `user.db` tạo mới trong cùng thư mục dữ liệu app.

## 6. Chức năng dịch (FR-4) — lưu ý kiến trúc
- ✅ (đã chốt B1=a) Offline: tra từ/cụm từ trong `vocab.db` rồi ghép → tách thành `TranslateRepository` để **dễ thay** bằng API online sau nếu khách yêu cầu.

## 7. Responsive / Adaptive UI
- Windows/desktop: cửa sổ rộng → có thể master-detail (danh sách + chi tiết).
- Android/iOS (mobile): bố cục 1 cột, bottom navigation.
- Dùng `LayoutBuilder` + breakpoints.

## 8. Testing
- Unit test: thuật toán SRS, repository (mock DB).
- Widget test: màn tra từ, học theo chương.

## 9. Môi trường build
- **Windows:** Visual Studio (Desktop C++ workload) + Flutter desktop enabled.
- **Android:** Android SDK (qua Android Studio) — build APK/AAB.
- **iOS:** bắt buộc **Mac** + Xcode để build & chạy trên iPhone (chế độ Developer — chưa cần tài khoản Apple Developer trả phí, đã chốt E1).
- ⚠️ Dự án dùng Flutter stable — đọc tài liệu Flutter chính thức trước khi dùng API mới.
