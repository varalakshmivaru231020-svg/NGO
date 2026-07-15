import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'add_donor_screen.dart' show AddDonorScreen;
import 'package:url_launcher/url_launcher.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/open_bytes.dart';
import '../../../core/utils/video_player.dart';
import '../../../core/auth/role_auth.dart';
import '../../settings/profile_store.dart';
import 'donors_screen.dart' show demoLocalDonors, mockDonorData, localDonorPhotos;

const _brand600 = Color(0xFFFF9933);
const _brand700 = Color(0xFFE07C1F);
const _brand100 = Color(0xFFFFE8CC);
const _amber600 = Color(0xFFE0921A);
const _coral500 = Color(0xFFF2685E);
const _violet500 = Color(0xFF7C6CF0);
const _sky500 = Color(0xFF2D9CDB);
const _onSurface1 = Color(0xFF15211E);
const _onSurface2 = Color(0xFF5A6B67);
const _onSurface3 = Color(0xFF93A29F);
const _border = Color(0xFFE5EBE9);
const _surface2 = Color(0xFFF4F7F6);

Color _avColor(String seed) {
  final p = [_brand600, const Color(0xFFF6A723), _violet500, _sky500, _coral500, const Color(0xFF14A98C)];
  int h = 0;
  for (int i = 0; i < seed.length; i++) h = ((h * 31) + seed.codeUnitAt(i)) & 0xFFFFFFFF;
  return p[h % p.length];
}

String _initials(String name) {
  final p = name.trim().split(RegExp(r'\s+'));
  return ((p[0].isNotEmpty ? p[0][0] : '') + (p.length > 1 && p[1].isNotEmpty ? p[1][0] : '')).toUpperCase();
}

String _fmtDate(String? iso) {
  if (iso == null || iso.isEmpty) return 'Not Available';
  try {
    final d = DateTime.parse(iso);
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day.toString().padLeft(2,'0')} ${m[d.month-1]} ${d.year}';
  } catch (_) { return iso; }
}

String _fmtAmount(dynamic v) {
  final n = v is int ? v : (v is double ? v.toInt() : int.tryParse(v?.toString() ?? '') ?? 0);
  if (n >= 10000000) return '₹${(n/10000000).toStringAsFixed(1)} Cr';
  if (n >= 100000)   return '₹${(n/100000).toStringAsFixed(1)} L';
  if (n >= 1000)     return '₹${(n/1000).toStringAsFixed(1)} K';
  return '₹$n';
}

// ══════════════════════════════════════════════════════════════════════
class DonorDetailScreen extends StatefulWidget {
  const DonorDetailScreen({super.key, required this.id});
  final String id;
  @override
  State<DonorDetailScreen> createState() => _DonorDetailScreenState();
}

