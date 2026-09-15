import 'package:flutter/material.dart';

/// Bọc [child] để chạm ra ngoài các ô nhập bên trong tự đóng bàn phím —
/// dùng chung cho mọi màn có form/nhập liệu (màn Dịch, Tự thêm từ mới...).
/// `HitTestBehavior.opaque` để bắt tap cả ở vùng trống không có widget con
/// nào khác xử lý; không chặn tap của TextField/nút bên trong vì Flutter
/// gesture arena ưu tiên recognizer của widget con khi trùng vị trí.
class DismissKeyboardOnTap extends StatelessWidget {
  const DismissKeyboardOnTap({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: child,
    );
  }
}
