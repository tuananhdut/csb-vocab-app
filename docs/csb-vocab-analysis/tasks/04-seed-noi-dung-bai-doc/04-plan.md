# Implementation Plan — Seed dữ liệu bài đọc (`sections`/`chapters`) từ `TA_chuyen_nganh.docx`

> Áp dụng skill `task-plan` — điều chỉnh format cho đúng bản chất công
> việc, giống điều chỉnh đã áp dụng ở `03-plan.md`: đây là **data
> pipeline** (Extract → Review → Load), không phải tính năng có API/UI.
> Không có Backend/Frontend tách biệt như skill gốc giả định — thay vào
> đó chia theo giai đoạn pipeline. Không sửa code, không implement, chỉ
> lập kế hoạch.

Kế thừa toàn bộ `Requirement Summary`/`Data Gap Analysis`/`Risk
Analysis` đã chốt ở
[`04-analysis.md`](04-analysis.md) — không lặp lại ở đây, chỉ bổ sung
phần thực thi.

# Open Questions đã chốt (bổ sung so với `04-analysis.md`)

| Câu hỏi | Quyết định |
|---|---|
| Ngôn ngữ tên hiển thị 2 `sections` | **Giữ tiếng Anh nguyên văn** từ docx: `"General Military English"` và `"Specialized English for the Vietnam Coast Guard"` — không dịch/rút gọn sang tiếng Việt |
| Thứ tự `sort_order` của 2 `sections` | **Theo đúng thứ tự xuất hiện trong docx**: CHAPTER I → `sort_order=1`, CHAPTER II → `sort_order=2` |
| Điểm dừng cuối UNIT 11 (Chapter II) | Xử lý ở EXT-01 (khảo sát trực tiếp đoạn 147656→159534 trước khi viết script chính thức) — xem Subtask Breakdown |

# Selected Approach

Tái dùng đúng pattern pipeline 3 giai đoạn đã áp dụng ở task 03, đổi
nguồn/đích cho đúng bản chất dữ liệu bài đọc (docx → `sections`/
`chapters`, không phải PDF → `words`):

```
[1. EXTRACT]  TA_chuyen_nganh.docx
                  │  (script Python, zipfile + regex trên word/document.xml)
                  ▼
[2. REVIEW]   chapters_import.csv (trung gian, người soát nhanh ranh giới UNIT)
                  │  (mở rộng load.py, đọc CSV đã review)
                  ▼
[3. LOAD]     INSERT vào sections + chapters (DB thử nghiệm, dựng từ schema.sql)
```

Khác biệt so với task 03 (không phải lựa chọn mới, chỉ ghi nhận để
tránh nhầm lẫn khi thực thi):

- Không cần khảo sát heuristic font/màu (EXT-01 ở task 03) — ranh giới
  ở đây là **regex `UNIT\s*\d+`/`CHAPTER\s+[IVX]+`** trên text thuần,
  đã xác nhận trực tiếp qua `zipfile` ở bước analysis, không cần công cụ
  đọc font/màu.
- Review ở đây **nhẹ hơn nhiều** (14 dòng, soát ranh giới UNIT — không
  soát từng câu như 1400+ dòng `words` ở task 03).
- `load.py` **mở rộng file đã có**, không viết file load mới — thêm hàm
  `load_chapters()` cạnh `seed_dictionaries_from_csv()`.

# Data Contract (thay cho API Contract)

