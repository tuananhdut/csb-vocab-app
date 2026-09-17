# SCR-05 — Ôn tập

**FR:** FR-5 · **Trạng thái:** ✅ Đã code xong — trắc nghiệm + gõ chữ,
tự động chấm · **Nguồn:** `lib/features/review/review_screen.dart`,
`lib/features/review/review_session_screen.dart`,
`lib/features/review/review_result_screen.dart`,
`lib/features/review/multiple_choice_card.dart`,
`lib/data/repositories/review_repository.dart`,
`lib/domain/srs/srs_scheduler.dart`

> ⚠️ **Viết lại toàn bộ (2026-09-17, xem `docs/spec_history.md`
> [IMPL-028])** — bản trước mô tả "1 kiểu: lật thẻ tự chấm" với 4 mức
> Quên/Khó/Tốt/Dễ. Kiểu ôn đó **đã bị bỏ hoàn toàn**, thay bằng ôn tập
> khách quan (trắc nghiệm + gõ chữ, hệ thống tự chấm đúng/sai) — xem
> `docs/csb-vocab-analysis/tasks/02-review-multi-mode/03-plan.md`.

## Mục đích

Ôn lại các từ đã đánh dấu "đã học" theo lịch tính bằng thuật toán lặp lại
ngắt quãng SM-2 — chỉ hiện từ **đến hạn** (due), không phải toàn bộ từ đã
học. Có thể ôn theo hàng đợi due chung (mọi từ đã học) hoặc theo riêng 1
bộ từ điển (từ nút "Ôn tập" trên card 1 bộ ở "Từ điển của tôi").

## Hành vi

Gồm 3 màn:

1. **`ReviewScreen`** (hàng đợi hôm nay): constructor có `dictionaryId?`
   — `null` → `dueReviewsProvider` (hàng đợi due chung); có giá trị →
   `dueReviewsForDictionaryProvider(dictionaryId)` (chỉ từ thuộc bộ đó).
   - Rỗng → `_EmptyDue`: icon + *"Không có từ cần ôn hôm nay"* + gợi ý
     đánh dấu "Đã học" ở Tra cứu/Học để thêm từ vào hàng đợi.
   - Có từ → `_DueQueue`: header *"Có N từ cần ôn hôm nay"* + nút "Bắt
     đầu ôn tập" + danh sách preview (từ, nghĩa, không tương tác). Nếu có
     ≥7 từ trễ hạn ôn từ 7 ngày trở lên, hiện thêm `_OverdueBanner` cảnh
     báo màu đỏ. Mỗi dòng có thể có 2 chip phụ: "Trễ Nd" (nếu trễ ≥7
     ngày) và "Từ khó" (`isDifficult(state)` — `easeFactor <= 1.5`, xem
     `srs_scheduler.dart`).
   - Bấm "Bắt đầu ôn tập" → `buildReviewSession(ref, items)` chuẩn bị
     phiên (tối đa 4 câu, xem mục dưới) rồi mở `ReviewSessionScreen`.
2. **`ReviewSessionScreen`** (phiên ôn khách quan): nhận
   `List<ReviewQuestion>` (đã chuẩn bị sẵn kiểu câu hỏi, không phải
   `List<DueReviewItem>` thô) + `dictionaryId?` qua constructor.
   - `AppBar` hiện "Ôn tập (i/N)" + `LinearProgressIndicator` +
     `_KindBadge` (chip nhỏ ghi "Trắc nghiệm" hoặc "Gõ chữ").
   - Mỗi câu hỏi hiện 1 trong 2 dạng (chọn ngẫu nhiên 50/50 lúc build
     phiên, không đổi khi đã hiện):
     - **Trắc nghiệm** (`MultipleChoiceCard`): hiện từ tiếng Anh, chọn 1
       trong 4 đáp án nghĩa tiếng Việt (đáp án đúng + 3 phương án nhiễu
       lấy ngẫu nhiên cùng bộ từ điển).
     - **Gõ chữ** (`_TypingCard`): hiện nghĩa tiếng Việt, gõ lại từ tiếng
       Anh, so khớp tuyệt đối sau chuẩn hoá (lowercase + trim). Sai thì
       viền input đỏ + hiện dòng "Đáp án đúng: ...".
   - Hệ thống **tự động chấm đúng/sai** — không còn người dùng tự đánh
     giá cảm nhận (bỏ hẳn 4 mức Quên/Khó/Tốt/Dễ của bản thiết kế cũ).
     Trả lời xong 1 câu → `submitWordReview(ref, wordId, isCorrect:
     ..., dictionaryId: ...)` → chuyển câu tiếp theo.
   - Ôn hết câu cuối → `pushReplacement` sang **`ReviewResultScreen`**
     (màn mới, không có trong bản tài liệu cũ) hiện "Đúng
     $correctCount/$totalCount" + nút "Đóng" (`pop`) — không còn
     `SnackBar`.

## Chuẩn bị phiên ôn (`buildSession`/`buildReviewSession`)

