import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/services/notification_service.dart';
import 'data/services/reminder_settings_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.init();

  // Khởi tạo `ReminderSettingsNotifier` trước `runApp` để nó tự đọc cấu
  // hình đã lưu (hoặc mặc định) và lên lịch nhắc tương ứng ngay từ đầu —
  // `ProviderScope` bên dưới dùng chung container này nên không tạo lại.
  final container = ProviderContainer();
  await container.read(reminderSettingsProvider.notifier).ready;

  runApp(
    UncontrolledProviderScope(container: container, child: const CsbVocabApp()),
  );
}