| Item | Value |
|---|---|
| Nguồn vào | `docs/source-materials/TA_chuyen_nganh.docx` — đọc bằng `zipfile` + regex trên `word/document.xml` (Python stdlib, không cần `python-docx`) |
| Artifact trung gian | `docs/db/import/chapters_import.csv` — human-reviewable, KHÔNG insert thẳng vào DB |
| Cột CSV | `section_name` (text, 1 trong 2 tên tiếng Anh đã chốt) · `chapter_title` (text, tên UNIT, vd `"Vietnam People's Army"`) · `sort_order` (int, số UNIT trong section đó — 1-3 cho section 1, 1-11 cho section 2) · `content_md` (text, Markdown thô toàn bộ nội dung UNIT) · `reviewed` (0/1) |
| Đầu ra | DB thử nghiệm SQLite (tái dùng `docs/db/import/review.sqlite` đã có từ task 03, dựng lại từ `docs/db/schema.sql`): 2 dòng `sections`, 14 dòng `chapters` |
| Validation khi LOAD | `chapter_title`/`content_md` không rỗng cho dòng sẽ insert · `section_name` phải khớp đúng 1 trong 2 tên đã chốt (`"General Military English"` / `"Specialized English for the Vietnam Coast Guard"`) |
| Lỗi nghiệp vụ | Dòng `reviewed=0` → skip (không insert), in danh sách dòng bị skip, không dừng batch — nhất quán quyết định đã áp dụng ở `load.py` cho `words_import.final.csv` |
| Lỗi dữ liệu | `section_name` không khớp 1 trong 2 tên chốt → skip dòng, log ra stdout, không dừng batch (an toàn phòng thủ, không nên xảy ra vì script extract chỉ sinh 2 tên cố định) |
| `sections.sort_order` | Suy từ thứ tự xuất hiện CHAPTER trong docx: CHAPTER I → 1, CHAPTER II → 2 (load.py tạo `sections` tương tự cách `seed_dictionaries_from_csv()` suy `dictionaries` động từ CSV — không hardcode riêng) |

# Subtask Breakdown

## Extract Subtasks (thay "Backend")

| Subtask ID | Title | Files/Modules | Description | Depends On | Risk |
|---|---|---|---|---|---|
| EXT-01 | Xác nhận điểm dừng cuối UNIT 11 | script khảo sát riêng, không lưu lại | Đọc chi tiết đoạn ký tự 147656→159534 trong `word/document.xml` (giữa UNIT 11 và `APPENDIX`) để chắc chắn không có Exercise cuối cùng bị cắt nhầm hoặc rác xen giữa — trả lời Open Question còn lại duy nhất trước khi viết script chính thức | None | Trung bình — nếu bỏ qua, UNIT 11 có thể thiếu phần Exercise cuối |
| EXT-02 | Viết script `extract_ta_chuyen_nganh_docx.py` | file mới, `docs/db/import/extract_ta_chuyen_nganh_docx.py` | Đọc `word/document.xml` qua `zipfile`, dùng regex tách 2 CHAPTER cha + 14 UNIT con theo đúng cấu trúc đã xác nhận (28 lần match `UNIT\s*\d+` — bỏ qua 14 lần đầu thuộc mục lục, chỉ lấy 14 lần sau ở vị trí ký tự ≥5030); gộp mỗi UNIT thành 1 khối Markdown thô (I. INTRODUCTION/A. FOREIGN RELATIONS cho Unit 9 lệch + II. TEXT + III. GRAMMAR + IV. VOCABULARY + Exercise), cắt trước `APPENDIX` theo mốc EXT-01 xác nhận | EXT-01 | **Cao** — sai ranh giới UNIT lan sang toàn bộ 14 dòng, tương tự rủi ro EXT-01 ở task 03 |
| EXT-03 | Gán `section_name`/`sort_order` | cùng file `extract_ta_chuyen_nganh_docx.py` | Map CHAPTER I → `section_name="General Military English"`, `sort_order=1`; CHAPTER II → `section_name="Specialized English for the Vietnam Coast Guard"`, `sort_order=2` (đã chốt, xem Open Questions đã chốt); mỗi UNIT con → `sort_order` = số UNIT trong section đó (1-3 hoặc 1-11, đánh số độc lập theo từng CHAPTER) | EXT-02 | Thấp — mapping đã chốt đầy đủ |
| EXT-04 | Chạy script, xuất CSV | — | Chạy `extract_ta_chuyen_nganh_docx.py`, xuất `docs/db/import/chapters_import.csv` (14 dòng, `reviewed=0` mặc định) | EXT-02, EXT-03 | Thấp |

