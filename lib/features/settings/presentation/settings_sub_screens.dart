import 'dart:convert';
import 'dart:typed_data';
import 'package:excel/excel.dart' as xl;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/utils/app_launcher.dart';
import '../../../core/utils/native_file_saver.dart';
import '../../../core/utils/open_bytes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/api_client.dart';
import '../../../core/widgets/photo_picker_widget.dart';
import '../../../core/auth/role_auth.dart';
import '../profile_store.dart';
import '../../students/presentation/students_screen.dart' show demoCentres;
import '../../students/student_lookups.dart';
import 'package:saksham_app/core/ui/ui.dart';

// ── brand palette ────────────────────────────────────────────────
const _brand600   = Color(0xFFFF9933);
const _brand100   = Color(0xFFFFE8CC);
const _amber600   = Color(0xFFE0921A);
const _coral500   = Color(0xFFF2685E);
const _coral100   = Color(0xFFFFE3DF);
const _sky500     = Color(0xFF2D9CDB);
const _sky100     = Color(0xFFDCEFFB);
const _violet500  = Color(0xFF7C6CF0);

// ── Riverpod provider: legal content from Admin Panel API ────────
// Replace base URL with real Master Admin API endpoint in production.
const _legalApiBaseUrl = 'https://api.sakshamfoundation.org/v1/legal';

final legalContentProvider = FutureProvider.family<Map<String, String>, String>(
  (ref, key) async {
    try {
      final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 5)));
      final res = await dio.get('$_legalApiBaseUrl/$key');
      if (res.statusCode == 200 && res.data is Map) {
        final data = res.data as Map;
        return {'title': data['title'] ?? key, 'body': data['body'] ?? ''};
      }
    } catch (_) {
      // Network unavailable — fall through to static content
    }
    return {'title': '', 'body': ''};
  },
);

// ── shared helpers ───────────────────────────────────────────────
// Compact page header: back, title + one-line subtitle, optional primary
// action on the right (kept out of a floating button so toasts never cover it).
Widget _buildHeader(BuildContext ctx, String title, {String? sub, Widget? action}) =>
  Container(
    decoration: BoxDecoration(color: ctx.headerBg, border: Border(bottom: BorderSide(color: ctx.border))),
    padding: EdgeInsets.fromLTRB(8, MediaQuery.of(ctx).padding.top + 10, 16, 10),
    child: Row(children: [
      IconButton(
        tooltip: 'Back to Settings',
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
        onPressed: () => ctx.go('/settings'),
      ),
      const SizedBox(width: 2),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.2)),
        if (sub != null)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: Text(sub, key: ValueKey(sub), maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, color: ctx.textSub, fontWeight: FontWeight.w500)),
          ),
      ])),
      if (action != null) ...[const SizedBox(width: 8), action],
    ]),
  );

// Primary form action: right-aligned and compact on wide screens, full
// width on phones.
Widget _formAction(BuildContext ctx, {
  required String label, required VoidCallback? onPressed,
  String? busyLabel, bool loading = false, IconData? icon,
  AppButtonVariant variant = AppButtonVariant.primary,
}) {
  final wide = isWideLayout(ctx);
  return Align(
    alignment: Alignment.centerRight,
    child: AppButton(label: label, busyLabel: busyLabel, loading: loading, icon: icon,
        variant: variant, expand: !wide, onPressed: onPressed),
  );
}

Widget _buildCard(BuildContext ctx, {required Widget child}) => Container(
  margin: const EdgeInsets.symmetric(horizontal: 18),
  decoration: BoxDecoration(
    color: ctx.cardBg, borderRadius: BorderRadius.circular(18),
    border: Border.all(color: ctx.border),
    boxShadow: const [BoxShadow(color: Color(0x080D2822), blurRadius: 6, offset: Offset(0, 2))],
  ),
  child: child,
);

Widget _buildRow(BuildContext ctx, String label, {
  String? value, IconData? icon, Color? fg,
  bool last = false, VoidCallback? onTap, Widget? trailing,
}) => GestureDetector(
  behavior: HitTestBehavior.opaque,
  onTap: onTap,
  child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: last ? null : BoxDecoration(border: Border(bottom: BorderSide(color: ctx.border))),
    child: Row(children: [
      if (icon != null) ...[Icon(icon, color: fg ?? ctx.textSub, size: 20), const SizedBox(width: 12)],
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
        if (value != null) Text(value, style: TextStyle(fontSize: 12.5, color: ctx.textHint, fontWeight: FontWeight.w500)),
      ])),
      trailing ?? Icon(Icons.chevron_right, color: ctx.textHint, size: 18),
    ]),
  ),
);

Widget _buildSectionLabel(BuildContext ctx, String t) => Padding(
  padding: const EdgeInsets.fromLTRB(20, 0, 0, 8),
  child: Text(t.toUpperCase(),
    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: ctx.textHint, letterSpacing: 0.8)));

// All feedback goes through the shared top-right toast. The tone is inferred
// from the wording unless [error] is given explicitly.
final _errorWords = RegExp(
  r'\b(fail|failed|could not|couldn.t|unable|error|invalid|required|expired|denied|only|not allowed|check your connection)\b',
  caseSensitive: false,
);
void _snack(BuildContext ctx, String msg, {bool? error}) {
  final clean = msg.replaceFirst(RegExp(r'^✓\s*'), '');
  final isError = error ?? _errorWords.hasMatch(clean);
  if (isError) {
    AppToast.error(ctx, clean);
  } else {
    AppToast.success(ctx, clean);
  }
}

// Friendly message for a failed POST /users (team-member creation).
String _createUserErrorMsg(Object e) {
  if (e is DioException) {
    final code = e.response?.statusCode;
    final data = e.response?.data;
    final serverMsg = (data is Map && data['message'] != null) ? data['message'].toString() : null;
    if (code == 409) return serverMsg ?? 'That email is already registered';
    if (code == 400) return serverMsg ?? 'Invalid details (password needs 8+ characters)';
    if (code == 401 || code == 403) return 'Admin session expired — please log out and log in as admin again';
    return serverMsg ?? 'Could not create the member on the server';
  }
  return 'Could not reach the server. Check your connection.';
}

// ════════════════════════════════════════════════════════════════
// 1. EDIT PROFILE
// ════════════════════════════════════════════════════════════════
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditProfileState();
}

class _EditProfileState extends State<EditProfileScreen> {
  late final ProfileData _p = adminProfile.value;
  late final _name  = TextEditingController(text: _p.name);
  late final _email = TextEditingController(text: _p.email);
  late final _phone = TextEditingController(text: _p.phone);
  late final _role  = TextEditingController(text: _p.role);
  late final _org   = TextEditingController(text: _p.org);
  late final _bio   = TextEditingController(text: _p.bio);
  Uint8List? _photo;
  bool _photoChanged = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _photo = _p.photoBytes;
  }

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _role, _org, _bio]) c.dispose();
    super.dispose();
  }

  void _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    await Future.delayed(const Duration(milliseconds: 400));
    var updated = adminProfile.value.copyWith(
      name:  _name.text.trim().isEmpty ? null : _name.text.trim(),
      email: _email.text.trim(),
      phone: _phone.text.trim(),
      role:  _role.text.trim().isEmpty ? null : _role.text.trim(),
      org:   _org.text.trim().isEmpty  ? null : _org.text.trim(),
      bio:   _bio.text.trim(),
    );
    // Only touch the photo field if the user actually changed it.
    if (_photoChanged) updated = updated.copyWith(photoBase64: encodePhoto(_photo));
    updateProfile(updated);
    // Persist to the backend too — session restore re-reads the server's copy
    // on every reload, so a local-only edit used to silently revert.
    var synced = true;
    String syncError = '';
    try {
      await apiClient.patch('/users/me/profile', {
        'name': updated.name,
        'phone': updated.phone,
        if (_photoChanged) 'avatar': encodePhoto(_photo) ?? '',
      });
    } catch (e) {
      synced = false;
      syncError = ApiClient.errorMessage(e);
    }
    if (!mounted) return;
    setState(() => _saving = false);
    if (synced) {
      AppToast.success(context, 'Profile updated');
    } else {
      AppToast.warning(context, 'Saved on this device only', detail: 'Could not sync to the server — $syncError');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(children: [
      _buildHeader(context, 'Edit Profile', sub: 'Update your personal information'),
      Expanded(child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: PhotoPickerCircle(
            size: 88, label: '', initials: _p.initials, initialImage: _photo,
            placeholderAsset: brandLogoAsset,
            onImageChanged: (bytes) { _photo = bytes; _photoChanged = true; },
          )),
          const SizedBox(height: 24),
          _buildSectionLabel(context, 'Basic Info'),
          _buildCard(context, child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
            _field('Full Name',  _name,  Icons.person_outline),
            _field('Email',      _email, Icons.email_outlined,  keyboardType: TextInputType.emailAddress),
            _field('Mobile',     _phone, Icons.phone_outlined,  keyboardType: TextInputType.phone),
          ]))),
          const SizedBox(height: 16),
          _buildSectionLabel(context, 'Professional'),
          _buildCard(context, child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
            _field('Role / Designation', _role, Icons.badge_outlined),
            _field('Organisation',       _org,  Icons.business_outlined),
            _field('About',              _bio,  Icons.info_outline, maxLines: 3),
          ]))),
          const SizedBox(height: 20),
          _formAction(context, label: 'Save Changes', busyLabel: 'Saving…', loading: _saving, onPressed: _save),
        ]),
      )),
    ]),
  );

  Widget _field(String label, TextEditingController ctrl, IconData icon, {TextInputType? keyboardType, int maxLines = 1}) =>
    Padding(padding: const EdgeInsets.only(bottom: 14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: context.textSub)),
      const SizedBox(height: 6),
      TextField(controller: ctrl, keyboardType: keyboardType, maxLines: maxLines,
        style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          prefixIcon: Icon(icon, size: 18, color: _brand600),
          filled: true, fillColor: context.surface2,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _brand600, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        )),
    ]));
}

// ════════════════════════════════════════════════════════════════
// 2. SECURITY & PIN
// ════════════════════════════════════════════════════════════════
class SecurityPinScreen extends StatefulWidget {
  const SecurityPinScreen({super.key});
  @override
  State<SecurityPinScreen> createState() => _SecurityPinState();
}

class _SecurityPinState extends State<SecurityPinScreen> {
  bool _bioEnabled = false;
  bool _twoFactor  = false;

  @override
  void dispose() { super.dispose(); }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(children: [
      _buildHeader(context, 'Security & PIN', sub: 'Protect your account'),
      Expanded(child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(16), margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFE07C1F), Color(0xFFFFB25E)]), borderRadius: BorderRadius.circular(18)),
            child: Row(children: [
              const Icon(Icons.shield_outlined, color: Colors.white, size: 32),
              const SizedBox(width: 14),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Account Secured', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                Text('Biometric & 2FA protection', style: TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w500)),
              ])),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                child: const Text('Active', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12))),
            ]),
          ),
          _buildSectionLabel(context, 'Biometric Security'),
          _buildCard(context, child: Column(children: [
            _buildRow(context, 'Biometric Login', value: 'Use fingerprint / face ID', icon: Icons.fingerprint, fg: _violet500, last: true,
              trailing: Switch(value: _bioEnabled, onChanged: (v) => _toggleBiometric(context, v), activeColor: _brand600)),
          ])),
          const SizedBox(height: 16),
          _buildSectionLabel(context, 'Account Security'),
          _buildCard(context, child: Column(children: [
            _buildRow(context, 'Two-Factor Auth', value: 'OTP via SMS on login', icon: Icons.sms_outlined, fg: _sky500,
              trailing: Switch(value: _twoFactor, onChanged: (v) => _toggleTwoFactor(context, v), activeColor: _brand600)),
            _buildRow(context, 'Login History', value: 'Last login: Today 09:24 AM', icon: Icons.history, fg: context.textSub, last: true,
              onTap: () => _showLoginHistory(context)),
          ])),
          const SizedBox(height: 16),
          _buildSectionLabel(context, 'Danger Zone'),
          _buildCard(context, child: _buildRow(context, 'Revoke All Sessions', value: 'Sign out from all devices',
            icon: Icons.logout_rounded, fg: _coral500, last: true,
            onTap: () => _confirmRevoke(context))),
        ]),
      )),
    ]),
  );

  void _toggleBiometric(BuildContext context, bool enable) {
    if (enable) {
      AppConfirm.show(
        context,
        title: 'Enable biometric login?',
        message: 'Use your fingerprint or face ID to log in quickly. Touch the fingerprint sensor on your device to confirm.',
        confirmLabel: 'Enable',
        busyLabel: 'Enabling…',
        destructive: false,
      ).then((ok) {
        if (!ok || !mounted) return;
        setState(() => _bioEnabled = true);
        _snack(this.context, 'Biometric login enabled');
      });
    } else {
      setState(() => _bioEnabled = false);
      _snack(context, 'Biometric login disabled');
    }
  }

  void _toggleTwoFactor(BuildContext context, bool enable) {
    if (enable) {
      final phoneCtrl = TextEditingController();
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Enable Two-Factor Auth', style: TextStyle(fontWeight: FontWeight.w800)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('Enter the mobile number to receive OTP on every login:', style: TextStyle(fontSize: 13.5)),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.phone_outlined, size: 18),
                hintText: '+91 98765 43210',
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
            ),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() => _twoFactor = true);
                _snack(context, '2FA enabled — OTP will be sent to ${phoneCtrl.text.isEmpty ? "your number" : phoneCtrl.text}');
              },
              child: const Text('Enable', style: TextStyle(color: _brand600, fontWeight: FontWeight.w800))),
          ],
        ),
      );
    } else {
      setState(() => _twoFactor = false);
      _snack(context, 'Two-factor authentication disabled');
    }
  }

  void _showLoginHistory(BuildContext context) {
    final history = [
      {'date': 'Today, 09:24 AM',       'device': 'OPPO A9 2020',  'loc': 'Bengaluru, KA', 'ok': true},
      {'date': 'Yesterday, 11:42 PM',   'device': 'Windows 11 PC', 'loc': 'Bengaluru, KA', 'ok': true},
      {'date': '15 Jun 2026, 03:10 PM', 'device': 'OPPO A9 2020',  'loc': 'Bengaluru, KA', 'ok': true},
      {'date': '14 Jun 2026, 08:50 AM', 'device': 'OPPO A9 2020',  'loc': 'Bengaluru, KA', 'ok': true},
      {'date': '12 Jun 2026, 02:15 PM', 'device': 'Unknown Device', 'loc': 'Chennai, TN',  'ok': false},
    ];
    showAppSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.6),
        decoration: BoxDecoration(color: ctx.cardBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(child: SheetHandle(margin: const EdgeInsets.symmetric(vertical: 12))),
          const Text('Login History', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          Text('Last 5 login events', style: TextStyle(fontSize: 12.5, color: ctx.textHint, fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          Flexible(child: ListView.separated(
            shrinkWrap: true,
            itemCount: history.length,
            separatorBuilder: (_, __) => Divider(height: 1, color: ctx.border),
            itemBuilder: (_, i) {
              final h = history[i];
              final ok = h['ok'] as bool;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(children: [
                  Container(width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: (ok ? _brand600 : _coral500).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10)),
                    child: Icon(ok ? Icons.check_circle_outline : Icons.cancel_outlined,
                      color: ok ? _brand600 : _coral500, size: 18)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(h['date'] as String, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                    Text('${h['device']}  ·  ${h['loc']}',
                      style: TextStyle(fontSize: 12, color: ctx.textHint, fontWeight: FontWeight.w500)),
                  ])),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: (ok ? _brand600 : _coral500).withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(6)),
                    child: Text(ok ? 'Success' : 'Failed',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ok ? _brand600 : _coral500))),
                ]),
              );
            },
          )),
        ]),
      ),
    );
  }

  void _confirmRevoke(BuildContext context) {
    AppConfirm.show(
      context,
      title: 'Revoke all sessions?',
      message: 'This will sign you out from all devices, including this one. You will need to log in again.',
      confirmLabel: 'Revoke All',
      busyLabel: 'Revoking…',
    ).then((ok) {
      if (ok && mounted) _snack(this.context, 'All sessions revoked — please log in again');
    });
  }
}

// ════════════════════════════════════════════════════════════════
// 3. LINKED DEVICES
// ════════════════════════════════════════════════════════════════
class LinkedDevicesScreen extends StatefulWidget {
  const LinkedDevicesScreen({super.key});
  @override
  State<LinkedDevicesScreen> createState() => _LinkedDevicesState();
}

class _LinkedDevicesState extends State<LinkedDevicesScreen> {
  final List<Map<String, dynamic>> _devices = [
    {'id': 'd1', 'name': 'OPPO A9 2020',  'type': 'Android',     'icon': Icons.phone_android, 'color': _brand600, 'last': 'Active now',         'current': true},
    {'id': 'd2', 'name': 'Windows 11 PC', 'type': 'Web Browser', 'icon': Icons.computer,      'color': _sky500,   'last': 'Yesterday 11:42 PM', 'current': false},
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(children: [
      _buildHeader(context, 'Linked Devices', sub: '${_devices.length} active sessions'),
      Expanded(child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(14), margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: _sky100, borderRadius: BorderRadius.circular(14), border: Border.all(color: _sky500.withValues(alpha: 0.25))),
            child: Row(children: [
              const Icon(Icons.info_outline, color: _sky500, size: 18), const SizedBox(width: 10),
              Expanded(child: Text('Devices logged into your SKET account. Revoke any you don\'t recognise.',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: context.textSub))),
            ])),
          _buildSectionLabel(context, 'Active Sessions'),
          _buildCard(context, child: Column(children: _devices.asMap().entries.map((e) {
            final i = e.key; final d = e.value;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: i < _devices.length - 1 ? BoxDecoration(border: Border(bottom: BorderSide(color: context.border))) : null,
              child: Row(children: [
                Container(width: 42, height: 42,
                  decoration: BoxDecoration(color: (d['color'] as Color).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                  child: Icon(d['icon'] as IconData, color: d['color'] as Color, size: 22)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(d['name'] as String, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                    if (d['current'] as bool) ...[
                      const SizedBox(width: 6),
                      Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(color: _brand100, borderRadius: BorderRadius.circular(6)),
                        child: const Text('This device', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: _brand600))),
                    ],
                  ]),
                  Text('${d['type']}  ·  ${d['last']}', style: TextStyle(fontSize: 12, color: context.textHint, fontWeight: FontWeight.w500)),
                ])),
                if (!(d['current'] as bool)) TextButton(
                  onPressed: () { setState(() => _devices.removeWhere((x) => x['id'] == d['id'])); _snack(context, 'Device removed'); },
                  style: TextButton.styleFrom(foregroundColor: _coral500, padding: const EdgeInsets.symmetric(horizontal: 8)),
                  child: const Text('Revoke', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                ),
              ]),
            );
          }).toList())),
          const SizedBox(height: 20),
          _formAction(context,
            label: 'Sign Out All Other Devices', icon: Icons.logout_rounded, variant: AppButtonVariant.destructive,
            onPressed: () { setState(() => _devices.removeWhere((d) => !(d['current'] as bool))); _snack(context, 'All other devices removed'); }),
        ]),
      )),
    ]),
  );
}

