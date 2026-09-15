import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

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
/// Chỉ gọi được từ Android/iOS — Windows không hỗ trợ nhắc nền theo lịch
/// nên nút mở modal này bị ẩn trên Windows (xem `home_shell.dart`).
Future<void> showDailyReminderSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const DailyReminderSheet(),
  );
}

class DailyReminderSheet extends ConsumerStatefulWidget {
  const DailyReminderSheet({super.key});

  @override
  ConsumerState<DailyReminderSheet> createState() => _DailyReminderSheetState();
}

class _DailyReminderSheetState extends ConsumerState<DailyReminderSheet>
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
    // User có thể vừa rời app để cấp quyền thông báo ở Cài đặt hệ thống
    // (nút "Mở Cài đặt" bên dưới) rồi quay lại — kiểm tra lại quyền ngay
    // khi app resume thay vì bắt user tự đóng/mở lại sheet.
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(notificationPermissionGrantedProvider);
    }
  }

  Future<void> _pickTime(ReminderSettings settings) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: settings.hour, minute: settings.minute),
    );
    if (picked == null) return;
    await ref
        .read(reminderSettingsProvider.notifier)
        .update(hour: picked.hour, minute: picked.minute);
    if (!context.mounted) return;
    _showSavedSnackBar();
  }

  void _toggleWeekday(ReminderSettings settings, int weekday, bool selected) {
    final next = Set<int>.from(settings.weekdays);
    if (selected) {
      next.add(weekday);
    } else {
      next.remove(weekday);
    }
    ref.read(reminderSettingsProvider.notifier).update(weekdays: next);
  }

  void _showSavedSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã lưu cài đặt nhắc ôn tập.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final permissionGranted = ref.watch(notificationPermissionGrantedProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
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
            switch (permissionGranted) {
              AsyncData(value: false) => const _PermissionDeniedPrompt(),
              AsyncData(value: true) => _buildControls(context),
              _ => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            },
          ],
        ),
      ),
    );
  }

  Widget _buildControls(BuildContext context) {
    final settings = ref.watch(reminderSettingsProvider);
    final time = TimeOfDay(hour: settings.hour, minute: settings.minute);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Bật nhắc ôn tập'),
          value: settings.enabled,
          onChanged: (value) {
            ref.read(reminderSettingsProvider.notifier).update(enabled: value);
            _showSavedSnackBar();
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Giờ nhắc'),
          subtitle: Text(time.format(context)),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _pickTime(settings),
        ),
        const SizedBox(height: 8),
        Text(
          'Các thứ trong tuần',
          style: Theme.of(context).textTheme.labelLarge,
        ),
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
                    _toggleWeekday(settings, entry.key, selected),
              ),
          ],
        ),
      ],
    );
  }
}

/// Hiện khi quyền thông báo hệ thống bị từ chối — thay hẳn phần điều
/// khiển giờ/thứ nhắc vì đặt lịch lúc này vô nghĩa (không có gì hiện ra
/// ngoài). Nút "Mở Cài đặt" dẫn thẳng vào màn cài đặt app của hệ điều
/// hành để user tự cấp lại quyền (`didChangeAppLifecycleState` ở
/// [_DailyReminderSheetState] tự kiểm tra lại khi quay về app).
class _PermissionDeniedPrompt extends StatelessWidget {
  const _PermissionDeniedPrompt();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.panel2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.notifications_off_outlined,
                size: 20,
                color: scheme.error,
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
    );
  }
}
