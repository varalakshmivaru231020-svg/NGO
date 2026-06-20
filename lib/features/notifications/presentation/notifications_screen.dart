import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

const _brand600 = Color(0xFF0E8C76);
const _brand100 = Color(0xFFD6F3EC);
const _amber600 = Color(0xFFE0921A);
const _amber100 = Color(0xFFFFF1D6);
const _coral500 = Color(0xFFF2685E);
const _coral100 = Color(0xFFFFE3DF);
const _violet500 = Color(0xFF7C6CF0);
const _violet100 = Color(0xFFE7E3FD);
const _sky500 = Color(0xFF2D9CDB);
const _sky100 = Color(0xFFDCEFFB);

class _Notif {
  _Notif({required this.id, required this.icon, required this.tint, required this.tintBg,
    required this.title, required this.body, required this.time, required this.group, this.unread = false});
  final String id, icon, title, body, time, group;
  final Color tint, tintBg;
  bool unread;
}

final _notifications = [
  _Notif(id:'nt1', icon:'wallet', tint:_brand600, tintBg:_brand100, title:'Donation received',       body:'Meera Iyer donated ₹15,000 via Payment Link.',       time:'12 min ago', unread:true,  group:'Today'),
  _Notif(id:'nt2', icon:'cake',   tint:_amber600, tintBg:_amber100, title:'2 birthdays today',       body:'Anita Desai (Donor) & Diya Reddy (Student).',        time:'1 hr ago',   unread:true,  group:'Today'),
  _Notif(id:'nt3', icon:'rings',  tint:_coral500, tintBg:_coral100, title:'Anniversary reminder',    body:"Vikram Singh's 20th anniversary is today.",          time:'1 hr ago',   unread:true,  group:'Today'),
  _Notif(id:'nt4', icon:'link',   tint:_violet500, tintBg:_violet100, title:'Payment link viewed',   body:'Kavya Reddy opened the Food Drive link.',            time:'3 hr ago',   unread:false, group:'Today'),
  _Notif(id:'nt5', icon:'trophy', tint:_amber600, tintBg:_amber100, title:'New achievement logged',  body:'Imran Qureshi won Gold at District Athletics.',      time:'Yesterday',  unread:false, group:'Earlier'),
  _Notif(id:'nt6', icon:'doc',    tint:_sky500,   tintBg:_sky100,   title:'80G receipts ready',     body:'Q1 FY26-27 receipts generated for 38 donors.',       time:'2 days ago', unread:false, group:'Earlier'),
];

IconData _iconData(String key) => switch (key) {
  'wallet' => Icons.account_balance_wallet_outlined,
  'cake'   => Icons.cake_outlined,
  'rings'  => Icons.favorite_border,
  'link'   => Icons.link_rounded,
  'trophy' => Icons.emoji_events_outlined,
  'doc'    => Icons.description_outlined,
  _        => Icons.notifications_outlined,
};

// ══════════════════════════════════════════════════════════════════════
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final List<_Notif> _notifs = _notifications;

  int get _unreadCount => _notifs.where((n) => n.unread).length;

  void _markAllRead() => setState(() { for (final n in _notifs) { n.unread = false; } });

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final groups = ['Today', 'Earlier'];

    return Scaffold(
      body: Column(children: [
        Container(
          color: context.headerBg,
          padding: EdgeInsets.fromLTRB(18, top + 14, 14, 16),
          child: Row(children: [
            IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20), onPressed: () => context.go('/more'), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Notifications', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: context.textPrimary)),
              Text('$_unreadCount unread', style: TextStyle(fontSize: 13, color: context.textSub, fontWeight: FontWeight.w600)),
            ])),
            if (_unreadCount > 0)
              TextButton(
                onPressed: _markAllRead,
                style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                child: const Text('Mark all read', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _brand600)),
              ),
          ]),
        ),
        Expanded(child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(0, 12, 0, 100),
          children: groups.expand((g) {
            final items = _notifs.where((n) => n.group == g).toList();
            if (items.isEmpty) return <Widget>[];
            return [
              Padding(padding: const EdgeInsets.fromLTRB(18, 6, 18, 8),
                child: Text(g, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: context.textHint, letterSpacing: 0.5))),
              ...items.map((n) => _NotifCard(notif: n, onTap: () => setState(() => n.unread = false))),
              const SizedBox(height: 8),
            ];
          }).toList(),
        )),
      ]),
    );
  }
}

class _NotifCard extends StatelessWidget {
  const _NotifCard({required this.notif, required this.onTap});
  final _Notif notif;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
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
              child: Icon(_iconData(notif.icon), color: notif.tint, size: 22)),
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
  );
}
