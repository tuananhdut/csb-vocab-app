# IX. HỒ SƠ THIẾT KẾ

## 1. Kiến trúc cơ sở dữ liệu

Cơ sở dữ liệu của phần mềm được thiết kế theo mô hình quan hệ và triển khai
bằng **SQLite** — một hệ quản trị cơ sở dữ liệu dạng nhúng, đóng gói ngay
bên trong ứng dụng, không cần cài đặt hay vận hành một máy chủ cơ sở dữ
liệu riêng biệt như các hệ thống SQL Server/MySQL truyền thống. Lựa chọn
này phù hợp với đặc thù một phần mềm chạy độc lập trên từng máy, phục vụ
đúng 1 người dùng/1 thiết bị, không đăng nhập và không đồng bộ dữ liệu qua
mạng — toàn bộ chức năng cốt lõi phải hoạt động được hoàn toàn không cần
Internet (nguyên tắc offline-first, xem mục 4.2).

Cơ sở dữ liệu được tách vật lý thành 2 tệp riêng biệt, mỗi tệp đảm nhiệm
một phạm vi dữ liệu độc lập (`lib/data/local/vocab_database.dart`,
`lib/data/local/user_database.dart`):

- **`vocab.db`** — cơ sở dữ liệu từ vựng, đóng gói sẵn trong gói cài đặt
  (`assets/db/vocab.db`), được sao chép ra thư mục dữ liệu riêng của ứng
  dụng ở lần chạy đầu tiên. Mở ở chế độ đọc-ghi: phần lớn dữ liệu (từ
  vựng, bài học) chỉ đọc, nhưng nhóm bảng "bộ từ điển" cần ghi được để
  người dùng tự tạo bộ từ điển cá nhân.
- **`user.db`** — cơ sở dữ liệu tiến độ học tập của người dùng, được tạo
  rỗng ở lần chạy đầu, lưu trạng thái ôn tập theo thuật toán lặp lại ngắt
  quãng SM-2. Tách riêng khỏi `vocab.db` để việc cập nhật dữ liệu từ vựng
  (khi phát hành bản mới) không ảnh hưởng tới tiến độ học đã lưu của
  người dùng.

Bộ lược đồ dữ liệu (suy ra trực tiếp từ mã nguồn tại
`lib/data/repositories/vocab_repository.dart` và
`lib/data/local/user_database.dart`) thể hiện rõ tính phân cấp và quan hệ
giữa các nhóm bảng như sau:

**(1) Nhóm bảng từ vựng cốt lõi**: bảng `words` lưu từng mục từ vựng
(từ, phiên âm, loại từ mã hoá số `part_of_speech`, nghĩa tiếng Việt
`meaning_vi`, ảnh minh hoạ `image_path`, cờ `is_subentry` đánh dấu mục là
biến thể/cụm từ liên quan đến một từ gốc, và cột `source` phân biệt nguồn
gốc dữ liệu: 0-SEED từ giáo trình gốc, 1-ONLINE tra được qua API rồi lưu
lại, 2-MANUAL do người dùng tự nhập). Đi kèm là bảng `examples` lưu câu ví
dụ song ngữ (`example_en`, `example_vi`) theo từng `word_id`.

**(2) Nhóm bảng phân loại — bộ từ điển (dictionary)**: bảng `dictionaries`
(gồm `id`, `name`, `is_default`, `sort_order`, `created_at`) mô tả một bộ
từ điển, có 2 loại — bộ mặc định đóng gói sẵn theo giáo trình
(`is_default = 1`, trong đó bộ `id = 1` là "Chưa phân loại" chứa các từ
chưa gán bộ nào) và bộ cá nhân do người dùng tự tạo (`is_default = 0`).
Quan hệ giữa từ vựng và bộ từ điển là quan hệ **nhiều-nhiều**, thể hiện
qua bảng trung gian `word_dictionaries (word_id, dictionary_id,
added_at)` — một từ có thể đồng thời thuộc nhiều bộ từ điển khác nhau.

