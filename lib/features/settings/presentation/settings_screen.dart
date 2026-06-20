import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../main.dart' show themeModeProvider;
import '../../../core/theme/app_theme.dart';

const _brand600 = Color(0xFF0E8C76);
const _brand100 = Color(0xFFD6F3EC);
const _amber100 = Color(0xFFFFF1D6);
const _coral500 = Color(0xFFF2685E);
const _coral100 = Color(0xFFFFE3DF);

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notifDonations    = true;
  bool _notifBirthdays    = true;
  bool _notifAchievements = false;

  void _toast(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w700)),
    backgroundColor: _brand600, behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    duration: const Duration(seconds: 2),
  ));

  @override
  Widget build(BuildContext context) {
    final top      = MediaQuery.of(context).padding.top;
    final isDark   = ref.watch(themeModeProvider) == ThemeMode.dark;
    return Scaffold(
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // header
          Container(color: context.headerBg, padding: EdgeInsets.fromLTRB(18, top + 14, 18, 16),
            child: Row(children: [
              IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20), onPressed: () => context.go('/more'), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
              const SizedBox(width: 10),
              Text('Settings', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: context.textPrimary)),
            ])),

          const SizedBox(height: 16),

          // profile card
          Padding(padding: const EdgeInsets.symmetric(horizontal: 18), child: GestureDetector(
            onTap: () => context.go('/settings/edit-profile'),
            child: Container(padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(22), border: Border.all(color: context.border),
                boxShadow: const [BoxShadow(color: Color(0x080D2822), blurRadius: 6, offset: Offset(0, 2))]),
              child: Row(children: [
                Container(width: 54, height: 54,
                  decoration: const BoxDecoration(gradient: LinearGradient(colors: [Color(0xFF0B6E5D), Color(0xFF14A98C)]), shape: BoxShape.circle),
                  child: const Center(child: Text('FA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 19)))),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Farhan Ansari', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: context.textPrimary)),
                  const SizedBox(height: 2),
                  Text('Admin · kishorreddy992@gmail.com', style: TextStyle(fontSize: 12.5, color: context.textSub, fontWeight: FontWeight.w500)),
                ])),
                Icon(Icons.chevron_right, color: context.textHint, size: 22),
              ]),
            ),
          )),

          const SizedBox(height: 20),

          // Appearance
          _sectionLabel(context, 'Appearance'),
          _SettingsCard(children: [
            _ToggleRow(icon: Icons.dark_mode_outlined, iconBg: context.surface2, iconFg: context.textSub,
              label: 'Dark Mode', sub: isDark ? 'Dark theme active' : 'Light theme active',
              value: isDark, onChanged: (v) {
                ref.read(themeModeProvider.notifier).state = v ? ThemeMode.dark : ThemeMode.light;
                _toast(v ? 'Dark mode on' : 'Light mode on');
              }),
          ]),

          const SizedBox(height: 14),

          // Notifications
          _sectionLabel(context, 'Notifications'),
          _SettingsCard(children: [
            _ToggleRow(icon: Icons.account_balance_wallet_outlined, iconBg: _brand100, iconFg: _brand600,
              label: 'Donations', sub: 'New donations & payment links',
              value: _notifDonations, onChanged: (v) => setState(() => _notifDonations = v)),
            _ToggleRow(icon: Icons.cake_outlined, iconBg: _amber100, iconFg: const Color(0xFFE0921A),
              label: 'Birthdays & Anniversaries', sub: 'Daily celebration reminders',
              value: _notifBirthdays, onChanged: (v) => setState(() => _notifBirthdays = v)),
            _ToggleRow(icon: Icons.emoji_events_outlined, iconBg: const Color(0xFFFFF1D6), iconFg: const Color(0xFFE0921A),
              label: 'Achievements', sub: 'When a student milestone is logged',
              value: _notifAchievements, onChanged: (v) => setState(() => _notifAchievements = v), last: true),
          ]),

          const SizedBox(height: 14),

          // Account
          _sectionLabel(context, 'Account'),
          _SettingsCard(children: [
            _ChevronRow(icon: Icons.person_outline,   iconBg: _brand100,                   iconFg: _brand600,                   label: 'Edit Profile',   onTap: () => context.go('/settings/edit-profile')),
            _ChevronRow(icon: Icons.lock_outline,     iconBg: const Color(0xFFE7E3FD),     iconFg: const Color(0xFF7C6CF0),     label: 'Security & PIN', onTap: () => context.go('/settings/security-pin')),
            _ChevronRow(icon: Icons.devices_outlined, iconBg: const Color(0xFFDCEFFB),     iconFg: const Color(0xFF2D9CDB),     label: 'Linked Devices', sub: '2 devices', last: true, onTap: () => context.go('/settings/linked-devices')),
          ]),

          const SizedBox(height: 14),

          // Administration
          _sectionLabel(context, 'Administration'),
          _SettingsCard(children: [
            _ChevronRow(icon: Icons.admin_panel_settings_outlined, iconBg: _brand100, iconFg: _brand600,
              label: 'Admin Panel', sub: 'Overview, team & system settings',
              onTap: () => context.go('/settings/admin-panel')),
            _ChevronRow(icon: Icons.manage_accounts_outlined, iconBg: const Color(0xFFEDE9FE), iconFg: const Color(0xFF7C6CF0),
              label: 'Manage Roles', sub: 'Staff access & permissions', last: true,
              onTap: () => context.go('/settings/manage-roles')),
          ]),

          const SizedBox(height: 14),

          // Organisation
          _sectionLabel(context, 'Organisation'),
          _SettingsCard(children: [
            _ChevronRow(icon: Icons.business_outlined, iconBg: _brand100, iconFg: _brand600, label: 'Offices',        onTap: () => context.go('/offices')),
            _ChevronRow(icon: Icons.people_outlined,   iconBg: _brand100, iconFg: _brand600, label: 'Team Members',   sub: '5 staff',  onTap: () => context.go('/settings/team-members')),
            _ChevronRow(icon: Icons.category_outlined, iconBg: _brand100, iconFg: _brand600, label: 'Donation Types', last: true,       onTap: () => context.go('/settings/donation-types')),
          ]),

          const SizedBox(height: 14),

          // Data
          _sectionLabel(context, 'Data'),
          _SettingsCard(children: [
            _ChevronRow(icon: Icons.download_outlined,   iconBg: const Color(0xFFDCEFFB), iconFg: const Color(0xFF2D9CDB), label: 'Export Data',   onTap: () => context.go('/settings/export-data')),
            _ChevronRow(icon: Icons.cloud_sync_outlined, iconBg: const Color(0xFFDCEFFB), iconFg: const Color(0xFF2D9CDB), label: 'Backup & Sync', sub: 'Last synced today', onTap: () => context.go('/settings/backup-sync')),
            _ChevronRow(icon: Icons.router_outlined,     iconBg: const Color(0xFFDCEFFB), iconFg: const Color(0xFF2D9CDB), label: 'Server URL',    sub: 'Update backend connection', last: true, onTap: () => context.go('/settings/server-url')),
          ]),

          const SizedBox(height: 14),

          // About
          _sectionLabel(context, 'About'),
          _SettingsCard(children: [
            _ChevronRow(icon: Icons.privacy_tip_outlined, iconBg: context.surface2, iconFg: context.textSub, label: 'Privacy Policy',   onTap: () => context.go('/settings/privacy-policy')),
            _ChevronRow(icon: Icons.gavel_outlined,       iconBg: context.surface2, iconFg: context.textSub, label: 'Terms of Service', onTap: () => context.go('/settings/terms-of-service')),
            _ChevronRow(icon: Icons.info_outline,         iconBg: context.surface2, iconFg: context.textSub, label: 'About Us',         onTap: () => context.go('/settings/about-us')),
            _ChevronRow(icon: Icons.help_outline,         iconBg: context.surface2, iconFg: context.textSub, label: 'Help & Support', last: true, onTap: () => context.go('/help')),
          ]),

          const SizedBox(height: 20),

          // Log out
          Padding(padding: const EdgeInsets.symmetric(horizontal: 18), child: GestureDetector(
            onTap: () => context.go('/login'),
            child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(color: _coral100, borderRadius: BorderRadius.circular(18), border: Border.all(color: _coral500.withValues(alpha: 0.3))),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.logout_rounded, color: _coral500, size: 20),
                SizedBox(width: 10),
                Text('Log Out', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _coral500)),
              ])),
          )),
          const SizedBox(height: 14),
          Center(child: Text('Saksham Foundation · v2.4.0', style: TextStyle(fontSize: 12, color: context.textHint, fontWeight: FontWeight.w600))),
          const SizedBox(height: 96),
        ]),
      ),
    );
  }
}

