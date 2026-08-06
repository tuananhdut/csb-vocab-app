# Implementation Plan — Ôn tập khách quan (trắc nghiệm + gõ chữ) + nhãn "từ khó"

> Áp dụng skill `task-plan` — điều chỉnh thuật ngữ cho kiến trúc thực tế
> của dự án: **"Backend"** = tầng Domain/Data (Repository, SQLite,
> `SrsScheduler`); **"Frontend"** = tầng Feature/UI (Flutter widgets).
> Không có API/REST vì app local-only. Input: `01-analysis.md` (6 Open
> Question đã chốt) + `02-brainstorm.md` (đã chọn **Option 2 —
> Structured Implementation**, Backend/Domain-first).

# Requirement Recap

Bỏ hẳn lật thẻ tự chấm chủ quan (`ReviewRating`/4 nút), thay bằng 2 kiểu
câu hỏi khách quan trộn ngẫu nhiên 50/50 trong 1 phiên (tối đa 4
từ/phiên): **trắc nghiệm** (chọn 1/4 nghĩa) và **gõ chữ** (nhập lại từ
tiếng Anh, so khớp tuyệt đối sau chuẩn hoá). Đúng→q=4, Sai→q=1, tái dùng
nguyên `SrsScheduler`. Thêm nhãn "từ khó" (`ease_factor <= 1.5`, chỉ
hiển thị, không đổi thứ tự hàng đợi) và màn kết quả cuối phiên. Không
migration DB nào (đã chốt bỏ cột `review_logs.question_mode`).

## Điều kiện tiên quyết đã thoả (OQ-1)

`01-analysis.md`/`02-brainstorm.md` chốt task này **đợi migrate xong**
sang schema `dictionaries`/`word_dictionaries` N-N rồi mới implement.
Điều kiện này **đã thoả** — `assets/db/vocab.db` đã được migrate sang
đúng `docs/db/schema.sql` (xem lịch sử hội thoại: `migrate_vocab_db.py`,
áp dụng cho SCR-03/SCR-07). `randomDistractors()` ở plan này viết trực
tiếp theo `word_dictionaries`, không cần bước trung gian nào nữa.

## 3 TODO đã chốt (bổ sung so với `02-brainstorm.md`)

| TODO | Quyết định |
|---|---|
| Nội dung màn kết quả cuối phiên | **Chỉ tổng số đúng/sai** ("Đúng 3/4" + nút Đóng) — không liệt kê lại từng từ sai |
| Khung hình "đã submit" cho gõ chữ | Đổi màu viền input theo đúng/sai (`.correct`/`.wrong`) + nếu sai, hiện thêm 1 dòng nhỏ đáp án đúng ngay dưới input (`answer-reveal`) |
| Vị trí `isDifficult()` | Thêm trực tiếp vào `lib/domain/srs/srs_scheduler.dart` (cùng file `SrsScheduler`), không tách file riêng |

# Selected Approach — Option 2: Structured Implementation

Tách đúng theo layer sẵn có (Domain thuần Dart / Repository / Feature
UI). Không có migration DB. Khác Option 1 (Minimal Safe) ở mức độ tách
lớp: logic nghiệp vụ (sinh câu hỏi, so khớp, ngưỡng khó) nằm ở
Domain/Repository, test độc lập được — cùng phong cách `SrsScheduler`
hiện có.

```
[Domain]     QuestionMode (enum runtime) + ReviewQuestion (struct)
                 │
[Domain]     isDifficult(SrsCardState) -> bool   (srs_scheduler.dart)
                 │
[Repository] randomDistractors(wordId, dictionaryId, count)
             buildSession(dueItems) -> List<ReviewQuestion>  (tối đa 4, random 50/50)
                 │
[UI]         ReviewSessionScreen (render theo question.mode)
                 ├─ _MultipleChoiceCard
                 └─ _TypingCard
                 │
[UI]         ReviewResultScreen (Đúng N/M)
                 │
[UI]         review_screen.dart: _DueQueue thêm nhãn "Từ khó"
```

