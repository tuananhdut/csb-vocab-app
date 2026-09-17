# IV. TÍNH KHOA HỌC KỸ THUẬT VÀ CÔNG NGHỆ

## 1. Cơ sở lý thuyết xây dựng phần mềm

Tính năng ôn tập từ vựng của phần mềm được xây dựng trên nền tảng thuật toán **lặp lại ngắt quãng SM-2 (Spaced Repetition — SuperMemo Algorithm)**, một thuật toán khoa học đã được kiểm chứng và ứng dụng rộng rãi trong lĩnh vực học ngoại ngữ trên thế giới. Bản chất khoa học của SM-2 là dựa trên quy luật quên lãng (forgetting curve) của trí nhớ con người, qua đó tính toán và giãn cách thời điểm ôn lại một từ vựng sao cho tối ưu hóa khả năng ghi nhớ dài hạn với số lần ôn tập ít nhất.

Thuật toán được cài đặt thuần Dart tại `lib/domain/srs/srs_scheduler.dart` (lớp `SrsScheduler`), không phụ thuộc vào Flutter hay tầng cơ sở dữ liệu, đảm bảo tính độc lập, dễ kiểm thử (unit test) và dễ bảo trì. Cơ chế vận hành cụ thể như sau:

- Mỗi lượt ôn tập, hệ thống tự động suy ra một giá trị chất lượng trả lời **q** (quality, thang 1–5) căn cứ vào kết quả đúng/sai của người học (trả lời sai → q = 1; trả lời đúng nhưng chưa ổn định → q = 4; trả lời đúng và đã ổn định từ 3 lần liên tiếp trở lên → q = 5).
- **Trường hợp q < 3 (trả lời sai):** hệ thống đặt lại số lần lặp (`repetitions`) về 0 và khoảng cách ôn tập tiếp theo (`interval`) về 1 ngày — buộc từ vựng phải được ôn lại ngay để củng cố trí nhớ.
- **Trường hợp q ≥ 3 (trả lời đúng):** khoảng cách ôn tập được kéo giãn dần theo quy luật:
  - Lần ôn đúng đầu tiên: khoảng cách 1 ngày.
  - Lần ôn đúng thứ hai: khoảng cách 6 ngày.
  - Từ lần thứ ba trở đi: khoảng cách mới = khoảng cách trước đó × hệ số dễ nhớ (`ease factor`), làm tròn.
- **Hệ số dễ nhớ (ease factor)** được cập nhật sau mỗi lượt ôn theo công thức chuẩn SM-2, tăng nếu người học trả lời tốt, giảm nếu trả lời kém, và được **giới hạn sàn (floor) ở mức 1,3** nhằm bảo đảm khoảng cách ôn tập không bị thu hẹp quá mức, gây phản tác dụng.
- Hệ thống dùng giá trị `easeFactor ≤ 1,5` để nhận diện "từ khó", phục vụ việc hiển thị ưu tiên trong hàng đợi ôn tập cho người học chú ý hơn.

Việc ứng dụng một thuật toán có cơ sở khoa học đã được kiểm chứng, thay vì áp dụng các khoảng ôn tập cố định theo kinh nghiệm (ví dụ 1-3-7-14-30 ngày), là điểm khác biệt cốt lõi tạo nên tính khoa học của phần mềm, giúp cá nhân hóa lộ trình ôn tập theo đúng năng lực ghi nhớ thực tế của từng cán bộ, chiến sĩ.

## 2. Phân tích hệ thống và yêu cầu kỹ thuật

### 2.1. Các thông số chủ yếu

**a) Các quy trình nghiệp vụ được tin học hóa**