// ════════════════════════════════════════════════════════════════
// 4. TEAM MEMBERS
// ════════════════════════════════════════════════════════════════
class TeamMembersScreen extends StatefulWidget {
  const TeamMembersScreen({super.key});
  @override
  State<TeamMembersScreen> createState() => _TeamMembersState();
}

class _TeamMembersState extends State<TeamMembersScreen> {
  static const _avatarPalette = [_brand600, _violet500, _sky500, _amber600, _coral500];
  static Color _memberColor(String seed) {
    int h = 0;
    for (final c in seed.codeUnits) { h = ((h * 31) + c) & 0xFFFFFFFF; }
    return _avatarPalette[h % _avatarPalette.length];
  }

  @override
  void initState() {
    super.initState();
    _loadPendingMembers();
    _syncMembersFromBackend();
  }

  // The server is the source of truth for accounts. Reconcile the local
  // mirror (appRoles): drop entries whose email no longer exists server-side
  // (deleted elsewhere → they showed as ghost members forever) and add ones
  // created on other devices.
  Future<void> _syncMembersFromBackend() async {
    try {
      final r = await apiClient.get('/users', params: {'limit': '100', 'page': '1'});
      final inner = r['data'];
      final list = inner is Map ? (inner['data'] as List? ?? const []) : (inner is List ? inner : const []);
      // Deleted members are only deactivated server-side — skip them, or they
      // reappear in the list as "Active" on the next visit.
      final backend = list.whereType<Map>().map((m) => m.cast<String, dynamic>())
          .where((u) => u['isActive'] != false).toList();
      final backendEmails = backend.map((u) => (u['email'] as String? ?? '').toLowerCase()).toSet();
      final adminEmail = adminProfile.value.email.toLowerCase();

      appRoles.removeWhere((role) =>
          role.email.toLowerCase() != adminEmail &&
          !backendEmails.contains(role.email.toLowerCase()));

      for (final u in backend) {
        final email = (u['email'] as String? ?? '');
        if (email.isEmpty || email.toLowerCase() == adminEmail) continue;
        final role = (u['role'] as String? ?? 'STAFF');
        if (role == 'SUPER_ADMIN' || role == 'ADMIN') continue;
        final csv = u['modules'] as String?;
        final modules = (csv != null && csv.trim().isNotEmpty)
            ? csv.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toSet()
            : <String>{};
        final existing = appRoles.where((r0) => r0.email.toLowerCase() == email.toLowerCase()).firstOrNull;
        if (existing == null) {
          appRoles.add(AppRole(
            name: u['name'] as String? ?? email,
            email: email,
            password: '',
            roleName: roleNameForModules(modules) ?? role,
            modules: modules,
            backendId: u['id'] as String?,
          ));
        } else {
          // The server's modules are what the member actually gets.
          existing.backendId ??= u['id'] as String?;
          if (modules.isNotEmpty && !(existing.modules.length == modules.length && existing.modules.containsAll(modules))) {
            existing.modules = modules;
            existing.roleName = roleNameForModules(modules) ?? existing.roleName;
          }
        }
      }
      saveRoles();
      if (mounted) setState(() {});
    } catch (_) {
      // Not an admin / offline — keep the local list as-is.
    }
  }

  // The team = the admin owner (row 0, self) + every persisted login account
  // (appRoles). Editing this list changes who can actually log in & what they see.
  // Team members below the owner — everyone in appRoles except the admin.
  List<AppRole> get _memberRoles =>
      appRoles.where((r) => r.email.toLowerCase() != adminProfile.value.email.toLowerCase()).toList();

  List<Map<String, dynamic>> get _members => [
    {'name': adminProfile.value.name, 'role': 'Super Admin', 'email': adminProfile.value.email, 'status': 'Active', 'color': _brand600, 'self': true},
    for (final r in _memberRoles)
      {
        'name':   r.name,
        'role':   r.roleName.isNotEmpty ? r.roleName : 'Custom',
        'email':  r.email,
        'status': r.active ? 'Active' : 'Inactive',
        'color':  _memberColor(r.name),
        'self':   false,
      },
  ];

  // The current (non-Super-Admin) user's own "Create User" submissions still
  // awaiting approval — otherwise an invited member they just created simply
  // disappears until a Super Admin approves it. Rendered separately (below
  // the real members) since they have no backend id yet — no documents/remove
  // actions make sense for them.
  List<Map<String, dynamic>> _pendingMembers = [];

  Future<void> _loadPendingMembers() async {
    try {
      final r = await apiClient.get('/approvals/mine');
      final inner = r['data'];
      final reqs = inner is List
          ? inner
          : (inner is Map ? (inner['data'] as List<dynamic>? ?? const []) : const []);
      final userReqs = reqs.whereType<Map<String, dynamic>>().where((q) =>
          (q['module'] as String?)?.toLowerCase() == 'users' &&
          (q['action'] as String?)?.toUpperCase() == 'CREATE' &&
          (q['status'] as String?)?.toUpperCase() == 'PENDING').toList();
      final pending = userReqs.map((q) {
        final payload = (q['payload'] as Map?)?.cast<String, dynamic>() ?? const {};
        final name = payload['name'] as String? ?? 'Unknown';
        return {
          'name': name,
          'role': payload['role'] as String? ?? 'Custom',
          'email': payload['email'] as String? ?? '',
          'color': _memberColor(name),
        };
      }).toList();
      if (mounted) setState(() => _pendingMembers = pending);
    } catch (_) {}
  }

  void _showInviteSheet() {
    final nameCtrl     = TextEditingController();
    final emailCtrl    = TextEditingController();
    final passwordCtrl = TextEditingController();
    final roleOptions = roleTemplates.map((t) => t['name'] as String).toList();
    String selectedRole = roleOptions.contains('Field Officer')
        ? 'Field Officer'
        : (roleOptions.isNotEmpty ? roleOptions.first : 'Field Officer');
    Map<String, String?> errors = {};
    bool obscurePass = true;
    bool saving = false;

    showAppSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent, useSafeArea: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
        Widget field(TextEditingController ctrl, String label, String hint, {bool required = true, TextInputType keyboard = TextInputType.text, bool obscure = false, VoidCallback? toggleObscure}) => Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: ctx.textSub)),
            if (required) const Text(' *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _coral500)),
          ]),
          const SizedBox(height: 6),
          TextField(
            controller: ctrl, keyboardType: keyboard, obscureText: obscure, enabled: !saving,
            onChanged: (_) { if (errors[label] != null) setSheet(() => errors.remove(label)); },
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: hint, hintStyle: TextStyle(color: ctx.textHint),
              filled: true, fillColor: ctx.surface2, errorText: errors[label],
              suffixIcon: toggleObscure != null ? IconButton(tooltip: obscure ? 'Show password' : 'Hide password', icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18, color: ctx.textHint), onPressed: toggleObscure) : null,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _brand600, width: 1.5)),
              errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _coral500, width: 1.5)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12))),
          const SizedBox(height: 12),
        ]);

        return Container(
          decoration: BoxDecoration(color: ctx.cardBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
          padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: SheetHandle(margin: const EdgeInsets.symmetric(vertical: 12))),
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Create User', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('Give a team member their own login and role.', style: TextStyle(fontSize: 12.5, color: ctx.textSub)),
              ])),
              IconButton(
                tooltip: 'Close',
                icon: Icon(Icons.close_rounded, size: 20, color: ctx.textSub),
                onPressed: saving ? null : () => Navigator.of(ctx).pop(),
              ),
            ]),
            const SizedBox(height: 16),
            field(nameCtrl, 'Full Name', 'e.g. Priya Sharma'),
            field(emailCtrl, 'Email', 'member@saksham.org', keyboard: TextInputType.emailAddress),
            field(passwordCtrl, 'Password', 'Enter password', obscure: obscurePass,
              toggleObscure: () => setSheet(() => obscurePass = !obscurePass)),
            Text('Role', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: ctx.textSub)),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(color: ctx.surface2, borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: DropdownButtonHideUnderline(child: DropdownButton<String>(
                value: selectedRole.isEmpty ? null : selectedRole,
                hint: Text('Create a role first', style: TextStyle(fontSize: 14, color: ctx.textHint, fontWeight: FontWeight.w600)),
                isExpanded: true,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                dropdownColor: ctx.cardBg,
                borderRadius: BorderRadius.circular(12),
                items: roleOptions.map((r) => DropdownMenuItem(value: r,
                  child: Text(r, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ctx.textPrimary)))).toList(),
                onChanged: saving ? null : (v) { if (v != null) setSheet(() => selectedRole = v); },
              )),
            ),
            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              AppButton(label: 'Cancel', variant: AppButtonVariant.secondary,
                  onPressed: saving ? null : () => Navigator.of(ctx).pop()),
              const SizedBox(width: 8),
              AppButton(
              label: 'Create User',
              busyLabel: 'Creating…',
              loading: saving,
              onPressed: () async {
                if (saving) return;
                final name     = nameCtrl.text.trim();
                final email    = emailCtrl.text.trim();
                final password = passwordCtrl.text;
                final newErrors = <String, String?>{};
                if (name.isEmpty)  newErrors['Full Name'] = 'Name is required';
                if (email.isEmpty) newErrors['Email']     = 'Email is required';
                else if (!email.contains('@')) newErrors['Email'] = 'Enter a valid email';
                if (password.isEmpty) newErrors['Password'] = 'Password is required';
                else if (password.length < 8) newErrors['Password'] = 'Min 8 characters';
                if (newErrors.isNotEmpty) { setSheet(() => errors = newErrors); return; }
                if (selectedRole.isEmpty) { if (mounted) AppToast.warning(context, 'Create a role in Manage Roles first'); return; }

                final modules = modulesForRoleName(selectedRole);
                final backendRole = selectedRole.toLowerCase() == 'admin' ? 'ADMIN' : 'STAFF';

                // Create on the backend first so the account persists server-side
                // and works on any device/browser.
                String? backendUserId;
                setSheet(() => saving = true);
                try {
                  final res = await apiClient.post('/users', {
                    'name': name, 'email': email, 'password': password,
                    'role': backendRole, 'modules': modules.join(','),
                  });
                  // Non-Super-Admins: queued for approval — don't add the member yet.
                  if ((res['meta'] as Map?)?['pendingApproval'] == true) {
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) _snack(context, 'Submitted for Super Admin approval', error: false);
                    _loadPendingMembers();
                    return;
                  }
                  backendUserId = ((res['data'] as Map?)?.cast<String, dynamic>())?['id'] as String?;
                } catch (e) {
                  if (ctx.mounted) setSheet(() => saving = false);
                  if (mounted) AppToast.error(context, 'Could not create user', detail: _createUserErrorMsg(e));
                  return;
                }

                // Mirror locally so the team list updates instantly + offline login works.
                if (!appRoles.any((r) => r.email.toLowerCase() == email.toLowerCase())) {
                  setState(() => appRoles.add(AppRole(
                    name: name, email: email, password: password,
                    roleName: selectedRole, modules: modules, backendId: backendUserId,
                  )));
                  saveRoles();
                }
                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) _snack(context, '$name created as $selectedRole', error: false);
              },
            ),
            ]),
          ])),
        );
      }),
    );
  }

  // Row 0 is the admin owner; member rows map to _memberRoles[idx - 1].
  // Returns null for the admin row or for a legacy local-only account that
  // was never synced to the backend (no backendId) — Documents needs a real
  // backend user id.
  String? _memberBackendId(int idx) {
    final ai = idx - 1;
    final members = _memberRoles;
    if (ai < 0 || ai >= members.length) return null;
    return members[ai].backendId;
  }

  void _showMemberDocuments(BuildContext context, int idx) {
    final backendId = _memberBackendId(idx);
    if (backendId == null) return;
    final name = _members[idx]['name'] as String;
    showAppSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent, useSafeArea: true,
      builder: (_) => _MemberDocumentsSheet(memberId: backendId, memberName: name),
    );
  }

  // Change a member's role without recreating the account: updates the
  // backend login (role + module access) and the local mirror.
  void _showEditRole(int idx) {
    final ai = idx - 1;
    final members = _memberRoles;
    if (ai < 0 || ai >= members.length) return;
    final member = members[ai];
    final roleOptions = roleTemplates.map((t) => t['name'] as String).toList();
    if (roleOptions.isEmpty) { AppToast.warning(context, 'Create a role in Manage Roles first'); return; }
    String selectedRole = roleOptions.firstWhere(
        (r) => r.toLowerCase() == member.roleName.toLowerCase(),
        orElse: () => roleNameForModules(member.modules) ?? roleOptions.first);
    bool saving = false;

    showAppSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent, useSafeArea: true,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) => Container(
        decoration: BoxDecoration(color: ctx.cardBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: SheetHandle(margin: const EdgeInsets.symmetric(vertical: 12))),
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Edit Role', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text('${member.name}  ·  ${member.email}', style: TextStyle(fontSize: 12.5, color: ctx.textSub), overflow: TextOverflow.ellipsis),
            ])),
            IconButton(
              tooltip: 'Close',
              icon: Icon(Icons.close_rounded, size: 20, color: ctx.textSub),
              onPressed: saving ? null : () => Navigator.of(ctx).pop(),
            ),
          ]),
          const SizedBox(height: 16),
          Text('Role', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: ctx.textSub)),
          const SizedBox(height: 6),
          Container(
            decoration: BoxDecoration(color: ctx.surface2, borderRadius: BorderRadius.circular(12)),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: DropdownButtonHideUnderline(child: DropdownButton<String>(
              value: selectedRole,
              isExpanded: true,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              dropdownColor: ctx.cardBg,
              borderRadius: BorderRadius.circular(12),
              items: roleOptions.map((r) => DropdownMenuItem(value: r,
                child: Text(r, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ctx.textPrimary)))).toList(),
              onChanged: saving ? null : (v) { if (v != null) setSheet(() => selectedRole = v); },
            )),
          ),
          const SizedBox(height: 8),
          Text('Their access changes the next time they open or reload the app.',
              style: TextStyle(fontSize: 12, color: ctx.textHint)),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            AppButton(label: 'Cancel', variant: AppButtonVariant.secondary,
                onPressed: saving ? null : () => Navigator.of(ctx).pop()),
            const SizedBox(width: 8),
            AppButton(
              label: 'Save Role', busyLabel: 'Saving…', loading: saving,
              onPressed: () async {
                if (saving) return;
                final modules = modulesForRoleName(selectedRole);
                final backendRole = selectedRole.toLowerCase() == 'admin' ? 'ADMIN' : 'STAFF';
                var queued = false;
                if (member.backendId != null) {
                  setSheet(() => saving = true);
                  try {
                    final res = await apiClient.patch('/users/${member.backendId}', {
                      'role': backendRole, 'modules': modules.join(','),
                    });
                    queued = (res['meta'] as Map?)?['pendingApproval'] == true;
                  } catch (e) {
                    if (ctx.mounted) setSheet(() => saving = false);
                    if (mounted) AppToast.error(context, 'Could not change role', detail: ApiClient.errorMessage(e));
                    return;
                  }
                }
                if (ctx.mounted) Navigator.pop(ctx);
                if (!mounted) return;
                if (queued) {
                  _snack(context, 'Role change submitted for Super Admin approval', error: false);
                  return;
                }
                setState(() { member.roleName = selectedRole; member.modules = modules; });
                saveRoles();
                _snack(context, '${member.name} is now $selectedRole', error: false);
              },
            ),
          ]),
        ]),
      )),
    );
  }

  // Admin-only: deactivate every team member (never admins / the owner).
  void _confirmRemoveAll() {
    final count = _memberRoles.length;
    AppConfirm.show(
      context,
      title: 'Delete all team members?',
      message: 'This deletes all $count team member${count == 1 ? '' : 's'}. Every one of them will be signed out '
          'and will not be able to log in again. Admin accounts are not affected. This cannot be undone.',
      confirmLabel: 'Delete All',
      busyLabel: 'Deleting…',
      onConfirm: () async {
        await apiClient.delete('/users');
        final adminEmail = adminProfile.value.email.toLowerCase();
        if (mounted) setState(() => appRoles.removeWhere((r) => r.email.toLowerCase() != adminEmail));
        saveRoles();
      },
      errorText: (e) => ApiClient.errorMessage(e, fallback: 'Could not delete team members.'),
    ).then((ok) {
      if (ok && mounted) _snack(context, 'All team members deleted', error: false);
    });
  }

  void _confirmRemove(int idx) {
    final name = _members[idx]['name'] as String;
    AppConfirm.show(
      context,
      title: 'Delete member?',
      message: 'Delete $name from the team? Their login will be disabled immediately — they will not be able to sign in on any device.',
      confirmLabel: 'Delete Member',
      onConfirm: () async {
        // Row 0 is the admin owner; member rows map to _memberRoles[idx - 1].
        final members = _memberRoles;
        final ai = idx - 1;
        if (ai >= 0 && ai < members.length) {
          final removed = members[ai];
          // Delete (deactivate) the backend account so they can't log in
          // anywhere — deterministic, and revokes their refresh tokens.
          if (removed.backendId != null) {
            try {
              await apiClient.delete('/users/${removed.backendId}');
            } catch (_) {
              // Fall back to the toggle endpoint if delete is unavailable.
              try { await apiClient.patch('/users/${removed.backendId}/toggle-active', {}); } catch (_) {}
            }
          }
          // Remove locally so the offline fallback login also fails.
          if (mounted) setState(() => appRoles.removeWhere((r) => r.email.toLowerCase() == removed.email.toLowerCase()));
          saveRoles();
        }
      },
    ).then((ok) {
      if (ok && mounted) _snack(context, '$name deleted — login disabled', error: false);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(children: [
      _buildHeader(context, 'Team Members', sub: '${_members.length} member${_members.length == 1 ? '' : 's'}',
        action: AppButton(label: 'Invite Member', icon: Icons.person_add_outlined, onPressed: _showInviteSheet)),
      Expanded(child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(0, 16, 0, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildCard(context, child: Column(children: _members.asMap().entries.map((e) {
          final i = e.key; final m = e.value;
          final c = m['color'] as Color;
          final name = m['name'] as String;
          final isSelf = m['self'] as bool? ?? false;
          final initials = name.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join();
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: i < _members.length - 1 ? BoxDecoration(border: Border(bottom: BorderSide(color: context.border))) : null,
            child: Row(children: [
              Container(width: 42, height: 42,
                decoration: BoxDecoration(color: c.withValues(alpha: 0.15), shape: BoxShape.circle),
                child: Center(child: Text(initials, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: c)))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                Text('${m['role']}  ·  ${m['email']}', style: TextStyle(fontSize: 12, color: context.textHint, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
              ])),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: m['status'] == 'Active' ? _brand100 : m['status'] == 'Invited' ? const Color(0xFFDCEFFB) : context.surface2,
                  borderRadius: BorderRadius.circular(8)),
                child: Text(m['status'] as String, style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: m['status'] == 'Active' ? _brand600 : m['status'] == 'Invited' ? _sky500 : context.textHint))),
              if (!isSelf) ...[
                if (_memberBackendId(i) != null) ...[
                  const SizedBox(width: 6),
                  Tooltip(message: 'Documents', child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _showMemberDocuments(context, i),
                    child: Container(padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: context.surface2, borderRadius: BorderRadius.circular(8)),
                      child: Icon(Icons.folder_outlined, size: 16, color: context.textSub)))),
                ],
                const SizedBox(width: 6),
                Tooltip(message: 'Edit role', child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _showEditRole(i),
                  child: Container(padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: context.surface2, borderRadius: BorderRadius.circular(8)),
                    child: Icon(Icons.manage_accounts_outlined, size: 16, color: context.textSub)))),
                const SizedBox(width: 6),
                Tooltip(message: 'Delete member', child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => _confirmRemove(i),
                  child: Container(padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: _coral100, borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.person_remove_outlined, size: 16, color: _coral500)))),
              ],
            ]),
          );
        }).toList())),
        if (isAdmin && _memberRoles.isNotEmpty) ...[
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Align(alignment: Alignment.centerRight, child: AppButton(
              label: 'Delete All Members', icon: Icons.group_remove_outlined,
              variant: AppButtonVariant.destructive, onPressed: _confirmRemoveAll,
            )),
          ),
        ],
        if (_pendingMembers.isNotEmpty) ...[
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Text('PENDING APPROVAL', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: context.textHint, letterSpacing: 0.8)),
          ),
          const SizedBox(height: 10),
          _buildCard(context, child: Column(children: _pendingMembers.asMap().entries.map((e) {
            final i = e.key; final m = e.value;
            final c = m['color'] as Color;
            final name = m['name'] as String;
            final initials = name.split(' ').map((w) => w.isNotEmpty ? w[0] : '').take(2).join();
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: i < _pendingMembers.length - 1 ? BoxDecoration(border: Border(bottom: BorderSide(color: context.border))) : null,
              child: Row(children: [
                Container(width: 42, height: 42,
                  decoration: BoxDecoration(color: c.withValues(alpha: 0.15), shape: BoxShape.circle),
                  child: Center(child: Text(initials, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: c)))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                  Text('${m['role']}  ·  ${m['email']}', style: TextStyle(fontSize: 12, color: context.textHint, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                ])),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: const Color(0xFFFFF1D6), borderRadius: BorderRadius.circular(8)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.schedule_outlined, size: 11, color: _amber600),
                    const SizedBox(width: 4),
                    Text('Pending Approval', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _amber600)),
                  ]),
                ),
              ]),
            );
          }).toList())),
        ],
      ]))),
    ]),
  );
}

