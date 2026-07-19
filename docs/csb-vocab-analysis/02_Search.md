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
> `docs/spec_history.md` [IMPL-005], **quyết định chốt ở [IMPL-013]**
> (Q-CSB-04/05/06).

- **Kích hoạt:** dùng gói **`connectivity_plus`** (đã chốt Q-CSB-06) để phát
  hiện có kết nối mạng hay không, chuyển trạng thái Offline ⇄ Online tương
  ứng. Cần hiển thị rõ cho người dùng đang ở trạng thái nào (badge/icon trên
  AppBar, xem `.net-badge` trong mockup `screen-02.html`/`screen-02b.html`)
  — UI cụ thể tham khảo mockup, chưa code.
- **Hành vi tra cứu khi Online:** vẫn chạy `VocabRepository.search(query)`
  trên `vocab.db` như bình thường trước; nếu không có kết quả, gọi thêm
  **API từ điển ngoài** để bổ sung. Đã chốt (Q-CSB-04): **Free Dictionary
  API** (`https://api.dictionaryapi.dev`, miễn phí, không cần API key) lấy
  định nghĩa/phiên âm/ví dụ **tiếng Anh**, sau đó gọi thêm
  **LibreTranslate** (self-host hoặc instance công khai) để dịch phần nghĩa
  sang tiếng Việt trước khi hiển thị — khớp với hành vi song ngữ hiện tại
  của `WordTile`/`WordDetailSheet`. Rủi ro: instance LibreTranslate công
  khai có thể không ổn định/giới hạn rate — cân nhắc self-host khi lên
  production.
- **Từ mới tra được qua API ngoài:** đã chốt (Q-CSB-05) **không tự động lưu
  lại local**. Chỉ ghi vào `user.db` khi user **chủ động bấm "Thêm vào bộ"**
  trong `WordDetailSheet` (theo mockup `screen-04b-them-vao-bo-tu-dien.html`)
  — lúc đó mới chọn/tạo bộ từ điển cá nhân để gắn từ vào. Không có khái
  niệm "cache tự động kết quả online" — đơn giản hoá luồng ghi dữ liệu, xem
  schema cụ thể ở `91_DB-design-new-model.md`.
- **Lỗi mạng chập chờn** (có kết nối nhưng API không phản hồi/timeout): đã
  chốt (Q-CSB-06) **fallback êm về kết quả offline** (chỉ `vocab.db`),
  không chặn UI bằng lỗi đỏ; có thể hiện thông báo nhẹ (ví dụ snackbar) báo
  không lấy được kết quả bổ sung.
- **Ảnh hưởng tới code hiện tại:** cần thêm 1 tầng gọi API mới (ví dụ
  `DictionaryApiRepository` gọi Free Dictionary API + `TranslationService`
  gọi LibreTranslate) song song với `VocabRepository`, và `searchProvider`
  cần biết trạng thái mạng (qua `connectivity_plus`) để quyết định có gọi
  thêm tầng này không — hiện `searchProvider`/`VocabRepository` chỉ biết đọc
  `vocab.db`, không có khái niệm mạng.

## Giả định / hạn chế

- Không có debounce khi gõ — mỗi ký tự gõ vào kích hoạt truy vấn DB ngay.
  Chấp nhận được vì `vocab.db` cỡ ~2.450 từ, chạy local, độ trễ không đáng kể.
- Không có lịch sử tra cứu — bảng `search_history` (từng có schema trong
  `user.db`, xem `lib/data/local/user_database.dart`) đã bị **bỏ hẳn**
  khỏi thiết kế mới ([IMPL-016]): chưa từng được đọc/ghi ở bất kỳ đâu,
  không mockup nào (kể cả `screen-02-tra-cuu.html`) thiết kế UI cho tính
  năng này. Nếu sau này thực sự làm "lịch sử tra cứu gần đây", tạo lại
  bảng bằng 1 migration khi đó — xem `91_DB-design-new-model.md` mục "Bỏ
  hẳn bảng `review_logs`/`search_history`".

> ⚠️ Mockup (`docs/artifact-design/screens/screen-02-tra-cuu.html`) đã thêm
> nút "Thêm vào bộ" bên cạnh "Đã học" trong sheet chi tiết từ — tính năng bộ
> từ điển cá nhân **chưa có trong code**, xem Q-CSB-02 (`docs/spec_history.md`).
