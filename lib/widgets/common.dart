import 'package:flutter/material.dart';

import '../theme/brand.dart';
import '../theme/tokens.dart';
import '../utils/format.dart';
import 'app_card.dart';
import 'loading_skeleton.dart';

export 'app_card.dart';
export 'date_badge.dart';
export 'initials_avatar.dart';
export 'loading_skeleton.dart';

void showSnack(BuildContext context, String message, {bool error = false}) {
  final scheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? scheme.error : null,
      behavior: SnackBarBehavior.floating,
    ));
}

/// Colour for APPROVED / REJECTED / PENDING / NOT_REQUIRED style statuses.
Color statusColor(String? status) {
  switch (status) {
    case 'APPROVED':
    case 'PRESENT':
      return AppColors.approved;
    case 'REJECTED':
    case 'ABSENT':
      return AppColors.rejected;
    case 'PENDING':
    case 'IN_PROGRESS':
      return AppColors.pending;
    default:
      return AppColors.neutral;
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key, this.label});

  final String? status;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: Space.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label ?? humanize(status),
        style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}

/// Centred icon and message for an empty list.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(Space.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconBubble(icon, color: scheme.onSurfaceVariant, size: 72),
          const SizedBox(height: Space.lg),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// Failed load: the (already human-readable) message and a retry button.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(Space.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconBubble(Icons.cloud_off_outlined, color: scheme.error, size: 72),
            const SizedBox(height: Space.lg),
            Text(message, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: Space.lg),
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Skeleton while loading, [ErrorState] on failure, [builder] with the data otherwise.
/// The data fades in once when it arrives. A one-way fade (rather than a cross-fade
/// AnimatedSwitcher) never has old and new content mounted together, so widgets with
/// GlobalKeys inside (the approvals highlight) cannot clash.
class AsyncBody<T> extends StatelessWidget {
  const AsyncBody({
    super.key,
    required this.future,
    required this.onRetry,
    required this.builder,
    this.skeleton,
  });

  final Future<T> future;
  final VoidCallback onRetry;
  final Widget Function(BuildContext context, T data) builder;

  /// Defaults to a generic list of card placeholders.
  final Widget? skeleton;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return skeleton ?? LoadingSkeleton.list();
        }
        if (snap.hasError) return ErrorState(message: snap.error.toString(), onRetry: onRetry);
        return _FadeIn(child: builder(context, snap.data as T));
      },
    );
  }
}

class _FadeIn extends StatelessWidget {
  const _FadeIn({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 200),
      builder: (context, value, child) => Opacity(opacity: value, child: child),
      child: child,
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.xs, Space.xl, Space.xs, Space.sm),
      child: Row(
        children: [
          Expanded(child: Text(text, style: Theme.of(context).textTheme.titleMedium)),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Label/value row used on detail sheets. Stacks the value under the label when the
/// text is scaled up, so long values never squeeze into a narrow column.
class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key, this.valueColor});

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final muted = TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant);
    final valueStyle = TextStyle(fontWeight: FontWeight.w600, color: valueColor);
    final stacked = MediaQuery.textScalerOf(context).scale(1) > 1.2;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: stacked
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [Text(label, style: muted), const SizedBox(height: 2), Text(value, style: valueStyle)],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 132, child: Text(label, style: muted)),
                Expanded(child: Text(value, style: valueStyle, textAlign: TextAlign.end)),
              ],
            ),
    );
  }
}
