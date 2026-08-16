import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_service.dart';

const _keyEnabled = 'daily_reminder_enabled';
const _keyHour = 'daily_reminder_hour';
const _keyMinute = 'daily_reminder_minute';
const _keyWeekdays = 'daily_reminder_weekdays';

const _defaultHour = 20;
const _defaultMinute = 0;
final _defaultWeekdays = {1, 2, 3, 4, 5, 6, 7};

/// Cấu hình nhắc ôn tập hàng tuần (đặt giờ tuỳ chỉnh, chọn theo thứ) —
/// xem `docs/csb-vocab-analysis/tasks/05-dat-gio-nhac-on-tap/03-plan.md`.
///
/// [weekdays] dùng giá trị `DateTime.weekday` (1=Thứ Hai..7=Chủ Nhật).
/// Bỏ chọn hết các thứ (nhưng [enabled] vẫn `true`) là trạng thái hợp lệ —
/// tương đương không có lịch nào active, không cần chặn ở UI (quyết định
/// đã chốt ở task-plan).
class ReminderSettings {
  const ReminderSettings({
    required this.enabled,
    required this.hour,
    required this.minute,
    required this.weekdays,
  });

  final bool enabled;
  final int hour;
  final int minute;
  final Set<int> weekdays;

  ReminderSettings copyWith({
    bool? enabled,
    int? hour,
    int? minute,
    Set<int>? weekdays,
  }) {
    return ReminderSettings(
      enabled: enabled ?? this.enabled,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
      weekdays: weekdays ?? this.weekdays,
    );
  }
}

/// Đọc/ghi [ReminderSettings] qua `shared_preferences` và đồng bộ lịch
/// thông báo thật trong [NotificationService] mỗi khi state đổi.
class ReminderSettingsNotifier extends Notifier<ReminderSettings> {
  /// Hoàn tất khi đã đọc xong `shared_preferences` và áp dụng lịch thông
  /// báo tương ứng lần đầu — `main.dart` await giá trị này trước `runApp`
  /// để tránh app mở lên với lịch nhắc còn ở trạng thái mặc định tạm thời.
  late final Future<void> ready;

  @override
  ReminderSettings build() {
    ready = _load();
    return ReminderSettings(
      enabled: true,
      hour: _defaultHour,
      minute: _defaultMinute,
      weekdays: _defaultWeekdays,
    );
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final weekdayStrings = prefs.getStringList(_keyWeekdays);
    state = ReminderSettings(
      enabled: prefs.getBool(_keyEnabled) ?? true,
      hour: prefs.getInt(_keyHour) ?? _defaultHour,
      minute: prefs.getInt(_keyMinute) ?? _defaultMinute,
      weekdays: weekdayStrings == null
          ? _defaultWeekdays
          : weekdayStrings.map(int.parse).toSet(),
    );
    await _applySchedule(state);
  }

  /// Cập nhật 1+ trường, lưu lại và lên lịch/huỷ lịch tương ứng.
  Future<void> update({
    bool? enabled,
    int? hour,
    int? minute,
    Set<int>? weekdays,
  }) async {
    final next = state.copyWith(
      enabled: enabled,
      hour: hour,
      minute: minute,
      weekdays: weekdays,
    );
    state = next;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, next.enabled);
    await prefs.setInt(_keyHour, next.hour);
    await prefs.setInt(_keyMinute, next.minute);
    await prefs.setStringList(
      _keyWeekdays,
      next.weekdays.map((w) => w.toString()).toList(),
    );

    await _applySchedule(next);
  }

  Future<void> _applySchedule(ReminderSettings settings) async {
    await NotificationService.instance.cancelAllReminders();
    if (settings.enabled && settings.weekdays.isNotEmpty) {
      await NotificationService.instance.scheduleWeeklyReminders(
        hour: settings.hour,
        minute: settings.minute,
        weekdays: settings.weekdays,
      );
    }
  }
}

final reminderSettingsProvider =
    NotifierProvider<ReminderSettingsNotifier, ReminderSettings>(
      ReminderSettingsNotifier.new,
    );
