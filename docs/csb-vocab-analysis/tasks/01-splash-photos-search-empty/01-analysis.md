# Task 01 — Đối ứng mockup Win/Mobile: Ảnh Splash + Trạng thái rỗng Tra cứu

## Impact Analysis

> Task-analysis only — **không sửa code**. Nguồn: `../../00_Overview.md`,
> `../../02_Search.md`, `../../03_Lessons-by-chapter.md`,
> `../../90_Traceability-matrix.md`, `docs/spec_history.md`
> ([IMPL-005]…[IMPL-010]).

### Diễn giải yêu cầu

"01" = mốc mockup mới nhất vừa hoàn thành đối ứng 2 nền tảng: commit
`8bf6c65` (mobile, [IMPL-008]/[IMPL-009]) và `9ef34b3` (Windows,
[IMPL-010]). Cả hai bộ `docs/artifact-design/` và
`docs/artifact-design-windows/` nay có **cùng bộ 16 màn** (tên file giống
hệt nhau), thể hiện cùng một định hướng mô hình mới. Task này rà soát:
mockup đã "đối ứng" xong ở tầng thiết kế, nhưng **code Flutter thật** (dùng
chung 1 codebase cho cả Windows/Android/iOS) **chưa triển khai bất kỳ phần
nào** của định hướng mới — đây là khoảng cách cần phân tích tác động trước
khi implement.

## Requirement Summary

### Business Goal

Đưa app từ mô hình hiện tại (tra cứu offline-only, "chương" = nhóm từ
phẳng) sang mô hình mới đã chốt định hướng và minh hoạ đầy đủ ở mockup:
(1) tra cứu có thêm chế độ Online bổ sung nguồn ngoài, (2) từ vựng thuộc
nhiều "bộ từ điển" (N-N) thay vì 1 chương cố định, (3) nội dung học tổ
chức lại thành Section → Chapter dạng bài báo thay vì danh sách từ trần.
Vì app dùng **1 codebase Flutter duy nhất** cho Windows/Android/iOS, mọi
thay đổi tầng dữ liệu/provider/logic là **dùng chung**; phần khác biệt
Win/Mobile chỉ nằm ở tầng UI layout (`NavigationRail` + 2 cột
`pane-list`/`pane-detail` cho Windows vs `NavigationBar` + full-screen/
bottom-sheet cho Mobile), đúng như `HomeShell` đã làm hiện tại qua
breakpoint 700px.

### Scope

- Rà soát khoảng cách giữa 16 màn mockup (đã đối ứng Win/Mobile) và code
  Flutter thật hiện có (`lib/features/search/`, `lib/features/lessons/`).
- Liệt kê toàn bộ gap UI, gap tầng dữ liệu, và các điểm chưa chốt (open
  questions) chặn việc implement.
- Xác định phần **dùng chung** (business logic, provider, schema) và phần
  **khác biệt** Windows/Mobile (layout, widget) để tách task implement sau
  này theo đúng ranh giới codebase hiện tại
  (`AppConstants.desktopBreakpoint` trong `HomeShell`).

### Out of Scope

- Không thiết kế schema Drift cụ thể (bảng, cột, migration) — chờ
  Q-CSB-04..07 được trả lời trước, theo đúng note ở [IMPL-007].
- Không chốt nhà cung cấp API từ điển ngoài (Q-CSB-04).
- Không xử lý quy trình chuyển `.docx` → dữ liệu Section/Chapter có cấu
  trúc (Q-CSB-07) — đây là công việc chuẩn bị dữ liệu, không phải UI/code
  app.
- Không implement bộ từ điển cá nhân, ôn tập trộn 3 dạng câu (gap cũ hơn,
  ghi trong `90_Traceability-matrix.md`).

### Acceptance Criteria

- [x] Có bảng liệt kê đầy đủ gap UI theo từng màn/luồng (Tra cứu,
      Section/Chapter, Từ điển của tôi) — đối chiếu rõ Windows vs Mobile.
