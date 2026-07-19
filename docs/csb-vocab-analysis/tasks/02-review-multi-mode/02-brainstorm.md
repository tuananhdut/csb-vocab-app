# Task Brainstorm — Ôn tập khách quan (trắc nghiệm + gõ chữ) + nhãn "từ khó"

> Áp dụng skill `task-brainstorm` — điều chỉnh thuật ngữ cho kiến trúc
> thực tế của dự án: **"Backend"** trong output gốc của skill = **tầng
> Domain/Data (Repository, Drift/SQLite, `SrsScheduler`)**; **"Frontend"**
> = **tầng Feature/UI (Flutter widgets)**. Không có API contract/REST vì
> app local-only. Input: `01-analysis.md` (đã chốt 6 Open Question, trong
> đó OQ-6 đã **đảo ngược**: không thêm cột `review_logs.question_mode`) +
> `91_DB-design-new-model.md` mục "Ôn tập khách quan: trắc nghiệm + gõ
> chữ". Không sửa code, không implement.

# Requirement Recap

Bỏ hẳn lật thẻ tự chấm chủ quan (`ReviewRating` 4 mức người dùng tự bấm),
thay bằng 2 kiểu câu hỏi khách quan trộn ngẫu nhiên 50/50 trong 1 phiên
(tối đa 4 từ/phiên): **trắc nghiệm** (chọn 1/4 nghĩa) và **gõ chữ** (nhập
lại từ tiếng Anh, so khớp tuyệt đối sau chuẩn hoá). Hệ thống tự map
Đúng→q=4/Sai→q=1 vào `SrsScheduler` (SM-2) hiện có, không đổi thuật toán.
Thêm nhãn "từ khó" (`ease_factor <= 1.5`) — **chỉ hiển thị**, không đổi
thứ tự/lịch ôn. Thêm màn kết quả cuối phiên. **Không** thêm cột DB nào
mới cho `review_logs` (đã chốt lại: chưa có màn hình đọc lại bảng này,
thêm cột không dùng là dữ liệu chết). **Chạy sau khi đã migrate xong**
sang schema `dictionaries`/`word_dictionaries` N-N ([IMPL-014]/[IMPL-015]).

---

## Option 1: Minimal Safe Implementation

### Description

Sửa tối thiểu trên khung sẵn có: giữ nguyên `ReviewSessionScreen` làm
1 widget duy nhất nhưng đổi nội dung bên trong theo `_index` — thay vì
render 4 nút tự chấm, render 1 trong 2 layout (trắc nghiệm/gõ chữ) chọn
ngẫu nhiên bằng `Random().nextBool()` **tại thời điểm build phiên** (danh
sách kiểu câu hỏi cố định ngay khi mở phiên, không đổi giữa chừng). Đáp
án nhiễu và so khớp gõ chữ tính trực tiếp trong widget (logic Dart
thuần, không tách class riêng). Nhãn "từ khó" thêm bằng 1 `Icon` nhỏ
điều kiện `ease_factor <= 1.5` viết trực tiếp tại `_DueQueue` hiện có,
không tách hàm riêng.

### Backend Changes (Domain/Data layer)

- `review_repository.dart`: thêm 1 hàm `randomDistractors(wordId,
  dictionaryId, count)` — query trực tiếp SQL `ORDER BY RANDOM() LIMIT 3`
  trên `word_dictionaries JOIN words`, loại trừ `word_id` hiện tại.
- `submitReview()` giữ nguyên chữ ký cũ, nơi gọi (`review_session_screen.
  dart`) tự tính `quality` = 4/1 rồi truyền vào — không đổi
  `ReviewRepository` interface.
- `dueToday()` **không đổi** — chỉ cắt `.take(4)` ngay tại nơi gọi
  (`review_screen.dart`, trước khi mở `ReviewSessionScreen`).
- Không thêm entity mới — kiểu câu hỏi là 1 `bool isTyping` cục bộ trong
  `State`, không nâng lên `lib/domain/entities/review.dart`. Điều kiện
  "từ khó" (`ease_factor <= 1.5`) viết thẳng inline tại nơi dùng, không
  tách hàm `isDifficult()` riêng.
- Không cần migration DB nào cho phần review (đã chốt: không thêm
  `question_mode`).

### Frontend Changes (Feature/UI layer)

- `review_session_screen.dart`: sửa trực tiếp trong file hiện có — bỏ
  `_rate()`/4 nút, thêm `_choices` (List<String>?) và `_typedAnswer`
  (TextEditingController) làm state cục bộ, `if/else` theo `_isTyping`
  để build UI tương ứng.
