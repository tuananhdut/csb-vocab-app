import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/theme/app_theme.dart';
import '../../data/services/reminder_settings_provider.dart';

/// Nhãn ngắn + đầy đủ của từng thứ, chỉ số khớp `DateTime.weekday`
/// (1=Thứ Hai..7=Chủ Nhật).
const _weekdayShort = {1: 'T2', 2: 'T3', 3: 'T4', 4: 'T5', 5: 'T6', 6: 'T7', 7: 'CN'};
const _weekdayFull = {
  1: 'Thứ Hai',
  2: 'Thứ Ba',
  3: 'Thứ Tư',
  4: 'Thứ Năm',
  5: 'Thứ Sáu',
  6: 'Thứ Bảy',
  7: 'Chủ Nhật',
};

/// Màn Cài đặt nhắc ôn tập — full-screen (route `/settings/reminders`), thay
/// cho `DailyReminderSheet` (BottomSheet) trước đó. Cho phép đặt giờ **riêng
/// từng ngày trong tuần** thay vì 1 giờ chung, xem
/// `docs/csb-vocab-analysis/tasks/06-gio-nhac-rieng-theo-ngay/01-analysis.md`.
///
/// Chỉ vào được từ Android/iOS — Windows không hỗ trợ nhắc nền theo lịch nên
/// nút mở màn này bị ẩn trên Windows (xem `home_shell.dart`).
class ReminderSettingsScreen extends ConsumerStatefulWidget {
  const ReminderSettingsScreen({super.key});

  @override
  ConsumerState<ReminderSettingsScreen> createState() =>
      _ReminderSettingsScreenState();
}

class _ReminderSettingsScreenState extends ConsumerState<ReminderSettingsScreen>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // User có thể vừa rời app để cấp quyền thông báo ở Cài đặt hệ thống rồi
    // quay lại — kiểm tra lại quyền ngay khi app resume.
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(notificationPermissionGrantedProvider);
    }
  }

  Future<void> _pickTime(int weekday, DayReminder day) async {
    final picked = await _showWheelTimePicker(
      context,
      initial: TimeOfDay(hour: day.hour, minute: day.minute),
    );
    if (picked == null) return;
    await ref
        .read(reminderSettingsProvider.notifier)
        .updateDay(weekday, hour: picked.hour, minute: picked.minute);
  }

  @override
  Widget build(BuildContext context) {
    final permissionGranted = ref.watch(notificationPermissionGrantedProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt nhắc ôn tập')),
      body: switch (permissionGranted) {
        AsyncData(value: false) => const _PermissionDeniedPrompt(),
        AsyncData(value: true) => _buildContent(context),
        _ => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      },
    );
  }

  Widget _buildContent(BuildContext context) {
    final settings = ref.watch(reminderSettingsProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        _MasterSwitchCard(
          enabled: settings.enabled,
          onChanged: (value) =>
              ref.read(reminderSettingsProvider.notifier).setEnabled(value),
        ),
        const SizedBox(height: 20),
        Text(
          'Giờ nhắc theo từng ngày',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: AppColors.inkSoft,
              ),
        ),
        const SizedBox(height: 8),
        for (var weekday = 1; weekday <= 7; weekday++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _DayReminderCard(
              weekday: weekday,
              day: settings.perDay[weekday]!,
              masterEnabled: settings.enabled,
              onToggle: (value) => ref
                  .read(reminderSettingsProvider.notifier)
                  .updateDay(weekday, enabled: value),
              onTapTime: () =>
                  _pickTime(weekday, settings.perDay[weekday]!),
            ),
          ),
      ],
    );
  }
}

/// Card công tắc tổng ở đầu màn — tắt thì toàn bộ nhắc từng ngày ngừng hoạt
/// động dù cấu hình từng ngày đang là gì (giữ nguyên, không mất khi bật lại).
class _MasterSwitchCard extends StatelessWidget {
  const _MasterSwitchCard({required this.enabled, required this.onChanged});

  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SwitchListTile(
        secondary: Icon(
          enabled ? Icons.notifications_active_outlined : Icons.notifications_off_outlined,
          color: enabled ? AppColors.brand : AppColors.inkSoft,
        ),
        title: const Text('Bật nhắc ôn tập'),
        subtitle: const Text('Tắt sẽ ngừng toàn bộ nhắc, không đổi giờ đã đặt cho từng ngày'),
        value: enabled,
        onChanged: onChanged,
      ),
    );
  }
}

/// 1 dòng cấu hình cho đúng 1 thứ trong tuần — huy hiệu tên ngày, giờ đã
/// chọn (bấm để đổi), công tắc bật/tắt riêng ngày đó.
class _DayReminderCard extends StatelessWidget {
  const _DayReminderCard({
    required this.weekday,
    required this.day,
    required this.masterEnabled,
    required this.onToggle,
    required this.onTapTime,
  });

  final int weekday;
  final DayReminder day;
  final bool masterEnabled;
  final ValueChanged<bool> onToggle;
  final VoidCallback onTapTime;

  @override
  Widget build(BuildContext context) {
    final active = masterEnabled && day.enabled;
    final time = TimeOfDay(hour: day.hour, minute: day.minute);

    return Card(
      child: ListTile(
        onTap: masterEnabled ? onTapTime : null,
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: active ? AppColors.brand : AppColors.panel2,
          foregroundColor: active ? AppColors.white : AppColors.inkSoft,
          child: Text(
            _weekdayShort[weekday]!,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
          ),
        ),
        title: Text(_weekdayFull[weekday]!),
        subtitle: Text(
          active ? time.format(context) : 'Không nhắc',
          style: TextStyle(
            fontFamily: AppFonts.mono,
            color: active ? AppColors.ink : AppColors.inkSoft,
          ),
        ),
        trailing: Switch(
          value: day.enabled,
          onChanged: masterEnabled ? onToggle : null,
        ),
      ),
    );
  }
}

/// Hiện khi quyền thông báo hệ thống bị từ chối — thay hẳn phần điều khiển
/// giờ/ngày nhắc vì đặt lịch lúc này vô nghĩa (không có gì hiện ra ngoài).
class _PermissionDeniedPrompt extends StatelessWidget {
  const _PermissionDeniedPrompt();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.panel2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.notifications_off_outlined,
                    size: 20,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Chưa cấp quyền thông báo',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Ứng dụng cần quyền thông báo để nhắc ôn tập đúng giờ. Vào Cài đặt hệ '
                'thống để cấp quyền, sau đó quay lại đây.',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: AppColors.inkSoft),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: openAppSettings,
                icon: const Icon(Icons.settings_outlined, size: 18),
                label: const Text('Mở Cài đặt'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Picker giờ dạng cuộn lên/xuống (`CupertinoDatePicker`, có sẵn trong
/// Flutter SDK, không cần thêm dependency) thay cho `showTimePicker` mặc
/// định (dạng mặt đồng hồ) — theo yêu cầu trực tiếp của user.
Future<TimeOfDay?> _showWheelTimePicker(
  BuildContext context, {
  required TimeOfDay initial,
}) {
  var picked = DateTime(0, 1, 1, initial.hour, initial.minute);

  return showModalBottomSheet<TimeOfDay>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Chọn giờ nhắc',
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              SizedBox(
                height: 200,
                child: CupertinoDatePicker(
                  mode: CupertinoDatePickerMode.time,
                  use24hFormat: true,
                  initialDateTime: picked,
                  onDateTimeChanged: (value) => picked = value,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      child: const Text('Huỷ'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(
                        sheetContext,
                        TimeOfDay(hour: picked.hour, minute: picked.minute),
                      ),
                      child: const Text('Xong'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