- **Quy trình tra cứu từ vựng song ngữ Anh ⇄ Việt:** tra cứu hai chiều trong cơ sở dữ liệu từ vựng cục bộ (`vocab.db`, đóng gói sẵn cùng phần mềm); khi không tìm được kết quả khớp chính xác và thiết bị đang có kết nối mạng, hệ thống tự động bổ sung thêm kết quả tra cứu trực tuyến (Online) từ các dịch vụ từ điển/dịch thuật công khai. Người dùng có thể chủ động lưu từ tra được qua Online vào cơ sở dữ liệu cục bộ bằng chức năng "Thêm vào bộ".
- **Quy trình học theo chương/bài đọc:** tổ chức nội dung học theo cấu trúc Section (phần) chứa nhiều Chapter (bài học), mỗi bài học gắn với nội dung tài liệu dạng PDF để người học nghiên cứu theo giáo trình *"Tiếng Anh chuyên ngành Cảnh sát biển"*.
- **Quy trình dịch văn bản Anh ⇄ Việt:** ưu tiên dịch trực tuyến khi có mạng; khi mất kết nối mạng hoặc dịch vụ trực tuyến gián đoạn, hệ thống tự động chuyển sang dịch bằng mô hình dịch máy nơ-ron (neural machine translation) cài đặt sẵn trên thiết bị (on-device), bảo đảm chức năng dịch vẫn hoạt động được trong điều kiện không có Internet.
- **Quy trình ôn tập theo thuật toán SM-2:** tổ chức hàng đợi các từ đến hạn ôn tập (due), tổ chức phiên ôn dưới hình thức trắc nghiệm và gõ chữ (tự động chấm điểm), từ kết quả trả lời tính toán lại lịch ôn tập tiếp theo cho từng từ.
- **Quy trình nhắc nhở lịch học:** nhắc trong ứng dụng khi có từ đến hạn ôn tập; hỗ trợ thêm lịch nhắc theo khung giờ và ngày trong tuần tùy chỉnh trên nền tảng di động (có xin quyền thông báo hệ thống trước khi thiết lập lịch).

**b) Các đối tượng tham gia**

- **Người sử dụng:** cán bộ, chiến sĩ Cảnh sát biển học tập từ vựng — mô hình một người dùng/một thiết bị, không phân vai trò, không đăng nhập, không đồng bộ nhiều thiết bị.
- **Thiết bị:** máy tính cài hệ điều hành Windows, điện thoại/máy tính bảng Android hoặc iOS.
- **Dữ liệu:** cơ sở dữ liệu SQLite đóng gói sẵn cùng phần mềm (từ vựng, bài học) và cơ sở dữ liệu tiến độ học tập lưu cục bộ trên thiết bị của người dùng.

**c) Các yêu cầu của người sử dụng**

- Giao diện đơn giản, trực quan, dễ thao tác, phù hợp với người dùng không chuyên về công nghệ thông tin.
- Tra cứu, học tập nhanh chóng, không yêu cầu phải luôn có kết nối mạng.
- Sử dụng được trên nhiều loại thiết bị phổ biến (máy tính Windows, điện thoại Android, iOS) mà không thay đổi trải nghiệm.

### 2.2. Các yêu cầu phi chức năng

**a) Yêu cầu đối với cơ sở dữ liệu**

Phần mềm sử dụng hệ quản trị cơ sở dữ liệu nhúng **SQLite** (thông qua các thư viện `sqlite3` và `sqlite3_flutter_libs` cho nền tảng Flutter), không sử dụng máy chủ cơ sở dữ liệu tập trung. Dữ liệu từ vựng được đóng gói sẵn trong phần mềm ngay từ khi cài đặt (`assets/db/vocab.db`); dữ liệu tiến độ học tập, trạng thái ôn tập của người dùng được khởi tạo và lưu trữ cục bộ ngay trên thiết bị cài đặt.

**b) Yêu cầu an toàn thông tin**

Toàn bộ dữ liệu học tập, tiến độ ôn tập của người dùng được lưu trữ hoàn toàn cục bộ trên thiết bị, không truyền tải hay lưu trữ trên bất kỳ máy chủ trung tâm nào, không thu thập thông tin định danh cá nhân. Chỉ khi người dùng chủ động sử dụng chức năng tra cứu/dịch trực tuyến, phần mềm mới gửi nội dung từ/câu cần tra cứu tới các dịch vụ từ điển, dịch thuật công khai, miễn phí, không yêu cầu khóa truy cập (API key) và không kèm theo thông tin định danh cá nhân của người dùng.

**c) Yêu cầu về thời gian xử lý**

Chức năng tra cứu trong cơ sở dữ liệu cục bộ được thiết kế để phản hồi gần như tức thời, đã được tối ưu bằng cơ chế phân trang và truy vấn có chỉ mục nhằm bảo đảm tốc độ tra cứu ổn định trên tập dữ liệu từ vựng có quy mô lớn (hàng chục nghìn mục từ).

