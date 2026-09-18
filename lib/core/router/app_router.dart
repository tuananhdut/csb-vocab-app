import 'package:go_router/go_router.dart';

import '../../features/home/home_shell.dart';
import '../../features/settings/reminder_settings_screen.dart';
import '../../features/splash/splash_screen.dart';

/// Cấu hình điều hướng toàn app (go_router).
/// Khởi động ở splash → tự chuyển sang /home.
final appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/home',
      builder: (context, state) => const HomeShell(),
    ),
    GoRoute(
      path: '/settings/reminders',
      builder: (context, state) => const ReminderSettingsScreen(),
    ),
  ],
);
