import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/services/reminder_settings_provider.dart';

/// Nhãn ngắn T2..CN, chỉ số khớp `DateTime.weekday` (1=Thứ Hai..7=Chủ Nhật).
const _weekdayLabels = {
  1: 'T2',
  2: 'T3',
  3: 'T4',
  4: 'T5',
  5: 'T6',
  6: 'T7',
  7: 'CN',
};

/// Modal "Nhắc ôn tập" — đặt giờ + chọn thứ trong tuần để nhận thông báo
/// hệ thống nhắc ôn tập (xem
/// `docs/csb-vocab-analysis/tasks/05-dat-gio-nhac-on-tap/03-plan.md`, FE-02).
///
/// Mobile: [showModalBottomSheet] (kéo lên từ đáy, quen thuộc trên màn
/// hẹp). Windows: [showDialog] căn giữa, width cố định — tránh 1
/// BottomSheet kiểu mobile trôi nổi giữa màn hình desktop rộng, không
/// neo vào cạnh nào của cửa sổ.
Future<void> showDailyReminderSheet(BuildContext context) {
  if (Platform.isWindows) {
    return showDialog<void>(
      context: context,
      builder: (_) => const Dialog(
        child: SizedBox(width: 420, child: DailyReminderSheet()),
      ),
    );
  }
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const DailyReminderSheet(),
  );
}

class DailyReminderSheet extends ConsumerWidget {
  const DailyReminderSheet({super.key});

  Future<void> _pickTime(BuildContext context, WidgetRef ref, ReminderSettings settings) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: settings.hour, minute: settings.minute),
    );
    if (picked == null) return;
    await ref
        .read(reminderSettingsProvider.notifier)
        .update(hour: picked.hour, minute: picked.minute);
    if (!context.mounted) return;
    _showSavedSnackBar(context);
  }

  void _toggleWeekday(WidgetRef ref, ReminderSettings settings, int weekday, bool selected) {
    final next = Set<int>.from(settings.weekdays);
    if (selected) {
      next.add(weekday);
    } else {
      next.remove(weekday);
    }
    ref.read(reminderSettingsProvider.notifier).update(weekdays: next);
  }

  void _showSavedSnackBar(BuildContext context) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Đã lưu cài đặt nhắc ôn tập.')));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(reminderSettingsProvider);
    final time = TimeOfDay(hour: settings.hour, minute: settings.minute);

    // Windows (`Dialog`) không có status bar/notch để né và không có drag
    // handle phía trên như BottomSheet mobile — cần padding-top đầy đủ
    // thay vì 0.
    final topPadding = Platform.isWindows ? 20.0 : 0.0;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, topPadding, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Nhắc ôn tập', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Chọn giờ và các thứ trong tuần muốn được nhắc ôn tập.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.inkSoft),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Bật nhắc ôn tập'),
              value: settings.enabled,
              onChanged: (value) {
                ref.read(reminderSettingsProvider.notifier).update(enabled: value);
                _showSavedSnackBar(context);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Giờ nhắc'),
              subtitle: Text(time.format(context)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _pickTime(context, ref, settings),
            ),
            const SizedBox(height: 8),
            Text('Các thứ trong tuần', style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in _weekdayLabels.entries)
                  FilterChip(
                    label: Text(entry.value),
                    selected: settings.weekdays.contains(entry.key),
                    onSelected: (selected) =>
                        _toggleWeekday(ref, settings, entry.key, selected),
                  ),
              ],
            ),
            if (Platform.isWindows) ...[
              const SizedBox(height: 16),
              Text(
                'Trên Windows, ứng dụng chỉ nhắc được khi đang mở — không hỗ trợ '
                'thông báo nền khi ứng dụng đã đóng.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.inkSoft),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
