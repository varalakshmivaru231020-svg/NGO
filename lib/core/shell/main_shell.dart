import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';
import '../../core/auth/role_auth.dart';

const _brand600 = Color(0xFF0E8C76);
const _coral500 = Color(0xFFF2685E);

// ── nav item descriptor ───────────────────────────────────────────────
class _N {
  const _N(this.icon, this.filled, this.label, this.route, {this.badge, this.module});
  final IconData icon, filled;
  final String label, route;
  final int? badge;
  final String? module; // null = always visible
  bool active(String loc) =>
      route == '/dashboard' ? (loc == '/dashboard' || loc == '/') : loc.startsWith(route);
  bool visible() => module == null || canAccess(module!);
}

// ── section descriptors ───────────────────────────────────────────────
const _main = [
  _N(Icons.dashboard_outlined,         Icons.dashboard,           'Dashboard',       '/dashboard'),
  _N(Icons.people_outlined,            Icons.people,              'Donors',          '/donors',           module: 'donors'),
  _N(Icons.receipt_long_outlined,      Icons.receipt_long,        'Donations',       '/donations',        module: 'donations'),
  _N(Icons.school_outlined,            Icons.school,              'Students',        '/students',         module: 'students'),
];

const _mgmt = [
  _N(Icons.business_outlined,          Icons.business,            'Offices',         '/offices',          module: 'offices'),
  _N(Icons.link_rounded,               Icons.link,                'Payment Links',   '/payment-links',    module: 'payments'),
  _N(Icons.cake_outlined,              Icons.cake,                'Reminders',       '/reminders',        module: 'reminders'),
  _N(Icons.track_changes_outlined,     Icons.track_changes,       'Donation Tracker','/donation-tracker', module: 'tracker'),
  _N(Icons.bar_chart_rounded,          Icons.bar_chart_rounded,   'Reports',         '/reports',          module: 'reports'),
  _N(Icons.emoji_events_outlined,      Icons.emoji_events,        'Achievements',    '/achievements',     module: 'achievements'),
];

const _acct = [
  _N(Icons.notifications_outlined,     Icons.notifications,       'Notifications',   '/notifications',    badge: 3),
  _N(Icons.manage_accounts_outlined,   Icons.manage_accounts,     'Roles',           '/roles'),
  _N(Icons.settings_outlined,          Icons.settings,            'Settings',        '/settings'),
  _N(Icons.help_outline_rounded,       Icons.help_rounded,        'Help',            '/help'),
];

// ── bottom tab bar (mobile only) ──────────────────────────────────────
const _tabs = [
  _N(Icons.dashboard_outlined,    Icons.dashboard,         'Home',      '/dashboard'),
  _N(Icons.people_outlined,       Icons.people,            'Donors',    '/donors'),
  _N(Icons.receipt_long_outlined, Icons.receipt_long,      'Donations', '/donations'),
  _N(Icons.school_outlined,       Icons.school,            'Students',  '/students'),
  _N(Icons.grid_view_outlined,    Icons.grid_view_rounded, 'More',      '/more'),
];

int _tabIdx(String loc) {
  if (loc.startsWith('/donors'))    return 1;
  if (loc.startsWith('/donations')) return 2;
  if (loc.startsWith('/students'))  return 3;
  if (loc.startsWith('/more') || loc == '/offices' || loc == '/payment-links' ||
      loc == '/reminders' || loc == '/notifications' || loc == '/donation-tracker' ||
      loc == '/reports' || loc == '/achievements' || loc == '/settings' || loc == '/help') return 4;
  return 0;
}

// ══════════════════════════════════════════════════════════════════════
// SHELL
// ══════════════════════════════════════════════════════════════════════
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final loc   = GoRouterState.of(context).matchedLocation;
    final width = MediaQuery.of(context).size.width;

    if (width >= 700) {
      return Scaffold(
        body: Row(children: [
          _Sidebar(loc: loc, extended: width >= 1060),
          Expanded(child: child),
        ]),
      );
    }

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: context.cardBg,
          border: Border(top: BorderSide(color: context.border)),
        ),
        child: NavigationBar(
          selectedIndex: _tabIdx(loc),
          backgroundColor: context.cardBg,
          elevation: 0,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          onDestinationSelected: (i) {
            const routes = ['/dashboard','/donors','/donations','/students','/more'];
            context.go(routes[i]);
          },
          destinations: _tabs.map((t) => NavigationDestination(
            icon: Icon(t.icon), selectedIcon: Icon(t.filled), label: t.label,
          )).toList(),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
// SIDEBAR
// ══════════════════════════════════════════════════════════════════════
class _Sidebar extends StatelessWidget {
  const _Sidebar({required this.loc, required this.extended});
  final String loc;
  final bool extended;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: extended ? 224 : 68,
      decoration: BoxDecoration(
        color: context.cardBg,
        border: Border(right: BorderSide(color: context.border)),
      ),
      child: Column(children: [
        // ── logo ────────────────────────────────────────────────
        SafeArea(bottom: false, child: _Logo(extended: extended)),
        Divider(height: 1, color: context.border),
        // ── nav items ───────────────────────────────────────────
        Expanded(child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            ..._main.where((n) => n.visible()).map((n) => _NavRow(n: n, loc: loc, ext: extended)),
            if (_mgmt.any((n) => n.visible())) ...[
              _Divider(label: 'Management', ext: extended),
              ..._mgmt.where((n) => n.visible()).map((n) => _NavRow(n: n, loc: loc, ext: extended)),
            ],
            _Divider(label: 'Account', ext: extended),
            // Roles option only for admin
            ..._acct.where((n) => n.route != '/roles' || isAdmin).map((n) => _NavRow(n: n, loc: loc, ext: extended)),
          ]),
        )),
        // ── profile footer ──────────────────────────────────────
        Divider(height: 1, color: context.border),
        _Footer(extended: extended),
      ]),
    );
  }
}

