# Implementation Plan — Trích xuất `TA_chuyen_nganh_2.pdf` vào bảng `words`

> Áp dụng skill `task-plan` — điều chỉnh format cho đúng bản chất công
> việc: đây là **data pipeline** (Extract → Review → Load), không phải
> tính năng có API/UI. Không có Backend/Frontend tách biệt như skill gốc
> giả định — thay vào đó chia theo giai đoạn pipeline. Không sửa code,
> không implement, chỉ lập kế hoạch.

# Requirement Summary

## Business Goal

Bổ sung dữ liệu từ vựng vào bảng `words` (thiết kế ở `91_DB-design-new-
model.md`) từ nguồn thứ 2: `docs/source-materials/TA_chuyen_nganh_2.pdf`
— "Sổ tay thuật ngữ chuyên ngành Việt–Anh cho tàu Hải quân" (211 trang,
6 chuyên ngành trùng khớp 6 bộ `dictionaries` đã seed).

> **Phạm vi nguồn dữ liệu**: `docs/source-materials/` có 3 nguồn tổng
> cộng — `TA_chuyen_nganh.docx` (đã dùng để chốt enum `part_of_speech`/
> `source`, xem `91_DB-design-new-model.md`), `TA_chuyen_nganh_2.pdf`
> (nguồn của **task này**), và `Tu_dien.pdf` (977 trang, xác nhận là
> **bản scan ảnh thuần, 0 ký tự trích được** qua cả `pdftotext` lẫn
> PyMuPDF — không có text layer). `Tu_dien.pdf` **không thuộc phạm vi
> task này** — cần OCR (Tesseract chưa cài trong môi trường hiện tại)
> với độ tin cậy thấp hơn nhiều so với đọc text layer có sẵn, nên tách
> thành 1 task riêng sau này khi quyết định làm.

## Nguồn dữ liệu — khác hẳn `TA_chuyen_nganh.docx` đã dùng trước

Đã khảo sát trực tiếp (trích mẫu bằng PyMuPDF, không phải giả định):

- **Hướng mục từ ngược lại**: đầu mục là **tiếng Việt**, tra ra thuật ngữ
  tiếng Anh (vd `an ninh hàng hải (dt.)` → `maritime security`) — khác
  `TA_chuyen_nganh.docx` (đầu mục tiếng Anh → nghĩa tiếng Việt).
- **1 đầu mục có thể nhiều thuật ngữ Anh tương đương**: vd `ác liệt (tt.)`
  → `fierce` **và** `violent` (2 dòng, phân tách bằng bullet `•` ẩn trong
  PDF).
- **Có câu ví dụ song ngữ** cho hầu hết mục từ (VN + EN) — khớp đúng bảng
  `examples` đã thiết kế sẵn.
- **Có từ phái sinh** đánh dấu bằng `~` (vd `~ chiến tranh: war hero`,
  `~ dân tộc: national hero`) — khớp đúng ý nghĩa cột `is_subentry` đã
  thiết kế sẵn.
