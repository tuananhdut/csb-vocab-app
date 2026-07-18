# SCR-03 — Học theo chương

**FR:** FR-3 · **Trạng thái:** ✅ Đã code xong · **Nguồn:** `lib/features/lessons/lessons_screen.dart`

## Mục đích

Duyệt từ vựng theo cấu trúc chương của giáo trình gốc — khác Tra cứu (tự do
gõ tìm), đây là duyệt tuần tự theo chủ đề chuyên môn.

## Hành vi

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

## Truy vấn dữ liệu

- `VocabRepository.chapters()` — `SELECT` từ bảng `chapters`, kèm subquery
  đếm `COUNT(*)` số từ mỗi chương, sắp theo `chapter_no`.
- `VocabRepository.wordsByChapter(chapterId, includeSub: true)` — lọc theo
  `chapter_id`, sắp `is_subentry` trước rồi mới `word_lower` (mục từ gốc lên
  trước, subentry/cụm liên quan xếp ngay sau).

6 chương thật trong `vocab.db` hiện tại: Quân sự chung, Hàng hải, Thông tin ra
đa, Vũ khí, Cơ điện, Cảnh sát biển.

## Phụ thuộc

- `chaptersProvider`, `chapterWordsProvider` (`lib/data/repositories/vocab_providers.dart`).
- `WordTile`, `showWordDetail` (chung với SCR-02).

## Giả định / hạn chế

- Không có thanh tiến độ (% đã học) trên mỗi dòng chương trong code thật —
  mockup có thêm chi tiết này (`chap-progress` bar) nhưng đây chỉ là ý tưởng
  thiết kế, chưa triển khai.
- Không có chế độ "học từ mới" kiểu flashcard trong code — từng có ở mockup
  cũ (03b/03c "mặt trước/mặt sau") nhưng đã bị bỏ theo yêu cầu, xem
  `docs/spec_history.md` và mockup mới nhất chỉ còn "danh sách chương → danh
  sách từ A-Z" (không có bước lật thẻ trung gian).
