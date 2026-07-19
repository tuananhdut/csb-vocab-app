# Task Analysis — Ôn tập nhiều kiểu câu hỏi (khách quan) + đánh dấu từ khó

> Áp dụng skill `task-analysis` — điều chỉnh format cho kiến trúc thực tế
> của dự án (Flutter, SQLite/Drift local, không có backend/API/serializer
> riêng biệt). Không sửa code, không implement, chỉ phân tích.

# Requirement Summary

## Business Goal

Thay cơ chế ôn tập hiện tại (lật thẻ, người dùng **tự chấm** chủ quan qua
4 nút Quên/Khó/Tốt/Dễ) bằng cơ chế **khách quan, tự động chấm điểm** dựa
trên hành vi trả lời thật của người dùng, gồm 2 kiểu câu hỏi:

1. **Trắc nghiệm** — hiện từ tiếng Anh, chọn 1 trong 4 đáp án nghĩa tiếng
   Việt (khớp mockup `screen-07f-phien-on-tap-cau-trac-nghiem.html`).
2. **Gõ chữ** — hiện nghĩa tiếng Việt, gõ lại từ tiếng Anh, hệ thống tự so
   khớp chuỗi (khớp mockup `screen-07e-phien-on-tap-cau-go-chu.html`).

Đồng thời bổ sung cơ chế **tự động phát hiện "từ khó"** (không cần người
dùng thao tác) để ưu tiên nhắc lại các từ này thường xuyên hơn trong hàng
đợi ôn tập — cải thiện trải nghiệm so với SM-2 gốc vốn chỉ điều chỉnh
lịch ôn theo `interval_days`, không có khái niệm ưu tiên hiển thị.

## Scope

- Bỏ hẳn kiểu **lật thẻ tự chấm chủ quan** hiện có (`ReviewRating` 4 mức
  do người dùng tự bấm) — quyết định đã xác nhận: không giữ song song.
- Thêm 2 kiểu câu hỏi mới: **trắc nghiệm** (chọn đáp án) và **gõ chữ**
  (nhập text) — hệ thống tự chấm đúng/sai, không hỏi cảm nhận người dùng.
- Cả 2 kiểu tái sử dụng **nguyên vẹn thuật toán SM-2** hiện có
  (`SrsScheduler`), chỉ đổi cách sinh `quality` (0–5) đưa vào:
  - Đúng → `q=4`, Sai → `q=1` (đã chốt ở `91_DB-design-new-model.md` mục
    "Ôn tập bằng trắc nghiệm", áp dụng chung cho cả gõ chữ).
- Trộn ngẫu nhiên 2 kiểu trong 1 phiên ôn (không cố định 1 kiểu cho cả
  phiên) — khớp tinh thần mockup gốc (dù mockup gốc có 3 kiểu, nay còn 2).
- **Đánh dấu từ khó**: hệ thống tự động suy ra "từ khó" từ dữ liệu SM-2
  sẵn có (`ease_factor` thấp và/hoặc chuỗi lần sai gần nhất), **không**
  cần người dùng thao tác gắn cờ thủ công. Từ khó được ưu tiên nổi lên
  trong hàng đợi/tần suất xuất hiện.
- So khớp chuỗi gõ chữ: so sánh tuyệt đối sau khi chuẩn hoá
  (`trim().toLowerCase()`), không fuzzy-match.
- Đáp án nhiễu trắc nghiệm: random 3 `meaning_vi` khác cùng bộ từ điển
  (`dictionary_id` qua `word_dictionaries`), fallback toàn bộ `words`
  nếu bộ không đủ từ.

## Out of Scope

- Không phục hồi/giữ lại kiểu lật thẻ tự chấm chủ quan.
- Không đo/lưu thời gian phản hồi (response time) — đã loại trừ ở quyết
  định trước, giữ nguyên.
- Không thêm fuzzy-match (Levenshtein) cho kiểu gõ chữ.
- Không cho người dùng tự gắn cờ "từ khó" thủ công (khác với đề xuất đã
  chọn — chỉ suy ra tự động).
- Không thiết kế màn hình thống kê/xem lại `review_logs` (đã ghi nhận là
  gap từ trước, không nằm trong phạm vi task này).