- **Loại từ viết tắt riêng** của nguồn này (theo trang 4 — "HƯỚNG DẪN SỬ
  DỤNG" chính thức trong PDF): `dt.` danh từ, `đt.` động từ, `tt.` tính
  từ, `trt.` trạng từ, `cụm gt.` cụm giới từ — **khác** ký hiệu enum đã
  khảo sát từ `TA_chuyen_nganh.docx` (`n/v/a/adv/prep`), cần map riêng
  sang cùng 1 bộ mã số `part_of_speech` đã chốt.
- **Không có ranh giới mục từ rõ ràng trong text thuần**: PDF gốc dùng
  màu/font (xanh đậm cho thuật ngữ gốc, đen cho phiên âm...) để phân
  biệt — thông tin này **mất khi trích bằng `pdftotext`/`get_text()`
  dạng text thuần**, cần dùng thông tin font/màu ở tầng thấp hơn (xem
  Backend Gap Analysis) hoặc heuristic theo pattern chữ.

## Selected Approach

**Script trích xuất bán tự động + soát thủ công bắt buộc trước khi nạp
DB** (đã chốt qua AskUserQuestion, loại bỏ phương án tự động hoàn toàn
không soát — rủi ro sai sót lẫn câu ví dụ vào nghĩa, tách sai từ phái
sinh không phát hiện được nếu không có bước rà soát người).

Pipeline 3 giai đoạn:

```
[1. EXTRACT]  TA_chuyen_nganh_2.pdf
                  │  (script Python, PyMuPDF đọc font/màu để tách mục từ)
                  ▼
[2. REVIEW]   words_import.csv (trung gian, người rà soát/sửa tay trong Excel/Sheets)
                  │  (script Python, đọc CSV đã duyệt)
                  ▼
[3. LOAD]     INSERT vào words + examples (qua schema.sql/seed.sql hoặc thẳng vào DB thật)
```

## Scope

- Trích xuất đúng 6 nhóm chuyên ngành có trong PDF (Quân sự chung, Hàng
  hải, Thông tin ra đa, Vũ khí, Cơ điện, Cảnh sát biển) — map thẳng vào
  6 `dictionary_id` đã seed sẵn (`docs/db/seed.sql`), **không** tạo bộ
  từ điển mới.
- Đảo chiều mục từ: `words.word` = thuật ngữ tiếng Anh, `words.meaning_vi`
  = đầu mục tiếng Việt gốc (đã chốt).
- 1 đầu mục Việt có N thuật ngữ Anh tương đương → tách thành N dòng
  `words` riêng, mỗi dòng 1 `meaning_vi` giống nhau.
- Trích câu ví dụ song ngữ vào bảng `examples` (đã chốt).
- Trích từ phái sinh (`~`) thành dòng `words` riêng với `is_subentry=1`
  (đã chốt).
- Map loại từ viết tắt của nguồn này sang đúng enum `part_of_speech` đã
  chốt ở `91_DB-design-new-model.md`: `dt.`→`0` (danh từ), `đt.`→`1`
  (động từ), `tt.`→`2` (tính từ), `trt.`→`3` (trạng từ), `cụm gt.`→`4`
  (giới từ — đã chốt gộp chung "cụm giới từ" vào mã giới từ có sẵn,
  không thêm mã mới).
- `words.source = 0` (SEED) — cùng loại nguồn với giáo trình gốc, đóng
  gói sẵn lúc build, không phải do user thêm.
- CSV trung gian là **artifact bắt buộc phải tồn tại và được soát qua**
  trước khi có bước LOAD — không cho phép bỏ qua bước review.
- **Trích ảnh minh hoạ nhúng trực tiếp trong mục từ** (mở rộng scope
  trong lúc implement, khác Phụ lục 2 vốn là ảnh phóng to riêng — xem
  Out of Scope) vào `docs/db/import/data/*.png`, gán qua cột
  `words.image_path`. Quy tắc phân biệt ảnh minh hoạ thật với icon móc
  khoá lặp lại đầu mỗi mục từ: kích thước pixel — icon 42-47px (~967
  lần lặp trên 211 trang), ảnh minh hoạ thật ≥225px; dùng ngưỡng
  `IMAGE_MIN_SIZE_PX = 150` (cách xa cả 2 nhóm). Gán theo headword gần
  nhất phía trên ảnh (khớp mô tả chính thức ở PDF trang 4: "Hình ảnh
  được chèn ngay sau ví dụ, hoặc sau từ gốc"); nếu 1 đầu mục Việt có
  nhiều thuật ngữ Anh tương đương (vd "life vest"/"life jacket" cùng 1
  ảnh), toàn bộ nhóm được gán chung 1 file, đặt tên theo từ đầu tiên +
  `source_page` (vd `life_vest_p7.png` — thêm số trang để tránh trùng
  tên khi cùng 1 từ tiếng Anh xuất hiện ở 2 chuyên ngành khác nghĩa, đã
  phát hiện 4 trường hợp thật: `filter`, `bearing`, `indicator`...).

## Out of Scope

- Không xử lý Phụ lục 1 (khẩu lệnh trên tàu, trang 192-201) và Phụ lục 2
  (hình ảnh minh hoạ phóng to riêng, trang 202+) — không phải mục từ
  vựng chuẩn, không khớp cấu trúc bảng `words`, cần phân tích riêng nếu
  sau này cần.
- Không tự động hoá 100% không cần review — đã loại bỏ ở bước brainstorm
  ngầm (chỉ 1 lựa chọn khả thi được chọn qua AskUserQuestion).
- Không chạy `INSERT` trực tiếp vào DB thật của app (`user.db`/`vocab.db`
  hiện tại) — vì `91_DB-design-new-model.md` là thiết kế **chưa
  implement**, và OQ-1 (đã chốt ở task trước) yêu cầu đợi migrate xong
  schema mới. Giai đoạn LOAD trong plan này chỉ nạp vào **file `.sqlite`
  thử nghiệm** dựng từ `docs/db/schema.sql` để verify dữ liệu đúng —
  không phải nạp vào app thật.
- Không xử lý trùng lặp giữa nguồn này và nguồn `TA_chuyen_nganh.docx`
  cũ (khả năng cao có từ trùng, vd `Bộ Tư lệnh`/`Command` có thể đã có ở
  1 trong 6 chương giáo trình gốc) — ghi nhận là Open Question, cần
  quyết định chiến lược dedup trước khi chạy LOAD thật.

## Acceptance Criteria

1. Có script `extract_ta_chuyen_nganh_2.py` chạy được, đọc `TA_chuyen_nganh_2.pdf`, xuất
   ra `words_import.csv` với đầy đủ cột cần soát (xem API Contract bên
   dưới — ở đây là "Data Contract" thay cho API).
2. CSV trung gian có annotate rõ số trang nguồn (`source_page`) cho mỗi
   dòng, để người soát dễ đối chiếu ngược lại PDF khi nghi ngờ sai.
3. Người review đã ký xác nhận (đơn giản: đổi tên file thành
   `words_import.reviewed.csv` hoặc thêm cột `reviewed=1`) trước khi cho
   phép chạy bước LOAD.
4. Script `load.py` đọc CSV đã review, insert vào DB thử nghiệm dựng từ
   `docs/db/schema.sql`, đối chiếu số dòng insert khớp số dòng CSV.
5. Chạy thử toàn bộ pipeline trên 1 chuyên ngành nhỏ trước (đề xuất "Vũ
   khí", ít trang nhất theo mục lục: trang 123-142, ~19 trang) để verify
   pipeline đúng trước khi chạy full 211 trang.

# Data Contract (thay cho API Contract — không có API trong task này)

| Item | Value |
|---|---|
| Nguồn vào | `docs/source-materials/TA_chuyen_nganh_2.pdf` (đọc bằng PyMuPDF `fitz`, không dùng `pdftotext` vì mất encoding tiếng Việt — đã xác nhận qua test) |
| Artifact trung gian | `words_import.csv` — human-reviewable, KHÔNG insert thẳng vào DB |
| Cột CSV | `source_page` (int, số trang PDF gốc để đối chiếu) · `dictionary_name` (text, 1 trong 6 tên bộ đã seed) · `word` (text, thuật ngữ tiếng Anh) · `phonetic` (text, có thể rỗng) · `part_of_speech_raw` (text, mã gốc từ PDF: `dt./đt./tt./trt./cụm gt.`) · `meaning_vi` (text, đầu mục tiếng Việt) · `is_subentry` (0/1) · `example_en` (text, có thể rỗng) · `example_vi` (text, có thể rỗng) · `reviewed` (0/1, mặc định 0 — script LOAD từ chối chạy nếu còn dòng `reviewed=0`) |
| Đầu ra | DB thử nghiệm SQLite (dựng từ `docs/db/schema.sql` + `docs/db/seed.sql`) — **không phải** `user.db`/`vocab.db` thật của app |
| Validation khi LOAD | `dictionary_name` phải khớp đúng 1 trong 6 tên đã seed (case-sensitive) · `part_of_speech_raw` phải map được sang 1 mã 0-4 theo bảng đã chốt (`dt.→0, đt.→1, tt.→2, trt.→3, cụm gt.→4`) · `word`/`meaning_vi` không được rỗng |
| Lỗi nghiệp vụ | Dòng có `reviewed=0` → script LOAD dừng toàn bộ, in danh sách dòng chưa review, không insert phần nào (all-or-nothing cho từng lần chạy) |
| Lỗi dữ liệu | `dictionary_name` không khớp → skip dòng đó, ghi log riêng `load_errors.csv` để xử lý tiếp, không dừng cả batch |

# Subtask Breakdown

## Extract Subtasks (thay "Backend")

| Subtask ID | Title | Files/Modules | Description | Depends On | Risk |
|---|---|---|---|---|---|
| EXT-01 | Khảo sát ranh giới mục từ bằng font/màu | script khảo sát riêng, không lưu lại | Dùng `page.get_text("dict")` của PyMuPDF (trả về span kèm font/màu/size) thay vì `get_text()` thuần — xác định chính xác quy tắc: thuật ngữ gốc = span màu xanh đậm cỡ 14, phiên âm = span đen cỡ 12 theo sau ngay. Xuất báo cáo mẫu 20-30 mục từ để tự kiểm tra quy tắc đúng trước khi viết script chính thức | None | **Cao** — đây là bước quyết định độ chính xác toàn bộ pipeline; nếu heuristic sai, mọi CSV sau đó sai theo |
| EXT-02 | Viết script `extract_ta_chuyen_nganh_2.py` | file mới, `docs/db/import/extract_ta_chuyen_nganh_2.py` (đặt tên theo nguồn cụ thể — sẽ có thêm extractor riêng cho `Tu_dien.pdf` ở task OCR tương lai, xem `91_DB-design-new-model.md` mục Risks) | Parse toàn bộ 6 chuyên ngành (trang 6-191, bỏ phụ lục), áp dụng quy tắc đã xác định ở EXT-01, xử lý: tách nhiều thuật ngữ Anh cho 1 đầu mục Việt (bullet), tách từ phái sinh (`~`), gán `dictionary_name` theo tiêu đề chuyên ngành đang đọc (heading `QUÂN SỰ CHUNG`/`HÀNG HẢI`/...), gán `source_page` | EXT-01 | Trung bình — logic tách case phức tạp (VD trang 7 có 1 mục từ với 2 thuật ngữ Anh + 3 sub-entry cùng lúc) |
| EXT-03 | Map `part_of_speech_raw` → mã số enum | cùng file `extract_ta_chuyen_nganh_2.py`, hoặc file mapping riêng `pos_mapping.py` | Chuẩn hoá theo bảng đã chốt: `dt.→0` (danh từ), `đt.→1` (động từ), `tt.→2` (tính từ), `trt.→3` (trạng từ), `cụm gt.→4` (giới từ, gộp chung với "cụm giới từ") | EXT-02 | Thấp — mapping đã chốt đầy đủ, chỉ còn rủi ro nếu PDF có mã viết tắt khác chưa khảo sát hết (vd biến thể chính tả) |
| EXT-04 | Chạy thử trên 1 chuyên ngành nhỏ | — | Chạy `extract_ta_chuyen_nganh_2.py` chỉ cho "Vũ khí" (trang 123-142) — kiểm tra thủ công 100% output CSV của riêng chuyên ngành này trước khi chạy full, vì đây là bước rẻ nhất để phát hiện lỗi hệ thống trong heuristic trước khi tốn công chạy 211 trang | EXT-02, EXT-03 | Thấp |
| EXT-05 | Chạy full 6 chuyên ngành | — | Sau khi EXT-04 xác nhận ổn, chạy toàn bộ, xuất `words_import.csv` đầy đủ | EXT-04 | Thấp |

## Review Subtasks (thay "Frontend" — công việc thủ công của người, không phải code)

| Subtask ID | Title | Files/Modules | Description | Depends On | Risk |
|---|---|---|---|---|---|
| REV-01 | Soát toàn bộ CSV trung gian | `words_import.csv` (mở bằng Excel/Google Sheets) | Người rà soát đối chiếu từng dòng nghi ngờ với `source_page` (mở lại PDF trang đó) — tập trung vào: câu ví dụ có bị lẫn vào `meaning_vi` không, từ phái sinh có tách đúng không, `part_of_speech_raw` có map đúng không | EXT-05 | **Cao** — đây là bước tốn thời gian nhất (211 trang, ước lượng hàng nghìn mục từ), nhưng bắt buộc theo phương án đã chọn |
| REV-02 | Đánh dấu `reviewed=1` sau khi sửa xong | `words_import.csv` | Cập nhật cột `reviewed` — có thể làm theo từng chuyên ngành (6 lần review nhỏ thay vì 1 lần lớn) để giảm rủi ro mệt mỏi bỏ sót | REV-01 | Trung bình |

## Load Subtasks (thay "Integration")

| Subtask ID | Title | Files/Modules | Description | Depends On | Risk |
|---|---|---|---|---|---|
| LOAD-01 | Viết script `load.py` | file mới, `docs/db/import/load.py` | Đọc CSV đã review, dựng DB thử nghiệm từ `docs/db/schema.sql`+`seed.sql`, `INSERT` vào `words` + `word_dictionaries` (link với `dictionary_id` tương ứng) + `examples` (nếu có câu ví dụ) trong 1 transaction | REV-02, `docs/db/schema.sql` đã có sẵn | Thấp |
| LOAD-02 | Chạy LOAD trên DB thử nghiệm, verify | DB tạm `.sqlite` | Đối chiếu số dòng insert = số dòng CSV đã review; query thử vài từ ngẫu nhiên so với PDF gốc để xác nhận đúng | LOAD-01 | Thấp |
| LOAD-03 | Quyết định chiến lược dedup với nguồn cũ | — | **Chưa thực hiện trong task này** — chỉ ghi nhận: trước khi nạp vào DB thật của app (khác với DB thử nghiệm ở LOAD-02), cần xử lý khả năng trùng từ giữa 2 nguồn `.docx` và `.pdf` (xem Open Question) | LOAD-02 | Cao — chưa có quyết định |

# Recommended Execution Order

## Option A: Extract-first (khuyến nghị áp dụng ở đây, không phải Option A/B gốc của skill)

Lý do dùng Option A thay vì đánh giá song song 2 hướng như skill gốc: đây
là pipeline tuần tự có phụ thuộc cứng (không thể review khi chưa extract,
không thể load khi chưa review) — không có lựa chọn "làm trước cái nào"
như BE/FE độc lập.

Thứ tự bắt buộc:

1. EXT-01 (khảo sát heuristic — **làm trước tiên, đừng bỏ qua** dù có vẻ
   tốn thời gian, vì sai ở đây lan ra toàn bộ 211 trang)
2. EXT-02, EXT-03 (viết script)
3. EXT-04 (chạy thử nhỏ — **điểm dừng để quyết định tiếp tục hay sửa lại
   EXT-01**)
4. EXT-05 (chạy full)
5. REV-01, REV-02 (soát — có thể chia nhỏ theo 6 chuyên ngành, làm song
   song với LOAD-01 vì không phụ thuộc nhau)
6. LOAD-01, LOAD-02 (nạp thử nghiệm + verify)
7. LOAD-03 (quyết định dedup — before khi nạp vào DB thật của app, ngoài
   phạm vi task này)

## Recommended Option

Recommend: **Extract-first, dừng lại xác nhận sau EXT-04 trước khi chạy
full 211 trang.**

Reason:

- Chi phí sai ở bước EXT-01 (heuristic font/màu) rất cao nếu phát hiện
  muộn — 211 trang thủ công đối chiếu lại tốn nhiều công hơn nhiều so
  với dừng ở 19 trang mẫu để sửa script.
- REV-01/REV-02 (review thủ công) là bottleneck thời gian thật sự của
  toàn bộ task — không có cách rút ngắn an toàn, đã được xác nhận là
  đánh đổi chấp nhận được (chọn ở AskUserQuestion đầu tiên).

# User Decision Required

Trước khi bắt đầu, cần xác nhận:

```text
Chạy EXT-01 (khảo sát heuristic) trước — cần Bash/Python trong môi
trường hiện tại (đã xác nhận có PyMuPDF sẵn).
Sau khi có kết quả EXT-01, quay lại xác nhận cách tách mục từ trước khi
viết EXT-02/EXT-03.
```

# Manual Verification Plan

## Main Flow

- [ ] Chạy `extract_ta_chuyen_nganh_2.py` trên chuyên ngành "Vũ khí" (19 trang), mở CSV,
      đối chiếu 100% dòng với PDF gốc trang 123-142.
- [ ] Xác nhận số lượng mục từ trích ra hợp lý so với ước lượng thủ công
      (đếm nhanh số mục từ trên 2-3 trang mẫu × 19 trang).

## Data Verification (thay "UI/API Verification")

- [ ] Từ có nhiều thuật ngữ Anh tương đương (vd "ác liệt" → fierce +
      violent) tách đúng thành 2 dòng CSV riêng, cùng `meaning_vi`.
- [ ] Từ phái sinh (`~ chiến tranh`, `~ dân tộc`...) có `is_subentry=1`
      và `meaning_vi` ghép đúng cụm (vd "anh hùng chiến tranh").
- [ ] Câu ví dụ song ngữ vào đúng cột `example_en`/`example_vi`, không
      lẫn vào `meaning_vi`.
- [ ] `part_of_speech_raw` map đúng mã số — spot-check 10 dòng ngẫu
      nhiên đối chiếu bảng enum.

## Error / Edge Case

- [ ] Mục từ không có phiên âm (nếu có) → `phonetic` rỗng, không crash
      script.
- [ ] Mục từ không có câu ví dụ → `example_en`/`example_vi` rỗng, không
      tạo dòng `examples` rỗng khi LOAD.
- [ ] Chạy `load.py` với CSV còn dòng `reviewed=0` → script từ chối chạy,
      in rõ danh sách dòng chưa duyệt.

## Regression

- [ ] Sau LOAD vào DB thử nghiệm, `docs/db/seed.sql` (7 dòng
      `dictionaries`) vẫn nguyên vẹn, không bị ghi đè.
- [ ] Tổng số dòng `words` sau LOAD = số dòng cũ (nếu chạy nhiều lần) +
      số dòng mới từ CSV — không có insert trùng nếu chạy `load.py` 2
      lần trên cùng CSV (cần idempotency check).

# Risks / TODO

- **[Đã chốt]** `cụm gt.` (cụm giới từ) map chung vào mã `4=Giới từ`
  (prep) có sẵn — không thêm mã `5` mới. Áp dụng cho cả EXT-03 và Data
  Contract ở trên.
- **[Đã chốt]** `Tu_dien.pdf` (977 trang, scan ảnh thuần — xác nhận qua
  PyMuPDF: 0 ký tự trích được ở mọi trang test) **không thuộc phạm vi
  task này**. Cần OCR (Tesseract chưa cài trong môi trường — chỉ có
  `pytesseract`, là Python wrapper, cần cài binary Tesseract engine
  riêng trên Windows + gói ngôn ngữ `vie.traineddata`) với độ tin cậy
  thấp hơn nhiều so với đọc text layer có sẵn — tách thành 1 task riêng
  khi quyết định làm, không gộp vào pipeline này.
- **[Cần xác nhận]** Trùng lặp giữa 2 nguồn (`TA_chuyen_nganh.docx` cũ
  và `TA_chuyen_nganh_2.pdf` mới) — chưa có chiến lược dedup. Rủi ro:
  cùng 1 thuật ngữ tiếng Anh xuất hiện 2 lần với `dictionary_id` khác
  nhau hoặc giống nhau, gây trải nghiệm trùng lặp khi tra cứu.
- **Rủi ro kỹ thuật EXT-01**: heuristic dựa trên font/màu **giả định
  PDF được xuất nhất quán** (mọi thuật ngữ gốc đều đúng "màu xanh cỡ 14"
  như tài liệu tự mô tả ở trang 4) — nếu có sai lệch cục bộ (vd 1 trang
  bị lỗi format khi biên soạn gốc), heuristic có thể bỏ sót hoặc trích
  sai mà không báo lỗi rõ ràng. Giảm thiểu bằng EXT-04 (chạy thử nhỏ)
  nhưng không loại trừ hoàn toàn rủi ro ở các trang chưa kiểm tra mẫu.
- **Khối lượng REV-01 lớn**: 211 trang, nhiều mục từ/trang (trang 7 mẫu
  đã thấy ~5 mục từ chính) — ước lượng sơ bộ có thể lên tới hàng nghìn
  dòng CSV cần soát. Cân nhắc chia nhỏ theo 6 chuyên ngành, làm dần thay
  vì 1 lần.
- Không tự thêm ảnh minh hoạ (Phụ lục 2) — nằm ngoài scope, nhưng nếu
  sau này muốn làm, cần 1 task riêng phân tích cách PDF liên kết ảnh với
  mục từ (không có trong khảo sát hiện tại).