- Kết quả cuối phiên: 1 `AlertDialog` đơn giản (không phải màn hình
  riêng) hiện "Đúng N/4" trước khi pop, thay `SnackBar`.

### UI Completion

Bám sát tối thiểu theo mockup 07e/07f cho phần "đang trả lời"; phần
"đã submit" của gõ chữ (mockup thiếu ảnh minh hoạ) tự chế bằng cách tái
dùng đúng các class CSS đã mô tả (`answer-reveal`) dịch trực tiếp sang
Flutter mà không thiết kế thêm biến thể mới.

### Execution Order

**Frontend-first có giới hạn**: vì phần lớn thay đổi nằm gọn trong 1 file
UI (`review_session_screen.dart`) và 1 hàm Repository mới độc lập
(`randomDistractors`), có thể viết UI trước với dữ liệu giả (mock list
string), sau đó nối `randomDistractors` thật — rủi ro thấp vì không đụng
schema DB.

### Pros

- Ít file thay đổi nhất (chủ yếu 1 file), review nhanh, risk thấp nhất
  về mặt "làm vỡ chỗ khác".
- Không có migration DB nào cho phần review — khớp đúng quyết định không
  thêm cột `question_mode`.
- Triển khai nhanh, phù hợp nếu muốn có bản demo sớm.

### Cons

- Logic so khớp gõ chữ + sinh đáp án nhiễu + điều kiện "từ khó" nằm lẫn
  trong UI widget — không tách được để unit test độc lập (khác phong
  cách `SrsScheduler` hiện có, vốn được tách riêng để test không cần
  Flutter).
- Không có entity `QuestionMode` chính thức → khó mở rộng thêm kiểu câu
  hỏi thứ 3 sau này mà không sửa lại toàn bộ file.
- Ngưỡng `ease_factor <= 1.5` viết rải rác (nếu cần dùng ở nhiều nơi
  ngoài `_DueQueue`) dễ copy-paste sai lệch giữa các chỗ.

### Risks

- Trộn "logic nghiệp vụ" (so khớp đúng/sai, sinh đáp án, ngưỡng từ khó)
  vào `State` của widget là style khác với phần còn lại của codebase
  (vốn tách `SrsScheduler` thuần Dart riêng) — dễ bị flag ở code review
  vì không nhất quán kiến trúc.
- Nếu sau này cần dùng lại logic "từ khó" ở màn khác (vd lọc "Từ khó" ở
  Từ điển của tôi), phải tách lại từ trong UI ra — tốn công sửa lần 2.

---

## Option 2: Structured Implementation

### Description

Tách đúng theo layer sẵn có của dự án (Domain thuần Dart / Repository /
Feature UI), implement đầy đủ theo scope đã chốt ở `01-analysis.md` —
bao gồm entity `QuestionMode` (chỉ ở tầng Domain runtime, không lưu DB)
và hàm `isDifficult()` tách riêng để test độc lập giống `SrsScheduler`.
Không có migration DB nào (đã chốt không thêm `question_mode`), nên
điểm khác biệt chính với Option 1 là **mức độ tách lớp** của logic
nghiệp vụ, không phải khối lượng thay đổi DB.

### Backend Changes (Domain/Data layer)

- `lib/domain/entities/review.dart`: thêm `enum QuestionMode {
  multipleChoice, typing }` (chỉ dùng ở runtime để UI biết render đúng
  dạng — **không** có cột DB tương ứng); thêm struct `ReviewQuestion`
  (word, mode, `choices: List<String>?` — null nếu typing).
- `lib/domain/srs/` : thêm hàm thuần Dart `bool isDifficult(SrsCardState
  state) => state.easeFactor <= 1.5` — file riêng hoặc thêm vào
  `srs_scheduler.dart`, có unit test riêng (không phụ thuộc DB/Flutter,
  cùng phong cách `SrsScheduler.review()`).
- `review_repository.dart`:
  - Thêm `randomDistractors(wordId, dictionaryId, count)` — query qua
    `word_dictionaries` (schema mới), fallback toàn bảng `words` nếu
    không đủ, loại trừ `word_id` hiện tại.
  - `submitReview(wordId, rating)` **không đổi chữ ký** — không có tham
    số `questionMode` vì không ghi xuống DB.
  - Thêm `buildSession(dueItems)` trả về `List<ReviewQuestion>` (tối đa
    4 phần tử, random 50/50 mode, kèm đáp án nhiễu nếu là trắc nghiệm) —
    gom logic "chuẩn bị phiên" vào 1 chỗ thay vì rải trong UI.
- **Không có migration DB** cho phần này — `user_database.dart` không
  đổi.

