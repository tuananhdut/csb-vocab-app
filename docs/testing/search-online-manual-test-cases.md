# Test case thủ công — Tra cứu (Search) + Tra Online + Thêm vào bộ

Checklist kiểm tra tay cho luồng "Tra cứu" (SCR-02): tìm kiếm local
2 chiều, fallback tra Online (MyMemory + Free Dictionary API) khi
local không có, và lưu kết quả Online vào 1+ bộ từ điển. Tick `[x]`
khi đã test và đúng kỳ vọng; ghi chú lại nếu sai.

Phạm vi code liên quan:
- `lib/features/search/search_screen.dart`
- `lib/data/repositories/vocab_providers.dart` (`searchProvider`, `onlineWordDictionaryIdsProvider`)
- `lib/data/repositories/vocab_repository.dart` (`search`, `findOnlineWordId`, `insertOnlineWord`)
- `lib/data/services/dictionary_api_service.dart` (MyMemory + Free Dictionary API)
- `lib/features/vocab/word_widgets.dart` (`WordTile`, `WordDetailContent`, badge "Online")
- `lib/features/vocab/add_to_dictionary_sheet.dart`

Ghi chú nền tảng quan trọng (đọc trước khi test, tránh báo nhầm là lỗi):
- `search()` **loại trừ `source=2` MANUAL** — từ tự thêm không bao giờ
  xuất hiện ở Tra cứu, dù trùng khớp query. Đây là chủ đích, không phải bug.
- Kết quả Online chỉ được thêm vào **cuối danh sách**, và **chỉ khi**:
  có mạng, query không rỗng, VÀ không có từ local nào khớp **chính xác**
  (so `==`, không phải `LIKE`) với query đã trim.
- Kết quả Online dùng `id = onlineWordSentinelId` (id giả) — **chưa lưu
  vào DB** cho tới khi user chủ động bấm "Thêm vào bộ".
- Badge "Online" hiện dựa vào `word.isOnline` — khi `true` sẽ **thay
  thế** hẳn phần hiển thị "tên chương" ở `WordTile` (2 thứ loại trừ nhau
  trên cùng 1 dòng).

---

## 1. Tra cứu local — hướng và độ chính xác khớp

- [ ] **1.1** Gõ 1 từ tiếng Anh có trong giáo trình (hướng "Anh → Việt") — ra đúng kết quả, không có badge "Online".
- [ ] **1.2** Đổi dropdown sang "Việt → Anh", gõ đúng nghĩa tiếng Việt của từ đó — ra đúng kết quả (khớp cột `meaning_vi`).
- [ ] **1.3** Gõ 1 từ tiếng Anh nhưng dropdown đang để "Việt → Anh" (sai hướng) — kỳ vọng: **không** ra kết quả local (vì chỉ so khớp `meaning_vi`, không phải `word`), rồi rơi xuống fallback Online nếu có mạng.
- [ ] **1.4** Gõ 1 phần của từ (vd gõ "cont" khi có từ "contract" trong giáo trình) — ra kết quả dạng khớp gần đúng (`LIKE '%cont%'`), sắp xếp ưu tiên khớp chính xác/khớp đầu trước.
- [ ] **1.5** Gõ 1 từ MANUAL (tự thêm ở bộ cá nhân, không phải SEED/ONLINE) — kỳ vọng: **không xuất hiện** trong kết quả Tra cứu (đúng thiết kế, `search()` loại trừ `source=2`).
- [ ] **1.6** Xoá hết chữ trong ô tìm kiếm (bấm nút "x" hoặc xoá tay) — quay về màn hình carousel ảnh Cảnh sát biển ("Sẵn sàng tra cứu"/"Tra cứu từ vựng chuyên ngành"), không còn danh sách kết quả cũ.
- [ ] **1.7** Gõ query chỉ toàn khoảng trắng — coi như rỗng, không tìm, không gọi Online.
- [ ] **1.8** Đổi dropdown hướng tìm kiếm khi đang có kết quả hiển thị (không xoá query) — danh sách tự cập nhật lại theo hướng mới, không cần bấm tìm lại.

---

## 2. Fallback tra Online — khi local không có kết quả

