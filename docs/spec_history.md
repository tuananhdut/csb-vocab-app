# CSB Vocab App — Spec Change History (spec_history)

Lịch sử thay đổi đặc tả. Mỗi entry: bối cảnh → nội dung thay đổi → tài liệu bị ảnh hưởng → điểm chờ xác nhận.

---

## [IMPL-016] 2026-07-19 — Bỏ hẳn bảng `review_logs` và `search_history`

**Người yêu cầu:** User · **Người thực hiện:** Claude

### Nội dung

Trong lúc rà lại `docs/db/schema.sql` (bản SQL đối chiếu trực quan cho
[IMPL-015]), phát hiện `review_logs` chỉ được `INSERT` trong code hiện
tại (`review_repository.dart`), **không có bất kỳ `SELECT` nào đọc
lại** — không màn hình, provider, hay thống kê nào từng dùng dữ liệu này.
Áp dụng đúng nguyên tắc đã chốt ở [IMPL-015] cho cột `question_mode`
("không giữ dữ liệu chưa ai dùng"), quyết định mở rộng thêm: bỏ **toàn
bộ bảng** `review_logs`, không chỉ dừng ở việc từ chối thêm cột mới.

Rà soát tiếp theo cùng nguyên tắc phát hiện `search_history` ở tình
trạng tương tự (thậm chí rõ hơn): không có cả `INSERT` lẫn `SELECT`
trong toàn bộ code, và `docs/csb-vocab-analysis/02_Search.md` đã ghi
nhận từ trước đây là gap ("chưa được đọc/ghi ở bất kỳ đâu") — không
mockup nào (kể cả `screen-02-tra-cuu.html`) thiết kế UI "lịch sử tra
cứu" đi kèm. Quyết định: bỏ hẳn luôn bảng này, cùng đợt với
`review_logs`.

Phân biệt rõ với `learned_words` (**không** bỏ) — đó là bảng lưu trạng
thái hiện tại của SM-2, được đọc liên tục để tính hàng đợi ôn tập; khác
bản chất với `review_logs`/`search_history` vốn chỉ là audit trail lịch
sử chưa từng có nhu cầu thống kê/hiển thị thật đi kèm. Hệ quả:
`submitReview()` sau khi implement chỉ còn `UPDATE learned_words`, bỏ
câu `INSERT INTO review_logs`.

Nếu sau này thực sự cần audit trail ôn tập hoặc tính năng "lịch sử tra
cứu gần đây", tạo lại bảng tương ứng khi đó bằng 1 migration đơn giản —
chấp nhận đánh đổi mất dữ liệu lịch sử trong giai đoạn không ghi, đổi
lấy việc không phải duy trì bảng không ai dùng trong lúc chờ.

### Tài liệu đã cập nhật

| File | Thay đổi |
|---|---|
| `docs/csb-vocab-analysis/91_DB-design-new-model.md` | Bỏ `review_logs` khỏi sơ đồ tổng quan quan hệ, khỏi bước 5 migration dữ liệu ban đầu (sửa luôn câu ghi sai trước đó nhắc `search_history` có `word_id`); đổi mục "Không thêm cột `review_logs.question_mode`" thành "Bỏ hẳn bảng `review_logs`/`search_history`" (lý do đầy đủ cho cả 2 bảng + phân biệt với `learned_words`); cập nhật "Việc cần làm khi implement" — `submitReview()` bỏ `INSERT INTO review_logs` |
| `docs/csb-vocab-analysis/02_Search.md` | Cập nhật mục "Giả định/hạn chế" — `search_history` từ "gap chưa làm" thành "đã bỏ hẳn khỏi thiết kế", trỏ sang [IMPL-016] |
| `docs/db/schema.sql` | Xoá `CREATE TABLE review_logs` và `search_history` + index liên quan; ghi chú ở đầu file giải thích lý do bỏ từng bảng (khác với `chapter_words` — dời sang phase sau chứ không bỏ hẳn) |

### Điểm chờ xác nhận còn mở

Không phát sinh điểm mới — kế thừa các điểm chờ đã có ở [IMPL-014]/
[IMPL-015].

---

## [IMPL-015] 2026-07-19 — Ôn tập khách quan (trắc nghiệm + gõ chữ), bỏ tự chấm, thêm nhãn "từ khó"

**Người yêu cầu:** User · **Người thực hiện:** Claude

### Nội dung

Mở rộng quyết định "Ôn tập bằng trắc nghiệm" đã chốt trước đó (dựng lại
từ 1 phiên phân tích trước, chưa từng ghi vào `spec_history.md`) thành 1
task-analysis đầy đủ (`docs/csb-vocab-analysis/tasks/02-review-multi-
mode/01-analysis.md`), sau khi xác nhận lại 6 điểm mở:

1. **Bỏ hẳn** kiểu lật thẻ tự chấm chủ quan (`ReviewRating` 4 mức
   Quên/Khó/Tốt/Dễ do người dùng tự bấm) — không giữ song song.
2. **Thêm 2 kiểu câu hỏi khách quan trộn ngẫu nhiên đều 50/50** trong 1
   phiên: **trắc nghiệm** (chọn 1/4 đáp án nghĩa tiếng Việt) và **gõ chữ**
   (nhập lại từ tiếng Anh, so khớp `trim().toLowerCase()` tuyệt đối,
   không fuzzy). Cả 2 đều tự động map Đúng→`q=4`, Sai→`q=1` vào
   `SrsScheduler` (SM-2) hiện có, không đổi thuật toán.
3. **Giới hạn 1 phiên tối đa 4 từ** — nếu hàng đợi hôm nay ít hơn 4 từ
   đến hạn thì phiên chỉ gồm đúng số từ đó, không độn thêm.
4. **"Từ khó"**: nhãn suy luận tự động, `ease_factor <= 1.5` (gần sàn
   1.3 của SM-2) — **chỉ dùng để hiển thị/thống kê**, không đổi thứ tự
   hàng đợi hay bất kỳ logic chọn từ nào (giữ nguyên nguyên tắc trước đó:
   không thêm tầng ưu tiên chồng lên SM-2, tránh phạt trùng 1 sự kiện
   sai 2 lần).
5. Thêm màn **kết quả cuối phiên** (tổng đúng/sai), thay `SnackBar` đơn
   giản hiện tại.
6. Thêm cột `review_logs.question_mode` (`0=MULTIPLE_CHOICE`,
   `1=TYPING`) vì nay giữ song song 2 kiểu câu hỏi, cần phân biệt nguồn
   gốc mỗi lượt ôn khi thống kê sau này.

Đã xác nhận **đợi migrate xong** sang schema mới (`dictionaries`/
`word_dictionaries` N-N, [IMPL-014]) mới implement — `randomDistractors`
viết theo `dictionary_id` mới, không viết tạm theo `chapter_id` cũ.