**(3) Nhóm bảng bài học (dạng bài đọc)**: bảng `sections` (chủ đề lớn của
giáo trình, có `sort_order`) là cấp đứng trên bảng `chapters` — một
`section` chứa nhiều `chapter` (qua khoá ngoại `chapters.section_id`);
mỗi `chapter` được định nghĩa là một bài học, có cột `pdf_path` trỏ đến
nội dung bài đọc dạng tệp PDF hiển thị trong ứng dụng.

**(4) Nhóm bảng tiến độ học (SM-2)**: bảng `learned_words` trong `user.db`
(`id`, `word_id UNIQUE`, `is_learned`, `ease_factor` mặc định 2.5,
`interval_days`, `repetitions`, `due_date`, `last_reviewed`) lưu trạng
thái ôn tập của từng từ đã đánh dấu "đã học", đúng theo 4 tham số cốt lõi
của thuật toán SM-2 (hệ số dễ nhớ, số ngày giãn cách, số lần lặp lại liên
tiếp, ngày đến hạn ôn tiếp theo). Bảng có chỉ mục (`idx_learned_words_due`)
trên cột `due_date` để truy vấn nhanh hàng đợi từ đến hạn ôn mỗi ngày.
Do `vocab.db` và `user.db` là 2 tệp SQLite vật lý tách biệt, không thể
JOIN trực tiếp bằng SQL — các repository liên quan (ví dụ
`MyDictionariesRepository`) phải tự ghép dữ liệu giữa 2 nguồn ở tầng mã
Dart.

## 2. Kiến trúc chức năng phần mềm

Phần mềm được thiết kế với giao diện thân thiện, các chức năng chia theo
từng phân hệ rõ ràng để người dùng dễ dàng thao tác, xoay quanh 4 phân hệ
chính điều hướng qua khung `HomeShell` (`lib/features/home/home_shell.dart`)
cùng các phân hệ phụ trợ.

### 2.1. Phân hệ Tra cứu

Tra cứu từ vựng 2 chiều Anh→Việt/Việt→Anh trên kho gần 33.000 từ đã đóng
gói sẵn trong `vocab.db`, gõ đến đâu tự tìm đến đó (debounce 300ms), có
phân trang cuộn vô hạn. Khi có kết nối mạng và không tìm thấy khớp chính
xác trong dữ liệu cục bộ, hệ thống tự động bổ sung thêm 1 kết quả tra cứu
trực tuyến (Free Dictionary API cho phiên âm/loại từ, MyMemory Translation
API cho nghĩa tiếng Việt) nối vào cuối danh sách kết quả offline, đồng
thời cho phép người dùng lưu từ tra được vào một hoặc nhiều bộ từ điển cá
nhân.

### 2.2. Phân hệ Học theo chương (Section/Chapter)

Trình bày nội dung giáo trình theo cấu trúc 2 cấp Section → Chapter, mỗi
Chapter là một bài học hiển thị dưới dạng tài liệu PDF gốc. Ngoài ra,
người dùng có thể duyệt từ vựng theo từng bộ từ điển (chương) để xem toàn
bộ danh sách từ thuộc bộ đó, mở chi tiết từng từ qua khung xem nhanh dạng
bottom sheet dùng chung với phân hệ Tra cứu.

### 2.3. Phân hệ Dịch

Dịch đoạn văn bản 2 chiều Anh⇄Việt, ưu tiên gọi dịch vụ trực tuyến
(MyMemory Translation API) khi có mạng; khi mất mạng hoặc dịch vụ trực
tuyến lỗi/quá thời gian chờ, hệ thống tự động chuyển sang mô hình dịch máy
nơron chạy ngay trên thiết bị (opus-mt, lượng tử hoá INT8, chạy qua
ONNX Runtime) làm phương án dự phòng, không phụ thuộc vào kết nối mạng.

### 2.4. Phân hệ Ôn tập