# Data Contract (thay cho API Contract — không có API trong task này)

| Item | Value |
|---|---|
| `QuestionMode` | `enum QuestionMode { multipleChoice, typing }` — chỉ runtime, **không** lưu DB |
| `ReviewQuestion` | struct `{ VocabWord word, QuestionMode mode, List<String>? choices }` — `choices` có 4 phần tử (1 đúng + 3 nhiễu, thứ tự đã xáo trộn) nếu `mode == multipleChoice`, `null` nếu `typing` |
| Hàm mới — `randomDistractors` | `List<String> randomDistractors(int wordId, int dictionaryId, {int count = 3})` — query `word_dictionaries` cùng `dictionaryId`, loại trừ `wordId`, `ORDER BY RANDOM() LIMIT count`; nếu bộ không đủ `count` từ khác, fallback query toàn bộ `words` (loại trừ `wordId`) |
| Hàm mới — `buildSession` | `List<ReviewQuestion> buildSession(List<DueReviewItem> dueItems)` — cắt `.take(4)`, với mỗi item random 50/50 `QuestionMode`, nếu `multipleChoice` gọi `randomDistractors` + chèn đáp án đúng vào vị trí ngẫu nhiên |
| Hàm mới — `isDifficult` | `bool isDifficult(SrsCardState state) => state.easeFactor <= 1.5` — thuần Dart, không phụ thuộc DB/Flutter |
| Hàm giữ nguyên | `submitReview(wordId, rating)` — không đổi chữ ký; nơi gọi mới (`ReviewSessionScreen`) tự map đúng/sai → `ReviewRating` giữ q=4/q=1 (xem Risk bên dưới về việc tái dùng enum `ReviewRating` hay thêm giá trị mới) |
| Validation | So khớp gõ chữ: `input.trim().toLowerCase() == word.word.toLowerCase()` (không dùng `word_lower` riêng ở client, so trực tiếp với field đã có) |
| Lỗi dữ liệu | Bộ từ điển < 4 từ tổng (không đủ 3 đáp án nhiễu) → fallback toàn bộ `words`; nếu toàn bộ `words` cũng không đủ (dữ liệu test/demo cực nhỏ) → giảm số lựa chọn xuống còn `1 + số nhiễu tìm được` (không crash) |

## Quyết định bổ sung cần chốt: tái dùng `ReviewRating` hay thêm giá trị mới?

`ReviewRating` hiện có 4 giá trị (`forgot=1, hard=3, good=4, easy=5`) với
`label` tiếng Việt hiển thị trên nút — nhưng UI nút đã bị bỏ, nên
`label` không còn dùng để hiển thị. Chỉ cần đúng 2 giá trị `quality`
(1 và 4) theo đúng scope đã chốt. **Đề xuất**: tái dùng thẳng
`ReviewRating.forgot` (q=1, Sai) và `ReviewRating.good` (q=4, Đúng) —
không thêm enum mới, không xoá `hard`/`easy` (dù không dùng ở đường mới,
xoá sẽ là thay đổi ngoài phạm vi task này nếu có chỗ khác tham chiếu —
xem BE-01 để xác nhận trước khi quyết định xoá).

# Subtask Breakdown

## Domain/Data Subtasks (thay "Backend")

