# Task Analysis — Seed dữ liệu bài đọc (`sections`/`chapters`) từ `TA_chuyen_nganh.docx`

> Áp dụng skill `task-analysis` — điều chỉnh format cho đúng bản chất công
> việc, giống điều chỉnh đã áp dụng ở task `03-import-tu-dien-hai-quan`:
> đây là **data pipeline** (Extract → Review → Load), không phải tính
> năng có API/UI. "Backend Gap Analysis" → "Data Gap Analysis", "API
> Contract" → "Data Contract". Không sửa code, không implement, chỉ phân
> tích.

# Requirement Summary

## Business Goal

Bổ sung dữ liệu "bài đọc" (đúng nghĩa tài liệu học, không phải mục từ
vựng đơn lẻ) vào 2 bảng `sections`/`chapters` (đã thiết kế sẵn ở
`docs/db/schema.sql`) từ nguồn `docs/source-materials/TA_chuyen_nganh.docx`,
để sau này mục "Học" trong app có thể hiển thị nội dung dạng bài báo
(mockup `docs/artifact-design/screens/screen-03c-hoc-noi-dung-bai.html`).

Đây là **phase 1** của tính năng lớn hơn (article view). Phạm vi đã chốt
qua brainstorm trước: **chỉ seed `sections` + `chapters` + `content` dạng
Markdown thô, không đụng `words`/`chapter_words`/highlight từ vựng** —
việc đó để dành phase sau.

## Scope