### Frontend Changes (Feature/UI layer)

- `review_session_screen.dart`: nhận `List<ReviewQuestion>` (đã build
  sẵn từ Repository) thay vì `List<DueReviewItem>` thô — tách rõ "chuẩn
  bị dữ liệu" (Repository) khỏi "hiển thị" (UI). Render theo
  `question.mode`.
- Thêm 1 widget con riêng cho mỗi kiểu (`_MultipleChoiceCard`,
  `_TypingCard`) thay vì if/else phẳng trong 1 hàm `build` — dễ đọc, dễ
  mở rộng thêm kiểu thứ 3 sau này.
- Thêm màn `ReviewResultScreen` (route riêng, không phải Dialog) — nhận
  `correctCount`/`totalCount`, có thể mở rộng sau (hiện danh sách từ sai)
  mà không phải đổi kiến trúc.
- `review_screen.dart`: sửa nơi gọi `dueToday()` để `.take(4)` trước khi
  gọi `buildSession()`.
- Thêm nhãn "Từ khó" trong `_DueQueue` (preview hàng đợi) dùng
  `isDifficult(state)` — hiển thị thuần tuý, không đổi thứ tự danh sách
  (đúng OQ-3).

### UI Completion

Đầy đủ theo cả 2 mockup (07e/07f) cho trạng thái "đang trả lời"; với
trạng thái "đã submit" của gõ chữ (thiếu ảnh mockup), tự thiết kế 1 khung
hình mới dựa trên đúng các CSS class đã có sẵn (`answer-reveal`,
`.correct`/`.wrong`) — đủ chi tiết để không phải đoán lại lúc code, có
thể duyệt lại nhanh với người thiết kế trước khi code UI thật (khớp phần
"Chi tiết UI ... để task-plan quyết định" đã ghi ở OQ-5).

### Execution Order

**Backend/Domain-first**: viết `QuestionMode`, `isDifficult`,
`randomDistractors`, và `buildSession()` trước — các phần này test được
độc lập (unit test thuần Dart, không cần chạy app, không cần migration
DB nào). Sau khi Repository trả đúng `List<ReviewQuestion>` như kỳ
vọng, mới viết UI nối vào. Lý do: đây là phần có logic nghiệp vụ dễ sai
nhất (map đúng/sai → quality, chọn đáp án nhiễu không trùng, giới hạn 4
từ) — verify bằng test trước khi tốn công dựng UI theo mockup.

### Pros

- Bám sát đầy đủ scope đã chốt trong `01-analysis.md` sau khi OQ-6 được
  đảo ngược (không migration DB thừa).
- Tách logic nghiệp vụ (`isDifficult`, chuẩn bị phiên) khỏi UI — nhất
  quán với phong cách hiện có của codebase (`SrsScheduler` đã tách kiểu
  này), dễ unit test, dễ mở rộng thêm kiểu câu hỏi thứ 3 sau này, dễ tái
  sử dụng `isDifficult()` ở màn khác (vd lọc "Từ khó" ở Từ điển của tôi).
- Không cần migration DB nào cho phần review — rủi ro thấp hơn Option 1
  không phải vì ít việc hơn, mà vì logic dễ verify độc lập bằng test
  trước khi chạm UI.

### Cons

- Nhiều file thay đổi hơn Option 1 (thêm entity, thêm hàm domain, thêm
  màn hình mới) — thời gian implement dài hơn dù không có migration DB.
- Cần viết thêm test cho `isDifficult`/`buildSession` để giữ đúng tinh
  thần "tách để test độc lập" — nếu không viết test thì phần tách lớp
  này chỉ tốn công mà không có lợi ích thực tế.

### Risks

- Màn `ReviewResultScreen` mới là UI chưa từng tồn tại (không mockup) —
  rủi ro phải sửa lại nếu người dùng cuối không thích bố cục tự thiết kế.
- `buildSession()` cần random đúng 50/50 và không lặp đáp án nhiễu trùng
  đáp án đúng — cần test kỹ biên (vd bộ từ điển chỉ có 1-2 từ, không đủ 3
  đáp án nhiễu).

---

## Option 3: Long-term Refactor-Oriented Implementation

### Description