class _DonorDetailScreenState extends State<DonorDetailScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  Map<String, dynamic>? _donor;
  List<Map<String, dynamic>> _donations = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
    _load();
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Map<String, dynamic>? _findMock() {
    for (final d in demoLocalDonors) {
      if (d['id'] == widget.id) return Map<String, dynamic>.from(d);
    }
    for (final d in mockDonorData) {
      if (d['id'] == widget.id) return Map<String, dynamic>.from(d);
    }
    return null;
  }

  Future<void> _load() async {
    try {
      final results = await Future.wait([
        apiClient.get('/donors/${widget.id}'),
        apiClient.get('/donations', params: {'donorId': widget.id, 'limit': '50', 'page': '1'}),
      ]);
      final dRaw = results[0]['data'];
      final donor = dRaw is Map ? Map<String, dynamic>.from(dRaw as Map) : <String, dynamic>{};
      final doRaw = results[1]['data'];
      final doList = doRaw is List ? doRaw : (doRaw is Map ? (doRaw['data'] as List? ?? []) : []);
      if (mounted) setState(() {
        _donor = donor.isNotEmpty ? donor : _findMock();
        _donations = doList.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loading = false;
      });
    } catch (_) {
      final mock = _findMock();
      if (mounted) setState(() {
        _donor = mock;
        _loading = false;
        _error = mock == null ? 'Donor not found' : null;
      });
    }
  }

  String get _name {
    final n = _donor?['name'] as String? ?? '';
    return n.trim().isNotEmpty ? n : 'Donor';
  }

  // Prefer a same-session, just-uploaded photo; otherwise decode the avatar
  // the backend actually persisted, so the photo survives a reload.
  Uint8List? get _photoBytes {
    final local = localDonorPhotos[widget.id];
    if (local != null) return local;
    final avatar = _donor?['avatar'] as String?;
    if (avatar == null || avatar.isEmpty) return null;
    try { return base64Decode(avatar); } catch (_) { return null; }
  }

  String get _mobile => _donor?['mobile'] as String? ?? '';
  String get _whatsappNum => (_donor?['whatsapp'] as String?)?.isNotEmpty == true ? _donor!['whatsapp'] as String : _mobile;
  String get _email => _donor?['email'] as String? ?? '';
  String get _donorId => _donor?['donorCode'] as String? ?? '—';
  int get _donationCount {
    final cnt = (_donor?['_count'] as Map<String, dynamic>?)?['donations'];
    return cnt as int? ?? _donations.length;
  }
  dynamic get _totalDonated => _donor?['totalDonated'] ?? _donor?['total_donated'] ?? 0;
  String get _categoryName {
    final cats = _donor?['categories'] as List<dynamic>? ?? [];
    if (cats.isEmpty) return '—';
    final cat = cats.first as Map<String, dynamic>?;
    return (cat?['category'] as Map<String, dynamic>?)?['name'] as String? ?? '—';
  }
  String get _lastGift {
    if (_donations.isNotEmpty) {
      final d = _donations.first;
      return _fmtDate(d['createdAt'] as String? ?? d['date'] as String?);
    }
    final ld = _donor?['lastDonationDate'] as String?;
    return ld != null ? _fmtDate(ld) : '—';
  }

  Future<void> _call() async {
    final digits = _mobile.replaceAll(RegExp(r'[^\d+]'), '');
    if (digits.isEmpty) return;
    final uri = Uri.parse('tel:$digits');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _openWhatsApp() async {
    final digits = _whatsappNum.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) return;
    final uri = Uri.parse('https://wa.me/$digits');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _sendEmail() async {
    if (_email.isEmpty) return;
    final uri = Uri.parse('mailto:$_email');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: _surface2,
        body: Center(child: CircularProgressIndicator(color: _brand600)),
      );
    }
    if (_error != null || _donor == null) {
      return Scaffold(
        backgroundColor: _surface2,
        body: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, color: _coral500, size: 44),
          const SizedBox(height: 12),
          const Text('Failed to load donor', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: _onSurface1)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () { setState(() { _loading = true; _error = null; }); _load(); },
            child: const Text('Retry', style: TextStyle(color: _brand600, fontWeight: FontWeight.w700)),
          ),
        ])),
      );
    }

    final color = _avColor(_name);
    final top = MediaQuery.of(context).padding.top;
    final occupation = _donor?['occupation'] as String? ?? '';
    final company = _donor?['company'] as String? ?? '';
    final subtitle = [occupation, company].where((s) => s.isNotEmpty).join(' · ');

    return Scaffold(
      backgroundColor: _surface2,
      body: Column(children: [
        // ── gradient header ────────────────────────────────────────
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [_brand700, _brand600], begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
          padding: EdgeInsets.fromLTRB(18, top + 12, 18, 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              GestureDetector(
                onTap: () => context.go('/donors'),
                child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
              ),
              GestureDetector(
                onTap: () => context.go('/donors/${widget.id}/edit'),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white.withValues(alpha: 0.4))),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.edit_outlined, color: Colors.white, size: 15),
                    SizedBox(width: 6),
                    Text('Edit', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  gradient: _photoBytes == null ? LinearGradient(colors: [color, Color.lerp(color, Colors.black, 0.25)!]) : null,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
                ),
                clipBehavior: Clip.hardEdge,
                child: _photoBytes != null
                    ? Image.memory(_photoBytes!, fit: BoxFit.cover, width: 64, height: 64)
                    : Center(child: Text(_initials(_name), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 22))),
              ),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_name, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12.5, fontWeight: FontWeight.w500), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 8),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
                    child: Text(_categoryName, style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withValues(alpha: 0.3))),
                    child: Text(_donorId, style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 11.5, fontWeight: FontWeight.w700)),
                  ),
                ]),
              ])),
            ]),
            const SizedBox(height: 18),
            // combined stats + quick actions in one row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 12),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(16)),
              child: Row(children: [
                _StatItem(label: 'Donated', value: _fmtAmount(_totalDonated)),
                _vDivider,
                _StatItem(label: 'Gifts', value: '$_donationCount'),
                _vDivider,
                _StatItem(label: 'Last Gift', value: _lastGift, small: true),
                _vDivider,
                _QuickAction(icon: Icons.call_outlined,  label: 'Call',      onTap: _call),
                _vDivider,
                _QuickAction(icon: Icons.chat_outlined,  label: 'WhatsApp',  onTap: _openWhatsApp),
                _vDivider,
                _QuickAction(icon: Icons.email_outlined, label: 'Email',     onTap: _sendEmail),
              ]),
            ),
          ]),
        ),

        // ── tabs ───────────────────────────────────────────────────
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabs,
            indicatorColor: _brand600,
            indicatorWeight: 3,
            labelColor: _brand600,
            unselectedLabelColor: _onSurface3,
            labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: const [Tab(text: 'Overview'), Tab(text: 'Donations'), Tab(text: 'Sponsored'), Tab(text: 'Documents'), Tab(text: 'Activities')],
          ),
        ),

        Expanded(child: TabBarView(controller: _tabs, children: [
          _OverviewTab(donor: _donor!),
          _DonationsTab(donations: _donations, donorId: widget.id),
          _SponsoredTab(donor: _donor!, donorId: widget.id),
          _DocumentsTab(donorId: widget.id),
          _ActivitiesTab(donorId: widget.id),
        ])),
      ]),
    );
  }
}

// ── shared widgets ────────────────────────────────────────────────────
class _StatItem extends StatelessWidget {
  const _StatItem({required this.label, required this.value, this.small = false});
  final String label, value;
  final bool small;
  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Text(value, style: TextStyle(color: Colors.white, fontSize: small ? 13 : 17, fontWeight: FontWeight.w800), maxLines: 1, overflow: TextOverflow.ellipsis),
    const SizedBox(height: 3),
    Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11, fontWeight: FontWeight.w600)),
  ]));
}

final _vDivider = Container(width: 1, height: 36, margin: const EdgeInsets.symmetric(horizontal: 6), color: Colors.white.withValues(alpha: 0.25));

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.onTap});
  final IconData icon; final String label; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Expanded(child: GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: Colors.white, size: 18),
      const SizedBox(height: 3),
      Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 10, fontWeight: FontWeight.w700)),
    ]),
  ));
}