Quản lý hàng đợi ôn tập các từ đã đánh dấu "đã học" và đến hạn theo lịch
tính bằng thuật toán SM-2, có thể ôn theo hàng đợi chung hoặc theo riêng
từng bộ từ điển. Mỗi phiên ôn tối đa 4 câu hỏi, ngẫu nhiên giữa 2 dạng
trắc nghiệm (chọn 1 trong 4 đáp án nghĩa tiếng Việt) và gõ chữ (gõ lại từ
tiếng Anh theo nghĩa cho sẵn); hệ thống tự động chấm đúng/sai và tự tính
lại lịch ôn tiếp theo, không yêu cầu người dùng tự đánh giá mức độ nhớ.

### 2.5. Phân hệ Từ điển của tôi (bộ từ điển cá nhân)

Cho phép người dùng tự tạo, đổi tên, xoá các bộ từ điển cá nhân; tự thêm
từ mới (nhập tay hoặc tự điền từ dữ liệu có sẵn khi trùng với từ đã tồn
tại), sửa/xoá các từ đã thêm, và gắn một từ vào nhiều bộ từ điển cùng lúc.
Mỗi bộ từ điển cá nhân có thể được ôn tập riêng thông qua phân hệ Ôn tập.

### 2.6. Phân hệ Nhắc ôn tập

Cho phép bật/tắt nhắc ôn tập tổng thể, đặt giờ nhắc và chọn các thứ trong
tuần áp dụng, có kiểm tra và yêu cầu cấp quyền thông báo hệ thống trước
khi cho phép đặt lịch. Trên Android/iOS, lịch nhắc hoạt động cả khi ứng
dụng đã đóng; trên Windows (do hạn chế nền tảng) chỉ nhắc được trong lúc
ứng dụng đang mở.

## 3. Thiết kế và cấu trúc giao diện

Giao diện được thiết kế theo hướng thích ứng (responsive/adaptive), tự
động thay đổi cách bố trí điều hướng theo kích thước màn hình
(`MediaQuery` so sánh với ngưỡng 700px):

- **Trên máy tính (Windows, cửa sổ rộng)**: sử dụng thanh điều hướng cố
  định bên trái (sidebar), tiêu đề trang hiển thị qua một khối tiêu đề
  riêng phía trên nội dung thay cho thanh AppBar mặc định.
- **Trên điện thoại (Android/iOS, màn hình hẹp)**: sử dụng thanh điều
  hướng dưới (bottom navigation bar), kết hợp thanh AppBar chuẩn phía
  trên.

Cả 2 dạng bố trí đều dùng chung **4 mục điều hướng chính**: **Tra cứu —
Học — Dịch — Từ điển của tôi**. Chuyển đổi giữa các mục không làm mất
trạng thái/vị trí cuộn của các mục còn lại (giữ toàn bộ 4 màn hình con
sống đồng thời). Trên mục "Từ điển của tôi" có hiển thị số lượng từ đang
đến hạn ôn tập dưới dạng huy hiệu (badge) đỏ, và có chỉ báo trạng thái kết
nối mạng (Online/Offline) đặt cạnh khu vực điều hướng.

Toàn bộ giao diện dùng chung một bộ màu nhất quán, lấy cảm hứng từ logo
Cảnh sát biển Việt Nam (tông xanh navy chủ đạo, kết hợp vàng phù hiệu và
đỏ), áp dụng thống nhất trên mọi màn hình và mọi nền tảng.

## 4. Nguyên tắc hoạt động

### 4.1. Luồng hoạt động nghiệp vụ

Luồng nghiệp vụ chính của phần mềm vận hành theo trình tự khép kín sau:

1. Người dùng tra cứu hoặc duyệt từ vựng qua phân hệ Tra cứu/Học.
2. Khi gặp từ cần ghi nhớ, người dùng đánh dấu **"Đã học"** — hệ thống
   ghi (hoặc cập nhật) một dòng trong bảng `learned_words` của `user.db`,
   khởi tạo trạng thái SM-2 mặc định.