- [x] Có bảng gap tầng dữ liệu/backend nội bộ (schema `vocab.db`, N-N,
      Drift, API ngoài) với mức độ ảnh hưởng.
- [x] Danh sách câu hỏi mở nào **phải trả lời trước khi code** vs câu hỏi
      nào **có thể quyết định trong lúc code**.
- [x] `spec_history.md` có entry mới ghi nhận việc phân tích này
      ([IMPL-011]).

## Existing UI Analysis

| Item | Current Status | File/Module | Notes |
| ---- | -------------- | ----------- | ----- |
| Tra cứu (offline) | ✅ Code xong | `lib/features/search/search_screen.dart` | Chỉ 1 trạng thái — không phân biệt Offline/Online, không badge mạng |
| Danh sách chương ("Học") | ✅ Code xong (mô hình cũ) | `lib/features/lessons/lessons_screen.dart` (`LessonsScreen`) | Chương = nhóm từ 1-N, sẽ đổi ý nghĩa hoàn toàn |
| Danh sách từ trong chương | ✅ Code xong (mô hình cũ) | `lib/features/lessons/lessons_screen.dart` (`ChapterWordsScreen`) | List phẳng `WordTile`, không phải bài báo |
| Chi tiết từ (bottom sheet) | ✅ Code xong, dùng chung SCR-02/03 | `lib/features/vocab/word_widgets.dart` (`WordDetailSheet`) | Chưa có nút "Thêm vào bộ" như mockup `screen-04b` |
| `HomeShell` (điều hướng thích ứng) | ✅ Code xong | `lib/features/home/home_shell.dart` | Cơ chế breakpoint Windows/Mobile đã có sẵn, tái dùng được cho các màn mới |
| Dịch nhanh | ⏳ Placeholder | `lib/features/translate/translate_screen.dart` | Không nằm trong scope task 01 nhưng cũng chưa khớp mockup `screen-06` |
| Từ điển của tôi | ❌ Chưa có trong code | *(không có route/tab)* | Toàn bộ luồng `screen-07*` (7 màn) chưa có gì tương ứng trong `HomeShell` (vẫn 5 tab cũ) |
| Title bar Windows tuỳ biến | ❌ Chưa có | *(không có)* | Mockup Windows có nút minimize/maximize/close riêng; code dùng `AppBar` Material chuẩn |
| Splash | ✅ Code xong | `lib/features/splash/splash_screen.dart` | Dùng `Icon(Icons.anchor)` placeholder — comment code đã ghi ý định thay ảnh thật khi có |

## UI Gap Analysis

| Missing / Incomplete UI | Required For Task | Recommended Action | Risk |
| ----------------------- | ----------------- | ------------------- | ---- |
| Badge Offline/Online trên Tra cứu (`screen-02`, `screen-02b`) | Cả Win + Mobile | Thêm `.net-badge` tương đương — cần provider trạng thái mạng dùng chung, chỉ khác style hiển thị theo layout | Trung bình — phụ thuộc Q-CSB-06 (cơ chế phát hiện mạng) chưa chốt |
| Trạng thái "chưa tìm kiếm" — slide ảnh CSB (`screen-02c`) | Cả Win + Mobile | Thêm carousel autoplay dùng ảnh `docs/artifact-design/assets/images/csb-slide-0{1,2,3}.jpg` — cần xác nhận nguồn ảnh có được dùng chính thức không (bản quyền, xem [IMPL-009]) trước khi đưa vào app thật | Thấp (UI thuần), nhưng **chặn bởi câu hỏi bản quyền ảnh** |
| Ảnh thật thay placeholder icon ở Splash (`screen-01`) | Cả Win + Mobile | Thay `Icon(Icons.anchor)` bằng `Image.asset` dùng cùng bộ ảnh CSB | Thấp — thay đổi cục bộ, nhưng **cùng chặn bởi câu hỏi bản quyền ảnh** như trên |
| Luồng Section → Chapter → bài đọc (`screen-03`, `03b`, `03c`) | Cả Win + Mobile, khác layout | Viết lại gần như hoàn toàn `LessonsScreen`/`ChapterWordsScreen` | **Cao** — thay đổi mô hình dữ liệu lớn nhất |
| Tab "Từ điển của tôi" (`screen-07*`, 7 màn) | Cả Win + Mobile | Thêm tab mới vào `HomeShell` | Cao — đổi cấu trúc điều hướng chính |
| Nút "Thêm vào bộ" trong `WordDetailSheet` (`screen-04b`) | Cả Win + Mobile | Thêm action mới vào sheet dùng chung | Trung bình — chặn bởi bộ từ điển cá nhân chưa có schema |
| Title bar tuỳ biến Windows | Chỉ Windows | Việc riêng, không phụ thuộc các gap trên | Thấp, có thể để sau |

