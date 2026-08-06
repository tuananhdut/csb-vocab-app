# SCR-04 — Dịch Anh ⇄ Việt

**FR:** FR-4 · **Trạng thái:** ✅ Đã code — máy dịch neural on-device ·
**Nguồn:** `lib/features/translate/translate_screen.dart`

## Cơ chế (đã đổi hướng, xem `docs/spec_history.md` [IMPL-017])

Thiết kế ban đầu (tra ghép từ/cụm offline trong `vocab.db`, ghi ở phiên
bản trước của tài liệu này) **chưa từng được code** và đã bị thay bằng
**máy dịch neural chạy hoàn toàn on-device**:

- Model: Helsinki-NLP/opus-mt-en-vi (chiều Anh→Việt) và opus-mt-vi-en
  (chiều Việt→Anh), kiến trúc MarianMT, license Apache-2.0.
- Chạy qua ONNX Runtime (`flutter_onnxruntime`), model đã convert +
  quantize INT8 (xem `tools/onnx-model-conversion/`).
- **Tải model sau khi cài đặt**, không đóng gói sẵn trong app — mỗi
  chiều ~130-140MB (nén zip), tải độc lập theo yêu cầu người dùng (2
  nút tải riêng cho En→Vi và Vi→En). Host trên GitHub Releases của repo
  này (tag `mt-models-v1`).
- Sau khi tải xong: dịch hoàn toàn offline, không gửi văn bản ra ngoài.

## Kiến trúc code

- `lib/domain/entities/translation_direction.dart` — enum
  `TranslationDirection` (en→vi, vi→en).
- `lib/data/services/model_download_service.dart` — tải + verify
  SHA-256 + giải nén model (singleton, theo pattern `NotificationService`).
- `lib/data/services/translation_service.dart` — nạp ONNX session
  (encoder/decoder/decoder_with_past) theo từng chiều, vòng lặp decode
  autoregressive (greedy, dùng KV-cache). Đọc `config.json` động cho mỗi
  chiều (token đặc biệt khác nhau giữa 2 chiều, không hardcode).
- `lib/data/repositories/translation_providers.dart` — `ModelDownloadState`
  (sealed class), `modelDownloadStateProvider` (`StateProvider.family`),
  `translateProvider` (`FutureProvider.family`).
- `lib/features/translate/translate_screen.dart` +
  `widgets/model_download_prompt.dart` + `widgets/translate_panels.dart`
  — UI: chọn/đảo chiều dịch, state machine tải model, 2 khung nguồn/kết
  quả (debounce 500ms trước khi gọi inference).

## So với mockup

Mockup gốc (`docs/artifact-design/screens/screen-06-dich-nhanh.html`)
vẫn là cơ sở cho layout 2 khung nguồn/kết quả + nút đảo chiều — giữ
nguyên phần này. **Bỏ** `.chip-row` (hiển thị từng cặp từ đã ghép nghĩa,
vd `buoy → phao`) và ghi chú "Ghép nghĩa offline từ N mục từ điển" —
không còn đúng với cơ chế NMT (không có alignment từ-đối-từ rõ ràng như
tra từ điển). Thay bằng ghi chú ngắn về cơ chế dịch bằng AI offline.

## Hạn chế đã biết

- Model tổng quát, không fine-tune riêng cho thuật ngữ quân sự/hàng hải
  — câu thường dịch tốt, thuật ngữ chuyên ngành riêng (cấp bậc, loại
  tàu...) có thể không chính xác.
- Greedy decoding kết hợp suy luận CPU đa luồng: cùng 1 câu có thể cho
  kết quả khác nhau nhẹ (vẫn đúng ngữ pháp) giữa các lần dịch, khi có 2
  lựa chọn từ gần ngang xác suất — xem chi tiết `docs/spec_history.md`
  [IMPL-017]. Chấp nhận cho MVP.
- Chưa hỗ trợ resume tải dở dang — mất mạng giữa chừng thì tải lại từ
  đầu (đánh đổi có chủ đích cho v1).