// ── overview tab ──────────────────────────────────────────────────────
class _OverviewTab extends StatelessWidget {
  const _OverviewTab({required this.donor});
  final Map<String, dynamic> donor;

  String get _categoryName {
    final cats = donor['categories'] as List<dynamic>? ?? [];
    if (cats.isEmpty) return '—';
    final cat = cats.first as Map<String, dynamic>?;
    return (cat?['category'] as Map<String, dynamic>?)?['name'] as String? ?? '—';
  }

  String _v(dynamic v) {
    final s = v as String?;
    return (s != null && s.isNotEmpty) ? s : 'Not Available';
  }

  String _gender(dynamic v) {
    if (v == 'MALE') return 'Male';
    if (v == 'FEMALE') return 'Female';
    return _v(v);
  }

  String _address() {
    final parts = <String>[
      donor['address'] as String? ?? '',
      donor['city'] as String? ?? '',
      donor['state'] as String? ?? '',
      donor['pincode'] as String? ?? '',
    ].where((s) => s.isNotEmpty).toList();
    return parts.isEmpty ? '—' : parts.join(', ');
  }

  String _prefContact() {
    const labels = {'CALL': 'Call', 'WHATSAPP': 'WhatsApp', 'EMAIL': 'Email'};
    final raw = (donor['preferredContactMethod'] as String? ?? '').trim();
    if (raw.isEmpty) return 'Not Available';
    final prefs = raw.split(',').map((c) => labels[c.trim()] ?? c.trim()).where((s) => s.isNotEmpty).join(' · ');
    return prefs.isEmpty ? 'Not Available' : prefs;
  }

  // `donor['donations']` is embedded by the backend (GET /donors/:id),
  // newest-first, capped at 10 — enough to derive "last donation" and its
  // type. `totalDonated` is a separately-computed accurate all-time sum.
  String get _totalDonations {
    final total = donor['totalDonated'];
    if (total is num) return _fmtAmount(total);
    return 'Not Available';
  }

  Map<String, dynamic>? get _mostRecentDonation {
    final list = (donor['donations'] as List?)?.whereType<Map>().toList() ?? const [];
    return list.isEmpty ? null : list.first.cast<String, dynamic>();
  }

  String get _lastDonationLabel {
    final d = _mostRecentDonation;
    if (d == null) return 'Not Available';
    final amt = _fmtAmount(d['amount']);
    final date = _fmtDate(d['date'] as String?);
    return '$amt on $date';
  }

  String get _donationTypeLabel {
    final d = _mostRecentDonation;
    final type = (d?['type'] as Map?)?['label'] as String?;
    return (type != null && type.isNotEmpty) ? type : 'Not Available';
  }

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('Donor ID',                _v(donor['donorCode'])),
      ('Donor Category',          _categoryName),
      ('Full Name',               _v(donor['name'])),
      ('PAN Number',              _v(donor['pan'])),
      ('Aadhaar Number',          _v(donor['aadhaar'])),
      ('Gender',                  _gender(donor['gender'])),
      ('Email',                   _v(donor['email'])),
      ('Mobile',                  _v(donor['mobile'])),
      ('WhatsApp',                _v(donor['whatsapp'])),
      ('Preferred Contact',       _prefContact()),
      ('Address',                 _address()),
      ('City',                    _v(donor['city'])),
      ('State',                   _v(donor['state'])),
      ('Country',                 _v(donor['country'])),
      ('Date of Birth',           _fmtDate(donor['dob'] as String?)),
      ('Anniversary',             _fmtDate(donor['anniversary'] as String?)),
      ('Occupation / Designation',_v(donor['occupation'])),
      ('Organisation Name',       _v(donor['company'])),
      ('Donation Type',           _donationTypeLabel),
      ('Total Donations',         _totalDonations),
      ('Last Donation',           _lastDonationLabel),
      ('Status',                  donor['isActive'] == false ? 'Inactive' : 'Active'),
      ('Notes',                   _v(donor['notes'])),
      ('Recurring',               _v(donor['recurring'] ?? donor['recurringType'])),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 40),
      physics: const BouncingScrollPhysics(),
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _border),
            boxShadow: const [BoxShadow(color: Color(0x080D2822), blurRadius: 6, offset: Offset(0, 2))],
          ),
          child: Column(children: rows.asMap().entries.map((entry) {
            final idx = entry.key;
            final label = entry.value.$1;
            final value = entry.value.$2;
            final isLast = idx == rows.length - 1;
            final isNotes = label == 'Notes';
            return Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: isNotes
                  ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _onSurface3)),
                      const SizedBox(height: 6),
                      Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: _onSurface1, height: 1.5)),
                    ])
                  : Row(children: [
                      SizedBox(
                        width: 152,
                        child: Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _onSurface3)),
                      ),
                      Expanded(child: Text(value,
                        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: _onSurface1),
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                      )),
                    ]),
              ),
              if (!isLast) const Divider(height: 1, color: _border),
            ]);
          }).toList()),
        ),
      ],
    );
  }
}

// ── global donation + sponsor store (keyed by donor id) ──────────────
final _donorLocalDonations = <String, List<Map<String, dynamic>>>{};
final _donorLocalSponsors  = <String, List<Map<String, dynamic>>>{};

