# SCR-02 — Tra cứu

**FR:** FR-2 · **Trạng thái:** ✅ Đã code xong (chế độ Offline) · **Nguồn:** `lib/features/search/search_screen.dart`, `lib/features/vocab/word_widgets.dart`

> ⚠️ **Định hướng mới — chưa code** (xem `00_Overview.md` mục "Mô hình dữ
> liệu — định hướng mới", `docs/spec_history.md` [IMPL-005]): màn này sẽ có
> **2 trạng thái** Offline/Online. Mục **Hành vi**, **Truy vấn dữ liệu**,
> **Phụ thuộc** bên dưới mô tả đúng code thật hôm nay = **chế độ Offline**.
> Mục **Chế độ Online — định hướng mới** ở cuối file mô tả phần mở rộng
> chưa triển khai.

## Mục đích

Tra cứu từ vựng 2 chiều (Anh → Việt hoặc Việt → Anh) trong phạm vi giáo
trình đã đóng gói. Hiện tại hoàn toàn offline; định hướng mới sẽ bổ sung
thêm nguồn online khi có mạng (xem mục cuối file).

## Hành vi — Chế độ Offline [ĐÃ CODE]

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

## Truy vấn dữ liệu — Chế độ Offline [ĐÃ CODE]

`VocabRepository.search(query)` (`lib/data/repositories/vocab_repository.dart`):
so khớp `word_lower LIKE %q%` HOẶC `lower(meaning_vi) LIKE %q%`, sắp xếp ưu
tiên: khớp chính xác → khớp tiền tố → còn lại theo độ dài từ, giới hạn 50 kết
quả.

## Phụ thuộc — Chế độ Offline [ĐÃ CODE]

- `vocabRepositoryProvider` → mở `vocab.db` qua `VocabDatabase.open()`.
- `WordTile`, `WordDetailSheet` (dùng chung với màn Học, SCR-03).
- `learnedStatusProvider`, `markWordLearned` (`lib/features/review/review_providers.dart`) — nối trực tiếp Tra cứu với hệ thống ôn tập SM-2.

## Chế độ Online — định hướng mới [CHƯA CODE]

> Nguồn: `00_Overview.md` mục "Mô hình dữ liệu — định hướng mới",
> `docs/spec_history.md` [IMPL-005] (Q-CSB-04..06).

- **Kích hoạt:** màn tự phát hiện có kết nối mạng hay không (cơ chế cụ thể
  chưa chốt — Q-CSB-06) và chuyển trạng thái Offline ⇄ Online tương ứng. Cần
  hiển thị rõ cho người dùng đang ở trạng thái nào (ví dụ badge/icon trên
  AppBar) — **chưa thiết kế UI cụ thể**.
- **Hành vi tra cứu khi Online:** vẫn chạy `VocabRepository.search(query)`
  trên `vocab.db` như bình thường trước; nếu không có kết quả (hoặc kết quả
  nghèo — tiêu chí "nghèo" chưa chốt), gọi thêm **API từ điển ngoài** để bổ
  sung. Nhà cung cấp API cụ thể **chưa chốt** (Q-CSB-04) — ảnh hưởng trực
  tiếp tới field trả về (có phiên âm/ví dụ/loại từ đầy đủ như `vocab.db`
  không) nên chưa thể mô tả chi tiết `WordTile`/`WordDetailSheet` sẽ hiển
  thị thêm gì cho kết quả loại này.
- **Từ mới tra được qua API ngoài:** có lưu lại vào local để dùng khi
  offline sau này không, và nếu lưu thì gắn vào bộ từ điển nào — **chưa
  chốt** (Q-CSB-05). Việc này phụ thuộc mô hình bộ từ điển N-N mô tả ở
  `00_Overview.md`.
- **Lỗi mạng chập chờn** (có kết nối nhưng API không phản hồi/timeout): cách
  xử lý (fallback về offline im lặng, hay báo lỗi rõ cho user) **chưa chốt**
  (Q-CSB-06).
- **Ảnh hưởng tới code hiện tại:** cần thêm 1 tầng gọi API (data source mới,
  ví dụ `DictionaryApiRepository`) song song với `VocabRepository`, và
  `searchProvider` cần biết trạng thái mạng để quyết định có gọi thêm tầng
  này không — hiện `searchProvider`/`VocabRepository` chỉ biết đọc
  `vocab.db`, không có khái niệm mạng.

## Giả định / hạn chế

- Không có debounce khi gõ — mỗi ký tự gõ vào kích hoạt truy vấn DB ngay.
  Chấp nhận được vì `vocab.db` cỡ ~2.450 từ, chạy local, độ trễ không đáng kể.
- Không có lịch sử tra cứu (bảng `search_history` đã có schema trong
  `user.db` — xem `lib/data/local/user_database.dart` — nhưng chưa được
  đọc/ghi ở bất kỳ đâu).

> ⚠️ Mockup (`docs/artifact-design/screens/screen-02-tra-cuu.html`) đã thêm
> nút "Thêm vào bộ" bên cạnh "Đã học" trong sheet chi tiết từ — tính năng bộ
> từ điển cá nhân **chưa có trong code**, xem Q-CSB-02 (`docs/spec_history.md`).
