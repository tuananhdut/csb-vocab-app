# 90 — Bảng Truy Vết

Truy vết FR ↔ màn hình ↔ file code chính. Cập nhật khi thêm/sửa FR hoặc file.

> ⚠️ Cập nhật 2026-09-17 ([IMPL-028]/[IMPL-029]): định hướng "tra cứu
> online/offline, bộ từ điển N-N, Section/Chapter dạng bài báo" (từng ghi
> "chưa code" ở đây) **đã code xong từ trước** — đã đưa vào bảng dưới.

| FR | Mô tả | Màn hình | Trạng thái | File code chính |
|----|-------|----------|------------|------------------|
| FR-1 | Splash — giới thiệu ứng dụng | SCR-01 | ✅ Xong | `lib/features/splash/splash_screen.dart` |
| FR-2 | Tra cứu song ngữ Anh⇄Việt, offline + Online (MyMemory/Free Dictionary API) | SCR-02 | ✅ Xong | `lib/features/search/search_screen.dart`, `lib/features/vocab/word_widgets.dart`, `lib/data/services/dictionary_api_service.dart` |
| FR-3 | Học theo chương/section (nội dung PDF) | SCR-03 | ✅ Xong | `lib/features/lessons/lessons_screen.dart` |
| FR-4 | Dịch Anh⇄Việt (ưu tiên Online/MyMemory, on-device (opus-mt) fallback — [IMPL-017]/[IMPL-025]) | SCR-04 | ✅ Xong | `lib/features/translate/translate_screen.dart`, `lib/data/services/translation_service.dart`, `lib/data/services/model_download_service.dart` |
| FR-5 | Ôn tập theo SM-2 (đánh dấu học, hàng đợi theo/không theo bộ, phiên trắc nghiệm+gõ chữ tự chấm, nhắc nhở) | SCR-05 | ✅ Xong | `lib/features/review/*.dart`, `lib/domain/srs/srs_scheduler.dart` |
| *(không có FR-6 trong code — xem Q-CSB-01)* | | | | |
| FR-7 | ~~Cài đặt (giao diện Sáng/Tối)~~ — **đã xoá khỏi code**, xem Q-CSB-11 | SCR-06 | ⚠️ Chỉ còn modal "Nhắc ôn tập" (FR-5.3) | `lib/features/settings/widgets/daily_reminder_sheet.dart` |
| — | Khung điều hướng (4 tab) + nhắc nhở khi mở app + badge mạng | SCR-07 | ✅ Xong | `lib/features/home/home_shell.dart` |
| — | Bộ từ điển cá nhân ("Từ điển của tôi") — chưa có mã FR/SCR chính thức, chưa có tài liệu riêng (Q-CSB-10) | — | ✅ Xong (code), tài liệu ❌ | `lib/features/my_dictionaries/*.dart` |

## Truy vết theo file dữ liệu

| Bảng DB | File | Đọc bởi | Ghi bởi |
|---|---|---|---|
| `chapters`/`dictionaries` | `vocab.db` | SCR-03 (`chaptersProvider`), My Dictionaries (`lib/features/my_dictionaries/`) | — (read-only, sinh sẵn — gồm cả bộ "Military Dictionary" gộp từ `Tu_dien.pdf`, [IMPL-021]) |
| `words` | `vocab.db` | SCR-02, SCR-03, SCR-05, My Dictionaries | — (read-only, trừ từ tự thêm qua "Tự thêm từ mới" ghi vào `user.db`) |
| `examples` | `vocab.db` | SCR-02, SCR-03 (trong `WordDetailSheet`) | — (read-only) |
| `learned_words` | `user.db` | SCR-05 (`dueReviewsProvider`, `dueReviewCountProvider`) | SCR-02/03 (`markWordLearned`), SCR-05 (`submitReview`) |

> `review_logs` và `search_history` đã **bỏ hẳn** khỏi thiết kế
> ([IMPL-016]) — không còn trong schema, xoá khỏi bảng này.

Chi tiết schema đầy đủ: tài liệu thiết kế DB riêng đã bị xoá (xem
`../spec_history.md` [IMPL-003]) — tra trực tiếp `../../lib/data/local/vocab_database.dart`
và `../../lib/data/local/user_database.dart`.

## Truy vết mockup ↔ code (khoảng cách chưa triển khai)

| Ý tưởng trong mockup | Vị trí mockup | Có trong code? |
|---|---|---|
| Bộ từ điển cá nhân (tạo bộ, thêm từ tự nhập) | `docs/artifact-design/screens/screen-07*.html` | ✅ Có — `lib/features/my_dictionaries/` (danh sách bộ, chi tiết bộ có phân trang, tự thêm từ, tự điền dữ liệu). **Chưa có tài liệu SCR phân tích riêng** — xem Q-CSB-10 (`docs/spec_history.md`) |
| Ôn tập trộn 3 dạng câu (lật thẻ/gõ chữ/trắc nghiệm) | `docs/artifact-design/screens/screen-07d/e/f-*.html` | ⚠️ 1 phần — code đã có trắc nghiệm + gõ chữ ([IMPL-015]), chưa xác nhận lại có đủ cả lật thẻ trộn ngẫu nhiên 3 kiểu như mockup hay không (cần rà soát `05_Review.md`, ngoài phạm vi đợt cập nhật này) |
| Tab "Từ điển của tôi" thay cho tab "Ôn tập" riêng | `docs/artifact-design/index.html` | ❌ Chưa xác nhận lại — cần rà soát `07_Home-shell.md` |
| Danh sách từ theo chương sắp A-Z (không qua bước lật thẻ) | `docs/artifact-design/screens/screen-03b-*.html` | ✅ Khớp — `ChapterWordsScreen` đã làm đúng vậy |
| Title bar tuỳ biến kiểu Windows (nút minimize/maximize/close) | `docs/artifact-design-windows/` | ❌ Chưa — code dùng `AppBar` Material chuẩn |
| Dịch 2 chiều với chip từ đã ghép nghĩa | `docs/artifact-design/screens/screen-06-dich-nhanh.html` | ⚠️ Đổi hướng — giữ layout 2 khung + nút đảo chiều, bỏ chip ghép nghĩa (không hợp với máy dịch neural); ưu tiên dịch Online khi có mạng, on-device chỉ fallback, xem [IMPL-017]/[IMPL-025] |
| Tra cứu có trạng thái Online (gọi thêm API từ điển ngoài) | *(chưa có ở mockup, mới chốt ở [IMPL-005])* | ✅ Có — MyMemory + Free Dictionary API, xem `02_Search.md` |
| Section chứa nhiều Chapter, Chapter hiển thị dạng bài báo | *(chưa có ở mockup, mới chốt ở [IMPL-005])* | ❌ Chưa — SCR-03 vẫn là mô hình "chương = nhóm từ" cũ, xem `03_Lessons-by-chapter.md` |
