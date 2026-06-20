import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/utils/app_launcher.dart';
import '../../../core/utils/native_file_saver.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/api_client.dart';

// ── brand palette ────────────────────────────────────────────────
const _brand600   = Color(0xFF0E8C76);
const _brand100   = Color(0xFFD6F3EC);
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
Widget _buildHeader(BuildContext ctx, String title, {String? sub}) =>
  Container(
    color: ctx.headerBg,
    padding: EdgeInsets.fromLTRB(8, MediaQuery.of(ctx).padding.top + 10, 18, 14),
    child: Row(children: [
      IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        onPressed: () => ctx.go('/settings'),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      ),
      const SizedBox(width: 6),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
        if (sub != null) Text(sub, style: TextStyle(fontSize: 12.5, color: ctx.textSub, fontWeight: FontWeight.w500)),
      ])),
    ]),
  );

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

void _snack(BuildContext ctx, String msg) {
  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
    content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w700)),
    backgroundColor: _brand600, behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    duration: const Duration(seconds: 2),
  ));
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
  final _name  = TextEditingController(text: 'Farhan Ansari');
  final _email = TextEditingController(text: 'kishorreddy992@gmail.com');
  final _phone = TextEditingController(text: '9876543210');
  final _role  = TextEditingController(text: 'Admin');
  final _org   = TextEditingController(text: 'Saksham Foundation');
  final _bio   = TextEditingController(text: 'Managing donations and child welfare programs since 2018.');
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _role, _org, _bio]) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(children: [
      _buildHeader(context, 'Edit Profile', sub: 'Update your personal information'),
      Expanded(child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Stack(children: [
            Container(width: 88, height: 88,
              decoration: const BoxDecoration(shape: BoxShape.circle,
                gradient: LinearGradient(colors: [Color(0xFF0B6E5D), Color(0xFF14A98C)])),
              child: const Center(child: Text('FA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 28)))),
            Positioned(bottom: 0, right: 0, child: Container(width: 28, height: 28,
              decoration: BoxDecoration(color: _brand600, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
              child: const Icon(Icons.camera_alt, size: 14, color: Colors.white))),
          ])),
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
          const SizedBox(height: 24),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: _saving ? null : () async {
              setState(() => _saving = true);
              await Future.delayed(const Duration(milliseconds: 600));
              if (mounted) { setState(() => _saving = false); _snack(context, 'Profile updated successfully'); }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _brand600, foregroundColor: Colors.white, elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(vertical: 15)),
            child: _saving
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
              : const Text('Save Changes', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          )),
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
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF0B6E5D), Color(0xFF14A98C)]), borderRadius: BorderRadius.circular(18)),
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
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          icon: const Icon(Icons.fingerprint, size: 48, color: _violet500),
          title: const Text('Enable Biometric Login?', style: TextStyle(fontWeight: FontWeight.w800), textAlign: TextAlign.center),
          content: const Text(
            'Use your fingerprint or face ID to log in quickly.\n\nTouch the fingerprint sensor on your device to confirm.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() => _bioEnabled = true);
                _snack(context, 'Biometric login enabled');
              },
              child: const Text('Enable', style: TextStyle(color: _brand600, fontWeight: FontWeight.w800))),
          ],
        ),
      );
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
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.6),
        decoration: BoxDecoration(color: ctx.cardBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 36, height: 4, margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(color: ctx.border, borderRadius: BorderRadius.circular(2)))),
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Revoke All Sessions?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: const Text('This will sign you out from all devices, including this one. You will need to log in again.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _snack(context, 'All sessions revoked — please log in again');
            },
            child: const Text('Revoke All', style: TextStyle(color: _coral500, fontWeight: FontWeight.w800))),
        ],
      ),
    );
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
              Expanded(child: Text('Devices logged into your Saksham account. Revoke any you don\'t recognise.',
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
          SizedBox(width: double.infinity, child: OutlinedButton.icon(
            onPressed: () { setState(() => _devices.removeWhere((d) => !(d['current'] as bool))); _snack(context, 'All other devices removed'); },
            icon: const Icon(Icons.logout_rounded, size: 18, color: _coral500),
            label: const Text('Sign Out All Other Devices', style: TextStyle(fontWeight: FontWeight.w700, color: _coral500)),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: _coral500.withValues(alpha: 0.4)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(vertical: 14)),
          )),
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
  final List<Map<String, dynamic>> _members = [
    {'name': 'Farhan Ansari', 'role': 'Admin',          'email': 'farhan@saksham.org',  'status': 'Active',   'color': _brand600,   'self': true},
    {'name': 'Priya Reddy',   'role': 'Field Officer',  'email': 'priya@saksham.org',   'status': 'Active',   'color': _violet500,  'self': false},
    {'name': 'Suresh Kumar',  'role': 'Donor Manager',  'email': 'suresh@saksham.org',  'status': 'Active',   'color': _sky500,     'self': false},
    {'name': 'Anita Sharma',  'role': 'Programme Lead', 'email': 'anita@saksham.org',   'status': 'Active',   'color': _amber600,   'self': false},
    {'name': 'Kiran Mehta',   'role': 'Data Entry',     'email': 'kiran@saksham.org',   'status': 'Inactive', 'color': _coral500,   'self': false},
  ];

  void _showInviteSheet() {
    final nameCtrl     = TextEditingController();
    final emailCtrl    = TextEditingController();
    final usernameCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    String userType    = 'Volunteer';
    Map<String, String?> errors = {};
    bool obscurePass = true;

    showModalBottomSheet(
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
            controller: ctrl, keyboardType: keyboard, obscureText: obscure,
            onChanged: (_) { if (errors[label] != null) setSheet(() => errors.remove(label)); },
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: hint, hintStyle: TextStyle(color: ctx.textHint),
              filled: true, fillColor: ctx.surface2, errorText: errors[label],
              suffixIcon: toggleObscure != null ? IconButton(icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18, color: ctx.textHint), onPressed: toggleObscure) : null,
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
            Center(child: Container(width: 36, height: 4, margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: ctx.border, borderRadius: BorderRadius.circular(2)))),
            const Text('Add Team Member', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            field(nameCtrl, 'Full Name', 'e.g. Priya Sharma'),
            field(emailCtrl, 'Email Address', 'member@saksham.org', keyboard: TextInputType.emailAddress),
            field(usernameCtrl, 'Username / User ID', 'e.g. priya.sharma'),
            field(passwordCtrl, 'Password', 'Min 6 characters', obscure: obscurePass,
              toggleObscure: () => setSheet(() => obscurePass = !obscurePass)),
            Text('User Type', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: ctx.textSub)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: ['Admin', 'Volunteer', 'Staff', 'Field Officer'].map((t) {
              final active = userType == t;
              return GestureDetector(
                onTap: () => setSheet(() => userType = t),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: active ? _brand600 : ctx.surface2,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(t, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: active ? Colors.white : ctx.textSub)),
                ),
              );
            }).toList()),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: () {
                final name     = nameCtrl.text.trim();
                final email    = emailCtrl.text.trim();
                final username = usernameCtrl.text.trim();
                final password = passwordCtrl.text;
                final newErrors = <String, String?>{};
                if (name.isEmpty)     newErrors['Full Name']      = 'Name is required';
                if (email.isEmpty)    newErrors['Email Address']  = 'Email is required';
                else if (!email.contains('@')) newErrors['Email Address'] = 'Enter a valid email';
                if (username.isEmpty) newErrors['Username / User ID'] = 'Username is required';
                if (password.isEmpty) newErrors['Password']       = 'Password is required';
                else if (password.length < 6) newErrors['Password'] = 'Minimum 6 characters';
                if (newErrors.isNotEmpty) { setSheet(() => errors = newErrors); return; }
                setState(() => _members.add({
                  'name': name, 'role': userType, 'email': email,
                  'status': 'Invited', 'color': _sky500, 'self': false,
                }));
                Navigator.pop(ctx);
                _snack(context, '$name added as $userType');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _brand600, foregroundColor: Colors.white, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 15)),
              child: const Text('Add Member', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            )),
          ])),
        );
      }),
    );
  }

  void _confirmRemove(int idx) {
    final name = _members[idx]['name'] as String;
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Remove Member', style: TextStyle(fontWeight: FontWeight.w800)),
      content: Text('Remove $name from the team? They will lose access to the app.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        TextButton(
          onPressed: () { Navigator.pop(ctx); setState(() => _members.removeAt(idx)); _snack(context, '$name removed from team'); },
          child: const Text('Remove', style: TextStyle(color: _coral500, fontWeight: FontWeight.w800))),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(children: [
      _buildHeader(context, 'Team Members', sub: '${_members.length} members'),
      Expanded(child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 100),
        child: _buildCard(context, child: Column(children: _members.asMap().entries.map((e) {
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
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: () => _confirmRemove(i),
                  child: Container(padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: _coral100, borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.person_remove_outlined, size: 16, color: _coral500))),
              ],
            ]),
          );
        }).toList())),
      )),
    ]),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _showInviteSheet,
      backgroundColor: _brand600, foregroundColor: Colors.white,
      icon: const Icon(Icons.person_add_outlined),
      label: const Text('Invite Member', style: TextStyle(fontWeight: FontWeight.w700)),
    ),
  );
}