// ── donations tab ─────────────────────────────────────────────────────
class _DonationsTab extends StatefulWidget {
  const _DonationsTab({required this.donations, required this.donorId});
  final List<Map<String, dynamic>> donations;
  final String donorId;
  @override
  State<_DonationsTab> createState() => _DonationsTabState();
}

class _DonationsTabState extends State<_DonationsTab> {

  Color _typeColor(String t) {
    if (t.contains('Education') || t.contains('School')) return _violet500;
    if (t.contains('Child')) return _brand600;
    if (t.contains('Medical') || t.contains('Health')) return _coral500;
    if (t.contains('Food')) return _amber600;
    return _sky500;
  }

  void _openAddDonation() {
    final amountCtrl = TextEditingController();
    String type = 'Education Fund';
    String method = 'UPI';
    const types = ['Education Fund', 'Child Sponsorship', 'Healthcare', 'General Donation', 'Food & Nutrition'];
    const methods = ['UPI', 'Bank Transfer', 'Cheque', 'Cash'];
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Add Donation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _onSurface1)),
              const SizedBox(height: 16),
              const Text('Amount (₹)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _onSurface2)),
              const SizedBox(height: 6),
              TextField(
                controller: amountCtrl, keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: 'e.g. 5000', prefixText: '₹ ',
                  filled: true, fillColor: const Color(0xFFF4F7F6),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5EBE9))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFE5EBE9))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _brand600, width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 14),
              const Text('Donation Type', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _onSurface2)),
              const SizedBox(height: 6),
              Wrap(spacing: 6, runSpacing: 6, children: types.map((t) => GestureDetector(
                onTap: () => setSt(() => type = t),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: type == t ? _brand600 : const Color(0xFFF4F7F6),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: type == t ? _brand600 : const Color(0xFFE5EBE9)),
                  ),
                  child: Text(t, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: type == t ? Colors.white : _onSurface2)),
                ),
              )).toList()),
              const SizedBox(height: 14),
              const Text('Payment Method', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _onSurface2)),
              const SizedBox(height: 6),
              Wrap(spacing: 6, children: methods.map((m) => GestureDetector(
                onTap: () => setSt(() => method = m),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: method == m ? _brand600 : const Color(0xFFF4F7F6),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: method == m ? _brand600 : const Color(0xFFE5EBE9)),
                  ),
                  child: Text(m, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: method == m ? Colors.white : _onSurface2)),
                ),
              )).toList()),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(foregroundColor: _onSurface2, side: const BorderSide(color: Color(0xFFE5EBE9)), padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700)),
                )),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton(
                  onPressed: () {
                    final amt = int.tryParse(amountCtrl.text.trim()) ?? 0;
                    if (amt <= 0) return;
                    final now = DateTime.now();
                    _donorLocalDonations.putIfAbsent(widget.donorId, () => []).insert(0, {
                      'amount': amt, 'donationType': type, 'paymentMethod': method,
                      'date': '${now.day.toString().padLeft(2,'0')}-${now.month.toString().padLeft(2,'0')}-${now.year}',
                      'receiptNo': 'SF/${now.year % 100}-${(now.year%100)+1}/${(1000 + (_donorLocalDonations[widget.donorId]?.length ?? 0))}',
                    });
                    Navigator.pop(ctx);
                    setState(() {});
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: _brand600, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                  child: const Text('Save Donation', style: TextStyle(fontWeight: FontWeight.w700)),
                )),
              ]),
            ]),
          ),
        ),
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allDonations = [...(_donorLocalDonations[widget.donorId] ?? []), ...widget.donations];
    return Column(children: [
      // header with + button
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
        child: Row(children: [
          Text('${allDonations.length} Donation${allDonations.length == 1 ? '' : 's'}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _onSurface2)),
          const Spacer(),
          GestureDetector(
            onTap: _openAddDonation,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(color: _brand600, borderRadius: BorderRadius.circular(10)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add, color: Colors.white, size: 16),
                SizedBox(width: 4),
                Text('Add Donation', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
              ]),
            ),
          ),
        ]),
      ),
      if (allDonations.isEmpty)
        const Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('💸', style: TextStyle(fontSize: 44)),
          SizedBox(height: 12),
          Text('No donations yet', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _onSurface3)),
        ])))
      else
      Expanded(child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 40),
        physics: const BouncingScrollPhysics(),
        itemCount: allDonations.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final d = allDonations[i];
        final typeMap = d['type'] as Map<String, dynamic>?;
        final label = typeMap?['label'] as String? ?? d['donationType'] as String? ?? 'Donation';
        final amount = d['amount'] as int? ?? 0;
        final date = _fmtDate(d['createdAt'] as String? ?? d['date'] as String?);
        final receipt = d['receiptNo'] as String? ?? '—';
        final method = (d['paymentMode'] as String? ?? d['paymentMethod'] as String? ?? '—')
            .replaceAll('_', ' ');
        final c = _typeColor(label);
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white, borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _border),
            boxShadow: const [BoxShadow(color: Color(0x080D2822), blurRadius: 6, offset: Offset(0, 2))],
          ),
          child: Row(children: [
            Container(width: 44, height: 44,
              decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
              child: Center(child: Icon(Icons.account_balance_wallet_outlined, color: c, size: 20))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _onSurface1))),
                Text(_fmtAmount(amount), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: c)),
              ]),
              const SizedBox(height: 4),
              Text('$date  ·  $receipt', style: const TextStyle(fontSize: 12, color: _onSurface3, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: _surface2, borderRadius: BorderRadius.circular(6)),
                child: Text(method, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _onSurface2)),
              ),
            ])),
          ]),
        );
      },
      )),
    ]);
  }
}