// Document metadata for a team member's uploaded files — same shape as
// settings_screen.dart's own "My Documents" _MyDoc, just fetched for an
// arbitrary member id instead of the logged-in user.
class _MemberDoc {
  _MemberDoc({required this.id, required this.category, required this.fileName, this.mimeType});
  final String id, category, fileName;
  final String? mimeType;
  factory _MemberDoc.fromJson(Map<String, dynamic> j) => _MemberDoc(
    id: j['id'] as String, category: j['category'] as String,
    fileName: j['fileName'] as String, mimeType: j['mimeType'] as String?);
}

// Bottom sheet: view / upload / delete a team member's documents.
// Uses the same GET/POST/DELETE /users/:id/documents and
// GET /users/documents/:docId endpoints as the "My Documents" section on
// the logged-in team member's own profile (settings_screen.dart).
class _MemberDocumentsSheet extends StatefulWidget {
  const _MemberDocumentsSheet({required this.memberId, required this.memberName});
  final String memberId;
  final String memberName;
  @override
  State<_MemberDocumentsSheet> createState() => _MemberDocumentsSheetState();
}

class _MemberDocumentsSheetState extends State<_MemberDocumentsSheet> {
  List<_MemberDoc> _docs = [];
  bool _loading = true;
  bool _uploading = false;
  String? _viewingId;
  String? _deletingId;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final r = await apiClient.get('/users/${widget.memberId}/documents');
      final list = (r['data'] as List<dynamic>? ?? const []);
      final docs = list.whereType<Map>().map((m) => _MemberDoc.fromJson(m.cast<String, dynamic>())).toList();
      if (mounted) setState(() { _docs = docs; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _upload() async {
    final nameCtrl = TextEditingController();
    final category = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Document Name', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: TextField(
          controller: nameCtrl, autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) { final v = nameCtrl.text.trim(); if (v.isNotEmpty) Navigator.pop(ctx, v); },
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
          AppButton(label: 'Cancel', variant: AppButtonVariant.secondary, onPressed: () => Navigator.pop(ctx)),
          AppButton(label: 'Next', onPressed: () { final v = nameCtrl.text.trim(); if (v.isNotEmpty) Navigator.pop(ctx, v); }),
        ],
      ),
    );
    if (category == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      final result = await FilePicker.platform.pickFiles(allowMultiple: false, withData: true);
      final bytes = result?.files.single.bytes;
      if (result != null && bytes != null && mounted) {
        final fileName = result.files.single.name;
        await apiClient.post('/users/${widget.memberId}/documents', {
          'category': category, 'fileName': fileName, 'mimeType': null, 'data': base64Encode(bytes),
        });
        await _load();
        if (mounted) _snack(context, '$fileName uploaded successfully', error: false);
      }
    } catch (e) {
      if (mounted) AppToast.error(context, 'Upload failed', detail: ApiClient.errorMessage(e, fallback: 'Check your connection and try again.'));
    }
    if (mounted) setState(() => _uploading = false);
  }

  Future<void> _view(_MemberDoc d) async {
    setState(() => _viewingId = d.id);
    try {
      final r = await apiClient.get('/users/documents/${d.id}');
      final data = (r['data'] as Map).cast<String, dynamic>();
      final b64 = data['data'] as String? ?? '';
      if (b64.isNotEmpty) openBytesInBrowser(base64Decode(b64), d.fileName);
    } catch (_) {
      if (mounted) _snack(context, 'Could not open document');
    }
    if (mounted) setState(() => _viewingId = null);
  }

  void _confirmDelete(_MemberDoc d) {
    if (_deletingId != null) return;
    AppConfirm.show(
      context,
      title: 'Delete document?',
      message: 'Delete “${d.fileName}”? This cannot be undone.',
    ).then((ok) { if (ok && mounted) _delete(d); });
  }

  Future<void> _delete(_MemberDoc d) async {
    setState(() => _deletingId = d.id);
    var failed = false;
    try { await apiClient.delete('/users/documents/${d.id}'); } catch (_) { failed = true; }
    await _load();
    if (!mounted) return;
    setState(() => _deletingId = null);
    if (failed) {
      AppToast.error(context, 'Could not delete the document');
    } else {
      AppToast.success(context, 'Document deleted');
    }
  }

  Widget _row(_MemberDoc d) {
    final viewing = _viewingId == d.id;
    final deleting = _deletingId == d.id;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
      leading: Container(width: 38, height: 38,
        decoration: BoxDecoration(color: context.surface2, shape: BoxShape.circle),
        child: Icon(Icons.insert_drive_file_outlined, size: 18, color: context.textSub)),
      title: Text(d.fileName, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.textPrimary),
        overflow: TextOverflow.ellipsis),
      subtitle: Text(d.category, style: TextStyle(fontSize: 12.5, color: context.textHint)),
      trailing: deleting
        ? const AppSpinner(size: 16, color: _coral500)
        : Row(mainAxisSize: MainAxisSize.min, children: [
            GestureDetector(
              onTap: viewing ? null : () => _view(d),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: viewing
                  ? const AppSpinner(color: _brand600)
                  : const Text('View', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _brand600)),
              ),
            ),
            IconButton(
              tooltip: 'Delete document',
              visualDensity: VisualDensity.compact,
              onPressed: () => _confirmDelete(d),
              icon: const Icon(Icons.delete_outline, size: 18, color: _coral500),
            ),
          ]),
    );
  }

  @override
  Widget build(BuildContext context) => Container(
    constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.75),
    decoration: BoxDecoration(color: context.cardBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
    padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 24),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Center(child: SheetHandle(margin: const EdgeInsets.symmetric(vertical: 12))),
      Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Documents', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          Text(widget.memberName, style: TextStyle(fontSize: 12.5, color: context.textHint, fontWeight: FontWeight.w500)),
        ])),
        AppButton(
          label: 'Upload', busyLabel: 'Uploading…', icon: Icons.upload_file_outlined,
          dense: true, loading: _uploading, onPressed: _upload,
        ),
      ]),
      const SizedBox(height: 8),
      Flexible(child: _loading
        ? const SkeletonList(rows: 3, rowHeight: 56)
        : _docs.isEmpty
          ? const EmptyStateLike(icon: Icons.folder_open_outlined, title: 'No documents yet',
              message: 'Upload ID proofs or certificates for this member.')
          : ListView.separated(
              shrinkWrap: true,
              itemCount: _docs.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: context.border),
              itemBuilder: (_, i) => _row(_docs[i]),
            )),
    ]),
  );
}

// ════════════════════════════════════════════════════════════════
// 5. DONATION TYPES
// ════════════════════════════════════════════════════════════════
// Donation Types and Expense Categories share one compact list screen (same
// look as the Student master lists): header with the Add action, skeleton
// loading, compact rows with an in-place toggle spinner, ⋮ menu, and a
// compact add modal.
class _TypeListConfig {
  const _TypeListConfig({
    required this.title, required this.noun, required this.plural,
    required this.listPath, required this.createPath, required this.itemPath,
    required this.style, required this.hint, required this.emptyIcon,
    required this.emptyHelp, required this.appearsIn, this.hasDescription = false,
  });
  final String title, noun, plural, listPath, createPath, hint, emptyHelp, appearsIn;
  final String Function(String id) itemPath;
  final (IconData, Color) Function(String label) style;
  final IconData emptyIcon;
  final bool hasDescription;
  String get nounTitle => noun.split(' ').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
}

class DonationTypesScreen extends StatelessWidget {
  const DonationTypesScreen({super.key});

  // Visuals are keyed off the label so custom types still get a sensible icon.
  static (IconData, Color) _style(String label) {
    final l = label.toLowerCase();
    if (l.contains('educat') || l.contains('school') || l.contains('scholar')) return (Icons.school_outlined, _violet500);
    if (l.contains('student') || l.contains('child') || l.contains('sponsor')) return (Icons.favorite_outline, _brand600);
    if (l.contains('medic') || l.contains('health')) return (Icons.medical_services_outlined, _coral500);
    if (l.contains('food') || l.contains('nutri') || l.contains('meal')) return (Icons.restaurant_outlined, _amber600);
    if (l.contains('infra') || l.contains('build')) return (Icons.business_outlined, _sky500);
    if (l.contains('general') || l.contains('fund')) return (Icons.account_balance_wallet_outlined, _sky500);
    return (Icons.volunteer_activism_outlined, _brand600);
  }

  // Loaded live from the backend — the same table Add Donation reads, so a
  // type added or toggled here shows up (or disappears) there immediately.
  static final _config = _TypeListConfig(
    title: 'Donation Types',
    noun: 'donation type',
    plural: 'donation types',
    listPath: '/donations/types/all',
    createPath: '/donations/types',
    itemPath: (id) => '/donations/types/$id',
    style: _style,
    hint: 'e.g. Healthcare, Scholarship…',
    emptyIcon: Icons.volunteer_activism_outlined,
    emptyHelp: 'Create a type like Education or Healthcare to categorise donations.',
    appearsIn: 'Add Donation',
    hasDescription: true,
  );

  @override
  Widget build(BuildContext context) => _TypeListScreen(config: _config);
}

// 5b. STUDENT CATEGORIES / STATUS / EDUCATION LEVELS → student_masters_screen.dart

// ════════════════════════════════════════════════════════════════
// 5c. EXPENSE CATEGORIES
// ════════════════════════════════════════════════════════════════
class ExpenseCategoriesScreen extends StatelessWidget {
  const ExpenseCategoriesScreen({super.key});

  static (IconData, Color) _style(String label) {
    final l = label.toLowerCase();
    if (l.contains('food') || l.contains('groc') || l.contains('meal')) return (Icons.restaurant_outlined, _amber600);
    if (l.contains('rent') || l.contains('build') || l.contains('infra')) return (Icons.business_outlined, _sky500);
    if (l.contains('salar') || l.contains('staff') || l.contains('wage')) return (Icons.badge_outlined, _violet500);
    if (l.contains('medic') || l.contains('health')) return (Icons.medical_services_outlined, _coral500);
    if (l.contains('educat') || l.contains('school') || l.contains('book')) return (Icons.school_outlined, _violet500);
    if (l.contains('transport') || l.contains('travel') || l.contains('fuel')) return (Icons.directions_bus_outlined, _sky500);
    if (l.contains('electric') || l.contains('water') || l.contains('util')) return (Icons.bolt_outlined, _amber600);
    return (Icons.account_balance_wallet_outlined, _brand600);
  }

  // Loaded live from the backend — the same table Add Expense reads, so a
  // category added or toggled here shows up (or disappears) there immediately.
  static final _config = _TypeListConfig(
    title: 'Expense Categories',
    noun: 'category',
    plural: 'categories',
    listPath: '/expenses/categories/all',
    createPath: '/expenses/categories',
    itemPath: (id) => '/expenses/categories/$id',
    style: _style,
    hint: 'e.g. Rent, Salaries, Transport…',
    emptyIcon: Icons.receipt_long_outlined,
    emptyHelp: 'Create categories like Rent or Salaries to organise expenses.',
    appearsIn: 'Add Expense',
  );

  @override
  Widget build(BuildContext context) => _TypeListScreen(config: _config);
}

class _TypeListScreen extends StatefulWidget {
  const _TypeListScreen({required this.config});
  final _TypeListConfig config;
  @override
  State<_TypeListScreen> createState() => _TypeListScreenState();
}

class _TypeListScreenState extends State<_TypeListScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;
  // Rows with a toggle request in flight — the switch shows a spinner and
  // ignores further taps until the server answers.
  final Set<String> _toggling = {};

  _TypeListConfig get _c => widget.config;

  @override
  void initState() { super.initState(); _load(); }

  // [quiet] refreshes in place (pull-to-refresh / after adding) without the
  // skeleton flash.
  Future<void> _load({bool quiet = false}) async {
    if (!quiet) setState(() { _loading = true; _error = null; });
    try {
      final r = await apiClient.get(_c.listPath);
      final list = (r['data'] as List? ?? []).cast<Map<String, dynamic>>();
      if (!mounted) return;
      setState(() { _items = list; _loading = false; _error = null; });
    } catch (e) {
      if (!mounted) return;
      if (quiet && _items.isNotEmpty) {
        AppToast.error(context, 'Couldn’t refresh the list', detail: ApiClient.errorMessage(e));
        return;
      }
      setState(() { _error = ApiClient.errorMessage(e, fallback: 'Could not load ${_c.plural}.'); _loading = false; });
    }
  }

  Future<void> _toggle(Map<String, dynamic> item, bool v) async {
    final id = '${item['id']}';
    if (_toggling.contains(id)) return;
    setState(() => _toggling.add(id));
    try {
      await apiClient.put(_c.itemPath(id), {'isActive': v});
      if (!mounted) return;
      // Only flip once the server has accepted it.
      setState(() { item['isActive'] = v; _toggling.remove(id); });
      AppToast.success(context, '“${item['label']}” ${v ? 'enabled' : 'disabled'}');
    } catch (e) {
      if (!mounted) return;
      setState(() => _toggling.remove(id));
      AppToast.error(context, 'Unable to update ${_c.noun}', detail: ApiClient.errorMessage(e, fallback: 'Please try again.'));
    }
  }

  Future<void> _showAdd() async {
    final saved = await showAppSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _TypeAddForm(config: _c),
    );
    if (saved == null || !mounted) return;
    AppToast.success(context, '${_c.nounTitle} added', detail: '“$saved” now appears in ${_c.appearsIn}');
    _load(quiet: true);
  }

  Widget _row(Map<String, dynamic> t, bool last) {
    final label = t['label'] as String? ?? '';
    final desc = t['description'] as String? ?? '';
    final active = t['isActive'] as bool? ?? true;
    final busy = _toggling.contains('${t['id']}');
    final (icon, color) = _c.style(label);
    return _HoverRow(
      last: last,
      child: Row(children: [
        Container(width: 34, height: 34,
          decoration: BoxDecoration(color: color.withValues(alpha: active ? 0.12 : 0.06), borderRadius: BorderRadius.circular(9)),
          child: Icon(icon, color: active ? color : context.textHint, size: 17)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: active ? context.textPrimary : context.textHint)),
          if (desc.isNotEmpty || !active) ...[
            const SizedBox(height: 2),
            Text([if (!active) 'Disabled', if (desc.isNotEmpty) desc].join('  ·  '), maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: context.textHint, fontWeight: FontWeight.w500)),
          ],
        ])),
        const SizedBox(width: 8),
        SizedBox(
          width: 48, height: 28,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: busy
                ? const Center(key: ValueKey('busy'), child: AppSpinner())
                : Transform.scale(
                    key: const ValueKey('sw'),
                    scale: 0.78,
                    child: Semantics(
                      label: '${active ? 'Disable' : 'Enable'} $label',
                      child: Switch(value: active, activeColor: _brand600, onChanged: (v) => _toggle(t, v)),
                    ),
                  ),
          ),
        ),
        const SizedBox(width: 4),
        PopupMenuButton<String>(
          tooltip: 'Actions for $label',
          icon: Icon(Icons.more_horiz_rounded, color: context.textSub, size: 20),
          position: PopupMenuPosition.under,
          offset: const Offset(0, 4),
          constraints: const BoxConstraints(minWidth: 150),
          enabled: !busy,
          onSelected: (v) { if (v == 'toggle') _toggle(t, !active); },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'toggle',
              height: 36,
              child: Row(children: [
                Icon(active ? Icons.toggle_off_outlined : Icons.toggle_on_outlined, size: 17, color: context.textSub),
                const SizedBox(width: 10),
                Text(active ? 'Disable' : 'Enable',
                    style: TextStyle(fontSize: 13.5, color: context.textPrimary, fontWeight: FontWeight.w500)),
              ]),
            ),
          ],
        ),
      ]),
    );
  }

  Widget _card(Widget child) => Container(
    decoration: BoxDecoration(
      color: context.cardBg, borderRadius: BorderRadius.circular(12),
      border: Border.all(color: context.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (_loading) {
      content = _card(const SkeletonList(rows: 4, rowHeight: 64));
    } else if (_error != null) {
      content = _card(ErrorState(message: _error!, onRetry: _load));
    } else if (_items.isEmpty) {
      content = _card(EmptyState(
        icon: _c.emptyIcon,
        title: 'No ${_c.plural} yet',
        message: _c.emptyHelp,
        actionLabel: 'Add ${_c.nounTitle}',
        onAction: _showAdd,
      ));
    } else {
      content = _card(Column(children: [
        for (var i = 0; i < _items.length; i++) _row(_items[i], i == _items.length - 1),
      ]));
    }

    return Scaffold(
      body: Column(children: [
        _buildHeader(context, _c.title,
          sub: _loading ? 'Loading…' : '${_items.length} ${_items.length == 1 ? _c.noun : _c.plural} configured',
          action: AppButton(label: 'Add ${_c.nounTitle}', icon: Icons.add, onPressed: _showAdd)),
        Expanded(child: RefreshIndicator(
          onRefresh: () => _load(quiet: true),
          color: _brand600,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 880),
                child: AnimatedSwitcher(duration: const Duration(milliseconds: 180), child: KeyedSubtree(
                  key: ValueKey(_loading ? 'l' : _error != null ? 'e' : _items.isEmpty ? 'x' : 'd'),
                  child: content,
                )),
              ),
            ),
          ),
        )),
      ]),
    );
  }
}

