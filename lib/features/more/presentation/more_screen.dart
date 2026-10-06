import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/auth/role_auth.dart';
import '../../../core/auth/session.dart';
import '../../notifications/notification_store.dart';
import '../../settings/profile_store.dart';
import 'package:saksham_app/core/ui/ui.dart';

const _brand600 = Color(0xFFFF9933);
const _brand100 = Color(0xFFFFE8CC);
const _amber600 = Color(0xFFE0921A);
const _amber100 = Color(0xFFFFF1D6);
const _coral500 = Color(0xFFF2685E);
const _violet500 = Color(0xFF7C6CF0);
const _sky500 = Color(0xFF2D9CDB);

class MoreScreen extends StatefulWidget {
  const MoreScreen({super.key});
  @override
  State<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends State<MoreScreen> {
  void _openEditProfile() {
    final p = adminProfile.value;
    final nameCtrl = TextEditingController(text: p.name);
    final roleCtrl = TextEditingController(text: p.role);
    final orgCtrl  = TextEditingController(text: p.org);
    showAppSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          decoration: BoxDecoration(color: ctx.cardBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SheetHandle(margin: EdgeInsets.only(bottom: 10)),
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Edit Profile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('Shown on this menu and the sidebar.', style: TextStyle(fontSize: 12.5, color: ctx.textSub)),
              ])),
              IconButton(tooltip: 'Close', icon: Icon(Icons.close_rounded, size: 20, color: ctx.textSub), onPressed: () => Navigator.pop(ctx)),
            ]),
            const SizedBox(height: 16),
            _EditField('Display Name', nameCtrl, Icons.person_outline),
            const SizedBox(height: 12),
            _EditField('Role', roleCtrl, Icons.badge_outlined),
            const SizedBox(height: 12),
            _EditField('Foundation Name', orgCtrl, Icons.business_outlined),
            const SizedBox(height: 18),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              AppButton(label: 'Cancel', variant: AppButtonVariant.secondary, onPressed: () => Navigator.pop(ctx)),
              const SizedBox(width: 8),
              AppButton(
              label: 'Save Changes',
              onPressed: () {
                final newName = nameCtrl.text.trim();
                updateProfile(adminProfile.value.copyWith(
                  name: newName.isEmpty ? null : newName,
                  role: roleCtrl.text.trim().isEmpty ? null : roleCtrl.text.trim(),
                  org:  orgCtrl.text.trim().isEmpty  ? null : orgCtrl.text.trim(),
                ));
                // Persist the name server-side — session restore re-reads it.
                if (newName.isNotEmpty) {
                  apiClient.patch('/users/me/profile', {'name': newName}).catchError((_) => <String, dynamic>{});
                }
                Navigator.pop(ctx);
                AppToast.success(context, 'Profile updated');
              },
            ),
            ]),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── top bar ───────────────────────────────────────────────
          Container(
            color: context.headerBg,
            padding: EdgeInsets.fromLTRB(18, top + 14, 18, 16),
            child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('More', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                const SizedBox(height: 2),
                Text('Management · Insights · Account', style: TextStyle(fontSize: 13, color: context.textSub, fontWeight: FontWeight.w600)),
              ])),
            ]),
          ),

          // ── profile card ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
            child: ValueListenableBuilder<ProfileData>(
              valueListenable: adminProfile,
              builder: (context, p, _) {
                // Role members see THEIR OWN identity here — this card used to
                // always show the admin/org profile ("Super Admin") to everyone.
                final member = currentLoggedInRole;
                final cardName = member?.name ?? p.name;
                final cardSub = member != null
                    ? (member.roleName.isNotEmpty ? member.roleName : 'Team Member')
                    : '${p.role} · ${p.org}';
                final photo = member == null ? p.photoBytes : null;
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFFE07C1F), Color(0xFFFFB25E)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: const [BoxShadow(color: Color(0x400B6E5D), blurRadius: 16, offset: Offset(0, 6))],
                  ),
                  child: Row(children: [
                    Container(width: 52, height: 52,
                      clipBehavior: Clip.hardEdge,
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: photo != null
                        ? Image.memory(photo, fit: BoxFit.cover, width: 52, height: 52)
                        : member != null
                          ? Center(child: Text(
                              cardName.isNotEmpty ? cardName.trim().split(RegExp(r'\s+')).map((w) => w[0]).take(2).join().toUpperCase() : '?',
                              style: const TextStyle(color: _brand600, fontWeight: FontWeight.w800, fontSize: 18)))
                          : Image.asset(brandLogoAsset, fit: BoxFit.cover, alignment: Alignment.centerLeft, width: 52, height: 52)),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(cardName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
                      const SizedBox(height: 3),
                      Text(cardSub, style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                    ])),
                    Tooltip(message: 'Edit profile', child: GestureDetector(
                      // Members edit their own profile (My Profile screen);
                      // only the admin edits the org/admin profile here.
                      onTap: member == null ? _openEditProfile : () => context.go('/settings'),
                      child: Container(width: 36, height: 36,
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.edit_outlined, color: Colors.white, size: 17)),
                    )),
                  ]),
                );
              },
            ),
          ),

          const SizedBox(height: 20),
          // ── Management (role-filtered like the sidebar) ────────────
          // Expenses & Approvals lived only in the desktop sidebar — on
          // phones (the APK) this menu is the ONLY way to reach them.
          if ([canAccess('offices'), canAccess('payments'), canAccess('reminders'), canAccess('expenses'), canAccess('approvals'), canAccess('staff')].any((v) => v))
            _GroupSection(title: 'Management', items: [
              if (canAccess('staff'))
                _MenuItem(icon: Icons.badge_outlined,         iconBg: const Color(0xFFDCEFFB), iconFg: _sky500,    label: 'Staff',             sub: 'Employees & salary details', route: '/staff'),
              if (canAccess('expenses'))
                _MenuItem(icon: Icons.payments_outlined,      iconBg: const Color(0xFFFFE3DF), iconFg: _coral500, label: 'Expenses',          sub: 'Vouchers & spending',    route: '/expenses'),
              if (canAccess('approvals'))
                _MenuItem(icon: Icons.fact_check_outlined,    iconBg: _amber100,  iconFg: _amber600,  label: 'Approvals',         sub: 'Review pending requests', route: '/approvals'),
              if (canAccess('offices'))
                _MenuItem(icon: Icons.business_outlined,     iconBg: _brand100,  iconFg: _brand600,  label: 'Office Management', sub: 'Locations & teams',  route: '/offices'),
              if (canAccess('payments'))
                _MenuItem(icon: Icons.link_rounded,           iconBg: const Color(0xFFE7E3FD), iconFg: _violet500, label: 'Payment Links',     sub: 'Generate & track links', route: '/payment-links'),
              if (canAccess('reminders'))
                _MenuItem(icon: Icons.cake_outlined,          iconBg: _amber100,  iconFg: _amber600,  label: 'Reminders',         sub: 'Birthdays & follow-ups', route: '/reminders'),
            ]),
          const SizedBox(height: 14),
          // ── Insights ──────────────────────────────────────────────
          if ([canAccess('tracker'), canAccess('reports'), canAccess('achievements')].any((v) => v))
            _GroupSection(title: 'Insights', items: [
              if (canAccess('tracker'))
                _MenuItem(icon: Icons.track_changes_outlined, iconBg: _brand100,  iconFg: _brand600,  label: 'Donation Tracker',  sub: 'Track & follow up',      route: '/donation-tracker'),
              if (canAccess('reports'))
                _MenuItem(icon: Icons.bar_chart_rounded,      iconBg: const Color(0xFFDCEFFB), iconFg: _sky500,    label: 'Reports & Analytics', sub: 'Impact overview',        route: '/reports'),
              if (canAccess('achievements'))
                _MenuItem(icon: Icons.emoji_events_outlined,  iconBg: _amber100,  iconFg: _amber600,  label: 'Student Achievements', sub: 'Milestones & awards',  route: '/achievements'),
            ]),
          const SizedBox(height: 14),
          // ── Account ───────────────────────────────────────────────
          _GroupSection(title: 'Account', items: [
            _MenuItem(icon: Icons.notifications_outlined, iconBg: const Color(0xFFFFE3DF), iconFg: _coral500,  label: 'Notifications',     sub: 'Tap to view',            route: '/notifications'),
            if (canAccess('settings'))
              _MenuItem(icon: Icons.location_city_outlined, iconBg: const Color(0xFFE7E3FD), iconFg: _violet500, label: 'Centre',            sub: 'Manage centres',         route: '/centres'),
            if (canAccess('settings'))
              _MenuItem(icon: Icons.settings_outlined,      iconBg: const Color(0xFFE7EDEB), iconFg: const Color(0xFF5A6B67), label: 'Settings',          sub: 'App & account',          route: '/settings'),
            _MenuItem(icon: Icons.help_outline_rounded,   iconBg: const Color(0xFFDCEFFB), iconFg: _sky500,    label: 'Help & Support',    sub: 'Guides & contact',       route: '/help'),
          ]),

          const SizedBox(height: 20),
          // ── Log Out ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Semantics(button: true, label: 'Log out', child: GestureDetector(
              onTap: () async { await logoutSession(); if (context.mounted) context.go('/login'); },
              child: Container(
                width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(color: const Color(0xFFFFE3DF), borderRadius: BorderRadius.circular(18), border: Border.all(color: _coral500.withValues(alpha: 0.3))),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.logout_rounded, color: _coral500, size: 20),
                  SizedBox(width: 10),
                  Text('Log Out', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _coral500)),
                ]),
              ),
            )),
          ),

          const SizedBox(height: 16),
          Center(child: Text('Sri Krishnashraya Educational Trust · v2.4.0', style: TextStyle(fontSize: 12, color: context.textHint, fontWeight: FontWeight.w600))),
          const SizedBox(height: 96),
        ]),
      ),
    );
  }
}