| Subtask ID | Title | Files/Modules | Description | Depends On | Risk |
|---|---|---|---|---|---|
| BE-01 | Xác nhận không còn nơi khác tham chiếu `ReviewRating.hard`/`.easy` theo nghĩa chủ quan | toàn repo (grep) | Trước khi đổi hành vi gọi `submitReview`, xác nhận `hard`/`easy` không bị dùng ở UI nào khác ngoài `review_session_screen.dart` sắp sửa — nếu có, quyết định giữ enum nguyên vẹn (chỉ đổi *nơi gọi*, không đổi *enum*) | None | Thấp — chỉ 1 file dùng theo khảo sát `01-analysis.md` |
| BE-02 | Thêm `isDifficult()` vào `srs_scheduler.dart` | `lib/domain/srs/srs_scheduler.dart` | Hàm top-level hoặc static method: `bool isDifficult(SrsCardState state) => state.easeFactor <= 1.5` — thuần Dart, unit test độc lập (không cần DB/Flutter) | None | Thấp |
| BE-03 | Thêm `QuestionMode` + `ReviewQuestion` vào `domain/entities/review.dart` | `lib/domain/entities/review.dart` | `enum QuestionMode { multipleChoice, typing }`; `class ReviewQuestion { word, mode, choices }` | None | Thấp |
| BE-04 | Thêm `randomDistractors()` vào Repository | `lib/data/repositories/review_repository.dart` (implementation SQLite), `lib/domain/repositories/review_repository.dart` (interface) | Query theo `word_dictionaries`/`dictionary_id` (đã migrate — xem Điều kiện tiên quyết), fallback toàn bộ `words` nếu không đủ. Cần biết `dictionary_id` của từ đang hỏi — lấy dictionary **đầu tiên** của `word.id` (nhất quán cách `chapter_title` hiện lấy 1 bộ đại diện ở `vocab_repository.dart`) | Điều kiện tiên quyết (đã thoả) | Trung bình — cần viết đúng query loại trừ trùng đáp án đúng |
| BE-05 | Thêm `buildSession()` vào Repository (hoặc file domain riêng thuần Dart) | `lib/data/repositories/review_repository.dart` hoặc `lib/domain/srs/` | Nhận `List<DueReviewItem>`, cắt `.take(4)`, random 50/50 `QuestionMode` mỗi từ, gọi `randomDistractors` khi `multipleChoice`, xáo trộn vị trí đáp án đúng trong 4 lựa chọn | BE-03, BE-04 | Trung bình — random 50/50 + không lặp đáp án là phần dễ sai nhất, cần test biên (bộ chỉ có 1-2 từ) |
| BE-06 | Sửa nơi gọi `submitReview` để nhận q=4/q=1 từ đúng/sai (không đổi chữ ký) | `review_session_screen.dart` (UI, nhưng logic map đặt gần nơi chấm) | Đúng → `ReviewRating.good`, Sai → `ReviewRating.forgot` (xem Quyết định bổ sung trên) | BE-01 | Thấp |

## Feature/UI Subtasks (thay "Frontend")