// Row with a subtle hover tint and a hairline divider.
class _HoverRow extends StatefulWidget {
  const _HoverRow({required this.child, required this.last});
  final Widget child;
  final bool last;
  @override
  State<_HoverRow> createState() => _HoverRowState();
}

class _HoverRowState extends State<_HoverRow> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hover = true),
    onExit: (_) => setState(() => _hover = false),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: _hover ? context.surface2.withValues(alpha: 0.6) : Colors.transparent,
        border: widget.last ? null : Border(bottom: BorderSide(color: context.border.withValues(alpha: 0.7))),
      ),
      child: widget.child,
    ),
  );
}

// Compact add form. Validates on leaving the field and on submit, keeps what
// was typed if the save fails, and can't be submitted twice. Pops with the
// saved name.
class _TypeAddForm extends StatefulWidget {
  const _TypeAddForm({required this.config});
  final _TypeListConfig config;
  @override
  State<_TypeAddForm> createState() => _TypeAddFormState();
}

class _TypeAddFormState extends State<_TypeAddForm> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _desc = TextEditingController();
  bool _saving = false;
  String? _serverError;

  _TypeListConfig get _c => widget.config;

  @override
  void dispose() { _name.dispose(); _desc.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _serverError = null);
    if (!_form.currentState!.validate()) return;
    final name = _name.text.trim();
    setState(() => _saving = true);
    try {
      await apiClient.post(_c.createPath, {
        'label': name,
        if (_c.hasDescription && _desc.text.trim().isNotEmpty) 'description': _desc.text.trim(),
      });
      if (mounted) Navigator.of(context).pop(name);
    } catch (e) {
      if (!mounted) return;
      // A duplicate/validation answer belongs under the name field; anything
      // else (network, server) is a toast.
      final msg = ApiClient.errorMessage(e, fallback: 'Could not save the ${_c.noun}.');
      final fieldLevel = msg.toLowerCase().contains('exist') || msg.toLowerCase().contains('name') || msg.toLowerCase().contains('label');
      setState(() { _saving = false; if (fieldLevel) _serverError = msg; });
      _form.currentState!.validate();
      if (!fieldLevel) AppToast.error(context, 'Unable to add ${_c.noun}', detail: msg);
    }
  }

  Widget _label(String t, {bool required = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text.rich(TextSpan(children: [
      TextSpan(text: t),
      if (required) const TextSpan(text: ' *', style: TextStyle(color: _coral500)),
    ]), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: context.textSub)),
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(color: context.cardBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Form(
          key: _form,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SheetHandle(margin: EdgeInsets.only(bottom: 10)),
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Add ${_c.noun}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('It will appear in ${_c.appearsIn} straight away.',
                    style: TextStyle(fontSize: 12.5, color: context.textSub)),
              ])),
              IconButton(
                tooltip: 'Close',
                icon: Icon(Icons.close_rounded, size: 20, color: context.textSub),
                onPressed: _saving ? null : () => Navigator.of(context).pop(),
              ),
            ]),
            const SizedBox(height: 16),
            _label('Name', required: true),
            TextFormField(
              controller: _name,
              autofocus: true,
              enabled: !_saving,
              textInputAction: _c.hasDescription ? TextInputAction.next : TextInputAction.done,
              onFieldSubmitted: _c.hasDescription ? null : (_) => _save(),
              onChanged: (_) { if (_serverError != null) setState(() => _serverError = null); },
              validator: (v) {
                if ((v ?? '').trim().isEmpty) return 'Please enter a name.';
                return _serverError;
              },
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              decoration: InputDecoration(hintText: _c.hint),
            ),
            if (_c.hasDescription) ...[
              const SizedBox(height: 12),
              _label('Description'),
              TextFormField(
                controller: _desc,
                enabled: !_saving,
                onFieldSubmitted: (_) => _save(),
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                decoration: const InputDecoration(hintText: 'Short description (optional)'),
              ),
            ],
            const SizedBox(height: 18),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              AppButton(label: 'Cancel', variant: AppButtonVariant.secondary,
                  onPressed: _saving ? null : () => Navigator.of(context).pop()),
              const SizedBox(width: 8),
              AppButton(
                label: 'Add ${_c.nounTitle}',
                busyLabel: 'Adding…',
                loading: _saving,
                onPressed: _save,
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// 6. EXPORT DATA
// ════════════════════════════════════════════════════════════════
class ExportDataScreen extends StatefulWidget {
  const ExportDataScreen({super.key});
  @override
  State<ExportDataScreen> createState() => _ExportDataState();
}

class _ExportDataState extends State<ExportDataScreen> {
  String _format  = 'PDF';
  String _range   = 'This Month';
  bool _donors    = true;
  bool _donations = true;
  bool _expenses  = true;
  bool _students  = false;
  bool _reports   = false;
  bool _exporting = false;

  // Start of the selected date range — null means "All Time" (no filter).
  DateTime? get _rangeStart {
    final now = DateTime.now();
    switch (_range) {
      case 'This Month': return DateTime(now.year, now.month, 1);
      // First of the month two months back (3 calendar months incl. current) —
      // `now.day` overflows short months (31 May − 3 → "31 Feb" → 3 March).
      case 'Last 3 Months': return DateTime(now.year, now.month - 2, 1);
      case 'This Year': return DateTime(now.year, 1, 1);
      default: return null;
    }
  }

  // Paged fetch — the backend caps limit at 100 (a limit=500 request is
  // rejected with a 400, which used to silently produce an empty export).
  // Errors propagate: swallowing them here produced a "successful" download
  // that was silently empty or cut off part-way.
  Future<List<Map<String, dynamic>>> _fetchList(String path) async {
    final all = <Map<String, dynamic>>[];
    for (int page = 1; page <= 500; page++) {
      final r = await apiClient.get(path, params: {'limit': '100', 'page': '$page'});
      final inner = r['data'];
      final list = inner is Map ? (inner['data'] as List? ?? const []) : (inner is List ? inner : const []);
      all.addAll(list.whereType<Map>().map((m) => m.cast<String, dynamic>()));
      final meta = (r['meta'] as Map?) ?? (inner is Map ? inner['meta'] as Map? : null);
      if (meta?['hasNext'] != true || list.isEmpty) break;
    }
    return all;
  }

  Future<Map<String, dynamic>> _fetchOverview() async {
    try {
      final r = await apiClient.get('/reports/overview');
      return (r['data'] as Map).cast<String, dynamic>();
    } catch (_) { return const {}; }
  }

  List<Map<String, dynamic>> _filterByDate(List<Map<String, dynamic>> rows, String dateKey) {
    final start = _rangeStart;
    if (start == null) return rows;
    return rows.where((r) {
      final dt = DateTime.tryParse(r[dateKey] as String? ?? '');
      return dt != null && !dt.isBefore(start);
    }).toList();
  }

  ({List<String> headers, List<List<String>> rows}) _donorRows(List<Map<String, dynamic>> donors) => (
    headers: const ['#', 'Donor Code', 'Name', 'Mobile', 'City', 'Tier', 'Total Donations'],
    rows: donors.asMap().entries.map((e) {
      final i = e.key, r = e.value;
      final count = (r['_count'] as Map?)?['donations'] as int? ?? 0;
      return ['${i + 1}', r['donorCode'] as String? ?? '', r['name'] as String? ?? '',
        r['mobile'] as String? ?? '', r['city'] as String? ?? '', r['tier'] as String? ?? '', '$count'];
    }).toList(),
  );

  // "Rs." not "₹" — the PDF export's default font (Helvetica) can't render
  // the rupee glyph, and the same row builders feed all three formats.
  ({List<String> headers, List<List<String>> rows}) _donationRows(List<Map<String, dynamic>> donations) => (
    headers: const ['#', 'Receipt No.', 'Donor', 'Date', 'Type', 'Payment Mode', 'Amount (Rs.)'],
    rows: donations.asMap().entries.map((e) {
      final i = e.key, r = e.value;
      final donor = (r['donor'] as Map?)?.cast<String, dynamic>() ?? const {};
      final type = (r['type'] as Map?)?.cast<String, dynamic>() ?? const {};
      final amount = (r['amount'] as num?)?.toInt() ?? 0;
      return ['${i + 1}', r['receiptNo'] as String? ?? '', donor['name'] as String? ?? '',
        (r['date'] as String? ?? '').split('T').first, type['label'] as String? ?? '',
        r['paymentMode'] as String? ?? '', amount.toString()];
    }).toList(),
  );

  ({List<String> headers, List<List<String>> rows}) _expenseRows(List<Map<String, dynamic>> expenses) => (
    headers: const ['#', 'Voucher No.', 'Date', 'Paid To', 'Category', 'Payment Mode', 'Amount (Rs.)'],
    rows: expenses.asMap().entries.map((e) {
      final i = e.key, r = e.value;
      final cat = (r['category'] as Map?)?.cast<String, dynamic>() ?? const {};
      final amount = (r['amount'] as num?)?.toInt() ?? 0;
      return ['${i + 1}', r['voucherNo'] as String? ?? '', (r['date'] as String? ?? '').split('T').first,
        r['paidTo'] as String? ?? '', cat['label'] as String? ?? '',
        r['paymentMode'] as String? ?? '', amount.toString()];
    }).toList(),
  );

  // Full contact details — the old export had only name/class/status, which
  // was useless for reaching a child's family.
  ({List<String> headers, List<List<String>> rows}) _studentRows(List<Map<String, dynamic>> students) {
    String s(dynamic v) => v == null ? '' : v.toString().trim();
    String d(dynamic v) {
      final dt = DateTime.tryParse(s(v));
      return dt == null ? '' : DateFormat('dd/MM/yyyy').format(dt.toLocal());
    }
    return (
      headers: const ['#', 'Child ID', 'Name', 'Gender', 'DOB', 'Centre', 'Status', 'Support Category',
        "Father's Name", "Mother's Name", 'Guardian', 'Relation', 'Guardian Phone', 'Address',
        'Education Level', 'School / College', 'Class'],
      rows: students.asMap().entries.map((e) {
        final i = e.key, r = e.value;
        final edu = s(r['educationLevel']);
        return ['${i + 1}', s(r['childId']), s(r['name']), s(r['gender']), d(r['dob']),
          s((r['center'] as Map?)?['name']), StudentLookups.statusLabel(s(r['status'])),
          s((r['category'] as Map?)?['label']), s(r['fatherName']), s(r['motherName']),
          s(r['guardianName']), s(r['guardianRelation']), s(r['guardianPhone']), s(r['address']),
          edu.isEmpty ? '' : StudentLookups.educationLabel(edu), s(r['school']), s(r['class'])];
      }).toList(),
    );
  }

  ({List<String> headers, List<List<String>> rows}) _summaryRows(Map<String, dynamic> overview) => (
    headers: const ['Metric', 'Value'],
    rows: [
      ['Total Raised (Rs.)', '${((overview['donations'] as Map?)?['totalRaised'] as num?)?.toInt() ?? 0}'],
      ['Total Donors', '${((overview['donors'] as Map?)?['total'] as num?)?.toInt() ?? 0}'],
      ['Active Students', '${((overview['students'] as Map?)?['active'] as num?)?.toInt() ?? 0}'],
    ],
  );

  String _csvEscape(String v) =>
      (v.contains(',') || v.contains('"') || v.contains('\n')) ? '"${v.replaceAll('"', '""')}"' : v;

  String _buildCsv({
    required List<Map<String, dynamic>> donors,
    required List<Map<String, dynamic>> donations,
    required List<Map<String, dynamic>> expenses,
    required List<Map<String, dynamic>> students,
    Map<String, dynamic>? overview,
  }) {
    final out = StringBuffer();
    out.writeln('Sri Krishnashraya Educational Trust — Data Export');
    out.writeln('Range: $_range  |  Generated: ${DateTime.now().toString().substring(0, 16)}');
    void section(String title, ({List<String> headers, List<List<String>> rows}) t) {
      out.writeln('');
      out.writeln('--- $title ---');
      out.writeln(t.headers.map(_csvEscape).join(','));
      for (final row in t.rows) { out.writeln(row.map(_csvEscape).join(',')); }
    }
    if (_donors) section('DONORS', _donorRows(donors));
    if (_donations) section('DONATIONS', _donationRows(donations));
    if (_expenses) section('EXPENSES', _expenseRows(expenses));
    if (_students) section('STUDENTS', _studentRows(students));
    if (_reports && overview != null) section('SUMMARY', _summaryRows(overview));
    return out.toString();
  }

  xl.CellStyle _xlHeaderStyle() => xl.CellStyle(
    bold: true,
    backgroundColorHex: xl.ExcelColor.fromHexString('#FF9933'),
    fontColorHex: xl.ExcelColor.fromHexString('#FFFFFF'),
  );

  void _xlWriteSheet(xl.Excel excel, String name, ({List<String> headers, List<List<String>> rows}) t) {
    final sheet = excel[name];
    for (int c = 0; c < t.headers.length; c++) {
      final cell = sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0));
      cell.value = xl.TextCellValue(t.headers[c]);
      cell.cellStyle = _xlHeaderStyle();
    }
    for (int r = 0; r < t.rows.length; r++) {
      for (int c = 0; c < t.rows[r].length; c++) {
        sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1)).value = xl.TextCellValue(t.rows[r][c]);
      }
    }
  }

  Uint8List? _buildExcel({
    required List<Map<String, dynamic>> donors,
    required List<Map<String, dynamic>> donations,
    required List<Map<String, dynamic>> expenses,
    required List<Map<String, dynamic>> students,
    Map<String, dynamic>? overview,
  }) {
    final excel = xl.Excel.createExcel();
    if (_donors) _xlWriteSheet(excel, 'Donors', _donorRows(donors));
    if (_donations) _xlWriteSheet(excel, 'Donations', _donationRows(donations));
    if (_expenses) _xlWriteSheet(excel, 'Expenses', _expenseRows(expenses));
    if (_students) _xlWriteSheet(excel, 'Students', _studentRows(students));
    if (_reports && overview != null) _xlWriteSheet(excel, 'Summary', _summaryRows(overview));
    if (excel.sheets.containsKey('Sheet1')) excel.delete('Sheet1');
    final bytes = excel.encode();
    return bytes == null ? null : Uint8List.fromList(bytes);
  }

  Future<Uint8List> _buildPdf({
    required List<Map<String, dynamic>> donors,
    required List<Map<String, dynamic>> donations,
    required List<Map<String, dynamic>> expenses,
    required List<Map<String, dynamic>> students,
    Map<String, dynamic>? overview,
  }) async {
    final doc = pw.Document();
    final orange = PdfColor.fromInt(0xFFF97316);
    final dark   = PdfColor.fromInt(0xFF1F2937);
    final grey   = PdfColor.fromInt(0xFF6B7280);

    // Returns the title and the table as SEPARATE top-level MultiPage children.
    // Wrapping them in a Column would make the section one non-spanning widget,
    // and any export taller than a page then loops adding blank pages instead
    // of flowing the table over (Column is not a SpanningWidget; Table is).
    List<pw.Widget> section(String title, ({List<String> headers, List<List<String>> rows}) t) => [
      pw.SizedBox(height: 16),
      pw.Text(title, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: dark)),
      pw.SizedBox(height: 6),
      pw.TableHelper.fromTextArray(
        headers: t.headers,
        data: t.rows,
        headerStyle: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
        headerDecoration: pw.BoxDecoration(color: orange),
        cellStyle: const pw.TextStyle(fontSize: 7.5),
        cellHeight: 20,
        cellAlignment: pw.Alignment.centerLeft,
        headerCount: 1,
      ),
    ];

    doc.addPage(pw.MultiPage(
      // Landscape: the student table carries 17 columns of contact details.
      pageFormat: PdfPageFormat.a4.landscape,
      margin: const pw.EdgeInsets.fromLTRB(24, 24, 24, 24),
      footer: (ctx) => pw.Container(
        alignment: pw.Alignment.centerRight,
        margin: const pw.EdgeInsets.only(top: 8),
        child: pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}',
            style: pw.TextStyle(fontSize: 7.5, color: grey)),
      ),
      build: (ctx) => [
        pw.Text('Sri Krishnashraya Educational Trust', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: dark)),
        pw.Text('Data Export', style: pw.TextStyle(fontSize: 11, color: grey)),
        pw.SizedBox(height: 4),
        pw.Text('Range: $_range   |   Generated: ${DateTime.now().toString().substring(0, 16)}',
            style: pw.TextStyle(fontSize: 9, color: grey)),
        if (_donors) ...section('Donors', _donorRows(donors)),
        if (_donations) ...section('Donations', _donationRows(donations)),
        if (_expenses) ...section('Expenses', _expenseRows(expenses)),
        if (_students) ...section('Students', _studentRows(students)),
        if (_reports && overview != null) ...section('Summary', _summaryRows(overview)),
      ],
    ));
    return doc.save();
  }

  Future<void> _export() async {
    if (_exporting) return;
    setState(() => _exporting = true);
    try {
      final donors = _donors ? await _fetchList('/donors') : <Map<String, dynamic>>[];
      final donations = _donations ? _filterByDate(await _fetchList('/donations'), 'date') : <Map<String, dynamic>>[];
      final expenses = _expenses ? _filterByDate(await _fetchList('/expenses'), 'date') : <Map<String, dynamic>>[];
      final students = _students ? await _fetchList('/students') : <Map<String, dynamic>>[];
      if (_students) await StudentLookups.load(force: true);
      final overview = _reports ? await _fetchOverview() : null;

      final dateStr = DateFormat('ddMMyyyy').format(DateTime.now());
      bool ok;
      String filename;

      if (_format == 'CSV') {
        filename = 'SKET_Export_$dateStr.csv';
        ok = await NativeFileSaver.saveCsv(filename, _buildCsv(donors: donors, donations: donations, expenses: expenses, students: students, overview: overview));
      } else if (_format == 'Excel') {
        filename = 'SKET_Export_$dateStr.xlsx';
        final bytes = _buildExcel(donors: donors, donations: donations, expenses: expenses, students: students, overview: overview);
        ok = bytes != null && await NativeFileSaver.saveBytes(filename, bytes,
          'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      } else {
        filename = 'SKET_Export_$dateStr.pdf';
        final bytes = await _buildPdf(donors: donors, donations: donations, expenses: expenses, students: students, overview: overview);
        ok = await NativeFileSaver.saveBytes(filename, bytes, 'application/pdf');
      }

      if (!mounted) return;
      setState(() => _exporting = false);
      if (ok) {
        AppToast.success(context, 'Export downloaded', detail: filename);
      } else {
        AppToast.error(context, 'Could not save the file', detail: 'Please try again.');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _exporting = false);
        AppToast.error(context, 'Export failed', detail: ApiClient.errorMessage(e, fallback: 'Check your connection and try again.'));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(children: [
      _buildHeader(context, 'Export Data', sub: 'Download reports & records'),
      Expanded(child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _buildSectionLabel(context, 'Export Format'),
          _buildCard(context, child: Padding(padding: const EdgeInsets.all(14), child: Row(children: ['PDF', 'Excel', 'CSV'].map((f) {
            final active = _format == f;
            return Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: Semantics(
              button: true, selected: active, label: '$f format',
              child: GestureDetector(
              onTap: _exporting ? null : () => setState(() => _format = f),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(color: active ? _brand600 : context.surface2, borderRadius: BorderRadius.circular(10)),
                child: Text(f, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: active ? Colors.white : context.textSub))),
            ))));
          }).toList()))),
          const SizedBox(height: 14),
          _buildSectionLabel(context, 'Date Range'),
          _buildCard(context, child: Column(children: ['This Month', 'Last 3 Months', 'This Year', 'All Time'].asMap().entries.map((e) {
            final active = _range == e.value;
            return GestureDetector(
              onTap: () => setState(() => _range = e.value),
              behavior: HitTestBehavior.opaque,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                decoration: e.key < 3 ? BoxDecoration(border: Border(bottom: BorderSide(color: context.border))) : null,
                child: Row(children: [
                  Expanded(child: Text(e.value, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600))),
                  if (active) const Icon(Icons.check_circle_rounded, color: _brand600, size: 20)
                  else Icon(Icons.radio_button_unchecked, color: context.textHint, size: 20),
                ])),
            );
          }).toList())),
          const SizedBox(height: 14),
          _buildSectionLabel(context, 'Include in Export'),
          _buildCard(context, child: Column(children: [
            _toggle(context, 'Donors',    _donors,    (v) => setState(() => _donors = v),    Icons.people_outlined,                  _brand600),
            _toggle(context, 'Donations', _donations, (v) => setState(() => _donations = v), Icons.account_balance_wallet_outlined,  _brand600),
            _toggle(context, 'Expenses',  _expenses,  (v) => setState(() => _expenses = v),  Icons.receipt_long_outlined,            _coral500),
            _toggle(context, 'Students',  _students,  (v) => setState(() => _students = v),  Icons.school_outlined,                  _violet500),
            _toggle(context, 'Reports',   _reports,   (v) => setState(() => _reports = v),   Icons.bar_chart_rounded,                _sky500, last: true),
          ])),
          const SizedBox(height: 20),
          _formAction(context, label: 'Download $_format', busyLabel: 'Preparing export…',
              icon: Icons.download_outlined, loading: _exporting, onPressed: _export),
        ]),
      )),
    ]),
  );

  Widget _toggle(BuildContext ctx, String label, bool val, ValueChanged<bool> fn, IconData icon, Color c, {bool last = false}) =>
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: last ? null : BoxDecoration(border: Border(bottom: BorderSide(color: ctx.border))),
      child: Row(children: [
        Icon(icon, size: 18, color: c), const SizedBox(width: 10),
        Expanded(child: Text(label, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700))),
        Switch(value: val, onChanged: fn, activeColor: _brand600),
      ]));
}