`SqliteReviewRepository.buildSession()` (`lib/data/repositories/review_repository.dart`):
lấy tối đa **4 từ đầu tiên** trong hàng đợi due (`dueItems.take(4)`), mỗi
từ random 50/50 giữa trắc nghiệm/gõ chữ (`Random().nextBool()`). Với câu
trắc nghiệm: `_vocabRepository.randomDistractors(wordId, dictionaryId)`
lấy 3 nghĩa nhiễu cùng bộ từ điển gốc của từ, trộn ngẫu nhiên với đáp án
đúng.

## Cách chấm đúng/sai → mức SM-2

`SqliteReviewRepository.submitReview(wordId, {required bool isCorrect})`
tự suy ra `ReviewRating` từ `isCorrect` + số lần đúng liên tiếp hiện có
(`repetitions`, tính qua nhiều phiên khác nhau, không chỉ trong 1 phiên):

- Sai → `ReviewRating.forgot` (q=1, SM-2 reset `repetitions=0, interval=1`).
- Đúng, đã có ≥3 lần đúng liên tiếp trước đó (`_stableStreakThreshold`)
  → `ReviewRating.easy` (q=5, cho phép `easeFactor` tăng — đúng chuẩn
  SM-2 gốc).
- Đúng, chưa đủ streak → `ReviewRating.good` (q=4).
- `ReviewRating.hard` (q=3) **không còn đường nào gán tới** — dead code,
  vẫn giữ trong enum (`lib/domain/entities/review.dart`) nhưng không
  dùng nữa vì hệ thống chỉ chấm đúng/sai nhị phân, không có mức "gần
  đúng".

## Thuật toán SM-2

Cài đặt thuần Dart trong `SrsScheduler.review()` (`lib/domain/srs/srs_scheduler.dart`
— không phụ thuộc Flutter/DB nên test độc lập được). Tóm tắt: `q < 3`
(Quên) reset `repetitions=0, interval=1`; `q >= 3` tăng `interval` theo
cấp số nhân với `ease_factor`; `ease_factor` không bao giờ xuống dưới
1.3. Cùng file có thêm `isDifficult(state)` (`easeFactor <= 1.5`) — dùng
cho chip "Từ khó" ở `ReviewScreen`.

## Truy vấn dữ liệu

`SqliteReviewRepository` (`lib/data/repositories/review_repository.dart`):
- `dueToday()` — `SELECT * FROM learned_words WHERE is_learned=1 AND due_date <= <23:59:59 hôm nay>`, ghép từng dòng với `vocab.db` qua `wordById()` (N+1 query, chấp nhận vì số từ đến hạn/ngày nhỏ).
- `dueCount()` — cùng điều kiện, chỉ `COUNT(*)` (dùng cho badge, không cần load full).
- `dueTodayForDictionary(dictionaryId)` — lọc thêm theo `wordIds` thuộc bộ đó.
- `markLearned(wordId)` — `INSERT ... ON CONFLICT(word_id) DO UPDATE` (idempotent).
- `submitReview(wordId, {isCorrect})` — chỉ `UPDATE learned_words`, **không còn `INSERT review_logs`** (bảng này đã bị bỏ hẳn từ `docs/spec_history.md` [IMPL-016] — bản tài liệu trước vẫn ghi có ghi log là sai).
- `buildSession(dueItems)` — xem mục "Chuẩn bị phiên ôn" ở trên.

## Badge số từ đến hạn

`dueReviewCountProvider` được `HomeShell` watch để hiện số đỏ (`Badge`)
trên icon tab **"Từ điển của tôi"** (không phải tab "Ôn tập" — app không
còn tab "Ôn tập" riêng, xem `07_Home-shell.md`), và kích hoạt
`NotificationService.showDueReminder(count)` một lần khi mở app (nếu
`count > 0`), qua `ref.listen` trong `HomeShell.build()`. Ngoài ra còn có
tính năng **nhắc theo lịch tuỳ chỉnh** (đặt giờ + thứ trong tuần, gật
quyền thông báo hệ thống) — xem `06_Settings.md` mục "Nhắc ôn tập".

## Phụ thuộc

- `dueReviewsProvider`, `dueReviewsForDictionaryProvider`,
  `dueReviewCountProvider`, `submitWordReview`, `buildReviewSession`
  (`lib/features/review/review_providers.dart`).
- `MultipleChoiceCard` — dùng chung với phiên "Học từ mới"
  (`lib/features/my_dictionaries/learn_new_words_screen.dart`).
- `MyDictionariesRepository` — nguồn `randomDistractors`/hàng đợi theo bộ.

## Giả định / hạn chế

- Phiên ôn giới hạn **tối đa 4 câu/lượt** (`buildSession`, hardcode) —
  nếu hàng đợi due nhiều hơn 4, phần còn lại chờ lượt "Bắt đầu ôn tập"
  tiếp theo (chưa có UI báo "còn N từ nữa chưa ôn trong lượt này").
  Chưa xác nhận đây có phải giới hạn chủ đích lâu dài hay chỉ tạm thời.
  Xem `docs/csb-vocab-analysis/tasks/02-review-multi-mode/03-plan.md`.
- `ReviewRating.hard` là dead code trong enum — không ảnh hưởng hành vi
  nhưng có thể gây nhầm lẫn khi đọc code sau này.