// ── global doc store: persists across navigation (cleared on restart) ─
final _donorUploadedDocs = <String, Set<String>>{};
final _donorExtraDocs    = <String, List<String>>{};
final _donorDocBytes     = <String, Map<String, Uint8List>>{};

// ── documents tab ─────────────────────────────────────────────────────
class _DocEntry {
  _DocEntry(this.name, this.type);
  final String name, type;
}

const _kBaseDocs = [
  ('Aadhaar Card',         'ID Proof'),
  ('PAN Card',             'Tax ID'),
  ('Tax Exemption Letter', 'Certificate'),
  ('Cancelled Cheque',     'Bank Proof'),
  ('Donor Agreement',      'Agreement'),
];

class _DocumentsTab extends StatefulWidget {
  const _DocumentsTab({required this.donorId});
  final String donorId;
  @override
  State<_DocumentsTab> createState() => _DocumentsTabState();
}

class _DocumentsTabState extends State<_DocumentsTab> {
  late final List<_DocEntry> _docs;
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _docs = _kBaseDocs.map((t) => _DocEntry(t.$1, t.$2)).toList();
    // restore any extra docs previously added for this donor
    for (final name in _donorExtraDocs[widget.donorId] ?? <String>[]) {
      _docs.add(_DocEntry(name, 'Attachment'));
    }
  }

  bool _isUploaded(String name) =>
      (_donorUploadedDocs[widget.donorId] ?? {}).contains(name);

  void _markUploaded(String name) {
    _donorUploadedDocs.putIfAbsent(widget.donorId, () => {}).add(name);
  }

  void _storeBytes(String docName, Uint8List? bytes) {
    if (bytes == null) return;
    _donorDocBytes.putIfAbsent(widget.donorId, () => {})[docName] = bytes;
  }

  Uint8List? _getBytes(String docName) =>
      _donorDocBytes[widget.donorId]?[docName];

  void _viewDoc(String docName) {
    final bytes = _getBytes(docName);
    if (bytes == null) return;
    openBytesInBrowser(bytes, docName);
  }

  Future<void> _pick(String docName) async {
    setState(() => _uploading = true);
    try {
      final r = await FilePicker.platform.pickFiles(allowMultiple: false, withData: true);
      if (r != null && r.files.isNotEmpty && mounted) {
        _storeBytes(docName, r.files.single.bytes);
        setState(() => _markUploaded(docName));
      }
    } catch (_) {}
    if (mounted) setState(() => _uploading = false);
  }

  Future<void> _pickOther() async {
    final nameCtrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Document Name'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Enter document name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final v = nameCtrl.text.trim();
              if (v.isNotEmpty) Navigator.pop(ctx, v);
            },
            child: const Text('Next'),
          ),
        ],
      ),
    );
    if (name == null || !mounted) return;
    setState(() => _uploading = true);
    try {
      final r = await FilePicker.platform.pickFiles(allowMultiple: false, withData: true);
      if (r != null && r.files.isNotEmpty && mounted) {
        _storeBytes(name, r.files.single.bytes);
        setState(() {
          _docs.add(_DocEntry(name, 'Attachment'));
          _markUploaded(name);
          _donorExtraDocs.putIfAbsent(widget.donorId, () => []).add(name);
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _uploading = false);
  }

  @override
  Widget build(BuildContext context) {
    final uploadedCount = _docs.where((d) => _isUploaded(d.name)).length;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 40),
      physics: const BouncingScrollPhysics(),
      children: [
        Row(children: [
          const Text('DOCUMENTS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _onSurface3, letterSpacing: 1.2)),
          const Spacer(),
          GestureDetector(
            onTap: _uploading ? null : _pickOther,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(color: _brand600, borderRadius: BorderRadius.circular(8)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.upload_file_outlined, size: 13, color: Colors.white),
                SizedBox(width: 4),
                Text('+ Upload', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white)),
              ]),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(color: _brand100, borderRadius: BorderRadius.circular(8)),
            child: Text('$uploadedCount uploaded', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _brand600)),
          ),
        ]),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: _border)),
          child: Column(children: _docs.asMap().entries.map((entry) {
            final i = entry.key;
            final doc = entry.value;
            final uploaded = _isUploaded(doc.name);
            final isLast = i == _docs.length - 1;
            return Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(children: [
                  Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: uploaded ? _brand100 : _surface2,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(child: Icon(
                      uploaded ? Icons.insert_drive_file_rounded : Icons.insert_drive_file_outlined,
                      size: 20, color: uploaded ? _brand600 : _onSurface3,
                    )),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(doc.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: _onSurface1)),
                    const SizedBox(height: 2),
                    Row(children: [
                      Text(doc.type, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: _onSurface3)),
                      const Text('  ·  ', style: TextStyle(fontSize: 11.5, color: _onSurface3)),
                      Text(
                        uploaded ? 'Uploaded' : 'Not uploaded',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: uploaded ? _brand600 : _onSurface3),
                      ),
                    ]),
                  ])),
                  const SizedBox(width: 8),
                  if (uploaded) ...[
                    GestureDetector(
                      onTap: () => _viewDoc(doc.name),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(color: _brand600, borderRadius: BorderRadius.circular(8)),
                        child: const Text('View', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  GestureDetector(
                    onTap: _uploading ? null : () => _pick(doc.name),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: uploaded ? _surface2 : _brand600,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        uploaded ? 'Replace' : 'Upload',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: uploaded ? _onSurface2 : Colors.white),
                      ),
                    ),
                  ),
                ]),
              ),
              if (!isLast) const Divider(height: 1, color: _border),
            ]);
          }).toList()),
        ),
      ],
    );
  }
}