// ════════════════════════════════════════════════════════════════
// 7. BACKUP & SYNC
// ════════════════════════════════════════════════════════════════
class BackupSyncScreen extends StatefulWidget {
  const BackupSyncScreen({super.key});
  @override
  State<BackupSyncScreen> createState() => _BackupSyncState();
}

class _BackupSyncState extends State<BackupSyncScreen> {
  bool _autoBackup = true;
  bool _syncing    = false;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(children: [
      _buildHeader(context, 'Backup & Sync', sub: 'Keep your data safe'),
      Expanded(child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            padding: const EdgeInsets.all(16), margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: _brand100, borderRadius: BorderRadius.circular(16), border: Border.all(color: _brand600.withValues(alpha: 0.2))),
            child: const Row(children: [
              Icon(Icons.cloud_done_outlined, color: _brand600, size: 32), SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Last Synced', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _brand600)),
                Text('Today at 09:14 AM · All data up to date', style: TextStyle(fontSize: 12, color: _brand600, fontWeight: FontWeight.w500)),
              ])),
            ])),
          _buildSectionLabel(context, 'Settings'),
          _buildCard(context, child: Column(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: context.border))),
              child: Row(children: [
                const Icon(Icons.backup_outlined, color: _brand600, size: 20), const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Auto Backup', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                  Text('Daily backup at midnight', style: TextStyle(fontSize: 12, color: context.textHint, fontWeight: FontWeight.w500)),
                ])),
                Switch(value: _autoBackup, onChanged: (v) => setState(() => _autoBackup = v), activeColor: _brand600),
              ])),
            _buildRow(context, 'Backup Now', value: 'Manually trigger a full backup', icon: Icons.cloud_upload_outlined, fg: _sky500, last: true,
              onTap: () => _snack(context, 'Backup started')),
          ])),
          const SizedBox(height: 16),
          _buildSectionLabel(context, 'Restore'),
          _buildCard(context, child: Column(children: [
            _buildRow(context, 'Restore from Backup', value: 'Revert to a previous data state', icon: Icons.restore, fg: _amber600,
              onTap: () => AppToast.info(context, 'Select a backup to restore')),
            _buildRow(context, 'Clear Local Cache', value: 'Free up device storage', icon: Icons.delete_sweep_outlined, fg: _coral500, last: true,
              onTap: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();
                if (mounted) _snack(context, 'Cache cleared — app data reset');
              }),
          ])),
          const SizedBox(height: 20),
          _formAction(context, label: 'Sync Now', busyLabel: 'Syncing…', icon: Icons.sync, loading: _syncing,
            onPressed: () async {
              if (_syncing) return;
              setState(() => _syncing = true);
              await Future.delayed(const Duration(seconds: 1));
              if (mounted) { setState(() => _syncing = false); _snack(context, 'Sync complete — all data up to date'); }
            }),
        ]),
      )),
    ]),
  );
}

// ════════════════════════════════════════════════════════════════
// 8. PRIVACY POLICY  (API-synced)
// ════════════════════════════════════════════════════════════════
class PrivacyPolicyScreen extends ConsumerWidget {
  const PrivacyPolicyScreen({super.key});

  static const _staticSections = [
    _LegalSection('1. Information We Collect',
      'We collect information you provide directly to us, such as donor names, contact details, donation amounts, child welfare records, and programme notes. We also collect device information and usage data to improve app performance.'),
    _LegalSection('2. How We Use Your Information',
      'We use the information to manage donor relationships, track programme impact, generate receipts, send reminders, and fulfil our legal obligations under NGO regulations. Data is never sold or shared with third parties for commercial purposes.'),
    _LegalSection('3. Data Storage & Security',
      'All data is stored on secured servers with AES-256 encryption. Access is restricted to authorised staff only. Regular backups are performed in compliance with Indian data protection norms.'),
    _LegalSection('4. Data Retention',
      'Donor records and financial data are retained for a minimum of 7 years as required by FCRA and Income Tax regulations. Child welfare records are retained for the duration of programme participation plus 3 years.'),
    _LegalSection('5. Your Rights',
      'You have the right to access, correct, or request deletion of your personal data, except where retention is required by law. Contact our Data Officer at privacy@sakshamfoundation.org.'),
    _LegalSection('6. Cookies & Analytics',
      'Our app uses anonymous crash reporting and performance analytics only. No tracking cookies are placed on your device and we do not use advertising networks.'),
    _LegalSection('7. Changes to this Policy',
      'We may update this Privacy Policy from time to time. Changes take effect immediately upon publishing in the app. Continued use constitutes acceptance.'),
    _LegalSection('8. Contact Us',
      'Sri Krishnashraya Educational Trust, No. 42, NGO Campus, Bengaluru – 560067, Karnataka.\nEmail: privacy@sakshamfoundation.org  ·  Phone: +91 80 2345 6789'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apiResult = ref.watch(legalContentProvider('privacy-policy'));
    return _LegalScreen(
      title: 'Privacy Policy', sub: 'Last updated: June 2026',
      icon: Icons.privacy_tip_outlined, sections: _staticSections,
      apiOverride: apiResult.valueOrNull,
    );
  }
}

// ════════════════════════════════════════════════════════════════
// 9. TERMS OF SERVICE  (API-synced)
// ════════════════════════════════════════════════════════════════
class TermsOfServiceScreen extends ConsumerWidget {
  const TermsOfServiceScreen({super.key});

  static const _staticSections = [
    _LegalSection('1. Acceptance of Terms',
      'By using the Sri Krishnashraya Educational Trust Management App, you agree to be bound by these Terms of Service. If you do not agree, please discontinue use immediately.'),
    _LegalSection('2. Authorised Use',
      'This application is intended solely for use by authorised staff, volunteers, and administrators of Sri Krishnashraya Educational Trust. Sharing credentials with unauthorised persons is prohibited.'),
    _LegalSection('3. Donor & Child Data',
      'All data entered is the property of Sri Krishnashraya Educational Trust. Users are responsible for accuracy and must not misuse donor or child beneficiary information.'),
    _LegalSection('4. Financial Records',
      'All financial transactions must be genuine. Fabricating donations, receipts, or expenditure reports is a serious violation and may result in legal action.'),
    _LegalSection('5. Intellectual Property',
      'The app design, code, logos, and content are the intellectual property of Sri Krishnashraya Educational Trust and its technology partners. Reproduction without permission is prohibited.'),
    _LegalSection('6. Limitation of Liability',
      'Sri Krishnashraya Educational Trust is not liable for any loss of data, system downtime, or errors resulting from user actions. Users are responsible for maintaining device security.'),
    _LegalSection('7. Termination',
      'Sri Krishnashraya Educational Trust reserves the right to suspend or revoke app access at any time for violation of these terms or termination of employment/volunteering relationship.'),
    _LegalSection('8. Governing Law',
      'These terms are governed by the laws of India. Any disputes shall be subject to the exclusive jurisdiction of courts in Bengaluru, Karnataka.'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apiResult = ref.watch(legalContentProvider('terms-of-service'));
    return _LegalScreen(
      title: 'Terms of Service', sub: 'Effective: June 2026',
      icon: Icons.gavel_outlined, sections: _staticSections,
      apiOverride: apiResult.valueOrNull,
    );
  }
}

// ════════════════════════════════════════════════════════════════
// 10. ABOUT US  (API-synced)
// ════════════════════════════════════════════════════════════════
class AboutUsScreen extends ConsumerWidget {
  const AboutUsScreen({super.key});

  static const _staticSections = [
    _LegalSection('Who We Are',
      'Sri Krishnashraya Educational Trust is a registered charitable organisation headquartered in Bengaluru, Karnataka. Founded in 2008, we work across education, child welfare, healthcare, and community development to uplift underserved communities across South India.'),
    _LegalSection('Our Mission',
      'To empower every child and family we serve with access to quality education, healthcare, and livelihood support — building a more equitable society, one community at a time.'),
    _LegalSection('Our Impact',
      '15,000+ children supported  ·  ₹8.2 Cr+ raised  ·  48 partner NGOs  ·  12 districts reached\n\nEvery rupee donated is tracked, accounted for, and directed toward maximum beneficiary impact.'),
    _LegalSection('Certifications & Registrations',
      '✦ 80G & 12A Tax Exemption\n✦ FCRA Licensed (Ministry of Home Affairs)\n✦ CSR-1 Registered (MCA)\n✦ GiveIndia Verified NGO\n✦ ISO 9001:2015 Quality Management'),
    _LegalSection('This App',
      'The SKET Admin App is a purpose-built tool for staff and volunteers to manage donors, track donations, monitor student progress, and generate impact reports — all from a single mobile platform.'),
    _LegalSection('Contact Us',
      'Sri Krishnashraya Educational Trust\nNo. 42, NGO Campus, HSR Layout\nBengaluru – 560067, Karnataka\n\nEmail: info@sakshamfoundation.org\nPhone: +91 80 2345 6789\nWebsite: www.sakshamfoundation.org'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apiResult = ref.watch(legalContentProvider('about-us'));
    return _LegalScreen(
      title: 'About Us', sub: 'Sri Krishnashraya Educational Trust · Est. 2008',
      icon: Icons.info_outline, sections: _staticSections,
      apiOverride: apiResult.valueOrNull,
    );
  }
}

// ════════════════════════════════════════════════════════════════
// 11. HELP & SUPPORT
// ════════════════════════════════════════════════════════════════
class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  static const List<Map<String, String>> _faqs = [
    {'q': 'How do I add a new donor?',              'a': 'Go to Donors → tap the + button → fill in donor details and tap Save. The donor will appear in your list immediately.'},
    {'q': 'Can I edit a donation after saving?',     'a': 'Yes. Open the donation from the Donations screen, tap the edit icon in the top right, make changes, and tap Save.'},
    {'q': 'How does a Payment Link work?',           'a': 'Go to Payment Links, fill in the amount and purpose, tap Generate. Share the link via WhatsApp, SMS, or Email directly from the app.'},
    {'q': 'Is my data backed up automatically?',    'a': 'Yes. When Auto Backup is enabled (Settings → Backup & Sync), data is backed up to the cloud every night at midnight.'},
    {'q': 'How do I export a report?',              'a': 'Go to Settings → Export Data, choose format (PDF / Excel / CSV), select date range and data types, then tap Export.'},
    {'q': 'Who can I contact for urgent help?',     'a': 'Call +91 80 2345 6789 (Mon–Fri, 9 AM–6 PM IST) or email support@sakshamfoundation.org. We respond within 4 business hours.'},
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(children: [
      _buildHeader(context, 'Help & Support', sub: 'We\'re here to help'),
      Expanded(child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 40),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(20), margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFE07C1F), Color(0xFFFFB25E)]), borderRadius: BorderRadius.circular(18)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.support_agent_outlined, color: Colors.white, size: 36),
              const SizedBox(height: 10),
              const Text('SKET Support', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
              const Text('Mon–Fri · 9 AM – 6 PM IST', style: TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w500)),
              const SizedBox(height: 14),
              Row(children: [
                _cBtn(Icons.email_outlined, 'Email',
                  onTap: () => launchEmail('support@sakshamfoundation.org', context, subject: 'Support Request – SKET App')),
                const SizedBox(width: 10),
                _cBtn(Icons.phone_outlined, 'Call',
                  onTap: () => launchPhone('+918023456789', context)),
                const SizedBox(width: 10),
                _cBtn(Icons.chat_outlined, 'WhatsApp',
                  onTap: () => launchWhatsApp('918023456789', context, message: 'Hi, I need support for the Sri Krishnashraya Educational Trust app.')),
              ]),
            ])),
          _buildSectionLabel(context, 'FAQs'),
          ..._faqs.map((f) => _FaqTile(q: f['q']!, a: f['a']!)),
          const SizedBox(height: 8),
          _buildSectionLabel(context, 'Guides'),
          _buildCard(context, child: Column(children: [
            _buildRow(context, 'Getting Started',    value: 'Set up your account & first donation', icon: Icons.rocket_launch_outlined, fg: _brand600,
              onTap: () => _showGuide(context, 'Getting Started', [
                'Create or update your profile in Settings → Edit Profile',
                'Add your first donor: tap Donors → + button → fill in contact and category details',
                'Record a donation: tap Donations → + button → pick the donor and enter the amount',
                'Check the Home dashboard for live stats, upcoming reminders, and recent activity',
                'Export data or view analytics via Settings → Export Data and More → Reports',
              ])),
            _buildRow(context, 'Adding Donors',      value: 'How to add and manage donors',         icon: Icons.people_outlined,        fg: _brand600,
              onTap: () => _showGuide(context, 'Adding Donors', [
                'Tap Donors in the bottom navigation bar',
                'Tap the + (Add Donor) floating button at the bottom right',
                'Fill in name, mobile number, email, and donor category',
                'Add PAN / Aadhaar number for 80G receipt generation',
                'Tap Save — the donor appears in your list immediately',
                'Edit or view a donor anytime by tapping their card in the list',
              ])),
            _buildRow(context, 'Payment Links',      value: 'Generate & share payment links',       icon: Icons.link_rounded,           fg: _sky500,
              onTap: () => _showGuide(context, 'Payment Links', [
                'Go to More → Payment Links from the bottom navigation',
                'Tap Generate New Link and fill in the amount and purpose',
                'Optionally link to a specific donor name',
                'Tap Generate — a unique payment URL is created instantly',
                'Share via WhatsApp, SMS, or Email using the share buttons',
                'Track link status (Pending / Paid) from the Payment Links list',
              ])),
            _buildRow(context, 'Export & Reports',   value: 'Download data and generate reports',   icon: Icons.download_outlined,      fg: _violet500,
              onTap: () => _showGuide(context, 'Export & Reports', [
                'Go to Settings → Export Data',
                'Choose your export format: PDF, Excel, or CSV',
                'Select date range and which data types to include',
                'Tap Export — the data is copied to your clipboard',
                'Paste into email, WhatsApp, or open in a spreadsheet app',
                'For charts and analytics, visit More → Reports & Analytics',
              ])),
            _buildRow(context, 'Student Management', value: 'Enrol and track child beneficiaries',  icon: Icons.school_outlined,        fg: _amber600,  last: true,
              onTap: () => _showGuide(context, 'Student Management', [
                'Tap Students in the bottom navigation bar',
                'Tap + to enrol a new student — fill in name, centre, class, and date of birth',
                'Add guardian / parent contact information',
                'Attach a student photo and documents using the upload buttons',
                'Optionally link a sponsorship donor to the student profile',
                'Track attendance and log achievements from the student\'s detail page',
              ])),
          ])),
          const SizedBox(height: 16),
          _buildSectionLabel(context, 'App Info'),
          _buildCard(context, child: Column(children: [
            _buildRow(context, 'App Version',     value: 'v2.4.0 (Build 195)', icon: Icons.info_outline,       fg: context.textSub, trailing: const SizedBox.shrink()),
            _buildRow(context, 'Flutter Version', value: '3.44.1',              icon: Icons.flutter_dash,       fg: _sky500,         last: true, trailing: const SizedBox.shrink()),
          ])),
        ]),
      )),
    ]),
  );

  static Widget _cBtn(IconData icon, String label, {required VoidCallback onTap}) => Expanded(child: GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
      child: Column(children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
      ]),
    ),
  ));

  static void _showGuide(BuildContext context, String title, List<String> steps) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 480, maxHeight: MediaQuery.of(ctx).size.height * 0.72),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              Flexible(child: SingleChildScrollView(child: Column(
                children: steps.asMap().entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(width: 28, height: 28, margin: const EdgeInsets.only(right: 12),
                      decoration: const BoxDecoration(color: _brand100, shape: BoxShape.circle),
                      child: Center(child: Text('${e.key + 1}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _brand600)))),
                    Expanded(child: Padding(padding: const EdgeInsets.only(top: 4),
                      child: Text(e.value,
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: ctx.textSub, height: 1.4)))),
                  ]),
                )).toList(),
              ))),
              const SizedBox(height: 16),
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
            ]),
          ),
        ),
      ),
    );
  }
}

