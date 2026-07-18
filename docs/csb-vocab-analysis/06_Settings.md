# SCR-06 — Cài đặt

**FR:** FR-7 · **Trạng thái:** ✅ Đã code xong phần rút gọn · **Nguồn:** `lib/features/settings/settings_screen.dart`, `lib/features/settings/theme_mode_provider.dart`

## Mục đích (theo comment trong code)

*"Giai đoạn 0 mới có chọn Sáng/Tối; sẽ bổ sung giọng đọc, số từ mới/ngày,
quản lý dữ liệu ở Giai đoạn 3."*

## Hành vi hiện tại

- 1 nhóm `RadioGroup<ThemeMode>` với 3 lựa chọn: "Theo hệ thống" / "Sáng" /
  "Tối" — chọn xong gọi `ThemeModeNotifier.set(mode)` ngay, không cần nút
  Lưu riêng.
- 1 `ListTile` thông báo tĩnh (không tương tác) liệt kê các mục **chưa có**:
  giọng đọc, số từ mới/ngày, quản lý dữ liệu.

## Lưu trữ

`ThemeModeNotifier` (Riverpod `Notifier<ThemeMode>`) đọc/ghi qua
`shared_preferences`, key `theme_mode`, giá trị lưu dạng string
(`'light'`/`'dark'`/khác → mặc định `ThemeMode.system`). Áp dụng ngay khi thay
đổi vì `MaterialApp` (trong `app.dart`) watch trực tiếp `themeModeProvider`.

## Phụ thuộc

- `themeModeProvider` được đọc ở `app.dart` (cấu hình `MaterialApp.themeMode`) — thay đổi ở đây phản ánh toàn app ngay lập tức, không cần khởi động lại.

## Giả định / hạn chế

- Đây là mã FR-7 — không có FR-6 nào được dùng trong code (xem
  `docs/spec_history.md` Q-CSB-01), số hiệu FR không liên tục.
- Các mục "sẽ bổ sung" (giọng đọc TTS, số từ mới/ngày, quản lý dữ liệu —
  có thể gồm xoá/backup `user.db`) chưa có UI, chưa có provider, chưa có
  quyết định thiết kế nào được chốt.
