import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Day number over a short caption (weekday or month), used by attendance and holiday
/// rows. [muted] greys it out for past dates.
class DateBadge extends StatelessWidget {
  const DateBadge({super.key, required this.date, required this.caption, this.muted = false});

  final DateTime date;
  final String caption;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = muted ? scheme.surfaceContainerHigh : scheme.primaryContainer;
    final fg = muted ? scheme.onSurfaceVariant : scheme.onPrimaryContainer;
    return Container(
      constraints: const BoxConstraints(minWidth: 52),
      padding: const EdgeInsets.symmetric(horizontal: Space.sm, vertical: Space.sm),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(Radii.control)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${date.day}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: fg, height: 1.1)),
          Text(caption, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: fg)),
        ],
      ),
    );
  }
}
