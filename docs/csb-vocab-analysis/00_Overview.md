# 00 — Tổng Quan

> ⚠️ **Tài liệu này đang trong quá trình cập nhật theo định hướng mới**
> (chốt 2026-07-18, xem [IMPL-005] trong `docs/spec_history.md`). Các mục
> **Kiến trúc kỹ thuật**, **Mô hình dữ liệu** và **Ràng buộc** bên dưới mô tả
> **định hướng sắp tới**, có phần **chưa được code** — phân biệt rõ bằng nhãn
> `[ĐÃ CODE]` / `[ĐỊNH HƯỚNG MỚI — CHƯA CODE]` ở từng mục. Các file
> `01`–`07` (phân tích từng màn hình) vẫn mô tả đúng code thật hiện tại và
> **chưa được cập nhật theo định hướng mới này** — sẽ cập nhật ở bước kế
> tiếp cùng `docs/artifact-design/`.

## Bối cảnh

CSB Vocab App là ứng dụng học từ vựng tiếng Anh chuyên ngành, phục vụ lực
lượng Cảnh sát biển Việt Nam. Nguồn từ vựng lấy từ giáo trình
*"Tiếng Anh chuyên ngành Cảnh sát biển"* (tài liệu gốc: `assets/TA_chuyen_nganh.docx`,
`assets/TA_chuyen_nganh_2.pdf`, `assets/Tu_dien.pdf`), được xử lý thành
`assets/db/vocab.db` (script xử lý đã chạy xong và không còn giữ trong repo —
xem `docs/spec_history.md` [IMPL-002]).

## Kiến trúc kỹ thuật

- **Flutter** (Dart), state management bằng **Riverpod**.
- **Điều hướng:** `go_router` — chỉ 2 route cấp cao:
  - `/splash` → `SplashScreen`, tự chuyển sang `/home` sau
    `AppConstants.splashDuration` (5 giây) hoặc khi bấm "Bỏ qua".
  - `/home` → `HomeShell`, chứa toàn bộ 5 tab chính qua `IndexedStack`
    (không phải route riêng — chuyển tab không rebuild lại từ đầu).
- **Layout thích ứng (adaptive):** `HomeShell` đo `MediaQuery.sizeOf(context).width`
  so với `AppConstants.desktopBreakpoint` (700px):
  - **Desktop (Windows, cửa sổ rộng):** `NavigationRail` cố định bên trái.
  - **Mobile (Android/iOS, hẹp):** `NavigationBar` ở đáy.
- **Dữ liệu — [ĐÃ CODE]:** 2 SQLite tách biệt (tài liệu thiết kế DB riêng đã
  bị xoá — xem `../spec_history.md` [IMPL-003] — schema hiện suy ra từ code):
  - `vocab.db` — từ vựng, chương, ví dụ. Read-only, đóng gói sẵn trong assets.
    Cài đặt tại `../../lib/data/local/vocab_database.dart`.
  - `user.db` — tiến độ học, trạng thái SM-2, lịch sử ôn tập. Read-write, tạo
    rỗng lần đầu chạy app. Cài đặt tại `../../lib/data/local/user_database.dart`.
  - **[ĐỊNH HƯỚNG MỚI — CHƯA CODE]** Mô hình dữ liệu ở trên sẽ mở rộng đáng
    kể — xem mục "Mô hình dữ liệu — định hướng mới" bên dưới. Không phải
    thiết kế lại từ đầu: 2 file `vocab.db`/`user.db` vẫn giữ vai trò tương tự
    (nội dung đóng gói sẵn / dữ liệu riêng của user), nhưng thêm bảng quan hệ
    N-N cho bộ từ điển, thêm khái niệm Section/Chapter dạng bài học, và thêm
    một tầng gọi API ngoài khi có mạng.
  - **[ĐỊNH HƯỚNG MỚI — CHƯA CODE] Chuyển sang Drift (ORM/query builder cho
    SQLite trên Flutter)** thay cho gọi `sqlite3` trực tiếp như hiện tại —
    xem D3 ở mục "Quyết định đã chốt". Áp dụng ngay từ bước thiết kế schema
    mới (N-N bộ từ điển + Section/Chapter), không chờ đổi sau. Lý do: schema
    dự kiến đổi nhiều lần trong thời gian ngắn (bộ từ điển N-N, Section/
    Chapter, có thể thêm truy vấn ôn tập phức tạp hơn sau này) — Drift cho
    type-safe query + migration được kiểm tra lúc compile, tránh lỗi runtime
    khi cột/bảng đổi. Đánh đổi: thêm `build_runner` vào pipeline build, và
    phải viết lại `VocabDatabase`/`UserDatabase`/`VocabRepository` hiện tại
    (raw `sqlite3`) sang Drift schema — chấp nhận chi phí này một lần thay vì
    migrate 2 lần (raw → raw mới → Drift).