// ── sponsored children tab ────────────────────────────────────────────
class _SponsoredTab extends StatefulWidget {
  const _SponsoredTab({required this.donor, required this.donorId});
  final Map<String, dynamic> donor;
  final String donorId;
  @override
  State<_SponsoredTab> createState() => _SponsoredTabState();
}

class _SponsoredTabState extends State<_SponsoredTab> {
  void _openAddSponsor(List<Map<String, dynamic>> allChildren) {
    final nameCtrl   = TextEditingController();
    final idCtrl     = TextEditingController(text: 'SKT-C-${(1000 + allChildren.length + 1).toString().padLeft(4,'0')}');
    final amtCtrl    = TextEditingController();
    final centreCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Add Sponsored Child', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: _onSurface1)),
              const SizedBox(height: 16),
              _SponsorField(ctrl: nameCtrl,   label: 'Child Name',   hint: 'e.g. Aarav Kumar'),
              const SizedBox(height: 10),
              _SponsorField(ctrl: idCtrl,     label: 'Child ID',     hint: 'SKT-C-0001'),
              const SizedBox(height: 10),
              _SponsorField(ctrl: amtCtrl,    label: 'Amount / year (₹)', hint: 'e.g. 18000', keyboard: TextInputType.number),
              const SizedBox(height: 10),
              _SponsorField(ctrl: centreCtrl, label: 'Centre',       hint: 'e.g. Sulibele'),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(foregroundColor: _onSurface2, side: const BorderSide(color: _border), padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700)),
                )),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton(
                  onPressed: () {
                    final name = nameCtrl.text.trim();
                    if (name.isEmpty) return;
                    final amt = amtCtrl.text.trim();
                    final now = DateTime.now();
                    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
                    _donorLocalSponsors.putIfAbsent(widget.donorId, () => []).add({
                      'name':    name,
                      'childId': idCtrl.text.trim(),
                      'age':     0,
                      'centre':  centreCtrl.text.trim().isNotEmpty ? centreCtrl.text.trim() : 'Main',
                      'since':   '${months[now.month - 1]} ${now.year}',
                      'amount':  amt.isNotEmpty ? '₹${int.tryParse(amt) != null ? _fmtAmt(int.parse(amt)) : amt} / yr' : '—',
                      'status':  'Active',
                    });
                    Navigator.pop(ctx);
                    setState(() {});
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: _brand600, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 13), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
                  child: const Text('Add Child', style: TextStyle(fontWeight: FontWeight.w700)),
                )),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  String _fmtAmt(int v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000)   return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toString();
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.donor['id'] as String? ?? '';
    // Only the original demo seed donors carry a sample sponsored child.
    // A child is NEVER auto-assigned just because the donor's category is
    // "Child Sponsor" — it must be added explicitly via "Add Sponsor".
    final showMock = id == 'd1' || id == 'd7' || id == 'd11';
    final mockList = showMock
        ? [{'name': 'Aarav Kumar', 'childId': 'SKT-C-0001', 'age': 12, 'centre': 'Sulibele', 'since': 'Jul 2022', 'amount': '₹18,000 / yr', 'status': 'Active'}]
        : <Map<String, dynamic>>[];
    final allChildren = <Map<String, dynamic>>[...mockList, ...(_donorLocalSponsors[widget.donorId] ?? [])];

    if (allChildren.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.child_care_outlined, size: 44, color: _onSurface3),
        const SizedBox(height: 12),
        const Text('No children sponsored', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _onSurface3)),
        const SizedBox(height: 6),
        const Text('This donor has not sponsored any child yet.', style: TextStyle(fontSize: 13, color: _onSurface3)),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: () => _openAddSponsor(allChildren),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(color: _brand600, borderRadius: BorderRadius.circular(14)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.add, color: Colors.white, size: 18),
              SizedBox(width: 6),
              Text('Add Sponsor', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
            ]),
          ),
        ),
      ]));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 40),
      physics: const BouncingScrollPhysics(),
      children: [
        Row(children: [
          const Text('SPONSORED CHILDREN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _onSurface3, letterSpacing: 1.2)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(color: _brand100, borderRadius: BorderRadius.circular(8)),
            child: Text('${allChildren.length} active', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _brand600)),
          ),
        ]),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => _openAddSponsor(allChildren),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(color: _brand600, borderRadius: BorderRadius.circular(14)),
            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.add, color: Colors.white, size: 18),
              SizedBox(width: 6),
              Text('Add Sponsor', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
            ]),
          ),
        ),
        const SizedBox(height: 10),
        ...allChildren.map((child) {
          final name = child['name'] as String;
          final initials = name.split(' ').map((p) => p[0]).take(2).join();
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _border),
              boxShadow: const [BoxShadow(color: Color(0x080D2822), blurRadius: 6, offset: Offset(0, 2))],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 48, height: 48,
                  decoration: const BoxDecoration(color: _brand100, shape: BoxShape.circle),
                  child: Center(child: Text(initials, style: const TextStyle(color: _brand600, fontWeight: FontWeight.w800, fontSize: 16))),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _onSurface1)),
                  const SizedBox(height: 3),
                  Text('${child['childId']}  ·  Age ${child['age']}  ·  ${child['centre']}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _onSurface3)),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: _brand100, borderRadius: BorderRadius.circular(20)),
                  child: Text(child['status'] as String, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _brand600)),
                ),
              ]),
              const SizedBox(height: 14),
              const Divider(height: 1, color: _border),
              const SizedBox(height: 12),
              Row(children: [
                _SpnDetail(label: 'Since', value: child['since'] as String),
                _SpnDetail(label: 'Amount', value: child['amount'] as String),
                _SpnDetail(label: 'Centre', value: child['centre'] as String),
              ]),
            ]),
          );
        }),
      ],
    );
  }
}

