# CSB Vocab App — Spec Change History (spec_history)

Lịch sử thay đổi đặc tả. Mỗi entry: bối cảnh → nội dung thay đổi → tài liệu bị ảnh hưởng → điểm chờ xác nhận.

---

## [IMPL-004] 2026-07-18 — Tách tài liệu nguồn (docx/pdf) ra khỏi assets/

**Người yêu cầu:** User · **Người thực hiện:** Claude

### Nội dung

`assets/` trước đây lẫn giữa tài nguyên runtime thật (những gì
`pubspec.yaml` đóng gói vào app: `db/vocab.db`, cộng `images/words/` dự
phòng) và tài liệu nguồn chỉ dùng lúc biên soạn dữ liệu
(`TA_chuyen_nganh.docx`, `TA_chuyen_nganh_2.pdf`, `Tu_dien.pdf`) — không file
nào trong 3 file này được `pubspec.yaml` khai báo hay code Dart đọc.

Chuyển 3 file đó (bằng `git mv`, giữ lịch sử) sang
`docs/source-materials/`, kèm `README.md` giải thích. **Giữ nguyên
`assets/csb-logo.png` trong `assets/`** theo yêu cầu — dù cũng chưa được
`pubspec.yaml` khai báo, logo có thể dùng làm app icon/splash chính thức
trong tương lai nên hợp lý để gần code hơn là tài liệu tham khảo thuần tuý.

### Tài liệu đã cập nhật / tạo mới

| File | Thay đổi |
|---|---|
| `assets/README.md` | Viết lại — chỉ liệt kê tài nguyên runtime thật, ghi rõ file nào chưa khai báo trong `pubspec.yaml` |
| `docs/source-materials/README.md` | Tạo mới — giải thích 3 file tài liệu nguồn vừa chuyển tới |

---

## [IMPL-003] 2026-07-18 — Xoá tài liệu thiết kế DB, đổi tên file phân tích sang tiếng Anh

**Người yêu cầu:** User · **Người thực hiện:** Claude

### Nội dung

1. **Xoá `docs/03-thiet-ke-co-so-du-lieu.md`** (tạo ở [IMPL-002] mục 7) theo
   yêu cầu trực tiếp — nội dung schema `vocab.db`/`user.db` + cơ chế SM-2
   **không được chuyển đi đâu khác**, chỉ còn suy ra được từ code thật
   (`lib/data/local/`, `lib/domain/srs/srs_scheduler.dart`).
2. **Đổi tên toàn bộ file trong `docs/csb-vocab-analysis/` sang tiếng Anh**
   (giữ nguyên nội dung tiếng Việt bên trong, chỉ đổi tên file) — xem bảng
   đối chiếu trong `docs/csb-vocab-analysis/README.md`.
3. Cập nhật mọi liên kết ở `README.md`, `docs/README.md`, `assets/README.md`
   trỏ tới file đã xoá — trỏ sang `docs/csb-vocab-analysis/` hoặc thẳng vào
   file code nguồn thay thế.

### Điểm chờ xác nhận còn mở

| # | Câu hỏi |
|---|---|
| Q-CSB-03 | Tài liệu thiết kế DB cho báo cáo bàn giao (mục 3 trong `docs/README.md`) hiện chưa có bản nháp nào — cần viết lại khi nào, và có cần giữ định dạng cũ (bảng schema, sơ đồ quan hệ, công thức SM-2) hay chỉ cần bản tóm tắt ngắn? |

---

## [IMPL-002] 2026-07-18 — Tái cấu trúc thư mục dự án + bổ sung tài liệu phân tích

**Người yêu cầu:** User · **Người thực hiện:** Claude

### Nội dung

Dọn dẹp cấu trúc repo sau khi phần khung ứng dụng (Giai đoạn 0–1) đã ổn định:

1. **Đưa project Flutter ra khỏi lớp `src/` trung gian** — `csb-vocab-app/` giờ
   là project Flutter chạy trực tiếp (`flutter run`/`flutter build` từ root),
   không cần `cd src/` trước.
2. **Xoá `plan/`** (7 file đặc tả ban đầu — yêu cầu chức năng, kiến trúc, thiết
   kế dữ liệu, roadmap, Q&A chốt) vì nội dung đã lỗi thời so với code thật và
   được thay thế bởi tài liệu trong `docs/` (thiết kế DB, mockup UI) cùng
   thư mục phân tích mới `docs/csb-vocab-analysis/`.
3. **Xoá `tools/pdf_to_sqlite/`** (script Python parse PDF → `vocab.db`) — đã
   chạy xong, `vocab.db` sinh ra đã đóng gói sẵn trong `assets/db/`, không cần
   giữ script trong repo ứng dụng.
4. **Xoá `test/`** (unit test SM-2 scheduler + widget smoke test) theo yêu cầu
   trực tiếp của user.