**d) Yêu cầu về cài đặt, hạ tầng**

Phần mềm được đóng gói theo từng nền tảng (gói cài đặt cho Windows, gói cài đặt cho Android; đối với iOS triển khai theo hình thức cài đặt trực tiếp phù hợp với chính sách của nền tảng), không đòi hỏi triển khai máy chủ ứng dụng hay máy chủ cơ sở dữ liệu riêng, không yêu cầu cấu hình hạ tầng mạng phức tạp.

**đ) Các ràng buộc hệ thống**

Phần mềm vận hành theo nguyên tắc **offline-first**: toàn bộ các nghiệp vụ cốt lõi (tra cứu từ vựng cục bộ, học theo chương/bài đọc, ôn tập theo thuật toán SM-2) đều hoạt động đầy đủ không cần kết nối Internet; kết nối mạng chỉ đóng vai trò bổ sung, nâng cao (tra cứu/dịch mở rộng). Mô hình sử dụng là một người dùng trên một thiết bị, không có khái niệm vai trò hay phân quyền nhiều cấp.

**e) Yêu cầu về địa chỉ IPv4/IPv6**

Không áp dụng do phần mềm không xây dựng máy chủ trung tâm/backend riêng. Trong trường hợp người dùng chủ động sử dụng chức năng tra cứu/dịch trực tuyến, phần mềm kết nối tới các dịch vụ công khai bên ngoài thông qua giao thức HTTP/HTTPS tiêu chuẩn, không phụ thuộc vào việc cấu hình địa chỉ IP cụ thể phía máy chủ do đơn vị quản lý.

**g) Yêu cầu phi chức năng khác**

Phần mềm bảo đảm tính đa nền tảng thực chất, sử dụng chung một bộ mã nguồn (single codebase) viết bằng công nghệ Flutter để triển khai đồng thời trên Windows, Android và iOS, giúp tiết kiệm chi phí phát triển, bảo trì và bảo đảm tính đồng nhất về nghiệp vụ, giao diện giữa các nền tảng.

## 3. Ứng dụng công nghệ

Phần mềm được xây dựng trên nền tảng và các công nghệ sau (căn cứ theo khai báo phụ thuộc thực tế tại tệp `pubspec.yaml` của dự án):

- **Flutter (ngôn ngữ Dart):** framework phát triển ứng dụng đa nền tảng do Google phát triển, cho phép triển khai đồng thời trên Windows, Android, iOS từ một bộ mã nguồn duy nhất.
- **Quản lý trạng thái (state management):** thư viện `flutter_riverpod`, bảo đảm luồng dữ liệu trong ứng dụng rõ ràng, dễ kiểm soát, dễ kiểm thử.
- **Điều hướng màn hình:** thư viện `go_router`.
- **Cơ sở dữ liệu:** SQLite nhúng trực tiếp trong ứng dụng thông qua các thư viện `sqlite3` và `sqlite3_flutter_libs`, không cần cài đặt hay vận hành máy chủ cơ sở dữ liệu riêng.
- **Dịch máy nơ-ron chạy trên thiết bị (on-device neural machine translation):** sử dụng thư viện `flutter_onnxruntime` để nạp và chạy mô hình dịch máy đã được huấn luyện sẵn theo kiến trúc MarianMT (họ mô hình opus-mt), đã được lượng tử hóa (quantize INT8) nhằm giảm dung lượng và tăng tốc độ suy luận, phù hợp chạy trên thiết bị di động cấu hình phổ thông; kèm theo thư viện `dart_sentencepiece_tokenizer` phục vụ mã hóa/giải mã văn bản cho mô hình. Cơ chế này đóng vai trò dự phòng (fallback) khi thiết bị không có kết nối mạng hoặc dịch vụ dịch trực tuyến gián đoạn.
- **Tích hợp dịch vụ tra cứu, dịch thuật trực tuyến:** khi thiết bị có kết nối mạng (giám sát qua thư viện `connectivity_plus`), phần mềm gọi tới các dịch vụ công khai, miễn phí, không yêu cầu khóa truy cập là **MyMemory Translation API** (dịch nghĩa Anh–Việt) và **Free Dictionary API** (tra cứu phiên âm, loại từ tiếng Anh), thông qua thư viện HTTP client `dio`.
- **Hệ thống thông báo, nhắc nhở:** thư viện `flutter_local_notifications` kết hợp thư viện `timezone` để lập lịch nhắc ôn tập theo khung giờ tùy chỉnh; thư viện `permission_handler` phục vụ xin quyền thông báo hệ thống.
- **Đọc tài liệu bài học:** thư viện `pdfx` phục vụ hiển thị nội dung bài học dạng tệp PDF.
- **Các thư viện hỗ trợ khác:** `path`, `path_provider` (quản lý đường dẫn tệp/thư mục dữ liệu cục bộ); `crypto` (kiểm tra tính toàn vẹn tệp mô hình dịch tải về bằng SHA-256); `archive` (giải nén gói mô hình dịch); `shared_preferences` (lưu cấu hình, tùy chọn người dùng); `flutter_tts` (phát âm từ vựng); `file_selector` (chọn tệp khi cần thiết).

