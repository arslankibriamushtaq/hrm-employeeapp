import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// The app's one card style (border, radius and soft shadow come from the theme's
/// cardTheme). Leave [color] null so theme overrides, such as the approvals highlight,
/// still apply.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(Space.lg),
    this.color,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);
    return Card(
      color: color,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}

/// An icon on a soft circle of its own colour, for quick actions, stats and list rows.
class IconBubble extends StatelessWidget {
  const IconBubble(this.icon, {super.key, this.color, this.size = 40});

  final IconData icon;

  /// Defaults to the theme's primary (brand red).
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: c.withValues(alpha: 0.12), shape: BoxShape.circle),
      child: Icon(icon, color: c, size: size * 0.5),
    );
  }
}