### Tài liệu đã cập nhật

| File | Thay đổi |
|---|---|
| `docs/csb-vocab-analysis/91_DB-design-new-model.md` | Viết lại mục "Ôn tập bằng trắc nghiệm" thành "Ôn tập khách quan: trắc nghiệm + gõ chữ" — thêm kiểu gõ chữ, giới hạn 4 từ/phiên, nhãn "từ khó" (`ease_factor<=1.5`, chỉ hiển thị), cột `review_logs.question_mode`, màn kết quả cuối phiên |
| `docs/csb-vocab-analysis/tasks/02-review-multi-mode/01-analysis.md` | Tạo mới — task-analysis đầy đủ (Requirement Summary, UI/Backend Gap, Risk Analysis), 6 Open Question đã chốt ghi trong mục "Quyết định đã chốt" |

### Điểm chờ xác nhận còn mở

- Chi tiết UI màn kết quả cuối phiên (bố cục, có hiện lại danh sách từ
  sai không) — để quyết định ở bước `task-plan`.
- Chi tiết UI kiểu gõ chữ ở trạng thái "đã submit" — mockup
  `screen-07e-phien-on-tap-cau-go-chu.html` chỉ có CSS state
  (`.type-input-row.correct/.wrong`, `.answer-reveal`) nhưng không có
  khung hình minh hoạ trực quan, cần tự thiết kế thêm khi vào task-plan.
- Kế thừa toàn bộ điểm chờ xác nhận của [IMPL-014] (Q-CSB-02, UX xoá từ
  khỏi bộ cá nhân, cơ chế cập nhật seed data) — vẫn chưa chốt, độc lập
  với thay đổi lần này.

---

## [IMPL-014] 2026-07-18 — Bỏ ranh giới vocab.db/user.db, gộp 1 DB, thêm bộ "Chưa phân loại"

**Người yêu cầu:** User · **Người thực hiện:** Claude

### Nội dung

Đổi hướng thiết kế DB mới ([IMPL-013]/`91_DB-design-new-model.md`) theo 3
yêu cầu:

1. **Bỏ ranh giới `vocab.db` (read-only) / `user.db` (read-write)** — không
   còn giữ nguyên 2 file SQLite tách biệt như dự tính ban đầu ở [IMPL-005].
   Thiết kế lại thành **1 database duy nhất**: 1 bảng `words` hợp nhất
   chứa mọi từ bất kể nguồn gốc (giáo trình gốc `source='seed'`, tự nhập
   tay `source='manual'`, tra online rồi lưu `source='online_lookup'`).
   Loại bỏ hoàn toàn vấn đề "N-N xuyên 2 file SQLite" (`ATTACH DATABASE`)
   từng nêu ở thiết kế trước. Phân biệt mặc định/cá nhân nay chỉ còn ở tầng
   bộ từ điển (`dictionaries.is_default`), không phải ở tầng file DB.
2. **Từ không thuộc bộ nào → gom vào 1 bộ đặc biệt "Chưa phân loại"** — bổ
   sung ràng buộc nghiệp vụ: mọi từ luôn phải có ít nhất 1 dòng trong
   `word_dictionaries`. Nếu thêm từ (tự nhập, hoặc lưu từ tra online) mà
   không chỉ định bộ cụ thể, tự động gán vào bộ "Chưa phân loại"
   (`is_deletable=0`, không thể xoá) — tránh dữ liệu "mồ côi" không thuộc
   bộ nào, khó hiển thị ở màn "Từ điển của tôi".
3. **Search vẫn ra kết quả bình thường dù từ thuộc bộ nào** — xác nhận rõ:
   `search(query)` không lọc theo bộ từ điển, luôn quét toàn bộ bảng
   `words` — giữ đúng hành vi FR-2 hiện tại (tìm mọi từ có trong hệ thống,
   không phân biệt nguồn/bộ).

Viết lại toàn bộ `91_DB-design-new-model.md` theo hướng mới (thay bản
[IMPL-013] cũ vốn vẫn giữ 2 file `vocab.db`/`user.db` song song).

### Tài liệu đã cập nhật

| File | Thay đổi |
|---|---|
| `docs/csb-vocab-analysis/91_DB-design-new-model.md` | Viết lại hoàn toàn: 1 bảng `words` hợp nhất (bỏ `custom_words` riêng), bảng `dictionaries` thêm cột `is_deletable` + dòng "Chưa phân loại" cố định, ràng buộc "mọi từ luôn có ≥1 bộ", xác nhận search không lọc theo bộ, cập nhật migration/Repository tương ứng |
| `docs/csb-vocab-analysis/00_Overview.md` | Cập nhật mục Kiến trúc kỹ thuật — ghi rõ không còn giữ 2 file `vocab.db`/`user.db` như dự tính ban đầu, trỏ sang `91_DB-design-new-model.md` |

### Điểm chờ xác nhận còn mở

Kế thừa các câu hỏi ở `91_DB-design-new-model.md` mục "Câu hỏi còn mở":
Q-CSB-02 (xác nhận lại "Từ điển của tôi"), UX xoá từ khỏi bộ cá nhân (xoá
hẳn hay chuyển về "Chưa phân loại"), và cơ chế cập nhật seed data giáo
trình gốc sau khi gộp 1 DB duy nhất (không còn cơ chế copy asset riêng như
`vocab.db` cũ).

---

## [IMPL-013] 2026-07-18 — Chốt Q-CSB-04/05/06, dời Q-CSB-07, thêm thiết kế DB mô hình mới

**Người yêu cầu:** User · **Người thực hiện:** Claude

### Nội dung

Trả lời trực tiếp 4 câu hỏi mở đã ghi ở [IMPL-005]/[IMPL-011]:

1. **Q-CSB-04 (nhà cung cấp dictionary API)** — chốt **Free Dictionary API**
   (`https://api.dictionaryapi.dev`, miễn phí, không cần API key) cho định
   nghĩa/phiên âm/ví dụ tiếng Anh. Vì API này chỉ trả tiếng Anh (không có
   nghĩa tiếng Việt, khác hành vi song ngữ hiện tại của `vocab.db`), ghép
   thêm **LibreTranslate** để dịch nghĩa sang tiếng Việt trước khi hiển thị.
2. **Q-CSB-06 (cơ chế phát hiện mạng)** — đồng ý dùng **`connectivity_plus`**
   như đã đề xuất; lỗi mạng chập chờn (có kết nối nhưng API không phản hồi/
   timeout) → **fallback êm về kết quả offline**, không chặn UI bằng lỗi đỏ.
