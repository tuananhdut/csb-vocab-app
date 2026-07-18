import 'package:flutter/material.dart';

/// Bảng màu — copy nguyên từ `app-ssm`
/// (`Sato/agent/app-ssm/lib/label_app/core/theme/app_colors.dart`): navy
/// đậm làm thương hiệu, cam "snap" làm accent chính, teal phụ, nền sáng
/// trung tính. App chỉ dùng **1 bộ màu cố định duy nhất** (không đổi theo
/// Sáng/Tối hệ thống).
class AppColors {
  AppColors._();

  // --- Brand (navy) ---
  static const Color brand = Color(0xFF1F497D);
  static const Color brand2 = Color(0xFF285A95); // lighter navy (hover/links)
  static const Color brandDeep = Color(0xFF16375F);

  // --- Accent (snap orange) ---
  static const Color snap = Color(0xFFF79646);
  static const Color snapDeep = Color(0xFFE07D28);

  // --- Teal (info bars + bottom nav) ---
  static const Color teal = Color(0xFF2CA58D);

  /// Xanh biển sáng — điểm nhấn phụ (đèn tín hiệu, gradient Splash).
  static const Color seaBlue = Color(0xFF0EA5E9);

  // --- Semantic ---
  static const Color signalRed = Color(0xFFDC2626);

  // --- Neutrals (light surface) ---
  static const Color pageBg = Color(0xFFEEF1F5);
  static const Color panel = Color(0xFFFFFFFF);
  static const Color panel2 = Color(0xFFF8FAFC);
  static const Color border = Color(0xFFE2E8F0);
  static const Color ink = Color(0xFF111827);
  static const Color inkSoft = Color(0xFF374151);

  static const Color white = Color(0xFFFFFFFF);
}

/// Font chữ — Georgia (serif) cho tiêu đề/thương hiệu (phong cách "từ điển
/// giấy"/phù hiệu chính thức); Consolas (monospace) cho phiên âm IPA và
/// nhãn loại từ, giống bảng điều khiển thiết bị hàng hải.
class AppFonts {
  AppFonts._();

  static const String serif = 'Georgia';
  static const String mono = 'Consolas';
}

/// Theme cố định duy nhất dùng chung toàn app (Material 3) — không có
/// biến thể Sáng/Tối, dựng thủ công từ [AppColors].
class AppTheme {
  AppTheme._();

  static ThemeData get theme {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.brand,
      onPrimary: AppColors.white,
      secondary: AppColors.snap,
      onSecondary: AppColors.white,
      tertiary: AppColors.teal,
      onTertiary: AppColors.white,
      error: AppColors.signalRed,
      onError: AppColors.white,
      surface: AppColors.panel,
      onSurface: AppColors.ink,
      surfaceContainerHighest: AppColors.panel2,
      outline: AppColors.inkSoft,
    );

    const radius = 8.0;

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.pageBg,
      dividerColor: AppColors.border,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.brand,
        foregroundColor: AppColors.white,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.panel,
        indicatorColor: AppColors.brand,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AppColors.white : scheme.outline,
          );
        }),
      ),
      cardTheme: CardThemeData(
        color: AppColors.panel,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        isDense: true,
        filled: true,
        fillColor: AppColors.panel2,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.brand,
          foregroundColor: AppColors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.brand,
          side: const BorderSide(color: AppColors.border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.brand),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thickness: WidgetStateProperty.all(5),
        radius: const Radius.circular(8),
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.dragged) ||
              states.contains(WidgetState.hovered)) {
            return AppColors.inkSoft.withValues(alpha: 0.5);
          }
          return AppColors.inkSoft.withValues(alpha: 0.25);
        }),
        trackColor: WidgetStateProperty.all(Colors.transparent),
        trackBorderColor: WidgetStateProperty.all(Colors.transparent),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: AppColors.brandDeep,
        contentTextStyle: TextStyle(color: AppColors.white),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
