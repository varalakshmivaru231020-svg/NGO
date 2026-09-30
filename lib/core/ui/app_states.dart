import 'package:flutter/material.dart';
import 'app_button.dart';

// ══════════════════════════════════════════════════════════════════════
// Loading / empty / error states shared by every list screen.
// ══════════════════════════════════════════════════════════════════════

// Shimmering placeholder block. Keeps the layout's shape while data loads.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.width, this.height = 12, this.radius = 6});
  final double? width;
  final double height;
  final double radius;
  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1F3A30) : const Color(0xFFE9EEEC);
    return FadeTransition(
      opacity: Tween(begin: 0.55, end: 1.0).animate(_c),
      child: Container(
        width: widget.width, height: widget.height,
        decoration: BoxDecoration(color: base, borderRadius: BorderRadius.circular(widget.radius)),
      ),
    );
  }
}

// N placeholder rows shaped like a list row (icon + two lines + trailing).
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.rows = 5, this.rowHeight = 64});
  final int rows;
  final double rowHeight;
  @override
  Widget build(BuildContext context) => Column(children: [
        for (var i = 0; i < rows; i++)
          SizedBox(
            height: rowHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(children: [
                const Skeleton(width: 34, height: 34, radius: 9),
                const SizedBox(width: 12),
                Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Skeleton(width: 120.0 + (i % 3) * 40, height: 11),
                  const SizedBox(height: 7),
                  const Skeleton(width: 80, height: 9),
                ])),
                const Skeleton(width: 34, height: 18, radius: 9),
              ]),
            ),
          ),
      ]);
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.actionLabel, this.onAction});
  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) {
    final sub = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(color: const Color(0xFFFF9933).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, size: 22, color: const Color(0xFFFF9933)),
        ),
        const SizedBox(height: 12),
        Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
        if (message != null) ...[
          const SizedBox(height: 4),
          Text(message!, textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: sub, height: 1.4)),
        ],
        if (actionLabel != null && onAction != null) ...[
          const SizedBox(height: 14),
          AppButton(label: actionLabel!, icon: Icons.add, onPressed: onAction, dense: true),
        ],
      ]),
    );
  }
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => EmptyStateLike(
        icon: Icons.cloud_off_rounded,
        title: 'Couldn’t load this page',
        message: message,
        action: AppButton(label: 'Retry', icon: Icons.refresh_rounded, variant: AppButtonVariant.secondary, dense: true, onPressed: onRetry),
      );
}

class EmptyStateLike extends StatelessWidget {
  const EmptyStateLike({super.key, required this.icon, required this.title, this.message, this.action});
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  @override
  Widget build(BuildContext context) {
    final sub = Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 30, color: sub),
        const SizedBox(height: 10),
        Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
        if (message != null) ...[
          const SizedBox(height: 4),
          Text(message!, textAlign: TextAlign.center, style: TextStyle(fontSize: 12.5, color: sub, height: 1.4)),
        ],
        if (action != null) ...[const SizedBox(height: 14), action!],
      ]),
    );
  }
}
