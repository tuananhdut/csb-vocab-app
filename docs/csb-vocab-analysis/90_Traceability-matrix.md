# 90 — Bảng Truy Vết

Truy vết FR ↔ màn hình ↔ file code chính. Cập nhật khi thêm/sửa FR hoặc file.

| FR | Mô tả | Màn hình | Trạng thái | File code chính |
|----|-------|----------|------------|------------------|
| FR-1 | Splash — giới thiệu ứng dụng | SCR-01 | ✅ Xong | `lib/features/splash/splash_screen.dart` |
| FR-2 | Tra cứu song ngữ Anh⇄Việt | SCR-02 | ✅ Xong | `lib/features/search/search_screen.dart`, `lib/features/vocab/word_widgets.dart` |
| FR-3 | Học theo chương | SCR-03 | ✅ Xong | `lib/features/lessons/lessons_screen.dart` |
| FR-4 | Dịch Anh⇄Việt (ghép từ/cụm offline) | SCR-04 | ⏳ Placeholder, chưa code logic | `lib/features/translate/translate_screen.dart` |
| FR-5 | Ôn tập theo SM-2 (đánh dấu học, hàng đợi, phiên ôn tập, nhắc nhở) | SCR-05 | ✅ Xong (1 kiểu ôn) | `lib/features/review/*.dart`, `lib/domain/srs/srs_scheduler.dart` |
| *(không có FR-6 trong code — xem Q-CSB-01)* | | | | |
| FR-7 | Cài đặt (giao diện Sáng/Tối) | SCR-06 | ✅ Xong (rút gọn) | `lib/features/settings/*.dart` |
| — | Khung điều hướng + nhắc nhở khi mở app | SCR-07 | ✅ Xong | `lib/features/home/home_shell.dart` |

## Truy vết theo file dữ liệu

| Bảng DB | File | Đọc bởi | Ghi bởi |
|---|---|---|---|
| `chapters` | `vocab.db` | SCR-03 (`chaptersProvider`) | — (read-only, sinh sẵn) |
| `words` | `vocab.db` | SCR-02, SCR-03, SCR-05 | — (read-only) |
| `examples` | `vocab.db` | SCR-02, SCR-03 (trong `WordDetailSheet`) | — (read-only) |
| `learned_words` | `user.db` | SCR-05 (`dueReviewsProvider`, `dueReviewCountProvider`) | SCR-02/03 (`markWordLearned`), SCR-05 (`submitReview`) |
| `review_logs` | `user.db` | *(chưa có màn nào đọc)* | SCR-05 (`submitReview`) |
| `search_history` | `user.db` | *(chưa có màn nào đọc)* | *(chưa có màn nào ghi)* |

Chi tiết schema đầy đủ: tài liệu thiết kế DB riêng đã bị xoá (xem
`../spec_history.md` [IMPL-003]) — tra trực tiếp `../../lib/data/local/vocab_database.dart`
và `../../lib/data/local/user_database.dart`.

## Truy vết mockup ↔ code (khoảng cách chưa triển khai)

| Ý tưởng trong mockup | Vị trí mockup | Có trong code? |
|---|---|---|
| Bộ từ điển cá nhân (tạo bộ, thêm từ tự nhập) | `docs/artifact-design/screens/screen-07*.html` | ❌ Chưa |
| Ôn tập trộn 3 dạng câu (lật thẻ/gõ chữ/trắc nghiệm) | `docs/artifact-design/screens/screen-07d/e/f-*.html` | ❌ Chưa — code chỉ có lật thẻ |
| Tab "Từ điển của tôi" thay cho tab "Ôn tập" riêng | `docs/artifact-design/index.html` | ❌ Chưa — `HomeShell` vẫn có 5 tab cũ |
| Danh sách từ theo chương sắp A-Z (không qua bước lật thẻ) | `docs/artifact-design/screens/screen-03b-*.html` | ✅ Khớp — `ChapterWordsScreen` đã làm đúng vậy |
| Title bar tuỳ biến kiểu Windows (nút minimize/maximize/close) | `docs/artifact-design-windows/` | ❌ Chưa — code dùng `AppBar` Material chuẩn |
| Dịch 2 chiều với chip từ đã ghép nghĩa | `docs/artifact-design/screens/screen-06-dich-nhanh.html` | ❌ Chưa — SCR-04 là placeholder |
