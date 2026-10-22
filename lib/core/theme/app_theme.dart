import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Brand typography is bundled locally: Gotham for Latin, GE SS TWO for Arabic.
/// No runtime Google Fonts fetch, so the first paint never waits on the network.
abstract final class AppTheme {
  static const String latinFamily = 'Gotham';
  static const String arabicFamily = 'GE SS TWO';

  static ThemeData light(Locale locale) {
    final isArabic = locale.languageCode == 'ar';
    final family = isArabic ? arabicFamily : latinFamily;
    final fallback = isArabic
        ? const [latinFamily, 'NotoSansArabic']
        : const [arabicFamily, 'NotoSansArabic'];

    final base = ThemeData(
      useMaterial3: true,
      fontFamily: family,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.brandNavy,
        primary: AppColors.brandNavy,
        secondary: AppColors.brandRed,
        surface: AppColors.pageBackground,
      ),
      scaffoldBackgroundColor: AppColors.pageBackground,
    );

    final textTheme = base.textTheme.apply(
      fontFamily: family,
      fontFamilyFallback: fallback,
    );

    return base.copyWith(
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.brandNavy,
        foregroundColor: AppColors.white,
        elevation: 0,
        centerTitle: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.white,
        indicatorColor: AppColors.brandNavy.withValues(alpha: 0.12),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontFamily: family,
            fontFamilyFallback: fallback,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: states.contains(WidgetState.selected)
                ? AppColors.brandNavy
                : AppColors.textSecondary,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.brandNavy
                : AppColors.textSecondary,
          ),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        selectedColor: AppColors.brandNavy,
        secondarySelectedColor: AppColors.brandNavy,
        labelStyle: textTheme.labelLarge,
        secondaryLabelStyle: textTheme.labelLarge?.copyWith(color: AppColors.white),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.brandNavy, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brandNavy,
          foregroundColor: AppColors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: TextStyle(
            fontFamily: family,
            fontFamilyFallback: fallback,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.brandNavy,
          minimumSize: const Size.fromHeight(48),
          side: const BorderSide(color: AppColors.brandNavy),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: TextStyle(
            fontFamily: family,
            fontFamilyFallback: fallback,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
    );
  }
}