- Không đổi cấu trúc `learned_words` cốt lõi (`ease_factor`,
  `interval_days`, `repetitions`, `due_date`) — chỉ bổ sung, không phá vỡ
  tương thích ngược với `SrsScheduler`.
- Không xử lý màn "kết quả cuối phiên" (summary) — mockup hiện chưa có,
  ghi nhận là UI gap, không tự thiết kế thêm ngoài yêu cầu.

## Acceptance Criteria

1. Phiên ôn tập không còn hiển thị 4 nút Quên/Khó/Tốt/Dễ — thay bằng câu
   hỏi trắc nghiệm hoặc câu hỏi gõ chữ, ngẫu nhiên xen kẽ theo từng từ.
2. Trả lời đúng/sai được hệ thống tự chấm ngay (không cần xác nhận thêm
   từ người dùng), tự động gọi `submitReview` với `quality` tương ứng
   (4 hoặc 1), cập nhật `learned_words` + ghi `review_logs` như cũ.
3. Trắc nghiệm hiện đúng 4 lựa chọn, 1 đúng + 3 nhiễu lấy từ cùng bộ từ
   điển (hoặc toàn bộ `words` nếu không đủ).
4. Gõ chữ chấm đúng khi chuỗi nhập (đã trim, lowercase) khớp tuyệt đối
   `word_lower`; mọi sai khác đều tính sai.
5. Từ có `ease_factor` thấp (gần sàn 1.3) hoặc vừa sai liên tiếp được ưu
   tiên xuất hiện sớm/thường xuyên hơn trong hàng đợi ôn tập — không cần
   cột dữ liệu mới, tính động từ dữ liệu SM-2 hiện có.
6. Không có regression: các từ đã học/lịch ôn hiện tại của người dùng vẫn
   tính đúng theo SM-2 sau khi đổi cơ chế chấm điểm.

# Existing UI Analysis

| Item | Current Status | File/Module | Notes |
| ---- | -------------- | ----------- | ----- |
| Màn hàng đợi ôn tập (`ReviewScreen`) | Đã code, hoạt động | `lib/features/review/review_screen.dart` | Không đổi — vẫn liệt kê `dueReviewsProvider`, chỉ cần đổi thứ tự ưu tiên hiển thị theo "từ khó" (AC5) |
| Phiên ôn — lật thẻ tự chấm | Đã code, **sẽ bị bỏ** | `lib/features/review/review_session_screen.dart` (125 dòng) | `_rate(ReviewRating)` + 4 `OutlinedButton` cần thay hoàn toàn bằng flow câu hỏi khách quan |
| Mockup trắc nghiệm | Có UI tĩnh, chưa có logic | `docs/artifact-design/screens/screen-07f-phien-on-tap-cau-trac-nghiem.html` | Card `audio-card` + nút phát âm + 4 `choice-row` (A/B/C/D), có sẵn CSS state `.correct`/`.wrong` |
| Mockup gõ chữ | Có UI tĩnh + CSS state, chưa có logic | `docs/artifact-design/screens/screen-07e-phien-on-tap-cau-go-chu.html` | Input text + nút submit; CSS đã định nghĩa `.type-input-row.correct/.wrong`, `.answer-reveal` nhưng **không có khung hình minh hoạ** trạng thái sau khi submit |
| Mockup lật thẻ (07d) | Có UI, **không dùng nữa** | `docs/artifact-design/screens/screen-07d-phien-on-tap-cau-lat-the.html` | Giữ lại làm tham khảo style card, nhưng luồng 4-nút-tự-chấm không áp dụng |
| Badge "kind-badge" phân biệt loại câu | Có trong cả 3 mockup | — | Cần giữ lại khái niệm này cho 2 kiểu còn dùng (trắc nghiệm/gõ chữ) để người dùng biết đang ở dạng nào |
| Màn kết quả cuối phiên | **Không tồn tại** ở cả code lẫn mockup | — | Hiện chỉ có `SnackBar` "Đã hoàn thành lượt ôn tập hôm nay!" khi pop |

# UI Gap Analysis