## Backend Gap Analysis

> App không có backend/server riêng (offline-first, 1 user/1 thiết bị) —
> "Backend" ở đây là tầng dữ liệu nội bộ (`lib/data/local/`,
> `lib/data/repositories/`).

| Layer | Current Status | File/Module | Gap |
| ----- | -------------- | ----------- | --- |
| `vocab.db` schema | ✅ Chạy tốt, mô hình cũ | `lib/data/local/vocab_database.dart` | Bảng `chapters` (1-N) cần thay bằng N-N `word_dictionaries` |
| Section/Chapter dạng bài báo | ❌ Chưa có bảng nào | *(chưa tồn tại)* | Cần bảng mới `sections`, `chapters` (định nghĩa lại), có thể `chapter_words` |
| ORM/query layer | Raw `sqlite3` trực tiếp | `vocab_database.dart`, `user_database.dart`, `vocab_repository.dart` | Đã chốt (D3, [IMPL-007]): chuyển sang Drift khi thiết kế schema mới |
| `VocabRepository` | ✅ Hoạt động, gắn mô hình cũ | `lib/data/repositories/vocab_repository.dart` | `chapters()`, `wordsByChapter()` cần viết lại |
| Tầng gọi API ngoài | ❌ Chưa tồn tại | *(chưa có)* | Cần data source mới (`DictionaryApiRepository`?) |
| Phát hiện mạng (connectivity) | ❌ Chưa tồn tại | *(chưa có)* | Cần thêm package (`connectivity_plus` gợi ý), chưa chốt (Q-CSB-06) |
| Bộ từ điển cá nhân | ❌ Chưa có bảng | *(chưa tồn tại, `user.db`)* | Cần bảng mới + quan hệ N-N |
| Quy trình `.docx` → dữ liệu bài học | ❌ Chưa có | *(không có script trong repo)* | Cần script/quy trình mới, tách biệt pipeline PDF→SQLite cũ |

## API Impact

App không có API HTTP nội bộ — mục này áp dụng cho **API từ điển ngoài**
(nguồn dữ liệu Online).

| Item           | Value |
| -------------- | ----- |
| Existing API   | Không có |
| New API needed | Có — 1 API từ điển ngoài (nhà cung cấp **chưa chốt**, Q-CSB-04) |
| Endpoint       | TODO — phụ thuộc nhà cung cấp |
| Method         | Dự kiến GET |
| Request        | TODO — tối thiểu từ khoá + ngôn ngữ nguồn/đích |
| Response       | TODO — chưa biết field trả về |
| Error response | TODO — không có mạng vs có mạng nhưng API không phản hồi (Q-CSB-06) |
| Auth required  | TODO — phụ thuộc nhà cung cấp |

## Risk Analysis

- [x] UI incomplete — 3/7 luồng lớn chưa có UI tương ứng
- [x] API contract unclear — nhà cung cấp dictionary API chưa chọn
- [x] DB schema unclear — N-N, Section/Chapter, Drift đều chưa chốt cấu trúc
- [ ] Permission rule unclear — N/A, app 1 user/1 thiết bị
- [x] Existing flow may be affected — `HomeShell`, `searchProvider`,
      `VocabRepository` đều bị ảnh hưởng dây chuyền