3. **Q-CSB-05 (từ tra online có lưu lại không)** — chốt **không tự động lưu
   lại local**. Chỉ ghi vào `user.db` khi user **chủ động bấm "Thêm vào bộ"**
   (gắn vào 1 bộ từ điển cá nhân do user chọn/tạo) — đơn giản hoá luồng ghi
   dữ liệu, không có khái niệm "cache tự động".
4. **Q-CSB-07 (quy trình `.docx` → dữ liệu Section/Chapter)** — chốt
   **thực hiện ở một bước phân tích/implement riêng**, tách khỏi việc thiết
   kế schema DB. Nghĩa là schema `sections`/`chapters`/`chapter_words` có
   thể thiết kế và tạo bảng trước, nhưng UI đọc bài thật (`screen-03c`) vẫn
   phải chờ bước `.docx` riêng đó xong mới có dữ liệu để code.

Dựa trên các quyết định trên, viết tài liệu thiết kế DB mới
(`91_DB-design-new-model.md`) mô tả đầy đủ schema cho mô hình N-N bộ từ
điển (mặc định + cá nhân), Section/Chapter, và luồng ghi dữ liệu tra cứu
Online — theo Drift (đã chốt D3, [IMPL-007]). Đây **không phải bản thiết
kế DB tương đương file cũ đã xoá ở [IMPL-003]** (vốn mô tả schema hiện tại
đang chạy thật, mô hình cũ) — đây là thiết kế cho **định hướng mới chưa
code**, làm nền cho việc implement Section/Chapter và bộ từ điển cá nhân
sau này. Trả lời gián tiếp Q-CSB-02 (không tự chốt, nhưng thiết kế bảng đã
giả định "có triển khai" bộ từ điển cá nhân để có cơ sở thiết kế — vẫn cần
xác nhận lại 1 lần trước khi code UI 7 màn `screen-07*`).

### Tài liệu tạo mới / cập nhật

| File | Thay đổi |
|---|---|
| `docs/csb-vocab-analysis/91_DB-design-new-model.md` | **Mới** — thiết kế DB mô hình mới: bảng `dictionaries`/`word_dictionaries` (N-N, thay `chapters` cũ), `sections`/`chapters` (định nghĩa lại)/`chapter_words`, `personal_dictionaries`/`personal_dictionary_words`/`custom_words` (bộ từ điển cá nhân), ghi chú ràng buộc N-N xuyên 2 file DB, migration tóm tắt |
| `docs/csb-vocab-analysis/00_Overview.md` | Cập nhật mục "Trạng thái tra cứu Online/Offline" (API + lưu dữ liệu + xử lý lỗi mạng theo quyết định mới), mục Section/Chapter (ghi chú Q-CSB-07 dời bước riêng), thêm D4 vào bảng "Quyết định đã chốt", cập nhật mục "Câu hỏi mở" |
| `docs/csb-vocab-analysis/02_Search.md` | Viết lại mục "Chế độ Online" theo quyết định Free Dictionary API + LibreTranslate + `connectivity_plus` + không tự cache |
| `docs/csb-vocab-analysis/tasks/01-splash-photos-search-empty/01-analysis.md` | Cập nhật bảng câu hỏi mở: tách "Đã chốt" riêng, trỏ tới `91_DB-design-new-model.md` |

### Điểm chờ xác nhận còn mở

| # | Câu hỏi |
|---|---|
| Q-CSB-02 | Mockup "Từ điển của tôi" (7 màn `screen-07*`) — schema đã thiết kế giả định có triển khai, nhưng chưa tự chốt chính thức; cần xác nhận lại trước khi code UI |
| — | Xoá 1 từ khỏi bộ cá nhân có xoá luôn `custom_words` (nếu từ nguồn online không còn nằm trong bộ nào khác) hay giữ lại? Xem `91_DB-design-new-model.md` mục câu hỏi còn mở |
| — | Instance LibreTranslate cụ thể dùng public hay self-host — chưa chọn, ảnh hưởng độ ổn định/rate limit khi implement thật |

---

## [IMPL-012] 2026-07-18 — Tạo thư mục task riêng cho quy trình task-analysis/task-plan

**Người yêu cầu:** User · **Người thực hiện:** Claude

### Nội dung

Chuyển từ đặt file phân tích/kế hoạch task rời rạc kiểu `9x_*.md` phẳng
trong `docs/csb-vocab-analysis/` sang cấu trúc thư mục riêng theo task:
`docs/csb-vocab-analysis/tasks/<số>-<slug>/`, mỗi task có `01-analysis.md`
(task-analysis) và `02-plan.md` (task-plan), đánh số tiếp nếu có thêm bước
(brainstorm, v.v.). Giữ nguyên `docs/csb-vocab-analysis/00-07, 90` (tài
liệu phân tích màn hình cố định, không theo task).

Task đầu tiên áp dụng cấu trúc mới: `tasks/01-splash-photos-search-empty/`
— gộp phân tích tác động mốc mockup 01 (đối ứng Win/Mobile) và kế hoạch
implement phần đã chốt hẹp (ảnh thật Splash + trạng thái rỗng Tra cứu).

### Tài liệu tạo mới / xoá

| File | Thay đổi |
|---|---|
| `docs/csb-vocab-analysis/tasks/01-splash-photos-search-empty/01-analysis.md` | **Mới** — task-analysis (nội dung tương đương entry [IMPL-011] cũ, vốn không được ghi xuống đĩa thành công — viết lại lần này) |
| `docs/csb-vocab-analysis/tasks/01-splash-photos-search-empty/02-plan.md` | **Mới** — task-plan (chuyển từ `92_Plan-01-splash-photos-and-search-empty-state.md` đã xoá) |
| `docs/csb-vocab-analysis/92_Plan-01-splash-photos-and-search-empty-state.md` | **Xoá** — chuyển vào thư mục task ở trên |

### Điểm chờ xác nhận còn mở

Không phát sinh câu hỏi mới. Các câu hỏi mở của task 01 (bản quyền ảnh
CSB, Q-CSB-04..07) không đổi — xem `01-analysis.md`/`02-plan.md` trong thư
mục task mới.

---

## [IMPL-010] 2026-07-18 — Cập nhật mockup Windows (docs/artifact-design-windows/) theo định hướng mới

**Người yêu cầu:** User · **Người thực hiện:** Claude

### Nội dung

Áp cùng thay đổi đã làm cho mockup mobile ([IMPL-008]/[IMPL-009]) vào bản
Windows desktop (`docs/artifact-design-windows/`), giữ đúng ngôn ngữ layout
riêng của bản này (`nav-rail`, `page-header`, layout 2 cột
`pane-list`/`pane-detail` thay bottom nav/bottom sheet của mobile).

