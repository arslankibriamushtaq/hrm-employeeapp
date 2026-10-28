import 'package:flutter/material.dart';

import '../theme/brand.dart';

/// The MYTM logo, sized by [width] or [height] (the other follows the file's aspect
/// ratio). The file already has its own white space and thin red border, so nothing is
/// drawn around it. A missing file shows a small "MYTM" text instead of crashing.
class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.width, this.height})
      : assert(width != null || height != null, 'Give the logo a width or a height');

  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final w = width ?? height! * Brand.logoAspectRatio;
    final h = height ?? w / Brand.logoAspectRatio;
    return Image.asset(
      Brand.logoAsset,
      width: w,
      height: h,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
      // Decode at 3x the shown width rather than the full 1200px file.
      cacheWidth: (w * 3).round(),
      semanticLabel: 'MYTM',
      errorBuilder: (context, error, stackTrace) => SizedBox(
        width: w,
        height: h,
        child: const Center(
          child: Text('MYTM', style: TextStyle(color: AppColors.red, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}