| Missing / Incomplete UI | Required For Task | Recommended Action | Risk |
| ----------------------- | ------------------ | ------------------- | ---- |
| Flow trắc nghiệm (chọn đáp án → feedback đúng/sai → tự next) | Có | Dựng theo mockup 07f: hiện 4 `choice-row`, chạm 1 đáp án → tô `.correct`/`.wrong` ngay, disable các lựa chọn còn lại, tự động next sau khoảng trễ ngắn | Thấp — mockup đã đủ chi tiết |
| Flow gõ chữ (nhập → submit → feedback → tự next) | Có | Dựng theo mockup 07e + CSS state có sẵn (`answer-reveal` khi sai hiện đáp án đúng); cần **tự thiết kế thêm** khung hình "đã submit" vì mockup chỉ có khung "đang gõ" | Trung bình — thiếu khung hình tham chiếu trực quan cho trạng thái kết quả |
| Badge/label phân biệt loại câu hỏi trong phiên trộn 2 kiểu | Có | Tái dùng `kind-badge` đã có, chỉ giữ 2 giá trị "Trắc nghiệm"/"Gõ chữ" | Thấp |
| UI/indicator "từ khó" (nếu muốn hiển thị cho người dùng biết) | Không bắt buộc (chỉ ảnh hưởng thứ tự nội bộ) | Không cần thêm UI mới nếu chỉ dùng để sắp xếp hàng đợi; cân nhắc thêm nhãn nhỏ kiểu "Từ khó" ở màn preview hàng đợi (`_DueQueue`) nếu muốn minh bạch với người dùng | Thấp — optional, nên hỏi lại nếu cần |
| Màn kết quả cuối phiên (tổng số đúng/sai) | Không có trong yêu cầu gốc nhưng tự nhiên phát sinh khi bỏ self-rating | Không tự thiết kế thêm — ghi nhận là **Open Question**, có thể để `SnackBar` cũ tạm đủ | Thấp — không chặn implement, có thể làm sau |

# Backend Gap Analysis

> Dự án không có backend/API riêng — layer tương ứng là **Domain/Data
> (Repository) + Local DB (Drift/sqflite)** trong chính app Flutter.

| Layer | Current Status | File/Module | Gap |
| ----- | --------------- | ----------- | --- |
| Domain — entity loại câu hỏi | Không tồn tại | `lib/domain/entities/review.dart` | Cần thêm enum kiểu `QuestionMode { multipleChoice, typing }` để tầng UI biết render dạng nào cho từng từ trong phiên |
| Domain — entity câu hỏi trắc nghiệm | Không tồn tại | — | Cần struct gộp `word` + `List<String> choices` (4 phần tử, biết vị trí đáp án đúng) |
| Domain — SM-2 scheduler | Đã có, **không cần đổi** | `lib/domain/srs/srs_scheduler.dart` | Input vẫn là `quality` 1/3/4/5 — chỉ nguồn sinh ra `quality` đổi, thuật toán giữ nguyên |
| Domain — logic "từ khó" | Không tồn tại | — | Cần hàm thuần Dart (không phụ thuộc DB) nhận `SrsCardState` (+ có thể thêm lịch sử gần nhất) → trả `bool isDifficult`, để dễ test độc lập giống `SrsScheduler` |
| Repository — lấy đáp án nhiễu | Không tồn tại | `lib/data/repositories/review_repository.dart` hoặc `VocabRepository` (tuỳ schema cũ/mới) | Cần hàm `randomDistractors(wordId, {dictionaryId}, count: 3)` — đã mô tả ở `91_DB-design-new-model.md`, chưa có trong code vì schema `dictionaries`/`word_dictionaries` **chưa migrate** (code hiện tại vẫn dùng `chapter_id` đơn ở `vocab.db` cũ) |
| Repository — so khớp gõ chữ | Không tồn tại | — | Không cần query DB riêng — so sánh string thuần Dart với `word.word` đã có sẵn trong `VocabWord`, không cần cột `word_lower` phía client (đã có ở DB nhưng so khớp có thể làm tại tầng domain) |
| Repository — truy vấn "từ khó" để sắp xếp hàng đợi | Không tồn tại | `dueToday()` (`review_repository.dart:89-104`) | Cần sửa để **sort** kết quả theo tiêu chí từ khó (ease_factor thấp/sai gần đây) thay vì chỉ `ORDER BY due_date ASC` — không phải thêm bảng, mà đổi logic sắp xếp/lọc |
| DB — cột phân biệt loại phiên ôn | Không tồn tại, **quyết định không thêm** | `lib/data/local/user_database.dart` bảng `review_logs` | Đã cân nhắc thêm cột `question_mode` nhưng **từ chối** (xem OQ-6) — chưa có màn hình nào đọc lại `review_logs`, thêm cột không ai dùng là dữ liệu chết. `QuestionMode` (enum Domain, không phải cột DB) vẫn cần để UI biết render đúng dạng câu hỏi trong phiên, chỉ không lưu xuống `review_logs` |
| DB — dữ liệu "từ khó" | Không có cột riêng (theo quyết định đã chọn: suy luận động) | — | Không cần migration mới nếu chỉ tính động từ `ease_factor`/`repetitions` hiện có trong `learned_words` |

