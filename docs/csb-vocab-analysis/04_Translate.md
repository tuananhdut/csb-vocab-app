# SCR-04 — Dịch Anh ⇄ Việt

**FR:** FR-4 · **Trạng thái:** ✅ Đã code — ưu tiên dịch Online, on-device
làm fallback · **Nguồn:** `lib/features/translate/translate_screen.dart`

## Cơ chế (đổi hướng lần 2, xem `docs/spec_history.md` [IMPL-025]; lần 1 ở [IMPL-017])

Bản đầu tiên (ghi ở phiên bản trước của tài liệu này) chỉ dịch bằng máy
dịch neural **hoàn toàn on-device** (opus-mt qua ONNX Runtime). Theo phản
ánh trực tiếp — model on-device độ chính xác còn thấp — đã đổi thành ưu
tiên dịch **Online** khi có mạng, model on-device chỉ còn là **fallback**:

- **Có mạng** → gọi **MyMemory Translation API** trước (dịch vụ đã dùng
  sẵn cho Tra cứu Online — SCR-02, `DictionaryApiService.translate()`,
  miễn phí, không cần key). Không cần tải model on-device trước khi dịch
  trong trường hợp này.
- **Không có mạng, hoặc MyMemory lỗi/timeout** → rơi về model on-device
  (opus-mt-en-vi / opus-mt-vi-en, MarianMT, chạy qua `flutter_onnxruntime`,
  quantize INT8) — phải tải model trước (mỗi chiều ~130-140MB, host trên
  GitHub Releases tag `mt-models-v1`, xem chi tiết cơ chế tải/verify ở
  [IMPL-017]).
- Vì model on-device giờ không bắt buộc khi online, màn hình vẫn cho
  user chủ động tải sẵn (để dùng khi mất mạng sau này) qua **`ModelStatusRow`**
  — 1 hàng trạng thái cố định dưới thanh chọn chiều dịch, chỉ hiện khi
  đang online mà model chưa `ModelReady` (ẩn khi đã tải xong; khi offline
  và chưa tải thì `ModelDownloadPrompt` — chặn cả màn — đã đủ, không hiện
  trùng lặp).

## Kiến trúc code

- `lib/domain/entities/translation_direction.dart` — enum
  `TranslationDirection` (en→vi, vi→en).
- `lib/data/services/dictionary_api_service.dart` — `translate()` (public,
  dùng chung với Tra cứu Online SCR-02) — nguồn dịch chính khi online.
- `lib/data/services/model_download_service.dart` — tải + verify
  SHA-256 + giải nén model on-device (singleton, theo pattern
  `NotificationService`).
- `lib/data/services/translation_service.dart` — nạp ONNX session
  (encoder/decoder/decoder_with_past) theo từng chiều, vòng lặp decode
  autoregressive (greedy, dùng KV-cache). Đọc `config.json` động cho mỗi
  chiều (token đặc biệt khác nhau giữa 2 chiều, không hardcode). Chỉ
  được gọi khi offline hoặc MyMemory lỗi.
- `lib/data/repositories/translation_providers.dart` — `ModelDownloadState`
  (sealed class), `modelDownloadStateProvider` (`StateProvider.family`),
  `translateProvider` (`FutureProvider.family` — tự chọn online/on-device
  theo `connectivityProvider`, xem [IMPL-025]).
- `lib/features/translate/translate_screen.dart` — chọn/đảo chiều dịch;
  `canTranslate = downloadState is ModelReady || isOnline` (không còn ép
  buộc tải model nếu đang online).
- `lib/features/translate/widgets/model_download_prompt.dart` — chặn cả
  màn, chỉ hiện khi offline + model chưa tải.
- `lib/features/translate/widgets/model_status_row.dart` — hàng trạng
  thái nhỏ, hiện khi online + model chưa `ModelReady` (mới, [IMPL-025]).
- `lib/features/translate/widgets/translate_panels.dart` — 2 khung
  nguồn/kết quả (debounce 500ms trước khi gọi `translateProvider`), bọc
  `SingleChildScrollView` (tránh tràn layout khi bàn phím mở) + dùng
  chung `lib/core/widgets/dismiss_keyboard_on_tap.dart` (chạm ra ngoài ô
  nhập để đóng bàn phím, cũng áp dụng cho "Tự thêm từ mới"). Trạng thái
  đang dịch hiện spinner nhỏ + chữ "Đang dịch…" (trước đó chỉ có spinner
  trơ trọi).

## So với mockup

Mockup gốc (`docs/artifact-design/screens/screen-06-dich-nhanh.html`)
vẫn là cơ sở cho layout 2 khung nguồn/kết quả + nút đảo chiều — giữ
nguyên phần này. **Bỏ** `.chip-row` (hiển thị từng cặp từ đã ghép nghĩa,
vd `buoy → phao`) và ghi chú "Ghép nghĩa offline từ N mục từ điển" —
không còn đúng với cơ chế NMT (không có alignment từ-đối-từ rõ ràng như
tra từ điển). Thay bằng ghi chú ngắn về cơ chế dịch bằng AI.

## Hạn chế đã biết

- Model on-device (chỉ còn dùng khi offline/MyMemory lỗi) là model tổng
  quát, không fine-tune riêng cho thuật ngữ quân sự/hàng hải — câu
  thường dịch tốt, thuật ngữ chuyên ngành riêng (cấp bậc, loại tàu...)
  có thể không chính xác. MyMemory (nguồn chính khi online) cũng không
  fine-tune riêng cho thuật ngữ chuyên ngành — chưa có benchmark so sánh
  độ chính xác 2 nguồn với nhau cho từ vựng chuyên ngành CSB cụ thể.
- Greedy decoding (model on-device) kết hợp suy luận CPU đa luồng: cùng
  1 câu có thể cho kết quả khác nhau nhẹ (vẫn đúng ngữ pháp) giữa các
  lần dịch — xem chi tiết `docs/spec_history.md` [IMPL-017]. Chấp nhận
  cho MVP, ảnh hưởng giảm nhiều vì đây giờ chỉ là fallback.
- Chưa hỗ trợ resume tải model on-device dở dang — mất mạng giữa chừng
  thì tải lại từ đầu (đánh đổi có chủ đích cho v1).
- MyMemory có quota (5.000-50.000 ký tự/ngày/IP, xem `02_Search.md`) —
  dùng chung quota với Tra cứu Online, chưa có cơ chế báo user khi gần
  chạm quota.
