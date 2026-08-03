import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../main.dart' show themeModeProvider;
import '../../../core/theme/app_theme.dart';
import '../../../core/auth/role_auth.dart';
import '../../../core/auth/session.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/open_bytes.dart';
import '../profile_store.dart';
import '../org_store.dart';

const _brand600 = Color(0xFFFF9933);
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

  // ── Organization (backend-persisted, GET/PATCH /settings/organization) ──
  bool _orgLoading = false;

  // Backend is the source of truth; org_store's local cache is only a
  // fallback for offline viewing (and for other screens — sidebar, receipts
  // — that still read orgProfile directly).
  Future<void> _loadOrgFromBackend() async {
    if (mounted) setState(() => _orgLoading = true);
    try {
      final r = await apiClient.get('/settings/organization');
      final d = (r['data'] as Map?)?.cast<String, dynamic>() ?? {};
      updateOrg(OrgData.fromBackend(d, fallback: orgProfile.value));
    } catch (_) {
      // Offline / unreachable backend — keep showing whatever is cached
      // locally so the screen isn't empty.
    }
    if (mounted) setState(() => _orgLoading = false);
  }

  Future<void> _syncOrgToBackend(Map<String, dynamic> patch) async {
    try {
      await apiClient.patch('/settings/organization', patch);
    } on DioException catch (e) {
      if (mounted) {
        _toastError(e.response?.statusCode == 403
            ? 'You do not have permission to update organization settings'
            : 'Saved locally — could not sync to the server');
      }
    } catch (_) {
      if (mounted) _toastError('Saved locally — could not sync to the server');
    }
  }

  // Edits one org field: updates the local cache immediately (so the UI and
  // sidebar/receipts update right away) and pushes the same change to the
  // real backend in the background.
  void _editOrgField(String label, String current,
      OrgData Function(OrgData org, String v) mutate, String backendKey) {
    _editField(label, current, (v) {
      updateOrg(mutate(orgProfile.value, v));
      _syncOrgToBackend({backendKey: v});
    });
  }

  void _toastError(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w700)),
    backgroundColor: _coral500, behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    duration: const Duration(seconds: 3),
  ));

  // ── Payments / Razorpay (backend-persisted, SUPER_ADMIN only) ───────────
  final _payKeyIdCtrl = TextEditingController();
  final _paySecretCtrl = TextEditingController();
  final _payWebhookCtrl = TextEditingController();
  bool _payLoading = false;
  bool _paySaving = false;
  bool _payObscureSecret = true;
  bool _payObscureWebhook = true;
  // Backend restricts GET/PATCH /settings/razorpay to SUPER_ADMIN — a plain
  // ADMIN (also "isAdmin" on the client) gets a 403; show a clean message.
  bool _payForbidden = false;

  Future<void> _loadPaymentsFromBackend() async {
    if (mounted) setState(() => _payLoading = true);
    try {
      final r = await apiClient.get('/settings/razorpay');
      final d = (r['data'] as Map?)?.cast<String, dynamic>() ?? {};
      if (mounted) setState(() {
        _payKeyIdCtrl.text = d['keyId'] as String? ?? '';
        _paySecretCtrl.text = d['keySecret'] as String? ?? '';
        _payWebhookCtrl.text = d['webhookSecret'] as String? ?? '';
        _payForbidden = false;
      });
    } on DioException catch (e) {
      if (mounted) setState(() => _payForbidden = e.response?.statusCode == 403);
    } catch (_) {
      // Offline — leave whatever was already loaded.
    }
    if (mounted) setState(() => _payLoading = false);
  }

  Future<void> _savePayments() async {
    final keyId = _payKeyIdCtrl.text.trim();
    final keySecret = _paySecretCtrl.text.trim();
    final webhookSecret = _payWebhookCtrl.text.trim();
    if (keyId.isEmpty || keySecret.isEmpty) {
      _toastError('Both Key ID and Key Secret are required');
      return;
    }
    setState(() => _paySaving = true);
    try {
      await apiClient.patch('/settings/razorpay',
          {'keyId': keyId, 'keySecret': keySecret, 'webhookSecret': webhookSecret});
      if (mounted) _toast('Razorpay credentials saved');
    } on DioException catch (e) {
      if (mounted) {
        _toastError(e.response?.statusCode == 403
            ? 'You do not have permission to update payment settings'
            : 'Could not save — check your connection and try again');
      }
    } catch (_) {
      if (mounted) _toastError('Could not save — check your connection and try again');
    }
    if (mounted) setState(() => _paySaving = false);
  }

  // ── My Documents (read-only team-member profile) ────────────────
  List<_MyDoc> _myDocs = [];
  bool _myDocsLoading = false;
  bool _myDocsUploading = false;
  String? _myDocsViewingId;
  String? _myDocsDeletingId;

  Future<void> _loadMyDocuments() async {
    final id = currentLoggedInRole?.backendId;
    if (id == null) return;
    if (mounted) setState(() => _myDocsLoading = true);
    try {
      final r = await apiClient.get('/users/$id/documents');
      final list = (r['data'] as List<dynamic>? ?? const []);
      final docs = list.whereType<Map>().map((m) => _MyDoc.fromJson(m.cast<String, dynamic>())).toList();
      if (mounted) setState(() { _myDocs = docs; _myDocsLoading = false; });
    } catch (_) {
      if (mounted) setState(() => _myDocsLoading = false);
    }
  }

  Future<void> _uploadMyDocument() async {
    final id = currentLoggedInRole?.backendId;
    if (id == null) return;
    final nameCtrl = TextEditingController();
    final category = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Document Name', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: TextField(
          controller: nameCtrl, autofocus: true,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: 'Enter document name',
            filled: true, fillColor: ctx.surface2,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _brand600, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () { final v = nameCtrl.text.trim(); if (v.isNotEmpty) Navigator.pop(ctx, v); },
            style: ElevatedButton.styleFrom(backgroundColor: _brand600, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Next'),
          ),
        ],
      ),
    );
    if (category == null || !mounted) return;
    setState(() => _myDocsUploading = true);
    try {
      final result = await FilePicker.platform.pickFiles(allowMultiple: false, withData: true);
      final bytes = result?.files.single.bytes;
      if (result != null && bytes != null && mounted) {
        final fileName = result.files.single.name;
        await apiClient.post('/users/$id/documents', {
          'category': category, 'fileName': fileName, 'mimeType': null, 'data': base64Encode(bytes),
        });
        await _loadMyDocuments();
        if (mounted) _toast('$fileName uploaded successfully');
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Upload failed — check your connection and try again', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: _coral500, behavior: SnackBarBehavior.floating));
    }
    if (mounted) setState(() => _myDocsUploading = false);
  }

  Future<void> _viewMyDocument(_MyDoc d) async {
    setState(() => _myDocsViewingId = d.id);
    try {
      final r = await apiClient.get('/users/documents/${d.id}');
      final data = (r['data'] as Map).cast<String, dynamic>();
      final b64 = data['data'] as String? ?? '';
      if (b64.isNotEmpty) openBytesInBrowser(base64Decode(b64), d.fileName);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not open document', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: _coral500, behavior: SnackBarBehavior.floating));
    }
    if (mounted) setState(() => _myDocsViewingId = null);
  }

  void _confirmDeleteMyDocument(_MyDoc d) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Delete Document', style: TextStyle(fontWeight: FontWeight.w800)),
      content: Text('Delete "${d.fileName}"? This cannot be undone.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        TextButton(
          onPressed: () { Navigator.pop(ctx); _deleteMyDocument(d); },
          child: const Text('Delete', style: TextStyle(color: _coral500, fontWeight: FontWeight.w700)),
        ),
      ],
    ));
  }

  Future<void> _deleteMyDocument(_MyDoc d) async {
    setState(() => _myDocsDeletingId = d.id);
    try { await apiClient.delete('/users/documents/${d.id}'); } catch (_) {}
    await _loadMyDocuments();
    if (mounted) setState(() => _myDocsDeletingId = null);
  }

  void _editField(String label, String current, void Function(String) onSave) {
    final ctrl = TextEditingController(text: current);
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text('Edit $label', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      content: TextField(
        controller: ctrl, autofocus: true,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          filled: true, fillColor: ctx.surface2,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _brand600, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () { if (ctrl.text.trim().isNotEmpty) { onSave(ctrl.text.trim()); } Navigator.pop(ctx); },
          style: ElevatedButton.styleFrom(backgroundColor: _brand600, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          child: const Text('Save'),
        ),
      ],
    ));
  }

  // Logo + profile photo both persist so they survive a reload and propagate
  // to the sidebar / receipts.
  Future<void> _pickLogo() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (r != null && r.files.isNotEmpty && r.files.single.bytes != null && mounted) {
      final encoded = encodeLogo(r.files.single.bytes);
      updateOrg(orgProfile.value.copyWith(logoBase64: encoded));
      _toast('Logo updated');
      _syncOrgToBackend({'logoBase64': encoded ?? ''});
    }
  }

  Future<void> _pickProfilePhoto() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (r != null && r.files.isNotEmpty && r.files.single.bytes != null && mounted) {
      final encoded = encodePhoto(r.files.single.bytes);
      updateProfile(adminProfile.value.copyWith(photoBase64: encoded));
      // Sync to the backend so the photo survives reloads and other devices.
      try { await apiClient.patch('/users/me/profile', {'avatar': encoded ?? ''}); } catch (_) {}
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
            onPressed: () async {
              if (newCtrl.text != confirmCtrl.text || newCtrl.text.isEmpty) {
                _toast('Passwords do not match');
                return;
              }
              if (newCtrl.text.length < 8) {
                _toast('New password must be at least 8 characters');
                return;
              }
              // Actually change it server-side — this dialog used to toast
              // success without calling any API at all.
              try {
                await apiClient.patch('/users/me/password', {
                  'currentPassword': currentCtrl.text,
                  'newPassword': newCtrl.text,
                });
                if (ctx.mounted) Navigator.pop(ctx);
                _toast('Password changed successfully');
              } catch (e) {
                _toast(ApiClient.errorMessage(e, fallback: 'Could not change password'));
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
      filled: true, fillColor: context.surface2,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _brand600, width: 1.5)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    ),
  );

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
    if (!isAdmin && currentLoggedInRole?.backendId != null) _loadMyDocuments();
    if (isAdmin) {
      _loadOrgFromBackend();
      _loadPaymentsFromBackend();
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _payKeyIdCtrl.dispose();
    _paySecretCtrl.dispose();
    _payWebhookCtrl.dispose();
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
    // Team members get a read-only profile only — no org/security settings,
    // no edit. Admins get the full settings.
    if (!isAdmin) return _memberProfile(context, top);
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
            unselectedLabelColor: context.textSub,
            labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            tabs: const [
              Tab(text: '🏢  Organization'),
              Tab(text: '👤  Profile'),
              Tab(text: '🔒  Security'),
              Tab(text: '💳  Payments'),
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
            _paymentsTab(),
          ],
        )),
      ]),
    );
  }

  // ── Tab: Organization ──────────────────────────────────────────
  Widget _orgTab() => ValueListenableBuilder<OrgData>(
    valueListenable: orgProfile,
    builder: (context, org, _) => SingleChildScrollView(
    physics: const BouncingScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(18, 16, 18, 40),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Logo upload
      _settingsSection('Organization Logo', [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            width: 52, height: 52,
            decoration: BoxDecoration(color: context.surface2, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.border)),
            clipBehavior: Clip.hardEdge,
            child: org.logoBytes != null
                ? Image.memory(org.logoBytes!, fit: BoxFit.cover)
                : Image.asset(brandLogoAsset, fit: BoxFit.contain),
          ),
          title: const Text('Upload Logo', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          subtitle: Text('PNG or SVG, recommended 200×200px', style: TextStyle(fontSize: 12, color: context.textSub)),
          trailing: GestureDetector(
            onTap: _pickLogo,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(color: _brand600, borderRadius: BorderRadius.circular(8)),
              child: Text(org.logoBytes != null ? 'Change' : 'Upload',
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
            decoration: BoxDecoration(color: context.surface2, shape: BoxShape.circle),
            child: Icon(Icons.dark_mode_outlined, size: 18, color: context.textSub)),
          title: const Text('Dark Mode', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          subtitle: Text('Toggle app theme', style: TextStyle(fontSize: 12.5, color: context.textSub)),
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
      if (_orgLoading)
        const Padding(padding: EdgeInsets.symmetric(vertical: 12),
          child: Center(child: SizedBox(width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: _brand600)))),
      _settingsSection('Organization Details', [
        _settingsItem(Icons.business_outlined, 'Organization Name', org.name,
          onTap: () => _editOrgField('Organization Name', org.name, (o, v) => o.copyWith(name: v), 'name')),
        _settingsItem(Icons.email_outlined, 'Email', org.email,
          onTap: () => _editOrgField('Email', org.email, (o, v) => o.copyWith(email: v), 'email')),
        _settingsItem(Icons.language_outlined, 'Website', org.website,
          onTap: () => _editOrgField('Website', org.website, (o, v) => o.copyWith(website: v), 'website')),
        _settingsItem(Icons.location_on_outlined, 'Address', org.address,
          onTap: () => _editOrgField('Address', org.address, (o, v) => o.copyWith(address: v), 'address')),
        _settingsItem(Icons.location_city_outlined, 'City', org.city,
          onTap: () => _editOrgField('City', org.city, (o, v) => o.copyWith(city: v), 'city')),
        _settingsItem(Icons.map_outlined, 'State', org.state,
          onTap: () => _editOrgField('State', org.state, (o, v) => o.copyWith(state: v), 'state')),
        _settingsItem(Icons.public_outlined, 'Country', org.country,
          onTap: () => _editOrgField('Country', org.country, (o, v) => o.copyWith(country: v), 'country')),
        _settingsItem(Icons.markunread_mailbox_outlined, 'Pincode', org.pincode,
          onTap: () => _editOrgField('Pincode', org.pincode, (o, v) => o.copyWith(pincode: v), 'pincode')),
        _settingsItem(Icons.phone_outlined, 'Contact Number', org.phone,
          onTap: () => _editOrgField('Contact Number', org.phone, (o, v) => o.copyWith(phone: v), 'phone')),
      ]),
      const SizedBox(height: 16),
      _settingsSection('Registration', [
        _settingsItem(Icons.article_outlined, 'Registration Number', org.regNo,
          onTap: () => _editOrgField('Registration Number', org.regNo, (o, v) => o.copyWith(regNo: v), 'registrationNumber')),
        _settingsItem(Icons.account_balance_outlined, 'PAN / Tax ID', org.pan,
          onTap: () => _editOrgField('PAN / Tax ID', org.pan, (o, v) => o.copyWith(pan: v), 'pan')),
        _settingsItem(Icons.description_outlined, '12A Certificate', org.reg12A.isEmpty ? 'Not set' : org.reg12A,
          onTap: () => _editOrgField('12A Certificate', org.reg12A, (o, v) => o.copyWith(reg12A: v), 'reg12A')),
        _settingsItem(Icons.workspace_premium_outlined, '80G Certificate', org.cert80G.isEmpty ? 'Not set' : org.cert80G,
          onTap: () => _editOrgField('80G Certificate', org.cert80G, (o, v) => o.copyWith(cert80G: v), 'cert80G')),
        _settingsItem(Icons.verified_outlined, 'FCRA Status', org.fcra,
          onTap: () => _editOrgField('FCRA Status', org.fcra, (o, v) => o.copyWith(fcra: v), 'fcra')),
      ]),
      const SizedBox(height: 16),
      _settingsSection('Administration', [
        _settingsItem(Icons.admin_panel_settings_outlined, 'Admin Panel', 'Overview, team & system settings', onTap: () => context.go('/settings/admin-panel')),
        _settingsItem(Icons.manage_accounts_outlined, 'Manage Roles', 'Staff access & permissions', onTap: () => context.go('/settings/manage-roles')),
        _settingsItem(Icons.people_outlined, 'Team Members',
            '${1 + appRoles.where((r) => r.email.toLowerCase() != adminProfile.value.email.toLowerCase()).length} staff',
            onTap: () => context.go('/settings/team-members')),
        _settingsItem(Icons.category_outlined, 'Donation Types', 'Manage categories', onTap: () => context.go('/settings/donation-types')),
        _settingsItem(Icons.face_outlined, 'Student Categories', 'Manage children categories', onTap: () => context.go('/settings/student-categories')),
        _settingsItem(Icons.location_city_outlined, 'Manage Centres', 'Add and manage centres', onTap: () => context.go('/settings/centres')),
        _settingsItem(Icons.business_outlined, 'Offices', 'Manage office locations', onTap: () => context.go('/offices')),
        _settingsItem(Icons.chat_outlined, 'WhatsApp Business API', 'Donation & receipt messaging', onTap: () => context.go('/settings/whatsapp')),
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
        _settingsItem(Icons.info_outline, 'About Us', 'Learn about Sri Krishnashraya Educational Trust', onTap: () => context.go('/settings/about-us')),
        _settingsItem(Icons.help_outline, 'Help & Support', 'FAQs and contact', onTap: () => context.go('/help')),
      ]),
      const SizedBox(height: 20),
      GestureDetector(
        onTap: () async { await logoutSession(); if (context.mounted) context.go('/login'); },
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
      Center(child: Text('${org.name} · v2.4.0',
        style: TextStyle(fontSize: 12, color: context.textHint, fontWeight: FontWeight.w600))),
    ]),
  ));

  // ── Tab: Profile ───────────────────────────────────────────────
  Widget _profileTab() => ValueListenableBuilder<ProfileData>(
    valueListenable: adminProfile,
    builder: (context, profile, _) => SingleChildScrollView(
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
                  color: context.cardBg,
                  border: Border.all(color: _brand600.withValues(alpha: 0.35), width: 2)),
                clipBehavior: Clip.hardEdge,
                child: profile.photoBytes != null
                    ? Image.memory(profile.photoBytes!, fit: BoxFit.cover)
                    : Image.asset(brandLogoAsset, fit: BoxFit.cover, alignment: Alignment.centerLeft),
              ),
              Positioned(bottom: 0, right: 0,
                child: Container(width: 26, height: 26,
                  decoration: BoxDecoration(color: _brand600, shape: BoxShape.circle, border: Border.all(color: context.cardBg, width: 2)),
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
          _settingsItem(Icons.person_outline, 'Full Name', profile.name, onTap: () => context.go('/settings/edit-profile')),
          _settingsItem(Icons.email_outlined, 'Email', profile.email, onTap: () => context.go('/settings/edit-profile')),
          _settingsItem(Icons.phone_outlined, 'Phone', profile.phone, onTap: () => context.go('/settings/edit-profile')),
          _settingsItem(Icons.work_outline, 'Role', profile.role, onTap: null),
        ]),
        const SizedBox(height: 16),
        _settingsSection('Edit Profile', [
          _settingsItem(Icons.edit_outlined, 'Edit Profile', 'Update your personal information', onTap: () => context.go('/settings/edit-profile')),
        ]),
      ]),
    ),
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
      // Real login history from the server (was hardcoded sample rows).
      FutureBuilder<List<({String device, String time, IconData icon})>>(
        future: _loadLoginHistory(),
        builder: (context, snap) {
          final rows = snap.data ?? const [];
          return _settingsSection('Login History', [
            if (snap.connectionState != ConnectionState.done)
              const Padding(padding: EdgeInsets.all(20),
                child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))))
            else if (rows.isEmpty)
              Padding(padding: const EdgeInsets.all(16),
                child: Text('No login history yet — entries appear from your next sign-in.',
                    style: TextStyle(fontSize: 13, color: context.textSub)))
            else
              ...rows.map((r) => _loginHistoryItem(r.device, r.time, r.icon)),
          ]);
        },
      ),
    ]),
  );

  Future<List<({String device, String time, IconData icon})>> _loadLoginHistory() async {
    try {
      final r = await apiClient.get('/auth/sessions');
      final list = (r['data'] as List?) ?? const [];
      const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      final now = DateTime.now();
      return list.whereType<Map>().map((s) {
        final ua = (s['userAgent'] as String? ?? '').toLowerCase();
        String device;
        IconData icon;
        if (ua.contains('dart') || ua.contains('dio')) {
          device = 'SKET App · Android'; icon = Icons.phone_android_outlined;
        } else {
          final browser = ua.contains('edg') ? 'Edge'
              : ua.contains('chrome') ? 'Chrome'
              : ua.contains('firefox') ? 'Firefox'
              : ua.contains('safari') ? 'Safari' : 'Browser';
          if (ua.contains('android')) { device = '$browser · Android'; icon = Icons.phone_android_outlined; }
          else if (ua.contains('iphone') || ua.contains('ipad')) { device = '$browser · iPhone'; icon = Icons.phone_iphone_outlined; }
          else if (ua.contains('windows')) { device = '$browser · Windows'; icon = Icons.computer_outlined; }
          else if (ua.contains('mac')) { device = '$browser · Mac'; icon = Icons.computer_outlined; }
          else { device = ua.isEmpty ? 'Unknown device' : browser; icon = Icons.devices_outlined; }
        }
        String time = '';
        final dt = DateTime.tryParse(s['createdAt'] as String? ?? '')?.toLocal();
        if (dt != null) {
          final h12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
          final ampm = dt.hour >= 12 ? 'PM' : 'AM';
          final hm = '$h12:${dt.minute.toString().padLeft(2, '0')} $ampm';
          final isToday = dt.year == now.year && dt.month == now.month && dt.day == now.day;
          final yd = now.subtract(const Duration(days: 1));
          final isYesterday = dt.year == yd.year && dt.month == yd.month && dt.day == yd.day;
          time = isToday ? 'Today, $hm' : isYesterday ? 'Yesterday, $hm' : '${dt.day} ${m[dt.month - 1]}, $hm';
        }
        return (device: device, time: time, icon: icon);
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  Widget _loginHistoryItem(String device, String time, IconData icon) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    leading: Container(width: 38, height: 38,
      decoration: BoxDecoration(color: context.surface2, shape: BoxShape.circle),
      child: Icon(icon, size: 18, color: context.textSub)),
    title: Text(device, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
    subtitle: Text(time, style: TextStyle(fontSize: 12.5, color: context.textSub)),
  );

  // ── Tab: Payments (Razorpay) — SUPER_ADMIN only server-side ─────
  Widget _paymentsTab() {
    if (_payLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_payForbidden) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.lock_outline, size: 40, color: context.textHint),
          const SizedBox(height: 12),
          Text('You do not have permission to view payment settings',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.textSub)),
        ]),
      ));
    }
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 40),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(14),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: context.surface2, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _brand600.withValues(alpha: 0.3))),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.info_outline, color: _brand600, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(
              'Get your API keys from the Razorpay Dashboard → Settings → API Keys.\nNever share your Key Secret or Webhook Secret publicly.',
              style: TextStyle(fontSize: 12.5, color: context.textSub, fontWeight: FontWeight.w600, height: 1.4))),
          ]),
        ),
        _settingsSection('Razorpay Credentials', [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: _payField(_payKeyIdCtrl, 'Key ID', Icons.vpn_key_outlined, hint: 'rzp_test_XXXXXXXXXXXXXXXXXX'),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: _payField(_paySecretCtrl, 'Key Secret', Icons.lock_outline,
              obscure: _payObscureSecret,
              onToggle: () => setState(() => _payObscureSecret = !_payObscureSecret)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: _payField(_payWebhookCtrl, 'Webhook Secret', Icons.webhook_outlined,
              obscure: _payObscureWebhook,
              onToggle: () => setState(() => _payObscureWebhook = !_payObscureWebhook)),
          ),
        ]),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          onPressed: _paySaving ? null : _savePayments,
          icon: _paySaving
            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.save_outlined, size: 16),
          label: const Text('Save Credentials'),
          style: ElevatedButton.styleFrom(
            backgroundColor: _brand600, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        )),
      ]),
    );
  }

  Widget _payField(TextEditingController ctrl, String label, IconData icon,
      {String? hint, bool obscure = false, VoidCallback? onToggle}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.textSub)),
      const SizedBox(height: 6),
      TextField(
        controller: ctrl,
        obscureText: obscure,
        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, fontFamily: 'monospace', color: context.textPrimary),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, size: 18, color: _brand600),
          hintText: hint ?? '••••••••••••••••••••',
          hintStyle: TextStyle(fontSize: 12, color: context.textHint),
          filled: true, fillColor: context.surface2,
          suffixIcon: onToggle == null ? null : IconButton(
            icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18, color: context.textHint),
            onPressed: onToggle),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _brand600, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      ),
      const SizedBox(height: 8),
    ],
  );

  // ── Read-only profile for logged-in team members ──────────────
  Widget _memberProfile(BuildContext context, double top) {
    final r = currentLoggedInRole;
    final name = (r?.name.isNotEmpty ?? false) ? r!.name : 'Team Member';
    final email = r?.email ?? '';
    final role = (r?.roleName.isNotEmpty ?? false) ? r!.roleName : 'Team Member';
    final parts = name.trim().split(RegExp(r'\s+'));
    final initials = ((parts.isNotEmpty && parts[0].isNotEmpty ? parts[0][0] : '') +
        (parts.length > 1 && parts[1].isNotEmpty ? parts[1][0] : '')).toUpperCase();
    return Scaffold(
      body: Column(children: [
        Container(
          color: context.headerBg,
          padding: EdgeInsets.fromLTRB(18, top + 14, 18, 16),
          child: Row(children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: () => context.go('/dashboard'),
              padding: EdgeInsets.zero, constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 10),
            Text('My Profile', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: context.textPrimary)),
          ]),
        ),
        Expanded(child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 40),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Column(children: [
              Container(
                width: 88, height: 88,
                decoration: const BoxDecoration(shape: BoxShape.circle,
                  gradient: LinearGradient(colors: [Color(0xFFE07C1F), Color(0xFFFFB25E)])),
                child: Center(child: Text(initials.isEmpty ? 'U' : initials, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800))),
              ),
              const SizedBox(height: 12),
              Text(name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(role, style: const TextStyle(fontSize: 13, color: _brand600, fontWeight: FontWeight.w700)),
            ])),
            const SizedBox(height: 24),
            _settingsSection('Personal Information', [
              _settingsItem(Icons.person_outline, 'Full Name', name),
              _settingsItem(Icons.email_outlined, 'Email', email.isEmpty ? '—' : email),
              _settingsItem(Icons.phone_outlined, 'Phone', '—'),
              _settingsItem(Icons.work_outline, 'Role', role),
            ]),
            ..._myDocumentsSectionWidgets(),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () async { await logoutSession(); if (context.mounted) context.go('/login'); },
              child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(color: _coral100, borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: _coral500.withValues(alpha: 0.3))),
                child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.logout_rounded, color: _coral500, size: 20),
                  SizedBox(width: 10),
                  Text('Log Out', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _coral500)),
                ])),
            ),
          ]),
        )),
      ]),
    );
  }

  // ── My Documents section (read-only team-member profile) ──────
  List<Widget> _myDocumentsSectionWidgets() {
    final backendId = currentLoggedInRole?.backendId;
    if (backendId == null) return const [];
    final items = <Widget>[
      if (_myDocsLoading)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Center(child: SizedBox(width: 22, height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.5, color: _brand600))),
        )
      else if (_myDocs.isEmpty)
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          title: Text('No documents uploaded yet', style: TextStyle(fontSize: 13, color: context.textSub, fontWeight: FontWeight.w600)),
        )
      else
        ..._myDocs.map(_myDocumentRow),
      _settingsItem(Icons.upload_file_outlined, 'Upload Document',
          _myDocsUploading ? 'Uploading…' : 'Add a new file to your profile',
          onTap: _myDocsUploading ? null : _uploadMyDocument),
    ];
    return [
      const SizedBox(height: 24),
      _settingsSection('My Documents', items),
    ];
  }

  Widget _myDocumentRow(_MyDoc d) {
    final viewing = _myDocsViewingId == d.id;
    final deleting = _myDocsDeletingId == d.id;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(width: 38, height: 38,
        decoration: BoxDecoration(color: context.surface2, shape: BoxShape.circle),
        child: Icon(Icons.insert_drive_file_outlined, size: 18, color: context.textSub)),
      title: Text(d.fileName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.textPrimary),
        overflow: TextOverflow.ellipsis),
      subtitle: Text(d.category, style: TextStyle(fontSize: 12.5, color: context.textSub)),
      trailing: deleting
        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: _coral500))
        : Row(mainAxisSize: MainAxisSize.min, children: [
            GestureDetector(
              onTap: viewing ? null : () => _viewMyDocument(d),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: viewing
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: _brand600))
                  : const Text('View', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _brand600)),
              ),
            ),
            GestureDetector(
              onTap: () => _confirmDeleteMyDocument(d),
              child: const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.delete_outline, size: 18, color: _coral500)),
            ),
          ]),
    );
  }

  // ── Helper: Section with title + card ─────────────────────────
  Widget _settingsSection(String title, List<Widget> items) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title.toUpperCase(), style: TextStyle(
        fontSize: 11, fontWeight: FontWeight.w800,
        color: context.textSub, letterSpacing: 0.8)),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.border),
        ),
        child: Column(children: items.asMap().entries.map((e) => Column(children: [
          e.value,
          if (e.key < items.length - 1) Divider(height: 1, color: context.border),
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
          color: isDestructive ? _coral100 : context.surface2,
          shape: BoxShape.circle),
        child: Icon(icon, size: 18,
          color: isDestructive ? _coral500 : context.textSub)),
      title: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
        color: isDestructive ? _coral500 : context.textPrimary)),
      subtitle: Text(subtitle, style: TextStyle(fontSize: 12.5, color: context.textSub)),
      trailing: onTap != null ? Icon(Icons.chevron_right, size: 18, color: context.textSub) : null,
    );
}

// Document metadata for the logged-in team member's own uploads
// (GET/POST/DELETE /users/:id/documents — see settings_screen.dart's
// "My Documents" section on the read-only member profile view).
class _MyDoc {
  _MyDoc({required this.id, required this.category, required this.fileName, this.mimeType});
  final String id, category, fileName;
  final String? mimeType;
  factory _MyDoc.fromJson(Map<String, dynamic> j) => _MyDoc(
    id: j['id'] as String, category: j['category'] as String,
    fileName: j['fileName'] as String, mimeType: j['mimeType'] as String?);
}
