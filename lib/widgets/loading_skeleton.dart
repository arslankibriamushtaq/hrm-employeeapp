import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Placeholder shapes shown while a screen loads. A single opacity pulse drives the whole
/// skeleton: cheap on low-end phones (no shader or blur layers) and switched off when the
/// system asks for reduced motion.
class LoadingSkeleton extends StatefulWidget {
  const LoadingSkeleton({super.key, required this.children, this.padding = const EdgeInsets.all(Space.lg)});

  /// [count] card-shaped rows, the common list case.
  LoadingSkeleton.list({super.key, int count = 5, double itemHeight = 84, this.padding = const EdgeInsets.all(Space.lg)})
      : children = [for (var i = 0; i < count; i++) SkeletonBox(height: itemHeight, radius: Radii.card)];

  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  State<LoadingSkeleton> createState() => _LoadingSkeletonState();
}

class _LoadingSkeletonState extends State<LoadingSkeleton> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  late final _opacity = Tween<double>(begin: 0.45, end: 1).animate(
    CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: FadeTransition(
        opacity: _opacity,
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: widget.padding,
          children: [
            for (var i = 0; i < widget.children.length; i++) ...[
              if (i > 0) const SizedBox(height: Space.md),
              widget.children[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// One grey placeholder block inside a [LoadingSkeleton].
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, required this.height, this.radius = Radii.control});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