- [ ] **2.1** Gõ 1 từ tiếng Anh chắc chắn **không có** trong giáo trình (vd 1 từ hiếm), đang **có mạng** — sau khi loading, kết quả Online xuất hiện ở **cuối danh sách** (hoặc là kết quả duy nhất nếu local rỗng), có badge "Online" màu cam, KHÔNG hiện tên chương.
- [ ] **2.2** Lặp lại 2.1 với hướng "Việt → Anh" (gõ nghĩa tiếng Việt của 1 từ không có trong giáo trình) — vẫn ra được kết quả Online, hiển thị đúng thứ tự (Anh trước, Việt sau) trong `WordTile`/chi tiết dù query gốc là tiếng Việt.
- [ ] **2.3** Gõ 1 từ **có sẵn khớp CHÍNH XÁC** trong local (không phải chỉ khớp gần đúng) — kỳ vọng: **không gọi Online** (theo code, `hasExactMatch` chặn gọi API để tiết kiệm quota) — chỉ thấy kết quả local, không có badge "Online" nào thêm vào cuối.
- [ ] **2.4** Gõ 1 từ chỉ khớp **gần đúng** ở local (vd "cont" khớp LIKE với "contract") nhưng KHÔNG khớp chính xác — kỳ vọng: **vẫn gọi Online** thêm (vì `hasExactMatch` chỉ true khi khớp tuyệt đối), nếu Online trả về kết quả khác sẽ thấy thêm 1 dòng badge "Online" ở cuối, cạnh các kết quả gần đúng ở trên.
- [ ] **2.5** Gõ 1 từ không có ở cả local lẫn Online (từ vô nghĩa, ký tự lộn xộn), có mạng — kỳ vọng: về tay trắng đúng cách, hiện "Không tìm thấy "..."", không crash, không treo loading.
- [ ] **2.6** Tắt mạng (tắt Wi-Fi/rút cáp), gõ 1 từ không có local — kỳ vọng: chỉ hiện "Không tìm thấy" (không gọi Online vì `isOnline` false), không có thông báo lỗi mạng nào bật lên (khác với `AddWordScreen`, ở đây fallback êm, không có snackbar báo lỗi kết nối).
- [ ] **2.7** Đang gõ và tra Online (loading), tắt Wi-Fi giữa chừng — kỳ vọng: không crash, cuối cùng rơi về chỉ hiện kết quả local (nếu có) hoặc "Không tìm thấy", không bị kẹt loading vĩnh viễn.
- [ ] **2.8** Gõ nhanh liên tục nhiều ký tự (mỗi ký tự kích hoạt `searchProvider` mới do family theo `(query, direction)`) — không bị lag nặng/crash do gọi API dồn dập; kết quả cuối cùng khớp đúng với query cuối cùng đã gõ (không hiển thị nhầm kết quả của query trung gian).

---

## 3. Chi tiết kết quả Online (`WordDetailContent`/`WordDetailSheet`)

- [ ] **3.1** Bấm vào 1 kết quả có badge "Online" — mở chi tiết, thấy badge "Online" ở đầu, có nút "Thêm vào bộ" nổi bật (FilledButton), **không có** phần "VÍ DỤ THỰC TẾ" (kết quả Online không có ví dụ, `examples` trả rỗng ngay lập tức không qua DB).
- [ ] **3.2** Ở chi tiết 1 từ **local** (không phải Online) — không có nút "Thêm vào bộ" (chỉ dành riêng cho `word.isOnline`).
- [ ] **3.3** Kết quả Online có phiên âm (do Free Dictionary API tìm được) — hiển thị đúng phiên âm + nút loa (phát âm TTS) hoạt động bình thường.
- [ ] **3.4** Kết quả Online **không có** phiên âm (Free Dictionary API không tìm thấy, hoặc query gốc là tiếng Việt) — không hiện dòng phiên âm, không lỗi layout (không có khoảng trống thừa kỳ lạ).

---

## 4. Thêm kết quả Online vào bộ từ điển (`AddToDictionarySheet`)

