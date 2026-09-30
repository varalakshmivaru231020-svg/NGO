import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../notification_store.dart';
import 'package:saksham_app/core/ui/ui.dart';


// ══════════════════════════════════════════════════════════════════════
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final List<AppNotif> _notifs = appNotifications;

  int get _unreadCount => _notifs.where((n) => n.unread).length;

  void _markAllRead() {
    setState(markAllNotifsRead);
    AppToast.success(context, 'All notifications marked as read');
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final groups = ['Today', 'Earlier'];

    return Scaffold(
      body: Column(children: [
        Container(
          color: context.headerBg,
          padding: EdgeInsets.fromLTRB(8, top + 10, 14, 10),
          child: Row(children: [
            IconButton(tooltip: 'Back', icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18), onPressed: () => context.go('/more')),
            const SizedBox(width: 2),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Notifications', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.2, color: context.textPrimary)),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: Text(_unreadCount == 0 ? 'All caught up' : '$_unreadCount unread', key: ValueKey(_unreadCount),
                    style: TextStyle(fontSize: 12.5, color: context.textSub, fontWeight: FontWeight.w500)),
              ),
            ])),
            if (_unreadCount > 0)
              AppButton(label: 'Mark all read', icon: Icons.done_all_rounded, variant: AppButtonVariant.ghost, dense: true, onPressed: _markAllRead),
          ]),
        ),
        if (_notifs.isEmpty)
          const Expanded(child: Center(child: EmptyStateLike(
            icon: Icons.notifications_none_rounded,
            title: 'No notifications yet',
            message: 'Updates about donations, approvals and reminders will appear here.',
          )))
        else
        Expanded(child: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(),
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(0, 12, 0, 24),
            children: groups.expand((g) {
              final items = _notifs.where((n) => n.group == g).toList();
              if (items.isEmpty) return <Widget>[];
              return [
                Padding(padding: const EdgeInsets.fromLTRB(18, 6, 18, 8),
                  child: Text(g, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: context.textHint, letterSpacing: 0.5))),
                ...items.map((n) => _NotifCard(notif: n, onTap: () => setState(() => markNotifRead(n)))),
                const SizedBox(height: 8),
              ];
            }).toList(),
          ),
        ))),
      ]),
    );
  }
}

class _NotifCard extends StatelessWidget {
  const _NotifCard({required this.notif, required this.onTap});
  final AppNotif notif;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: notif.unread,
    label: notif.unread ? 'Unread: ${notif.title}. Tap to mark as read' : notif.title,
    child: GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.fromLTRB(18, 0, 18, 8),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: notif.unread ? notif.tint.withValues(alpha: 0.35) : context.border),
        boxShadow: const [BoxShadow(color: Color(0x080D2822), blurRadius: 4, offset: Offset(0, 1))],
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // left accent
        Container(width: 4, decoration: BoxDecoration(
          color: notif.unread ? notif.tint : Colors.transparent,
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(18), bottomLeft: Radius.circular(18)),
        )),
        Expanded(child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 14, 14, 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(color: notif.tintBg, borderRadius: BorderRadius.circular(13)),
              child: Icon(notifIconData(notif.icon), color: notif.tint, size: 22)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(notif.title, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, height: 1, color: context.textPrimary))),
                if (notif.unread)
                  Container(width: 8, height: 8, decoration: BoxDecoration(color: notif.tint, shape: BoxShape.circle)),
              ]),
              const SizedBox(height: 4),
              Text(notif.body, style: TextStyle(fontSize: 13, color: context.textSub, fontWeight: FontWeight.w500, height: 1.4)),
              const SizedBox(height: 6),
              Text(notif.time, style: TextStyle(fontSize: 11.5, color: context.textHint, fontWeight: FontWeight.w600)),
            ])),
          ]),
        )),
      ]),
    ),
  ));
}
