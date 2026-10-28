import 'package:flutter/material.dart';

import 'brand.dart';

/// The app's only theme (light). Components take their colours from here so screens
/// do not hardcode any.
ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: AppColors.red).copyWith(
    primary: AppColors.red,
    onPrimary: AppColors.white,
    primaryContainer: AppColors.redTint,
    onPrimaryContainer: AppColors.onRedTint,
    secondaryContainer: AppColors.redTint,
    onSecondaryContainer: AppColors.onRedTint,
    error: AppColors.rejected,
    onError: AppColors.white,
    surface: AppColors.white,
    onSurface: AppColors.text,
    onSurfaceVariant: AppColors.grey,
    surfaceContainerLowest: AppColors.white,
    surfaceContainerLow: const Color(0xFFFAFAFA),
    surfaceContainer: AppColors.surfaceGrey,
    surfaceContainerHigh: const Color(0xFFF0F0F0),
    surfaceContainerHighest: const Color(0xFFEEEEEE),
    outline: const Color(0xFFBDBDBD),
    outlineVariant: AppColors.border,
    surfaceTint: Colors.transparent,
  );

  const inputRadius = BorderRadius.all(Radius.circular(4));
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: Brightness.light);

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.white,
    textTheme: base.textTheme.apply(bodyColor: AppColors.text, displayColor: AppColors.text),
    iconTheme: const IconThemeData(color: AppColors.grey),
    dividerTheme: const DividerThemeData(color: AppColors.border),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.white,
      foregroundColor: AppColors.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    cardTheme: const CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: AppColors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        side: BorderSide(color: AppColors.border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(backgroundColor: AppColors.red, foregroundColor: AppColors.white),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.red,
        side: const BorderSide(color: AppColors.border),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.red),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: inputRadius, borderSide: BorderSide(color: AppColors.border)),
      enabledBorder:
          OutlineInputBorder(borderRadius: inputRadius, borderSide: BorderSide(color: AppColors.border)),
      focusedBorder:
          OutlineInputBorder(borderRadius: inputRadius, borderSide: BorderSide(color: AppColors.red, width: 2)),
      errorBorder:
          OutlineInputBorder(borderRadius: inputRadius, borderSide: BorderSide(color: AppColors.rejected)),
      focusedErrorBorder:
          OutlineInputBorder(borderRadius: inputRadius, borderSide: BorderSide(color: AppColors.rejected, width: 2)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.white,
      surfaceTintColor: Colors.transparent,
      indicatorColor: AppColors.redTint,
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(color: states.contains(WidgetState.selected) ? AppColors.red : AppColors.grey),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: states.contains(WidgetState.selected) ? AppColors.red : AppColors.grey,
        ),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.white,
      selectedItemColor: AppColors.red,
      unselectedItemColor: AppColors.grey,
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: AppColors.red,
      unselectedLabelColor: AppColors.grey,
      indicatorColor: AppColors.red,
      dividerColor: AppColors.border,
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: AppColors.white,
      selectedColor: AppColors.redTint,
      checkmarkColor: AppColors.red,
      side: const BorderSide(color: AppColors.border),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: AppColors.white,
      surfaceTintColor: Colors.transparent,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.white,
      modalBackgroundColor: AppColors.white,
      surfaceTintColor: Colors.transparent,
      dragHandleColor: AppColors.border,
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.text,
      contentTextStyle: TextStyle(color: AppColors.white),
      actionTextColor: AppColors.redTint,
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? AppColors.white : AppColors.grey,
      ),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) ? AppColors.red : AppColors.surfaceGrey,
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.red,
      linearTrackColor: AppColors.redTint,
    ),
  );
}
