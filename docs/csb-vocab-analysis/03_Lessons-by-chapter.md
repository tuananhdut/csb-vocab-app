# SCR-03 — Học theo chương

**FR:** FR-3 · **Trạng thái:** ✅ Đã code xong (mô hình "chương = nhóm từ") · **Nguồn:** `lib/features/lessons/lessons_screen.dart`

> ⚠️ **Định hướng mới — chưa code, đổi mô hình khái niệm** (xem
> `00_Overview.md` mục "Mô hình dữ liệu — định hướng mới",
> `docs/spec_history.md` [IMPL-005] Q-CSB-07): khái niệm **"chương"** mô tả
> trong file này (nhóm từ vựng, bảng `chapters` trong `vocab.db`) sẽ được
> **diễn giải lại thành "bộ từ điển mặc định"**. Cấp **"Chương" (Chapter)**
> sẽ mang ý nghĩa mới: **1 bài học dạng bài báo/bài đọc**, nằm trong 1
> **Section** (cấp mới, đứng trên Chapter). Mục **Hành vi**, **Truy vấn dữ
> liệu**, **Phụ thuộc** bên dưới mô tả đúng code thật hôm nay theo mô hình
> **cũ**. Mục **Mô hình mới: Section / Chapter dạng bài báo** ở cuối file mô
> tả định hướng chưa triển khai — **màn hình này gần như sẽ phải viết lại
> hoàn toàn** khi mô hình mới được chốt và code, không phải chỉnh sửa nhỏ.

## Mục đích

Duyệt từ vựng theo cấu trúc chương của giáo trình gốc — khác Tra cứu (tự do
gõ tìm), đây là duyệt tuần tự theo chủ đề chuyên môn.

## Hành vi — mô hình cũ ("chương" = nhóm từ) [ĐÃ CODE]

Gồm 2 widget lồng nhau (điều hướng bằng `Navigator.push`, không phải route
`go_router` riêng):

1. **`LessonsScreen`** (danh sách chương): `chaptersProvider` trả về
   `List<Chapter>`, hiện dạng `ListTile` — `CircleAvatar` số thứ tự chương +
   tên chương + số từ (`subtitle`) + mũi tên phải. Bấm vào 1 chương →
   `Navigator.push` sang `ChapterWordsScreen`.
2. **`ChapterWordsScreen`** (từ trong 1 chương): nhận `Chapter` qua
   constructor, `chapterWordsProvider(chapter.id)` trả về `List<VocabWord>`
   của đúng chương đó, hiện bằng `WordTile` (dùng chung với Tra cứu, nhưng
   `showChapter: false` vì chương đã hiển nhiên từ AppBar).

Bấm vào 1 từ trong `ChapterWordsScreen` → mở `WordDetailSheet` — **cùng
component** với Tra cứu (SCR-02), không phải bản riêng.

## Truy vấn dữ liệu — mô hình cũ [ĐÃ CODE]

- `VocabRepository.chapters()` — `SELECT` từ bảng `chapters`, kèm subquery
  đếm `COUNT(*)` số từ mỗi chương, sắp theo `chapter_no`.
- `VocabRepository.wordsByChapter(chapterId, includeSub: true)` — lọc theo
  `chapter_id`, sắp `is_subentry` trước rồi mới `word_lower` (mục từ gốc lên
  trước, subentry/cụm liên quan xếp ngay sau).

6 chương thật trong `vocab.db` hiện tại: Quân sự chung, Hàng hải, Thông tin ra
đa, Vũ khí, Cơ điện, Cảnh sát biển. Theo mô hình mới, 6 nhóm này sẽ trở thành
6 **bộ từ điển mặc định** (xem mục dưới).

## Phụ thuộc — mô hình cũ [ĐÃ CODE]

- `chaptersProvider`, `chapterWordsProvider` (`lib/data/repositories/vocab_providers.dart`).
- `WordTile`, `showWordDetail` (chung với SCR-02).

## Mô hình mới: Section / Chapter dạng bài báo [CHƯA CODE]

> Nguồn: `00_Overview.md` mục "Mô hình dữ liệu — định hướng mới",
> `docs/spec_history.md` [IMPL-005] Q-CSB-07.

### Đổi ý nghĩa khái niệm

