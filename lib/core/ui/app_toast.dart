import 'dart:async';
import 'package:flutter/material.dart';

// ══════════════════════════════════════════════════════════════════════
// AppToast — the single notification system for the whole app.
// Compact overlay, top-right on desktop / top on phones. It never pushes
// page content around, auto-dismisses, can be closed by hand, and is read
// out by screen readers (live region).
//
//   AppToast.success(context, 'Student added');
//   AppToast.error(context, 'Could not save', detail: 'Check the form.');
//
// Legacy call sites that built a SnackBar go through [fromSnackBar], which
// keeps their text and infers the tone from the old background colour.
// ══════════════════════════════════════════════════════════════════════

enum ToastTone { success, error, warning, info }

class AppToast {
  AppToast._();

  static final List<_ToastHandle> _live = [];
  static const _maxVisible = 3;

  static void success(BuildContext context, String message, {String? detail}) =>
      show(context, tone: ToastTone.success, title: message, detail: detail);

  static void error(BuildContext context, String message, {String? detail}) =>
      show(context, tone: ToastTone.error, title: message, detail: detail);

  static void warning(BuildContext context, String message, {String? detail}) =>
      show(context, tone: ToastTone.warning, title: message, detail: detail);

  static void info(BuildContext context, String message, {String? detail}) =>
      show(context, tone: ToastTone.info, title: message, detail: detail);

  static void show(
    BuildContext context, {
    required ToastTone tone,
    String? title,
    String? detail,
    Widget? content,
    Duration? duration,
    SnackBarAction? action,
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    // Errors get a little longer to read.
    final d = duration ?? (tone == ToastTone.error ? const Duration(milliseconds: 5000) : const Duration(milliseconds: 3500));

    while (_live.length >= _maxVisible) {
      _live.first.dismiss();
    }
    late final _ToastHandle handle;
    final key = GlobalKey<_ToastCardState>();
    final entry = OverlayEntry(builder: (ctx) {
      final index = _live.indexOf(handle);
      return _ToastPositioned(
        index: index < 0 ? 0 : index,
        child: _ToastCard(
          key: key,
          tone: tone,
          title: title,
          detail: detail,
          content: content,
          action: action,
          onClose: () => handle.dismiss(),
        ),
      );
    });
    handle = _ToastHandle(entry, key);
    _live.add(handle);
    overlay.insert(entry);
    _relayout();
    handle.timer = Timer(d, handle.dismiss);
  }

  // Adapter for existing `SnackBar(...)` call sites.
  static void fromSnackBar(BuildContext context, SnackBar bar) {
    show(
      context,
      tone: _toneFor(bar.backgroundColor),
      content: bar.content,
      duration: bar.duration > const Duration(seconds: 6)
          ? const Duration(seconds: 6)
          : (bar.duration < const Duration(milliseconds: 2500) ? null : bar.duration),
      action: bar.action,
    );
  }

  static void hideAll() {
    for (final h in List.of(_live)) {
      h.dismiss();
    }
  }

  static ToastTone _toneFor(Color? c) {
    if (c == null) return ToastTone.success;
    final v = c.toARGB32() & 0xFFFFFF;
    const warnings = {0xE0921A, 0xF6A723, 0xF6B84A, 0xFFC107, 0xFF9800};
    if (warnings.contains(v)) return ToastTone.warning;
    final hsl = HSLColor.fromColor(c);
    if (hsl.saturation > 0.35 && (hsl.hue < 15 || hsl.hue > 340)) return ToastTone.error;
    if (hsl.saturation < 0.15) return ToastTone.info;
    return ToastTone.success;
  }

  static void _relayout() {
    for (final h in _live) {
      h.entry.markNeedsBuild();
    }
  }
}

class _ToastHandle {
  _ToastHandle(this.entry, this.key);
  final OverlayEntry entry;
  final GlobalKey<_ToastCardState> key;
  Timer? timer;
  bool _gone = false;

