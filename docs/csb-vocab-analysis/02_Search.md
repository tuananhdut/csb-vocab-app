# SCR-02 — Tra cứu

**FR:** FR-2 · **Trạng thái:** ✅ Đã code xong · **Nguồn:** `lib/features/search/search_screen.dart`, `lib/features/vocab/word_widgets.dart`

## Mục đích

Tra cứu từ vựng 2 chiều (Anh → Việt hoặc Việt → Anh) trong phạm vi giáo
trình đã đóng gói, hoàn toàn offline.

## Hành vi

- `TextField` tự động focus khi vào màn (`autofocus: true`), gõ tới đâu tìm
  tới đó (`onChanged` cập nhật `_query` → rebuild).
- Không gõ gì → hiện `_Hint` (icon + gợi ý "Gõ từ tiếng Anh hoặc tiếng Việt để tìm").
- Có gõ → `searchProvider(_query)` (FutureProvider.family) trả về danh sách
  `VocabWord` khớp; 3 trạng thái xử lý qua `.when()`: loading (spinner),
  error (hiện lỗi thô), data rỗng (hiện `"Không tìm thấy "$_query""`).
- Mỗi kết quả hiện qua `WordTile`: từ (đậm) + phiên âm IPA (màu accent) +
  loại từ (`Chip` nhỏ, viết tắt tiếng Việt: dt/đt/tt...) + nghĩa tiếng Việt +
  tên chương gốc bên phải (`showChapter: true` — chỉ bật ở màn Tra cứu, tắt ở
  màn Học vì ở đó chương đã hiển nhiên).
- Bấm vào 1 dòng → mở `WordDetailSheet` dạng bottom sheet kéo lên
  (`DraggableScrollableSheet`, cao 50–90% màn hình), tải thêm ví dụ
  (`wordExamplesProvider`) và trạng thái đã-học (`learnedStatusProvider`)
  riêng theo `word.id`.
- Trong sheet: nút "Đánh dấu đã học" / "Đã học" (disabled khi đã học) gọi
  `markWordLearned(ref, word.id)` → ghi vào `learned_words` (user.db) và
  invalidate 3 provider phụ thuộc (trạng thái đã-học, hàng đợi ôn tập, badge
  số từ đến hạn trên `HomeShell`).

## Truy vấn dữ liệu

`VocabRepository.search(query)` (`lib/data/repositories/vocab_repository.dart`):
so khớp `word_lower LIKE %q%` HOẶC `lower(meaning_vi) LIKE %q%`, sắp xếp ưu
tiên: khớp chính xác → khớp tiền tố → còn lại theo độ dài từ, giới hạn 50 kết
quả.

## Phụ thuộc

- `vocabRepositoryProvider` → mở `vocab.db` qua `VocabDatabase.open()`.
- `WordTile`, `WordDetailSheet` (dùng chung với màn Học, SCR-03).
- `learnedStatusProvider`, `markWordLearned` (`lib/features/review/review_providers.dart`) — nối trực tiếp Tra cứu với hệ thống ôn tập SM-2.

## Giả định / hạn chế

- Không có debounce khi gõ — mỗi ký tự gõ vào kích hoạt truy vấn DB ngay.
  Chấp nhận được vì `vocab.db` cỡ ~2.450 từ, chạy local, độ trễ không đáng kể.
- Không có lịch sử tra cứu (bảng `search_history` đã có schema trong
  `user.db` — xem `lib/data/local/user_database.dart` — nhưng chưa được
  đọc/ghi ở bất kỳ đâu).

> ⚠️ Mockup (`docs/artifact-design/screens/screen-02-tra-cuu.html`) đã thêm
> nút "Thêm vào bộ" bên cạnh "Đã học" trong sheet chi tiết từ — tính năng bộ
> từ điển cá nhân **chưa có trong code**, xem Q-CSB-02 (`docs/spec_history.md`).