// ── sponsor field helper ──────────────────────────────────────────────
class _SponsorField extends StatelessWidget {
  const _SponsorField({required this.ctrl, required this.label, required this.hint, this.keyboard = TextInputType.text});
  final TextEditingController ctrl;
  final String label, hint;
  final TextInputType keyboard;
  @override
  Widget build(BuildContext context) => TextField(
    controller: ctrl,
    keyboardType: keyboard,
    decoration: InputDecoration(
      labelText: label, hintText: hint, isDense: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    ),
  );
}

class _SpnDetail extends StatelessWidget {
  const _SpnDetail({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _onSurface3)),
    const SizedBox(height: 3),
    Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _onSurface1)),
  ]));
}

// ── activities tab (video uploads) ─────────────────────────────────────
const _allowedVideoExt = {'mp4', 'mov', 'avi', 'webm'};

class _ActivityVideo {
  _ActivityVideo({
    required this.id, required this.title, required this.activityDate,
    required this.fileName, this.mimeType, this.uploadedBy, required this.createdAt,
  });
  final String id, title, fileName;
  final DateTime activityDate, createdAt;
  final String? mimeType, uploadedBy;

  factory _ActivityVideo.fromJson(Map<String, dynamic> j) => _ActivityVideo(
    id: j['id'] as String,
    title: j['title'] as String? ?? 'Untitled activity',
    activityDate: DateTime.tryParse(j['activityDate'] as String? ?? '') ?? DateTime.now(),
    fileName: j['fileName'] as String? ?? '',
    mimeType: j['mimeType'] as String?,
    uploadedBy: j['uploadedBy'] as String?,
    createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
  );
}

class _ActivitiesTab extends StatefulWidget {
  const _ActivitiesTab({required this.donorId});
  final String donorId;
  @override
  State<_ActivitiesTab> createState() => _ActivitiesTabState();
}

class _ActivitiesTabState extends State<_ActivitiesTab> {
  List<_ActivityVideo> _videos = [];
  bool _loading = true;
  bool _uploading = false;

  @override
  void initState() { super.initState(); _load(); }

  String get _uploaderName => currentLoggedInRole?.name ?? adminProfile.value.name;

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final r = await apiClient.get('/donors/${widget.donorId}/activity-videos');
      final list = (r['data'] as List<dynamic>? ?? const []);
      final videos = list.whereType<Map>().map((m) => _ActivityVideo.fromJson(m.cast<String, dynamic>())).toList();
      if (mounted) setState(() { _videos = videos; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _mimeFromExt(String ext) {
    switch (ext) {
      case 'mp4': return 'video/mp4';
      case 'mov': return 'video/quicktime';
      case 'avi': return 'video/x-msvideo';
      case 'webm': return 'video/webm';
      default: return null;
    }
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w700)),
      backgroundColor: error ? _coral500 : _brand600, behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
  }

