import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../main.dart' show themeModeProvider;
import '../../../core/theme/app_theme.dart';

const _brand600 = Color(0xFF0E8C76);
const _coral500 = Color(0xFFF2685E);
const _coral100 = Color(0xFFFFE3DF);

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  bool _notifDonations    = true;
  bool _notifBirthdays    = true;
  bool _notifAnniversary  = true;
  bool _notifNewDonor     = false;
  bool _notifStudent      = false;
  bool _notifAchievements = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  void _toast(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w700)),
    backgroundColor: _brand600, behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    duration: const Duration(seconds: 2),
  ));

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      body: Column(children: [
        // ── Header ───────────────────────────────────────────────
        Container(
          color: context.headerBg,
          padding: EdgeInsets.fromLTRB(18, top + 14, 18, 16),
          child: Row(children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: () => context.go('/more'),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 10),
            Text('Settings', style: TextStyle(
              fontSize: 22, fontWeight: FontWeight.w800,
              letterSpacing: -0.3, color: context.textPrimary)),
          ]),
        ),

        // ── Tab Bar ──────────────────────────────────────────────
        Container(
          color: context.headerBg,
          child: TabBar(
            controller: _tabCtrl,
            isScrollable: true,
            indicatorColor: const Color(0xFF0E8C76),
            indicatorWeight: 2.5,
            labelColor: const Color(0xFF0E8C76),
            unselectedLabelColor: const Color(0xFF93A29F),
            labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            tabs: const [
              Tab(text: '🏢  Organization'),
              Tab(text: '👤  Profile'),
              Tab(text: '🔒  Security'),
              Tab(text: '🎨  Branding'),
              Tab(text: '🔔  Notifications'),
            ],
          ),
        ),

        // ── Tab Views ─────────────────────────────────────────────
        Expanded(child: TabBarView(
          controller: _tabCtrl,
          children: [
            _orgTab(),
            _profileTab(),
            _securityTab(),
            _brandingTab(),
            _notificationsTab(),
          ],
        )),
      ]),
    );
  }

  // ── Tab: Organization ──────────────────────────────────────────
  Widget _orgTab() => SingleChildScrollView(
    physics: const BouncingScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(18, 16, 18, 40),
    child: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 700),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _settingsSection('Organization Details', [
          _settingsItem(Icons.business_outlined, 'Organization Name', 'Saksham Foundation', onTap: () {}),
          _settingsItem(Icons.language_outlined, 'Website', 'www.saksham.org', onTap: () {}),
          _settingsItem(Icons.location_on_outlined, 'Address', 'Mumbai, Maharashtra', onTap: () {}),
          _settingsItem(Icons.phone_outlined, 'Contact Number', '+91 98765 43210', onTap: () {}),
        ]),
        const SizedBox(height: 16),
        _settingsSection('Registration', [
          _settingsItem(Icons.article_outlined, 'Registration Number', 'NGO-2019-MH-00123', onTap: () {}),
          _settingsItem(Icons.account_balance_outlined, 'PAN / Tax ID', 'AABCS1234D', onTap: () {}),
          _settingsItem(Icons.verified_outlined, 'FCRA Status', 'Active', onTap: () {}),
        ]),
        const SizedBox(height: 16),
        _settingsSection('Administration', [
          _settingsItem(Icons.admin_panel_settings_outlined, 'Admin Panel', 'Overview, team & system settings',
            onTap: () => context.go('/settings/admin-panel')),
          _settingsItem(Icons.manage_accounts_outlined, 'Manage Roles', 'Staff access & permissions',
            onTap: () => context.go('/settings/manage-roles')),
          _settingsItem(Icons.people_outlined, 'Team Members', '5 staff',
            onTap: () => context.go('/settings/team-members')),
          _settingsItem(Icons.category_outlined, 'Donation Types', 'Manage categories',
            onTap: () => context.go('/settings/donation-types')),
          _settingsItem(Icons.business_outlined, 'Offices', 'Manage office locations',
            onTap: () => context.go('/offices')),
        ]),
        const SizedBox(height: 16),
        _settingsSection('Data', [
          _settingsItem(Icons.download_outlined, 'Export Data', 'Download reports & records',
            onTap: () => context.go('/settings/export-data')),
          _settingsItem(Icons.cloud_sync_outlined, 'Backup & Sync', 'Last synced today',
            onTap: () => context.go('/settings/backup-sync')),
          _settingsItem(Icons.router_outlined, 'Server URL', 'Update backend connection',
            onTap: () => context.go('/settings/server-url')),
        ]),
        const SizedBox(height: 16),
        _settingsSection('About', [
          _settingsItem(Icons.privacy_tip_outlined, 'Privacy Policy', 'View our privacy policy',
            onTap: () => context.go('/settings/privacy-policy')),
          _settingsItem(Icons.gavel_outlined, 'Terms of Service', 'View terms of service',
            onTap: () => context.go('/settings/terms-of-service')),
          _settingsItem(Icons.info_outline, 'About Us', 'Learn about Saksham Foundation',
            onTap: () => context.go('/settings/about-us')),
          _settingsItem(Icons.help_outline, 'Help & Support', 'FAQs and contact',
            onTap: () => context.go('/help')),
        ]),
        const SizedBox(height: 20),
        // Log out button
        GestureDetector(
          onTap: () => context.go('/login'),
          child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(color: _coral100, borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _coral500.withValues(alpha: 0.3))),
            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.logout_rounded, color: _coral500, size: 20),
              SizedBox(width: 10),
              Text('Log Out', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _coral500)),
            ])),
        ),
        const SizedBox(height: 14),
        Center(child: Text('Saksham Foundation · v2.4.0',
          style: TextStyle(fontSize: 12, color: context.textHint, fontWeight: FontWeight.w600))),
      ]),
    )),
  );

  // ── Tab: Profile ───────────────────────────────────────────────
  Widget _profileTab() => SingleChildScrollView(
    physics: const BouncingScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(18, 16, 18, 40),
    child: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 700),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 8),
        Center(child: Column(children: [
          CircleAvatar(
            radius: 44,
            backgroundColor: const Color(0xFF0E8C76),
            child: const Text('FA', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => context.go('/settings/edit-profile'),
            child: const Text('Change Photo',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF0E8C76))),
          ),
        ])),
        const SizedBox(height: 20),
        _settingsSection('Personal Information', [
          _settingsItem(Icons.person_outline, 'Full Name', 'Farhan Ansari',
            onTap: () => context.go('/settings/edit-profile')),
          _settingsItem(Icons.email_outlined, 'Email', 'admin@saksham.org',
            onTap: () => context.go('/settings/edit-profile')),
          _settingsItem(Icons.phone_outlined, 'Phone', '+91 99887 66554',
            onTap: () => context.go('/settings/edit-profile')),
          _settingsItem(Icons.work_outline, 'Role', 'Administrator', onTap: null),
        ]),
        const SizedBox(height: 16),
        _settingsSection('Edit Profile', [
          _settingsItem(Icons.edit_outlined, 'Edit Profile', 'Update your personal information',
            onTap: () => context.go('/settings/edit-profile')),
        ]),
      ]),
    )),
  );

  // ── Tab: Security ──────────────────────────────────────────────
  Widget _securityTab() => SingleChildScrollView(
    physics: const BouncingScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(18, 16, 18, 40),
    child: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 700),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _settingsSection('Password & Authentication', [
          _settingsItem(Icons.lock_outline, 'Change Password', 'Last changed 30 days ago',
            onTap: () => context.go('/settings/security-pin')),
          _settingsItem(Icons.security_outlined, 'Two-Factor Authentication', 'Not enabled',
            onTap: () => _show2FADialog()),
          _settingsItem(Icons.devices_outlined, 'Active Sessions', 'View and manage sessions',
            onTap: () => context.go('/settings/linked-devices')),
          _settingsItem(Icons.lock_outline, 'Security & PIN', 'Protect your account',
            onTap: () => context.go('/settings/security-pin')),
        ]),
        const SizedBox(height: 16),
        _settingsSection('Danger Zone', [
          _settingsItem(Icons.delete_outline, 'Delete Account', 'Permanently remove all data',
            onTap: () {}, isDestructive: true),
        ]),
      ]),
    )),
  );

  // ── Tab: Branding ──────────────────────────────────────────────
  Widget _brandingTab() => SingleChildScrollView(
    physics: const BouncingScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(18, 16, 18, 40),
    child: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 700),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _settingsSection('Visual Identity', [
          _settingsItem(Icons.image_outlined, 'Organization Logo', 'Upload PNG or SVG', onTap: () {}),
          _settingsItem(Icons.color_lens_outlined, 'Primary Color', '#0F9D7A', onTap: () {}),
          _settingsItem(Icons.font_download_outlined, 'Font Family', 'Inter (current)', onTap: null),
        ]),
        const SizedBox(height: 16),
        _settingsSection('App Appearance', [
          _settingsItem(Icons.dark_mode_outlined, 'Dark Mode', 'Toggle theme', onTap: () {
            final isDark = ref.read(themeModeProvider) == ThemeMode.dark;
            ref.read(themeModeProvider.notifier).state =
              isDark ? ThemeMode.light : ThemeMode.dark;
            _toast(isDark ? 'Light mode on' : 'Dark mode on');
          }),
          _settingsItem(Icons.language_outlined, 'Language', 'English', onTap: () {}),
        ]),
      ]),
    )),
  );

  // ── Tab: Notifications ─────────────────────────────────────────
  Widget _notificationsTab() => SingleChildScrollView(
    physics: const BouncingScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(18, 16, 18, 40),
    child: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 700),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _settingsSection('Alerts', [
          _settingsToggle(Icons.cake_outlined, 'Birthday Reminders', 'Get notified on donor/student birthdays', _notifBirthdays,
            onChanged: (v) => setState(() => _notifBirthdays = v)),
          _settingsToggle(Icons.favorite_border, 'Anniversary Alerts', 'Anniversary notifications', _notifAnniversary,
            onChanged: (v) => setState(() => _notifAnniversary = v)),
          _settingsToggle(Icons.payment_outlined, 'Donation Received', 'Alert on every donation', _notifDonations,
            onChanged: (v) => setState(() => _notifDonations = v)),
          _settingsToggle(Icons.person_add_outlined, 'New Donor Added', 'Notify on new donor registration', _notifNewDonor,
            onChanged: (v) => setState(() => _notifNewDonor = v)),
          _settingsToggle(Icons.school_outlined, 'Student Enrolled', 'Notify on student enrollment', _notifStudent,
            onChanged: (v) => setState(() => _notifStudent = v)),
          _settingsToggle(Icons.emoji_events_outlined, 'Achievements', 'When a student milestone is logged', _notifAchievements,
            onChanged: (v) => setState(() => _notifAchievements = v)),
        ]),
      ]),
    )),
  );

  // ── Helper: Section with title + card ─────────────────────────
  Widget _settingsSection(String title, List<Widget> items) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title.toUpperCase(), style: const TextStyle(
        fontSize: 11, fontWeight: FontWeight.w800,
        color: Color(0xFF93A29F), letterSpacing: 0.8)),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE5EBE9)),
        ),
        child: Column(children: items.asMap().entries.map((e) => Column(children: [
          e.value,
          if (e.key < items.length - 1) const Divider(height: 1, color: Color(0xFFE5EBE9)),
        ])).toList()),
      ),
    ]);

  // ── Helper: Settings item row ──────────────────────────────────
  Widget _settingsItem(IconData icon, String title, String subtitle,
      {VoidCallback? onTap, bool isDestructive = false}) =>
    ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: isDestructive ? const Color(0xFFFFE3DF) : const Color(0xFFF4F7F6),
          shape: BoxShape.circle),
        child: Icon(icon, size: 18,
          color: isDestructive ? const Color(0xFFF2685E) : const Color(0xFF5A6B67)),
      ),
      title: Text(title, style: TextStyle(
        fontSize: 14, fontWeight: FontWeight.w700,
        color: isDestructive ? const Color(0xFFF2685E) : const Color(0xFF15211E))),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12.5, color: Color(0xFF93A29F))),
      trailing: onTap != null
        ? const Icon(Icons.chevron_right, size: 18, color: Color(0xFF93A29F))
        : null,
    );

  // ── Helper: Toggle row (self-contained state via StatefulBuilder) ─
  Widget _settingsToggle(IconData icon, String title, String subtitle, bool value,
      {required ValueChanged<bool> onChanged}) =>
    ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 38, height: 38,
        decoration: const BoxDecoration(color: Color(0xFFF4F7F6), shape: BoxShape.circle),
        child: Icon(icon, size: 18, color: const Color(0xFF5A6B67)),
      ),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF15211E))),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12.5, color: Color(0xFF93A29F))),
      trailing: Switch(value: value, onChanged: onChanged, activeColor: const Color(0xFF0E8C76)),
    );

  // ── 2FA dialog ─────────────────────────────────────────────────
  void _show2FADialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Two-Factor Authentication',
          style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text(
          '2FA setup will be available in the next release. This will add an extra layer of security to your account.',
          style: TextStyle(fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }
}