1. **Trạng thái Offline/Online** — thêm `.net-badge` vào `page-header` của
   `screen-02-tra-cuu.html` (Offline). Tạo `screen-02b-tra-cuu-online.html`:
   badge Online, `.net-note`, kết quả gắn `.source-tag` "Online" ở cả
   `pane-list` và `pane-detail`.
2. **Trạng thái chưa tìm kiếm — slide ảnh CSB** — tạo
   `screen-02c-tra-cuu-trong.html`: slide 3 ảnh (tái dùng từ
   `docs/artifact-design/assets/images/`, copy sang
   `docs/artifact-design-windows/assets/images/`) chiếm toàn bộ
   `page-content` (khác mobile — không có `pane-list`/`pane-detail` khi ở
   trạng thái này), autoplay bằng cùng đoạn `<script>` minh hoạ.
3. **Section → Chapter dạng bài báo** — thay `screen-03-hoc-danh-sach-
   chuong.html` bằng `screen-03-hoc-danh-sach-section.html` (danh sách
   Section trong `pane-list`, gợi ý trong `pane-detail-empty`); thay
   `screen-03b-hoc-danh-sach-tu-a-z.html` bằng `screen-03b-hoc-danh-sach-
   chapter.html` (danh sách Chapter dùng `.lesson-list` mới trong
   `pane-list`); thêm `screen-03c-hoc-noi-dung-bai.html` — khác biệt so với
   mobile: giữ layout 2 cột, `pane-list` bên trái vẫn hiện danh sách Chapter
   để chuyển bài nhanh, `pane-detail` bên phải là nội dung bài
   (`.article-*`). Xoá 2 file cũ.
4. **`screen-07-tu-dien-cua-toi.html`** — đổi "Giáo trình (6 chương)" →
   "Giáo trình (mặc định)", bổ sung câu giải thích duyệt theo bộ mặc định
   nay cũng ở đây.
5. **`index.html`** — cập nhật/thêm thẻ 02/02b/02c/03/03b/03c/07, thêm đoạn
   banner "Định hướng mới — chưa code" vào masthead.
6. **`styles.css`** — thêm class mới tương ứng bản mobile nhưng theo kích
   thước/khoảng cách desktop: `.net-badge`, `.net-note`, `.source-tag`,
   `.search-empty` (+ `.slide`/`.slide-caption`/`.dots`), `.lesson-list`/
   `.lesson-row`, `.article-wrap`/`.article-title`/`.article-body`/
   `.vocab-hl`. Không sửa class cũ đang dùng ở màn khác.

Toàn bộ màn mới/sửa đều ghi banner "⚠️ Định hướng mới — chưa code" trong
`frame-desc`, nhất quán với bản mobile.

### Tài liệu đã cập nhật

| File | Thay đổi |
|---|---|
| `docs/artifact-design-windows/screens/screen-02-tra-cuu.html` | Thêm badge Offline, sửa link điều hướng |
| `docs/artifact-design-windows/screens/screen-02b-tra-cuu-online.html` | **Mới** — trạng thái Online |
| `docs/artifact-design-windows/screens/screen-02c-tra-cuu-trong.html` | **Mới** — trạng thái chưa tìm kiếm, slide ảnh CSB |
| `docs/artifact-design-windows/screens/screen-03-hoc-danh-sach-section.html` | **Mới** — thay `screen-03-hoc-danh-sach-chuong.html` (đã xoá) |
| `docs/artifact-design-windows/screens/screen-03b-hoc-danh-sach-chapter.html` | **Mới** — thay `screen-03b-hoc-danh-sach-tu-a-z.html` (đã xoá) |
| `docs/artifact-design-windows/screens/screen-03c-hoc-noi-dung-bai.html` | **Mới** — bài đọc dạng article, layout 2 cột |
| `docs/artifact-design-windows/screens/screen-01-splash.html` | Sửa link cuối trang trỏ sang 02c |
| `docs/artifact-design-windows/screens/screen-04-chi-tiet-tu.html` | Sửa link điều hướng trỏ về 03c |
| `docs/artifact-design-windows/screens/screen-07-tu-dien-cua-toi.html` | Bỏ nhắc "6 chương" cứng |
| `docs/artifact-design-windows/index.html` | Cập nhật/thêm thẻ màn hình, banner định hướng mới |
| `docs/artifact-design-windows/styles.css` | Thêm class mới cho badge mạng, danh sách bài học, bài đọc article |
| `docs/artifact-design-windows/assets/images/csb-slide-01/02/03.jpg` | **Mới** — copy từ `docs/artifact-design/assets/images/` |

### Điểm chờ xác nhận còn mở

Không phát sinh câu hỏi mới — cùng các điểm mở đã ghi ở [IMPL-005]/[IMPL-009].
Bộ mobile và Windows nay đồng bộ hoàn toàn về nội dung định hướng mới, chỉ
khác khung layout theo đúng quy ước đã có của từng bộ.

---

## [IMPL-009] 2026-07-18 — Thêm trạng thái "chưa tìm kiếm" cho màn Tra cứu (slide ảnh CSB)

**Người yêu cầu:** User · **Người thực hiện:** Claude

### Nội dung

Bổ sung 1 trạng thái nữa cho màn Tra cứu (SCR-02, mockup) — khi vừa vào màn,
chưa gõ gì, hiện slide ảnh Cảnh sát biển Việt Nam tự động lướt qua lại
(autoplay carousel), có dots chỉ báo cùng ngôn ngữ thị giác với màn Splash
(01). Trước đây trạng thái rỗng chỉ có gợi ý dạng chữ đơn giản (`_Hint`,
theo mô tả trong `02_Search.md` mục code thật) — mockup nay minh hoạ thêm
phương án trực quan hơn.