  Future<void> _upload() async {
    final r = await FilePicker.platform.pickFiles(type: FileType.video, withData: true);
    final file = r?.files.firstOrNull;
    if (file == null || file.bytes == null) return;

    final ext = (file.extension ?? file.name.split('.').last).toLowerCase();
    if (!_allowedVideoExt.contains(ext)) {
      _toast('Unsupported format "$ext" — please upload MP4, MOV, AVI, or WebM.', error: true);
      return;
    }

    final defaultTitle = file.name.contains('.') ? file.name.substring(0, file.name.lastIndexOf('.')) : file.name;
    final titleCtrl = TextEditingController(text: defaultTitle);
    DateTime activityDate = DateTime.now();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Upload Activity Video', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(
            controller: titleCtrl, autofocus: true,
            decoration: InputDecoration(labelText: 'Activity Name', filled: true, fillColor: _surface2,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(context: ctx, initialDate: activityDate, firstDate: DateTime(2000), lastDate: DateTime.now());
              if (picked != null) setDlg(() => activityDate = picked);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(color: _surface2, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                const Icon(Icons.calendar_today_outlined, size: 16, color: _onSurface2),
                const SizedBox(width: 10),
                Text('Activity Date: ${_fmtDate(activityDate.toIso8601String())}', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: _brand600, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Upload'),
          ),
        ],
      )),
    );
    if (confirmed != true) return;

    setState(() => _uploading = true);
    try {
      await apiClient.post('/donors/${widget.donorId}/activity-videos', {
        'title': titleCtrl.text.trim().isNotEmpty ? titleCtrl.text.trim() : defaultTitle,
        'activityDate': activityDate.toIso8601String(),
        'fileName': file.name,
        'mimeType': _mimeFromExt(ext),
        'uploadedBy': _uploaderName,
        'data': base64Encode(file.bytes!),
      });
      _toast('Video uploaded successfully');
      await _load();
    } catch (e) {
      _toast(e.toString().contains('too large') ? 'Video is too large — please upload a shorter clip.' : 'Upload failed. Please try again.', error: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<Uint8List?> _fetchBytes(String videoId) async {
    try {
      final r = await apiClient.get('/donors/activity-videos/$videoId');
      final data = (r['data'] as Map?)?['data'] as String?;
      if (data == null) return null;
      return base64Decode(data);
    } catch (_) { return null; }
  }

  Future<void> _play(_ActivityVideo v) async {
    showDialog(context: context, barrierColor: Colors.black87, builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: FutureBuilder<Uint8List?>(
        future: _fetchBytes(v.id),
        builder: (ctx, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator(color: Colors.white)));
          }
          final bytes = snap.data;
          return Column(mainAxisSize: MainAxisSize.min, children: [
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close, color: Colors.white)),
            ]),
            if (bytes == null)
              const _VideoNotAvailable()
            else
              AspectRatio(aspectRatio: 16 / 9, child: WebVideoPlayer(bytes: bytes, mimeType: v.mimeType)),
          ]);
        },
      ),
    ));
  }

  Future<void> _download(_ActivityVideo v) async {
    final bytes = await _fetchBytes(v.id);
    if (bytes == null) { _toast('Video not available', error: true); return; }
    downloadBytes(bytes, v.fileName, mimeType: v.mimeType);
  }

  Future<void> _delete(_ActivityVideo v) async {
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text('Delete Video?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      content: Text('This will permanently remove "${v.title}".', style: const TextStyle(fontSize: 13.5, color: _onSurface2)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: _coral500, fontWeight: FontWeight.w700))),
      ],
    ));
    if (confirmed != true) return;
    try { await apiClient.delete('/donors/activity-videos/${v.id}'); _toast('Video deleted'); } catch (_) { _toast('Delete failed', error: true); }
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
        child: Row(children: [
          Text('${_videos.length} Video${_videos.length == 1 ? '' : 's'}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _onSurface2)),
          const Spacer(),
          GestureDetector(
            onTap: _uploading ? null : _upload,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(color: _brand600, borderRadius: BorderRadius.circular(10)),
              child: _uploading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.upload_rounded, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text('Upload Video', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                  ]),
            ),
          ),
        ]),
      ),
      if (_loading)
        Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 40),
          children: List.generate(3, (_) => const Padding(padding: EdgeInsets.only(bottom: 10), child: _SkeletonCard()))))
      else if (_videos.isEmpty)
        Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.videocam_off_outlined, size: 44, color: _onSurface3),
          const SizedBox(height: 12),
          const Text('No activity videos uploaded.', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _onSurface3)),
          const SizedBox(height: 6),
          const Text('Tap Upload Video to add the first one.', style: TextStyle(fontSize: 13, color: _onSurface3)),
        ])))
      else
        Expanded(child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 40),
          physics: const BouncingScrollPhysics(),
          itemCount: _videos.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final v = _videos[i];
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _border),
                boxShadow: const [BoxShadow(color: Color(0x080D2822), blurRadius: 6, offset: Offset(0, 2))],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                GestureDetector(
                  onTap: () => _play(v),
                  child: Container(
                    height: 120, width: double.infinity,
                    decoration: BoxDecoration(color: const Color(0xFF15211E), borderRadius: BorderRadius.circular(12)),
                    child: const Center(child: Icon(Icons.play_circle_fill_rounded, size: 44, color: Colors.white70)),
                  ),
                ),
                const SizedBox(height: 10),
                Text(v.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _onSurface1)),
                const SizedBox(height: 3),
                Text(
                  'Activity date: ${_fmtDate(v.activityDate.toIso8601String())} · Uploaded ${_fmtDate(v.createdAt.toIso8601String())}${(v.uploadedBy ?? '').isNotEmpty ? ' by ${v.uploadedBy}' : ''}',
                  style: const TextStyle(fontSize: 12, color: _onSurface3, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  _ActBtn(label: 'Play', icon: Icons.play_arrow_rounded, onTap: () => _play(v)),
                  const SizedBox(width: 8),
                  _ActBtn(label: 'Download', icon: Icons.download_outlined, color: _sky500, onTap: () => _download(v)),
                  const SizedBox(width: 8),
                  _ActBtn(label: 'Delete', icon: Icons.delete_outline, color: _coral500, onTap: () => _delete(v)),
                ]),
              ]),
            );
          },
        )),
    ]);
  }
}

// Loading-state placeholder shown while the video list is being fetched.
class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();
  @override
  Widget build(BuildContext context) => Container(
    height: 74, width: double.infinity,
    decoration: BoxDecoration(color: _surface2, borderRadius: BorderRadius.circular(16)),
  );
}

class _VideoNotAvailable extends StatelessWidget {
  const _VideoNotAvailable();
  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 16 / 9,
    child: Container(
      color: const Color(0xFF15211E),
      child: const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.videocam_off_outlined, size: 40, color: Colors.white38),
        SizedBox(height: 10),
        Text('Video Not Available', style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w700)),
      ])),
    ),
  );
}

class _ActBtn extends StatelessWidget {
  const _ActBtn({required this.label, required this.icon, required this.onTap, this.color = _brand600});
  final String label; final IconData icon; final VoidCallback onTap; final Color color;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
      ]),
    ),
  );
}
