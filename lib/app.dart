import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/constants/app_constants.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

/// Widget gốc: MaterialApp.router + theme cố định duy nhất (teal biển),
/// không có biến thể Sáng/Tối.
class CsbVocabApp extends ConsumerWidget {
  const CsbVocabApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      locale: const Locale('vi'),
      supportedLocales: const [Locale('vi')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      // Ép giờ 24h cho mọi dialog dùng đồng hồ (showTimePicker...) thay vì
      // phụ thuộc cài đặt 12h/24h của từng máy — đồng bộ với UI còn lại
      // của app (label "Giờ nhắc" hiển thị 24h).
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
      routerConfig: appRouter,
    );
  }
}