Nguồn ảnh: 3 ảnh do user cung cấp từ
`C:\Users\anhnt\Desktop\csb\ẢNH LÀM PHẦN MỀM\slide\` — 2 ảnh diễu binh đội
danh dự Cảnh sát biển và 1 ảnh trụ sở Bộ Tư lệnh Cảnh sát biển Việt Nam.
Copy vào `docs/artifact-design/assets/images/` (đặt tên lại
`csb-slide-01/02/03.jpg`, kể cả file gốc `.jfif` cũng đổi đuôi `.jpg` vì
cùng là dữ liệu JPEG) để mockup tự chứa, không phụ thuộc đường dẫn ngoài
repo.

Tạo màn mới `screen-02c-tra-cuu-trong.html`, chèn vào **trước** 02 trong
luồng điều hướng (01 Splash → 02c chưa tìm kiếm → 02 có kết quả → 02b
online). CSS carousel (`.search-empty`, `.slide`, `.dots` dùng lại) thêm vào
`styles.css`, có đoạn `<script>` nhỏ chỉ để minh hoạ hiệu ứng autoplay trong
mockup tĩnh — không phải code thật, không đại diện cho cách Flutter sẽ cài
đặt animation này.

### Tài liệu đã cập nhật

| File | Thay đổi |
|---|---|
| `docs/artifact-design/screens/screen-02c-tra-cuu-trong.html` | **Mới** — trạng thái chưa tìm kiếm, slide ảnh CSB autoplay |
| `docs/artifact-design/screens/screen-02-tra-cuu.html` | Sửa link điều hướng, cập nhật mô tả nhắc tới 02c |
| `docs/artifact-design/screens/screen-01-splash.html` | Sửa link cuối trang trỏ sang 02c thay vì 02 |
| `docs/artifact-design/index.html` | Thêm thẻ 02c |
| `docs/artifact-design/styles.css` | Thêm `.search-empty`, `.slide`, `.slide-caption`, dùng lại `.dots` |
| `docs/artifact-design/assets/images/csb-slide-01/02/03.jpg` | **Mới** — 3 ảnh CSB do user cung cấp |

### Điểm chờ xác nhận còn mở

Không phát sinh câu hỏi mới. Lưu ý: ảnh dùng ở đây (diễu binh đội danh dự,
trụ sở Bộ Tư lệnh) khác nội dung với `assets/csb-logo.png` đang dùng cho
theme màu app — chưa xác nhận ảnh này có được dùng chính thức trong app thật
(bản quyền/nguồn ảnh) hay chỉ minh hoạ ý tưởng bố cục cho mockup.

---

## [IMPL-008] 2026-07-18 — Cập nhật mockup mobile (docs/artifact-design/) theo định hướng mới

**Người yêu cầu:** User · **Người thực hiện:** Claude

### Nội dung

Lan tỏa định hướng mới ([IMPL-005]/[IMPL-006]) vào mockup HTML tĩnh mobile
(`docs/artifact-design/`) — Windows (`docs/artifact-design-windows/`) chưa
làm, để ở bước riêng theo yêu cầu.

1. **Trạng thái Offline/Online ở màn Tra cứu** — thêm chỉ báo mạng
   (`.net-badge`) trên appbar của `screen-02-tra-cuu.html` (Offline).
   Tạo mới `screen-02b-tra-cuu-online.html`: badge Online, banner giải
   thích, và 2 kết quả mẫu gắn nhãn nguồn "Online" (`.source-tag`) cho từ
   không có trong CSDL local.
2. **Section → Chapter dạng bài báo** — thay hoàn toàn luồng "danh sách
   chương → danh sách từ A-Z" cũ bằng 3 màn mới: `screen-03-hoc-danh-sach-
   section.html` (danh sách Section, tái dùng `.chapter-list`), `screen-03b-
   hoc-danh-sach-chapter.html` (danh sách Chapter/bài học trong 1 Section,
   layout mới `.lesson-list`/`.lesson-row`), `screen-03c-hoc-noi-dung-
   bai.html` (bài đọc dạng article — `.article-*`, từ vựng highlight lồng
   trong đoạn văn bằng `.vocab-hl`, bấm vào mở chung `WordDetailSheet` với
   màn 04). **Xoá** 2 file cũ `screen-03-hoc-danh-sach-chuong.html` và
   `screen-03b-danh-sach-tu-a-z.html` (đã hỏi ý kiến — không giữ song song
   để tránh 2 mô hình mâu thuẫn cùng tồn tại trong mockup).
3. **Duyệt theo bộ từ điển mặc định chuyển hẳn sang tab "Từ điển của tôi"**
   (quyết định của user) — tab "Học" từ nay chỉ còn Section/Chapter dạng bài
   báo, không có đường vào khác để browse từ theo bộ mặc định. Cập nhật
   `screen-07-tu-dien-cua-toi.html`: bỏ nhắc cứng "6 chương", đổi tên thẻ
   "Giáo trình (6 chương)" → "Giáo trình (mặc định)", làm rõ quan hệ N-N.
4. **`index.html`** — cập nhật thẻ 02/03/07, thêm thẻ 02b/03c, thêm đoạn
   banner "Định hướng mới — chưa code" vào masthead.
5. **`styles.css`** — thêm class mới: `.net-badge`, `.net-note`,
   `.source-tag` (trạng thái mạng); `.lesson-list`/`.lesson-row` (danh sách
   Chapter); `.article-wrap`/`.article-title`/`.article-body`/`.vocab-hl`
   (bài đọc dạng article). Không sửa class cũ đang dùng ở màn khác.

Toàn bộ màn mới/sửa đều ghi rõ banner "⚠️ Định hướng mới — chưa code" trong
`frame-desc`, trỏ về `docs/csb-vocab-analysis/00_Overview.md` và
`docs/spec_history.md` — nhất quán với cách đã làm ở [IMPL-006] cho tài liệu
phân tích.

### Tài liệu đã cập nhật

| File | Thay đổi |
|---|---|
| `docs/artifact-design/screens/screen-02-tra-cuu.html` | Thêm badge Offline, sửa link điều hướng cuối trang |
| `docs/artifact-design/screens/screen-02b-tra-cuu-online.html` | **Mới** — trạng thái Online |
| `docs/artifact-design/screens/screen-03-hoc-danh-sach-section.html` | **Mới** — thay `screen-03-hoc-danh-sach-chuong.html` (đã xoá) |
| `docs/artifact-design/screens/screen-03b-hoc-danh-sach-chapter.html` | **Mới** — thay `screen-03b-danh-sach-tu-a-z.html` (đã xoá) |
| `docs/artifact-design/screens/screen-03c-hoc-noi-dung-bai.html` | **Mới** — bài đọc dạng article |
| `docs/artifact-design/screens/screen-04-chi-tiet-tu.html` | Sửa link điều hướng trỏ về 03c thay vì 03b cũ |
| `docs/artifact-design/screens/screen-07-tu-dien-cua-toi.html` | Bỏ nhắc "6 chương" cứng, đổi tên thẻ bộ mặc định |
| `docs/artifact-design/index.html` | Cập nhật/thêm thẻ màn hình, thêm banner định hướng mới |
| `docs/artifact-design/styles.css` | Thêm class mới cho badge mạng, danh sách bài học, bài đọc article |

### Điểm chờ xác nhận còn mở

Không phát sinh câu hỏi mới — mockup minh hoạ trực quan cho Q-CSB-04..07 đã
ghi ở [IMPL-005], chưa tự ý chốt các điểm đó (ví dụ: API cụ thể, có lưu từ
tra online hay không, cách trích xuất `.docx`). `docs/artifact-design-
windows/` (bản Windows) **chưa cập nhật** — làm ở bước sau theo yêu cầu.

---

## [IMPL-007] 2026-07-18 — Chốt dùng Drift thay cho sqlite3 raw cho schema mới

**Người yêu cầu:** User · **Người thực hiện:** Claude

### Nội dung

Trao đổi về việc truy vấn SQLite sẽ phức tạp hơn khi thêm bộ từ điển N-N,
Section/Chapter, và các truy vấn ôn tập mở rộng trong tương lai — có nên gọi
`sqlite3` trực tiếp hay qua một lớp nữa, và có cần ORM không.

**Đã chốt:** chuyển sang **Drift** (type-safe query builder + code gen cho
SQLite trên Flutter, dùng `build_runner`) thay cho gọi `sqlite3` package
trực tiếp như hiện tại (`lib/data/local/vocab_database.dart`,
`user_database.dart`). Áp dụng **ngay từ bước thiết kế schema mới** (bảng
N-N `word_dictionaries`, Section/Chapter), không chờ đổi sau — chấp nhận chi
phí viết lại data layer hiện tại một lần thay vì đổi 2 lần (raw → raw mới →
Drift). Việc dùng Repository pattern làm lớp trung gian (đã có sẵn qua
`VocabRepository`) vẫn giữ nguyên — Drift không thay thế Repository, mà thay
thế cách Repository nói chuyện với SQLite bên trong.

Lý do chính: schema dự kiến đổi nhiều lần trong thời gian ngắn (N-N bộ từ
điển, Section/Chapter dạng bài báo, có thể thêm bảng ôn tập mở rộng sau) —
Drift cho type-safe query + migration kiểm tra được lúc compile, giảm rủi ro
lỗi runtime khi cột/bảng đổi so với viết SQL string tay.

### Tài liệu đã cập nhật

| File | Thay đổi |
|---|---|
| `docs/csb-vocab-analysis/00_Overview.md` | Thêm ghi chú Drift vào mục Dữ liệu (Kiến trúc kỹ thuật); thêm dòng D3 vào bảng "Quyết định đã chốt" |

### Điểm chờ xác nhận còn mở

Không phát sinh câu hỏi mới. Việc thiết kế schema Drift cụ thể (bảng, cột,
migration) sẽ làm ở bước implement sau, sau khi Q-CSB-04..07 ([IMPL-005])
được trả lời.

---

## [IMPL-006] 2026-07-18 — Lan tỏa định hướng mới vào 02_Search.md, 03_Lessons-by-chapter.md, bảng truy vết

**Người yêu cầu:** User · **Người thực hiện:** Claude

### Nội dung

Tiếp nối [IMPL-005] (chốt định hướng mới ở `00_Overview.md`), cập nhật các
tài liệu phân tích màn hình còn lại theo cùng định hướng — tra cứu 2 trạng
thái Offline/Online, bộ từ điển N-N (mặc định + cá nhân), Section chứa nhiều
Chapter hiển thị dạng bài báo. Nguyên tắc áp dụng: **giữ nguyên nội dung mô
tả code thật hiện có**, chỉ gắn nhãn `[ĐÃ CODE]` rõ ràng, và thêm phần mới
riêng biệt mô tả định hướng `[CHƯA CODE]` — không xoá hay viết đè thông tin
về hành vi thật đang chạy.

1. **`02_Search.md`** — tách "Hành vi"/"Truy vấn dữ liệu"/"Phụ thuộc" hiện
   có thành "...— Chế độ Offline [ĐÃ CODE]"; thêm mục mới "Chế độ Online —
   định hướng mới [CHƯA CODE]" mô tả cơ chế phát hiện mạng, hành vi gọi
   thêm API ngoài, câu hỏi về lưu từ mới tra được, và ảnh hưởng tới
   `searchProvider`/`VocabRepository`.
2. **`03_Lessons-by-chapter.md`** — đây là thay đổi mô hình lớn nhất: khái
   niệm "chương" (nhóm từ, 1-N) sẽ trở thành "bộ từ điển mặc định"; "Chapter"
   được định nghĩa lại thành 1 bài học dạng bài báo, nằm trong "Section" (cấp
   mới). Thêm mục "Mô hình mới: Section / Chapter dạng bài báo [CHƯA CODE]"
   với bảng đối chiếu ý nghĩa cũ/mới, hành vi điều hướng dự kiến (tối thiểu
   3 cấp: Section → Chapter → nội dung bài), và ảnh hưởng tầng dữ liệu
   (`chapter_words`, quy trình từ `.docx`). Ghi rõ đây **không phải chỉnh
   sửa nhỏ** — màn hình sẽ cần viết lại gần như hoàn toàn khi mô hình mới
   được code.
3. **`90_Traceability-matrix.md`** — thêm banner nói rõ bảng phản ánh code
   thật (mô hình cũ); thêm 2 dòng vào bảng "Truy vết mockup ↔ code" cho 2
   khoảng cách mới (tra cứu online, Section/Chapter dạng bài báo).
4. **`README.md`** — nâng phiên bản lên 1.2, thêm banner định hướng mới ở
   đầu trỏ tới `00_Overview.md`, cập nhật dòng lịch sử.

### Tài liệu đã cập nhật

| File | Thay đổi |
|---|---|
| `docs/csb-vocab-analysis/02_Search.md` | Gắn nhãn `[ĐÃ CODE]` cho hành vi hiện tại; thêm mục "Chế độ Online — định hướng mới [CHƯA CODE]" |
| `docs/csb-vocab-analysis/03_Lessons-by-chapter.md` | Gắn nhãn `[ĐÃ CODE]` cho mô hình cũ; thêm mục "Mô hình mới: Section / Chapter dạng bài báo [CHƯA CODE]" |
| `docs/csb-vocab-analysis/90_Traceability-matrix.md` | Thêm banner cảnh báo phạm vi; thêm 2 dòng khoảng cách mockup↔code mới |
| `docs/csb-vocab-analysis/README.md` | Nâng phiên bản 1.2, thêm banner định hướng mới, cập nhật lịch sử |

### Điểm chờ xác nhận còn mở

Không phát sinh câu hỏi mở mới — vẫn dùng Q-CSB-04..07 đã ghi ở [IMPL-005].
Xem thêm ghi chú trong `03_Lessons-by-chapter.md` mục "Hành vi dự kiến": vị
trí chính xác của "duyệt theo bộ từ điển mặc định" trong điều hướng chính
(tab nào) chưa chốt, cần rà soát cùng `07_Home-shell.md` và mockup "Từ điển
của tôi" khi bước sang cập nhật `docs/artifact-design/`.

---

## [IMPL-005] 2026-07-18 — Định hướng mới: tra cứu online/offline, bộ từ điển N-N, Section/Chapter dạng bài báo

**Người yêu cầu:** User · **Người thực hiện:** Claude

### Nội dung

User đưa ra định hướng mở rộng đáng kể so với code thật hiện tại (chưa
triển khai, mới cập nhật tài liệu phân tích):

1. **Tra cứu 2 trạng thái** — Offline: chỉ `vocab.db` local (giữ nguyên hành
   vi hiện tại). Online: `vocab.db` local **+** gọi thêm API từ điển ngoài
   cho từ không có sẵn. Ràng buộc "Offline hoàn toàn" đổi thành
   "Offline-first, online tùy chọn" — toàn bộ tính năng cốt lõi vẫn phải
   chạy được không cần mạng.
2. **Bộ từ điển (dictionary), quan hệ N-N với từ** — khái niệm "chương" hiện
   tại (bảng `chapters`, 6 chương cố định, quan hệ 1-N với từ qua
   `chapter_id`) được diễn giải lại thành **1 bộ từ điển mặc định**. Một từ
   có thể thuộc **nhiều** bộ từ điển cùng lúc (cần bảng trung gian N-N thay
   cột `chapter_id` đơn). 2 loại: mặc định (đóng gói sẵn, read-only) và cá
   nhân (user tự tạo **nhiều** bộ, tự thêm/bỏ từ — giống playlist, xác nhận
   lại hướng đã có ở mockup cũ Q-CSB-02).
3. **Section → Chapter, Chapter là bài học dạng bài báo** — Section là cấp
   mới, đứng trên Chapter (1 Section nhiều Chapter). Chapter được định nghĩa
   lại: không còn là nhóm từ vựng (vai trò đó nay thuộc "bộ từ điển mặc
   định" ở mục 2) mà là **1 bài học hiển thị dạng bài báo/bài đọc chuyên
   ngành**, từ vựng lồng trong nội dung bài thay vì liệt kê trần. Nguồn nội
   dung hiện là file Word (`.docx`).

Đây là **thay đổi mô hình dữ liệu + kiến trúc lớn**, ảnh hưởng dây chuyền
tới `vocab.db` schema, `VocabRepository`, các provider, và toàn bộ UI của
SCR-02 (Tra cứu) và SCR-03 (Học theo chương). Bước này **chỉ cập nhật
`00_Overview.md`** để chốt khung khái niệm chung; các file `01`–`07` và
`docs/artifact-design/` sẽ cập nhật ở bước kế tiếp theo yêu cầu của user.

### Tài liệu đã cập nhật

| File | Thay đổi |
|---|---|
| `docs/csb-vocab-analysis/00_Overview.md` | Thêm banner định hướng mới ở đầu file; thêm mục "Mô hình dữ liệu — định hướng mới" (trạng thái online/offline, bộ từ điển N-N, Section/Chapter); cập nhật Ràng buộc, Glossary, Câu hỏi mở |

### Điểm chờ xác nhận còn mở

| # | Câu hỏi |
|---|---|
| Q-CSB-04 | API từ điển ngoài dùng khi online là nhà cung cấp nào cụ thể (Oxford, Free Dictionary API, Google...)? Ảnh hưởng chi phí, giới hạn rate, và cách xử lý lỗi mạng chập chờn. |
| Q-CSB-05 | Từ tra được qua API ngoài khi online có được lưu lại vào DB local để dùng khi offline không? Nếu có, lưu vào bộ từ điển nào (mặc định hay tự tạo 1 bộ "đã tra online" riêng)? |
| Q-CSB-06 | Cơ chế phát hiện trạng thái online/offline dùng gói nào (`connectivity_plus`?) và có xử lý trường hợp "có kết nối mạng nhưng API đích không phản hồi" (khác với offline hẳn) không? |
| Q-CSB-07 | Quy trình chuyển nội dung bài học từ file Word (`.docx`) sang dữ liệu có cấu trúc (Section → Chapter → nội dung bài + từ vựng liên kết) sẽ làm thủ công, bán tự động (script + soát lại), hay tự động hoàn toàn? Ảnh hưởng trực tiếp tới việc có tách bảng `chapter_words` riêng hay suy ra từ nội dung bài lúc hiển thị. |

---

## [IMPL-004] 2026-07-18 — Tách tài liệu nguồn (docx/pdf) ra khỏi assets/

**Người yêu cầu:** User · **Người thực hiện:** Claude

### Nội dung

`assets/` trước đây lẫn giữa tài nguyên runtime thật (những gì
`pubspec.yaml` đóng gói vào app: `db/vocab.db`, cộng `images/words/` dự
phòng) và tài liệu nguồn chỉ dùng lúc biên soạn dữ liệu
(`TA_chuyen_nganh.docx`, `TA_chuyen_nganh_2.pdf`, `Tu_dien.pdf`) — không file
nào trong 3 file này được `pubspec.yaml` khai báo hay code Dart đọc.

Chuyển 3 file đó (bằng `git mv`, giữ lịch sử) sang
`docs/source-materials/`, kèm `README.md` giải thích. **Giữ nguyên
`assets/csb-logo.png` trong `assets/`** theo yêu cầu — dù cũng chưa được
`pubspec.yaml` khai báo, logo có thể dùng làm app icon/splash chính thức
trong tương lai nên hợp lý để gần code hơn là tài liệu tham khảo thuần tuý.

### Tài liệu đã cập nhật / tạo mới

| File | Thay đổi |
|---|---|
| `assets/README.md` | Viết lại — chỉ liệt kê tài nguyên runtime thật, ghi rõ file nào chưa khai báo trong `pubspec.yaml` |
| `docs/source-materials/README.md` | Tạo mới — giải thích 3 file tài liệu nguồn vừa chuyển tới |

---

## [IMPL-003] 2026-07-18 — Xoá tài liệu thiết kế DB, đổi tên file phân tích sang tiếng Anh

**Người yêu cầu:** User · **Người thực hiện:** Claude

### Nội dung

1. **Xoá `docs/03-thiet-ke-co-so-du-lieu.md`** (tạo ở [IMPL-002] mục 7) theo
   yêu cầu trực tiếp — nội dung schema `vocab.db`/`user.db` + cơ chế SM-2
   **không được chuyển đi đâu khác**, chỉ còn suy ra được từ code thật
   (`lib/data/local/`, `lib/domain/srs/srs_scheduler.dart`).
2. **Đổi tên toàn bộ file trong `docs/csb-vocab-analysis/` sang tiếng Anh**
   (giữ nguyên nội dung tiếng Việt bên trong, chỉ đổi tên file) — xem bảng
   đối chiếu trong `docs/csb-vocab-analysis/README.md`.
3. Cập nhật mọi liên kết ở `README.md`, `docs/README.md`, `assets/README.md`
   trỏ tới file đã xoá — trỏ sang `docs/csb-vocab-analysis/` hoặc thẳng vào
   file code nguồn thay thế.

### Điểm chờ xác nhận còn mở

| # | Câu hỏi |
|---|---|
| Q-CSB-03 | Tài liệu thiết kế DB cho báo cáo bàn giao (mục 3 trong `docs/README.md`) hiện chưa có bản nháp nào — cần viết lại khi nào, và có cần giữ định dạng cũ (bảng schema, sơ đồ quan hệ, công thức SM-2) hay chỉ cần bản tóm tắt ngắn? |

---

## [IMPL-002] 2026-07-18 — Tái cấu trúc thư mục dự án + bổ sung tài liệu phân tích

**Người yêu cầu:** User · **Người thực hiện:** Claude

### Nội dung

Dọn dẹp cấu trúc repo sau khi phần khung ứng dụng (Giai đoạn 0–1) đã ổn định:

1. **Đưa project Flutter ra khỏi lớp `src/` trung gian** — `csb-vocab-app/` giờ
   là project Flutter chạy trực tiếp (`flutter run`/`flutter build` từ root),
   không cần `cd src/` trước.
2. **Xoá `plan/`** (7 file đặc tả ban đầu — yêu cầu chức năng, kiến trúc, thiết
   kế dữ liệu, roadmap, Q&A chốt) vì nội dung đã lỗi thời so với code thật và
   được thay thế bởi tài liệu trong `docs/` (thiết kế DB, mockup UI) cùng
   thư mục phân tích mới `docs/csb-vocab-analysis/`.
3. **Xoá `tools/pdf_to_sqlite/`** (script Python parse PDF → `vocab.db`) — đã
   chạy xong, `vocab.db` sinh ra đã đóng gói sẵn trong `assets/db/`, không cần
   giữ script trong repo ứng dụng.
4. **Xoá `test/`** (unit test SM-2 scheduler + widget smoke test) theo yêu cầu
   trực tiếp của user.
5. **Thêm `.claude/skills/`** — copy các skill Flutter/quản lý task dùng
   chung từ một project khác (`Sato/agent`): `app-flutter-skill`,
   `business-logic-flow`, `context-engineering`, `project-context`,
   `task-analysis`, `task-brainstorm`, `task-implement`,
   `task-implement-app`, `task-manager-project`, `task-plan`.
6. **Thêm mockup UI tĩnh** cho cả mobile (`docs/artifact-design/`) và Windows
   desktop (`docs/artifact-design-windows/`) — 13 màn/bản, dùng bảng màu lấy
   trực tiếp từ `assets/csb-logo.png` (xem
   `docs/artifact-design/bang-mau-ung-dung.md`). **Lưu ý:** mockup này đã đi
   trước code thật một bước — có tính năng mới chưa code (bộ từ điển cá nhân,
   ôn tập trộn 3 dạng câu) và đổi cấu trúc điều hướng (gộp "Ôn tập" vào "Từ
   điển của tôi", bỏ chế độ flashcard học-từ-mới ở màn Học). Xem
   `docs/csb-vocab-analysis/README.md` mục trạng thái để phân biệt phần đã
   code với phần mới ở mockup.
7. **Thêm `docs/03-thiet-ke-co-so-du-lieu.md`** — tài liệu thiết kế DB viết
   lại theo đúng schema thực tế của `vocab.db`/`user.db` (khác với bản kế
   hoạch ban đầu trong `plan/04-thiet-ke-du-lieu.md`, vốn có vài chỗ lệch so
   với lúc triển khai thật).
8. **Thêm `docs/csb-vocab-analysis/`** (entry này) — phân tích từng màn hình
   *đã code thật* trong `lib/features/`, theo format rút gọn từ
   `Sato/agent/docs/cloud-print-analysis/` (bỏ phần vai trò nhiều tầng/Web
   admin vì csb-vocab-app là app 1 người dùng, offline, không backend).

### Tài liệu tạo mới

| File | Nội dung |
|---|---|
| `docs/03-thiet-ke-co-so-du-lieu.md` | Schema `vocab.db`/`user.db` thực tế + cơ chế SM-2. **Đã xoá ở [IMPL-003].** |
| `docs/artifact-design/` | Mockup UI mobile, 13 màn, + ảnh chụp + PDF gộp |
| `docs/artifact-design-windows/` | Mockup UI Windows desktop, 13 màn tương ứng |
| `docs/csb-vocab-analysis/README.md` | Tổng quan + bảng danh sách màn hình đã code |
| `docs/csb-vocab-analysis/00_Tong-quan.md` | Bối cảnh, kiến trúc, ràng buộc, glossary. **Đổi tên thành `00_Overview.md` ở [IMPL-003].** |
| `docs/csb-vocab-analysis/01..07_*.md` | Phân tích từng màn hình thật. **Đổi tên sang tiếng Anh ở [IMPL-003]** (xem `docs/csb-vocab-analysis/README.md`) |
| `docs/csb-vocab-analysis/90_Bang-truy-vet.md` | Truy vết FR ↔ màn hình ↔ file code. **Đổi tên thành `90_Traceability-matrix.md` ở [IMPL-003].** |

### Điểm chờ xác nhận còn mở

| # | Câu hỏi |
|---|---|
| Q-CSB-01 | FR-6 không xuất hiện trong bất kỳ comment code nào (FR-1, 2, 3, 4, 5, 7 đều có) — số hiệu này có từng được gán cho một yêu cầu đã bỏ/gộp trong `plan/` cũ không, hay chỉ là khoảng trống trong đánh số gốc? Không thể xác minh vì `plan/` đã bị xoá ở mục 2. |
| Q-CSB-02 | Mockup (`docs/artifact-design/`) đã thiết kế "Từ điển của tôi" (bộ từ vựng cá nhân, 3 kiểu ôn trộn lẫn) và bỏ segmented control Học theo chương/Từ mới — có chốt triển khai code theo đúng hướng mockup này không, hay mockup chỉ mang tính tham khảo? |

---

## [SPEC-BASE] (không rõ ngày — trước phiên làm việc này) — Spec gốc

Đặc tả ban đầu từng nằm ở `plan/00-tong-quan.md` → `plan/06-cau-hoi-can-chot.md`
(đã xoá ở [IMPL-002] mục 2). Tóm tắt còn giữ lại được qua comment trong code:
ứng dụng học từ vựng chuyên ngành Cảnh sát biển Việt Nam, offline-first,
Windows → Android → iOS, SQLite (`vocab.db` read-only + `user.db` read-write),
ôn tập theo thuật toán SM-2 (Phương án A đã chốt tại Q&A 06, xem
`docs/03-thiet-ke-co-so-du-lieu.md` mục 3).