// ── Logo ──────────────────────────────────────────────────────────────
class _Logo extends StatelessWidget {
  const _Logo({required this.extended});
  final bool extended;
  static const _avatar = BoxDecoration(
    gradient: LinearGradient(colors: [Color(0xFF0B6E5D), Color(0xFF14A98C)]),
    shape: BoxShape.circle,
  );
  @override
  Widget build(BuildContext context) {
    final icon = Container(
      width: 36, height: 36, decoration: _avatar,
      child: const Icon(Icons.volunteer_activism, size: 19, color: Colors.white),
    );
    if (!extended) {
      return Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Center(child: icon));
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Row(children: [
        icon, const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Saksham', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900,
              letterSpacing: -0.4, color: context.textPrimary)),
          Text('Foundation', style: TextStyle(fontSize: 10, color: context.textSub, fontWeight: FontWeight.w600)),
        ]),
      ]),
    );
  }
}

// ── Section divider / label ───────────────────────────────────────────
class _Divider extends StatelessWidget {
  const _Divider({required this.label, required this.ext});
  final String label;
  final bool ext;
  @override
  Widget build(BuildContext context) {
    if (!ext) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Center(child: Container(
          width: 22, height: 1,
          decoration: BoxDecoration(
            color: context.border,
            borderRadius: BorderRadius.circular(1),
          ),
        )),
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 3),
      child: Text(label.toUpperCase(),
        style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w900,
            color: context.textHint, letterSpacing: 1.0)),
    );
  }
}

// ── Single nav row ────────────────────────────────────────────────────
class _NavRow extends StatelessWidget {
  const _NavRow({required this.n, required this.loc, required this.ext});
  final _N n;
  final String loc;
  final bool ext;
  @override
  Widget build(BuildContext context) {
    final active = n.active(loc);
    return GestureDetector(
      onTap: () => context.go(n.route),
      behavior: HitTestBehavior.opaque,
      child: Stack(clipBehavior: Clip.none, children: [
        if (active)
          Positioned(
            left: 0, top: 4, bottom: 4,
            child: Container(
              width: 3,
              decoration: BoxDecoration(
                color: _brand600,
                borderRadius: const BorderRadius.only(topRight: Radius.circular(3), bottomRight: Radius.circular(3)),
              ),
            ),
          ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
          padding: ext
              ? const EdgeInsets.symmetric(horizontal: 10, vertical: 9)
              : const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? _brand600.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: ext
              ? Row(children: [
                  Icon(active ? n.filled : n.icon,
                      color: active ? _brand600 : context.textSub, size: 19),
                  const SizedBox(width: 10),
                  Expanded(child: Text(n.label,
                      style: TextStyle(fontSize: 13, fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                          color: active ? _brand600 : context.textPrimary),
                      overflow: TextOverflow.ellipsis)),
                  if (n.badge != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(color: _coral500, borderRadius: BorderRadius.circular(8)),
                      child: Text('${n.badge}',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900))),
                ])
              : Center(
                  child: Stack(clipBehavior: Clip.none, children: [
                    Icon(active ? n.filled : n.icon,
                        color: active ? _brand600 : context.textSub, size: 22),
                    if (n.badge != null)
                      Positioned(
                        right: -5, top: -3,
                        child: Container(
                          width: 15, height: 15,
                          decoration: const BoxDecoration(color: _coral500, shape: BoxShape.circle),
                          child: Center(child: Text('${n.badge}',
                              style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.w900))))),
                  ]),
                ),
        ),
      ]),
    );
  }
}

// ── Profile footer ────────────────────────────────────────────────────
class _Footer extends StatelessWidget {
  const _Footer({required this.extended});
  final bool extended;
  static const _grad = BoxDecoration(
    gradient: LinearGradient(colors: [Color(0xFF0B6E5D), Color(0xFF14A98C)]),
    shape: BoxShape.circle,
  );
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.all(9),
        child: GestureDetector(
          onTap: () => context.go('/settings'),
          child: extended
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                  decoration: BoxDecoration(
                    color: context.surface2,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    Container(width: 32, height: 32, decoration: _grad,
                        child: Center(child: Text(
                          isAdmin ? 'FA' : (currentLoggedInRole?.name.trim().split(' ').where((w) => w.isNotEmpty).map((w) => w[0].toUpperCase()).take(2).join() ?? 'U'),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11)))),
                    const SizedBox(width: 9),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(isAdmin ? 'Farhan Ansari' : (currentLoggedInRole?.name ?? 'User'),
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: context.textPrimary), overflow: TextOverflow.ellipsis),
                      Text(isAdmin ? 'Administrator' : 'Role Member',
                          style: TextStyle(fontSize: 10.5, color: context.textSub, fontWeight: FontWeight.w500)),
                    ])),
                    Icon(Icons.settings_outlined, size: 15, color: context.textSub),
                  ]),
                )
              : Container(
                  width: 38, height: 38, decoration: _grad,
                  child: Center(child: Text(
                    isAdmin ? 'FA' : (currentLoggedInRole?.name.trim().split(' ').where((w) => w.isNotEmpty).map((w) => w[0].toUpperCase()).take(2).join() ?? 'U'),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11)))),
        ),
      ),
    );
  }
}
