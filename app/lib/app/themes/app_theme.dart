import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// App theme configuration
class AppTheme {
  /// Dark theme for the app
  static ThemeData get darkTheme {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.brand,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: AppColors.background,
      useMaterial3: true,
    );
  }

  /// Light theme for the app (if needed in future)
  static ThemeData get lightTheme {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.brand,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: Colors.white,
      useMaterial3: true,
    );
  }
}