- **Thông báo:** `NotificationService` (singleton) dùng
  `flutter_local_notifications` — nhắc trong-app khi có từ đến hạn ôn (mọi nền
  tảng), cộng thêm lịch nhắc hàng ngày cho Android/iOS (Windows không hỗ trợ
  nhắc nền khi app đã đóng — giới hạn đã chốt, ngoài phạm vi MVP).
- **Cài đặt:** `ThemeModeNotifier` lưu lựa chọn Sáng/Tối/Theo hệ thống bằng
  `shared_preferences`, áp dụng ngay lập tức qua `MaterialApp.themeMode`.

## Mô hình dữ liệu — định hướng mới [ĐỊNH HƯỚNG MỚI — CHƯA CODE]

> Thay đổi mô hình so với code thật hiện tại (mô tả ở `02_Search.md`,
> `03_Lessons-by-chapter.md`). Ghi ở đây làm nền tảng chung; từng màn hình sẽ
> cập nhật chi tiết hành vi ở bước kế tiếp.

### Trạng thái tra cứu: Offline / Online

Màn Tra cứu (SCR-02) có 2 trạng thái vận hành, tự chuyển theo kết nối mạng
(chưa chốt cơ chế phát hiện online/offline — xem Câu hỏi mở):

| Trạng thái | Nguồn dữ liệu | Ghi chú |
|---|---|---|
| Offline | Chỉ `vocab.db` local | Hành vi giữ nguyên như hiện tại (xem `02_Search.md`) |
| Online | `vocab.db` local **+** API từ điển ngoài | Dùng khi từ không có sẵn trong `vocab.db`, hoặc để bổ sung nghĩa/ví dụ phong phú hơn. Nhà cung cấp API cụ thể **chưa chốt** (Câu hỏi mở) |

Từ tra được qua API ngoài khi online là **từ mới** — cần quyết định có lưu lại
vào `vocab.db`/`user.db` để dùng lại khi offline không, và nếu lưu thì thuộc
bộ từ điển nào (xem mục dưới). Đây là điểm ảnh hưởng trực tiếp tới ràng buộc
"Offline hoàn toàn" trước đây (xem mục Ràng buộc).

### Bộ từ điển (dictionary) — quan hệ nhiều-nhiều với từ

- Khái niệm **"chương"** hiện tại (bảng `chapters` trong `vocab.db`, 6 chương
  cố định — xem `03_Lessons-by-chapter.md`) sẽ được **diễn giải lại thành 1
  bộ từ điển mặc định** (default dictionary), không còn là thuộc tính đơn
  (1-N) gắn trực tiếp trên từ.
- Một **từ (word)** có thể thuộc **nhiều bộ từ điển** cùng lúc → quan hệ
  N-N, cần bảng trung gian kiểu `word_dictionaries (word_id, dictionary_id)`
  thay cho cột `chapter_id` đơn hiện tại trên bảng từ.
- 2 loại bộ từ điển:
  - **Từ điển mặc định** — đóng gói sẵn theo giáo trình (tương đương 6
    "chương" hiện tại), read-only, giống `vocab.db` ngày nay.
  - **Từ điển cá nhân** — do user tự tạo, tự thêm/bỏ từ (giống playlist);
    user có thể tạo **nhiều** bộ cá nhân cùng lúc, 1 từ có thể nằm trong
    nhiều bộ cá nhân khác nhau. Đây là read-write, thuộc `user.db` (tương tự
    hướng mockup cũ ở Q-CSB-02, `docs/spec_history.md`).

### Section / Chapter — nội dung học dạng bài báo

- **Section** là cấp mới, đứng **trên** Chapter: 1 Section chứa nhiều
  Chapter (`Section 1–N Chapter`).
- **Chapter** được định nghĩa lại: **không còn là một nhóm/bộ từ vựng** (vai
  trò đó nay thuộc về "bộ từ điển mặc định" ở mục trên). Chapter là **1 bài
  học**, hiển thị dạng **bài báo/bài đọc** (nội dung văn bản chuyên ngành),
  từ vựng xuất hiện lồng trong nội dung bài thay vì liệt kê trần thành danh
  sách như màn Học hiện tại (`03_Lessons-by-chapter.md`).
- Nguồn nội dung bài học hiện là file Word (`.docx`) — cần quy trình
  chuyển hoá sang dữ liệu có cấu trúc (Section → Chapter → nội dung bài +
  từ vựng liên kết); cách trích xuất **chưa chốt** (Câu hỏi mở).
