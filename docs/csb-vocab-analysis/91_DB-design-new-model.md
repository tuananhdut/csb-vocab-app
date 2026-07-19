# 91 — Thiết kế DB cho định hướng mới (N-N bộ từ điển, Section/Chapter, Drift)

> Tài liệu thiết kế — **không phải code**. Mô tả schema cho định hướng mới
> đã chốt ở `00_Overview.md` (bộ từ điển N-N, Section/Chapter dạng bài báo,
> tra cứu Online) và các quyết định chốt ở `docs/spec_history.md`
> [IMPL-013] (Q-CSB-04/05/06), [IMPL-014] (1 DB duy nhất, bộ "Chưa phân
> loại"). Không thay thế `lib/data/local/vocab_database.dart`/
> `user_database.dart` hiện tại — đây là bản thiết kế để implement sau,
> theo Drift (đã chốt D3, [IMPL-007]).
>
> **Không bao gồm:** cấu trúc bảng nội dung bài học Chapter cụ thể (nội
> dung bài + vị trí từ trong bài) — phần này phụ thuộc quy trình `.docx` →
> dữ liệu có cấu trúc, đã chốt thực hiện ở **một bước riêng** (Q-CSB-07,
> xem `00_Overview.md`). Tài liệu này chỉ thiết kế khung bảng
> `sections`/`chapters` ở mức tối thiểu để Section/Chapter có thể tồn tại
> độc lập với việc nội dung bài đã có hay chưa.

## Nguyên tắc thiết kế

1. **Bỏ ranh giới `vocab.db` (read-only) / `user.db` (read-write)** —
   quyết định mới ([IMPL-014]): thiết kế lại thành **1 database duy nhất**,
   không phân biệt "đóng gói sẵn" vs "user tự tạo" ở tầng file SQLite nữa.
   Toàn bộ từ vựng (giáo trình gốc, tự thêm tay, tra online rồi lưu) nằm
   chung 1 bảng `words`; sự khác biệt "mặc định vs cá nhân" chỉ còn ở tầng
   **bộ từ điển** (`dictionaries.is_default`), không phải ở tầng file DB.
   Đơn giản hoá đáng kể so với thiết kế trước: không còn 2 loại bảng từ
   song song (`words` ở `vocab.db` + `custom_words` ở `user.db`), không còn
   vấn đề "N-N xuyên 2 file SQLite".
2. **Mọi từ luôn thuộc ít nhất 1 bộ từ điển** — quyết định mới
   ([IMPL-014]): nếu 1 từ được thêm vào hệ thống mà không gán bộ từ điển cụ
   thể nào (ví dụ tự nhập nhanh, hoặc lưu từ tra Online mà chưa chọn bộ),
   hệ thống **tự động gán vào 1 bộ mặc định đặc biệt "Chưa phân loại"**
   (`dictionaries.is_default = 1`, tạo sẵn 1 dòng cố định, không thể xoá) —
   thay vì để từ đó không thuộc bộ nào (tránh dữ liệu "mồ côi" khó truy
   vấn/hiển thị ở màn "Từ điển của tôi").
3. **Tra cứu (`search`) không phụ thuộc bộ từ điển** — quyết định mới
   ([IMPL-014]): `search(query)` luôn quét toàn bộ bảng `words` bất kể từ
   thuộc bộ nào (kể cả "Chưa phân loại"), giữ đúng hành vi hiện tại của
   FR-2 (tìm mọi từ có trong hệ thống). Bộ từ điển chỉ ảnh hưởng tới màn
   "Từ điển của tôi" (duyệt theo bộ), không ảnh hưởng phạm vi search.
4. **Dùng Drift** (đã chốt D3) — bảng dưới đây mô tả ở mức khái niệm
   (tên bảng, cột, kiểu, khoá) để chuyển thẳng sang định nghĩa Drift
   (`.drift` hoặc Dart table class) khi implement, không mô tả SQL thô.
5. **Không tự động cache kết quả tra cứu Online** (đã chốt Q-CSB-05) — chỉ
   có 1 đường ghi dữ liệu từ "Online" vào local: hành động rõ ràng
   "Thêm vào bộ" do user khởi xướng (nếu bấm "Thêm" mà không chọn bộ cụ thể
   → áp dụng nguyên tắc 2, gán vào "Chưa phân loại").

## Sơ đồ tổng quan quan hệ

```
words ──┬── word_dictionaries (N-N) ──── dictionaries
         │                                   │
         │                                   ├─ is_default=1: "Chưa phân loại" (cố định, không xoá)
         │                                   ├─ is_default=1: 6 bộ giáo trình gốc (Quân sự chung, Hàng hải...)
         │                                   └─ is_default=0: bộ cá nhân do user tạo (nhiều bộ)
         │
         ├── examples (1-N, giữ nguyên)
         └── learned_words (1-1, SM-2, giữ nguyên)

sections ── 1-N ── chapters ── N-N ── chapter_words ── words
(nội dung bài học, độc lập với khái niệm "bộ từ điển")
```

## Bảng `words` (hợp nhất — thay cho `words` + `custom_words` cũ)

| Cột | Kiểu | Ghi chú |
| --- | --- | --- |
| `id` | INTEGER PK | Namespace duy nhất cho mọi từ, không phân biệt nguồn gốc |
| `word` | TEXT | Lấy trực tiếp từ nguồn biên soạn (`docs/source-materials/TA_chuyen_nganh.docx`, mục `VOCABULARY` mỗi Unit) |
| `word_lower` | TEXT | Cột phụ trợ tìm kiếm không phân biệt hoa/thường (giữ như code hiện tại) — cột kỹ thuật, không phải field ngữ nghĩa từ nguồn |
| `phonetic` | TEXT NULL | Lấy trực tiếp từ nguồn biên soạn; có thể rỗng nếu nguồn không cung cấp (vd một số từ tự nhập tay) |
| `meaning_vi` | TEXT | Nghĩa tiếng Việt — lấy trực tiếp từ nguồn biên soạn; với từ nguồn Online, là kết quả đã qua LibreTranslate |
| `part_of_speech` | INTEGER NULL | Lấy trực tiếp từ nguồn biên soạn (mã `n`/`v`/`a`/`adv`/`prep` gốc), chuẩn hoá sang mã số cố định — xem bảng bên dưới. `NULL` = chưa xác định (khác với 1 mã cụ thể) |
| `is_subentry` | INTEGER (bool) | Giữ nguyên ý nghĩa cũ (cụm từ/biến thể liên quan 1 từ gốc) — cột kỹ thuật, không phải field ngữ nghĩa từ nguồn |
| `image_path` | TEXT NULL | Đường dẫn ảnh minh hoạ, giữ như code hiện tại (`vocab_repository.dart`) — cột kỹ thuật/UI, nguồn biên soạn `.docx` không có ảnh, ảnh được bổ sung riêng ngoài quy trình trích xuất từ vựng |
| `source` | INTEGER | Mã số nguồn gốc từ, giá trị cố định trong 1 enum nhỏ — xem bảng bên dưới. Không nullable (mọi từ đều phải có nguồn gốc rõ ràng) |
| `created_at` | INTEGER | Unix timestamp — với `source=SEED` là thời điểm build DB |

> Đã bỏ `meaning_en` (định nghĩa tiếng Anh) khỏi thiết kế trước — không có
> căn cứ từ nguồn biên soạn thật (`TA_chuyen_nganh.docx` chỉ có 4 field:
> từ, phiên âm, loại từ, nghĩa tiếng Việt; `Tu_dien.pdf` là bản scan ảnh,
> chỉ dùng đối chiếu thủ công lúc biên soạn, không trích xuất được field
> có cấu trúc). Nếu sau này cần nghĩa tiếng Anh (vd từ nguồn Online lookup
> qua Free Dictionary API), bổ sung lại cột này kèm lý do cụ thể.
>
> Không còn khái niệm "read-only" ở tầng bảng — từ `source=SEED` vẫn có
> thể coi là "không nên sửa/xoá qua UI thường" ở tầng ứng dụng (Repository
> có thể chặn edit/xoá dựa vào cột `source`), nhưng đây là ràng buộc logic
> nghiệp vụ, không phải ràng buộc vật lý 2 file DB như thiết kế trước.

### Enum `source`

3 giá trị cố định, không nullable — cùng pattern với `part_of_speech`
(INTEGER + mapping ở 1 enum Dart, không cần bảng lookup riêng):

| Mã | Tên gợi nhớ | Ghi chú |
| --- | --- | --- |
| `0` | `SEED` | Giáo trình gốc, đóng gói sẵn lúc build |
| `1` | `ONLINE_LOOKUP` | Tra Online rồi bấm "Thêm vào bộ" |
| `2` | `MANUAL` | User tự nhập tay, khớp mockup `screen-07b-tu-them-tu-moi.html` |

### Enum `part_of_speech`

Khảo sát trực tiếp nguồn `docs/source-materials/TA_chuyen_nganh.docx` (mục
`VOCABULARY` của từng Unit — dòng ngay sau phiên âm) cho thấy chỉ có **5
mã loại từ** viết tắt tiếng Anh được dùng xuyên suốt giáo trình, không tự
do như giả định trước đây. Chốt thành enum số cố định (INTEGER) thay vì
TEXT tự do — mapping mã ↔ nhãn giữ ở tầng Dart (không cần bảng lookup
riêng trong DB vì chỉ 5 giá trị, gần như không đổi theo thời gian):

| Mã (lưu trong cột) | Nhãn hiển thị (map ở tầng UI) | Ghi chú |
| --- | --- | --- |
| `0` | Danh từ | Phổ biến nhất trong nguồn |
| `1` | Động từ | |
| `2` | Tính từ | Nguồn dùng lẫn cả `a` và `adj` cho cùng nghĩa — chuẩn hoá về 1 mã duy nhất lúc biên soạn dữ liệu |
| `3` | Trạng từ | |
| `4` | Giới từ | Hiếm gặp, chỉ vài mục |
| `NULL` | (chưa xác định) | Khác với mã `0`–`4` — dùng khi chưa xác định được loại từ, không ép buộc chọn |

Việc chuẩn hoá (gộp `adj` → mã Tính từ) thực hiện ở bước biên soạn dữ
liệu từ nguồn `.docx`/`.pdf` sang `words`, không phải ở runtime. Nếu sau
này phát hiện thêm loại từ khác khi biên soạn tiếp các Unit còn lại, bổ
sung thêm dòng vào bảng này (mã tiếp theo `5`, `6`...) — không đổi kiểu
cột. Đề xuất định nghĩa 1 enum Dart duy nhất (`PartOfSpeech`) làm nguồn sự
thật cho mapping mã ↔ nhãn, dùng cả khi ghi dữ liệu (biên soạn) lẫn khi
đọc để hiển thị UI, tránh lệch giữa 2 chiều.

## Bảng `dictionaries` (bộ từ điển — mặc định + cá nhân, thay cho `chapters` cũ)

| Cột             | Kiểu          | Ghi chú                                                                                                                                               |
| ---------------- | -------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `id`           | INTEGER PK     |                                                                                                                                                        |
| `name`         | TEXT           | Vd: "Chưa phân loại", "Quân sự chung", "Hàng hải"..., hoặc tên do user tự đặt                                                              |
| `is_default`   | INTEGER (bool) | `1` = đóng gói sẵn/hệ thống tạo (6 bộ giáo trình gốc + 1 bộ "Chưa phân loại"), `0` = do user tự tạo                               |
| `is_deletable` | INTEGER (bool) | `0` riêng cho "Chưa phân loại" (không cho xoá — luôn cần nơi chứa từ mồ côi); các bộ mặc định khác và bộ cá nhân đều `1` |
| `sort_order`   | INTEGER        | Thứ tự hiển thị ở màn "Từ điển của tôi"                                                                                                     |
| `created_at`   | INTEGER        |                                                                                                                                                        |

Dữ liệu khởi tạo cố định: 1 dòng "Chưa phân loại" (`is_default=1`,
`is_deletable=0`) + 6 dòng giáo trình gốc (`is_default=1`, `is_deletable=1`
— về mặt kỹ thuật cho phép xoá nếu sau này cần, nhưng UI có thể vẫn chặn
xoá bộ giáo trình gốc bằng validation riêng, không bắt buộc dùng
`is_deletable` cho việc đó).

## Bảng `word_dictionaries` (N-N, thay cho cột `chapter_id` đơn cũ)

| Cột              | Kiểu                              | Ghi chú                                    |
| ----------------- | ---------------------------------- | ------------------------------------------- |
| `word_id`       | INTEGER FK →`words.id`          |                                             |
| `dictionary_id` | INTEGER FK →`dictionaries.id`   |                                             |
| `added_at`      | INTEGER                            | Thời điểm từ được gán vào bộ này |
| —                | PK(`word_id`, `dictionary_id`) | Composite key                               |

**Ràng buộc nghiệp vụ quan trọng** (áp dụng nguyên tắc thiết kế #2): mọi
`word_id` **luôn phải có ít nhất 1 dòng** trong bảng này. Khi insert 1 từ
mới (`source=MANUAL` hoặc `source=ONLINE_LOOKUP`) mà không chỉ định
bộ cụ thể, tầng Repository **tự động insert thêm 1 dòng**
`(word_id, dictionary_id=<id của "Chưa phân loại">)` trong cùng transaction
— đảm bảo không bao giờ tồn tại từ "mồ côi" (0 bộ). Với 6 chương giáo
trình gốc hiện tại: mỗi từ migrate từ `chapter_id` cũ → 1 dòng tương ứng
(không rơi vào "Chưa phân loại" vì đã có bộ rõ ràng).

## Bảng `sections` / `chapters` / `chapter_words` (nội dung bài học — không đổi so với thiết kế trước)

### `sections`

| Cột           | Kiểu      | Ghi chú                      |
| -------------- | ---------- | ----------------------------- |
| `id`         | INTEGER PK |                               |
| `name`       | TEXT       | Tên Section (chủ đề lớn) |
| `sort_order` | INTEGER    |                               |

### `chapters` (định nghĩa lại — là 1 bài học, không phải nhóm từ)

| Cột | Kiểu | Ghi chú |
| --- | --- | --- |
| `id` | INTEGER PK | |
| `section_id` | INTEGER FK → `sections.id` | |
| `title` | TEXT | Tiêu đề bài học |
| `sort_order` | INTEGER | Thứ tự bài trong Section |
| `content` | TEXT | Nội dung bài đọc dạng **văn bản có cấu trúc** (Markdown/HTML rút gọn), không phải file PDF/DOCX gốc nhúng nguyên trạng — cấu trúc chi tiết và cú pháp đánh dấu highlight từ vựng trong bài chốt ở bước xử lý `.docx` riêng (Q-CSB-07); cột này là placeholder tối thiểu |

### `chapter_words` (liên kết Chapter ↔ từ xuất hiện trong bài)

| Cột           | Kiểu                           | Ghi chú                                                                                      |
| -------------- | ------------------------------- | --------------------------------------------------------------------------------------------- |
| `chapter_id` | INTEGER FK →`chapters.id`    |                                                                                               |
| `word_id`    | INTEGER FK →`words.id`       | Nay trỏ thẳng vào bảng`words` hợp nhất, không còn phân vân "vocab.db hay user.db" |
| —             | PK(`chapter_id`, `word_id`) |                                                                                               |

Quyết định tách bảng riêng (thay vì parse `content` lúc hiển thị) không
đổi so với thiết kế trước — lý do hiệu năng truy vấn, xem lại nếu cần.

## Ảnh hưởng tới tầng Repository/Provider

- **1 Repository/database instance duy nhất** thay cho
  `VocabRepository` (đọc `vocab.db`) + tách riêng cho `user.db` như trước
  — vì nay chỉ còn 1 file DB, không cần 2 tầng song song rồi ghép kết quả.
- `chapters()`/`wordsByChapter()` (mô hình cũ) → thay bằng
  `dictionaries()`/`wordsByDictionary(dictionaryId)` (đọc `dictionaries` +
  `word_dictionaries`), bao gồm cả bộ "Chưa phân loại" như 1 bộ bình
  thường trong danh sách trả về.
- `search(query)` **không đổi phạm vi** — vẫn quét toàn bộ `words` như
  code hiện tại, không JOIN thêm `word_dictionaries` để lọc (đúng nguyên
  tắc thiết kế #3). Có thể JOIN thêm chỉ để **hiển thị** tên bộ (nếu cần),
  không phải để lọc kết quả.
- Thêm `SectionRepository`/`ChapterRepository` (đọc `sections`, `chapters`,
  `chapter_words`) — độc lập với repository từ vựng.
- Thêm `DictionaryApiRepository` (gọi Free Dictionary API) +
  `TranslationService` (gọi LibreTranslate) — xem `02_Search.md` mục
  Online. Khi user bấm "Thêm vào bộ" với từ tra Online: insert 1 dòng vào
  `words` (`source=ONLINE_LOOKUP`) + 1 dòng `word_dictionaries` (bộ đã
  chọn, hoặc "Chưa phân loại" nếu không chọn) trong cùng transaction.

## Migration dữ liệu ban đầu (tóm tắt, chi tiết để lúc implement)

1. Gộp `vocab.db.words` + toàn bộ dữ liệu `user.db` liên quan từ vựng vào 1
   file DB mới, bảng `words` hợp nhất — thêm cột `source` (mặc định
   `SEED` cho dữ liệu từ `vocab.db` cũ).
2. Tạo bảng `dictionaries`: 1 dòng "Chưa phân loại" (`is_deletable=0`) + 6
   dòng từ `chapters` cũ (đổi tên bảng, giữ nguyên tên 6 chương).
3. Tạo bảng `word_dictionaries`: mỗi từ có `chapter_id=X` cũ → 1 dòng
   `(word_id, dictionary_id=X)`. Từ nào (nếu có) không có `chapter_id` cũ
   → gán vào "Chưa phân loại".
4. Tạo bảng `sections`, `chapters` (mới), `chapter_words` — rỗng cho tới
   khi có dữ liệu từ bước xử lý `.docx` riêng (Q-CSB-07).
5. `learned_words` (giữ nguyên) trỏ `word_id` sang bảng `words` hợp nhất
   mới — không đổi cấu trúc bảng này, chỉ đổi namespace `word_id` tham
   chiếu tới (nay là 1 nguồn thay vì tiềm ẩn 2 nguồn). Không còn
   `review_logs`/`search_history` trong migration này — xem mục "Bỏ hẳn
   bảng `review_logs`/`search_history`" bên dưới.

## Ôn tập khách quan: trắc nghiệm + gõ chữ (thay hẳn tự đánh giá chủ quan)

> Đã mở rộng so với bản trước (chỉ có trắc nghiệm) theo
> `docs/csb-vocab-analysis/tasks/02-review-multi-mode/01-analysis.md` —
> xem `spec_history.md` [IMPL-015] cho lịch sử quyết định đầy đủ.

**Thay thế hoàn toàn** cách chấm điểm hiện tại của `review_repository.dart`
(người dùng tự bấm 1 trong 4 nút "Quên/Khó/Tốt/Dễ" sau khi lật thẻ — chủ
quan, phụ thuộc cảm nhận) bằng chấm điểm **khách quan tự động** dựa trên
kết quả trả lời thật, gồm **2 kiểu câu hỏi trộn ngẫu nhiên đều 50/50**
trong 1 phiên (không còn giữ kiểu lật thẻ tự chấm):

1. **Trắc nghiệm** — hiện từ tiếng Anh, chọn 1 trong 4 đáp án nghĩa tiếng
   Việt (khớp mockup `screen-07f-phien-on-tap-cau-trac-nghiem.html`).
2. **Gõ chữ** — hiện nghĩa tiếng Việt, gõ lại từ tiếng Anh, hệ thống tự so
   khớp chuỗi (khớp mockup `screen-07e-phien-on-tap-cau-go-chu.html`).
   So khớp: `input.trim().toLowerCase() == word.word_lower` — khớp tuyệt
   đối sau chuẩn hoá, không fuzzy-match (sai 1 ký tự vẫn tính sai).

**Giới hạn số từ/phiên**: 1 phiên ôn tối đa **4 từ**. Nếu hàng đợi hôm
nay chỉ có ít hơn 4 từ đến hạn (vd 1 từ), phiên chỉ gồm đúng số từ đó —
không độn thêm từ chưa đến hạn cho đủ 4.

**Không đổi schema cốt lõi `learned_words`/thuật toán `SrsScheduler`
(SM-2)** — chỉ đổi **nguồn sinh ra `quality` (0–5)** đưa vào
`submitReview()`: từ "người dùng tự chọn" sang "hệ thống tự map theo
đúng/sai", áp dụng chung cho cả 2 kiểu câu hỏi. Lý do giữ nguyên SM-2
thay vì thiết kế thang điểm riêng (đã khảo sát SuperMemo SM-2 gốc, Anki,
FSRS, Leitner, Duolingo Half-Life Regression trước khi chốt):

| Kết quả trả lời (trắc nghiệm hoặc gõ chữ) | `quality` (q) map vào `SrsScheduler.review()` | Vì sao |
| --- | --- | --- |
| Đúng | `4` (tương đương mức "Tốt" cũ) | Không có căn cứ để tự nhận "rất dễ" (q=5) chỉ từ 1 lượt đúng — không đo thời gian phản hồi nên không phân biệt được "nhớ ngay" hay "may mắn đoán trúng" |
| Sai | `1` (tương đương mức "Quên" cũ) | Dưới ngưỡng `q<3` của SM-2 → tự động `repetitions=0`, `interval=1` ngày (mai ôn lại) |

**Không dùng thêm "số lần từng sai trước đó" để tinh chỉnh `quality`**,
và **không thêm bất kỳ tầng ưu tiên/sắp xếp nào khác** cho từ vừa trả lời
sai — bản thân công thức SM-2 hiện có **đã** đảm bảo "từ sai nhiều thì ôn
thường xuyên hơn" thông qua `ease_factor` (giảm dần mỗi lần sai, có sàn
`1.3`, không reset) và `repetitions` (reset về 0 mỗi lần sai, kéo
`interval` về 1 ngày). Từ sai hôm nay tự nhiên quay lại hàng đợi **ngày
mai** theo đúng `due_date` — không cần đổi thứ tự hiển thị trong hàng đợi
cùng ngày. Lý do không thêm tầng điều chỉnh thứ hai: sẽ phạt trùng 2 lần
cho cùng 1 sự kiện "từng sai" — không có tiền lệ trong tài liệu gốc
SuperMemo, Anki, hay FSRS.

### Nhãn "từ khó" (chỉ hiển thị, không đổi lịch ôn)

Bổ sung khái niệm **"từ khó"** — suy luận **hoàn toàn tự động** từ dữ
liệu SM-2 sẵn có, không cần người dùng thao tác gắn cờ thủ công, không
thêm cột dữ liệu mới:

```sql
is_difficult = (learned_words.ease_factor <= 1.5)
```

Ngưỡng `1.5` chọn vì gần sàn cứng `1.3` của công thức SM-2 (`ease_factor`
không bao giờ xuống dưới 1.3) — từ có `ease_factor` trong khoảng này đã
bị đánh giá "khó nhớ" qua nhiều lượt sai tích luỹ. Đây **chỉ là nhãn hiển
thị/thống kê** (vd chấm nhỏ ở màn hàng đợi, hoặc lọc "Từ khó" ở màn Từ
điển của tôi) — **không** ảnh hưởng tới `ORDER BY` của `dueToday()` hay
bất kỳ logic chọn từ nào vào hàng đợi/phiên ôn, giữ đúng nguyên tắc "không
thêm tầng ưu tiên chồng lên SM-2" ở trên.

**Đáp án nhiễu** (3 đáp án sai trong 4 lựa chọn, riêng kiểu trắc
nghiệm): lấy ngẫu nhiên `meaning_vi` của các từ khác **cùng
`dictionary_id`** với từ đang hỏi (qua `word_dictionaries`) — khớp định
hướng ban đầu ở mockup ("mượn từ cùng chương gốc"), nay chuyển sang khái
niệm bộ từ điển N-N. Nếu bộ đó không đủ từ để lấy 3 đáp án nhiễu khác
nghĩa, fallback lấy ngẫu nhiên từ toàn bộ bảng `words`. **Loại trừ**
`word_id` của từ đang hỏi khỏi tập chọn nhiễu để tránh trùng đáp án đúng.

### Bỏ hẳn bảng `review_logs`/`search_history`

Quyết định mới (mở rộng thêm so với lần chốt trước — trước đây chỉ từ
chối thêm cột `question_mode`, nay đi xa hơn: bỏ **toàn bộ 2 bảng**):
cả `review_logs` và `search_history` **không còn trong thiết kế**.

- `review_logs`: rà lại code hiện tại (`review_repository.dart`) xác
  nhận bảng này **chỉ được `INSERT`, không có bất kỳ `SELECT` nào đọc
  lại** — không có màn hình, provider, hay thống kê nào từng dùng tới
  dữ liệu này kể từ khi tạo ra, dù đã tồn tại qua nhiều vòng phát triển.
- `search_history`: tình trạng còn rõ hơn — không có cả `INSERT` lẫn
  `SELECT` nào trong toàn bộ code. `02_Search.md` đã ghi nhận đây là gap
  từ trước ("chưa được đọc/ghi ở bất kỳ đâu"), và không mockup nào (kể
  cả `screen-02-tra-cuu.html`) thiết kế UI "lịch sử tra cứu" đi kèm.

Giữ 1 bảng chỉ-ghi-không-ai-đọc (hoặc không-ghi-không-đọc) là dữ liệu
chết, đúng nguyên tắc "không thêm/giữ những gì chưa cần" đã áp dụng
trước đó cho cột `question_mode`.

Phân biệt rõ với `learned_words` (**không** bỏ): đó là bảng lưu **trạng
thái hiện tại** của SM-2, được đọc liên tục để tính hàng đợi ôn tập
(`dueToday()`) — khác bản chất với `review_logs`/`search_history` vốn
chỉ là **audit trail lịch sử** (log theo thời gian) mà chưa từng có nhu
cầu thống kê/hiển thị thật sự đi kèm.

**Hệ quả**: `submitReview(wordId, quality)` chỉ còn `UPDATE
learned_words`, bỏ câu `INSERT INTO review_logs` đang có trong
`review_repository.dart`. Nếu sau này thực sự cần audit trail ôn tập
hoặc tính năng "lịch sử tra cứu gần đây", tạo lại bảng tương ứng khi đó
— không có cách "khôi phục" dữ liệu lịch sử đã bỏ qua giai đoạn không
ghi, nhưng chi phí tạo lại bảng (1 migration) không đáng kể so với việc
duy trì 1-2 bảng không ai dùng trong suốt thời gian chờ.

Kiểu câu hỏi (trắc nghiệm/gõ chữ) vẫn cần biết ở **tầng runtime** (để UI
render đúng dạng câu hỏi trong phiên) — nhưng đó là 1 enum ở tầng Domain
Dart thuần tuý (`QuestionMode`), không phải cột lưu trữ trong DB (điểm
này không đổi so với quyết định trước).

### Màn kết quả cuối phiên

Thay `SnackBar` "Đã hoàn thành lượt ôn tập hôm nay!" hiện tại bằng 1 màn
hình tổng kết: tổng số câu đúng/sai trong phiên vừa hoàn thành (tối đa 4
câu, theo giới hạn số từ/phiên ở trên). Chi tiết UI cụ thể (bố cục, có
hiện lại danh sách từ sai không...) để quyết định ở bước task-plan, không
thuộc phạm vi tài liệu thiết kế DB.

**Việc cần làm khi implement** (ngoài phạm vi tài liệu thiết kế DB
thuần tuý, ghi chú lại để không quên):

- Sửa `review_repository.dart`/`review_session_screen.dart`: bỏ hẳn 4 nút
  tự đánh giá, thay bằng flow trộn ngẫu nhiên trắc nghiệm/gõ chữ (50/50)
  → chọn đáp án hoặc gõ chữ → tự gọi
  `submitReview(wordId, quality: đúng ? 4 : 1)` (chữ ký không đổi). Trong
  `submitReview()`, bỏ câu `INSERT INTO review_logs` hiện có — chỉ còn
  `UPDATE learned_words`.
- Giới hạn `dueToday()` (hoặc nơi khởi tạo phiên) lấy tối đa 4 phần tử.
- Thêm hàm lấy đáp án nhiễu (`randomDistractors(wordId, dictionaryId,
  count: 3)`) ở repository tương ứng theo schema mới — **chỉ implement
  sau khi đã migrate xong sang schema `dictionaries`/`word_dictionaries`
  N-N** (không viết tạm theo `chapter_id` cũ).
- Thêm hàm/computed field `isDifficult` (thuần Dart, không phụ thuộc DB,
  cùng phong cách với `SrsScheduler` để dễ test độc lập) nhận
  `SrsCardState` → trả `ease_factor <= 1.5`.
- Thêm màn kết quả cuối phiên (mới), thay cho `SnackBar` hiện tại.

## Câu hỏi còn mở liên quan tới thiết kế này

| #        | Câu hỏi                                                                                                                                                                                                                                                | Ghi chú                                                                                                                                                                                                                                                |
| -------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Q-CSB-02 | Mockup "Từ điển của tôi" (7 màn`screen-07*`) có chốt triển khai đúng như thiết kế không?                                                                                                                                                | Thiết kế bảng ở trên đã giả định**có** triển khai — cần xác nhận lại 1 lần trước khi bắt đầu code                                                                                                                          |
| —       | Xoá 1 từ khỏi 1 bộ cá nhân — có tự động chuyển về "Chưa phân loại" nếu đó là bộ duy nhất chứa từ đó không, hay xoá thẳng cả`words`?                                                                                      | Áp dụng nguyên tắc#2 (không mồ côi) gợi ý: **chuyển về "Chưa phân loại"** thay vì xoá dữ liệu từ, trừ khi user chủ động chọn "Xoá từ" (khác với "Bỏ khỏi bộ") — cần xác nhận lại UX cụ thể trước khi code |
| —       | 1 file DB duy nhất có còn cần tách "đóng gói sẵn lúc build" (giống cơ chế copy asset của`vocab.db` cũ) khỏi phần user ghi thêm không, hay toàn bộ đều tạo/ghi runtime từ đầu (seed data insert lúc khởi tạo lần đầu)? | Ảnh hưởng cơ chế cập nhật app sau này (đổi/thêm từ giáo trình gốc mà không mất dữ liệu user) — chưa chốt, nên bàn kỹ trước khi implement                                                                                    |