// ── Standalone helpers used by Notifications section (legacy) ───
Widget _sectionLabel(BuildContext ctx, String t) => Padding(
  padding: const EdgeInsets.fromLTRB(20, 0, 0, 8),
  child: Text(t.toUpperCase(), style: TextStyle(
    fontSize: 11.5, fontWeight: FontWeight.w800, color: ctx.textHint, letterSpacing: 0.8)));

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 18),
    child: Container(
      decoration: BoxDecoration(
        color: context.cardBg, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.border),
        boxShadow: const [BoxShadow(color: Color(0x080D2822), blurRadius: 6, offset: Offset(0, 2))]),
      child: Column(children: children)));
}

class _ToggleRow extends StatelessWidget {
  const _ToggleRow({required this.icon, required this.iconBg, required this.iconFg,
    required this.label, required this.sub, required this.value,
    required this.onChanged, this.last = false});
  final IconData icon;
  final Color iconBg, iconFg;
  final String label, sub;
  final bool value, last;
  final ValueChanged<bool> onChanged;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
    decoration: last ? null : BoxDecoration(border: Border(bottom: BorderSide(color: context.border))),
    child: Row(children: [
      Container(width: 38, height: 38,
        decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(11)),
        child: Icon(icon, color: iconFg, size: 19)),
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
  const _ChevronRow({required this.icon, required this.iconBg, required this.iconFg,
    required this.label, required this.onTap, this.sub, this.last = false});
  final IconData icon;
  final Color iconBg, iconFg;
  final String label;
  final String? sub;
  final bool last;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: last ? null : BoxDecoration(border: Border(bottom: BorderSide(color: context.border))),
      child: Row(children: [
        Container(width: 38, height: 38,
          decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(11)),
          child: Icon(icon, color: iconFg, size: 19)),
        const SizedBox(width: 13),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: context.textPrimary)),
          if (sub != null) Text(sub!, style: TextStyle(fontSize: 12, color: context.textHint, fontWeight: FontWeight.w500)),
        ])),
        Icon(Icons.chevron_right, color: context.textHint, size: 20),
      ]),
    ));
}