3. Từ đã đánh dấu được đưa vào **hàng đợi ôn tập**, xuất hiện khi
   `due_date` của từ đó nhỏ hơn hoặc bằng ngày hiện tại.
4. Khi tới hạn ôn tập, phân hệ Ôn tập đưa ra câu hỏi dạng trắc nghiệm
   hoặc gõ chữ (chọn ngẫu nhiên) cho từng từ trong hàng đợi.
5. Hệ thống tự động chấm đúng/sai câu trả lời, suy ra mức đánh giá chất
   lượng ghi nhớ tương ứng của thuật toán SM-2 (trả lời sai → mức thấp
   nhất; trả lời đúng, tuỳ đã đạt đủ số lần đúng liên tiếp hay chưa → mức
   trung bình hoặc mức cao).
6. Dựa trên mức đánh giá đó, `SrsScheduler` tính lại `interval_days`,
   `ease_factor`, `repetitions` và `due_date` mới cho lần ôn tiếp theo —
   khép lại một vòng lặp học/ôn theo nguyên lý lặp lại ngắt quãng.

### 4.2. Nguyên tắc offline-first

Toàn bộ dữ liệu từ vựng, bài học và mã nguồn xử lý được đóng gói sẵn ngay
trong gói cài đặt (`assets/db/vocab.db`) — người dùng không cần tải thêm
dữ liệu sau khi cài đặt. Mọi chức năng cốt lõi (tra cứu, học theo
chương/section, ôn tập theo lịch SM-2) hoạt động đầy đủ hoàn toàn không
cần kết nối Internet.

Chỉ có 2 chức năng mang tính **bổ sung, tuỳ chọn** cần có mạng: (1) bổ
sung thêm 1 kết quả tra cứu/dịch nghĩa từ dịch vụ từ điển trực tuyến khi
không có sẵn trong dữ liệu cục bộ (phân hệ Tra cứu), và (2) ưu tiên dùng
dịch vụ dịch thuật trực tuyến có độ chính xác cao hơn (phân hệ Dịch). Cả
hai chức năng này đều được thiết kế để tự động và êm ái chuyển về chế độ
hoạt động ngoại tuyến (dùng dữ liệu cục bộ / mô hình dịch trên thiết bị)
ngay khi mất kết nối mạng hoặc khi dịch vụ trực tuyến không phản hồi kịp
thời, không làm gián đoạn hay chặn giao diện người dùng.

## 5. Quy trình cài đặt và triển khai

Phần mềm được đóng gói và phân phối dưới hình thức một tệp cài đặt duy
nhất cho từng nền tảng, không đòi hỏi cài đặt thêm bất kỳ phần mềm quản
trị cơ sở dữ liệu nào khác — khác biệt căn bản so với các hệ thống sử
dụng SQL Server phải cài đặt và cấu hình máy chủ cơ sở dữ liệu riêng —
vì toàn bộ cơ sở dữ liệu (SQLite) đã được nhúng sẵn ngay trong gói cài
đặt của ứng dụng:

- **Windows**: tệp cài đặt `.exe`, có trình cài đặt tự động dẫn dắt từng
  bước, tự tạo shortcut khởi chạy, và hỗ trợ gỡ cài đặt chuẩn qua hệ
  điều hành.
- **Android**: tệp cài đặt `.apk`, cài đặt trực tiếp trên thiết bị.
- **iOS**: gói ứng dụng cài đặt theo cơ chế phân phối chuẩn của nền tảng
  iOS.

Sau khi cài đặt, ở lần khởi chạy đầu tiên ứng dụng tự sao chép cơ sở dữ
liệu từ vựng đóng gói sẵn ra thư mục dữ liệu riêng của ứng dụng và khởi
tạo cơ sở dữ liệu tiến độ học rỗng — toàn bộ quá trình diễn ra tự động,
không cần thao tác thủ công nào từ người dùng hay quản trị viên.

## 6. Mã nguồn minh hoạ

### 6.1. Tính lịch ôn tập theo thuật toán SM-2