- [x] Manual verification required — offline-first phải giữ nguyên hành vi

## Open Questions / TODO

### Đã chốt (xem `docs/spec_history.md` [IMPL-013])

| # | Câu hỏi | Quyết định |
|---|---|---|
| Q-CSB-04 | Nhà cung cấp dictionary API cụ thể | **Free Dictionary API** (miễn phí, không cần key) + **LibreTranslate** để dịch nghĩa sang tiếng Việt |
| Q-CSB-05 | Từ tra online có lưu lại local không, lưu vào bộ nào? | **Không tự động lưu** — chỉ ghi vào `user.db` khi user chủ động bấm "Thêm vào bộ" |
| Q-CSB-06 | Package phát hiện mạng + xử lý lỗi mạng chập chờn | `connectivity_plus`; lỗi/timeout → fallback êm về offline, không chặn UI |
| Q-CSB-07 | Quy trình chuyển `.docx` → Section/Chapter có cấu trúc | **Dời sang một bước phân tích/implement riêng** — không chặn thiết kế schema DB nữa (xem `91_DB-design-new-model.md`), nhưng vẫn chặn việc code UI đọc bài thật (`screen-03c`) cho tới khi bước đó xong |

Chi tiết schema áp dụng các quyết định trên: xem
`../../91_DB-design-new-model.md` (thiết kế DB cho N-N bộ từ điển,
Section/Chapter, bộ từ điển cá nhân — theo Drift).

### Còn chặn trước khi code

| # | Câu hỏi | Vì sao chặn |
|---|---|---|
| — | Tách `chapter_words` riêng hay parse runtime? | **Đã chốt trong `91_DB-design-new-model.md`: tách bảng riêng** (lý do hiệu năng — xem tài liệu đó) |
| — | Bản quyền/nguồn 3 ảnh CSB dùng ở Splash + `screen-02c` | Chặn subtask FE-01/FE-02/FE-03 ở `02-plan.md` — xem Risks trong plan |

### Có thể quyết định trong lúc code (risk thấp hơn)

| # | Câu hỏi | Ghi chú |
|---|---|---|
| Q-CSB-01 | FR-6 có từng tồn tại không | Không ảnh hưởng implement |
| Q-CSB-02 | Mockup "Từ điển của tôi" có chốt triển khai đúng như thiết kế không | `91_DB-design-new-model.md` đã thiết kế schema giả định **có** triển khai — vẫn nên hỏi lại 1 lần trước khi code UI 7 màn `screen-07*` |

### Việc cần làm tiếp

- Xem `02-plan.md` trong cùng thư mục cho implementation plan của phần đã
  scope hẹp lại (ảnh Splash + trạng thái rỗng Tra cứu) — không đổi vì các
  quyết định trên không ảnh hưởng tới Splash/SCR-02c.
- Bước `.docx` → dữ liệu Section/Chapter (Q-CSB-07): lập task-analysis/
  task-plan riêng khi tới lượt.
- Sau khi xác nhận lại Q-CSB-02 → chạy `task-brainstorm` rồi `task-plan`
  cho luồng "Từ điển của tôi" và luồng tra cứu Online (dùng
  `91_DB-design-new-model.md` làm nền schema).

## Manual Verification

- Sau khi thêm chế độ Online, bắt buộc test tắt mạng hoàn toàn trên cả
  Windows và 1 thiết bị mobile — xác nhận luồng offline-first vẫn chạy
  đúng.
- Test chuyển đổi Online ⇄ Offline giữa lúc đang dùng app.
- Sau khi implement Section/Chapter mới: xác nhận 6 "chương" cũ vẫn tra
  cứu được đầy đủ qua vai trò "bộ từ điển mặc định" mới.
- Đối chiếu Windows vs Mobile cùng 1 thao tác để đảm bảo hành vi logic
  giống nhau, chỉ khác layout.