Việc lựa chọn kết hợp giữa dịch vụ trực tuyến công khai (khi có mạng) và mô hình trí tuệ nhân tạo chạy cục bộ trên thiết bị (khi không có mạng) thể hiện tính ứng dụng công nghệ hiện đại, đồng thời vẫn bảo đảm nguyên tắc vận hành offline-first phù hợp với điều kiện tác chiến, huấn luyện đặc thù của lực lượng Cảnh sát biển.

## 4. Thiết kế chức năng phần mềm

Phần mềm được thiết kế thành các mô-đun chức năng chính như sau:

- **Tra cứu từ vựng song ngữ Anh ⇄ Việt (offline kết hợp online):** tra cứu hai chiều trong bộ dữ liệu từ vựng cục bộ; tự động bổ sung kết quả tra cứu trực tuyến khi không có kết quả khớp chính xác cục bộ và thiết bị đang có kết nối mạng; cho phép lưu từ tra được qua Online vào bộ từ điển cá nhân.
- **Học theo chương/bài đọc:** tổ chức nội dung học theo cấu trúc phần (Section) và bài học (Chapter), mỗi bài học gắn nội dung tài liệu chuyên ngành dạng PDF, kèm danh sách từ vựng của từng chương để người học tra cứu nhanh trong quá trình học.
- **Dịch văn bản Anh ⇄ Việt:** dịch đoạn văn bản ngắn theo hai chiều, ưu tiên sử dụng dịch vụ trực tuyến khi có mạng để bảo đảm độ chính xác, tự động chuyển sang mô hình dịch máy cài đặt sẵn trên thiết bị khi mất kết nối mạng.
- **Ôn tập theo thuật toán SM-2:** tổ chức hàng đợi các từ vựng đến hạn ôn tập, thực hiện phiên ôn dưới hai hình thức trắc nghiệm và gõ chữ có tự động chấm điểm, sau mỗi lượt trả lời tự động tính toán lại khoảng cách ôn tập tiếp theo cho từng từ theo cơ sở khoa học của thuật toán SM-2.
- **Từ điển cá nhân ("Từ điển của tôi"):** cho phép người dùng tự tạo các bộ từ vựng riêng theo nhu cầu, tự thêm từ mới (nhập tay hoặc lấy từ kết quả tra cứu trực tuyến), quản lý và ôn tập theo từng bộ từ điển cá nhân đã tạo.
- **Nhắc nhở lịch ôn tập tùy chỉnh:** nhắc trong ứng dụng khi có từ đến hạn ôn tập; trên nền tảng di động hỗ trợ thêm lịch nhắc theo khung giờ và ngày trong tuần do người dùng tự thiết lập, có xin quyền thông báo hệ thống trước khi kích hoạt.

Các mô-đun nêu trên được tổ chức chặt chẽ, có liên kết nghiệp vụ với nhau (ví dụ: từ tra cứu được trong mô-đun Tra cứu có thể được thêm trực tiếp vào Từ điển cá nhân; từ trong các bài học được đưa vào hàng đợi ôn tập của mô-đun Ôn tập), tạo thành một hệ thống thống nhất, khép kín, phục vụ hiệu quả cho nhu cầu tự học và ôn luyện tiếng Anh chuyên ngành của cán bộ, chiến sĩ Cảnh sát biển Việt Nam.