- Trích toàn bộ nội dung của **14 UNIT thật** trong docx. Cấu trúc thật
  (đã xác nhận trực tiếp bằng cách đọc `word/document.xml` qua
  `zipfile` + regex, không phải giả định) là **2 CHAPTER cha**:
  - "CHAPTER I: GENERAL MILITARY ENGLISH" — chứa Unit 1-3 (Vietnam
    People's Army, Uniforms, Vietnam Coast Guard).
  - "CHAPTER II: SPECIALIZED ENGLISH FOR THE VIETNAM COAST GUARD" —
    chứa Unit 1-11 (đánh số **lặp lại độc lập**, không nối tiếp Chapter
    I: Stipulating the Law..., Maritime, Profession of the VCG, Patrol
    Inspection and Control, Crime Fighting and Prevention, Communication
    on the VCG Ship, Command of the VCG Ships, Daily Life on the VCG
    Ship, International Relations, The Search and Rescue System, Initial
    Response and Search Planning).
- Map 2 CHAPTER cha trong docx → 2 dòng `sections` (khớp quyết định đã
  chốt: "2 sections cố định").
- Map mỗi UNIT con → 1 dòng `chapters` (`section_id` tương ứng,
  `sort_order` = số UNIT trong section đó, `title` = tên UNIT).
- `content` mỗi chapter = **toàn bộ nội dung UNIT gộp thành 1 khối
  Markdown thô** (I. INTRODUCTION + II. TEXT + III. GRAMMAR +
  IV. VOCABULARY + Exercise, giữ nguyên thứ tự xuất hiện trong docx) —
  đã chốt ở brainstorm trước (Option 1 — Minimal Safe).
- Script extract mới: `docs/db/import/extract_ta_chuyen_nganh_docx.py`
  (đặt tên riêng theo nguồn, nhất quán với
  `extract_ta_chuyen_nganh_2.py` đã có cho nguồn PDF).
- Mở rộng `docs/db/import/load.py` đã có: thêm hàm `load_chapters()`
  cạnh `seed_dictionaries_from_csv()`.
- CSV trung gian để soát tay trước khi load (nhất quán nguyên tắc
  "review bắt buộc trước LOAD" đã áp dụng ở task 03).
- Load vào DB thử nghiệm (file `.sqlite` dựng từ `docs/db/schema.sql`,
  **không phải** `user.db`/`vocab.db` thật — nhất quán ràng buộc đã
  chốt ở task 03).

## Out of Scope

- Bảng `words`, `chapter_words`, highlight từ vựng trong bài đọc — đã
  chốt rõ với user, để dành phase sau.
- Phần `APPENDIX` (APPENDIX 1: Organization..., APPENDIX 2: Ranks...,
  APPENDIX 3: Uniforms...) và `PREFACE`/`REFERENCE` ở cuối file — không
  thuộc cấu trúc UNIT chuẩn, không đưa vào `content`.
- Trích ảnh nhúng trong docx (docx có ảnh trong phần TEXT, theo khảo sát
  trước ở brainstorm) — bỏ qua ở phase này, chỉ lấy text thuần.
- Chuẩn hoá bảng GRAMMAR/VOCABULARY thành Markdown table chuẩn hoá kỹ
  (`|---|---|`, parse `<w:tbl>`) — đã quyết định dùng Markdown thô đơn
  giản, không đầu tư parse bảng phức tạp ở phase này.
- Implement UI `ArticleScreen`/renderer — phase này chỉ là data, dừng ở
  `chapters.content` có dữ liệu đúng trong DB thử nghiệm.
- Insert vào DB thật của app (`user.db`/`vocab.db`).

## Acceptance Criteria

1. Có script `extract_ta_chuyen_nganh_docx.py` chạy được, đọc
   `TA_chuyen_nganh.docx`, xuất ra `chapters_import.csv` với cột:
   `section_name`, `chapter_title`, `sort_order`, `content_md`,
   `reviewed`.
2. CSV có đúng 14 dòng (2 CHAPTER cha × tổng 3+11 UNIT con), không lẫn
   nội dung UNIT khác, không lẫn APPENDIX/PREFACE.
3. Nội dung `content_md` mỗi dòng bắt đầu đúng từ đầu UNIT (heading
   `I. INTRODUCTION` — riêng Unit 9 của Chapter II lệch, dùng
   `A. FOREIGN RELATIONS...` thay vì `I. INTRODUCTION`, cần heuristic dự
   phòng) đến hết phần Exercise của UNIT đó, không tràn sang UNIT kế
   tiếp.
4. Người review xác nhận `reviewed=1` cho toàn bộ 14 dòng trước khi cho
   phép chạy LOAD (soát nhanh, không cần soát từng câu như task 03 — chỉ
   cần đúng ranh giới UNIT, không lẫn unit khác).
5. `load.py` (mở rộng) đọc CSV đã review, tạo 2 dòng `sections` + 14
   dòng `chapters` vào DB thử nghiệm, đối chiếu số dòng insert khớp CSV.

# Existing UI Analysis

| Item | Current Status | File/Module | Notes |
| ---- | -------------- | ----------- | ----- |
| Mục "Học" hiện tại | Đã tồn tại nhưng chỉ list phẳng chương→từ, không có khái niệm bài đọc | `lib/features/lessons/lessons_screen.dart` (`LessonsScreen`) | Không bị ảnh hưởng ở phase này — phase này chỉ seed data, không sửa UI |
| Mockup bài báo | Đã có, chưa implement | `docs/artifact-design/screens/screen-03c-hoc-noi-dung-bai.html` | Tham chiếu cho phase UI sau, không dùng ở phase này |
| Pipeline extract-review-load | Đã có tiền lệ, dùng cho nguồn PDF khác | `docs/db/import/extract_ta_chuyen_nganh_2.py`, `load.py`, `review.sqlite` | Tái dùng pattern, mở rộng `load.py` thay vì viết script load mới hoàn toàn |

Đây là **data pipeline task** (không có UI/API theo nghĩa web app), nên
mục "UI Gap Analysis"/"API Impact" của template gốc không áp dụng nguyên
văn — điều chỉnh thành "Data Gap Analysis"/"Data Contract" cho đúng bản
chất công việc, đã có tiền lệ ở `03-plan.md`.

# Data Gap Analysis (thay "Backend Gap Analysis" — không có backend/server ở đây)

| Layer | Current Status | File/Module | Gap |
| ----- | -------------- | ----------- | --- |
| Schema DB | Đã có sẵn, đúng thiết kế cần dùng | `docs/db/schema.sql` (bảng `sections`, `chapters`, dòng 116-130) | Không cần đổi — `content` TEXT đã có comment ý định "Markdown/HTML rút gọn" |
| Script extract cho docx | **Chưa tồn tại** | cần tạo `docs/db/import/extract_ta_chuyen_nganh_docx.py` | Phải viết mới — khác hẳn script PDF đã có (input là `.docx` zip/XML qua `zipfile` + regex trên `word/document.xml`, không phải PyMuPDF) |
| Script load cho chapters | **Chưa tồn tại** | `docs/db/import/load.py` (mở rộng) | Cần thêm hàm `load_chapters()` cạnh `seed_dictionaries_from_csv()` đã có |
| Ranh giới UNIT trong XML | Đã khảo sát trực tiếp, xác nhận pattern `UNIT\s*\d+` xuất hiện **28 lần tổng** trong toàn văn bản | — | 14 lần đầu (vị trí ký tự < 2000) là **mục lục**, không phải nội dung thật; 14 lần sau (vị trí 5030 → 147656) là nội dung thật. Script cần logic phân biệt (lọc theo vị trí hoặc bỏ qua N match đầu), không thể chỉ regex tìm "UNIT n" đơn thuần |
| Cấu trúc phần con trong UNIT | Đa số theo mẫu `I. INTRODUCTION` → `II. TEXT` → `III. GRAMMAR` → `IV. VOCABULARY` → `Exercise`, nhưng **Unit 9 của Chapter II lệch**: dùng `A. FOREIGN RELATIONS BETWEEN...` thay vì `I. INTRODUCTION` | — | Vì phase này lấy **toàn bộ UNIT gộp 1 khối** (đã chốt), lệch heading con không chặn được việc extract — chỉ cần bắt đúng ranh giới UNIT ngoài cùng, không cần parse từng heading con |
| Ranh giới cuối UNIT 11 (UNIT cuối cùng, Chapter II) | Vị trí bắt đầu 147656, `APPENDIX` bắt đầu ở vị trí 159534 — khoảng cách đủ lớn, an toàn để cắt trước APPENDIX | — | Cần xác nhận thêm không có nội dung rác/Exercise cuối cùng bị cắt nhầm — xem Open Questions |

# Data Contract (thay "API Contract")

| Item | Value |
|---|---|
| Nguồn vào | `docs/source-materials/TA_chuyen_nganh.docx` — đọc bằng `zipfile` + regex trên `word/document.xml` (đã xác nhận không cần cài `python-docx`/`docx2txt`, dùng Python stdlib, nhất quán cách đã dùng để khảo sát ở đây) |
| Artifact trung gian | `chapters_import.csv` — human-reviewable, KHÔNG insert thẳng vào DB |
| Cột CSV | `section_name` (text: "General Military English" / "Specialized English for the Vietnam Coast Guard" — tên chính xác cần xác nhận, xem Open Questions) · `chapter_title` (text, tên UNIT, vd "Vietnam People's Army") · `sort_order` (int, số UNIT trong section đó) · `content_md` (text, Markdown thô toàn bộ nội dung UNIT) · `reviewed` (0/1) |
| Đầu ra | DB thử nghiệm SQLite dựng từ `docs/db/schema.sql`: 2 dòng `sections`, 14 dòng `chapters` |
| Validation khi LOAD | `chapter_title`/`content_md` không được rỗng cho dòng sẽ insert; `section_name` phải khớp đúng 1 trong 2 tên đã chốt |
| Lỗi nghiệp vụ | Dòng có `reviewed=0` → skip dòng đó (không insert), in danh sách dòng bị skip, không dừng cả batch — nhất quán quyết định đã áp dụng ở task 03 |
| Lỗi dữ liệu | Nếu ranh giới UNIT extract sai (lẫn nội dung 2 unit) → phát hiện được ở bước review (đọc lướt CSV), không có rule cứng để tự động validate nội dung đúng/sai bằng code |

# Risk Analysis

- [x] UI incomplete — không áp dụng, phase này không đụng UI (đã chốt out of scope).
- [ ] Data contract unclear — đã rõ, xem bảng Data Contract trên.
- [ ] DB schema unclear — đã rõ, dùng đúng `sections`/`chapters` có sẵn, không cần migrate.
- [x] Permission rule unclear — không áp dụng, không có concept permission ở data pipeline nội bộ này.
- [x] Existing flow may be affected — không, `LessonsScreen` hiện tại không đọc `chapters.content`, seed data này không ảnh hưởng hành vi app hiện tại cho tới khi có phase UI riêng.
- [ ] Manual verification required — có, xem Acceptance Criteria #4 (review 14 dòng trước LOAD).
- [ ] **Ranh giới UNIT/CHAPTER phức tạp hơn giả định ban đầu ở brainstorm** — brainstorm trước giả định "14 UNIT phẳng"; thực tế là **2 CHAPTER × (3+11) UNIT với số thứ tự lặp lại độc lập theo từng CHAPTER**. Task-plan kế tiếp cần dùng đúng cấu trúc này, không dùng lại giả định cũ.
- [ ] **Unit 9 (Chapter II) lệch cấu trúc heading con** (`A.` thay vì `I.`) — không chặn extract (vì lấy nguyên khối theo ranh giới UNIT ngoài cùng) nhưng cần lưu ý khi review, không phải lỗi script.

# Open Questions / TODO

- Xác nhận lại tên hiển thị 2 `sections`: dùng nguyên văn tiếng Anh từ
  docx ("General Military English" / "Specialized English for the
  Vietnam Coast Guard") hay dịch/rút gọn sang tiếng Việt cho nhất quán
  với cách đặt tên `dictionaries` hiện có (vd "Quân sự chung", "Chuyên
  ngành Cảnh sát biển")?
- Xác nhận điểm dừng chính xác cuối UNIT 11 (trước `APPENDIX`, khoảng
  cách ký tự 147656 → 159534) — cần đọc chi tiết đoạn này để chắc chắn
  không có nội dung Exercise cuối cùng bị cắt nhầm hoặc rác xen giữa.
- Xác nhận thứ tự hiển thị 2 `sections` (`sort_order=1,2` theo đúng thứ
  tự CHAPTER I/II trong docx, hay ưu tiên khác theo quyết định nghiệp
  vụ — không phải quyết định kỹ thuật).
- Task-plan kế tiếp nên tái dùng format "Data Contract"/Subtask
  Breakdown theo giai đoạn Extract/Review/Load đã dùng ở `03-plan.md`
  thay vì format Backend/Frontend gốc của skill `task-plan`.
