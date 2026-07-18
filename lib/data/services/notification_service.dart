import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Thông báo nhắc ôn tập (FR-5.3).
///
/// Đã chốt D2 (plan 06): Windows chỉ nhắc trong lúc app đang mở (in-app +
/// system notification tức thời); Android/iOS dùng local notification lịch
/// hàng ngày, nhắc được cả khi app đã đóng.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const _dueChannelId = 'review_due';
  static const _dailyChannelId = 'daily_reminder';
  static const _windowsGuid = 'd2a2f8b8-1b0b-4ee7-8e9f-6e1e7b2b9a31';

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;

    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
      windows: WindowsInitializationSettings(
        appName: 'CSB Vocab',
        appUserModelId: 'Com.CsbVocab.App',
        guid: _windowsGuid,
      ),
    );
    await _plugin.initialize(settings: initSettings);

    if (Platform.isAndroid) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } else if (Platform.isIOS) {
      await _plugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }

    if (!Platform.isWindows) {
      tz_data.initializeTimeZones();
      _setLocalLocationFromDeviceOffset();
    }

    _initialized = true;
  }

  /// `timezone` cần biết múi giờ thiết bị để lên lịch đúng giờ tường.
  /// Dùng offset UTC hiện tại của máy thay vì phụ thuộc thêm 1 package
  /// tra tên múi giờ — chỉ chính xác với múi giờ tròn giờ (đúng cho VN = UTC+7).
  void _setLocalLocationFromDeviceOffset() {
    final offsetHours = DateTime.now().timeZoneOffset.inHours;
    // Quy ước tên vùng Etc/GMT ngược dấu so với offset UTC thông thường.
    final sign = offsetHours <= 0 ? '+' : '-';
    try {
      tz.setLocalLocation(tz.getLocation('Etc/GMT$sign${offsetHours.abs()}'));
    } catch (_) {
      // Múi giờ lệch nửa giờ (không thuộc Etc/GMT) — giữ mặc định UTC.
    }
  }

  /// Nhắc tức thời khi có từ đến hạn ôn — dùng lúc mở/quay lại app
  /// (đáp ứng yêu cầu Windows; cũng chạy tốt trên Android/iOS).
  Future<void> showDueReminder(int count) async {
    if (count <= 0) return;
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        _dueChannelId,
        'Nhắc ôn tập',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: DarwinNotificationDetails(),
      windows: WindowsNotificationDetails(),
    );
    await _plugin.show(
      id: 1001,
      title: 'Đến giờ ôn tập!',
      body: 'Bạn có $count từ cần ôn hôm nay.',
      notificationDetails: details,
    );
  }

  /// Lên lịch nhắc hàng ngày cho Android/iOS (nhắc cả khi app đã đóng).
  /// Windows không hỗ trợ nhắc nền khi app tắt hẳn — ngoài phạm vi MVP
  /// (đã chốt D2, plan 06).
  Future<void> scheduleDailyReminder({int hour = 20, int minute = 0}) async {
    if (Platform.isWindows) return;

    await _plugin.zonedSchedule(
      id: 2001,
      title: 'Đến giờ ôn từ vựng',
      body: 'Đừng quên ôn lại các từ đã học hôm nay nhé!',
      scheduledDate: _nextInstanceOf(hour, minute),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _dailyChannelId,
          'Nhắc ôn tập hàng ngày',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  tz.TZDateTime _nextInstanceOf(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    return scheduled;
  }
}
