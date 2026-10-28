import 'package:flutter/material.dart';

/// MYTM brand assets. Swap the logo file here only.
abstract final class Brand {
  static const logoAsset = 'assets/images/mytm_logo.png';

  /// Width / height of the logo file (1200 x 547).
  static const logoAspectRatio = 1200 / 547;
}

/// MYTM palette plus the neutrals and status shades the theme is built from.
abstract final class AppColors {
  static const red = Color(0xFFEC1B21);
  static const grey = Color(0xFF828282);
  static const white = Color(0xFFFFFFFF);

  static const text = Color(0xFF2B2B2B);
  static const surfaceGrey = Color(0xFFF5F5F5);
  static const border = Color(0xFFE0E0E0);

  /// Light red for selected states (navigation indicator, chips, containers).
  static const redTint = Color(0xFFFDE8E9);
  static const onRedTint = Color(0xFF7F0F13);

  // Status meaning stays fixed: approved green, pending orange, rejected red, the rest grey.
  static const approved = Color(0xFF2E7D32);
  static const pending = Color(0xFFE65100);
  static const rejected = Color(0xFFD32F2F);
  static const neutral = grey;
}
