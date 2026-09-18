# 00 — Tổng Quan

> ⚠️ **Rà soát lại 2026-09-17** (xem `docs/spec_history.md` [IMPL-028]):
> phần lớn nội dung từng ghi "[ĐỊNH HƯỚNG MỚI — CHƯA CODE]" bên dưới
> (bộ từ điển N-N, Section/Chapter dạng bài học) **thực ra đã code xong
> từ trước**, chỉ chưa được cập nhật nhãn trong tài liệu này. Đã relabel
> lại cho khớp thực tế — chi tiết xem từng mục. Vẫn còn thật sự **chưa
> code**: gộp `vocab.db`/`user.db` thành 1 file, chuyển sang Drift, và
> LibreTranslate (đã đổi sang MyMemory Translation API thực tế, không
> phải LibreTranslate như tài liệu này từng ghi — xem `02_Search.md`).

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
  - `/home` → `HomeShell`, chứa **4 tab chính** (Tra cứu/Học/Dịch/**Từ
    điển của tôi** — không phải 5, không có tab "Ôn tập"/"Cài đặt" riêng,
    xem `07_Home-shell.md`) qua `IndexedStack` (không phải route riêng —
    chuyển tab không rebuild lại từ đầu).
- **Layout thích ứng (adaptive):** `HomeShell` đo `MediaQuery.sizeOf(context).width`
  so với `AppConstants.desktopBreakpoint` (700px):
  - **Desktop (Windows, cửa sổ rộng):** sidebar tự dựng cố định bên trái
    (không phải `NavigationRail` mặc định của Flutter, xem `07_Home-shell.md`).
  - **Mobile (Android/iOS, hẹp):** thanh nav tự dựng ở đáy (không phải
    `NavigationBar` mặc định).
- **Dữ liệu — [ĐÃ CODE]:** 2 file SQLite vẫn tách biệt vật lý (chưa gộp
  thành 1 file — xem đoạn dưới), nhưng bảng `dictionaries`/`word_dictionaries`
  (bộ từ điển N-N, xem mục "Mô hình dữ liệu" bên dưới) **đã có trong
  `vocab.db` từ trước, đang dùng thật**, không còn là định hướng tương
  lai (tài liệu thiết kế DB riêng đã bị xoá — xem `../spec_history.md`
  [IMPL-003] — schema hiện suy ra từ code):
  - `vocab.db` — từ vựng, chương/section, ví dụ, **và bảng
    `dictionaries`/`word_dictionaries`**. Mở **read-write** (không phải
    read-only như bản trước ghi) — phần lớn bảng chỉ đọc, nhưng
    `dictionaries`/`word_dictionaries` cần ghi được để user tự tạo "bộ từ
    điển cá nhân" (xem `lib/data/local/vocab_database.dart`, comment
    ngay trong code giải thích rõ lý do). Cài đặt tại
    `../../lib/data/local/vocab_database.dart`.
  - `user.db` — tiến độ học, trạng thái SM-2. Read-write, tạo rỗng lần
    đầu chạy app. Cài đặt tại `../../lib/data/local/user_database.dart`.
  - **Chưa gộp thành 1 file** như định hướng từng ghi ở [IMPL-005]/[IMPL-014]
    — `MyDictionariesRepository` vẫn phải tự JOIN 2 `Database` object
    trong Dart vì "2 file SQLite riêng, không JOIN được bằng SQL" (comment
    trong `lib/data/repositories/my_dictionaries_repository.dart`). Phân
    biệt "mặc định vs cá nhân" đã chuyển sang tầng bộ từ điển
    (`dictionaries.is_default`) như định hướng, nhưng vẫn trên nền 2 file
    vật lý riêng, không phải 1 DB duy nhất.
  - **[ĐỊNH HƯỚNG MỚI — CHƯA CODE] Chuyển sang Drift** (ORM/query builder
    cho SQLite trên Flutter) thay cho gọi `sqlite3` trực tiếp — vẫn chưa
    làm, `pubspec.yaml` không có dependency `drift`. Xem D3 ở mục "Quyết
    định đã chốt".
- **Thông báo:** `NotificationService` (singleton) dùng
  `flutter_local_notifications` — nhắc trong-app khi có từ đến hạn ôn (mọi nền
  tảng), cộng thêm lịch nhắc theo giờ + thứ trong tuần tuỳ chỉnh cho
  Android/iOS (Windows không hỗ trợ nhắc nền khi app đã đóng — giới hạn
  đã chốt, ngoài phạm vi MVP), có gật quyền thông báo hệ thống trước khi
  cho đặt lịch (xem `06_Settings.md`).
- **Cài đặt:** ⚠️ Màn "Cài đặt" (từng chọn Sáng/Tối qua `ThemeModeNotifier`)
  **đã bị xoá khỏi code** — `app.dart` giờ dùng 1 theme cố định
  (`theme: AppTheme.theme`, không có `themeMode`). Xem `06_Settings.md`
  Q-CSB-11.

## Mô hình dữ liệu

> Định hướng đặt ra ở [IMPL-005] — bộ từ điển N-N và Section/Chapter dạng
> bài học **đã được code từ trước**, relabel lại từ "[ĐỊNH HƯỚNG MỚI —
> CHƯA CODE]" theo audit 2026-09-17 ([IMPL-028]). Trạng thái Offline/Online
> ở Tra cứu cũng đã code — chỉ có tên dịch vụ dịch thay đổi so với dự
> kiến ban đầu (LibreTranslate → MyMemory, xem bên dưới).

### Trạng thái tra cứu: Offline / Online [ĐÃ CODE]

Màn Tra cứu (SCR-02) có 2 trạng thái vận hành, tự chuyển theo kết nối mạng
(`connectivity_plus`):

| Trạng thái | Nguồn dữ liệu | Ghi chú |
|---|---|---|
| Offline | Chỉ `vocab.db` local | Xem `02_Search.md` |
| Online | `vocab.db` local **+** API từ điển ngoài | Dùng khi không có khớp chính xác trong `vocab.db`. **Free Dictionary API** (`dictionaryapi.dev`, miễn phí, không cần key) cho phiên âm/loại từ tiếng Anh; dịch nghĩa dùng **MyMemory Translation API** (`api.mymemory.translated.net`, miễn phí, không cần key) — **không phải LibreTranslate** như định hướng ban đầu ở Q-CSB-04, đã đổi vì LibreTranslate public instance bắt buộc API key (xem `docs/spec_history.md` [IMPL-013]) |

**Xử lý lỗi mạng chập chờn**: có kết nối mạng nhưng API không phản hồi/
timeout được coi khác với offline hẳn — fallback êm về kết quả `vocab.db`
local, không chặn UI.

Từ tra được qua API ngoài khi online là **từ mới** — không tự động lưu
lại vào local chỉ vì đã tra; chỉ lưu khi user chủ động bấm "Thêm vào bộ"
— lúc đó mới ghi vào `vocab.db` (bảng `words`, `source = ONLINE`), gắn
vào bộ từ điển cá nhân do user chọn/tạo.

### Bộ từ điển (dictionary) — quan hệ nhiều-nhiều với từ [ĐÃ CODE]

- "Chương" (bảng `chapters`, 6 chương gốc — nay đã thêm "Military
  Dictionary" gộp từ `Tu_dien.pdf`, xem [IMPL-021]) đã được diễn giải lại
  thành **bộ từ điển mặc định**.
- Một **từ (word)** có thể thuộc nhiều bộ từ điển cùng lúc — quan hệ N-N
  qua bảng `word_dictionaries (word_id, dictionary_id)`, thay cho cột
  `chapter_id` đơn trước đây. Cài đặt đầy đủ ở
  `lib/data/repositories/vocab_repository.dart` (`dictionariesWithWordIds()`,
  `createDictionary()`, `deleteDictionary()`, `linkWordToDictionary()`...).
- 2 loại bộ từ điển, cả 2 đã có UI (`lib/features/my_dictionaries/`):
  - **Từ điển mặc định** — đóng gói sẵn theo giáo trình (`dictionaries.is_default`),
    có 1 bộ đặc biệt "Chưa phân loại" (`id = 1`) chứa từ không gán bộ nào.
  - **Từ điển cá nhân** — user tự tạo (`createDictionary`), tự thêm/bỏ từ,
    có thể tạo nhiều bộ cùng lúc.
- Bảng `words` đã có cột `source` phân biệt nguồn gốc: SEED(0, giáo
  trình gốc)/ONLINE(1, tra online rồi lưu)/MANUAL(2, tự nhập tay) — dùng
  chung 1 bảng cho mọi nguồn như định hướng ban đầu.

### Section / Chapter — nội dung học dạng bài báo [ĐÃ CODE]

- **Section** là cấp đứng **trên** Chapter: 1 Section chứa nhiều Chapter
  (bảng `sections`, `chapters.section_id`) — `VocabRepository.sections()`/
  `chapters(sectionId)`.
- **Chapter** đã được định nghĩa lại thành **1 bài học**, có cột
  `pdf_path` (nội dung bài là file PDF, không phải `.docx` chuyển hoá có
  cấu trúc như định hướng ban đầu). UI đọc bài (`ChapterContentScreen`,
  `lib/features/lessons/lessons_screen.dart`) đã hoạt động — hiện accordion
  Section → Chapter, chọn 1 Chapter mở màn đọc PDF (`_ChapterPdfBody`,
  dùng `pdfx`).
- Từ vựng **không** lồng trong nội dung bài kiểu gạch chân/bấm mở
  `WordDetailSheet` như định hướng ban đầu dự tính — bài đọc hiện chỉ là
  PDF hiển thị nguyên trang, chưa có liên kết từ ↔ vị trí trong bài.

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
| SM-2 | Thuật toán lặp lại ngắt quãng (spaced repetition) gốc của SuperMemo, dùng để tính lịch ôn tập tiếp theo |
| `q` (quality) | Giá trị 1–5 truyền vào công thức SM-2; hệ thống tự suy ra từ đúng/sai (không còn cho user tự chọn mức — xem `05_Review.md`): sai→1, đúng lần đầu/chưa ổn định→4, đúng đã ổn định (≥3 lần liên tiếp)→5. Mức 3 (`hard`) là dead code, không còn đường nào gán tới |
| Subentry | Một mục từ vựng là cụm từ/biến thể liên quan đến 1 từ gốc (vd: `anchor buoy` là subentry của `buoy`), đánh dấu bằng cột `is_subentry` |
| Due (đến hạn) | Từ đã đánh dấu học và có `due_date <= hôm nay` — xuất hiện trong hàng đợi ôn tập |
| `HomeShell` | Widget khung chính chứa 4 tab (Tra cứu/Học/Dịch/Từ điển của tôi — không có tab Ôn tập/Cài đặt riêng), tự chọn layout sidebar/bottom-nav tuỳ độ rộng cửa sổ (widget tự dựng, không phải `NavigationRail`/`NavigationBar` mặc định) |
| Bộ từ điển (dictionary) | ✅ Đã code. Một tập hợp từ vựng; 1 từ có thể thuộc nhiều bộ. 2 loại: mặc định (đóng gói sẵn, thay cho khái niệm "chương" cũ) và cá nhân (user tự tạo, nhiều bộ) |
| Section | ✅ Đã code. Cấp phân loại đứng trên Chapter — 1 Section chứa nhiều Chapter |
| Chapter (định nghĩa mới) | ✅ Đã code. 1 bài học hiển thị nội dung PDF, không còn là nhóm từ vựng trần như "chương" cũ |

## Quyết định đã chốt (trích từ code/comment, `plan/` gốc đã xoá)

| # | Quyết định | Nguồn |
|---|---|---|
| D1 | Thuật toán ôn tập = SM-2 (không dùng khoảng cố định 1-3-7-14-30 ngày) | `lib/domain/srs/srs_scheduler.dart` |
| D2 | Windows: nhắc chỉ khi app đang mở; Android/iOS: nhắc được cả khi app đóng | `lib/data/services/notification_service.dart` |
| D3 | *[Chưa làm]* Chuyển từ `sqlite3` raw sang **Drift** — vẫn chưa thực hiện, không có dependency `drift` trong `pubspec.yaml` | Quyết định trong hội thoại phân tích 2026-07-18, xem `docs/spec_history.md` [IMPL-007] |
| D4 | API tra cứu Online = Free Dictionary API (định nghĩa/phiên âm tiếng Anh) + **MyMemory Translation API** (dịch sang tiếng Việt — đổi từ LibreTranslate dự kiến ban đầu vì LibreTranslate bắt buộc API key); phát hiện mạng bằng `connectivity_plus`; lỗi mạng chập chờn → fallback êm về `vocab.db` local; từ tra online **chỉ lưu local khi user bấm "Thêm vào bộ"**, không tự động cache | `docs/spec_history.md` [IMPL-013] |
| — | Bảng màu app lấy từ logo Cảnh sát biển VN (navy + vàng phù hiệu + đỏ) | `lib/core/theme/app_theme.dart`, `docs/artifact-design/bang-mau-ung-dung.md` |

## Câu hỏi mở

**Đã chốt/đã code**: Q-CSB-04 (Free Dictionary API + MyMemory thay
LibreTranslate), Q-CSB-05 (chỉ lưu khi user bấm "Thêm vào bộ"), Q-CSB-06
(`connectivity_plus` + fallback êm khi API lỗi/timeout) — cả 3 đã code
xong, xem `02_Search.md`. Bộ từ điển N-N và Section/Chapter (mục "Mô
hình dữ liệu" ở trên) cũng đã code xong.

**Còn mở** (xem `docs/spec_history.md` mục "Điểm chờ xác nhận còn mở" để
biết đầy đủ, đặc biệt các câu hỏi mới Q-CSB-08 đến Q-CSB-11):
- Q-CSB-01: không ảnh hưởng implement.
- Q-CSB-07: quy trình chuyển `.docx` → dữ liệu Section/Chapter có cấu
  trúc — thực tế Chapter dùng nội dung **PDF** thay vì `.docx` chuyển
  hoá có cấu trúc như dự tính, nên câu hỏi gốc có phần không còn áp
  dụng theo đúng nghĩa ban đầu; cần xác nhận lại có còn ý nghĩa gì
  không.
- Q-CSB-10 (mới): "Từ điển của tôi" đã có code đầy đủ nhưng chưa có tài
  liệu SCR phân tích riêng.
- Q-CSB-11 (mới): màn "Cài đặt" (chọn Sáng/Tối) đã biến mất khỏi code
  mà không có entry nào trong `spec_history.md` ghi lại — cần xác nhận
  đây có phải chủ đích hay không (xem `06_Settings.md`).