Ngoài toàn bộ Option 2, tổng quát hoá kiến trúc câu hỏi ôn tập thành 1
hệ thống "pluggable question types" — định nghĩa 1 interface/abstract
class `ReviewQuestionStrategy` (có `generate()`, `checkAnswer()`,
`toQuality()`) mà `MultipleChoiceStrategy`/`TypingStrategy` implement,
để sau này thêm kiểu câu hỏi thứ 3/4/5 (nghe-chọn, sắp xếp chữ cái...)
chỉ cần thêm 1 class mới, không sửa `ReviewSessionScreen`. Đồng thời tổng
quát hoá "nhãn từ khó" thành 1 hệ thống gắn nhãn (`WordTag`) có thể mở
rộng thêm loại nhãn khác trong tương lai (không chỉ "khó", có thể thêm
"mới học", "sắp quên"...).

### Backend Changes (Domain/Data layer)

- Thêm abstract `ReviewQuestionStrategy` + registry chọn ngẫu nhiên trong
  danh sách strategy đã đăng ký (thay vì hard-code 50/50 giữa đúng 2
  kiểu).
- Thêm bảng/enum tổng quát cho "nhãn từ" thay vì hard-code
  `isDifficult()` — ví dụ 1 hàm `computeTags(SrsCardState) ->
  Set<WordTag>` mở rộng được.
- Toàn bộ phần còn lại giống Option 2 (entity, repository) — vẫn không
  có migration DB.

### Frontend Changes (Feature/UI layer)

- `ReviewSessionScreen` chỉ còn biết gọi `strategy.buildWidget(question)`
  — không còn if/else theo mode, thực sự mở (open/closed) cho kiểu câu
  hỏi mới.
- Thêm cơ chế hiển thị nhãn tổng quát (không chỉ "Từ khó") ở `_DueQueue`
  và các màn liên quan.

### UI Completion

Giống Option 2, cộng thêm phải thiết kế UI generic đủ linh hoạt cho
nhiều loại nhãn/nhiều loại câu hỏi tương lai — tăng thời gian thiết kế
dù hiện tại chỉ cần đúng 2 kiểu.

### Execution Order

Backend/Domain-first, nhưng **kéo dài hơn nhiều** vì phải thiết kế trừu
tượng hoá trước khi viết bất kỳ implementation cụ thể nào — rủi ro
"over-engineer trước khi biết rõ yêu cầu thực tế của kiểu câu hỏi thứ 3"
(hiện tại **chưa có** yêu cầu cụ thể nào cho kiểu thứ 3 trong
`01-analysis.md`, chỉ có 2 kiểu đã chốt).

### Pros

- Dễ mở rộng nhất về lâu dài nếu tương lai gần chắc chắn sẽ có thêm
  nhiều kiểu câu hỏi/nhiều loại nhãn.
- Kiến trúc "closed for modification, open for extension" — giảm rủi ro
  sửa lại `ReviewSessionScreen` mỗi lần thêm kiểu mới.

### Risks

- **Vi phạm trực tiếp nguyên tắc "giữ scope nhỏ"** và nguyên tắc "không
  refactor/không thêm abstraction ngoài phạm vi yêu cầu" đã nêu trong
  system instructions của dự án — hiện chỉ có đúng 2 kiểu câu hỏi được
  yêu cầu, chưa có bằng chứng sẽ cần kiểu thứ 3.
- Tăng đáng kể thời gian implement và bề mặt code cần review, trong khi
  lợi ích (mở rộng tương lai) là suy đoán, không có yêu cầu cụ thể nào
  trong `01-analysis.md` xác nhận.
- Rủi ro cao nhất trong 3 option về "làm vỡ chỗ khác" vì thay đổi kiến
  trúc rộng hơn cần thiết.

---

# Comparison

| Option | Scope | Safety | Speed | Maintainability | Risk | Recommendation |
|---|---|---|---|---|---|---|
| 1. Minimal Safe | Nhỏ nhất | Trung bình (logic lẫn trong UI) | Nhanh nhất | Thấp — khó test, khó mở rộng | Trung bình (nợ kỹ thuật nếu cần mở rộng sau) | Không khuyến nghị |
| 2. Structured | Đúng scope đã chốt, không migration DB thừa | Cao (tách lớp, test được) | Trung bình | Cao — nhất quán phong cách hiện có | Thấp | **Khuyến nghị** |
| 3. Long-term Refactor | Vượt quá scope đã chốt | Cao nhưng bề mặt thay đổi lớn hơn | Chậm nhất | Cao nhất (lý thuyết) nhưng chưa có yêu cầu xác nhận cần | Cao (over-engineer) | Không khuyến nghị bây giờ |

# Recommended Approach

Recommend: **Option 2 — Structured Implementation**

Reason:

- Bám sát chính xác các Acceptance Criteria và quyết định đã chốt ở
  `01-analysis.md` (đặc biệt AC5/OQ-3: nhãn "từ khó" chỉ hiển thị, không
  đổi thứ tự — Option 2 hiện thực đúng ranh giới này bằng 1 hàm
  `isDifficult()` thuần tuý, không đụng vào `dueToday()`).
