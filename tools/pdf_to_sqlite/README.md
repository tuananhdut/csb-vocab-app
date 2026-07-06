# pdf_to_sqlite — Sinh `vocab.db` từ PDF giáo trình

Script Python trích xuất dữ liệu từ vựng từ file **`assets/TA_chuyen_nganh_2.pdf`**
(giáo trình thuật ngữ chuyên ngành VN→EN) → cơ sở dữ liệu SQLite **`vocab.db`**
đóng gói sẵn cho app (Giai đoạn 1).

## Cách hoạt động

PDF là **text** (không phải ảnh scan) và định dạng **rất nhất quán bằng màu + font + size**,
nên dùng parser rule-based (không tốn token LLM):

| Thành phần | Nhận diện |
|-----------|-----------|
| Từ khóa tiếng Việt (headword) | xanh, **bold**, size ~14 |
| Từ tiếng Anh (equivalent) | xanh, thường, size 13–14 |
| Cụm từ con (sub-entry) | xanh, size ~12 (có/không dấu `~`) |
| Loại từ (POS) | đen, dạng `(dt.)`, `(tt.)`… |
| Phiên âm IPA | đen, bắt đầu `/` |
| Ví dụ Việt | đen thường |
| Ví dụ Anh | đen **nghiêng** |
| Chuyên ngành (= chương) | **đỏ**, bold, đầu mỗi trang |

Xử lý đặc biệt:
- **Cross-reference** `X (xem Y)` → không có từ tiếng Anh riêng → **bỏ** (đúng, không phải lỗi).
- **Alias** `X (Y)` → Y là dạng thay thế, gộp vào nghĩa của X.
- Màu xanh không đồng nhất (`#0000ff` và `#3333ff` ở chương VŨ KHÍ) → dùng `is_blue()`.
- Bỏ **catchword** (từ lặp size 20 ở chân trang) và chữ cái phân mục A–Z (size 48).

## Chạy

Yêu cầu: Python 3.10+ và `pymupdf` (xem `requirements.txt`).

```bash
pip install -r requirements.txt

python build_vocab.py \
  ../../assets/TA_chuyen_nganh_2.pdf \
  ../../src/assets/db/vocab.db \
  ../../src/assets/images/words \
  --no-images
```

- `--no-images`: bỏ qua trích ảnh (mặc định nên dùng — ảnh chưa được nén/lọc kỹ,
  xem mục "Việc còn lại").
- Các mục không parse được ghi vào `parse_warnings.log` để rà soát tay.

## Kết quả hiện tại

- **6 chương**: QUÂN SỰ CHUNG, HÀNG HẢI, THÔNG TIN RA ĐA, VŨ KHÍ, CƠ ĐIỆN, CẢNH SÁT BIỂN.
- **~1100 mục từ chính + ~1120 cụm từ con = ~2450 từ tiếng Anh**, 97% có phiên âm.
- Còn ~8 mục cần rà tay (ghi trong `parse_warnings.log`) — chủ yếu do từ tiếng Anh
  in đậm bất thường; <0.4%.

## Schema `vocab.db`

- `chapters(id, chapter_no, title)`
- `words(id, chapter_id, word, word_lower, phonetic, part_of_speech, meaning_vi, image_path, is_subentry)`
- `examples(id, word_id, example_en, example_vi)`

## Việc còn lại (tinh chỉnh)

- **Ảnh minh họa (A5):** bản trích thô ra 546 ảnh/70MB, mới khớp caption được ~22.
  Cần: chỉ lấy ảnh khớp từ khóa + nén (WebP) trước khi đóng gói. Tạm thời chưa gắn ảnh.
- ~8 mục từ in đậm bất thường: sửa tay hoặc bổ sung rule.
