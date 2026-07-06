import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'theme_mode_provider.dart';

/// FR-7 — Cài đặt. Giai đoạn 0 mới có chọn Sáng/Tối; sẽ bổ sung giọng đọc,
/// số từ mới/ngày, quản lý dữ liệu ở Giai đoạn 3.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final notifier = ref.read(themeModeProvider.notifier);

    return ListView(
      children: [
        const ListTile(
          title: Text('Giao diện'),
          dense: true,
        ),
        RadioGroup<ThemeMode>(
          groupValue: mode,
          onChanged: (v) => notifier.set(v!),
          child: const Column(
            children: [
              RadioListTile<ThemeMode>(
                title: Text('Theo hệ thống'),
                value: ThemeMode.system,
              ),
              RadioListTile<ThemeMode>(
                title: Text('Sáng'),
                value: ThemeMode.light,
              ),
              RadioListTile<ThemeMode>(
                title: Text('Tối'),
                value: ThemeMode.dark,
              ),
            ],
          ),
        ),
        const Divider(),
        const ListTile(
          leading: Icon(Icons.info_outline),
          title: Text('Các cấu hình khác'),
          subtitle: Text('Giọng đọc, số từ mới/ngày, quản lý dữ liệu — '
              'sẽ bổ sung ở Giai đoạn 3.'),
        ),
      ],
    );
  }
}
