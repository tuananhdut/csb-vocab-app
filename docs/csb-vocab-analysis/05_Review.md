# SCR-05 — Ôn tập

**FR:** FR-5 · **Trạng thái:** ✅ Đã code xong (1 kiểu: lật thẻ tự chấm) · **Nguồn:** `lib/features/review/review_screen.dart`, `lib/features/review/review_session_screen.dart`, `lib/features/review/review_providers.dart`, `lib/domain/srs/srs_scheduler.dart`

## Mục đích

Ôn lại các từ đã đánh dấu "đã học" theo lịch tính bằng thuật toán lặp lại
ngắt quãng SM-2 — chỉ hiện từ **đến hạn** (due), không phải toàn bộ từ đã học.

## Hành vi

Gồm 2 màn:

1. **`ReviewScreen`** (hàng đợi hôm nay): `dueReviewsProvider` trả về
   `List<DueReviewItem>`.
   - Rỗng → `_EmptyDue`: icon + *"Không có từ cần ôn hôm nay"* + gợi ý đánh
     dấu "Đã học" ở Tra cứu/Học để thêm từ vào hàng đợi.
   - Có từ → `_DueQueue`: header *"Có N từ cần ôn hôm nay"* + nút "Bắt đầu ôn
     tập" (mở `ReviewSessionScreen`) + danh sách preview (chỉ từ + nghĩa, không
     tương tác được — xem trước nội dung sẽ ôn).
2. **`ReviewSessionScreen`** (phiên flashcard): nhận `List<DueReviewItem>` qua
   constructor.
   - Hiện từ tiếng Anh + phiên âm trong 1 `Card`, ẩn nghĩa ban đầu
     (`_revealed = false`), có `LinearProgressIndicator` theo tiến độ
     `_index / items.length`.
   - Chạm vào card hoặc bấm "Hiện nghĩa" → lộ loại từ (`Chip`) + nghĩa tiếng
     Việt + 4 nút đánh giá: **Quên / Khó / Tốt / Dễ**
     (`ReviewRating.values`, ánh xạ `q` = 1/3/4/5).
   - Bấm 1 mức → `submitWordReview(ref, wordId, rating)` → tính lại
     `SrsCardState` mới qua `SrsScheduler.review()`, ghi `UPDATE learned_words`
     + `INSERT review_logs`, rồi chuyển sang từ tiếp theo (`_index += 1`,
     `_revealed = false`).
   - Ôn hết từ cuối cùng → `Navigator.pop()` + `SnackBar`
     *"Đã hoàn thành lượt ôn tập hôm nay!"*.

## Thuật toán SM-2

Cài đặt thuần Dart trong `SrsScheduler.review()` (`lib/domain/srs/srs_scheduler.dart`
— không phụ thuộc Flutter/DB nên test độc lập được). Tóm tắt: `q < 3` (Quên)
reset `repetitions=0, interval=1`; `q >= 3` tăng `interval` theo cấp số nhân
với `ease_factor`; `ease_factor` không bao giờ xuống dưới 1.3.

## Truy vấn dữ liệu

`SqliteReviewRepository` (`lib/data/repositories/review_repository.dart`):
- `dueToday()` — `SELECT * FROM learned_words WHERE is_learned=1 AND due_date <= <23:59:59 hôm nay>`, ghép từng dòng với `vocab.db` qua `wordById()` (chấp nhận N+1 query vì số từ đến hạn/ngày nhỏ).
- `markLearned(wordId)` — `INSERT ... ON CONFLICT(word_id) DO UPDATE` (idempotent).
- `submitReview(wordId, rating)` — đọc trạng thái hiện tại, tính lại qua `SrsScheduler`, `UPDATE` + ghi log.

## Badge số từ đến hạn

`dueReviewCountProvider` được `HomeShell` watch để hiện số đỏ (`Badge`) trên
icon tab "Ôn tập", và kích hoạt `NotificationService.showDueReminder(count)`
một lần khi mở app (nếu `count > 0`), qua `ref.listen` trong `HomeShell.build()`.

## Giả định / hạn chế

- **Chỉ 1 kiểu ôn tập** (lật thẻ tự chấm) — mockup mới nhất
  (`docs/artifact-design/screens/screen-07d/e/f-*.html`) thiết kế 3 kiểu trộn
  ngẫu nhiên (lật thẻ, gõ chữ, trắc nghiệm) trong cùng 1 phiên, **chưa có
  trong code**.
- **Không phân theo bộ từ điển** — hàng đợi ôn tập hiện là 1 danh sách chung
  cho toàn bộ từ đã học, không tách theo "bộ" như mockup (chưa có khái niệm
  bộ từ điển cá nhân trong code, xem SCR-03 và Q-CSB-02).
- Bảng `review_logs` được ghi nhưng chưa có màn hình nào đọc lại (dự phòng
  cho thống kê tương lai).
