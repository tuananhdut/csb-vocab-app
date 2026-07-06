# 04 — Thiết Kế Dữ Liệu & Xử Lý PDF

## 1. Nguồn dữ liệu: từ file PDF
Yêu cầu: **phân tích dữ liệu từ file PDF** để tạo cơ sở dữ liệu, lưu **SQLite**, dùng offline.

✅ **Đã chốt (A1, A2, A5):** nguồn là **PDF giáo trình từ vựng**, mỗi mục có đủ **6 trường** (từ EN, nghĩa VI, phiên âm IPA, loại từ, ví dụ, hình ảnh). Ảnh có sẵn trong PDF → trích xuất dùng luôn.
⏳ **Còn cần khách gửi:** (1) file PDF gốc để viết script parse; (2) file PDF thứ 2 định nghĩa chương (A3). Schema dưới đây đã cố định theo 6 trường trên; chỉ tinh chỉnh chi tiết sau khi xem file thực tế.

### 1.1 Pipeline tạo dữ liệu (chạy 1 lần, ngoài app)
```
File PDF  ──►  Trích xuất text  ──►  Parse thành cấu trúc  ──►  Sinh SQLite (vocab.db)  ──►  Đóng gói vào assets/db/
           (pdfplumber/PyMuPDF)     (từ, nghĩa, chương...)      (script Python/Dart)
```
- Đặt script trong `tools/pdf_to_sqlite/`.
- Kiểm tra thủ công một mẫu để đảm bảo parse đúng (PDF thường không đều → cần rà soát).
- Ghi log các dòng parse lỗi để sửa tay.

### 1.2 Các trường trích xuất (✅ đã chốt A2 — PDF có đủ 6 trường)
- Từ tiếng Anh (bắt buộc)
- Nghĩa tiếng Việt (bắt buộc)
- Phiên âm IPA
- Loại từ
- Ví dụ
- Hình ảnh (trích từ PDF → lưu `assets/images/words/`)
- Chương/bài (để chia FR-3 — lấy từ **PDF thứ 2**, A3)

> Trường nào một số mục bị thiếu trong PDF thì để trống (không bịa dữ liệu); giao diện tự ẩn trường trống.

## 2. Schema Database (SQLite)

Có thể để chung 1 file hoặc tách 2 file (khuyến nghị tách read-only / read-write).

### 2.1 Nhóm dữ liệu từ vựng (`vocab.db`, read-only)

**Bảng `chapters`** (chương / bài học — FR-3)
| Cột | Kiểu | Mô tả |
|-----|------|-------|
| id | INTEGER PK | |
| chapter_no | INTEGER | số thứ tự chương (1..11) |
| title | TEXT | tên chương |
| description | TEXT | mô tả (nếu có) |

**Bảng `words`**
| Cột | Kiểu | Mô tả |
|-----|------|-------|
| id | INTEGER PK | |
| chapter_id | INTEGER FK → chapters.id | từ thuộc chương nào |
| word | TEXT (indexed) | từ tiếng Anh (chữ thường để tìm) |
| word_display | TEXT | dạng hiển thị |
| phonetic | TEXT | phiên âm (nullable) |
| part_of_speech | TEXT | loại từ (nullable) |
| meaning_vi | TEXT | nghĩa tiếng Việt |
| image_path | TEXT | đường dẫn ảnh (nullable) |

**Bảng `examples`** (một từ có thể nhiều ví dụ)
| Cột | Kiểu | Mô tả |
|-----|------|-------|
| id | INTEGER PK | |
| word_id | INTEGER FK → words.id | |
| example_en | TEXT | câu ví dụ |
| example_vi | TEXT | dịch ví dụ (nullable) |

**Index bắt buộc:** `CREATE INDEX idx_words_word ON words(word);`
(Có thể thêm FTS5 nếu cần tìm nâng cao / phạm vi từ điển lớn — Q&A A4.)

### 2.2 Nhóm dữ liệu người dùng (`user.db`, read-write)

**Bảng `learned_words`** (đánh dấu đã học + trạng thái ôn tập — FR-5)
| Cột | Kiểu | Mô tả |
|-----|------|-------|
| id | INTEGER PK | |
| word_id | INTEGER | tham chiếu words.id |
| is_learned | INTEGER (0/1) | đã học |
| — trạng thái SRS — | | |
| ease_factor | REAL | mặc định 2.5 |
| interval_days | INTEGER | khoảng ôn (ngày) |
| repetitions | INTEGER | số lần nhớ đúng liên tiếp |
| due_date | INTEGER | timestamp đến hạn ôn |
| last_reviewed | INTEGER | lần ôn gần nhất |

**Bảng `search_history`**
| Cột | Kiểu | Mô tả |
|-----|------|-------|
| id | INTEGER PK | |
| word | TEXT | |
| searched_at | INTEGER | |

**Bảng `review_logs`** (thống kê)
| Cột | Kiểu | Mô tả |
|-----|------|-------|
| id | INTEGER PK | |
| word_id | INTEGER | |
| reviewed_at | INTEGER | |
| rating | INTEGER | 0=Quên,1=Khó,2=Tốt,3=Dễ |

## 3. Cơ chế ôn tập (FR-5)
✅ **Đã chốt D1 = Phương án A (SM-2).** Phương án B giữ lại chỉ để tham khảo/dự phòng.

### Phương án A (✅ ĐÃ CHỐT): SM-2 (lặp lại ngắt quãng)
```
function review(card, q):   # q: Quên=1, Khó=3, Tốt=4, Dễ=5
    if q < 3:
        card.repetitions = 0
        card.interval = 1
    else:
        if card.repetitions == 0: card.interval = 1
        elif card.repetitions == 1: card.interval = 6
        else: card.interval = round(card.interval * card.ease_factor)
        card.repetitions += 1
    card.ease_factor = max(1.3, card.ease_factor + (0.1 - (5-q)*(0.08 + (5-q)*0.02)))
    card.due_date = today + card.interval (ngày)
```

### Phương án B (không dùng — chỉ tham khảo): khoảng cố định
- Ôn lại sau 1 ngày → 3 ngày → 7 ngày → 14 ngày → 30 ngày.

**Hàng đợi ôn hôm nay:**
```sql
SELECT * FROM learned_words WHERE is_learned=1 AND due_date <= <cuối_ngày_hôm_nay> ORDER BY due_date ASC;
```

> Logic tách riêng trong `srs_scheduler.dart` → đổi giữa A/B dễ dàng.

## 4. Dịch (FR-4) — dữ liệu
- ✅ (đã chốt B1=a) Offline: tra `words` (Anh→Việt) và tra ngược `meaning_vi` (Việt→Anh) + bảng cụm từ nếu có. Không dùng API online ở MVP.

## 5. Vị trí lưu trữ dữ liệu (cho báo cáo)
- `vocab.db`: đóng gói trong app (`assets/db/`), copy ra thư mục dữ liệu app khi chạy lần đầu.
- `user.db`: tạo trong thư mục dữ liệu app.
- Windows: `%APPDATA%\<app>\...`; iOS: sandbox của app.

## 6. Phát âm
- Dùng `flutter_tts` (TTS offline của OS). Không đóng gói audio để tiết kiệm dung lượng (trừ khi khách yêu cầu).
