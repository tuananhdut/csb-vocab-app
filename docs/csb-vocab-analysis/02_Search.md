# SCR-02 — Tra cứu

**FR:** FR-2 · **Trạng thái:** ✅ Đã code xong — offline + Online, phân
trang · **Nguồn:** `lib/features/search/search_screen.dart`,
`lib/features/vocab/word_widgets.dart`

> ⚠️ **Tài liệu này từng ghi chế độ Online là "chưa code"** (bản cũ hơn) —
> **sai với thực tế**, phần Online đã được code từ trước, chỉ chưa được
> cập nhật vào tài liệu. Bản hiện tại mô tả đúng code thật tại thời điểm
> viết (2026-09-17), gồm cả debounce + phân trang thêm ở
> `docs/spec_history.md` [IMPL-023]/[IMPL-024].

## Mục đích

Tra cứu từ vựng 2 chiều (Anh → Việt hoặc Việt → Anh) trong phạm vi
`vocab.db` (33.019 từ sau khi gộp thêm `Tu_dien.pdf`, xem [IMPL-021]),
bổ sung thêm 1 kết quả tra Online khi không có sẵn local và đang có mạng.

## Hành vi

- Dropdown chọn hướng tra (`SearchDirection`: Anh→Việt / Việt→Anh, tự
  dựng bằng `showMenu` + `RenderBox` thay vì `DropdownButtonFormField`
  mặc định) — bắt buộc chọn, không tự đoán ngôn ngữ từ nội dung gõ vào.
- Gõ vào ô tìm kiếm → **debounce 300ms** trước khi gọi
  `VocabRepository.search()` (không gọi lại mỗi ký tự gõ, xem
  [IMPL-023]) — đổi hướng tra cũng huỷ debounce đang chờ trước khi tìm
  lại, tránh 1 kết quả debounce cũ (hướng cũ) ghi đè lên kết quả của
  hướng vừa đổi.
- Không gõ gì → hiện `_Hint` (icon + gợi ý "Gõ từ tiếng Anh hoặc tiếng
  Việt để tìm").
- Kết quả local hiện qua `WordTile`: từ (đậm), phiên âm IPA (màu accent),
  loại từ (`Chip` nhỏ, viết tắt tiếng Việt: dt/đt/tt...), nghĩa tiếng
  Việt, và tên chương/bộ từ điển gốc bên phải (`showChapter: true` — chỉ
  bật ở màn Tra cứu, tắt ở màn Học vì ở đó chương đã hiển nhiên).
- **Phân trang (cuộn vô hạn, [IMPL-023])**: trang đầu tải qua
  `VocabRepository.search(..., limit, offset: 0)`; cuộn gần cuối danh
  sách tự tải thêm trang tiếp theo (`ScrollController`, ngưỡng gần đáy).
  Có bộ đếm `_loadGeneration` chặn kết quả async trễ từ 1 lượt tải cũ ghi
  đè lên danh sách đã bị reset bởi lượt tìm kiếm mới hơn.
- Bấm vào 1 dòng → mở `WordDetailSheet` dạng bottom sheet kéo lên
  (`DraggableScrollableSheet`, cao 50–90% màn hình), tải thêm ví dụ
  (`wordExamplesProvider`) và trạng thái đã-học (`learnedStatusProvider`)
  riêng theo `word.id`. Sheet có cả nút "Đánh dấu đã học" và **"Thêm vào
  bộ"** (mở modal chọn/tạo bộ từ điển cá nhân — tính năng "Từ điển của
  tôi" **đã có trong code**, `lib/features/my_dictionaries/`, dù chưa có
  tài liệu phân tích riêng, xem mục Giả định/hạn chế).

## Chế độ Online

- **Kích hoạt:** `connectivity_plus` (`connectivityProvider`, `StreamProvider<bool>`)
  phát hiện có kết nối mạng hay không.
- **Khi nào gọi Online:** chỉ khi trang đầu của kết quả local **không có
  khớp chính xác** (`hasExactMatch`) với từ đang gõ, và đang có mạng —
  không gọi Online nếu đã có khớp chính xác trong `vocab.db`.