## Review Subtasks (thay "Frontend" — công việc thủ công của người)

| Subtask ID | Title | Files/Modules | Description | Depends On | Risk |
|---|---|---|---|---|---|
| REV-01 | Soát ranh giới 14 dòng CSV | `chapters_import.csv` (mở bằng Excel/Sheets hoặc đọc trực tiếp) | Soát **nhanh** (không cần từng câu như task 03): mỗi dòng bắt đầu đúng từ đầu UNIT, kết thúc đúng cuối Exercise của UNIT đó, không lẫn nội dung UNIT kế/APPENDIX. Chú ý riêng Unit 9 Chapter II (heading lệch `A. FOREIGN RELATIONS...`) — xác nhận vẫn nằm trong đúng ranh giới UNIT, không phải lỗi script | EXT-04 | Trung bình — chỉ 14 dòng nên rẻ hơn nhiều task 03, nhưng bỏ sót ranh giới sai sẽ lẫn nội dung 2 unit vào 1 dòng |
| REV-02 | Đánh dấu `reviewed=1` | `chapters_import.csv` | Cập nhật cột `reviewed` cho toàn bộ 14 dòng sau khi xác nhận đúng (Acceptance Criteria #4 — bắt buộc `reviewed=1` cho toàn bộ trước khi LOAD, khác task 03 vốn cho phép skip từng dòng) | REV-01 | Thấp |

## Load Subtasks (thay "Integration")

| Subtask ID | Title | Files/Modules | Description | Depends On | Risk |
|---|---|---|---|---|---|
| LOAD-01 | Thêm hàm `load_chapters()` vào `load.py` | `docs/db/import/load.py` (mở rộng, không viết file mới) | Đọc `chapters_import.csv`, suy `sections` động từ cột `section_name` distinct (2 dòng, `sort_order` theo thứ tự CHAPTER trong docx — tương tự cách `seed_dictionaries_from_csv()` đã làm cho `dictionaries`), `INSERT` vào `sections` + `chapters` trong 1 transaction, gọi từ `main()` cạnh luồng `words` đã có hoặc luồng riêng | REV-02, `load.py` đã có sẵn | Thấp |
| LOAD-02 | Chạy LOAD, verify | DB thử nghiệm `docs/db/import/review.sqlite` (tái dùng, không tạo file `.sqlite` riêng) | Đối chiếu số dòng insert: 2 `sections` + 14 `chapters` khớp CSV; query thử `content` của Unit 9 Chapter II để xác nhận heading lệch không làm hỏng nội dung | LOAD-01 | Thấp |

# Recommended Execution Order

Giữ nguyên nguyên tắc "Extract-first" đã áp dụng ở `03-plan.md` — pipeline
tuần tự có phụ thuộc cứng, không có lựa chọn song song BE/FE:

1. EXT-01 (xác nhận điểm dừng UNIT 11 — **làm trước tiên**, đây là Open
   Question kỹ thuật duy nhất còn lại)
2. EXT-02, EXT-03 (viết script, áp dụng 2 quyết định tên/thứ tự
   `sections` đã chốt)
3. EXT-04 (chạy, xuất CSV — **không cần** bước "chạy thử 1 phần nhỏ
   trước" như EXT-04/EXT-05 ở task 03, vì chỉ có 14 dòng tổng, chi phí
   chạy full và soát full là như nhau)
4. REV-01, REV-02 (soát nhanh 14 dòng — rẻ hơn nhiều so với task 03,
   không cần chia nhỏ theo batch)
5. LOAD-01, LOAD-02 (mở rộng `load.py`, nạp thử nghiệm + verify)

Không có bước tương đương LOAD-03 (dedup) ở task 03 — `sections`/
`chapters` là dữ liệu bài đọc, không có khái niệm trùng lặp với nguồn
`words` khác.

# User Decision Required

Không còn quyết định nghiệp vụ nào cần hỏi thêm trước khi bắt đầu — cả 3
Open Question ở `04-analysis.md` đã chốt (2 câu ở bảng trên, câu còn lại
là kỹ thuật thuần, xử lý ở EXT-01). Có thể bắt đầu thực thi theo thứ tự
Recommended Execution Order.

# Manual Verification Plan

## Main Flow

- [ ] Chạy `extract_ta_chuyen_nganh_docx.py`, xác nhận CSV có đúng 14
      dòng (3 dòng `section_name="General Military English"` +
      11 dòng `section_name="Specialized English for the Vietnam Coast
      Guard"`).
- [ ] Đối chiếu `chapter_title` của 14 dòng đúng thứ tự/tên UNIT đã liệt
      kê ở `04-analysis.md` (Vietnam People's Army, Uniforms, Vietnam
      Coast Guard; Stipulating the Law..., Maritime, ..., Initial
      Response and Search Planning).

## Data Verification (thay "UI/API Verification")

- [ ] Mỗi `content_md` bắt đầu đúng từ heading đầu UNIT (`I.
      INTRODUCTION`, riêng Unit 9 Chapter II là `A. FOREIGN RELATIONS
      BETWEEN...`) đến hết Exercise, không lẫn nội dung UNIT kế tiếp.
- [ ] UNIT 11 (Chapter II, UNIT cuối) không bị cắt thiếu Exercise cuối
      cùng, không lẫn nội dung `APPENDIX` (xác nhận từ EXT-01).
- [ ] Không có dòng nào chứa nội dung `PREFACE`/`REFERENCE`/`APPENDIX`.
- [ ] Sau LOAD: `sections` có đúng 2 dòng, `sort_order` 1/2 đúng thứ tự
      CHAPTER I/II; `chapters.section_id` trỏ đúng section cha, `sort_order`
      đúng số UNIT trong từng section (1-3 và 1-11, không liên tục xuyên
      2 section).

## Error / Edge Case

- [ ] Chạy `load_chapters()` với CSV còn dòng `reviewed=0` (nếu có) →
      dòng đó bị skip, in rõ danh sách, không dừng batch — nhất quán
      hành vi đã có trong `load.py` cho `words`.
- [ ] `section_name` không khớp 1 trong 2 tên chốt (giả lập lỗi nhập
      liệu) → dòng bị skip, log ra stdout, không dừng batch.

## Regression

- [ ] Chạy `load.py` không làm thay đổi hành vi LOAD hiện có của
      `words`/`dictionaries`/`examples` (luồng cũ từ task 03 vẫn hoạt
      động đúng sau khi thêm `load_chapters()`).
- [ ] `docs/db/schema.sql` không cần đổi cấu trúc bảng nào — `sections`/
      `chapters` đã tồn tại đúng thiết kế cần dùng (dòng 116-130).

# Risks / TODO

- **[Đã chốt]** Tên hiển thị + thứ tự 2 `sections` — xem bảng "Open
  Questions đã chốt" ở đầu file này.
- **[Cần làm ở EXT-01]** Điểm dừng chính xác cuối UNIT 11 trước
  `APPENDIX` — chưa xác nhận chi tiết, là việc đầu tiên cần làm trước
  khi viết EXT-02.
- Unit 9 Chapter II lệch heading con (`A.` thay `I.`) — không chặn
  extract nhưng cần nhắc người review ở REV-01 để không nhầm là lỗi
  script.
- Phase UI (`ArticleScreen`/renderer đọc `chapters.content`) hoàn toàn
  ngoài phạm vi — chỉ ghi nhận lại, không lập subtask cho phase đó ở
  đây.
