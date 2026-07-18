import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.init();
  await NotificationService.instance.scheduleDailyReminder();
  runApp(const ProviderScope(child: CsbVocabApp()));
}
