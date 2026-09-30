import 'package:flutter/material.dart';

// ══════════════════════════════════════════════════════════════════════
// AppButton — compact, consistent buttons with a built-in loading state.
// While `loading` is true the button shows a spinner + busyLabel and
// ignores taps, so an action can't be submitted twice.
// ══════════════════════════════════════════════════════════════════════

enum AppButtonVariant { primary, secondary, destructive, ghost }

const _brand = Color(0xFFFF9933);
const _danger = Color(0xFFE5484D);

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.icon,
    this.loading = false,
    this.busyLabel,
    this.expand = false,
    this.autofocus = false,
    this.dense = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final IconData? icon;
  final bool loading;
  final String? busyLabel; // e.g. "Saving…"
  final bool expand;       // full width (forms on phones)
  final bool autofocus;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (bg, fg, border) = switch (variant) {
      AppButtonVariant.primary => (_brand, Colors.white, null),
      AppButtonVariant.destructive => (_danger, Colors.white, null),
      AppButtonVariant.secondary => (Theme.of(context).cardTheme.color ?? Colors.white, scheme.onSurface, Theme.of(context).dividerColor.withValues(alpha: 0.6)),
      AppButtonVariant.ghost => (Colors.transparent, scheme.onSurface.withValues(alpha: 0.8), null),
    };
    final disabled = onPressed == null && !loading;
    final h = dense ? 32.0 : 38.0;

    final child = AnimatedSwitcher(
      duration: const Duration(milliseconds: 150),
      child: Row(
        key: ValueKey(loading),
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (loading)
            SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: fg))
          else if (icon != null)
            Icon(icon, size: 16, color: fg),
          if (loading || icon != null) const SizedBox(width: 8),
          Text(loading ? (busyLabel ?? label) : label,
              style: TextStyle(fontSize: dense ? 12.5 : 13.5, fontWeight: FontWeight.w600, color: fg)),
        ],
      ),
    );

    return Semantics(
      button: true,
      enabled: !disabled && !loading,
      child: Opacity(
        opacity: disabled ? 0.5 : 1,
        child: SizedBox(
          height: h,
          width: expand ? double.infinity : null,
          child: TextButton(
            autofocus: autofocus,
            onPressed: (loading || onPressed == null) ? null : onPressed,
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith((s) {
                if (variant == AppButtonVariant.ghost) {
                  return s.contains(WidgetState.hovered) ? scheme.onSurface.withValues(alpha: 0.06) : Colors.transparent;
                }
                // Loading keeps full colour (disabled look only when truly disabled).
                if (s.contains(WidgetState.pressed)) return Color.lerp(bg, Colors.black, 0.08);
                if (s.contains(WidgetState.hovered)) return Color.lerp(bg, Colors.black, 0.04);
                return bg;
              }),
              foregroundColor: WidgetStatePropertyAll(fg),
              overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: dense ? 12 : 16)),
              minimumSize: WidgetStatePropertyAll(Size(0, h)),
              shape: WidgetStateProperty.resolveWith((s) => RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                    side: s.contains(WidgetState.focused)
                        ? BorderSide(color: _brand.withValues(alpha: 0.6), width: 2)
                        : (border != null ? BorderSide(color: border) : BorderSide.none),
                  )),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              animationDuration: const Duration(milliseconds: 150),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

// Small subtle spinner for inline loading (toggles, rows).
class AppSpinner extends StatelessWidget {
  const AppSpinner({super.key, this.size = 14, this.color});
  final double size;
  final Color? color;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: size, height: size,
        child: CircularProgressIndicator(strokeWidth: 2, color: color ?? _brand),
      );
}