class _FaqTile extends StatefulWidget {
  const _FaqTile({required this.q, required this.a});
  final String q, a;
  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _open = false;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: context.border)),
    child: Column(children: [
      GestureDetector(
        onTap: () => setState(() => _open = !_open),
        behavior: HitTestBehavior.opaque,
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13), child: Row(children: [
          Expanded(child: Text(widget.q, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700))),
          Icon(_open ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: _brand600, size: 20),
        ]))),
      if (_open) Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: Text(widget.a, style: TextStyle(fontSize: 13.5, color: context.textSub, fontWeight: FontWeight.w500, height: 1.5))),
    ]));
}

// ════════════════════════════════════════════════════════════════
// Shared Legal Screen
// ════════════════════════════════════════════════════════════════
class _LegalSection {
  const _LegalSection(this.title, this.body);
  final String title, body;
}

class _LegalScreen extends StatelessWidget {
  const _LegalScreen({required this.title, required this.sub, required this.icon, required this.sections, this.apiOverride});
  final String title, sub;
  final IconData icon;
  final List<_LegalSection> sections;
  final Map<String, String>? apiOverride;

  @override
  Widget build(BuildContext context) {
    final hasLiveBody = apiOverride != null && (apiOverride!['body'] ?? '').isNotEmpty;
    return Scaffold(body: Column(children: [
      _buildHeader(context, title, sub: sub),
      Expanded(child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 40),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (hasLiveBody) Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: _brand100, borderRadius: BorderRadius.circular(8)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.wifi_outlined, size: 14, color: _brand600), SizedBox(width: 6),
              Text('Content synced live from Admin Panel', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _brand600)),
            ])),
          Container(
            padding: const EdgeInsets.all(16), margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFE07C1F), Color(0xFFFFB25E)]), borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              Icon(icon, color: Colors.white, size: 28), const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                Text('Sri Krishnashraya Educational Trust · $sub', style: const TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w500)),
              ])),
            ])),
          if (hasLiveBody)
            Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.border)),
              child: Text(apiOverride!['body']!, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: context.textSub, height: 1.55)))
          else
            ...sections.map((s) => Container(
              margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: context.border)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.title, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: context.textPrimary)),
                const SizedBox(height: 8),
                Text(s.body, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: context.textSub, height: 1.5)),
              ]))),
        ]),
      )),
    ]));
  }
}

// ════════════════════════════════════════════════════════════════
// Razorpay Credentials Screen
// ════════════════════════════════════════════════════════════════
class RazorpayCredentialsScreen extends StatefulWidget {
  const RazorpayCredentialsScreen({super.key});
  @override
  State<RazorpayCredentialsScreen> createState() => _RazorpayCredentialsState();
}

class _RazorpayCredentialsState extends State<RazorpayCredentialsScreen> {
  final _keyIdCtrl        = TextEditingController();
  final _keySecretCtrl    = TextEditingController();
  final _webhookSecretCtrl = TextEditingController();
  bool _loading = true;
  bool _saving  = false;
  bool _obscureSecret  = true;
  bool _obscureWebhook = true;
  bool _clearing = false;
  String? _keyIdError;
  String? _keySecretError;
  // Backend restricts GET/PATCH /settings/razorpay to SUPER_ADMIN — a plain
  // ADMIN (which also passes the app-side isAdmin check) gets a 403 here.
  bool _forbidden = false;

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() {
    _keyIdCtrl.dispose();
    _keySecretCtrl.dispose();
    _webhookSecretCtrl.dispose();
    super.dispose();
  }

  // Backend-persisted (Super Admin only) — the Key Secret must live server
  // side since only the backend ever calls Razorpay's API with it.
  Future<void> _load() async {
    try {
      final r = await apiClient.get('/settings/razorpay');
      final d = (r['data'] as Map?)?.cast<String, dynamic>() ?? {};
      if (mounted) setState(() {
        _keyIdCtrl.text         = d['keyId'] as String? ?? '';
        _keySecretCtrl.text     = d['keySecret'] as String? ?? '';
        _webhookSecretCtrl.text = d['webhookSecret'] as String? ?? '';
        _loading = false;
      });
    } on DioException catch (e) {
      if (mounted) setState(() { _loading = false; _forbidden = e.response?.statusCode == 403; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final keyId         = _keyIdCtrl.text.trim();
    final keySecret     = _keySecretCtrl.text.trim();
    final webhookSecret = _webhookSecretCtrl.text.trim();
    if (_saving) return;
    if (keyId.isEmpty || keySecret.isEmpty) {
      // Say exactly which field is missing, right under it.
      setState(() {
        _keyIdError = keyId.isEmpty ? 'Key ID is required' : null;
        _keySecretError = keySecret.isEmpty ? 'Key Secret is required' : null;
      });
      return;
    }
    setState(() { _saving = true; _keyIdError = null; _keySecretError = null; });
    try {
      await apiClient.patch('/settings/razorpay', {
        'keyId': keyId, 'keySecret': keySecret, 'webhookSecret': webhookSecret,
      });
      if (mounted) AppToast.success(context, 'Razorpay credentials saved');
    } on DioException catch (e) {
      if (mounted) {
        AppToast.error(context, 'Could not save credentials', detail: e.response?.statusCode == 403
          ? 'You do not have permission to update payment settings.'
          : 'Check your connection and try again.');
      }
    } catch (_) {
      if (mounted) AppToast.error(context, 'Could not save credentials', detail: 'Check your connection and try again.');
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _clear() async {
    if (_saving || _clearing) return;
    setState(() { _saving = true; _clearing = true; });
    try {
      await apiClient.patch('/settings/razorpay', {'keyId': '', 'keySecret': '', 'webhookSecret': ''});
      if (mounted) setState(() { _keyIdCtrl.clear(); _keySecretCtrl.clear(); _webhookSecretCtrl.clear(); });
      if (mounted) AppToast.success(context, 'Credentials cleared');
    } on DioException catch (e) {
      if (mounted) {
        AppToast.error(context, 'Could not clear credentials', detail: e.response?.statusCode == 403
          ? 'You do not have permission to update payment settings.'
          : 'Check your connection and try again.');
      }
    } catch (_) {
      if (mounted) AppToast.error(context, 'Could not clear credentials', detail: 'Check your connection and try again.');
    }
    if (mounted) setState(() { _saving = false; _clearing = false; });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(children: [
      _buildHeader(context, 'Razorpay Credentials', sub: 'Payment gateway configuration'),
      if (_loading)
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
          child: _buildCard(context, child: const SkeletonList(rows: 3, rowHeight: 64)),
        ))
      else if (_forbidden)
        const Expanded(child: Center(child: EmptyStateLike(
          icon: Icons.lock_outline,
          title: 'No access',
          message: 'You do not have permission to view payment settings. Only a Super Admin can change them.',
        )))
      else
        Expanded(child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 40),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // Info banner
            Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: _brand100, borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _brand600.withValues(alpha: 0.3))),
              child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.info_outline, color: _brand600, size: 18),
                SizedBox(width: 10),
                Expanded(child: Text(
                  'Get your API keys from the Razorpay Dashboard → Settings → API Keys.\nNever share your Key Secret publicly.',
                  style: TextStyle(fontSize: 12.5, color: _brand600, fontWeight: FontWeight.w600, height: 1.4))),
              ]),
            ),

            _buildSectionLabel(context, 'Key ID (Public)'),
            _buildCard(context, child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _keyIdCtrl,
                enabled: !_saving,
                textInputAction: TextInputAction.next,
                onChanged: (_) { if (_keyIdError != null) setState(() => _keyIdError = null); },
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, fontFamily: 'monospace'),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.vpn_key_outlined, size: 18, color: _brand600),
                  errorText: _keyIdError,
                  hintText: 'rzp_test_XXXXXXXXXXXXXXXXXX',
                  hintStyle: TextStyle(fontSize: 12, color: context.textHint),
                  filled: true, fillColor: context.surface2,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _brand600, width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
              ),
            )),

            const SizedBox(height: 16),
            _buildSectionLabel(context, 'Key Secret (Private)'),
            _buildCard(context, child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _keySecretCtrl,
                obscureText: _obscureSecret,
                enabled: !_saving,
                textInputAction: TextInputAction.next,
                onChanged: (_) { if (_keySecretError != null) setState(() => _keySecretError = null); },
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, fontFamily: 'monospace'),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.lock_outline, size: 18, color: _brand600),
                  errorText: _keySecretError,
                  hintText: '••••••••••••••••••••',
                  hintStyle: TextStyle(fontSize: 12, color: context.textHint),
                  filled: true, fillColor: context.surface2,
                  suffixIcon: IconButton(
                    tooltip: _obscureSecret ? 'Show secret' : 'Hide secret',
                    icon: Icon(_obscureSecret ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18, color: context.textHint),
                    onPressed: () => setState(() => _obscureSecret = !_obscureSecret)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _brand600, width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
              ),
            )),

            const SizedBox(height: 16),
            _buildSectionLabel(context, 'Webhook Secret (Private)'),
            _buildCard(context, child: Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _webhookSecretCtrl,
                obscureText: _obscureWebhook,
                enabled: !_saving,
                onSubmitted: (_) => _save(),
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, fontFamily: 'monospace'),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.webhook_outlined, size: 18, color: _brand600),
                  hintText: '••••••••••••••••••••',
                  hintStyle: TextStyle(fontSize: 12, color: context.textHint),
                  filled: true, fillColor: context.surface2,
                  suffixIcon: IconButton(
                    tooltip: _obscureWebhook ? 'Show secret' : 'Hide secret',
                    icon: Icon(_obscureWebhook ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18, color: context.textHint),
                    onPressed: () => setState(() => _obscureWebhook = !_obscureWebhook)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _brand600, width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
              ),
            )),

            const SizedBox(height: 20),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              AppButton(
                label: 'Clear', busyLabel: 'Clearing…', icon: Icons.delete_outline,
                variant: AppButtonVariant.secondary, loading: _clearing,
                onPressed: _saving ? null : _clear,
              ),
              const SizedBox(width: 8),
              AppButton(
                label: 'Save Credentials', busyLabel: 'Saving…', icon: Icons.save_outlined,
                loading: _saving && !_clearing,
                onPressed: _saving ? null : _save,
              ),
            ]),
          ]),
        )),
    ]),
  );
}

// ════════════════════════════════════════════════════════════════
// WhatsApp Business API — BotSyncWA credentials (Super Admin only).
// Backend-persisted (not local), same GET/PATCH /settings/whatsapp used by
// the WhatsappService that actually sends donation_received, receipt_generated,
// payment_failed, birthday_wishes and donation_anniversary templates.
// ════════════════════════════════════════════════════════════════
class WhatsappSettingsScreen extends StatefulWidget {
  const WhatsappSettingsScreen({super.key});
  @override
  State<WhatsappSettingsScreen> createState() => _WhatsappSettingsState();
}

class _WhatsappSettingsState extends State<WhatsappSettingsScreen> {
  final _storeNumberCtrl   = TextEditingController();
  final _phoneNumberIdCtrl = TextEditingController();
  final _apiTokenCtrl      = TextEditingController();
  final _apiUrlCtrl        = TextEditingController();
  final _apiVersionCtrl    = TextEditingController();
  final _wabaIdCtrl        = TextEditingController();
  final _businessIdCtrl    = TextEditingController();

  bool _loading = true;
  bool _saving  = false;
  bool _obscureToken = true;

  // Native-Meta passthrough mode (API Version / WABA ID / Business ID) only
  // applies when the configured API URL contains "/api/meta".
  bool get _isMetaMode => _apiUrlCtrl.text.toLowerCase().contains('/api/meta');

  @override
  void initState() { super.initState(); _load(); _apiUrlCtrl.addListener(() => setState(() {})); }

  @override
  void dispose() {
    _storeNumberCtrl.dispose(); _phoneNumberIdCtrl.dispose(); _apiTokenCtrl.dispose();
    _apiUrlCtrl.dispose(); _apiVersionCtrl.dispose(); _wabaIdCtrl.dispose(); _businessIdCtrl.dispose();
    super.dispose();
  }

  void _apply(Map<String, dynamic> d) {
    _storeNumberCtrl.text   = d['storeNumber'] as String? ?? '';
    _phoneNumberIdCtrl.text = d['phoneNumberId'] as String? ?? '';
    _apiTokenCtrl.text      = d['apiToken'] as String? ?? '';
    _apiUrlCtrl.text        = d['apiUrl'] as String? ?? '';
    _apiVersionCtrl.text    = d['apiVersion'] as String? ?? '';
    _wabaIdCtrl.text        = d['wabaId'] as String? ?? '';
    _businessIdCtrl.text    = d['businessId'] as String? ?? '';
  }

  Future<void> _load() async {
    try {
      final r = await apiClient.get('/settings/whatsapp');
      final d = (r['data'] as Map?)?.cast<String, dynamic>() ?? {};
      if (mounted) setState(() { _apply(d); _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final r = await apiClient.patch('/settings/whatsapp', {
        'storeNumber':   _storeNumberCtrl.text.trim(),
        'phoneNumberId': _phoneNumberIdCtrl.text.trim(),
        'apiToken':      _apiTokenCtrl.text.trim(),
        'apiUrl':        _apiUrlCtrl.text.trim(),
        'apiVersion':    _apiVersionCtrl.text.trim(),
        'wabaId':        _wabaIdCtrl.text.trim(),
        'businessId':    _businessIdCtrl.text.trim(),
      });
      final d = (r['data'] as Map?)?.cast<String, dynamic>() ?? {};
      if (mounted) { setState(() => _apply(d)); AppToast.success(context, 'WhatsApp settings saved'); }
    } catch (e) {
      if (mounted) AppToast.error(context, 'Could not save WhatsApp settings', detail: ApiClient.errorMessage(e, fallback: 'Check your connection and try again.'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(String label, TextEditingController ctrl, {String? hint, bool obscure = false, Widget? suffix, IconData? icon}) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildSectionLabel(context, label),
      _buildCard(context, child: Padding(
        padding: const EdgeInsets.all(16),
        child: TextField(
          controller: ctrl,
          obscureText: obscure,
          enabled: !_saving,
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, fontFamily: 'monospace'),
          decoration: InputDecoration(
            prefixIcon: icon != null ? Icon(icon, size: 18, color: _brand600) : null,
            suffixIcon: suffix,
            hintText: hint,
            hintStyle: TextStyle(fontSize: 12, color: context.textHint),
            filled: true, fillColor: context.surface2,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _brand600, width: 1.5)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
        ),
      )),
      const SizedBox(height: 16),
    ]);

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(children: [
      _buildHeader(context, 'WhatsApp Business API', sub: 'Donation & receipt messaging via BotSyncWA'),
      if (_loading)
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
          child: _buildCard(context, child: const SkeletonList(rows: 3, rowHeight: 64)),
        ))
      else
        Expanded(child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(0, 20, 0, 40),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.symmetric(horizontal: 18), child: Container(
              padding: const EdgeInsets.all(14),
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: _brand100, borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _brand600.withValues(alpha: 0.3))),
              child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.info_outline, color: _brand600, size: 18),
                SizedBox(width: 10),
                Expanded(child: Text(
                  'Auto-sends donation confirmation & receipt messages to donors via BotSyncWA. '
                  'Requires approved templates (donation_received, receipt_generated, payment_failed, '
                  'birthday_wishes, donation_anniversary) in Meta Business Manager.',
                  style: TextStyle(fontSize: 12.5, color: _brand600, fontWeight: FontWeight.w600, height: 1.4))),
              ]),
            )),

            _field('Store WhatsApp Number', _storeNumberCtrl, hint: '919832399399', icon: Icons.phone_outlined),
            _field('Phone Number ID', _phoneNumberIdCtrl, hint: '1129335896919323', icon: Icons.tag_outlined),
            _field('API Token', _apiTokenCtrl, hint: '••••••••••••••••', obscure: _obscureToken, icon: Icons.vpn_key_outlined,
              suffix: IconButton(
                tooltip: _obscureToken ? 'Show token' : 'Hide token',
                icon: Icon(_obscureToken ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18, color: context.textHint),
                onPressed: () => setState(() => _obscureToken = !_obscureToken))),
            _field('API URL (optional override)', _apiUrlCtrl, hint: 'https://crmapp.botsyncwa.com/api/v1/messages', icon: Icons.link),
            if (_isMetaMode) ...[
              _field('API Version', _apiVersionCtrl, hint: 'v19.0', icon: Icons.numbers_outlined),
              _field('WABA ID', _wabaIdCtrl, hint: '1951565062163055', icon: Icons.badge_outlined),
              _field('Business ID', _businessIdCtrl, hint: '1075079811743037', icon: Icons.apartment_outlined),
            ],

            Padding(padding: const EdgeInsets.symmetric(horizontal: 18), child:
              _formAction(context, label: 'Save Changes', busyLabel: 'Saving…', icon: Icons.save_outlined,
                loading: _saving, onPressed: _save)),
          ]),
        )),
    ]),
  );
}