- [ ] **4.1** Bấm "Thêm vào bộ" từ chi tiết 1 kết quả Online — mở bottom sheet, tiêu đề đúng "Từ — Nghĩa", danh sách checkbox các bộ (không có "Chưa phân loại").
- [ ] **4.2** Không tick bộ nào, bấm "Thêm" — báo "Chọn ít nhất 1 bộ từ điển.", không đóng sheet, không lưu gì.
- [x] **4.3** **[Đã tự xác minh — logic]** Tick 1 bộ, bấm "Thêm" — sheet đóng, snackbar "Đã thêm "..." vào 1 bộ.", vào lại bộ đó thấy từ mới xuất hiện, không còn badge "Online" nữa (đã lưu thành `source=1`, không phải sentinel). Vẫn cần test tay để xem đúng snackbar/UI.
- [ ] **4.4** Tick **2-3 bộ cùng lúc**, bấm "Thêm" — snackbar báo đúng số bộ đã chọn; mở từng bộ, tất cả đều thấy từ mới (đúng `insertOnlineWord` chèn `word_dictionaries` cho mọi bộ đã chọn cùng 1 `word_id`).
- [ ] **4.5** Bấm "Tạo bộ mới" ngay trong sheet, đặt tên, xác nhận — bộ mới xuất hiện trong danh sách checkbox (chưa tự tick sẵn, cần tick tay lại) — đúng theo comment code (`createDictionary` không trả id nên không tự tick được).
- [x] **4.6** **[Đã tự xác minh — logic]** Sau khi đã thêm 1 từ Online vào bộ A (case 4.3), tra lại **đúng từ đó** lần nữa (cùng chính tả) — mở lại chi tiết/"Thêm vào bộ": bộ A phải hiện **đã tick sẵn và khoá** (không bỏ tick được), phụ đề đổi thành "... · đã có từ này". Đã xác minh `findOnlineWordId` + `dictionaryIdsContaining` trả đúng; vẫn cần test tay để xem đúng checkbox/UI.
- [x] **4.7** **[Đã tự xác minh — logic]** Tiếp case 4.6, tick thêm bộ B (khác bộ A), bấm "Thêm" — kỳ vọng: **tái sử dụng đúng `word_id` cũ** (không tạo bản ghi trùng), chỉ thêm liên kết vào bộ B; vào bộ A vẫn thấy đúng 1 dòng từ đó (không nhân đôi). Đã xác minh: cùng 1 `word_id` được tái sử dụng, giờ liên kết đúng cả 2 bộ, không có bản ghi `words` thứ 2.
- [x] **4.8** **[Đã tự xác minh — logic]** Thêm từ Online vào bộ mặc định (SEED, `is_default=1`) — vẫn cho phép chọn/tick bình thường (bộ mặc định chỉ khoá xoá cả bộ, không khoá nhận từ mới); từ mới trong bộ mặc định có `source=1`, không phải `source=0`, nên vẫn sửa/xoá được sau này. Đã xác minh `source` lưu đúng `1`.
- [ ] **4.9** Đóng modal "Thêm vào bộ" giữa chừng (vuốt xuống/bấm ra ngoài) mà chưa bấm "Thêm" — không lưu gì cả, tra lại từ đó vẫn thấy badge "Online" như cũ (chưa persist).
- [ ] **4.10** Chưa có bộ từ điển nào (trường hợp hiếm, mới cài app và chưa từng tạo bộ tự chọn) — sheet hiện "Chưa có bộ từ điển nào — tạo bộ mới bên dưới." thay vì danh sách trống trơn khó hiểu.

---

## 5. Layout desktop 2 cột (`width >= AppConstants.desktopBreakpoint`)

- [ ] **5.1** Trên cửa sổ đủ rộng (desktop breakpoint) — Tra cứu hiện đúng 2 cột: danh sách bên trái, chi tiết bên phải; chưa chọn dòng nào thì cột phải hiện "Chưa chọn từ" (placeholder), không trống trơn.
- [ ] **5.2** Chọn 1 kết quả Online ở cột trái (desktop) — cột phải hiện đúng chi tiết kèm nút "Thêm vào bộ"; dòng đang chọn ở cột trái có viền trái + nền tô sáng (`selected`).
- [ ] **5.3** Thêm kết quả Online vào bộ từ cột phải (desktop) rồi tra lại — dòng đó ở cột trái vẫn còn (kết quả tìm kiếm không tự refresh xoá dòng Online sau khi lưu, vì `searchProvider` cache theo query/direction, không invalidate khi thêm vào bộ) — xác nhận đây là hành vi hiện tại, không phải lỗi cần sửa gấp, nhưng nên biết để không nhầm là "thêm vào bộ không thành công".

---

## 6. Case đặc biệt / rủi ro đã biết

- [ ] **6.1** Gõ ký tự đặc biệt/emoji vào ô tìm kiếm — không crash, ra "Không tìm thấy" hợp lý (không gọi Online với input rác nếu server trả lỗi — xác nhận app vẫn mượt).
- [ ] **6.2** Gõ từ rất dài (>100 ký tự) — không crash, MyMemory có giới hạn độ dài dịch nhưng lỗi phải được nuốt êm (không có snackbar đỏ bung ra).
- [ ] **6.3** Tra 1 từ đã tồn tại trong local nhưng gõ sai hoa/thường (vd "CONTRACT" toàn hoa) — vẫn tìm ra đúng kết quả (`LIKE`/`=` đều so khớp `word_lower`, không phân biệt hoa/thường).
- [ ] **6.4** Xoay app từ mobile-width sang desktop-width (resize cửa sổ Windows qua lại quanh breakpoint) khi đang có kết quả Online hiển thị — không crash, chuyển layout mượt, dữ liệu đang chọn không bị mất.

---

## Ghi chú theo dõi

| # | Ngày test | Kết quả | Ghi chú |
|---|-----------|---------|---------|
|   |           |         |         |