// ════════════════════════════════════════════════════════════════
// 5. DONATION TYPES
// ════════════════════════════════════════════════════════════════
class DonationTypesScreen extends StatefulWidget {
  const DonationTypesScreen({super.key});
  @override
  State<DonationTypesScreen> createState() => _DonationTypesState();
}

class _DonationTypesState extends State<DonationTypesScreen> {
  final List<Map<String, dynamic>> _types = [
    {'name': 'Education',         'desc': 'School fees, books, uniforms',    'icon': Icons.school_outlined,            'color': _violet500, 'active': true},
    {'name': 'Child Sponsorship', 'desc': 'Monthly child welfare support',   'icon': Icons.favorite_outline,           'color': _brand600,  'active': true},
    {'name': 'Medical',           'desc': 'Health, medicines, surgeries',    'icon': Icons.medical_services_outlined,  'color': _coral500,  'active': true},
    {'name': 'General Fund',      'desc': 'Unrestricted operational fund',   'icon': Icons.account_balance_outlined,   'color': _brand600,  'active': true},
    {'name': 'Food & Nutrition',  'desc': 'Ration kits, mid-day meals',      'icon': Icons.restaurant_outlined,        'color': _amber600,  'active': true},
    {'name': 'Infrastructure',    'desc': 'Building & facility improvement', 'icon': Icons.business_outlined,          'color': _sky500,    'active': false},
    {'name': 'Zakat',             'desc': 'Islamic charitable giving',       'icon': Icons.volunteer_activism_outlined,'color': _amber600,  'active': true},
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(children: [
      _buildHeader(context, 'Donation Types', sub: '${_types.length} categories'),
      Expanded(child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 100),
        child: _buildCard(context, child: Column(children: _types.asMap().entries.map((e) {
          final i = e.key; final t = e.value;
          final c = t['color'] as Color;
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: i < _types.length - 1 ? BoxDecoration(border: Border(bottom: BorderSide(color: context.border))) : null,
            child: Row(children: [
              Container(width: 40, height: 40,
                decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(11)),
                child: Icon(t['icon'] as IconData, color: c, size: 20)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(t['name'] as String, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                Text(t['desc'] as String, style: TextStyle(fontSize: 12, color: context.textHint, fontWeight: FontWeight.w500)),
              ])),
              Switch(
                value: t['active'] as bool,
                onChanged: (v) => setState(() => _types[i]['active'] = v),
                activeColor: _brand600),
            ]),
          );
        }).toList())),
      )),
    ]),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _showAddTypeDialog(context),
      backgroundColor: _brand600, foregroundColor: Colors.white,
      icon: const Icon(Icons.add),
      label: const Text('Add Type', style: TextStyle(fontWeight: FontWeight.w700)),
    ),
  );

  void _showAddTypeDialog(BuildContext context) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    String? nameError;

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            decoration: BoxDecoration(color: ctx.cardBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: ctx.border, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              const Text('Add Donation Type', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              Row(children: [
                Text('Type Name', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: ctx.textSub)),
                const Text(' *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _coral500)),
              ]),
              const SizedBox(height: 6),
              TextField(
                controller: nameCtrl,
                onChanged: (_) { if (nameError != null) setSheet(() => nameError = null); },
                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'e.g. Healthcare, Scholarship…', hintStyle: TextStyle(color: ctx.textHint),
                  filled: true, fillColor: ctx.surface2,
                  errorText: nameError,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _brand600, width: 1.5)),
                  errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _coral500, width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12))),
              const SizedBox(height: 12),
              Text('Description (optional)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: ctx.textSub)),
              const SizedBox(height: 6),
              TextField(
                controller: descCtrl,
                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'Short description of this donation type', hintStyle: TextStyle(color: ctx.textHint),
                  filled: true, fillColor: ctx.surface2,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _brand600, width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12))),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, child: ElevatedButton(
                onPressed: () {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) {
                    setSheet(() => nameError = 'Type name is required');
                    return;
                  }
                  setState(() => _types.add({
                    'name': name,
                    'desc': descCtrl.text.trim().isEmpty ? 'Custom donation type' : descCtrl.text.trim(),
                    'icon': Icons.volunteer_activism_outlined,
                    'color': _brand600,
                    'active': true,
                  }));
                  Navigator.pop(ctx);
                  _snack(context, '"$name" added successfully');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brand600, foregroundColor: Colors.white, elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 15)),
                child: const Text('Save Donation Type', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              )),
            ]),
          ),
        );
      }),
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
  bool _students  = false;
  bool _reports   = false;
  bool _exporting = false;

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
            return Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: GestureDetector(
              onTap: () => setState(() => _format = f),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(color: active ? _brand600 : context.surface2, borderRadius: BorderRadius.circular(10)),
                child: Text(f, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: active ? Colors.white : context.textSub))),
            )));
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
            _toggle(context, 'Students',  _students,  (v) => setState(() => _students = v),  Icons.school_outlined,                  _violet500),
            _toggle(context, 'Reports',   _reports,   (v) => setState(() => _reports = v),   Icons.bar_chart_rounded,                _sky500, last: true),
          ])),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(
            onPressed: _exporting ? null : () async {
              setState(() => _exporting = true);
              await Future.delayed(const Duration(milliseconds: 800));
              if (!mounted) return;
              // Build a sample CSV/text export
              final csv = StringBuffer();
              csv.writeln('Saksham Foundation — Data Export');
              csv.writeln('Format: $_format  |  Range: $_range');
              csv.writeln('Generated: ${DateTime.now().toString().substring(0, 16)}');
              csv.writeln('');
              if (_donors) {
                csv.writeln('--- DONORS ---');
                csv.writeln('ID,Name,Category,Mobile,Email,City,Status');
                csv.writeln('SF-D-0001,Rajesh Khanna,Major Donor,9876543210,rajesh@example.com,Mumbai,Active');
                csv.writeln('SF-D-0002,Priya Sharma,Child Sponsor,9812345678,priya@example.com,Pune,Active');
                csv.writeln('SF-D-0003,Arjun Mehta,Corporate,9800012345,arjun@example.com,Bengaluru,Active');
                csv.writeln('');
              }
              if (_donations) {
                csv.writeln('--- DONATIONS ---');
                csv.writeln('ID,Donor,Amount,Type,Method,Date,Status');
                csv.writeln('SF/26-27/0423,Priya Sharma,18000,Child Sponsorship,UPI,04 Jun 2026,Received');
                csv.writeln('SF/26-27/0422,Sanjay Gupta,75000,Education,Bank Transfer,04 Jun 2026,Received');
                csv.writeln('SF/26-27/0421,Vikram Singh,30000,Medical,UPI,03 Jun 2026,Received');
                csv.writeln('');
              }
              if (_students) {
                csv.writeln('--- STUDENTS ---');
                csv.writeln('ID,Name,Centre,Gender,Class,Status');
                csv.writeln('SKT-C-0001,Imran Qureshi,Sulibele,Male,Class 9,Active');
                csv.writeln('SKT-C-0002,Diya Reddy,Medahalli,Female,Class 8,Active');
                csv.writeln('');
              }
              final filename = 'Saksham_Export_${DateTime.now().millisecondsSinceEpoch}.${_format.toLowerCase()}';
              final ok = await NativeFileSaver.saveCsv(filename, csv.toString());
              setState(() => _exporting = false);
              _snack(context, ok ? '✓ Downloaded to Downloads/$filename' : 'Failed to save file');
            },
            icon: _exporting
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.download_outlined, size: 20),
            label: Text(_exporting ? 'Downloading...' : 'Download $_format', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _brand600, foregroundColor: Colors.white, elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(vertical: 14)),
          )),
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
              onTap: () => _snack(context, 'Select a backup to restore')),
            _buildRow(context, 'Clear Local Cache', value: 'Free up device storage', icon: Icons.delete_sweep_outlined, fg: _coral500, last: true,
              onTap: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();
                if (mounted) _snack(context, 'Cache cleared — app data reset');
              }),
          ])),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity, child: ElevatedButton.icon(
            onPressed: _syncing ? null : () async {
              setState(() => _syncing = true);
              await Future.delayed(const Duration(seconds: 1));
              if (mounted) { setState(() => _syncing = false); _snack(context, 'Sync complete — all data up to date'); }
            },
            icon: _syncing
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.sync, size: 20),
            label: Text(_syncing ? 'Syncing...' : 'Sync Now', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _brand600, foregroundColor: Colors.white, elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(vertical: 14)),
          )),
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
      'Saksham Foundation, No. 42, NGO Campus, Bengaluru – 560067, Karnataka.\nEmail: privacy@sakshamfoundation.org  ·  Phone: +91 80 2345 6789'),
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
      'By using the Saksham Foundation Management App, you agree to be bound by these Terms of Service. If you do not agree, please discontinue use immediately.'),
    _LegalSection('2. Authorised Use',
      'This application is intended solely for use by authorised staff, volunteers, and administrators of Saksham Foundation. Sharing credentials with unauthorised persons is prohibited.'),
    _LegalSection('3. Donor & Child Data',
      'All data entered is the property of Saksham Foundation. Users are responsible for accuracy and must not misuse donor or child beneficiary information.'),
    _LegalSection('4. Financial Records',
      'All financial transactions must be genuine. Fabricating donations, receipts, or expenditure reports is a serious violation and may result in legal action.'),
    _LegalSection('5. Intellectual Property',
      'The app design, code, logos, and content are the intellectual property of Saksham Foundation and its technology partners. Reproduction without permission is prohibited.'),
    _LegalSection('6. Limitation of Liability',
      'Saksham Foundation is not liable for any loss of data, system downtime, or errors resulting from user actions. Users are responsible for maintaining device security.'),
    _LegalSection('7. Termination',
      'Saksham Foundation reserves the right to suspend or revoke app access at any time for violation of these terms or termination of employment/volunteering relationship.'),
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
      'Saksham Foundation is a registered charitable organisation headquartered in Bengaluru, Karnataka. Founded in 2008, we work across education, child welfare, healthcare, and community development to uplift underserved communities across South India.'),
    _LegalSection('Our Mission',
      'To empower every child and family we serve with access to quality education, healthcare, and livelihood support — building a more equitable society, one community at a time.'),
    _LegalSection('Our Impact',
      '15,000+ children supported  ·  ₹8.2 Cr+ raised  ·  48 partner NGOs  ·  12 districts reached\n\nEvery rupee donated is tracked, accounted for, and directed toward maximum beneficiary impact.'),
    _LegalSection('Certifications & Registrations',
      '✦ 80G & 12A Tax Exemption\n✦ FCRA Licensed (Ministry of Home Affairs)\n✦ CSR-1 Registered (MCA)\n✦ GiveIndia Verified NGO\n✦ ISO 9001:2015 Quality Management'),
    _LegalSection('This App',
      'The Saksham Admin App is a purpose-built tool for staff and volunteers to manage donors, track donations, monitor student progress, and generate impact reports — all from a single mobile platform.'),
    _LegalSection('Contact Us',
      'Saksham Foundation\nNo. 42, NGO Campus, HSR Layout\nBengaluru – 560067, Karnataka\n\nEmail: info@sakshamfoundation.org\nPhone: +91 80 2345 6789\nWebsite: www.sakshamfoundation.org'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apiResult = ref.watch(legalContentProvider('about-us'));
    return _LegalScreen(
      title: 'About Us', sub: 'Saksham Foundation · Est. 2008',
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
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF0B6E5D), Color(0xFF14A98C)]), borderRadius: BorderRadius.circular(18)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.support_agent_outlined, color: Colors.white, size: 36),
              const SizedBox(height: 10),
              const Text('Saksham Support', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
              const Text('Mon–Fri · 9 AM – 6 PM IST', style: TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w500)),
              const SizedBox(height: 14),
              Row(children: [
                _cBtn(Icons.email_outlined, 'Email',
                  onTap: () => launchEmail('support@sakshamfoundation.org', context, subject: 'Support Request – Saksham App')),
                const SizedBox(width: 10),
                _cBtn(Icons.phone_outlined, 'Call',
                  onTap: () => launchPhone('+918023456789', context)),
                const SizedBox(width: 10),
                _cBtn(Icons.chat_outlined, 'WhatsApp',
                  onTap: () => launchWhatsApp('918023456789', context, message: 'Hi, I need support for the Saksham Foundation app.')),
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
            _buildRow(context, 'Flutter Version', value: '3.44.1',              icon: Icons.flutter_dash,       fg: _sky500,         trailing: const SizedBox.shrink()),
            _buildRow(context, 'Report a Bug',    value: 'Send us a crash/UX report', icon: Icons.bug_report_outlined, fg: _coral500, last: true,
              onTap: () => launchEmail('bugs@sakshamfoundation.org', context,
                subject: 'Bug Report – Saksham App v2.4.0',
                body: 'Describe the bug:\n\nSteps to reproduce:\n\nDevice: OPPO\nApp Version: v2.4.0')),
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
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.72),
        decoration: BoxDecoration(color: ctx.cardBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 36, height: 4, margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(color: ctx.border, borderRadius: BorderRadius.circular(2)))),
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
        ]),
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
        child: Column(children: [
          if (hasLiveBody) Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(color: _brand100, borderRadius: BorderRadius.circular(8)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.wifi_outlined, size: 14, color: _brand600), SizedBox(width: 6),
              Text('Content synced live from Admin Panel', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _brand600)),
            ])),
          Container(
            padding: const EdgeInsets.all(16), margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF0B6E5D), Color(0xFF14A98C)]), borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              Icon(icon, color: Colors.white, size: 28), const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
                Text('Saksham Foundation · $sub', style: const TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w500)),
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
// Server URL Screen — update backend URL without rebuilding APK
// ════════════════════════════════════════════════════════════════
class ServerUrlScreen extends StatefulWidget {
  const ServerUrlScreen({super.key});
  @override
  State<ServerUrlScreen> createState() => _ServerUrlScreenState();
}

