import 'package:flutter/material.dart';
import 'app_colors.dart';

abstract final class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryStart,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: Colors.transparent,
        cardColor: AppColors.lightCardFill,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          foregroundColor: AppColors.lightText,
          titleTextStyle: TextStyle(
            color: AppColors.lightText,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: AppColors.lightNavBg,
          indicatorColor: AppColors.primaryStart.withValues(alpha: 0.15),
          labelTextStyle: WidgetStatePropertyAll(
            TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.lightSecondaryText,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF3F3F5),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primaryStart, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          hintStyle: const TextStyle(color: AppColors.lightSecondaryText, fontSize: 14),
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(color: AppColors.lightText, fontWeight: FontWeight.w700),
          headlineMedium: TextStyle(color: AppColors.lightText, fontWeight: FontWeight.w600),
          headlineSmall: TextStyle(color: AppColors.lightText, fontWeight: FontWeight.w600),
          titleLarge: TextStyle(color: AppColors.lightText, fontWeight: FontWeight.w600),
          titleMedium: TextStyle(color: AppColors.lightText, fontWeight: FontWeight.w500),
          titleSmall: TextStyle(color: AppColors.lightText, fontWeight: FontWeight.w500),
          bodyLarge: TextStyle(color: AppColors.lightText),
          bodyMedium: TextStyle(color: AppColors.lightText),
          bodySmall: TextStyle(color: AppColors.lightSecondaryText),
          labelLarge: TextStyle(color: AppColors.lightText, fontWeight: FontWeight.w500),
          labelMedium: TextStyle(color: AppColors.lightSecondaryText),
          labelSmall: TextStyle(color: AppColors.lightSecondaryText),
        ),
        dividerColor: const Color(0x1A000000),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return Colors.white;
            return AppColors.lightSecondaryText;
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return AppColors.primaryStart;
            return const Color(0xFFE5E7EB);
          }),
        ),
      );

  static ThemeData get dark => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primaryStart,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: Colors.transparent,
        cardColor: AppColors.darkCardFill,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          foregroundColor: AppColors.darkText,
          titleTextStyle: TextStyle(
            color: AppColors.darkText,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: AppColors.darkNavBg,
          indicatorColor: AppColors.primaryStart.withValues(alpha: 0.2),
          labelTextStyle: WidgetStatePropertyAll(
            TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.darkSecondaryText,
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0x1AFFFFFF),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0x1AFFFFFF)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primaryStart, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          hintStyle: const TextStyle(color: AppColors.darkSecondaryText, fontSize: 14),
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(color: AppColors.darkText, fontWeight: FontWeight.w700),
          headlineMedium: TextStyle(color: AppColors.darkText, fontWeight: FontWeight.w600),
          headlineSmall: TextStyle(color: AppColors.darkText, fontWeight: FontWeight.w600),
          titleLarge: TextStyle(color: AppColors.darkText, fontWeight: FontWeight.w600),
          titleMedium: TextStyle(color: AppColors.darkText, fontWeight: FontWeight.w500),
          titleSmall: TextStyle(color: AppColors.darkText, fontWeight: FontWeight.w500),
          bodyLarge: TextStyle(color: AppColors.darkText),
          bodyMedium: TextStyle(color: AppColors.darkText),
          bodySmall: TextStyle(color: AppColors.darkSecondaryText),
          labelLarge: TextStyle(color: AppColors.darkText, fontWeight: FontWeight.w500),
          labelMedium: TextStyle(color: AppColors.darkSecondaryText),
          labelSmall: TextStyle(color: AppColors.darkSecondaryText),
        ),
        dividerColor: const Color(0x1AFFFFFF),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return Colors.white;
            return AppColors.darkSecondaryText;
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return AppColors.primaryStart;
            return const Color(0x33FFFFFF);
          }),
        ),
      );
}