- **Dịch vụ dùng:** **MyMemory Translation API**
  (`https://api.mymemory.translated.net/get`, miễn phí, không cần key,
  gọi thẳng từ Flutter client qua `dio`) để dịch en↔vi — xem
  `lib/data/services/dictionary_api_service.dart`. Quota: 5.000 ký
  tự/ngày/IP ẩn danh, hoặc 50.000 ký tự/ngày/IP nếu kèm tham số
  `de=<email liên hệ>` (quota tính theo IP gọi API, không phải theo
  user vì app không có backend/tài khoản để phân biệt). **Free
  Dictionary API** (`https://api.dictionaryapi.dev`, miễn phí, không
  cần key) bổ sung phiên âm/loại từ khi từ tra là tiếng Anh (không hỗ
  trợ tiếng Việt nên không dùng để dịch) — lỗi khác 404 được log kèm từ
  đang tra + loại lỗi + status code + URL ([IMPL-024]).
- **Vị trí hiển thị:** kết quả Online chèn ở **cuối** danh sách kết quả
  local (không phải đầu — đã đổi qua lại 1 lần theo yêu cầu, chốt cuối
  cùng là cuối danh sách, [IMPL-024]); khi cuộn tải thêm trang local mới,
  trang mới được chèn **trước** phần tử Online để nó luôn ở cuối cùng.
- **Chỉ báo loading:** trong lúc đang gọi API Online (`_checkingOnline`),
  hiện spinner ở footer danh sách (không hiện "Không tìm thấy" ngay rồi
  lại có kết quả Online đến sau — tránh nhấp nháy mâu thuẫn).
- **Từ mới tra được qua API ngoài:** không tự động lưu lại local. Chỉ
  ghi vào DB khi user chủ động bấm "Thêm vào bộ" trong `WordDetailSheet`
  — lúc đó mới chọn/tạo bộ từ điển cá nhân để gắn từ vào.
- **Lỗi mạng chập chờn** (có kết nối nhưng API không phản hồi/timeout):
  fallback êm về kết quả offline, không chặn UI bằng lỗi đỏ.

## Truy vấn dữ liệu

- `VocabRepository.search(query, direction, {limit, offset})`
  (`lib/data/repositories/vocab_repository.dart`): so khớp
  `word_lower LIKE %q%` HOẶC `lower(meaning_vi) LIKE %q%`, sắp xếp ưu
  tiên: khớp chính xác → khớp tiền tố → còn lại theo độ dài từ, cuối
  cùng thêm `w.id` làm tie-breaker (đảm bảo thứ tự ổn định giữa các
  trang khi nhiều headword trùng nhau, vd "RA" — xem [IMPL-023]).
- `VocabRepository.findExactMatch(query, direction)` — dùng để quyết
  định có cần gọi Online hay không (`hasExactMatch`), và ở "Tự điền" của
  `AddWordScreen`.

## Phụ thuộc

- `vocabRepositoryProvider` → mở `vocab.db` qua `VocabDatabase.open()`.
- `WordTile`, `WordDetailSheet` (dùng chung với màn Học, SCR-03).
- `learnedStatusProvider`, `markWordLearned` (`lib/features/review/review_providers.dart`) — nối trực tiếp Tra cứu với hệ thống ôn tập SM-2.
- `dictionaryApiServiceProvider`, `connectivityProvider` — chế độ Online.
- `lib/features/my_dictionaries/` — luồng "Thêm vào bộ" từ `WordDetailSheet`.

## Giả định / hạn chế

- Không có lịch sử tra cứu — bảng `search_history` (từng có schema trong
  `user.db`) đã bị **bỏ hẳn** khỏi thiết kế ([IMPL-016]): chưa từng được
  đọc/ghi ở bất kỳ đâu, không mockup nào thiết kế UI cho tính năng này.
- **Tính năng "Từ điển của tôi" / bộ từ điển cá nhân đã có trong code**
  (`lib/features/my_dictionaries/`: danh sách bộ, chi tiết bộ (có phân
  trang, xem [IMPL-023]), tự thêm từ mới, tự điền từ dữ liệu có sẵn) —
  README của thư mục này (`docs/csb-vocab-analysis/README.md`) và
  `90_Traceability-matrix.md` **vẫn ghi "❌ Chưa"**, cần cập nhật + viết
  tài liệu phân tích riêng cho màn hình này (chưa làm trong đợt cập nhật
  này, xem Q-CSB-10 ở `docs/spec_history.md`).
