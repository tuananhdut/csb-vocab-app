# Task 01 (nhánh phụ) — Plan: Layout 2 cột Windows cho màn Tra cứu (SCR-02)

## Task-plan

> Input: `01-analysis.md` (gap đã ghi: "Windows chưa dùng layout 2 cột
> pane-list/pane-detail như mockup"), làm rõ phạm vi qua trả lời user:
> chỉ làm cho SCR-02 (Tra cứu) — **không** đụng SCR-03 (Học), vì màn đó
> mockup đã đổi hẳn sang mô hình Section/Chapter mới chưa có dữ liệu thật
> (xem `03_Lessons-by-chapter.md`, Q-CSB-07 dời sang bước riêng).

## Requirement Summary

### Selected Approach

`SearchScreen` hiện dùng 1 code path chung cho cả Windows/Mobile: ô tìm
kiếm + `ListView` kết quả, bấm 1 dòng → mở `WordDetailSheet` dạng bottom
sheet kéo lên (`DraggableScrollableSheet`) — kể cả trên Windows.

Mockup Windows (`docs/artifact-design-windows/screens/screen-02-tra-
cuu.html`) dùng bố cục 2 cột cố định:
- **`pane-list`** (340px, cuộn riêng): danh sách kết quả, dòng đang chọn có
  style `selected` (nền khác).
- **`pane-detail`** (phần còn lại, cuộn riêng): hiển thị chi tiết từ đang
  chọn **inline ngay tại chỗ** — không phải bottom sheet/modal. Có nút
  "Đã học" và "Thêm vào bộ" ngay trong pane này.

Cách tiếp cận: `SearchScreen` phân nhánh layout theo
`MediaQuery.sizeOf(context).width >= AppConstants.desktopBreakpoint` (đúng
pattern đã dùng ở `HomeShell`/carousel rỗng vừa thêm):
- **Desktop:** `Row` 2 phần — trái là `ListView` kết quả (thay
  `WordTile.onTap` mở sheet bằng cập nhật `_selectedWord` state), phải là
  widget chi tiết mới **tái dùng nội dung của `WordDetailSheet`** nhưng
  render inline (không bọc trong `showModalBottomSheet`).
- **Mobile:** giữ nguyên hành vi hiện tại (bottom sheet) — không đổi.

Để tránh trùng lặp code hiển thị chi tiết từ (tiêu đề, phiên âm, nghĩa, ví
dụ, nút hành động), tách phần nội dung bên trong `WordDetailSheet` hiện tại
thành 1 widget con dùng chung (`WordDetailContent`), rồi `WordDetailSheet`
(mobile) và pane chi tiết mới (desktop) đều bọc widget đó theo layout khác
nhau.

### Scope

- Chỉ `SearchScreen` (SCR-02) trên Windows.
- Tách `WordDetailContent` từ `WordDetailSheet` để dùng chung inline/sheet.
- Thêm trạng thái "chưa chọn từ nào" cho `pane-detail` (khớp
  `pane-detail-empty` trong mockup) — hiện khi mới vào màn/chưa bấm dòng
  nào.

### Out of Scope

- SCR-03 (Học) — không đổi, giữ nguyên `Navigator.push` + `ChapterWordsScreen`
  hiện tại kể cả trên Windows (mô hình "chương = nhóm từ" cũ vẫn còn hiệu
  lực, mockup Section/Chapter mới chưa có dữ liệu để code — xem
  `01-analysis.md`).
- Badge Offline/Online (`.net-badge`), trạng thái Online (`screen-02b`) —
  gap khác, không thuộc phạm vi "layout 2 cột" lần này.
- Nút "Thêm vào bộ" (`.add-deck-btn` trong mockup) — phụ thuộc bộ từ điển
  cá nhân chưa có schema thật (`91_DB-design-new-model.md` mới là thiết
  kế, chưa code) — **không thêm nút này**, giữ nguyên chỉ có "Đã học" như
  hiện tại.
- Mobile — không đổi gì, giữ nguyên bottom sheet.
- Title bar tuỳ biến Windows — không liên quan.

## API Contract

Không áp dụng — thuần thay đổi UI/layout nội bộ app, không có API/backend
liên quan (`VocabRepository.search()` không đổi).

| Item | Value |
|---|---|
| API name | N/A |
| Endpoint | N/A |
| Method | N/A |
| Auth required | N/A |
| Permission rule | N/A |
| Request params | N/A |
| Request body | N/A |
| Success response | N/A |
| Validation error response | N/A |
| Business error response | N/A |
| Auth/session error response | N/A |
| Permission error response | N/A |
| Frontend caller | N/A |
| Backend handler | N/A |

## Subtask Breakdown

### Backend Subtasks

Không có — N/A.

### Frontend Subtasks

| Subtask ID | Title | Files/Modules | Description | Depends On | Risk |
|---|---|---|---|---|---|
| FE-04 | Tách `WordDetailContent` khỏi `WordDetailSheet` | `lib/features/vocab/word_widgets.dart` | Trích phần nội dung bên trong `DraggableScrollableSheet` (tiêu đề, phiên âm, nút "Đã học", nghĩa, ví dụ) thành widget `WordDetailContent` riêng (nhận `VocabWord` + `WidgetRef`/dùng `ConsumerWidget`). `WordDetailSheet` (mobile) gọi lại widget này bên trong `DraggableScrollableSheet` như cũ — hành vi mobile không đổi | None | Thấp — refactor thuần tách widget, không đổi logic |
| FE-05 | `SearchScreen`: thêm layout 2 cột cho Windows | `lib/features/search/search_screen.dart` | Thêm state `VocabWord? _selected`. Khi `isDesktop` (dùng `AppConstants.desktopBreakpoint` có sẵn): render `Row` — trái là danh sách kết quả (đổi `WordTile.onTap` từ `showWordDetail(context, word)` sang `setState(() => _selected = word)` khi desktop, highlight dòng đang chọn kiểu `.selected`), phải là `WordDetailContent` (nếu có `_selected`) hoặc empty-state (icon + text, khớp `.pane-detail-empty`) nếu chưa chọn. Mobile giữ nguyên `showWordDetail` mở bottom sheet | FE-04 | Trung bình — cần đảm bảo `WordTile` vẫn dùng được ở cả 2 chế độ (tham số `onTap` tuỳ chỉnh thay vì hard-code `showWordDetail` bên trong `WordTile`) |
| FE-06 | `WordTile`: cho phép tuỳ chỉnh hành vi tap + style "đang chọn" | `lib/features/vocab/word_widgets.dart` | Thêm tham số `onTap` (mặc định vẫn gọi `showWordDetail` để không phá `ChapterWordsScreen` đang dùng `WordTile` cho SCR-03) và tham số `selected` (bool, đổi màu nền dòng giống `.word-row.selected` khi `true`) | None | Thấp — thêm tham số optional, không đổi call site khác nếu không truyền |

### Integration Subtasks

| Subtask ID | Title | Files/Modules | Description | Depends On | Risk |
|---|---|---|---|---|---|
| INT-02 | Verify Windows 2 cột + Mobile không đổi | `lib/features/search/`, `lib/features/vocab/` | Chạy `flutter run -d windows`: gõ tìm kiếm, bấm 1 dòng → chi tiết hiện bên phải (không phải sheet), bấm dòng khác → cập nhật ngay, bấm "Đã học" hoạt động đúng. Resize cửa sổ qua breakpoint 700px → chuyển đúng giữa 2 cột và bottom sheet. Chạy 1 target mobile: xác nhận hành vi y hệt trước khi đổi (mở sheet như cũ) | FE-05, FE-06 | Thấp |

## Recommended Execution Order

### Option B: Frontend First

Order:

1. FE-04 (tách widget dùng chung — nền tảng cho cả 2 nơi gọi)
2. FE-06 (mở rộng `WordTile` trước, vì FE-05 phụ thuộc tham số mới)
3. FE-05 (ráp layout 2 cột trong `SearchScreen`)
4. INT-02

### Recommended Option

Recommend: **Option B, thứ tự FE-04 → FE-06 → FE-05 → INT-02**

Reason:

- Không có backend — toàn bộ là refactor + thêm UI thuần frontend.
- FE-04 tách widget dùng chung trước để FE-05 có thể tái sử dụng ngay,
  tránh viết trùng code hiển thị chi tiết từ.
- FE-06 (mở rộng `WordTile`) cần xong trước FE-05 vì `SearchScreen` sẽ
  truyền `onTap`/`selected` mới vào `WordTile`.

## User Decision Required

```text
Implement frontend first: use task-implement-frontend with FE-04
```

## Manual Verification Plan

### Main Flow

- [ ] Windows: mở tab Tra cứu, gõ từ khoá → danh sách hiện bên trái, chưa
      bấm dòng nào → bên phải hiện empty-state (không phải trắng trơn).
- [ ] Bấm 1 dòng → chi tiết từ hiện ngay bên phải (tiêu đề, phiên âm,
      nghĩa, ví dụ), dòng vừa bấm được highlight khác các dòng còn lại.
- [ ] Bấm dòng khác → nội dung bên phải cập nhật ngay, không có hiệu ứng
      mở/đóng sheet nào (khác hẳn hành vi mobile).
- [ ] Bấm "Đánh dấu đã học" trong pane phải → cập nhật trạng thái đúng như
      hành vi hiện tại (nút chuyển "Đã học", disabled).

### UI Verification

- [ ] Resize cửa sổ Windows từ rộng (>700px) xuống hẹp (<700px) và ngược
      lại — layout chuyển đúng giữa 2 cột và bottom sheet, không lỗi vỡ
      giao diện giữa chừng.
- [ ] Mobile (thiết bị/emulator thật): hành vi y hệt trước khi đổi — bấm
      dòng vẫn mở `WordDetailSheet` dạng bottom sheet kéo lên, không bị
      ảnh hưởng bởi thay đổi ở Windows.
- [ ] `ChapterWordsScreen` (SCR-03, dùng chung `WordTile`) trên cả 2 nền
      tảng vẫn mở `WordDetailSheet` bottom sheet như cũ (không bị đổi hành
      vi ngoài ý muốn vì FE-06 thêm tham số optional).

### API Verification

Không áp dụng.

### Error / Edge Case

- [ ] Xoá hết chữ tìm kiếm khi đang có từ được chọn (desktop) — pane phải
      nên quay về empty-state hay giữ nguyên từ đang chọn? (xem TODO bên
      dưới — cần quyết định trước khi code FE-05)
- [ ] Tìm 1 từ, chọn nó, rồi gõ tìm từ khác không liên quan — `_selected`
      cũ vẫn hiển thị cho tới khi user bấm dòng mới (không tự động xoá
      lựa chọn khi query đổi, trừ khi quyết định khác ở trên).

### SPA / Browser Behavior

Không áp dụng.

### Regression

- [ ] Luồng search cơ bản (gõ → kết quả → xem nghĩa) không đổi hành vi
      dữ liệu, chỉ đổi cách hiển thị trên Windows.
- [ ] `_SearchEmptyCarousel` (vừa thêm ở subtask trước, FE-03) vẫn hiện
      đúng khi `_query` rỗng, không bị đổi bởi thay đổi layout 2 cột này
      (carousel này thay `pane-detail`+`pane-list` hoàn toàn khi rỗng,
      đúng như mockup `screen-02c` — không có 2 cột lúc chưa gõ gì).

## Risks / TODO

- **Cần quyết định trước khi code FE-05:** khi user xoá hết chữ tìm kiếm
  (quay về trạng thái rỗng/carousel) trong lúc đang có 1 từ được chọn ở
  pane phải (desktop) — có nên reset `_selected = null` luôn không? Mockup
  không thể hiện rõ trường hợp này (carousel chiếm toàn bộ `page-content`
  khi rỗng, không còn 2 pane). Đề xuất: reset về `null` khi `_query` rỗng,
  để tránh giữ state cũ không còn ý nghĩa khi carousel hiện lại.
- `WordDetailContent` sau khi tách cần giữ đúng toàn bộ hành vi hiện tại
  của `WordDetailSheet` (đọc `wordExamplesProvider`, `learnedStatusProvider`
  theo đúng `word.id`) — rủi ro thấp nhưng cần test kỹ để không có
  provider nào bị đọc sai khi đổi từ modal sang inline.
- Không thêm nút "Thêm vào bộ" (theo Out of Scope) — nếu sau này chốt
  Q-CSB-02 và implement bộ từ điển cá nhân, sẽ cần quay lại
  `WordDetailContent` để thêm nút này cho cả 2 chế độ cùng lúc (điểm dùng
  chung là lợi ích chính của việc tách widget ở FE-04).
