# Thiết kế cơ sở dữ liệu

Ứng dụng dùng **SQLite**, tách thành **2 file độc lập** để dữ liệu từ vựng (chỉ đọc) và
tiến độ học của người dùng (đọc/ghi) không ảnh hưởng lẫn nhau — cập nhật bộ từ vựng
mới (thay file `vocab.db`) sẽ không xóa lịch sử học tập của người dùng.

| File | Chế độ | Vai trò | Nơi lưu |
|---|---|---|---|
| `vocab.db` | Read-only | Từ vựng, chương, ví dụ — đóng gói sẵn trong app | Copy từ `assets/db/vocab.db` ra thư mục dữ liệu app khi chạy lần đầu |
| `user.db` | Read-write | Tiến độ học, lịch ôn tập (SRS), lịch sử tra cứu | Tạo mới trong thư mục dữ liệu app (rỗng ở lần cài đầu) |

Cả hai đều nằm trong thư mục dữ liệu riêng của app (`getApplicationSupportDirectory()`):
Windows là `%APPDATA%\<app>\...`, Android/iOS là sandbox riêng của app.

---

## 1. `vocab.db` — dữ liệu từ vựng (read-only)

Sinh một lần từ giáo trình *"Tiếng Anh chuyên ngành Cảnh sát biển"* bằng script
Python trong `tools/pdf_to_sqlite/` (xem Giai đoạn 1), rồi đóng gói vào
`assets/db/vocab.db`. Ứng dụng không bao giờ ghi vào file này.

### Bảng `chapters`

Từ vựng được nhóm theo **6 chương chuyên đề** (không theo 14 unit của giáo trình gốc,
mà theo chủ đề chuyên môn để tiện tra cứu và học):

| Cột | Kiểu | Mô tả |
|---|---|---|
| `id` | INTEGER PK | |
| `chapter_no` | INTEGER | Số thứ tự hiển thị (1–6) |
| `title` | TEXT | Tên chương |

6 chương hiện có trong dữ liệu: *Quân sự chung, Hàng hải, Thông tin ra đa, Vũ khí,
Cơ điện, Cảnh sát biển.*

### Bảng `words`

| Cột | Kiểu | Mô tả |
|---|---|---|
| `id` | INTEGER PK | |
| `chapter_id` | INTEGER FK → `chapters.id` | Từ thuộc chương nào |
| `word` | TEXT | Từ/cụm từ tiếng Anh, dạng hiển thị |
| `word_lower` | TEXT (indexed) | Bản chữ thường — dùng để tra cứu, không phân biệt hoa/thường |
| `phonetic` | TEXT | Phiên âm IPA (có thể chứa nhiều phiên âm cho cụm từ, cách nhau bằng khoảng trắng) |
| `part_of_speech` | TEXT | Loại từ, viết tắt tiếng Việt: `dt` (danh từ, 2162 mục), `đt` (động từ, 203), `tt` (tính từ, 67). Còn 23 mục rỗng và 1 mục lỗi parser (`prep`, từ cụm "by land") — dữ liệu chưa được chuẩn hóa thành enum, chỉ lưu nguyên văn chuỗi từ PDF gốc. |
| `meaning_vi` | TEXT | Nghĩa tiếng Việt |
| `image_path` | TEXT, nullable | Đường dẫn ảnh minh họa (nếu giáo trình có) |
| `is_subentry` | INTEGER (0/1) | `1` nếu đây là mục con/cụm từ liên quan của một từ gốc (ví dụ `anchor buoy` là subentry của `buoy`) |

**Index:** `idx_words_word_lower` trên `word_lower` — bắt buộc để tra cứu nhanh trên
tập ~2.450 từ.

> Ghi chú thiết kế: `is_subentry` cho phép một mục từ vựng gốc (VD: `buoy` — "phao")
> hiển thị kèm các biến thể/cụm từ liên quan (`channel buoy`, `lifebuoy`...) ngay dưới
> nó trong màn Học theo chương, thay vì trộn lẫn ngang hàng.

### Bảng `examples`

| Cột | Kiểu | Mô tả |
|---|---|---|
| `id` | INTEGER PK | |
| `word_id` | INTEGER FK → `words.id` | |
| `example_en` | TEXT | Câu ví dụ tiếng Anh |
| `example_vi` | TEXT, nullable | Bản dịch tiếng Việt |

Một từ có thể có 0, 1 hoặc nhiều ví dụ.

### Sơ đồ quan hệ

```
chapters (1) ───< (N) words (1) ───< (N) examples
                       │
                       └─ is_subentry: tự tham chiếu theo ngữ nghĩa
                          (không có FK cứng, gộp theo word gốc lúc hiển thị)
```

---

## 2. `user.db` — dữ liệu người dùng (read-write)

Tạo rỗng khi cài app lần đầu; toàn bộ dữ liệu trong này là tiến độ học **của riêng
người dùng trên máy đó** — không đồng bộ, không sao lưu lên máy chủ (app hoạt động
hoàn toàn offline).

### Bảng `learned_words`

Vừa là "đã đánh dấu học" vừa lưu trạng thái thuật toán lặp lại ngắt quãng SM-2 cho
từ đó — không tách bảng riêng vì luôn dùng chung 1-1 với từ đã học.