// ════════════════════════════════════════════════════════════════
// MANAGE ROLES
// ════════════════════════════════════════════════════════════════

class ManageRolesScreen extends StatefulWidget {
  const ManageRolesScreen({super.key});
  @override
  State<ManageRolesScreen> createState() => _ManageRolesState();
}

class _ManageRolesState extends State<ManageRolesScreen> {
  // Role definitions now live in the shared, persisted role-template store
  // (core/auth/role_auth.dart) so edits control real access and survive restart.
  List<Map<String, dynamic>> get _roles => roleTemplates;

  List<String> _summary(Map<String, dynamic> perms) {
    bool p(String mod, String key) {
      final m = perms[mod];
      if (m is Map) return (m[key] as bool?) ?? false;
      return false;
    }
    String _level(String mod) {
      if (p(mod, 'delete')) return 'Full CRUD';
      if (p(mod, 'edit'))   return 'No Delete';
      if (p(mod, 'add'))    return 'Add only';
      if (p(mod, 'view'))   return 'View only';
      return '';
    }
    final parts = <String>[];
    for (final entry in {
      'donors': 'Donors', 'donations': 'Donations', 'expenses': 'Expenses', 'students': 'Students',
      'offices': 'Offices', 'reminders': 'Reminders',
      'donationTracker': 'Tracker', 'paymentLinks': 'Pay Links', 'achievements': 'Achievements', 'staff': 'Staff',
    }.entries) {
      final lv = _level(entry.key);
      if (lv.isNotEmpty) parts.add('${entry.value} ($lv)');
    }
    if (p('reports', 'export'))    parts.add('Reports + Export');
    else if (p('reports', 'view')) parts.add('Reports (view)');
    if (p('settings', 'access'))   parts.add('Settings');
    if (parts.isEmpty)             parts.add('No module access');
    return parts;
  }

  void _showRoleSheet(BuildContext context, {Map<String, dynamic>? role}) {
    final isNew    = role == null;
    final nameCtrl = TextEditingController(text: isNew ? '' : role['name'] as String);
    final descCtrl = TextEditingController(text: isNew ? '' : role['desc'] as String);
    String? nameError;

    Map<String, bool> initPerm(String mod, List<String> keys) {
      final src = (role?['perms'] as Map?)?[mod];
      return {for (final k in keys) k: (src is Map ? (src[k] as bool?) : null) ?? false};
    }

    final perms = <String, Map<String, bool>>{
      'donors':          initPerm('donors',          ['view', 'add', 'edit', 'delete']),
      'donations':       initPerm('donations',       ['view', 'add', 'edit', 'delete']),
      'expenses':        initPerm('expenses',        ['view', 'add', 'edit', 'delete']),
      'students':        initPerm('students',        ['view', 'add', 'edit', 'delete']),
      'offices':         initPerm('offices',         ['view', 'add', 'edit', 'delete']),
      'reports':         initPerm('reports',         ['view', 'export']),
      'reminders':       initPerm('reminders',       ['view', 'add', 'edit', 'delete']),
      'donationTracker': initPerm('donationTracker', ['view', 'add', 'edit', 'delete']),
      'paymentLinks':    initPerm('paymentLinks',    ['view', 'add', 'edit', 'delete']),
      'achievements':    initPerm('achievements',    ['view', 'add', 'edit', 'delete']),
      'staff':           initPerm('staff',           ['view', 'add', 'edit', 'delete']),
      'settings':        initPerm('settings',        ['access']),
    };

    showAppSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.92,
          decoration: BoxDecoration(
            color: context.cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(children: [
            // handle + title bar
            const SheetHandle(margin: EdgeInsets.only(top: 10)),
            Padding(padding: const EdgeInsets.fromLTRB(20, 10, 8, 0), child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(isNew ? 'Create Role' : 'Edit Role',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('Choose what members with this role can see and do.',
                  style: TextStyle(fontSize: 12.5, color: context.textSub)),
              ])),
              IconButton(tooltip: 'Close', icon: Icon(Icons.close_rounded, size: 20, color: context.textSub), onPressed: () => Navigator.pop(ctx)),
            ])),
            const SizedBox(height: 4),
            Expanded(child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Role Name *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: context.textSub)),
                const SizedBox(height: 6),
                TextField(
                  controller: nameCtrl,
                  autofocus: isNew,
                  textInputAction: TextInputAction.next,
                  onChanged: (_) { if (nameError != null) setSt(() => nameError = null); },
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    errorText: nameError,
                    hintText: 'e.g. Programme Officer, Accountant',
                    hintStyle: TextStyle(color: context.textHint),
                    filled: true, fillColor: context.surface2,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _brand600, width: 1.5)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),
                Text('Description', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: context.textSub)),
                const SizedBox(height: 6),
                TextField(
                  controller: descCtrl,
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: 'Brief description of what this role does',
                    hintStyle: TextStyle(color: context.textHint),
                    filled: true, fillColor: context.surface2,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _brand600, width: 1.5)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 22),
                Text('PERMISSIONS', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: context.textHint, letterSpacing: 0.8)),
                const SizedBox(height: 10),
                _PermModule(
                  icon: Icons.people_outlined, color: _brand600, title: 'Donors',
                  perms: perms['donors']!,
                  labels: const {'view': 'View', 'add': 'Add', 'edit': 'Edit', 'delete': 'Delete'},
                  onToggle: (k, v) => setSt(() {
                    perms['donors']![k] = v;
                    if (v && k != 'view') perms['donors']!['view'] = true;
                    if (v && k == 'delete') perms['donors']!['edit'] = true;
                    if (!v && k == 'view') { perms['donors']!['add'] = false; perms['donors']!['edit'] = false; perms['donors']!['delete'] = false; }
                  }),
                ),
                const SizedBox(height: 10),
                _PermModule(
                  icon: Icons.account_balance_wallet_outlined, color: _amber600, title: 'Donations',
                  perms: perms['donations']!,
                  labels: const {'view': 'View', 'add': 'Add', 'edit': 'Edit', 'delete': 'Delete'},
                  onToggle: (k, v) => setSt(() {
                    perms['donations']![k] = v;
                    if (v && k != 'view') perms['donations']!['view'] = true;
                    if (v && k == 'delete') perms['donations']!['edit'] = true;
                    if (!v && k == 'view') { perms['donations']!['add'] = false; perms['donations']!['edit'] = false; perms['donations']!['delete'] = false; }
                  }),
                ),
                const SizedBox(height: 10),
                _PermModule(
                  icon: Icons.payments_outlined, color: _coral500, title: 'Expenses',
                  perms: perms['expenses']!,
                  labels: const {'view': 'View', 'add': 'Add', 'edit': 'Edit', 'delete': 'Delete'},
                  onToggle: (k, v) => setSt(() {
                    perms['expenses']![k] = v;
                    if (v && k != 'view') perms['expenses']!['view'] = true;
                    if (v && k == 'delete') perms['expenses']!['edit'] = true;
                    if (!v && k == 'view') { perms['expenses']!['add'] = false; perms['expenses']!['edit'] = false; perms['expenses']!['delete'] = false; }
                  }),
                ),
                const SizedBox(height: 10),
                _PermModule(
                  icon: Icons.school_outlined, color: _violet500, title: 'Students',
                  perms: perms['students']!,
                  labels: const {'view': 'View', 'add': 'Add', 'edit': 'Edit', 'delete': 'Delete'},
                  onToggle: (k, v) => setSt(() {
                    perms['students']![k] = v;
                    if (v && k != 'view') perms['students']!['view'] = true;
                    if (v && k == 'delete') perms['students']!['edit'] = true;
                    if (!v && k == 'view') { perms['students']!['add'] = false; perms['students']!['edit'] = false; perms['students']!['delete'] = false; }
                  }),
                ),
                const SizedBox(height: 10),
                _PermModule(
                  icon: Icons.business_outlined, color: _sky500, title: 'Offices',
                  perms: perms['offices']!,
                  labels: const {'view': 'View', 'add': 'Add', 'edit': 'Edit', 'delete': 'Delete'},
                  onToggle: (k, v) => setSt(() {
                    perms['offices']![k] = v;
                    if (v && k != 'view') perms['offices']!['view'] = true;
                    if (v && k == 'delete') perms['offices']!['edit'] = true;
                    if (!v && k == 'view') { perms['offices']!['add'] = false; perms['offices']!['edit'] = false; perms['offices']!['delete'] = false; }
                  }),
                ),
                const SizedBox(height: 10),
                _PermModule(
                  icon: Icons.bar_chart_rounded, color: _sky500, title: 'Reports & Analytics',
                  perms: perms['reports']!,
                  labels: const {'view': 'View reports', 'export': 'Export data'},
                  onToggle: (k, v) => setSt(() {
                    perms['reports']![k] = v;
                    if (v && k == 'export') perms['reports']!['view'] = true;
                  }),
                ),
                const SizedBox(height: 10),
                _PermModule(
                  icon: Icons.notifications_outlined, color: _amber600, title: 'Reminders',
                  perms: perms['reminders']!,
                  labels: const {'view': 'View', 'add': 'Add', 'edit': 'Edit', 'delete': 'Delete'},
                  onToggle: (k, v) => setSt(() {
                    perms['reminders']![k] = v;
                    if (v && k != 'view') perms['reminders']!['view'] = true;
                    if (v && k == 'delete') perms['reminders']!['edit'] = true;
                    if (!v && k == 'view') { perms['reminders']!['add'] = false; perms['reminders']!['edit'] = false; perms['reminders']!['delete'] = false; }
                  }),
                ),
                const SizedBox(height: 10),
                _PermModule(
                  icon: Icons.track_changes_outlined, color: _brand600, title: 'Donation Tracker',
                  perms: perms['donationTracker']!,
                  labels: const {'view': 'View', 'add': 'Add', 'edit': 'Edit', 'delete': 'Delete'},
                  onToggle: (k, v) => setSt(() {
                    perms['donationTracker']![k] = v;
                    if (v && k != 'view') perms['donationTracker']!['view'] = true;
                    if (v && k == 'delete') perms['donationTracker']!['edit'] = true;
                    if (!v && k == 'view') { perms['donationTracker']!['add'] = false; perms['donationTracker']!['edit'] = false; perms['donationTracker']!['delete'] = false; }
                  }),
                ),
                const SizedBox(height: 10),
                _PermModule(
                  icon: Icons.link_rounded, color: _violet500, title: 'Payment Links',
                  perms: perms['paymentLinks']!,
                  labels: const {'view': 'View', 'add': 'Add', 'edit': 'Edit', 'delete': 'Delete'},
                  onToggle: (k, v) => setSt(() {
                    perms['paymentLinks']![k] = v;
                    if (v && k != 'view') perms['paymentLinks']!['view'] = true;
                    if (v && k == 'delete') perms['paymentLinks']!['edit'] = true;
                    if (!v && k == 'view') { perms['paymentLinks']!['add'] = false; perms['paymentLinks']!['edit'] = false; perms['paymentLinks']!['delete'] = false; }
                  }),
                ),
                const SizedBox(height: 10),
                _PermModule(
                  icon: Icons.emoji_events_outlined, color: _amber600, title: 'Achievements',
                  perms: perms['achievements']!,
                  labels: const {'view': 'View', 'add': 'Add', 'edit': 'Edit', 'delete': 'Delete'},
                  onToggle: (k, v) => setSt(() {
                    perms['achievements']![k] = v;
                    if (v && k != 'view') perms['achievements']!['view'] = true;
                    if (v && k == 'delete') perms['achievements']!['edit'] = true;
                    if (!v && k == 'view') { perms['achievements']!['add'] = false; perms['achievements']!['edit'] = false; perms['achievements']!['delete'] = false; }
                  }),
                ),
                const SizedBox(height: 10),
                _PermModule(
                  icon: Icons.badge_outlined, color: _sky500, title: 'Staff (salary & bank details)',
                  perms: perms['staff']!,
                  labels: const {'view': 'View', 'add': 'Add', 'edit': 'Edit', 'delete': 'Delete'},
                  onToggle: (k, v) => setSt(() {
                    perms['staff']![k] = v;
                    if (v && k != 'view') perms['staff']!['view'] = true;
                    if (v && k == 'delete') perms['staff']!['edit'] = true;
                    if (!v && k == 'view') { perms['staff']!['add'] = false; perms['staff']!['edit'] = false; perms['staff']!['delete'] = false; }
                  }),
                ),
                const SizedBox(height: 10),
                _PermModule(
                  icon: Icons.settings_outlined, color: const Color(0xFF64748B), title: 'Settings',
                  perms: perms['settings']!,
                  labels: const {'access': 'Access settings page'},
                  onToggle: (k, v) => setSt(() => perms['settings']![k] = v),
                ),
              ]),
            )),
            Container(
              decoration: BoxDecoration(border: Border(top: BorderSide(color: context.border))),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              AppButton(label: 'Cancel', variant: AppButtonVariant.secondary, onPressed: () => Navigator.pop(ctx)),
              const SizedBox(width: 8),
              AppButton(
                label: isNew ? 'Create Role' : 'Save Changes',
                onPressed: () {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) { setSt(() => nameError = 'Please enter a role name.'); return; }
                  if (isNew) {
                    setState(() => _roles.add({
                      'name': name, 'desc': descCtrl.text.trim(),
                      'isSystem': false, 'perms': perms,
                    }));
                    saveRoleTemplates();
                    applyTemplateToMembers(name);
                    _snack(context, '"$name" role created', error: false);
                  } else {
                    final oldName = role!['name'] as String;
                    final idx = _roles.indexOf(role);
                    if (idx >= 0) setState(() {
                      _roles[idx]['name'] = name;
                      _roles[idx]['desc'] = descCtrl.text.trim();
                      _roles[idx]['perms'] = perms;
                    });
                    // Re-point members that referenced the old name, then
                    // re-apply the (possibly changed) permissions to them.
                    if (oldName != name) {
                      for (final mbr in appRoles) {
                        if (mbr.roleName.toLowerCase() == oldName.toLowerCase()) mbr.roleName = name;
                      }
                    }
                    saveRoleTemplates();
                    applyTemplateToMembers(name);
                    _snack(context, '"$name" role updated', error: false);
                  }
                  Navigator.pop(ctx);
                },
              ),
            ])),
          ]),
        );
      }),
    );
  }

  void _confirmDelete(BuildContext context, int idx) {
    final roleName = _roles[idx]['name'] as String;
    AppConfirm.show(
      context,
      title: 'Delete role?',
      message: 'Delete the “$roleName” role? Members with this role will lose access. This cannot be undone.',
      confirmLabel: 'Delete Role',
    ).then((ok) {
      if (!ok || !mounted) return;
      setState(() => _roles.removeAt(idx));
      // Members that used this role keep their current access but are
      // no longer linked to a template.
      for (final mbr in appRoles) {
        if (mbr.roleName.toLowerCase() == roleName.toLowerCase()) mbr.roleName = '';
      }
      saveRoleTemplates();
      saveRoles();
      _snack(this.context, '"$roleName" role deleted', error: false);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(children: [
      _buildHeader(context, 'Manage Roles', sub: 'Control what each staff member can access',
        action: AppButton(label: 'New Role', icon: Icons.add, onPressed: () => _showRoleSheet(context))),
      Expanded(child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
        physics: const BouncingScrollPhysics(),
        itemCount: _roles.length,
        itemBuilder: (ctx, i) {
          final r        = _roles[i];
          final isSystem = r['isSystem'] as bool;
          final roleNm   = r['name'] as String;
          // Live member count = team members assigned this role (+ admin for the System role).
          final members  = appRoles.where((m) => m.roleName.toLowerCase() == roleNm.toLowerCase()).length
              + (isSystem ? 1 : 0);
          final summary  = _summary(r['perms'] as Map<String, dynamic>);
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: context.cardBg, borderRadius: BorderRadius.circular(18),
              border: Border.all(color: context.border),
              boxShadow: const [BoxShadow(color: Color(0x080D2822), blurRadius: 6, offset: Offset(0, 2))],
            ),
            child: Padding(padding: const EdgeInsets.all(16), child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 46, height: 46,
                  decoration: BoxDecoration(
                    color: isSystem ? _brand100 : context.surface2,
                    borderRadius: BorderRadius.circular(13)),
                  child: Icon(
                    isSystem ? Icons.admin_panel_settings_outlined : Icons.manage_accounts_outlined,
                    color: isSystem ? _brand600 : context.textSub, size: 22)),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Text(r['name'] as String,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                    if (isSystem) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(color: _brand100, borderRadius: BorderRadius.circular(6)),
                        child: const Text('System',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: _brand600))),
                    ],
                  ]),
                  const SizedBox(height: 3),
                  Text(r['desc'] as String,
                    style: TextStyle(fontSize: 12.5, color: context.textSub, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 6, runSpacing: 4, children: summary.map((p) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: context.surface2, borderRadius: BorderRadius.circular(6)),
                    child: Text(p, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.textSub)),
                  )).toList()),
                  const SizedBox(height: 6),
                  Text('$members member${members == 1 ? "" : "s"}',
                    style: TextStyle(fontSize: 12, color: context.textHint, fontWeight: FontWeight.w500)),
                ])),
                if (!isSystem) PopupMenuButton<String>(
                  tooltip: 'Actions for ${r['name']}',
                  position: PopupMenuPosition.under,
                  onSelected: (v) {
                    if (v == 'edit')   _showRoleSheet(context, role: r);
                    if (v == 'delete') _confirmDelete(context, i);
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit',   child: Row(children: [Icon(Icons.edit_outlined,  size: 18), SizedBox(width: 10), Text('Edit')])),
                    PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, size: 18, color: _coral500), SizedBox(width: 10), Text('Delete', style: TextStyle(color: _coral500))])),
                  ],
                  icon: Icon(Icons.more_vert, size: 20, color: context.textSub),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ],
            )),
          );
        },
      )),
    ]),
  );
}