5. **Thêm `.claude/skills/`** — copy các skill Flutter/quản lý task dùng
   chung từ một project khác (`Sato/agent`): `app-flutter-skill`,
   `business-logic-flow`, `context-engineering`, `project-context`,
   `task-analysis`, `task-brainstorm`, `task-implement`,
   `task-implement-app`, `task-manager-project`, `task-plan`.
6. **Thêm mockup UI tĩnh** cho cả mobile (`docs/artifact-design/`) và Windows
   desktop (`docs/artifact-design-windows/`) — 13 màn/bản, dùng bảng màu lấy
   trực tiếp từ `assets/csb-logo.png` (xem
   `docs/artifact-design/bang-mau-ung-dung.md`). **Lưu ý:** mockup này đã đi
   trước code thật một bước — có tính năng mới chưa code (bộ từ điển cá nhân,
   ôn tập trộn 3 dạng câu) và đổi cấu trúc điều hướng (gộp "Ôn tập" vào "Từ
   điển của tôi", bỏ chế độ flashcard học-từ-mới ở màn Học). Xem
   `docs/csb-vocab-analysis/README.md` mục trạng thái để phân biệt phần đã
   code với phần mới ở mockup.
7. **Thêm `docs/03-thiet-ke-co-so-du-lieu.md`** — tài liệu thiết kế DB viết
   lại theo đúng schema thực tế của `vocab.db`/`user.db` (khác với bản kế
   hoạch ban đầu trong `plan/04-thiet-ke-du-lieu.md`, vốn có vài chỗ lệch so
   với lúc triển khai thật).
8. **Thêm `docs/csb-vocab-analysis/`** (entry này) — phân tích từng màn hình
   *đã code thật* trong `lib/features/`, theo format rút gọn từ
   `Sato/agent/docs/cloud-print-analysis/` (bỏ phần vai trò nhiều tầng/Web
   admin vì csb-vocab-app là app 1 người dùng, offline, không backend).

### Tài liệu tạo mới

| File | Nội dung |
|---|---|
| `docs/03-thiet-ke-co-so-du-lieu.md` | Schema `vocab.db`/`user.db` thực tế + cơ chế SM-2. **Đã xoá ở [IMPL-003].** |
| `docs/artifact-design/` | Mockup UI mobile, 13 màn, + ảnh chụp + PDF gộp |
| `docs/artifact-design-windows/` | Mockup UI Windows desktop, 13 màn tương ứng |
| `docs/csb-vocab-analysis/README.md` | Tổng quan + bảng danh sách màn hình đã code |
| `docs/csb-vocab-analysis/00_Tong-quan.md` | Bối cảnh, kiến trúc, ràng buộc, glossary. **Đổi tên thành `00_Overview.md` ở [IMPL-003].** |
| `docs/csb-vocab-analysis/01..07_*.md` | Phân tích từng màn hình thật. **Đổi tên sang tiếng Anh ở [IMPL-003]** (xem `docs/csb-vocab-analysis/README.md`) |
| `docs/csb-vocab-analysis/90_Bang-truy-vet.md` | Truy vết FR ↔ màn hình ↔ file code. **Đổi tên thành `90_Traceability-matrix.md` ở [IMPL-003].** |

### Điểm chờ xác nhận còn mở

| # | Câu hỏi |
|---|---|
| Q-CSB-01 | FR-6 không xuất hiện trong bất kỳ comment code nào (FR-1, 2, 3, 4, 5, 7 đều có) — số hiệu này có từng được gán cho một yêu cầu đã bỏ/gộp trong `plan/` cũ không, hay chỉ là khoảng trống trong đánh số gốc? Không thể xác minh vì `plan/` đã bị xoá ở mục 2. |
| Q-CSB-02 | Mockup (`docs/artifact-design/`) đã thiết kế "Từ điển của tôi" (bộ từ vựng cá nhân, 3 kiểu ôn trộn lẫn) và bỏ segmented control Học theo chương/Từ mới — có chốt triển khai code theo đúng hướng mockup này không, hay mockup chỉ mang tính tham khảo? |

---

## [SPEC-BASE] (không rõ ngày — trước phiên làm việc này) — Spec gốc

Đặc tả ban đầu từng nằm ở `plan/00-tong-quan.md` → `plan/06-cau-hoi-can-chot.md`
(đã xoá ở [IMPL-002] mục 2). Tóm tắt còn giữ lại được qua comment trong code:
ứng dụng học từ vựng chuyên ngành Cảnh sát biển Việt Nam, offline-first,
Windows → Android → iOS, SQLite (`vocab.db` read-only + `user.db` read-write),
ôn tập theo thuật toán SM-2 (Phương án A đã chốt tại Q&A 06, xem
`docs/03-thiet-ke-co-so-du-lieu.md` mục 3).