  Future<void> dismiss() async {
    if (_gone) return;
    _gone = true;
    timer?.cancel();
    await key.currentState?.animateOut();
    entry.remove();
    AppToast._live.remove(this);
    AppToast._relayout();
  }
}

class _ToastPositioned extends StatelessWidget {
  const _ToastPositioned({required this.index, required this.child});
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final wide = mq.size.width >= 640;
    final top = mq.padding.top + 16 + index * 76.0;
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      top: top,
      right: 16,
      left: wide ? null : 16,
      width: wide ? 360 : null,
      child: child,
    );
  }
}

class _ToastCard extends StatefulWidget {
  const _ToastCard({
    super.key,
    required this.tone,
    this.title,
    this.detail,
    this.content,
    this.action,
    required this.onClose,
  });
  final ToastTone tone;
  final String? title;
  final String? detail;
  final Widget? content;
  final SnackBarAction? action;
  final VoidCallback onClose;

  @override
  State<_ToastCard> createState() => _ToastCardState();
}

class _ToastCardState extends State<_ToastCard> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 200))..forward();

  Future<void> animateOut() async {
    if (!mounted) return;
    await _c.reverse();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  (IconData, Color) get _style => switch (widget.tone) {
        ToastTone.success => (Icons.check_circle_rounded, const Color(0xFF34C38F)),
        ToastTone.error => (Icons.error_rounded, const Color(0xFFFF6B61)),
        ToastTone.warning => (Icons.schedule_rounded, const Color(0xFFF6B84A)),
        ToastTone.info => (Icons.info_rounded, const Color(0xFF6EA8FE)),
      };

  @override
  Widget build(BuildContext context) {
    final (icon, accent) = _style;
    final curved = CurvedAnimation(parent: _c, curve: Curves.easeOutCubic, reverseCurve: Curves.easeInCubic);
    const textStyle = TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Colors.white, height: 1.35);

    Widget body = widget.content != null
        // Legacy content: keep its words, but drop the leading icon it drew
        // for itself (the toast has one) and cap its size.
        ? DefaultTextStyle.merge(style: textStyle, child: IconTheme.merge(
            data: const IconThemeData(color: Colors.white, size: 16),
            child: _stripLeadingIcon(widget.content!)))
        : Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            if (widget.title != null) Text(widget.title!, style: textStyle),
            if (widget.detail != null) ...[
              const SizedBox(height: 2),
              Text(widget.detail!, style: TextStyle(fontSize: 12.5, color: Colors.white.withValues(alpha: 0.72), height: 1.35)),
            ],
          ]);

    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween(begin: const Offset(0.06, -0.15), end: Offset.zero).animate(curved),
        child: Semantics(
          liveRegion: true,
          container: true,
          child: Material(
            color: const Color(0xFF1E2724),
            elevation: 0,
            borderRadius: BorderRadius.circular(12),
            clipBehavior: Clip.antiAlias,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 18, offset: Offset(0, 6))],
              ),
              padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(padding: const EdgeInsets.only(top: 1), child: Icon(icon, color: accent, size: 18)),
                const SizedBox(width: 10),
                Expanded(child: Padding(padding: const EdgeInsets.only(top: 1), child: body)),
                if (widget.action != null)
                  TextButton(
                    onPressed: () { widget.action!.onPressed(); widget.onClose(); },
                    style: TextButton.styleFrom(
                      foregroundColor: accent, minimumSize: const Size(0, 28),
                      padding: const EdgeInsets.symmetric(horizontal: 8), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    child: Text(widget.action!.label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ),
                Semantics(
                  button: true,
                  label: 'Dismiss notification',
                  child: InkResponse(
                    onTap: widget.onClose,
                    radius: 16,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.close_rounded, size: 16, color: Colors.white.withValues(alpha: 0.6)),
                    ),
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  // Old snackbars often were Row([Icon, SizedBox, Text]) — show only the text.
  static Widget _stripLeadingIcon(Widget w) {
    if (w is Row && w.children.length >= 2 && w.children.first is Icon) {
      final rest = w.children.skip(1).where((c) => !(c is SizedBox && c.child == null)).toList();
      if (rest.length == 1) {
        final only = rest.first;
        return only is Flexible ? only.child : only;
      }
      return Row(mainAxisSize: MainAxisSize.min, children: rest);
    }
    return w;
  }
}