| Cột | Kiểu | Mô tả |
|---|---|---|
| `id` | INTEGER PK AUTOINCREMENT | |
| `word_id` | INTEGER, **UNIQUE** | Tham chiếu `vocab.db → words.id` (không FK vật lý vì khác file DB) |
| `is_learned` | INTEGER (0/1), mặc định `1` | Đã đánh dấu học |
| `ease_factor` | REAL, mặc định `2.5` | Hệ số dễ nhớ (SM-2) |
| `interval_days` | INTEGER, mặc định `0` | Khoảng cách đến lần ôn tiếp theo, tính bằng ngày |
| `repetitions` | INTEGER, mặc định `0` | Số lần ôn đúng liên tiếp |
| `due_date` | INTEGER (epoch millis), nullable | Thời điểm đến hạn ôn tiếp theo |
| `last_reviewed` | INTEGER (epoch millis), nullable | Lần ôn gần nhất |

**Index:** `idx_learned_words_due` trên `due_date` — phục vụ truy vấn "các từ đến
hạn ôn hôm nay" chạy mỗi lần mở màn Ôn tập.

Ràng buộc `UNIQUE(word_id)` cho phép dùng `INSERT ... ON CONFLICT(word_id) DO UPDATE`
khi đánh dấu học một từ đã từng học trước đó (idempotent).

### Bảng `review_logs`

Lịch sử từng lượt ôn tập — phục vụ thống kê sau này (VD: biểu đồ số từ ôn theo ngày);
hiện chưa có màn hình nào đọc bảng này.

| Cột | Kiểu | Mô tả |
|---|---|---|
| `id` | INTEGER PK AUTOINCREMENT | |
| `word_id` | INTEGER | |
| `reviewed_at` | INTEGER (epoch millis) | |
| `rating` | INTEGER | Giá trị `q` truyền vào SM-2: `1`=Quên, `3`=Khó, `4`=Tốt, `5`=Dễ |

### Bảng `search_history`

| Cột | Kiểu | Mô tả |
|---|---|---|
| `id` | INTEGER PK AUTOINCREMENT | |
| `word` | TEXT | Từ khóa đã tra |
| `searched_at` | INTEGER (epoch millis) | |

Bảng đã có schema nhưng chưa được ghi/đọc ở bất kỳ màn hình nào — dự phòng cho tính
năng "lịch sử tra cứu" trong tương lai.

---

## 3. Cơ chế ôn tập — SM-2 (Spaced Repetition)

Người dùng đánh giá mức độ nhớ sau khi xem nghĩa bằng 4 mức, ánh xạ sang giá trị
chất lượng `q` của thuật toán SM-2 gốc:

| Nút hiển thị | `q` |
|---|---|
| Quên | 1 |
| Khó | 3 |
| Tốt | 4 |
| Dễ | 5 |

```
function review(card, q):
    if q < 3:
        card.repetitions = 0
        card.interval = 1
    else:
        if card.repetitions == 0: card.interval = 1
        elif card.repetitions == 1: card.interval = 6
        else: card.interval = round(card.interval * card.ease_factor)
        card.repetitions += 1

    card.ease_factor = max(1.3, card.ease_factor + (0.1 - (5-q) * (0.08 + (5-q) * 0.02)))
    card.due_date = today + card.interval (ngày)
```

Cài đặt tại [`src/lib/domain/srs/srs_scheduler.dart`](../src/lib/domain/srs/srs_scheduler.dart) —
thuần Dart, không phụ thuộc Flutter hay DB nên test được độc lập
([`src/test/unit/srs_scheduler_test.dart`](../src/test/unit/srs_scheduler_test.dart)).

**Hàng đợi "ôn hôm nay"** là một truy vấn đơn giản trên `learned_words`:

```sql
SELECT * FROM learned_words
WHERE is_learned = 1 AND due_date <= <23:59:59 hôm nay>
ORDER BY due_date ASC;
```

Kết quả được ghép với từ vựng tương ứng bằng cách gọi sang `vocab.db` (`wordById`)
cho từng dòng — chấp nhận N+1 query vì số từ đến hạn mỗi ngày nhỏ (thường < 50).

---

## 4. Vì sao tách 2 file thay vì 1 database chung

- **Cập nhật nội dung an toàn:** khi giáo trình sửa/bổ sung từ vựng, chỉ cần thay
  file `vocab.db` trong bản cập nhật app — không đụng đến `user.db` nên tiến độ học
  của người dùng không bị mất.
- **Khác chế độ mở:** `vocab.db` mở `OpenMode.readOnly` (an toàn, không lo ghi nhầm);
  `user.db` mở read-write bình thường và tự tạo schema nếu chưa có (`CREATE TABLE
  IF NOT EXISTS`) — không cần bước "cài đặt" riêng.
- **Liên kết giữa 2 file:** chỉ qua khóa ngoài **logic** (`word_id`), không có ràng
  buộc FK vật lý vì SQLite không hỗ trợ FK xuyên file. Tính toàn vẹn (từ bị xóa khỏi
  `vocab.db` nhưng còn `learned_words` tham chiếu) hiện chưa được xử lý — chấp nhận
  được vì `vocab.db` chỉ được cập nhật (thêm/sửa), chưa có kịch bản xóa từ.

## 5. Vị trí lưu trữ dữ liệu thực tế

| Nền tảng | Đường dẫn thư mục dữ liệu app |
|---|---|
| Windows | `%APPDATA%\<tên_app>\` |
| Android | Sandbox riêng của app (`/data/data/<package>/...`) |
| iOS | Application Support trong sandbox app |

`vocab.db` được copy lại từ assets mỗi khi kích thước file trong assets khác với bản
đã copy trước đó (`file.lengthSync() != bytes.length`) — cách đơn giản để phát hiện
bản cập nhật trong lúc phát triển mà không cần version number riêng.