Widget _sectionLabel(BuildContext ctx, String t) => Padding(padding: const EdgeInsets.fromLTRB(20, 0, 0, 8),
  child: Text(t.toUpperCase(), style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: ctx.textHint, letterSpacing: 0.8)));

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(horizontal: 18),
    child: Container(decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: context.border),
      boxShadow: const [BoxShadow(color: Color(0x080D2822), blurRadius: 6, offset: Offset(0, 2))]),
      child: Column(children: children)));
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({required this.icon, required this.iconBg, required this.iconFg, required this.label,
    required this.sub, required this.value, required this.onChanged, this.last = false});
  final IconData icon; final Color iconBg, iconFg; final String label, sub; final bool value, last; final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
    decoration: last ? null : BoxDecoration(border: Border(bottom: BorderSide(color: context.border))),
    child: Row(children: [
      Container(width: 38, height: 38, decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(11)), child: Icon(icon, color: iconFg, size: 19)),
      const SizedBox(width: 13),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: context.textPrimary)),
        Text(sub, style: TextStyle(fontSize: 12, color: context.textHint, fontWeight: FontWeight.w500)),
      ])),
      Switch(value: value, onChanged: onChanged, activeColor: _brand600),
    ]),
  );
}

class _ChevronRow extends StatelessWidget {
  const _ChevronRow({required this.icon, required this.iconBg, required this.iconFg, required this.label, required this.onTap, this.sub, this.last = false});
  final IconData icon; final Color iconBg, iconFg; final String label; final String? sub; final bool last; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(onTap: onTap, child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
    decoration: last ? null : BoxDecoration(border: Border(bottom: BorderSide(color: context.border))),
    child: Row(children: [
      Container(width: 38, height: 38, decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(11)), child: Icon(icon, color: iconFg, size: 19)),
      const SizedBox(width: 13),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: context.textPrimary)),
        if (sub != null) Text(sub!, style: TextStyle(fontSize: 12, color: context.textHint, fontWeight: FontWeight.w500)),
      ])),
      Icon(Icons.chevron_right, color: context.textHint, size: 20),
    ]),
  ));
}