- Quan hệ Chapter ↔ từ vựng: 1 Chapter (bài học) nhiều khả năng vẫn liên kết
  tới các từ xuất hiện trong bài (để tra nhanh/đánh dấu đã học ngay trong bài
  đọc), nhưng đây không phải quan hệ "bộ từ điển" — cần làm rõ có tách bảng
  liên kết riêng (`chapter_words`) hay suy ra từ nội dung bài lúc hiển thị.

## Ràng buộc

- **Offline-first, online tùy chọn** *(cập nhật — trước đây "Offline hoàn
  toàn")* — toàn bộ tính năng cốt lõi (tra cứu trong `vocab.db`, học theo
  chương/section, ôn tập SM-2) vẫn phải chạy được không cần Internet. Khi có
  mạng, màn Tra cứu bổ sung thêm kết quả từ API từ điển ngoài (xem mục Mô
  hình dữ liệu). Không đăng nhập, không đồng bộ đa thiết bị — giữ nguyên.
- **1 người dùng / 1 thiết bị** — không có khái niệm vai trò hay phân quyền.
- **Ưu tiên nền tảng:** Windows → Android → iOS (thứ tự phát triển/kiểm thử).
- **Windows không hỗ trợ nhắc nền khi app đóng hẳn** — chỉ nhắc trong lúc app
  đang mở (in-app + system notification tức thời). Đã chốt (plan Q&A D2, xem
  comment trong `notification_service.dart`).

## Glossary

| Thuật ngữ | Nghĩa |
|---|---|
| SM-2 | Thuật toán lặp lại ngắt quãng (spaced repetition) gốc của SuperMemo, dùng để tính lịch ôn tập tiếp theo dựa trên độ khó tự đánh giá |
| `q` (quality) | Giá trị 1–5 truyền vào công thức SM-2; app dùng 4 mức: Quên=1, Khó=3, Tốt=4, Dễ=5 |
| Subentry | Một mục từ vựng là cụm từ/biến thể liên quan đến 1 từ gốc (vd: `anchor buoy` là subentry của `buoy`), đánh dấu bằng cột `is_subentry` |
| Due (đến hạn) | Từ đã đánh dấu học và có `due_date <= hôm nay` — xuất hiện trong hàng đợi ôn tập |
| `HomeShell` | Widget khung chính chứa 5 tab, tự chọn `NavigationRail` hay `NavigationBar` tuỳ độ rộng cửa sổ |
| Bộ từ điển (dictionary) | *[Định hướng mới]* Một tập hợp từ vựng; 1 từ có thể thuộc nhiều bộ. 2 loại: mặc định (đóng gói sẵn, thay cho khái niệm "chương" cũ) và cá nhân (user tự tạo, nhiều bộ) |
| Section | *[Định hướng mới]* Cấp phân loại mới, đứng trên Chapter — 1 Section chứa nhiều Chapter |
| Chapter (định nghĩa mới) | *[Định hướng mới]* 1 bài học hiển thị dạng bài báo/bài đọc chuyên ngành, không còn là nhóm từ vựng trần như "chương" hiện tại |

## Quyết định đã chốt (trích từ code/comment, `plan/` gốc đã xoá)

| # | Quyết định | Nguồn |
|---|---|---|
| D1 | Thuật toán ôn tập = SM-2 (không dùng khoảng cố định 1-3-7-14-30 ngày) | `lib/domain/srs/srs_scheduler.dart` |
| D2 | Windows: nhắc chỉ khi app đang mở; Android/iOS: nhắc được cả khi app đóng | `lib/data/services/notification_service.dart` |
| D3 | *[Định hướng mới]* Chuyển từ `sqlite3` raw sang **Drift** ngay từ bước thiết kế schema mới (N-N bộ từ điển + Section/Chapter) — lý do và đánh đổi xem mục Dữ liệu ở trên | Quyết định trong hội thoại phân tích 2026-07-18, xem `docs/spec_history.md` [IMPL-007] |
| — | Bảng màu app lấy từ logo Cảnh sát biển VN (navy + vàng phù hiệu + đỏ) | `lib/core/theme/app_theme.dart`, `docs/artifact-design/bang-mau-ung-dung.md` |

## Câu hỏi mở

Xem `docs/spec_history.md` mục "Điểm chờ xác nhận còn mở"
(Q-CSB-01, Q-CSB-02, và Q-CSB-04..07 mới thêm ở [IMPL-005] cho định hướng
online/bộ từ điển/Section-Chapter).