# API Impact

> Không áp dụng theo nghĩa REST API — app không có backend riêng. Bảng
> dưới đây liệt kê tương đương: các **hàm Repository** đóng vai trò ranh
> giới giao tiếp giữa UI (feature layer) và Data (DB layer).

| Item | Value |
| ---- | ----- |
| Hàm hiện có tái sử dụng | `submitReview(wordId, rating)` — không đổi chữ ký, chỉ đổi nơi gọi và cách tính `rating` |
| Hàm mới cần thêm | `randomDistractors(wordId, count)`, `dueTodaySortedByDifficulty()` (hoặc sửa `dueToday()` hiện có để nhận thêm tham số sort) |
| "Request" tương đương | Tham số đầu vào các hàm trên: `wordId` (int), `count` (int, mặc định 3) |
| "Response" tương đương | `randomDistractors` → `List<String>` (nghĩa tiếng Việt của 3 từ nhiễu); `dueTodaySortedByDifficulty` → `List<DueReviewItem>` đã sắp xếp |
| Error case | Bộ từ điển không đủ từ để lấy 3 đáp án nhiễu khác nghĩa → fallback toàn bộ `words` (đã chốt); trùng lặp ngẫu nhiên đáp án nhiễu với đáp án đúng → cần loại trừ `word_id` hiện tại khỏi tập chọn nhiễu |
| Auth required | Không áp dụng — app local-only, không có khái niệm user/session đăng nhập |

# Risk Analysis

- [x] UI incomplete — thiếu khung hình mockup cho trạng thái "đã submit" của kiểu gõ chữ (chỉ có CSS, không có ảnh minh hoạ)
- [ ] API contract unclear — không áp dụng (không có API layer)
- [x] DB schema unclear — phụ thuộc vào việc task này chạy trên schema **hiện tại** (`chapter_id` đơn, `vocab.db`/`user.db` tách rời) hay đã chờ migrate sang schema mới ở `91_DB-design-new-model.md` (`dictionaries` N-N) — ảnh hưởng trực tiếp cách lấy đáp án nhiễu
- [ ] Permission rule unclear — không áp dụng
- [x] Existing flow may be affected — bỏ hẳn `ReviewRating`/4-nút tự chấm là thay đổi phá vỡ (breaking) với `review_session_screen.dart` hiện tại; cần xác nhận không còn chỗ nào khác trong app tham chiếu tới `ReviewRating.hard`/`.easy` theo nghĩa chủ quan
- [x] Manual verification required — cần verify thủ công: (1) trắc nghiệm không lặp đáp án đúng trong 3 đáp án nhiễu, (2) gõ chữ chấm đúng với input có khoảng trắng thừa/hoa thường lẫn lộn, (3) từ vừa trả lời sai có thực sự nổi lên sớm hơn trong lần mở hàng đợi tiếp theo

## Quyết định đã chốt (trước đây là Open Questions)

- **OQ-1 — Đã chốt**: Task này **đợi migrate xong** sang schema mới
  (`91_DB-design-new-model.md`, bảng `dictionaries`/`word_dictionaries`
  N-N) rồi mới implement. `randomDistractors` viết theo `dictionary_id`
  mới, không viết tạm theo `chapter_id` cũ.
