import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_button.dart';
import 'app_toast.dart';

// ══════════════════════════════════════════════════════════════════════
// Modals & confirmations — one look for every dialog in the app.
//
// showAppSheet: drop-in for showModalBottomSheet. Phones keep a bottom
//   sheet; wider screens get a compact centred dialog (≤520px) with a soft,
//   lightly blurred backdrop. Content built for a sheet works unchanged —
//   its grab handle (SheetHandle) hides itself in dialog mode.
// AppConfirm.show: the single confirmation dialog (delete etc.), with its
//   own loading state so the action can't be fired twice.
// ══════════════════════════════════════════════════════════════════════

const kAppBarrier = Color(0x5215211E); // soft slate, page stays recognisable

bool isWideLayout(BuildContext context) => MediaQuery.sizeOf(context).width >= 700;

class _DialogMode extends InheritedWidget {
  const _DialogMode({required super.child});
  static bool of(BuildContext c) => c.dependOnInheritedWidgetOfExactType<_DialogMode>() != null;
  @override
  bool updateShouldNotify(_DialogMode old) => false;
}

// The small grab bar at the top of a sheet. Invisible when the same content
// is shown as a desktop dialog.
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key, this.margin});
  final EdgeInsetsGeometry? margin;
  @override
  Widget build(BuildContext context) {
    if (_DialogMode.of(context)) return const SizedBox.shrink();
    return Center(
      child: Container(
        width: 36, height: 4, margin: margin,
        decoration: BoxDecoration(color: Theme.of(context).dividerColor.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(2)),
      ),
    );
  }
}

Future<T?> showAppSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  Color? backgroundColor,
  ShapeBorder? shape,
  bool useSafeArea = false,
  bool isDismissible = true,
  bool enableDrag = true,
  bool useRootNavigator = false,
  BoxConstraints? constraints,
}) {
  if (!isWideLayout(context)) {
    return showModalBottomSheet<T>(
      context: context,
      builder: builder,
      isScrollControlled: isScrollControlled,
      backgroundColor: backgroundColor,
      shape: shape,
      useSafeArea: useSafeArea,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      useRootNavigator: useRootNavigator,
      constraints: constraints,
      barrierColor: kAppBarrier,
    );
  }
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: isDismissible,
    barrierLabel: 'Close',
    barrierColor: kAppBarrier,
    useRootNavigator: useRootNavigator,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (ctx, _, __) => _DialogMode(child: _DesktopDialogFrame(builder: builder)),
    transitionBuilder: (ctx, anim, _, child) {
      final a = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 2 * a.value, sigmaY: 2 * a.value),
        child: FadeTransition(
          opacity: a,
          child: ScaleTransition(scale: Tween(begin: 0.97, end: 1.0).animate(a), child: child),
        ),
      );
    },
  );
}

class _DesktopDialogFrame extends StatelessWidget {
  const _DesktopDialogFrame({required this.builder});
  final WidgetBuilder builder;
  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.sizeOf(context).height * 0.88;
    return Shortcuts(
      shortcuts: const {SingleActivator(LogicalKeyboardKey.escape): DismissIntent()},
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 520, maxHeight: maxH),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Material(
              color: Theme.of(context).cardTheme.color ?? Colors.white,
              borderRadius: BorderRadius.circular(16),
              clipBehavior: Clip.antiAlias,
              elevation: 12,
              shadowColor: const Color(0x40000000),
              // Sheet content often sizes itself with MediaQuery bottom
              // insets / rounded top corners; a scroll view keeps tall forms
              // usable inside the dialog's max height.
              child: SingleChildScrollView(
                child: MediaQuery.removeViewInsets(context: context, removeBottom: true, child: Builder(builder: builder)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AppConfirm {
  AppConfirm._();

  // Returns true once [onConfirm] has completed successfully (or, without
  // onConfirm, when the user confirmed). Errors thrown by onConfirm are
  // shown as a toast and the dialog stays open.
  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Delete',
    String busyLabel = 'Deleting…',
    bool destructive = true,
    Future<void> Function()? onConfirm,
    String Function(Object error)? errorText,
  }) async {
    final ok = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Cancel',
      barrierColor: kAppBarrier,
      transitionDuration: const Duration(milliseconds: 160),
      pageBuilder: (ctx, _, __) => _ConfirmDialog(
        title: title, message: message, confirmLabel: confirmLabel, busyLabel: busyLabel,
        destructive: destructive, onConfirm: onConfirm, errorText: errorText,
      ),
      transitionBuilder: (ctx, anim, _, child) {
        final a = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(opacity: a, child: ScaleTransition(scale: Tween(begin: 0.97, end: 1.0).animate(a), child: child));
      },
    );
    return ok == true;
  }
}

class _ConfirmDialog extends StatefulWidget {
  const _ConfirmDialog({
    required this.title, required this.message, required this.confirmLabel, required this.busyLabel,
    required this.destructive, this.onConfirm, this.errorText,
  });
  final String title, message, confirmLabel, busyLabel;
  final bool destructive;
  final Future<void> Function()? onConfirm;
  final String Function(Object error)? errorText;
  @override
  State<_ConfirmDialog> createState() => _ConfirmDialogState();
}

class _ConfirmDialogState extends State<_ConfirmDialog> {
  bool _busy = false;

  Future<void> _go() async {
    if (_busy) return;
    if (widget.onConfirm == null) { Navigator.of(context).pop(true); return; }
    setState(() => _busy = true);
    try {
      await widget.onConfirm!();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppToast.error(context, widget.errorText?.call(e) ?? 'Something went wrong. Please try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Shortcuts(
      shortcuts: const {SingleActivator(LogicalKeyboardKey.escape): DismissIntent()},
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Material(
              color: theme.cardTheme.color ?? Colors.white,
              borderRadius: BorderRadius.circular(14),
              elevation: 12,
              shadowColor: const Color(0x40000000),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(widget.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(widget.message, style: TextStyle(fontSize: 13.5, height: 1.45, color: theme.colorScheme.onSurface.withValues(alpha: 0.72))),
                  const SizedBox(height: 18),
                  Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    AppButton(label: 'Cancel', variant: AppButtonVariant.secondary,
                        onPressed: _busy ? null : () => Navigator.of(context).pop(false)),
                    const SizedBox(width: 8),
                    AppButton(
                      label: widget.confirmLabel, busyLabel: widget.busyLabel, loading: _busy, autofocus: true,
                      variant: widget.destructive ? AppButtonVariant.destructive : AppButtonVariant.primary,
                      onPressed: _go,
                    ),
                  ]),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
