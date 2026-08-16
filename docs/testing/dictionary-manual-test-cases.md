# Test case thủ công — Quản lý từ điển

Checklist kiểm tra tay cho luồng "Từ điển của tôi": tạo/xoá bộ, thêm từ
thủ công, tự điền (autofill), liên kết bản ghi có sẵn (link), sửa/xoá
từ. Tick `[x]` khi đã test và đúng kỳ vọng; ghi chú lại nếu sai.

Phạm vi code liên quan:
- `lib/features/my_dictionaries/add_word_screen.dart`
- `lib/features/my_dictionaries/dictionary_detail_screen.dart`
- `lib/features/my_dictionaries/my_dictionaries_screen.dart`
- `lib/data/repositories/vocab_repository.dart`
- `lib/features/review/review_providers.dart`

Các case đánh dấu **[Đã tự xác minh]** đã được kiểm chứng bằng 1 script
Dart chạy trực tiếp `VocabRepository` (logic SQL thuần) trên bản copy
`vocab.db`, không đụng dữ liệu thật — không thay thế test tay qua UI
(dialog, ảnh, mất mạng...) nhưng xác nhận đúng phần logic dữ liệu.

**Bug phát hiện qua script và đã sửa:** `VocabRepository.deleteWord`
trước đây chặn cả `source=0` (SEED) giống `updateManualWord`, khiến
bấm nút "Xoá" ở 1 từ SEED trong bộ tự tạo ném `StateError` không được
bắt (crash luồng xoá) — mâu thuẫn với spec "Xoá luôn khả dụng bất kể
nguồn từ". Đã bỏ điều kiện chặn đó khỏi `deleteWord`, giữ nguyên ở
`updateManualWord` (Sửa vẫn khoá với SEED). Xem case **5.4**.

---

## 1. Quản lý bộ từ điển (`my_dictionaries_screen.dart`)

- [ ] **1.1** Tạo bộ mới với tên hợp lệ — bộ mới xuất hiện ngay trong lưới, `0 từ`.
- [ ] **1.2** Tạo bộ với tên rỗng/toàn khoảng trắng — bị chặn (không tạo bộ trống tên).
- [ ] **1.3** Tạo 2 bộ trùng tên nhau — kỳ vọng hiện tại: **không có kiểm tra trùng tên**, cả 2 bộ cùng tên vẫn được tạo. Xác nhận đây có phải hành vi chấp nhận được không.
- [ ] **1.4** Bộ mặc định (SEED, `isDefault=true`) — nút "⋮" ẩn, chỉ còn icon "+" (Thêm từ mới), không có tuỳ chọn xoá bộ.
- [ ] **1.5** Bộ tự tạo — nút "⋮" hiện đúng menu custom (không phải menu Flutter mặc định to bè), có 2 mục "Thêm từ mới" / "Xoá bộ".
- [ ] **1.6** Xoá 1 bộ tự tạo đang có từ — dialog cảnh báo đúng số từ sẽ mất, xác nhận xong bộ biến mất khỏi lưới.
- [ ] **1.7** Xoá bộ chứa 1 từ đã **học/ôn tập** (`learned_words` có dữ liệu) — sau khi xoá, vào bộ khác không thấy badge "đến hạn" tính nhầm từ đã xoá.

---

## 2. Thêm từ thủ công — không dùng "Tự điền"

- [ ] **2.1** Gõ tay đầy đủ Từ + Nghĩa (không bấm "Tự điền"), Lưu — từ mới xuất hiện trong bộ, `source = MANUAL`, có nút Sửa/Xoá.
- [ ] **2.2** Để trống "Từ tiếng Anh" hoặc "Nghĩa tiếng Việt", bấm Lưu — form báo "Bắt buộc", không lưu được.
- [ ] **2.3** Gõ ví dụ tiếng Anh nhưng bỏ trống bản dịch (hoặc ngược lại), bấm Lưu — form báo lỗi yêu cầu điền đủ cặp.
- [x] **2.4** **[Đã tự xác minh — logic]** **(Chống trùng — vừa sửa)** Thêm từ `Contract` / `Hợp đồng`, Lưu. Vào lại "Thêm từ mới", gõ tay `contract` (chữ thường) / `Hợp đồng` y hệt, Lưu. Kỳ vọng: **không tạo bản ghi trùng** — được tự động liên kết vào bản ghi vừa tạo trước đó (snackbar hiện "... (từ có sẵn) ..."), danh sách bộ vẫn chỉ có 1 dòng "Contract". Vẫn nên test tay 1 lần để xác nhận snackbar/UI đúng.
- [x] **2.5** **[Đã tự xác minh — logic]** Lặp lại case 2.4 nhưng đổi **nghĩa khác** ở lần gõ thứ 2 (`contract` / `Co lại`) — kỳ vọng: **tạo bản ghi MANUAL mới** (không link), vì nghĩa không khớp — 1 từ có thể có nhiều nghĩa khác nhau là hợp lệ. Vẫn nên test tay 1 lần để xác nhận snackbar/UI đúng.
- [ ] **2.6** Gõ 1 từ đã tồn tại sẵn trong **giáo trình gốc (SEED)** y hệt cả từ lẫn nghĩa (tra trước ở Search để biết 1 từ SEED không có ví dụ), để trống phiên âm/loại từ/ví dụ, Lưu. Kỳ vọng: nếu SEED word đó cũng đang có phiên âm/loại từ rỗng thì sẽ link; nếu SEED có sẵn phiên âm/loại từ khác rỗng thì **không link** (vì form đang trống lệch với bản ghi gốc) — tạo MANUAL mới.

