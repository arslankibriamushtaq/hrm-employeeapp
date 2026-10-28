import 'package:flutter/material.dart';

import 'brand_logo.dart';

/// Home header shared by every role: logo with [trailing] (the notification bell) on the
/// first line, then the greeting and the user's name below it.
class HomeHeader extends StatelessWidget {
  const HomeHeader({super.key, required this.greeting, required this.name, required this.trailing});

  final String greeting;
  final String name;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nameStyle = (theme.appBarTheme.titleTextStyle ?? theme.textTheme.titleLarge)
        ?.copyWith(fontWeight: FontWeight.w600);
    // 16 on the left matches the screen's padding; the bell's own 8px padding makes up
    // the rest on the right.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const BrandLogo(height: 34),
              const Spacer(),
              trailing,
            ],
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(greeting, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: nameStyle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
