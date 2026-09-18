import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_service.dart';

/// Khoá `shared_preferences` mới (khác 4 khoá phẳng của bản trước —
/// `daily_reminder_enabled`/`hour`/`minute`/`weekdays`, nay không còn đọc) —
/// đổi tên khoá là chủ đích để user nâng cấp từ bản cũ nhận đúng giá trị
/// mặc định mới (đã chốt: không migrate, chấp nhận reset về mặc định vì cấu
/// trúc dữ liệu đổi hẳn từ "1 giờ chung" sang "giờ riêng từng ngày").
const _keyPerDay = 'reminder_per_day_v2';

const _defaultHour = 20;
const _defaultMinute = 0;

/// Cấu hình nhắc ôn tập của 1 ngày trong tuần — bật/tắt và giờ đều độc lập
/// với các ngày khác.
class DayReminder {
  const DayReminder({
    required this.enabled,
    required this.hour,
    required this.minute,
  });

  final bool enabled;
  final int hour;
  final int minute;

  DayReminder copyWith({bool? enabled, int? hour, int? minute}) {
    return DayReminder(
      enabled: enabled ?? this.enabled,
      hour: hour ?? this.hour,
      minute: minute ?? this.minute,
    );
  }
}

final Map<int, DayReminder> _defaultPerDay = {
  for (var weekday = 1; weekday <= 7; weekday++)
    weekday: const DayReminder(
      enabled: true,
      hour: _defaultHour,
      minute: _defaultMinute,
    ),
};

/// Cấu hình nhắc ôn tập hàng tuần — giờ nhắc **riêng cho từng thứ** (khoá
/// [perDay] theo `DateTime.weekday`, 1=Thứ Hai..7=Chủ Nhật), cộng công tắc
/// [enabled] tổng tắt hết bất kể cấu hình từng ngày đang là gì. Xem
/// `docs/csb-vocab-analysis/tasks/06-gio-nhac-rieng-theo-ngay/01-analysis.md`.
class ReminderSettings {
  const ReminderSettings({required this.enabled, required this.perDay});

  final bool enabled;
  final Map<int, DayReminder> perDay;

  ReminderSettings copyWith({bool? enabled, Map<int, DayReminder>? perDay}) {
    return ReminderSettings(
      enabled: enabled ?? this.enabled,
      perDay: perDay ?? this.perDay,
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
    return ReminderSettings(enabled: true, perDay: _defaultPerDay);
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyPerDay);
    state = raw == null ? state : _decode(raw);
    await _applySchedule(state);
  }

  ReminderSettings _decode(String raw) {
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final perDayJson = json['perDay'] as Map<String, dynamic>? ?? const {};
      return ReminderSettings(
        enabled: json['enabled'] as bool? ?? true,
        perDay: {
          for (var weekday = 1; weekday <= 7; weekday++)
            weekday: _decodeDay(perDayJson['$weekday']) ?? _defaultPerDay[weekday]!,
        },
      );
    } catch (_) {
      // Dữ liệu hỏng/không đọc được — coi như chưa từng cấu hình.
      return ReminderSettings(enabled: true, perDay: _defaultPerDay);
    }
  }

  DayReminder? _decodeDay(dynamic json) {
    if (json is! Map<String, dynamic>) return null;
    final hour = json['hour'] as int?;
    final minute = json['minute'] as int?;
    final enabled = json['enabled'] as bool?;
    if (hour == null || minute == null || enabled == null) return null;
    return DayReminder(enabled: enabled, hour: hour, minute: minute);
  }

  /// Bật/tắt công tắc tổng — không đổi cấu hình từng ngày đã lưu.
  Future<void> setEnabled(bool enabled) async {
    state = state.copyWith(enabled: enabled);
    await _save();
  }

  /// Cập nhật 1+ trường của riêng [weekday], giữ nguyên các ngày khác.
  Future<void> updateDay(
    int weekday, {
    bool? enabled,
    int? hour,
    int? minute,
  }) async {
    final current = state.perDay[weekday] ?? _defaultPerDay[weekday]!;
    final nextPerDay = Map<int, DayReminder>.from(state.perDay);
    nextPerDay[weekday] = current.copyWith(
      enabled: enabled,
      hour: hour,
      minute: minute,
    );
    state = state.copyWith(perDay: nextPerDay);
    await _save();
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _keyPerDay,
      jsonEncode({
        'enabled': state.enabled,
        'perDay': {
          for (final entry in state.perDay.entries)
            '${entry.key}': {
              'enabled': entry.value.enabled,
              'hour': entry.value.hour,
              'minute': entry.value.minute,
            },
        },
      }),
    );
    await _applySchedule(state);
  }

  Future<void> _applySchedule(ReminderSettings settings) async {
    await NotificationService.instance.cancelAllReminders();
    if (!settings.enabled) return;

    final dayTimes = {
      for (final entry in settings.perDay.entries)
        if (entry.value.enabled)
          entry.key: (hour: entry.value.hour, minute: entry.value.minute),
    };
    if (dayTimes.isNotEmpty) {
      await NotificationService.instance.scheduleWeeklyReminders(
        dayTimes: dayTimes,
      );
    }
  }
}

final reminderSettingsProvider =
    NotifierProvider<ReminderSettingsNotifier, ReminderSettings>(
      ReminderSettingsNotifier.new,
    );

/// Quyền thông báo hệ thống hiện tại — [ReminderSettingsScreen] chặn UI đặt
/// lịch và chỉ hiện nút mở Cài đặt hệ thống khi `false` (lịch đặt trong
/// app vô nghĩa nếu quyền bị từ chối, không có gì hiện ra ngoài). Không
/// tự cập nhật khi user cấp quyền lại từ Cài đặt hệ thống rồi quay lại
/// app — nơi gọi cần tự `ref.invalidate` khi app resume.
final notificationPermissionGrantedProvider = FutureProvider<bool>((ref) {
  return NotificationService.instance.areNotificationsEnabled();
});