- Giữ đúng phong cách kiến trúc hiện có của dự án: `SrsScheduler` vốn đã
  được tách thành hàm Dart thuần để test độc lập — `isDifficult()` và
  logic build câu hỏi nên theo đúng tiền lệ đó, không phá vỡ tính nhất
  quán.
- Không rơi vào 2 thái cực: Option 1 tạo nợ kỹ thuật (logic khó test,
  khó tái sử dụng), Option 3 vi phạm nguyên tắc "giữ scope nhỏ, không
  refactor/thêm abstraction ngoài yêu cầu" mà dự án đã quy định rõ.
- Sau khi bỏ cột `question_mode` (OQ-6 đảo ngược), Option 2 **không còn
  cần migration DB nào** cho phần review — chênh lệch chi phí so với
  Option 1 chỉ còn ở việc tách lớp code, không phải khối lượng thay đổi
  schema, nên rủi ro/thời gian thực hiện thấp hơn so với bản trước.

# Recommended Execution Order

Recommend: **Backend/Domain-first (Repository + Domain layer trước UI)**

Reason:

- Phần rủi ro logic cao nhất (map đúng/sai → quality, chọn 3 đáp án nhiễu
  không trùng đáp án đúng, cắt đúng tối đa 4 từ/phiên, ngưỡng
  `ease_factor <= 1.5`) đều là logic thuần Dart, verify được bằng unit
  test **trước khi** tốn công dựng UI theo mockup.
- Nếu làm UI trước mà logic domain sau đó phát hiện sai (vd đáp án nhiễu
  bị trùng khi bộ từ điển quá nhỏ), phải sửa lại UI đã dựng — ngược lại,
  sửa domain logic sau khi UI đã "khoá" theo đúng interface đã thống
  nhất từ đầu thì rẻ hơn.
- Không có migration DB nào cần verify riêng (đã bỏ `question_mode`) —
  toàn bộ rủi ro dồn vào logic Dart thuần, càng củng cố lý do ưu tiên
  viết và test phần Domain/Repository trước.

# Things Not To Do

- Không giữ lại bất kỳ phần nào của luồng tự chấm chủ quan (`ReviewRating`
  4 mức Quên/Khó/Tốt/Dễ) — đã chốt bỏ hẳn, không làm song song "cho chắc".
- Không thêm fuzzy-match (Levenshtein) cho kiểu gõ chữ — đã loại trừ ở
  Out of Scope của `01-analysis.md`.
- Không thêm cột "đếm số lần sai" hay bất kỳ logic sắp xếp lại hàng đợi
  theo độ khó — đã chốt ở OQ-3: SM-2 tự lo, "từ khó" chỉ là nhãn hiển thị.
- **Không thêm cột `review_logs.question_mode`** — đã chốt lại ở OQ-6:
  chưa có màn hình nào đọc lại `review_logs`, không thêm dữ liệu chưa
  ai dùng.
- Không thiết kế trước cho kiểu câu hỏi thứ 3 trở lên (Option 3) khi chưa
  có yêu cầu cụ thể — vi phạm nguyên tắc giữ scope nhỏ.
- Không viết `randomDistractors` theo `chapter_id` cũ để "làm tạm trước
  khi migrate" — đã chốt ở OQ-1: đợi migrate xong schema N-N mới làm,
  tránh viết 2 lần.
- Không tự thêm màn thống kê/xem lại `review_logs` — ngoài phạm vi task
  này (đã ghi rõ ở Out of Scope).

# TODO / Need Confirmation

- Xác nhận chi tiết UI màn kết quả cuối phiên (`ReviewResultScreen`) —
  Option 2 đề xuất route riêng thay vì Dialog để dễ mở rộng, nhưng bố cục
  cụ thể (có hiện lại từng câu sai không, có nút "Ôn lại ngay" không)
  chưa được xác nhận, cần chốt trước khi sang `task-plan`.
- Xác nhận khung hình "đã submit" cho kiểu gõ chữ (mockup thiếu ảnh minh
  hoạ) — Option 2 đề xuất tự thiết kế dựa trên CSS class có sẵn, cần
  duyệt lại bản vẽ trước khi code UI thật.
- Xác nhận vị trí đặt `isDifficult()`: thêm vào `srs_scheduler.dart` hay
  tách file domain riêng (`lib/domain/srs/word_difficulty.dart`)? Không
  ảnh hưởng hành vi, chỉ ảnh hưởng tổ chức file.