// per-module permission toggle card used inside the role sheet
class _PermModule extends StatelessWidget {
  const _PermModule({
    required this.icon, required this.color, required this.title,
    required this.perms, required this.labels, required this.onToggle,
  });
  final IconData icon;
  final Color    color;
  final String   title;
  final Map<String, bool>   perms;
  final Map<String, String> labels;
  final void Function(String key, bool val) onToggle;

  @override
  Widget build(BuildContext context) {
    final keys = labels.keys.toList();
    return Container(
      decoration: BoxDecoration(
        color: context.cardBg, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.border)),
      child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          child: Row(children: [
            Container(width: 34, height: 34,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: color, size: 18)),
            const SizedBox(width: 10),
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
          ])),
        const Divider(height: 1),
        ...keys.map((k) {
          final isLast = k == keys.last;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: isLast ? null : BoxDecoration(border: Border(bottom: BorderSide(color: context.border))),
            child: Row(children: [
              const SizedBox(width: 44),
              Expanded(child: Text(labels[k]!,
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: context.textSub))),
              Switch(
                value: perms[k] ?? false,
                onChanged: (v) => onToggle(k, v),
                activeColor: color,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ]),
          );
        }),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// ADMIN PANEL  (professional redesign)
// ════════════════════════════════════════════════════════════════

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});
  @override
  State<AdminPanelScreen> createState() => _AdminPanelState();
}

class _AdminPanelState extends State<AdminPanelScreen> {
  int? _staff, _donorsTotal, _studentsTotal, _officesTotal;
  int? _monthAmount;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    Future<int?> total(String path) async {
      try {
        final r = await apiClient.get(path, params: {'limit': '1', 'page': '1'});
        return (r['meta'] as Map?)?['total'] as int?;
      } catch (_) { return null; }
    }
    final results = await Future.wait<dynamic>([
      total('/users'),
      total('/donors'),
      total('/students'),
      () async {
        try {
          final r = await apiClient.get('/offices');
          final inner = r['data'];
          return inner is List ? inner.length : null;
        } catch (_) { return null; }
      }(),
      () async {
        try {
          final r = await apiClient.get('/donations/summary');
          return ((r['data'] as Map?)?['month'] as Map?)?['amount'] as int?;
        } catch (_) { return null; }
      }(),
    ]);
    if (mounted) setState(() {
      _staff = results[0] as int?;
      _donorsTotal = results[1] as int?;
      _studentsTotal = results[2] as int?;
      _officesTotal = results[3] as int?;
      _monthAmount = results[4] as int?;
    });
  }

  String _n(int? v) => v?.toString() ?? '—';

  String _inrCompact(int n) {
    if (n >= 10000000) return '₹${(n / 10000000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}Cr';
    if (n >= 100000) return '₹${(n / 100000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}L';
    if (n >= 1000) return '₹${(n / 1000).round()}K';
    return '₹$n';
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final profile = adminProfile.value;
    final displayName = currentLoggedInRole?.name ?? profile.name;
    final initials = displayName.trim().isEmpty ? '?' :
        displayName.trim().split(RegExp(r'\s+')).map((w) => w[0]).take(2).join().toUpperCase();
    return Scaffold(
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Welcome banner ──────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF7A3E0A), Color(0xFFFF9933), Color(0xFFFFB25E)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
            ),
            padding: EdgeInsets.fromLTRB(18, top + 14, 18, 28),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // back row
              Row(children: [
                GestureDetector(
                  onTap: () => context.go('/settings'),
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(9)),
                    child: const Icon(Icons.arrow_back_ios_new_rounded, size: 15, color: Colors.white)),
                ),
                const SizedBox(width: 12),
                const Text('Admin Panel',
                    style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 20),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Welcome back,',
                      style: TextStyle(color: Colors.white60, fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(displayName,
                      style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900,
                          letterSpacing: -0.6, height: 1.1)),
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 6, children: [
                    _Chip(label: '🛡️  Administrator'),
                    _Chip(label: profile.org.isNotEmpty ? profile.org : 'Sri Krishnashraya Educational Trust'),
                  ]),
                ])),
                const SizedBox(width: 14),
                Container(
                  width: 58, height: 58,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2)),
                  child: Center(child: Text(initials,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)))),
              ]),
            ]),
          ),

          // ── KPI stat cards (live data) ──────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 0),
            child: Row(children: [
              _Kpi(value: _n(_staff),         label: 'Total Staff',    icon: Icons.badge_outlined,           color: _brand600,  bg: _brand100),
              const SizedBox(width: 10),
              _Kpi(value: '${roleTemplates.length}', label: 'Active Roles', icon: Icons.manage_accounts_outlined, color: _violet500, bg: const Color(0xFFEDE9FE)),
              const SizedBox(width: 10),
              _Kpi(value: _n(_studentsTotal), label: 'Total Students', icon: Icons.school_outlined,          color: _sky500,    bg: _sky100),
              const SizedBox(width: 10),
              _Kpi(value: _n(_donorsTotal),   label: 'Total Donors',   icon: Icons.people_outlined,          color: _amber600,  bg: const Color(0xFFFFF1D6)),
            ]),
          ),

          // ── Quick Actions ───────────────────────────────────────────
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _Label(text: 'Quick Actions'),
              const SizedBox(height: 10),
              LayoutBuilder(builder: (ctx, box) {
                final cols = box.maxWidth > 460 ? 3 : 2;
                final actions = <Map<String, dynamic>>[
                  {'icon': Icons.people_outlined,          'color': _brand600,  'bg': _brand100,            'label': 'Team Members',     'route': '/settings/team-members'},
                  {'icon': Icons.location_city_outlined,   'color': _violet500, 'bg': const Color(0xFFEDE9FE), 'label': 'Manage Centres', 'route': '/settings/centres'},
                  {'icon': Icons.category_outlined,        'color': _amber600,  'bg': const Color(0xFFFFF1D6), 'label': 'Donation Types', 'route': '/settings/donation-types'},
                  {'icon': Icons.face_outlined,            'color': _coral500,  'bg': _coral100,            'label': 'Student Categories', 'route': '/settings/student-categories'},
                  {'icon': Icons.receipt_long_outlined,    'color': _brand600,  'bg': _brand100,            'label': 'Expense Categories', 'route': '/settings/expense-categories'},
                  {'icon': Icons.download_outlined,        'color': _sky500,    'bg': _sky100,              'label': 'Export Data',      'route': '/settings/export-data'},
                  {'icon': Icons.cloud_sync_outlined,      'color': _sky500,    'bg': _sky100,              'label': 'Backup & Sync',    'route': '/settings/backup-sync'},
                ];
                final spacing = 10.0;
                final w = (box.maxWidth - (cols - 1) * spacing) / cols;
                return Wrap(spacing: spacing, runSpacing: spacing,
                  children: actions.map((a) => SizedBox(width: w, child: _ActionCard(
                    icon: a['icon'] as IconData, color: a['color'] as Color,
                    bg: a['bg'] as Color, label: a['label'] as String,
                    onTap: () => context.go(a['route'] as String),
                  ))).toList());
              }),
            ]),
          ),

          // ── Module Overview ─────────────────────────────────────────
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _Label(text: 'Module Overview'),
              const SizedBox(height: 10),
              _buildCard(context, child: Column(children: [
                _ModRow(icon: Icons.people_outlined,                  color: _brand600,  bg: _brand100,            label: 'Donors',        value: '${_n(_donorsTotal)} total',   route: '/donors'),
                _ModRow(icon: Icons.account_balance_wallet_outlined,  color: _amber600,  bg: const Color(0xFFFFF1D6), label: 'Donations',  value: _monthAmount != null ? '${_inrCompact(_monthAmount!)} this month' : '—', route: '/donations'),
                _ModRow(icon: Icons.school_outlined,                  color: _violet500, bg: const Color(0xFFEDE9FE), label: 'Students',   value: '${_n(_studentsTotal)} enrolled', route: '/students'),
                _ModRow(icon: Icons.bar_chart_rounded,                color: _sky500,    bg: _sky100,              label: 'Reports',       value: 'Analytics',       route: '/reports'),
                _ModRow(icon: Icons.business_outlined,                color: _brand600,  bg: _brand100,            label: 'Offices',       value: '${_n(_officesTotal)} locations', route: '/offices', last: true),
              ])),
            ]),
          ),

          // ── System Settings quick links ────────────────────────────
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _Label(text: 'System'),
              const SizedBox(height: 10),
              _buildCard(context, child: Column(children: [
                _buildRow(context, 'Security & PIN',
                  icon: Icons.lock_outline, fg: _violet500,
                  onTap: () => context.go('/settings/security-pin')),
                _buildRow(context, 'Linked Devices',
                  icon: Icons.devices_outlined, fg: _sky500, value: '2 devices',
                  onTap: () => context.go('/settings/linked-devices')),
                _buildRow(context, 'Audit Log',
                  icon: Icons.history_outlined, fg: context.textSub, value: 'Coming soon',
                  last: true, onTap: null),
              ])),
            ]),
          ),

          const SizedBox(height: 96),
        ]),
      ),
    );
  }
}

// ── Admin Panel helper widgets ────────────────────────────────────────

class _Chip extends StatelessWidget {
  const _Chip({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.white.withValues(alpha: 0.25))),
    child: Text(label,
        style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)));
}

class _Kpi extends StatelessWidget {
  const _Kpi({required this.value, required this.label, required this.icon, required this.color, required this.bg});
  final String value, label; final IconData icon; final Color color, bg;
  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: context.cardBg, borderRadius: BorderRadius.circular(18),
      border: Border.all(color: context.border),
      boxShadow: const [BoxShadow(color: Color(0x080D2822), blurRadius: 6, offset: Offset(0, 2))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 34, height: 34, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 18)),
      const SizedBox(height: 10),
      Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
      Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: context.textSub, height: 1.2)),
    ]),
  ));
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({required this.icon, required this.color, required this.bg, required this.label, required this.onTap});
  final IconData icon; final Color color, bg; final String label; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: context.cardBg, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.border),
        boxShadow: const [BoxShadow(color: Color(0x060D2822), blurRadius: 4, offset: Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Container(width: 36, height: 36, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 18)),
        const SizedBox(height: 10),
        Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: context.textPrimary)),
        const SizedBox(height: 2),
        Row(children: [
          Text('Open', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
          const SizedBox(width: 3),
          Icon(Icons.arrow_forward_rounded, size: 11, color: color),
        ]),
      ]),
    ),
  );
}

class _ModRow extends StatelessWidget {
  const _ModRow({required this.icon, required this.color, required this.bg,
    required this.label, required this.value, required this.route, this.last = false});
  final IconData icon; final Color color, bg; final String label, value, route; final bool last;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => context.go(route),
    behavior: HitTestBehavior.opaque,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: last ? null : BoxDecoration(border: Border(bottom: BorderSide(color: context.border))),
      child: Row(children: [
        Container(width: 36, height: 36, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, color: color, size: 18)),
        const SizedBox(width: 12),
        Expanded(child: Text(label,
            style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: context.textPrimary))),
        Text(value, style: TextStyle(fontSize: 12.5, color: context.textSub, fontWeight: FontWeight.w600)),
        const SizedBox(width: 6),
        Icon(Icons.chevron_right, size: 18, color: context.textHint),
      ]),
    ),
  );
}

class _ActRow extends StatelessWidget {
  const _ActRow({required this.dot, required this.text, required this.time, this.last = false});
  final Color dot; final String text, time; final bool last;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
    decoration: last ? null : BoxDecoration(border: Border(bottom: BorderSide(color: context.border))),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Container(width: 8, height: 8, decoration: BoxDecoration(color: dot, shape: BoxShape.circle))),
      const SizedBox(width: 12),
      Expanded(child: Text(text,
          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: context.textPrimary))),
      const SizedBox(width: 8),
      Text(time, style: TextStyle(fontSize: 11.5, color: context.textHint, fontWeight: FontWeight.w500)),
    ]),
  );
}

class _Label extends StatelessWidget {
  const _Label({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(),
      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: context.textHint, letterSpacing: 0.9));
}

// ════════════════════════════════════════════════════════════════
// MANAGE CENTRES
// ════════════════════════════════════════════════════════════════

class ManageCentresScreen extends StatefulWidget {
  const ManageCentresScreen({super.key});
  @override
  State<ManageCentresScreen> createState() => _ManageCentresScreenState();
}

class _ManageCentresScreenState extends State<ManageCentresScreen> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCentres();
  }

  // Centres are stored in the backend (shared with Add Student). Load them so
  // this screen and the student forms always show the same dynamic list.
  Future<void> _loadCentres() async {
    try {
      final res = await apiClient.get('/students/centers');
      final list = (res['data'] as List<dynamic>? ?? []);
      final centres = list.map<({String id, String name})>((c) {
        final m = c as Map<String, dynamic>;
        return (id: m['id'] as String, name: (m['name'] ?? '') as String);
      }).toList();
      // Backend is the source of truth even when empty (clean DB = no centres).
      if (mounted) {
        setState(() { demoCentres..clear()..addAll(centres); });
      }
    } catch (_) {/* keep existing list if backend unreachable */}
    if (mounted && _loading) setState(() => _loading = false);
  }

  Future<void> _openSheet({({String id, String name})? editing}) async {
    final saved = await showAppSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _CentreEditor(editing: editing, onSaved: _loadCentres),
    );
    if (saved == null || !mounted) return;
    AppToast.success(context, editing == null ? 'Centre added' : 'Changes saved', detail: '“$saved”');
  }

  void _delete(({String id, String name}) c) {
    AppConfirm.show(
      context,
      title: 'Delete centre?',
      message: 'Remove “${c.name}”? Students assigned here will be unaffected.',
      confirmLabel: 'Delete Centre',
      onConfirm: () async {
        try {
          await apiClient.delete('/students/centers/${c.id}');
          await _loadCentres();
        } catch (_) {
          if (mounted) setState(() => demoCentres.remove(c));
        }
      },
    ).then((ok) {
      if (ok && mounted) AppToast.success(context, 'Centre deleted');
    });
  }

  @override
  Widget build(BuildContext context) {
    final Widget content;
    if (_loading && demoCentres.isEmpty) {
      content = const SkeletonList(rows: 3, rowHeight: 64);
    } else if (demoCentres.isEmpty) {
      content = EmptyState(
        icon: Icons.location_city_outlined,
        title: 'No centres yet',
        message: 'Add the centres your students attend — they appear in Add Student.',
        actionLabel: 'Add Centre',
        onAction: () => _openSheet(),
      );
    } else {
      content = Column(children: [
        for (var i = 0; i < demoCentres.length; i++)
          _HoverRow(
            last: i == demoCentres.length - 1,
            child: Row(children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(color: _brand600.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(9)),
                child: const Icon(Icons.location_city_outlined, color: _brand600, size: 17)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Text(demoCentres[i].name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('ID: ${demoCentres[i].id}', maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: context.textHint, fontWeight: FontWeight.w500)),
              ])),
              IconButton(
                tooltip: 'Edit ${demoCentres[i].name}',
                icon: Icon(Icons.edit_outlined, size: 18, color: context.textSub),
                onPressed: () => _openSheet(editing: demoCentres[i])),
              IconButton(
                tooltip: 'Delete ${demoCentres[i].name}',
                icon: const Icon(Icons.delete_outline, size: 18, color: _coral500),
                onPressed: () => _delete(demoCentres[i])),
            ]),
          ),
      ]);
    }
    return Scaffold(
      body: Column(children: [
        _buildHeader(context, 'Manage Centres',
          sub: _loading && demoCentres.isEmpty ? 'Loading…' : '${demoCentres.length} centre${demoCentres.length == 1 ? '' : 's'}',
          action: AppButton(label: 'Add Centre', icon: Icons.add, onPressed: () => _openSheet())),
        Expanded(child: RefreshIndicator(
          onRefresh: _loadCentres,
          color: _brand600,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 880),
                child: Container(
                  decoration: BoxDecoration(
                    color: context.cardBg, borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: AnimatedSwitcher(duration: const Duration(milliseconds: 180), child: KeyedSubtree(
                    key: ValueKey(_loading && demoCentres.isEmpty ? 'l' : demoCentres.isEmpty ? 'x' : 'd'),
                    child: content,
                  )),
                ),
              ),
            ),
          ),
        )),
      ]),
    );
  }
}

// Compact add/edit form for a centre. Keeps the typed name if the save fails
// and can't be submitted twice. Pops with the saved name.
class _CentreEditor extends StatefulWidget {
  const _CentreEditor({this.editing, required this.onSaved});
  final ({String id, String name})? editing;
  final Future<void> Function() onSaved;
  @override
  State<_CentreEditor> createState() => _CentreEditorState();
}

class _CentreEditorState extends State<_CentreEditor> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.editing?.name ?? '');
  bool _saving = false;

  bool get _editing => widget.editing != null;

  @override
  void dispose() { _name.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (_saving) return;
    if (!_form.currentState!.validate()) return;
    final n = _name.text.trim();
    setState(() => _saving = true);
    try {
      if (!_editing) {
        await apiClient.post('/students/centers', {'name': n});
      } else {
        await apiClient.patch('/students/centers/${widget.editing!.id}', {'name': n});
      }
      await widget.onSaved();
      if (mounted) Navigator.of(context).pop(n);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppToast.error(context, 'Could not save centre', detail: 'Log in as admin and try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(color: context.cardBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Form(
          key: _form,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SheetHandle(margin: EdgeInsets.only(bottom: 10)),
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_editing ? 'Edit centre' : 'Add centre', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(_editing ? 'Rename this centre.' : 'Centres appear in Add Student.',
                    style: TextStyle(fontSize: 12.5, color: context.textSub)),
              ])),
              IconButton(
                tooltip: 'Close',
                icon: Icon(Icons.close_rounded, size: 20, color: context.textSub),
                onPressed: _saving ? null : () => Navigator.of(context).pop(),
              ),
            ]),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text.rich(const TextSpan(children: [
                TextSpan(text: 'Name'),
                TextSpan(text: ' *', style: TextStyle(color: _coral500)),
              ]), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: context.textSub)),
            ),
            TextFormField(
              controller: _name,
              autofocus: true,
              enabled: !_saving,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _save(),
              validator: (v) => (v ?? '').trim().isEmpty ? 'Please enter a centre name.' : null,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              decoration: const InputDecoration(hintText: 'Centre name'),
            ),
            const SizedBox(height: 18),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              AppButton(label: 'Cancel', variant: AppButtonVariant.secondary,
                  onPressed: _saving ? null : () => Navigator.of(context).pop()),
              const SizedBox(width: 8),
              AppButton(
                label: _editing ? 'Save Changes' : 'Add Centre',
                busyLabel: _editing ? 'Saving…' : 'Adding…',
                loading: _saving,
                onPressed: _save,
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}
