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
         ├── learned_words (1-1, SM-2, giữ nguyên)
         └── review_logs (1-N, giữ nguyên)

sections ── 1-N ── chapters ── N-N ── chapter_words ── words
(nội dung bài học, độc lập với khái niệm "bộ từ điển")
```

## Bảng `words` (hợp nhất — thay cho `words` + `custom_words` cũ)

| Cột               | Kiểu          | Ghi chú                                                                                                                                                                                                       |
| ------------------ | -------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `id`             | INTEGER PK     | Namespace duy nhất cho mọi từ, không phân biệt nguồn gốc                                                                                                                                               |
| `word`           | TEXT           |                                                                                                                                                                                                                |
| `word_lower`     | TEXT           | Cột phụ trợ tìm kiếm không phân biệt hoa/thường (giữ như code hiện tại)                                                                                                                          |
| `phonetic`       | TEXT NULL      | Có thể rỗng nếu nguồn không cung cấp (vd một số từ tự nhập tay)                                                                                                                                    |
| `meaning_vi`     | TEXT           | Nghĩa tiếng Việt — với từ nguồn Online, là kết quả đã qua LibreTranslate                                                                                                                           |
| `meaning_en`     | TEXT NULL      | Định nghĩa gốc tiếng Anh (giữ lại từ Free Dictionary API khi có, hữu ích nếu bản dịch máy không chuẩn)                                                                                        |
| `part_of_speech` | TEXT NULL      | Loại từ (dt/đt/tt...), giữ như code hiện tại                                                                                                                                                            |
| `is_subentry`    | INTEGER (bool) | Giữ nguyên ý nghĩa cũ (cụm từ/biến thể liên quan 1 từ gốc)                                                                                                                                         |
| `source`         | TEXT           | `'seed'` (giáo trình gốc, đóng gói sẵn lúc build) / `'online_lookup'` (tra Online rồi bấm "Thêm vào bộ") / `'manual'` (user tự nhập tay, khớp mockup `screen-07b-tu-them-tu-moi.html`) |
| `created_at`     | INTEGER        | Unix timestamp — với`source='seed'` là thời điểm build DB                                                                                                                                              |

> Không còn khái niệm "read-only" ở tầng bảng — từ `source='seed'` vẫn có
> thể coi là "không nên sửa/xoá qua UI thường" ở tầng ứng dụng (Repository
> có thể chặn edit/xoá dựa vào cột `source`), nhưng đây là ràng buộc logic
> nghiệp vụ, không phải ràng buộc vật lý 2 file DB như thiết kế trước.

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
mới (`source='manual'` hoặc `source='online_lookup'`) mà không chỉ định
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

| Cột           | Kiểu                        | Ghi chú                                                                                                                                                                              |
| -------------- | ---------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `id`         | INTEGER PK                   |                                                                                                                                                                                       |
| `section_id` | INTEGER FK →`sections.id` |                                                                                                                                                                                       |
| `title`      | TEXT                         | Tiêu đề bài học                                                                                                                                                                  |
| `sort_order` | INTEGER                      | Thứ tự bài trong Section                                                                                                                                                           |
| `content`    | TEXT                         | Nội dung bài đọc —**cấu trúc chi tiết và cách nhúng highlight từ vựng chốt ở bước xử lý `.docx` riêng (Q-CSB-07)**; cột này là placeholder tối thiểu |

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
  `words` (`source='online_lookup'`) + 1 dòng `word_dictionaries` (bộ đã
  chọn, hoặc "Chưa phân loại" nếu không chọn) trong cùng transaction.

## Migration dữ liệu ban đầu (tóm tắt, chi tiết để lúc implement)

1. Gộp `vocab.db.words` + toàn bộ dữ liệu `user.db` liên quan từ vựng vào 1
   file DB mới, bảng `words` hợp nhất — thêm cột `source` (mặc định
   `'seed'` cho dữ liệu từ `vocab.db` cũ).
2. Tạo bảng `dictionaries`: 1 dòng "Chưa phân loại" (`is_deletable=0`) + 6
   dòng từ `chapters` cũ (đổi tên bảng, giữ nguyên tên 6 chương).
3. Tạo bảng `word_dictionaries`: mỗi từ có `chapter_id=X` cũ → 1 dòng
   `(word_id, dictionary_id=X)`. Từ nào (nếu có) không có `chapter_id` cũ
   → gán vào "Chưa phân loại".
4. Tạo bảng `sections`, `chapters` (mới), `chapter_words` — rỗng cho tới
   khi có dữ liệu từ bước xử lý `.docx` riêng (Q-CSB-07).
5. `learned_words`, `review_logs`, `search_history` (SM-2, giữ nguyên) trỏ
   `word_id` sang bảng `words` hợp nhất mới — không đổi cấu trúc các bảng
   này, chỉ đổi namespace `word_id` tham chiếu tới (nay là 1 nguồn thay vì
   tiềm ẩn 2 nguồn).

## Câu hỏi còn mở liên quan tới thiết kế này

| #        | Câu hỏi                                                                                                                                                                                                                                                | Ghi chú                                                                                                                                                                                                                                                |
| -------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Q-CSB-02 | Mockup "Từ điển của tôi" (7 màn`screen-07*`) có chốt triển khai đúng như thiết kế không?                                                                                                                                                | Thiết kế bảng ở trên đã giả định**có** triển khai — cần xác nhận lại 1 lần trước khi bắt đầu code                                                                                                                          |
| —       | Xoá 1 từ khỏi 1 bộ cá nhân — có tự động chuyển về "Chưa phân loại" nếu đó là bộ duy nhất chứa từ đó không, hay xoá thẳng cả`words`?                                                                                      | Áp dụng nguyên tắc#2 (không mồ côi) gợi ý: **chuyển về "Chưa phân loại"** thay vì xoá dữ liệu từ, trừ khi user chủ động chọn "Xoá từ" (khác với "Bỏ khỏi bộ") — cần xác nhận lại UX cụ thể trước khi code |
| —       | 1 file DB duy nhất có còn cần tách "đóng gói sẵn lúc build" (giống cơ chế copy asset của`vocab.db` cũ) khỏi phần user ghi thêm không, hay toàn bộ đều tạo/ghi runtime từ đầu (seed data insert lúc khởi tạo lần đầu)? | Ảnh hưởng cơ chế cập nhật app sau này (đổi/thêm từ giáo trình gốc mà không mất dữ liệu user) — chưa chốt, nên bàn kỹ trước khi implement                                                                                    |
