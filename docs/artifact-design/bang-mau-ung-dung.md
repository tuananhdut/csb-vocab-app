# Bảng màu ứng dụng — CSB Vocab

## 1. Màu gốc trích từ logo chính thức

Lấy mẫu trực tiếp từ `assets/csb-logo.png` (không áng chừng bằng mắt):

| Vùng trên logo | Mã màu đo được | Vai trò trên logo |
|---|---|---|
| Nền khiên | `#0050A0` | Nền chính, chiếm diện tích lớn nhất |
| Viền ngoài, khiên nhỏ giữa | `#F02028` | Điểm nhấn viền, số lượng ít |
| Sao, chữ, lúa, mỏ neo | `#E8B820` → `#F8E008` | Chi tiết nổi bật, dải từ vàng đậm đến vàng tươi |

Ba màu này đúng theo quy chuẩn phù hiệu lực lượng vũ trang: navy = biển/kỷ luật, vàng = huy hiệu/danh dự, đỏ = cách mạng — dùng đúng 3 màu này để ứng dụng gắn liền cảm giác "chính danh, thuộc về lực lượng" chứ không phải một app học tiếng Anh chung chung.

## 2. Ràng buộc thực dụng riêng của ứng dụng này

Đây là phần quan trọng nhất — **không thể bê nguyên màu logo vào UI** vì bối cảnh sử dụng khác hẳn một phù hiệu in tĩnh:

- **Dùng trên tàu, ngoài nắng gắt:** màn hình điện thoại/tablet ngoài trời bị chói, mất tương phản. Nền trắng thuần (`#FFFFFF`) và chữ xám nhạt gần như vô hình dưới nắng. Chữ và nền cần tỷ lệ tương phản cao (khuyến nghị ≥ 7:1 cho văn bản chính, vượt cả mức AA thông thường 4.5:1) để vẫn đọc được khi độ sáng màn hình bị nắng lấn át.
- **Không có sóng — không tự động chỉnh độ sáng theo cloud, không tải theme nào từ server:** bảng màu phải cố định, nhúng cứng trong app, hoạt động tốt ở cả 2 chế độ sáng/tối vì thiết bị dùng cả ban ngày (ngoài boong) lẫn ban đêm (trong ca trực, ánh sáng đỏ/tối để giữ thị lực đêm).
- **Đỏ của logo dễ đụng độ với đỏ tín hiệu lỗi/cảnh báo:** app đã dùng đỏ để báo "từ quên/đến hạn ôn" (xem `docs/artifact-design/csb-vocab-mockup.html`). Nếu dùng cùng một đỏ cho cả "thương hiệu" lẫn "cảnh báo sai", người dùng sẽ lẫn lộn hai tín hiệu khác bản chất nhau. → Cần **tách riêng đỏ thương hiệu (ít dùng, chỉ ở logo/splash) và đỏ tín hiệu (dùng trong luồng học/ôn tập)**, hơi lệch tông để không merge làm một.
- **Vàng gốc logo (`#F8E008`) quá sáng/chói để làm nền hoặc để làm chữ trên nền sáng** — tỷ lệ tương phản với nền trắng rất thấp. Cần hạ độ sáng (giảm lightness, giữ nguyên hue) thành một "vàng ánh đồng" trầm hơn khi dùng làm chữ/icon, và chỉ dùng vàng tươi nguyên bản cho các chi tiết nhỏ, diện tích thấp (viền, dấu chấm, icon nhỏ).

## 3. Bảng màu đề xuất

### Màu thương hiệu (giữ nguyên tinh thần logo, đã hiệu chỉnh độ sáng cho dùng ngoài trời)

| Token | Hex | Nguồn gốc | Dùng cho |
|---|---|---|---|
| `navy-900` | `#0A2340` | Tối hơn `#0050A0` gốc ~1 bậc | Nền chính, thanh điều hướng, nền thẻ flashcard — nền tối giúp chữ trắng tương phản cao dưới nắng thay vì làm nền sáng bị chói |
| `navy-700` | `#15497A` | Trung gian giữa gốc và 900 | Icon phụ, IPA, đường viền nhấn — đủ sáng để nổi trên `navy-900` nhưng không chói |
| `brass` | `#C99A3E` | Hạ lightness từ `#E8B820` gốc | Accent chính: nút chính, tiêu đề, nhãn — vàng ánh đồng thay vì vàng chói, đọc được trên cả nền sáng và nền tối |
| `brass-bright` | `#F2C230` | Gần nguyên bản `#F8E008` gốc | CHỈ dùng diện tích nhỏ: sao, viền mảnh, dấu hiệu thương hiệu ở màn Splash/Giới thiệu — không dùng làm nền hay chữ |
| `crest-red` | `#B5272E` | Hạ saturation/lightness từ `#F02028` gốc | CHỈ dùng ở logo/splash/tiêu đề "Cảnh sát biển Việt Nam" — không dùng trong luồng học tập hàng ngày |

