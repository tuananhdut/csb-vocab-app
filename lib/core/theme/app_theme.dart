import 'package:flutter/material.dart';

/// Bảng màu theo bộ nhận diện Cảnh sát biển Việt Nam:
/// chủ đạo xanh navy + trắng, điểm nhấn vàng (theo phù hiệu).
class AppColors {
  AppColors._();

  /// Xanh navy đậm — màu chủ đạo.
  static const Color navy = Color(0xFF0A2A5E);
  static const Color navyDark = Color(0xFF061B3D);

  /// Xanh biển sáng hơn cho điểm nhấn phụ.
  static const Color seaBlue = Color(0xFF1565C0);

  /// Vàng phù hiệu — dùng làm accent.
  static const Color gold = Color(0xFFF2A900);

  static const Color white = Color(0xFFFFFFFF);
}

/// Theme sáng / tối dùng chung cho toàn app (Material 3).
class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.navy,
      primary: AppColors.navy,
      secondary: AppColors.gold,
      brightness: Brightness.light,
    );
    return _base(scheme);
  }

  static ThemeData get dark {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.navy,
      primary: AppColors.seaBlue,
      secondary: AppColors.gold,
      brightness: Brightness.dark,
    );
    return _base(scheme);
  }

  static ThemeData _base(ColorScheme scheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        centerTitle: false,
        elevation: 0,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        isDense: true,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
    );
  }
}
