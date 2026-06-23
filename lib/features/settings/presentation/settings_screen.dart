import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../main.dart' show themeModeProvider;
import '../../../core/theme/app_theme.dart';

const _brand600 = Color(0xFF0E8C76);
const _brand100 = Color(0xFFD6F3EC);
const _coral500 = Color(0xFFF2685E);
const _coral100 = Color(0xFFFFE3DF);
const _onSurface3 = Color(0xFF93A29F);

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;

  // Editable org/registration fields
  String _orgName    = 'Saksham Foundation';
  String _orgWebsite = 'www.saksham.org';
  String _orgAddress = 'Mumbai, Maharashtra';
  String _orgPhone   = '+91 98765 43210';
  String _regNo      = 'NGO-2019-MH-00123';
  String _pan        = 'AABCS1234D';
  String _fcraSt     = 'Active';

  // Logo & profile photo
  Uint8List? _logoBytes;
  Uint8List? _profileBytes;

  void _editField(String label, String current, void Function(String) onSave) {
    final ctrl = TextEditingController(text: current);
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text('Edit $label', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      content: TextField(
        controller: ctrl, autofocus: true,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          filled: true, fillColor: const Color(0xFFF4F7F6),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _brand600, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () { if (ctrl.text.trim().isNotEmpty) { setState(() => onSave(ctrl.text.trim())); } Navigator.pop(ctx); },
          style: ElevatedButton.styleFrom(backgroundColor: _brand600, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          child: const Text('Save'),
        ),
      ],
    ));
  }

  Future<void> _pickLogo() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (r != null && r.files.isNotEmpty && r.files.single.bytes != null && mounted) {
      setState(() => _logoBytes = r.files.single.bytes);
      _toast('Logo updated');
    }
  }

  Future<void> _pickProfilePhoto() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (r != null && r.files.isNotEmpty && r.files.single.bytes != null && mounted) {
      setState(() => _profileBytes = r.files.single.bytes);
      _toast('Profile photo updated');
    }
  }

  void _showChangePasswordDialog() {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Change Password', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          _pwField(currentCtrl, 'Enter Current Password'),
          const SizedBox(height: 10),
          _pwField(newCtrl, 'Enter New Password'),
          const SizedBox(height: 10),
          _pwField(confirmCtrl, 'Confirm New Password'),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (newCtrl.text == confirmCtrl.text && newCtrl.text.isNotEmpty) {
                Navigator.pop(ctx);
                _toast('Password changed successfully');
              } else {
                _toast('Passwords do not match');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: _brand600, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Widget _pwField(TextEditingController ctrl, String hint) => TextField(
    controller: ctrl,
    obscureText: true,
    style: const TextStyle(fontSize: 14),
    decoration: InputDecoration(
      hintText: hint,
      filled: true, fillColor: const Color(0xFFF4F7F6),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _brand600, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
  );

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
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
            indicatorColor: _brand600,
            indicatorWeight: 2.5,
            labelColor: _brand600,
            unselectedLabelColor: _onSurface3,
            labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            tabs: const [
              Tab(text: '🏢  Organization'),
              Tab(text: '👤  Profile'),
              Tab(text: '🔒  Security'),
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
          ],
        )),
      ]),
    );
  }

  // ── Tab: Organization ──────────────────────────────────────────
  Widget _orgTab() => SingleChildScrollView(
    physics: const BouncingScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(18, 16, 18, 40),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Logo upload
      _settingsSection('Organization Logo', [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            width: 52, height: 52,
            decoration: BoxDecoration(color: const Color(0xFFF4F7F6), borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE5EBE9))),
            clipBehavior: Clip.hardEdge,
            child: _logoBytes != null
                ? Image.memory(_logoBytes!, fit: BoxFit.cover)
                : const Icon(Icons.image_outlined, size: 26, color: _onSurface3),
          ),
          title: const Text('Upload Logo', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          subtitle: const Text('PNG or SVG, recommended 200×200px', style: TextStyle(fontSize: 12, color: _onSurface3)),
          trailing: GestureDetector(
            onTap: _pickLogo,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(color: _brand600, borderRadius: BorderRadius.circular(8)),
              child: Text(_logoBytes != null ? 'Change' : 'Upload',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
        ),
      ]),
      const SizedBox(height: 16),
      // Dark mode toggle
      _settingsSection('Appearance', [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(width: 38, height: 38,
            decoration: const BoxDecoration(color: Color(0xFFF4F7F6), shape: BoxShape.circle),
            child: const Icon(Icons.dark_mode_outlined, size: 18, color: Color(0xFF5A6B67))),
          title: const Text('Dark Mode', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          subtitle: const Text('Toggle app theme', style: TextStyle(fontSize: 12.5, color: _onSurface3)),
          trailing: Switch(
            value: ref.watch(themeModeProvider) == ThemeMode.dark,
            onChanged: (v) {
              ref.read(themeModeProvider.notifier).state = v ? ThemeMode.dark : ThemeMode.light;
              _toast(v ? 'Dark mode on' : 'Light mode on');
            },
            activeColor: _brand600,
          ),
        ),
      ]),
      const SizedBox(height: 16),
      _settingsSection('Organization Details', [
        _settingsItem(Icons.business_outlined, 'Organization Name', _orgName, onTap: () => _editField('Organization Name', _orgName, (v) => _orgName = v)),
        _settingsItem(Icons.language_outlined, 'Website', _orgWebsite, onTap: () => _editField('Website', _orgWebsite, (v) => _orgWebsite = v)),
        _settingsItem(Icons.location_on_outlined, 'Address', _orgAddress, onTap: () => _editField('Address', _orgAddress, (v) => _orgAddress = v)),
        _settingsItem(Icons.phone_outlined, 'Contact Number', _orgPhone, onTap: () => _editField('Contact Number', _orgPhone, (v) => _orgPhone = v)),
      ]),
      const SizedBox(height: 16),
      _settingsSection('Registration', [
        _settingsItem(Icons.article_outlined, 'Registration Number', _regNo, onTap: () => _editField('Registration Number', _regNo, (v) => _regNo = v)),
        _settingsItem(Icons.account_balance_outlined, 'PAN / Tax ID', _pan, onTap: () => _editField('PAN / Tax ID', _pan, (v) => _pan = v)),
        _settingsItem(Icons.verified_outlined, 'FCRA Status', _fcraSt, onTap: () => _editField('FCRA Status', _fcraSt, (v) => _fcraSt = v)),
      ]),
      const SizedBox(height: 16),
      _settingsSection('Administration', [
        _settingsItem(Icons.admin_panel_settings_outlined, 'Admin Panel', 'Overview, team & system settings', onTap: () => context.go('/settings/admin-panel')),
        _settingsItem(Icons.manage_accounts_outlined, 'Manage Roles', 'Staff access & permissions', onTap: () => context.go('/settings/manage-roles')),
        _settingsItem(Icons.people_outlined, 'Team Members', '5 staff', onTap: () => context.go('/settings/team-members')),
        _settingsItem(Icons.category_outlined, 'Donation Types', 'Manage categories', onTap: () => context.go('/settings/donation-types')),
        _settingsItem(Icons.business_outlined, 'Offices', 'Manage office locations', onTap: () => context.go('/offices')),
      ]),
      const SizedBox(height: 16),
      _settingsSection('Data', [
        _settingsItem(Icons.download_outlined, 'Export Data', 'Download reports & records', onTap: () => context.go('/settings/export-data')),
        _settingsItem(Icons.cloud_sync_outlined, 'Backup & Sync', 'Last synced today', onTap: () => context.go('/settings/backup-sync')),
        _settingsItem(Icons.router_outlined, 'Server URL', 'Update backend connection', onTap: () => context.go('/settings/server-url')),
        _settingsItem(Icons.payment_outlined, 'Razorpay Credentials', 'Add payment gateway keys', onTap: () => context.go('/settings/razorpay')),
      ]),
      const SizedBox(height: 16),
      _settingsSection('About', [
        _settingsItem(Icons.privacy_tip_outlined, 'Privacy Policy', 'View our privacy policy', onTap: () => context.go('/settings/privacy-policy')),
        _settingsItem(Icons.gavel_outlined, 'Terms of Service', 'View terms of service', onTap: () => context.go('/settings/terms-of-service')),
        _settingsItem(Icons.info_outline, 'About Us', 'Learn about Saksham Foundation', onTap: () => context.go('/settings/about-us')),
        _settingsItem(Icons.help_outline, 'Help & Support', 'FAQs and contact', onTap: () => context.go('/help')),
      ]),
      const SizedBox(height: 20),
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
  );

  // ── Tab: Profile ───────────────────────────────────────────────
  Widget _profileTab() => SingleChildScrollView(
    physics: const BouncingScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(18, 16, 18, 40),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 8),
      Center(child: Column(children: [
        GestureDetector(
          onTap: _pickProfilePhoto,
          child: Stack(children: [
            Container(
              width: 88, height: 88,
              decoration: BoxDecoration(shape: BoxShape.circle,
                color: _profileBytes == null ? _brand600 : null,
                border: Border.all(color: _brand600.withValues(alpha: 0.35), width: 2)),
              clipBehavior: Clip.hardEdge,
              child: _profileBytes != null
                  ? Image.memory(_profileBytes!, fit: BoxFit.cover)
                  : const Center(child: Text('FA', style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900))),
            ),
            Positioned(bottom: 0, right: 0,
              child: Container(width: 26, height: 26,
                decoration: BoxDecoration(color: _brand600, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                child: const Icon(Icons.camera_alt, size: 13, color: Colors.white))),
          ]),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _pickProfilePhoto,
          child: const Text('Change Photo', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: _brand600)),
        ),
      ])),
      const SizedBox(height: 20),
      _settingsSection('Personal Information', [
        _settingsItem(Icons.person_outline, 'Full Name', 'Farhan Ansari', onTap: () => context.go('/settings/edit-profile')),
        _settingsItem(Icons.email_outlined, 'Email', 'admin@saksham.org', onTap: () => context.go('/settings/edit-profile')),
        _settingsItem(Icons.phone_outlined, 'Phone', '+91 99887 66554', onTap: () => context.go('/settings/edit-profile')),
        _settingsItem(Icons.work_outline, 'Role', 'Administrator', onTap: null),
      ]),
      const SizedBox(height: 16),
      _settingsSection('Edit Profile', [
        _settingsItem(Icons.edit_outlined, 'Edit Profile', 'Update your personal information', onTap: () => context.go('/settings/edit-profile')),
      ]),
    ]),
  );

  // ── Tab: Security ──────────────────────────────────────────────
  Widget _securityTab() => SingleChildScrollView(
    physics: const BouncingScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(18, 16, 18, 40),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _settingsSection('Password', [
        _settingsItem(Icons.lock_outline, 'Change Password', 'Update your login password',
          onTap: _showChangePasswordDialog),
      ]),
      const SizedBox(height: 16),
      _settingsSection('Sessions', [
        _settingsItem(Icons.devices_outlined, 'Active Sessions', 'View and manage active sessions',
          onTap: () => context.go('/settings/linked-devices')),
      ]),
      const SizedBox(height: 16),
      _settingsSection('Login History', [
        _loginHistoryItem('Chrome · Windows', 'Today, 4:30 PM', Icons.computer_outlined),
        _loginHistoryItem('Safari · iPhone', 'Yesterday, 11:00 AM', Icons.phone_iphone_outlined),
        _loginHistoryItem('Chrome · Android', '20 Jun, 9:15 AM', Icons.phone_android_outlined),
      ]),
    ]),
  );

  Widget _loginHistoryItem(String device, String time, IconData icon) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    leading: Container(width: 38, height: 38,
      decoration: const BoxDecoration(color: Color(0xFFF4F7F6), shape: BoxShape.circle),
      child: Icon(icon, size: 18, color: const Color(0xFF5A6B67))),
    title: Text(device, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
    subtitle: Text(time, style: const TextStyle(fontSize: 12.5, color: _onSurface3)),
  );

  // ── Helper: Section with title + card ─────────────────────────
  Widget _settingsSection(String title, List<Widget> items) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title.toUpperCase(), style: const TextStyle(
        fontSize: 11, fontWeight: FontWeight.w800,
        color: _onSurface3, letterSpacing: 0.8)),
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

  Widget _settingsItem(IconData icon, String title, String subtitle,
      {VoidCallback? onTap, bool isDestructive = false}) =>
    ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(width: 38, height: 38,
        decoration: BoxDecoration(
          color: isDestructive ? _coral100 : const Color(0xFFF4F7F6),
          shape: BoxShape.circle),
        child: Icon(icon, size: 18,
          color: isDestructive ? _coral500 : const Color(0xFF5A6B67))),
      title: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
        color: isDestructive ? _coral500 : const Color(0xFF15211E))),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12.5, color: _onSurface3)),
      trailing: onTap != null ? const Icon(Icons.chevron_right, size: 18, color: _onSurface3) : null,
    );
}