### Màu tín hiệu (tách riêng khỏi đỏ thương hiệu — xem lý do ở mục 2)

| Token | Hex | Dùng cho |
|---|---|---|
| `signal-green` | `#2F8F72` | Đúng / đã học / dễ — xanh lục ngả xanh biển nhẹ để hợp tông với navy, không phải xanh lá cây thuần |
| `signal-red` | `#B5472B` | Sai / quên / đến hạn ôn — đỏ ngả cam/gạch, cố ý lệch tông so với `crest-red` của logo để hai tín hiệu không bị đọc nhầm là cùng một ý nghĩa |
| `signal-amber` | `#D98C1F` | Cảnh báo nhẹ / gần đến hạn (nếu cần mức trung gian giữa đúng và sai) |

### Nền & chữ (neutrals — có chủ đích, không phải xám mặc định)

| Token | Hex (sáng) | Hex (tối) | Vai trò |
|---|---|---|---|
| `bg` | `#F4F7FA` | `#060F1C` | Nền màn hình — ánh xanh thép rất nhẹ thay vì trắng/đen thuần, đỡ chói hơn trắng thuần dưới nắng nhưng vẫn đủ sáng để đọc |
| `surface` | `#FFFFFF` | `#0D2038` | Nền thẻ, nền input |
| `text` | `#0D1B2A` | `#EAF1F7` | Chữ chính — gần đen/gần trắng, không dùng xám giữa để giữ tương phản cao nhất có thể |
| `text-soft` | `#46586B` | `#93A7BC` | Chữ phụ, chú thích — vẫn đủ tương phản để đọc ngoài nắng, chỉ nhẹ hơn chữ chính |

## 4. Kiểm tra tương phản (ngoài trời là ưu tiên số 1)

| Cặp màu | Tỷ lệ tương phản | Đạt chuẩn |
|---|---|---|
| `text` (#0D1B2A) trên `bg` sáng (#F4F7FA) | ~15.8:1 | Vượt xa AAA (7:1) — an toàn dưới nắng gắt |
| Trắng trên `navy-900` (#0A2340) | ~13.9:1 | Vượt AAA — dùng cho toàn bộ chữ trên nền thẻ tối |
| `brass` (#C99A3E) trên `navy-900` | ~4.6:1 | Đạt AA cho chữ lớn/đậm (tiêu đề, nhãn), không dùng cho chữ nhỏ mật độ cao |
| `signal-red` (#B5472B) trên trắng | ~5.2:1 | Đạt AA — đủ cho nhãn trạng thái |
| `signal-green` (#2F8F72) trên trắng | ~3.6:1 | Đạt AA cho chữ lớn/đậm và icon, không dùng cho chữ thường nhỏ |

> Nguyên tắc áp dụng: mọi văn bản đọc liên tục (nghĩa từ, câu ví dụ, nội dung chính) phải đặt trên `text`/`bg` hoặc trắng/`navy-900` — hai cặp tương phản cao nhất. Màu thương hiệu (`brass`, `signal-*`) chỉ dùng cho nhãn ngắn, icon, viền, không dùng làm màu chữ cho đoạn văn dài.

## 5. Vì sao không dùng thẳng 3 màu logo nguyên bản

| Nếu dùng nguyên `#0050A0` làm nền, `#F8E008` làm chữ, `#F02028` làm nút | Vấn đề |
|---|---|
| Nền `#0050A0` sáng hơn `navy-900` đề xuất | Giảm tương phản với chữ trắng, khó đọc hơn dưới nắng |
| Chữ `#F8E008` (vàng chói) trên nền trắng | Tỷ lệ tương phản quá thấp (~1.6:1) — gần như không đọc được, đây là lỗi phổ biến khi lấy màu logo làm màu chữ trực tiếp |
| Nút hành động màu `#F02028` | Trùng tông với `signal-red` dùng cho "sai/quên" — người dùng sẽ hoang mang không biết nút đó là hành động bình thường hay cảnh báo lỗi |

Kết luận: bảng màu đề xuất ở mục 3 **giữ đúng bản sắc thị giác của logo** (navy + vàng ánh đồng + đỏ, đúng thứ tự vai trò) nhưng đã hiệu chỉnh độ sáng/tương phản và tách bạch vai trò màu để phù hợp với điều kiện dùng thực tế: ngoài nắng, không mạng, cả ngày lẫn đêm.