class _GroupSection extends StatelessWidget {
  const _GroupSection({required this.title, required this.items});
  final String title;
  final List<_MenuItem> items;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 18),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(padding: const EdgeInsets.only(left: 2, bottom: 8),
        child: Text(title.toUpperCase(), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: context.textHint, letterSpacing: 0.8))),
      Container(
        decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: context.border),
          boxShadow: const [BoxShadow(color: Color(0x080D2822), blurRadius: 6, offset: Offset(0, 2))]),
        child: Column(children: items.asMap().entries.map((e) {
          final isLast = e.key == items.length - 1;
          return _MenuRow(item: e.value, showDivider: !isLast);
        }).toList()),
      ),
    ]),
  );
}

class _MenuItem {
  const _MenuItem({required this.icon, required this.iconBg, required this.iconFg, required this.label, required this.sub, required this.route, this.badge});
  final IconData icon;
  final Color iconBg, iconFg;
  final String label, sub, route;
  final String? badge;
}

class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.item, required this.showDivider});
  final _MenuItem item;
  final bool showDivider;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => context.go(item.route),
    behavior: HitTestBehavior.opaque,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: showDivider ? BoxDecoration(border: Border(bottom: BorderSide(color: context.border))) : null,
      child: Row(children: [
        Container(width: 40, height: 40, decoration: BoxDecoration(color: item.iconBg, borderRadius: BorderRadius.circular(12)),
          child: Icon(item.icon, color: item.iconFg, size: 20)),
        const SizedBox(width: 13),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(item.label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.textPrimary)),
          Text(item.sub, style: TextStyle(fontSize: 12.5, color: context.textSub, fontWeight: FontWeight.w500)),
        ])),
        if (item.route == '/notifications')
          ValueListenableBuilder<int>(
            valueListenable: unreadNotifCount,
            builder: (_, count, __) => count == 0 ? const SizedBox.shrink() : Container(
              margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: _coral500, borderRadius: BorderRadius.circular(8)),
              child: Text('$count', style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800))),
          )
        else if (item.badge != null)
          Container(margin: const EdgeInsets.only(right: 8), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: _coral500, borderRadius: BorderRadius.circular(8)),
            child: Text(item.badge!, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800))),
        Icon(Icons.chevron_right, color: context.textHint, size: 20),
      ]),
    ),
  );
}

class _EditField extends StatelessWidget {
  const _EditField(this.label, this.ctrl, this.icon);
  final String label;
  final TextEditingController ctrl;
  final IconData icon;
  @override
  Widget build(BuildContext context) => TextField(
    controller: ctrl,
    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
    decoration: InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: context.textSub, fontWeight: FontWeight.w600),
      prefixIcon: Icon(icon, color: _brand600, size: 20),
      filled: true, fillColor: context.surface2,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _brand600, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
  );
}