---

## 3. Tự điền từ dữ liệu (nút "Tự điền từ dữ liệu")

- [ ] **3.1** Để trống cả 2 ô Từ/Nghĩa, bấm "Tự điền" — báo "Nhập từ tiếng Anh hoặc nghĩa tiếng Việt trước", không crash.
- [ ] **3.2** Gõ 1 từ tiếng Anh có trong SEED (vd tra trước ở Search), bấm "Tự điền" — điền đúng Nghĩa/Phiên âm/Loại từ, **không** tự điền Ví dụ (ô ví dụ vẫn trống dù bản ghi gốc có ví dụ).
- [ ] **3.3** Gõ Nghĩa tiếng Việt (để trống Từ tiếng Anh), bấm "Tự điền" — tra theo hướng Việt→Anh, điền đúng ô Từ tiếng Anh.
- [ ] **3.4** Gõ 1 từ **không có** trong local, đang **có mạng** — tự điền qua Online (MyMemory/Free Dictionary), điền được ít nhất Nghĩa; nếu từ không tồn tại ở cả 2 API thì báo "Không tìm thấy dữ liệu cho từ này."
- [ ] **3.5** Gõ 1 từ không có local, **tắt mạng** (tắt Wi-Fi/rút cáp) — báo "Không tìm thấy — cần có mạng để tra thêm Online.", không bị treo loading.
- [ ] **3.6** Bấm "Tự điền" khi đang tự điền (bấm nhanh 2 lần liên tiếp) — nút tự chuyển thành icon loading disable, không gọi trùng 2 lần.
- [ ] **3.7** Tự điền xong (khớp local, đã link ngầm — xem log/snackbar sau khi Lưu), sau đó **tự sửa tay** lại ô Phiên âm — Lưu. Kỳ vọng: **không còn link nữa**, tạo bản ghi MANUAL mới (vì nội dung đã lệch bản gốc).
- [ ] **3.8** Tự điền xong, sửa tay ô "Ví dụ thực tế" (gõ thêm ví dụ khác bản gốc) — Lưu. Kỳ vọng: tương tự 3.7, không link, tạo MANUAL mới.
- [ ] **3.9** Tự điền xong, đổi lựa chọn ở dropdown "Loại từ" sang giá trị khác — Lưu. Kỳ vọng: không link, tạo MANUAL mới.
- [ ] **3.10** Tự điền ra 1 kết quả, sau đó **xoá sạch cả 2 ô Từ/Nghĩa** và gõ lại 1 từ khác hẳn, bấm "Tự điền" lần 2 — kết quả lần 2 áp dụng đúng, không dính dữ liệu/link cũ của lần 1.

---

## 4. Sửa từ

- [ ] **4.1** Từ SEED (giáo trình gốc) — không có nút "Sửa" ở cả danh sách lẫn pane chi tiết (desktop), chỉ có nút "Xoá".
- [ ] **4.2** Từ MANUAL/ONLINE — có đủ nút Sửa + Xoá; bấm Sửa mở lại form với dữ liệu cũ đã điền sẵn (kể cả ảnh, ví dụ).
- [ ] **4.3** Sửa 1 từ đang thuộc **2 bộ trở lên** (thêm qua "Thêm vào bộ" chọn nhiều bộ, hoặc autofill+link vào bộ thứ 2) — đổi nghĩa rồi Lưu. Mở cả 2 bộ, xác nhận **cả 2 nơi đều thấy nghĩa mới** (đồng bộ, không tách riêng theo bộ).
- [ ] **4.4** Sửa xoá ảnh minh hoạ đã có (bấm "Xoá ảnh"), Lưu — ảnh biến mất khỏi card/detail; (lưu ý: file ảnh cũ vẫn còn trên đĩa, không phải lỗi hiển thị, chỉ là rác không dọn — không cần test phần này qua UI).
- [ ] **4.5** Sửa đổi ảnh khác (bấm "Đổi ảnh" chọn file mới), Lưu — hiển thị đúng ảnh mới.
- [ ] **4.6** Sửa 1 từ đã **học/ôn tập nhiều lần** — đổi hẳn nội dung (từ và nghĩa khác hoàn toàn không liên quan gì tới từ cũ), Lưu. Vào bộ kiểm tra `đến hạn`/`đã học` — kỳ vọng hiện tại: **số liệu không đổi** (tiến trình ôn tập cũ được giữ nguyên dù nội dung đã đổi hẳn) — ghi nhận, không phải lỗi cần sửa ngay nhưng cần biết trước.