| Subtask ID | Title | Files/Modules | Description | Depends On | Risk |
|---|---|---|---|---|---|
| FE-01 | Viết `_MultipleChoiceCard` | `lib/features/review/review_session_screen.dart` (widget con mới, cùng file hoặc tách `_multiple_choice_card.dart` nếu file quá dài) | Theo mockup 07f: `audio-card` (từ + IPA + nút phát âm — tái dùng service TTS hiện có nếu có) + 4 `choice-row` (A/B/C/D). Chạm 1 đáp án → tô `.correct`/`.wrong` ngay, disable các lựa chọn còn lại, tự động gọi `submitReview` rồi next sau khoảng trễ ngắn (~800ms) | BE-03, BE-05 | Thấp — mockup đủ chi tiết |
| FE-02 | Viết `_TypingCard` | cùng vị trí FE-01 | Theo mockup 07e: `type-card` (nghĩa tiếng Việt + `pos-tag`) + input text + nút submit. Sau submit: đổi viền input theo đúng/sai (quyết định đã chốt), nếu sai hiện thêm dòng nhỏ đáp án đúng dưới input, disable input, tự next sau khoảng trễ ngắn | BE-03, BE-05 | Trung bình — UI "đã submit" tự thiết kế (mockup thiếu ảnh), cần review lại sau khi code |
| FE-03 | Viết lại `ReviewSessionScreen` | `lib/features/review/review_session_screen.dart` | Nhận `List<ReviewQuestion>` (từ `buildSession()`) thay `List<DueReviewItem>` thô. Bỏ hoàn toàn `_rate()`/4 `OutlinedButton`/`_revealed`. Giữ `LinearProgressIndicator` + `kind-badge` (nhãn "Trắc nghiệm"/"Gõ chữ" theo `question.mode`). Render `_MultipleChoiceCard` hoặc `_TypingCard` theo mode. Khi hết list → mở `ReviewResultScreen` thay `SnackBar` | FE-01, FE-02, BE-05, BE-06 | Trung bình — thay đổi lớn nhất trong 1 file, nhiều state cần quản lý đúng (khoá input khi đang chờ next) |
| FE-04 | Viết `ReviewResultScreen` | `lib/features/review/review_result_screen.dart` (file mới) | Route riêng (không phải Dialog, theo Option 2 đã chọn) — nhận `correctCount`/`totalCount`, hiện "Đúng N/M" + nút Đóng (pop về `ReviewScreen`). Chỉ đúng/sai tổng, không liệt kê từng từ (theo TODO đã chốt) | FE-03 | Thấp |
| FE-05 | Cắt `.take(4)` trước khi mở phiên | `lib/features/review/review_screen.dart` | Sửa nơi gọi mở `ReviewSessionScreen`: build `List<ReviewQuestion>` qua `buildSession(items.take(4).toList())` hoặc gọi `buildSession(items)` (đã tự cắt trong hàm — xem BE-05, chọn 1 trong 2 nơi cắt, khuyến nghị cắt trong `buildSession()` để logic tập trung 1 chỗ) | BE-05 | Thấp |
| FE-06 | Thêm nhãn "Từ khó" trong `_DueQueue` | `lib/features/review/review_screen.dart` | Dùng `isDifficult(item.state)` (BE-02) — thêm 1 `Chip`/label nhỏ cạnh từ trong danh sách preview hàng đợi, **không đổi thứ tự** danh sách (đúng OQ-3/AC5) | BE-02 | Thấp |

# Recommended Execution Order

Giữ nguyên khuyến nghị **Backend/Domain-first** đã chốt ở `02-brainstorm.md`:

1. BE-01 (xác nhận an toàn trước khi đổi hành vi `ReviewRating`)
2. BE-02, BE-03 (các phần thuần Dart, độc lập, viết test được ngay)
3. BE-04, BE-05 (Repository — phần rủi ro logic cao nhất: random không
   trùng đáp án, cắt đúng 4 từ, fallback khi bộ nhỏ — **verify bằng unit
   test trước khi đụng UI**)
4. BE-06 (map đúng/sai → rating, phụ thuộc BE-01)
5. FE-01, FE-02 (2 widget con, độc lập nhau, có thể làm song song)
6. FE-03 (ghép `ReviewSessionScreen` — phụ thuộc toàn bộ Domain/Data đã
   xong và FE-01/FE-02 đã có)
7. FE-04 (màn kết quả — độc lập, có thể làm song song với FE-03 nếu định
   nghĩa route/tham số trước)
8. FE-05, FE-06 (2 thay đổi nhỏ ở `review_screen.dart`, làm cuối cùng)

Lý do giữ thứ tự này (nhắc lại từ brainstorm): logic nghiệp vụ dễ sai
nhất (BE-04/BE-05) là thuần Dart, verify bằng unit test rẻ hơn nhiều so
với phát hiện lỗi sau khi đã dựng UI theo mockup rồi phải sửa lại.

# Manual Verification Plan

## Main Flow

- [ ] Mở "Ôn tập" với ≥4 từ đến hạn → phiên đúng 4 câu, trộn cả trắc
      nghiệm và gõ chữ (không phải toàn 1 kiểu).