class _ServerUrlScreenState extends State<ServerUrlScreen> {
  final _ctrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String _activeUrl = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(ApiClient.serverUrlKey) ?? '';
    setState(() {
      _activeUrl = saved.isNotEmpty ? saved : ApiClient.defaultBaseUrl;
      _ctrl.text = _activeUrl;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final url = _ctrl.text.trim();
    if (url.isEmpty) return;
    setState(() => _saving = true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(ApiClient.serverUrlKey, url);
    setState(() { _saving = false; _activeUrl = url; });
    if (mounted) _snack(context, '✓ Server URL saved — no rebuild needed!');
  }

  Future<void> _reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(ApiClient.serverUrlKey);
    setState(() {
      _activeUrl = ApiClient.defaultBaseUrl;
      _ctrl.text = _activeUrl;
    });
    if (mounted) _snack(context, 'Reset to built-in default URL');
  }

  Future<void> _testConnection() async {
    final url = _ctrl.text.trim();
    if (url.isEmpty) return;
    setState(() => _saving = true);
    try {
      final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 8)));
      await dio.get('$url/auth/health');
      if (mounted) _snack(context, '✓ Connection successful!');
    } catch (e) {
      if (mounted) _snack(context, 'Connection failed: ${e.toString().substring(0, 60)}');
    }
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(children: [
      _buildHeader(context, 'Server URL', sub: 'Change backend without rebuilding'),
      if (_loading)
        const Expanded(child: Center(child: CircularProgressIndicator()))
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
                border: Border.all(color: _brand600.withValues(alpha: 0.3)),
              ),
              child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Icon(Icons.info_outline, color: _brand600, size: 18),
                SizedBox(width: 10),
                Expanded(child: Text(
                  'When Serveo restarts, update the URL here and tap Save — no APK rebuild needed.',
                  style: TextStyle(fontSize: 12.5, color: _brand600, fontWeight: FontWeight.w600, height: 1.4),
                )),
              ]),
            ),

            _buildSectionLabel(context, 'Backend URL (include /api/v1)'),
            _buildCard(context, child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                TextField(
                  controller: _ctrl,
                  keyboardType: TextInputType.url,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  maxLines: 3,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.link, size: 18, color: _brand600),
                    hintText: 'https://xxxxxxxxxxxxxxxx.serveousercontent.com/api/v1',
                    hintStyle: TextStyle(fontSize: 12, color: context.textHint),
                    filled: true, fillColor: context.surface2,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _brand600, width: 1.5)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 10),
                Text('Example: https://abc123.serveousercontent.com/api/v1',
                  style: TextStyle(fontSize: 11.5, color: context.textHint, fontWeight: FontWeight.w500)),
              ]),
            )),

            const SizedBox(height: 20),

            Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: _saving ? null : _testConnection,
                icon: const Icon(Icons.wifi_find, size: 16),
                label: const Text('Test'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _brand600,
                  side: const BorderSide(color: _brand600),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              )),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.save_outlined, size: 16),
                label: const Text('Save URL'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brand600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              )),
            ]),

            const SizedBox(height: 24),

            _buildSectionLabel(context, 'Active URL'),
            _buildCard(context, child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_activeUrl,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, fontFamily: 'monospace')),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: _reset,
                  child: const Row(children: [
                    Icon(Icons.restore, size: 15, color: _coral500),
                    SizedBox(width: 6),
                    Text('Reset to built-in default', style: TextStyle(fontSize: 12.5, color: _coral500, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ]),
            )),
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
  final List<Map<String, dynamic>> _roles = [
    {
      'name': 'Admin',
      'desc': 'Full access to all features and settings',
      'members': 1,
      'isSystem': true,
      'perms': <String, dynamic>{
        'donors':    <String, bool>{'view': true,  'add': true,  'edit': true},
        'donations': <String, bool>{'view': true,  'add': true},
        'children':  <String, bool>{'view': true,  'add': true,  'edit': true},
        'reports':   <String, bool>{'view': true,  'export': true},
        'settings':  <String, bool>{'access': true},
      },
    },
    {
      'name': 'Field Officer',
      'desc': 'Manages children and views reports',
      'members': 2,
      'isSystem': false,
      'perms': <String, dynamic>{
        'donors':    <String, bool>{'view': true,  'add': false, 'edit': false},
        'donations': <String, bool>{'view': true,  'add': false},
        'children':  <String, bool>{'view': true,  'add': true,  'edit': true},
        'reports':   <String, bool>{'view': true,  'export': false},
        'settings':  <String, bool>{'access': false},
      },
    },
    {
      'name': 'Donor Manager',
      'desc': 'Handles donors and donations only',
      'members': 1,
      'isSystem': false,
      'perms': <String, dynamic>{
        'donors':    <String, bool>{'view': true,  'add': true,  'edit': true},
        'donations': <String, bool>{'view': true,  'add': true},
        'children':  <String, bool>{'view': false, 'add': false, 'edit': false},
        'reports':   <String, bool>{'view': false, 'export': false},
        'settings':  <String, bool>{'access': false},
      },
    },
    {
      'name': 'Data Entry',
      'desc': 'Can add records; cannot edit or delete',
      'members': 1,
      'isSystem': false,
      'perms': <String, dynamic>{
        'donors':    <String, bool>{'view': true,  'add': true,  'edit': false},
        'donations': <String, bool>{'view': true,  'add': true},
        'children':  <String, bool>{'view': true,  'add': true,  'edit': false},
        'reports':   <String, bool>{'view': false, 'export': false},
        'settings':  <String, bool>{'access': false},
      },
    },
  ];

  List<String> _summary(Map<String, dynamic> perms) {
    bool p(String mod, String key) {
      final m = perms[mod];
      if (m is Map) return (m[key] as bool?) ?? false;
      return false;
    }
    final parts = <String>[];
    if (p('donors', 'edit'))          parts.add('Donors (full)');
    else if (p('donors', 'add'))      parts.add('Donors (add)');
    else if (p('donors', 'view'))     parts.add('Donors (view)');
    if (p('donations', 'add'))        parts.add('Donations (add)');
    else if (p('donations', 'view'))  parts.add('Donations (view)');
    if (p('children', 'edit'))        parts.add('Children (full)');
    else if (p('children', 'add'))    parts.add('Children (add)');
    else if (p('children', 'view'))   parts.add('Children (view)');
    if (p('reports', 'export'))       parts.add('Reports + Export');
    else if (p('reports', 'view'))    parts.add('Reports (view)');
    if (parts.isEmpty)                parts.add('No module access');
    return parts;
  }

  void _showRoleSheet(BuildContext context, {Map<String, dynamic>? role}) {
    final isNew    = role == null;
    final nameCtrl = TextEditingController(text: isNew ? '' : role['name'] as String);
    final descCtrl = TextEditingController(text: isNew ? '' : role['desc'] as String);

    Map<String, bool> initPerm(String mod, List<String> keys) {
      final src = (role?['perms'] as Map?)?[mod];
      return {for (final k in keys) k: (src is Map ? (src[k] as bool?) : null) ?? false};
    }

    final perms = <String, Map<String, bool>>{
      'donors':    initPerm('donors',    ['view', 'add', 'edit']),
      'donations': initPerm('donations', ['view', 'add']),
      'children':  initPerm('children',  ['view', 'add', 'edit']),
      'reports':   initPerm('reports',   ['view', 'export']),
      'settings':  initPerm('settings',  ['access']),
    };

    showModalBottomSheet(
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
            Padding(padding: const EdgeInsets.fromLTRB(20, 14, 8, 0), child: Row(children: [
              Center(child: Container(width: 36, height: 4,
                decoration: BoxDecoration(color: context.border, borderRadius: BorderRadius.circular(2)))),
              const Spacer(),
              Text(isNew ? 'Create Role' : 'Edit Role',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const Spacer(),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
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
                  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
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
                  labels: const {'view': 'View donors', 'add': 'Add donors', 'edit': 'Edit & delete'},
                  onToggle: (k, v) => setSt(() {
                    perms['donors']![k] = v;
                    if (v && k != 'view') perms['donors']!['view'] = true;
                  }),
                ),
                const SizedBox(height: 10),
                _PermModule(
                  icon: Icons.account_balance_wallet_outlined, color: _amber600, title: 'Donations',
                  perms: perms['donations']!,
                  labels: const {'view': 'View donations', 'add': 'Record donations'},
                  onToggle: (k, v) => setSt(() {
                    perms['donations']![k] = v;
                    if (v && k == 'add') perms['donations']!['view'] = true;
                  }),
                ),
                const SizedBox(height: 10),
                _PermModule(
                  icon: Icons.school_outlined, color: _violet500, title: 'Children',
                  perms: perms['children']!,
                  labels: const {'view': 'View children', 'add': 'Enrol children', 'edit': 'Edit & delete'},
                  onToggle: (k, v) => setSt(() {
                    perms['children']![k] = v;
                    if (v && k != 'view') perms['children']!['view'] = true;
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
                  icon: Icons.settings_outlined, color: const Color(0xFF64748B), title: 'Settings',
                  perms: perms['settings']!,
                  labels: const {'access': 'Access settings page'},
                  onToggle: (k, v) => setSt(() => perms['settings']![k] = v),
                ),
              ]),
            )),
            Padding(padding: const EdgeInsets.fromLTRB(20, 8, 20, 28), child:
              SizedBox(width: double.infinity, child: ElevatedButton(
                onPressed: () {
                  final name = nameCtrl.text.trim();
                  if (name.isEmpty) { _snack(ctx, 'Role name is required'); return; }
                  if (isNew) {
                    setState(() => _roles.add({
                      'name': name, 'desc': descCtrl.text.trim(),
                      'members': 0, 'isSystem': false, 'perms': perms,
                    }));
                    _snack(context, '"$name" role created');
                  } else {
                    final idx = _roles.indexOf(role);
                    if (idx >= 0) setState(() {
                      _roles[idx]['name'] = name;
                      _roles[idx]['desc'] = descCtrl.text.trim();
                      _roles[idx]['perms'] = perms;
                    });
                    _snack(context, '"$name" role updated');
                  }
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brand600, foregroundColor: Colors.white, elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 15)),
                child: Text(isNew ? 'Create Role' : 'Save Changes',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              )),
            ),
          ]),
        );
      }),
    );
  }

  void _confirmDelete(BuildContext context, int idx) {
    final roleName = _roles[idx]['name'] as String;
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: context.cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(color: context.border, borderRadius: BorderRadius.circular(2))),
          Container(width: 56, height: 56,
            decoration: BoxDecoration(color: _coral100, borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.delete_outline, color: _coral500, size: 26)),
          const SizedBox(height: 14),
          Text('Delete "$roleName" Role?',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('Members with this role will lose access. This cannot be undone.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: context.textSub, fontWeight: FontWeight.w500)),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => Navigator.pop(ctx),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: context.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 13)),
              child: Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700, color: context.textSub)),
            )),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(
              onPressed: () {
                setState(() => _roles.removeAt(idx));
                Navigator.pop(ctx);
                _snack(context, '"$roleName" role deleted');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _coral500, foregroundColor: Colors.white, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 13)),
              child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w800)),
            )),
          ]),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(children: [
      _buildHeader(context, 'Manage Roles', sub: 'Control what each staff member can access'),
      Expanded(child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 100),
        physics: const BouncingScrollPhysics(),
        itemCount: _roles.length,
        itemBuilder: (ctx, i) {
          final r        = _roles[i];
          final isSystem = r['isSystem'] as bool;
          final members  = r['members'] as int;
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
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _showRoleSheet(context),
      backgroundColor: _brand600, foregroundColor: Colors.white,
      icon: const Icon(Icons.add),
      label: const Text('New Role', style: TextStyle(fontWeight: FontWeight.w700)),
    ),
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

class AdminPanelScreen extends StatelessWidget {
  const AdminPanelScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Welcome banner ──────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF094F41), Color(0xFF0E8C76), Color(0xFF14A98C)],
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
                  const Text('Farhan Ansari',
                      style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900,
                          letterSpacing: -0.6, height: 1.1)),
                  const SizedBox(height: 10),
                  Wrap(spacing: 8, runSpacing: 6, children: [
                    _Chip(label: '🛡️  Administrator'),
                    _Chip(label: 'Saksham Foundation'),
                  ]),
                ])),
                const SizedBox(width: 14),
                Container(
                  width: 58, height: 58,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2)),
                  child: const Center(child: Text('FA',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20)))),
              ]),
            ]),
          ),

          // ── KPI stat cards ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 0),
            child: Row(children: const [
              _Kpi(value: '5',  label: 'Total Staff',   icon: Icons.badge_outlined,             color: _brand600,  bg: _brand100),
              SizedBox(width: 10),
              _Kpi(value: '4',  label: 'Active Roles',  icon: Icons.manage_accounts_outlined,   color: _violet500, bg: Color(0xFFEDE9FE)),
              SizedBox(width: 10),
              _Kpi(value: '3',  label: 'Online Today',  icon: Icons.sensors_rounded,            color: _sky500,    bg: _sky100),
              SizedBox(width: 10),
              _Kpi(value: '12', label: 'Total Donors',  icon: Icons.people_outlined,            color: _amber600,  bg: Color(0xFFFFF1D6)),
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
                  {'icon': Icons.people_outlined,          'color': _brand600,  'bg': _brand100,            'label': 'Team Members',   'route': '/settings/team-members'},
                  {'icon': Icons.manage_accounts_outlined, 'color': _violet500, 'bg': const Color(0xFFEDE9FE), 'label': 'Manage Roles', 'route': '/settings/manage-roles'},
                  {'icon': Icons.category_outlined,        'color': _amber600,  'bg': const Color(0xFFFFF1D6), 'label': 'Donation Types','route': '/settings/donation-types'},
                  {'icon': Icons.download_outlined,        'color': _sky500,    'bg': _sky100,              'label': 'Export Data',    'route': '/settings/export-data'},
                  {'icon': Icons.cloud_sync_outlined,      'color': _sky500,    'bg': _sky100,              'label': 'Backup & Sync',  'route': '/settings/backup-sync'},
                  {'icon': Icons.router_outlined,          'color': const Color(0xFF64748B), 'bg': const Color(0xFFF1F5F9), 'label': 'Server URL', 'route': '/settings/server-url'},
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
                _ModRow(icon: Icons.people_outlined,                  color: _brand600,  bg: _brand100,            label: 'Donors',        value: '12 total',        route: '/donors'),
                _ModRow(icon: Icons.account_balance_wallet_outlined,  color: _amber600,  bg: const Color(0xFFFFF1D6), label: 'Donations',  value: '₹4.15L this month', route: '/donations'),
                _ModRow(icon: Icons.school_outlined,                  color: _violet500, bg: const Color(0xFFEDE9FE), label: 'Students',   value: '10 enrolled',     route: '/students'),
                _ModRow(icon: Icons.bar_chart_rounded,                color: _sky500,    bg: _sky100,              label: 'Reports',       value: 'Analytics',       route: '/reports'),
                _ModRow(icon: Icons.link_rounded,                     color: _brand600,  bg: _brand100,            label: 'Payment Links', value: '3 active',        route: '/payment-links'),
                _ModRow(icon: Icons.business_outlined,                color: _brand600,  bg: _brand100,            label: 'Offices',       value: '4 locations',     route: '/offices', last: true),
              ])),
            ]),
          ),

          // ── Recent Activity ─────────────────────────────────────────
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _Label(text: 'Recent Activity'),
              const SizedBox(height: 10),
              _buildCard(context, child: const Column(children: [
                _ActRow(dot: _brand600,  text: 'New donor "Rekha Gupta" added',           time: '1 hr ago'),
                _ActRow(dot: _violet500, text: 'Role "Data Entry" created by Farhan',     time: '3 hrs ago'),
                _ActRow(dot: _amber600,  text: 'Donation Type "Medical Aid" added',        time: 'Yesterday'),
                _ActRow(dot: _sky500,    text: 'Server backup completed successfully',     time: '2 days ago'),
                _ActRow(dot: _brand600,  text: '10 students enrolled this month',          time: '3 days ago', last: true),
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
                  icon: Icons.history_outlined, fg: const Color(0xFF64748B), value: 'Coming soon',
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