Đoạn mã dưới đây trích từ `lib/domain/srs/srs_scheduler.dart` — hàm
`review()` nhận trạng thái SM-2 hiện tại của một từ và mức đánh giá chất
lượng ghi nhớ (`rating`), trả về trạng thái mới với `interval_days`,
`ease_factor`, `repetitions` và `due_date` đã được tính lại:

```dart
class SrsScheduler {
  const SrsScheduler();

  /// Tính trạng thái SRS mới sau khi người dùng đánh giá 1 lượt ôn.
  /// [now] cho phép truyền giờ cố định khi test; mặc định là hiện tại.
  SrsCardState review(SrsCardState card, ReviewRating rating, {DateTime? now}) {
    final q = rating.quality;
    var repetitions = card.repetitions;
    var interval = card.intervalDays;

    if (q < 3) {
      repetitions = 0;
      interval = 1;
    } else {
      if (repetitions == 0) {
        interval = 1;
      } else if (repetitions == 1) {
        interval = 6;
      } else {
        interval = (interval * card.easeFactor).round();
      }
      repetitions += 1;
    }

    final easeFactor = math.max(
      1.3,
      card.easeFactor + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02)),
    );

    final today = now ?? DateTime.now();
    final todayMidnight = DateTime(today.year, today.month, today.day);
    final dueDate = todayMidnight.add(Duration(days: interval));

    return card.copyWith(
      repetitions: repetitions,
      intervalDays: interval,
      easeFactor: easeFactor,
      dueDate: dueDate,
      lastReviewed: today,
    );
  }
}
```

### 6.2. Đánh giá "từ khó" dựa trên hệ số dễ nhớ

Cùng tệp trên, hàm phụ trợ dùng để làm nổi bật các từ có hệ số dễ nhớ thấp
(khó nhớ) trong danh sách hàng đợi ôn tập, không ảnh hưởng đến việc tính
lịch ôn:

```dart
/// "Từ khó" — chỉ dùng để hiển thị/ưu tiên nổi bật trong hàng đợi, KHÔNG
/// ảnh hưởng `ORDER BY`/lịch ôn (SM-2 tự lo qua `due_date`, xem OQ-3 ở
/// `docs/csb-vocab-analysis/tasks/02-review-multi-mode/01-analysis.md`).
/// Ngưỡng 1.5 nằm gần sàn cứng 1.3 của `easeFactor`.
bool isDifficult(SrsCardState state) => state.easeFactor <= 1.5;
```

### 6.3. Truy vấn tra cứu từ vựng 2 chiều

Đoạn mã dưới đây trích từ `lib/data/repositories/vocab_repository.dart`
— hàm `search()` thực hiện tra cứu 2 chiều (khớp cột `word_lower` hoặc
`meaning_vi` tuỳ hướng tra), loại trừ các từ do người dùng tự nhập
(`source = 2`), sắp xếp ưu tiên khớp chính xác → khớp tiền tố → còn lại
theo độ dài từ, có hỗ trợ phân trang qua `LIMIT`/`OFFSET`:

```dart
List<VocabWord> search(
  String query, {
  required SearchDirection direction,
  int limit = 50,
  int offset = 0,
}) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return const [];
  final like = '%$q%';
  final prefix = '$q%';

  final matchColumn = switch (direction) {
    SearchDirection.enToVi => 'w.word_lower LIKE ?',
    SearchDirection.viToEn => 'lower(w.meaning_vi) LIKE ?',
  };
  final matchParams = [like];

  final rows = _db.select(
    '''$_selectWord
       WHERE w.source != 2 AND $matchColumn
       ORDER BY
         CASE WHEN w.word_lower = ? THEN 0
              WHEN w.word_lower LIKE ? THEN 1 ELSE 2 END,
         length(w.word), w.word_lower, w.id
       LIMIT ? OFFSET ?''',
    [...matchParams, q, prefix, limit, offset],
  );
  return rows.map(_wordFromRow).toList();
}
```
