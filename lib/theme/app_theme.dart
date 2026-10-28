import 'package:flutter/material.dart';

import 'brand.dart';
import 'tokens.dart';

/// The app's only theme (light). Components take their colours, radii and sizes from
/// here so screens do not hardcode any.
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

  const controlRadius = BorderRadius.all(Radius.circular(Radii.control));
  const controlShape = RoundedRectangleBorder(borderRadius: controlRadius);
  // 48dp minimum height keeps every button a comfortable tap target.
  const buttonSize = Size(64, 48);

  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: Brightness.light);
  final text = base.textTheme.apply(bodyColor: AppColors.text, displayColor: AppColors.text);

  OutlineInputBorder inputBorder(Color color, [double width = 1]) =>
      OutlineInputBorder(borderRadius: controlRadius, borderSide: BorderSide(color: color, width: width));

  return base.copyWith(
    scaffoldBackgroundColor: AppColors.white,
    textTheme: text.copyWith(
      headlineSmall: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
      titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w600),
      titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      titleSmall: text.titleSmall?.copyWith(fontWeight: FontWeight.w600),
    ),
    iconTheme: const IconThemeData(color: AppColors.grey),
    dividerTheme: const DividerThemeData(color: AppColors.border, space: 1, thickness: 1),
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.white,
      foregroundColor: AppColors.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: text.titleLarge?.copyWith(fontWeight: FontWeight.w600, color: AppColors.text),
    ),
    // One card style everywhere: thin border plus a barely-there shadow (cheap to paint).
    cardTheme: CardThemeData(
      elevation: 1,
      shadowColor: AppColors.text.withValues(alpha: 0.08),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: AppColors.white,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(Radii.card)),
        side: BorderSide(color: AppColors.border),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: AppColors.grey,
      contentPadding: EdgeInsets.symmetric(horizontal: Space.lg),
      minVerticalPadding: Space.md,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.red,
        foregroundColor: AppColors.white,
        minimumSize: buttonSize,
        shape: controlShape,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.red,
        side: const BorderSide(color: AppColors.border),
        minimumSize: buttonSize,
        shape: controlShape,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.red,
        shape: controlShape,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.lg),
      border: inputBorder(AppColors.border),
      enabledBorder: inputBorder(AppColors.border),
      focusedBorder: inputBorder(AppColors.red, 2),
      errorBorder: inputBorder(AppColors.rejected),
      focusedErrorBorder: inputBorder(AppColors.rejected, 2),
      prefixIconColor: AppColors.grey,
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
          fontWeight: states.contains(WidgetState.selected) ? FontWeight.w600 : FontWeight.w500,
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
      indicatorSize: TabBarIndicatorSize.tab,
      dividerColor: AppColors.border,
      labelStyle: TextStyle(fontWeight: FontWeight.w600),
      unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500),
    ),
    chipTheme: base.chipTheme.copyWith(
      backgroundColor: AppColors.white,
      selectedColor: AppColors.redTint,
      checkmarkColor: AppColors.red,
      side: const BorderSide(color: AppColors.border),
      shape: const RoundedRectangleBorder(borderRadius: controlRadius),
      labelStyle: const TextStyle(color: AppColors.text, fontWeight: FontWeight.w500),
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: AppColors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(Radii.sheet))),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.white,
      modalBackgroundColor: AppColors.white,
      surfaceTintColor: Colors.transparent,
      dragHandleColor: AppColors.border,
      showDragHandle: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.sheet))),
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.text,
      contentTextStyle: TextStyle(color: AppColors.white),
      actionTextColor: AppColors.redTint,
      shape: RoundedRectangleBorder(borderRadius: controlRadius),
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
      linearMinHeight: 6,
    ),
  );
}