- [ ] Mở "Ôn tập" với 1 từ đến hạn → phiên chỉ có 1 câu (không độn thêm
      từ chưa đến hạn).
- [ ] Trả lời hết phiên → mở `ReviewResultScreen` hiện đúng "Đúng N/M",
      không phải `SnackBar` cũ.

## Data Verification

- [ ] Trắc nghiệm: 4 lựa chọn không lặp, đúng 1 đáp án đúng khớp
      `meaning_vi` của từ đang hỏi, 3 đáp án nhiễu khác nhau.
- [ ] Trắc nghiệm với bộ từ điển nhỏ (< 4 từ) → vẫn ra đủ 4 lựa chọn nhờ
      fallback toàn bộ `words`.
- [ ] Gõ chữ: nhập đúng chữ nhưng dư khoảng trắng/hoa thường lẫn lộn (vd
      `" Buoy "`) → vẫn chấm đúng.
- [ ] Gõ chữ: nhập sai → viền đỏ + hiện đáp án đúng dưới input.
- [ ] Trả lời đúng → `learned_words.ease_factor` tăng, `due_date` xa hơn
      (theo SM-2 q=4); trả lời sai → `interval_days=1`, `repetitions=0`
      (theo SM-2 q=1) — đối chiếu trực tiếp qua `user.db`.
- [ ] Từ có `ease_factor <= 1.5` hiện nhãn "Từ khó" ở `_DueQueue`; từ
      khác không hiện nhãn.

## Error / Edge Case

- [ ] Bộ từ điển chỉ có đúng từ đang hỏi (0 từ khác) → không crash, số
      lựa chọn giảm xuống (documented fallback, không phải bug).
- [ ] Ôn tập khi hàng đợi rỗng (0 từ đến hạn) → giữ hành vi `_EmptyDue`
      hiện có, không đổi.

## Regression

- [ ] Không còn bất kỳ `OutlinedButton` Quên/Khó/Tốt/Dễ nào trong toàn
      app (grep xác nhận sau khi implement).
- [ ] `markLearned`/`dueToday`/`dueCount` không đổi hành vi — chỉ
      `ReviewSessionScreen` và nơi gọi nó thay đổi.
- [ ] Luồng SCR-07 ("Từ điển của tôi", nút "Ôn tập ngay" mở `ReviewScreen`
      toàn cục) vẫn hoạt động đúng sau khi `ReviewSessionScreen` đổi —
      xác nhận không phá luồng vừa làm ở task trước.

# Risks / TODO

- **[Đã chốt]** Cả 3 TODO ở `02-brainstorm.md` — xem bảng đầu file này.
- **[Đã thoả]** OQ-1 (đợi migrate) — `vocab.db` đã migrate xong.
- **Cần xác nhận ở BE-01**: nếu phát hiện `ReviewRating.hard`/`.easy`
  đang được dùng ở nơi khác ngoài dự đoán, cần quay lại quyết định có
  nên giữ 4 giá trị enum nguyên vẹn (chỉ 2 giá trị được dùng ở đường
  mới) hay tách riêng — không tự quyết định thay đổi enum nếu phát hiện
  phụ thuộc chưa biết.
- Đáp án nhiễu lấy theo dictionary **đầu tiên** của từ (nếu 1 từ thuộc
  nhiều bộ) — chấp nhận được vì UI hiện tại cũng chỉ hiện 1
  `chapterTitle` đại diện, nhất quán cách đã làm.
- `_MultipleChoiceCard` có nút phát âm (audio) theo mockup 07f — cần
  xác nhận `flutter_tts` (đã có trong `pubspec.yaml`) đọc đúng tiếng Anh
  trước khi coi FE-01 hoàn tất; nếu TTS không sẵn dùng ngay, có thể ẩn
  nút phát âm tạm thời (ghi nhận, không chặn toàn bộ task).