---

## 5. Xoá từ

- [x] **5.1** **[Đã tự xác minh — logic]** **(Dialog rõ ràng — vừa sửa)** Xoá 1 từ chỉ thuộc **đúng 1 bộ** (bộ đang xem) — dialog phải ghi rõ "sẽ bị xoá hẳn khỏi hệ thống ... không thể hoàn tác". Đã xác minh `deleteWord` trả `true` (xoá hẳn record) đúng trong trường hợp này; vẫn cần test tay để xem đúng chữ dialog.
- [x] **5.2** **[Đã tự xác minh — logic]** **(Dialog rõ ràng — vừa sửa)** Thêm cùng 1 từ vào **2 bộ** (A và B, qua "Thêm vào bộ" chọn cả 2, hoặc Tra Online). Vào bộ A, bấm Xoá từ đó — dialog phải ghi rõ "sẽ được gỡ khỏi [bộ A] ... vẫn còn ở 1 bộ khác". Xác nhận xoá — mở bộ B, từ đó **vẫn còn nguyên**. Đã xác minh `deleteWord` trả `false` và record vẫn còn liên kết bộ B; vẫn cần test tay để xem đúng chữ dialog.
- [x] **5.3** **[Đã tự xác minh — logic]** Sau case 5.2, quay lại bộ A — từ đã biến mất khỏi danh sách (chỉ gỡ liên kết đúng bộ A, không ảnh hưởng bộ B). Đã xác minh `word_dictionaries` không còn dòng (word, A) sau khi xoá.
- [x] **5.4** **[Đã tự xác minh — logic, PHÁT HIỆN BUG ĐÃ SỬA]** Xoá 1 từ **SEED** khỏi 1 bộ tự tạo (từ SEED được thêm vào bộ tự tạo qua Tra cứu/"Thêm vào bộ") — nút Xoá vẫn hiển thị và hoạt động (không bị khoá như nút Sửa); dialog phải báo đúng "vẫn còn ở bộ giáo trình gốc", không xoá hẳn từ SEED khỏi hệ thống. **Trước khi sửa, thao tác này crash (StateError không bắt được)** — đã sửa `VocabRepository.deleteWord`, giờ script xác nhận: không throw, gỡ đúng liên kết, record `words` của từ SEED vẫn còn nguyên. Vẫn cần test tay qua UI thật 1 lần để chắc chắn.
- [ ] **5.5** Xoá 1 từ **đã học** (`learned_words` có dữ liệu) mà đây là bộ duy nhất chứa nó (xoá hẳn) — vào lại các badge tổng số/đến hạn ở bộ khác, số liệu không bị lệch do dữ liệu ôn tập mồ côi.

---

## 6. Case đặc biệt / rủi ro đã biết (không bắt buộc sửa ngay, nhưng nên biết)

- [ ] **6.1** Xoá bộ trong lúc đang mở dở màn "Học từ mới" của đúng bộ đó (mở "Học từ mới", back giữa chừng, xoá bộ, quay lại màn học nếu còn) — quan sát có crash hoặc dữ liệu rác không.
- [ ] **6.2** Force-kill app ngay sau khi bấm "Xoá bộ" (kill Task Manager thật nhanh) — mở lại app, kiểm tra bộ đã xoá có quay lại không, số liệu ở các bộ khác có bất thường không.
- [ ] **6.3** Mất mạng **giữa lúc** đang gọi Online tra cứu (bật autofill rồi tắt Wi-Fi ngay khi đang loading) — không crash, báo lỗi hợp lý sau khi request fail/timeout.
- [ ] **6.4** Gõ từ có ký tự đặc biệt/emoji vào ô "Từ tiếng Anh" — không crash, lưu được bình thường (không có giới hạn ký tự ở form).

---

## Ghi chú theo dõi

| # | Ngày test | Kết quả | Ghi chú |
|---|-----------|---------|---------|
|   |           |         |         |
