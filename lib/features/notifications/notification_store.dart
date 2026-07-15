import 'package:flutter/material.dart';

// ── palette (matches the rest of the app) ─────────────────────────────
const _brand600  = Color(0xFFFF9933);
const _brand100  = Color(0xFFFFE8CC);
const _amber600  = Color(0xFFE0921A);
const _amber100  = Color(0xFFFFF1D6);
const _coral500  = Color(0xFFF2685E);
const _coral100  = Color(0xFFFFE3DF);
const _violet500 = Color(0xFF7C6CF0);
const _violet100 = Color(0xFFE7E3FD);
const _sky500    = Color(0xFF2D9CDB);
const _sky100    = Color(0xFFDCEFFB);

class AppNotif {
  AppNotif({
    required this.id, required this.icon, required this.tint, required this.tintBg,
    required this.title, required this.body, required this.time, required this.group,
    this.unread = false,
  });
  final String id, icon, title, body, time, group;
  final Color tint, tintBg;
  bool unread;
}

// Shared, app-wide notification list. The sidebar & More screen read the live
// unread count from [unreadNotifCount] so the badge updates as soon as items
// are read.
final appNotifications = <AppNotif>[];

int _countUnread() => appNotifications.where((n) => n.unread).length;

// Live unread count — listen to this to keep badges in sync.
final unreadNotifCount = ValueNotifier<int>(_countUnread());

void refreshUnreadCount() => unreadNotifCount.value = _countUnread();

void markNotifRead(AppNotif n) {
  if (n.unread) { n.unread = false; refreshUnreadCount(); }
}

void markAllNotifsRead() {
  for (final n in appNotifications) { n.unread = false; }
  refreshUnreadCount();
}

IconData notifIconData(String key) => switch (key) {
  'wallet' => Icons.account_balance_wallet_outlined,
  'cake'   => Icons.cake_outlined,
  'rings'  => Icons.favorite_border,
  'link'   => Icons.link_rounded,
  'trophy' => Icons.emoji_events_outlined,
  'doc'    => Icons.description_outlined,
  _        => Icons.notifications_outlined,
};