| Khái niệm | Ý nghĩa cũ (code thật) | Ý nghĩa mới (định hướng) |
|---|---|---|
| "Chương" hiện tại (bảng `chapters`, `chapter_id` trên từ) | Nhóm từ vựng theo chủ đề, 1-N với từ | Trở thành **bộ từ điển mặc định** — xem `00_Overview.md`; quan hệ với từ đổi từ 1-N (`chapter_id`) sang N-N (bảng trung gian `word_dictionaries`) |
| Section | *(không tồn tại)* | Cấp mới, đứng **trên** Chapter — 1 Section chứa nhiều Chapter |
| Chapter | *(= "chương" cũ, xem dòng trên)* | Định nghĩa lại: **1 bài học dạng bài báo/bài đọc** chuyên ngành, không phải nhóm từ |

### Hành vi dự kiến (chưa chốt UI cụ thể)

- Màn danh sách hiện tại (`LessonsScreen` → `ChapterWordsScreen`, list chương
  → list từ A-Z) sẽ đổi thành **ít nhất 3 cấp điều hướng**: danh sách Section
  → danh sách Chapter trong Section → nội dung bài học (Chapter) dạng bài
  báo. Đây là thay đổi cấu trúc, không phải thêm field — `ChapterWordsScreen`
  hiện tại (hiển thị `WordTile` dạng list phẳng) **không còn phù hợp** làm
  màn hiển thị nội dung Chapter mới; cần widget đọc bài (văn bản dài, có thể
  cuộn) thay vì `ListView` các `WordTile`.
- Từ vựng xuất hiện **lồng trong nội dung bài** (Chapter) thay vì liệt kê
  trần — cách liên kết từ ↔ vị trí trong bài (ví dụ: từ được gạch chân/tô
  màu, bấm vào mở `WordDetailSheet` như hiện tại) **chưa thiết kế**.
- Việc "duyệt theo bộ từ điển mặc định" (tương đương hành vi list-từ-theo-
  chương hiện tại) không biến mất — chỉ **chuyển sang cùng cơ chế với bộ từ
  điển cá nhân** (khả năng là một màn/khu vực riêng, không còn nằm ở tab
  "Học" — vị trí chính xác trong điều hướng **chưa chốt**, cần rà soát lại
  cùng lúc với `07_Home-shell.md` và mockup "Từ điển của tôi" đã có sẵn ở
  `docs/artifact-design/`).

### Ảnh hưởng dữ liệu

- Nguồn nội dung bài học hiện là file Word (`.docx`) — quy trình chuyển hoá
  sang dữ liệu có cấu trúc (Section → Chapter → nội dung bài + từ vựng liên
  kết) **chưa chốt** (thủ công/bán tự động/tự động — Q-CSB-07).
- Cần quyết định có tách bảng liên kết riêng `chapter_words` (Chapter ↔ từ
  xuất hiện trong bài) hay suy ra từ nội dung bài lúc hiển thị (parse text
  runtime) — ảnh hưởng trực tiếp hiệu năng và độ phức tạp truy vấn SQLite.
- `VocabRepository.chapters()`/`wordsByChapter()` hiện tại gắn chặt với mô
  hình 1-N cũ — cần thiết kế lại tầng repository/provider tương ứng với
  Section/Chapter mới + bảng N-N `word_dictionaries`, không phải sửa nhỏ.

## Giả định / hạn chế

- Không có thanh tiến độ (% đã học) trên mỗi dòng chương trong code thật —
  mockup có thêm chi tiết này (`chap-progress` bar) nhưng đây chỉ là ý tưởng
  thiết kế, chưa triển khai.
- Không có chế độ "học từ mới" kiểu flashcard trong code — từng có ở mockup
  cũ (03b/03c "mặt trước/mặt sau") nhưng đã bị bỏ theo yêu cầu, xem
  `docs/spec_history.md` và mockup mới nhất chỉ còn "danh sách chương → danh
  sách từ A-Z" (không có bước lật thẻ trung gian).
- Mô hình mới ở trên **thay thế hoàn toàn** giả định "chương = nhóm từ" mà
  các giả định phía trên dựa vào — cần rà soát lại một khi mô hình mới được
  chốt chi tiết hơn (đặc biệt sau khi trả lời Q-CSB-07).