- **OQ-2 — Đã chốt**: Ngưỡng "từ khó" = `ease_factor <= 1.5` (gần sàn
  1.3 của SM-2). Chỉ dùng 1 điều kiện này, không kết hợp thêm điều kiện
  "vừa sai ở lượt gần nhất" (đơn giản hoá so với đề xuất ban đầu).
- **OQ-3 — Đã chốt**: **Không** thêm logic sắp xếp/ưu tiên nào ngoài
  SM-2 chuẩn. "Nhắc lại thường xuyên hơn" hoàn toàn đến từ hành vi sẵn có
  của thuật toán: trả lời sai → `q=1` → `repetitions=0, interval=1 ngày`
  → từ tự nhiên xuất hiện lại ở hàng đợi **ngày mai** theo đúng
  `due_date`, không cần đổi thứ tự hiển thị trong hàng đợi cùng ngày.
  Nhãn "từ khó" (`ease_factor <= 1.5`, theo OQ-2) chỉ dùng để **hiển
  thị/thống kê**, không ảnh hưởng `ORDER BY` của `dueToday()`. Điều này
  nhất quán với quyết định trước đó ở `91_DB-design-new-model.md` (từ
  chối "phạt trùng" qua wrong-count) — không thêm tầng ưu tiên thứ hai
  chồng lên SM-2.
- **OQ-4 — Đã chốt**: Trộn ngẫu nhiên đều 50/50 giữa trắc nghiệm và gõ
  chữ (không lệch theo `ease_factor`). **Giới hạn quan trọng bổ sung**:
  1 phiên ôn tối đa **4 từ** — nếu hàng đợi hôm nay chỉ có 1 từ đến hạn,
  phiên chỉ gồm 1 từ (không độn thêm từ chưa đến hạn cho đủ 4). Đây là
  thay đổi so với hành vi hiện tại (`ReviewSessionScreen` nhận nguyên
  `List<DueReviewItem>` không giới hạn số lượng) — cần cắt còn tối đa 4
  phần tử trước khi vào phiên.
- **OQ-5 — Đã chốt**: **Có** thiết kế màn kết quả cuối phiên (thay cho
  `SnackBar` đơn giản hiện tại) — hiển thị tổng số câu đúng/sai trong
  phiên vừa hoàn thành. Chi tiết UI cụ thể để task-plan quyết định.
- **OQ-6 — Đã chốt lại (đảo ngược quyết định trước)**: **Không** thêm
  cột `review_logs.question_mode`. Lý do: hiện **chưa có màn hình nào
  đọc lại `review_logs`** (xác nhận ở `05_Review.md:65-66` — "dự phòng
  cho thống kê tương lai"), thêm cột mà không ai dùng là dữ liệu chết,
  vi phạm nguyên tắc "không thêm những gì chưa cần". Nếu sau này thực sự
  cần thống kê theo kiểu câu hỏi, thêm cột này khi đó (migration thêm
  cột mới không tốn kém, không cần làm trước).

---

## Ghi chú liên kết tài liệu

Task này **kế thừa trực tiếp** quyết định đã chốt ở
`docs/csb-vocab-analysis/91_DB-design-new-model.md` mục "Ôn tập bằng
trắc nghiệm" (mapping `q=4`/`q=1`, nguồn đáp án nhiễu theo bộ từ điển,
lý do không dùng wrong-count để tinh chỉnh quality). Điểm **mở rộng
thêm** so với tài liệu đó: (1) thêm kiểu gõ chữ song song trắc nghiệm
thay vì chỉ trắc nghiệm, (2) thêm cơ chế tự động phát hiện "từ khó" (chỉ
để hiển thị, không đổi lịch ôn) để gắn nhãn trong hàng đợi, (3) giới hạn
1 phiên tối đa 4 từ, (4) thêm màn kết quả cuối phiên. **Không** thêm cột
`review_logs.question_mode` (quyết định đảo ngược ở OQ-6 — chưa có màn
hình nào đọc lại `review_logs` nên không thêm cột chưa cần dùng). Toàn
bộ các điểm mở rộng này đã được xác nhận — xem mục "Quyết định đã chốt"
ở trên. Bước tiếp theo: cập nhật
`91_DB-design-new-model.md` + ghi `docs/spec_history.md`, sau đó chuyển
sang `task-brainstorm`/`task-plan`.
