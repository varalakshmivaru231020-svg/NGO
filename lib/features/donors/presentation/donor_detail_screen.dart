import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'add_donor_screen.dart' show AddDonorScreen;
import 'package:url_launcher/url_launcher.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/open_bytes.dart';
import '../../../core/widgets/lazy_photo.dart';
import '../../../core/utils/native_file_saver.dart';
import '../../../core/utils/video_player.dart';
import '../../donations/presentation/receipt_generator.dart';
import '../../../core/auth/role_auth.dart';
import '../../../core/theme/app_theme.dart';
import '../../settings/profile_store.dart';
import 'donors_screen.dart' show demoLocalDonors, mockDonorData, localDonorPhotos;
import 'package:saksham_app/core/ui/ui.dart';

const _brand600 = Color(0xFFFF9933);
const _brand700 = Color(0xFFE07C1F);
const _brand100 = Color(0xFFFFE8CC);
const _amber600 = Color(0xFFE0921A);
const _coral500 = Color(0xFFF2685E);
const _violet500 = Color(0xFF7C6CF0);
const _sky500 = Color(0xFF2D9CDB);

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

  // Donations are fetched on their own with an empty fallback — a failing
  // /donations call must not turn a perfectly good donor into "not found".
  Future<List<Map<String, dynamic>>> _loadDonations() async {
    try {
      final r = await apiClient.get('/donations', params: {'donorId': widget.id, 'limit': '50', 'page': '1'});
      final doRaw = r['data'];
      final doList = doRaw is List ? doRaw : (doRaw is Map ? (doRaw['data'] as List? ?? []) : []);
      return doList.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> _load() async {
    final donationsFuture = _loadDonations();
    try {
      final res = await apiClient.get('/donors/${widget.id}');
      final dRaw = res['data'];
      final donor = dRaw is Map ? Map<String, dynamic>.from(dRaw) : <String, dynamic>{};
      final donations = await donationsFuture;
      if (!mounted) return;
      setState(() {
        _donor = donor.isNotEmpty ? donor : _findMock();
        _donations = donations;
        _loading = false;
        _error = _donor == null ? 'Donor not found' : null;
      });
    } catch (e) {
      final mock = _findMock();
      if (!mounted) return;
      setState(() {
        _donor = mock;
        _loading = false;
        _error = mock == null ? ApiClient.errorMessage(e, fallback: 'Donor not found') : null;
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
    return decodePhoto(_donor?['avatar'] as String?);
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
      return _fmtDate(d['date'] as String? ?? d['createdAt'] as String?);
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
      return Scaffold(
        backgroundColor: context.scaffoldBg,
        body: const Center(child: CircularProgressIndicator(color: _brand600)),
      );
    }
    if (_error != null || _donor == null) {
      return Scaffold(
        backgroundColor: context.scaffoldBg,
        body: SafeArea(child: Column(children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              tooltip: 'Back to Donors',
              icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: context.textPrimary),
              onPressed: () => context.go('/donors'),
            ),
          ),
          Expanded(child: Center(child: SingleChildScrollView(child: ErrorState(
            message: _error ?? 'Donor not found',
            onRetry: () { setState(() { _loading = true; _error = null; }); _load(); },
          )))),
        ])),
      );
    }

    final color = _avColor(_name);
    final top = MediaQuery.of(context).padding.top;
    final occupation = _donor?['occupation'] as String? ?? '';
    final company = _donor?['company'] as String? ?? '';
    final subtitle = [occupation, company].where((s) => s.isNotEmpty).join(' · ');

    return Scaffold(
      backgroundColor: context.scaffoldBg,
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
          color: context.cardBg,
          child: TabBar(
            controller: _tabs,
            indicatorColor: _brand600,
            indicatorWeight: 3,
            labelColor: _brand600,
            unselectedLabelColor: context.textHint,
            labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: const [Tab(text: 'Personal Details'), Tab(text: 'Donations'), Tab(text: 'Sponsored'), Tab(text: 'Documents'), Tab(text: 'Activities')],
          ),
        ),

        Expanded(child: TabBarView(controller: _tabs, children: [
          _OverviewTab(donor: _donor!),
          _DonationsTab(donations: _donations, donorId: widget.id, donor: _donor!),
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
            color: context.cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.border),
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
                      Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.textHint)),
                      const SizedBox(height: 6),
                      Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: context.textPrimary, height: 1.5)),
                    ])
                  : Row(children: [
                      SizedBox(
                        width: 152,
                        child: Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: context.textHint)),
                      ),
                      Expanded(child: Text(value,
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: context.textPrimary),
                        maxLines: 2, overflow: TextOverflow.ellipsis,
                      )),
                    ]),
              ),
              if (!isLast) Divider(height: 1, color: context.border),
            ]);
          }).toList()),
        ),
      ],
    );
  }
}

// ── donations tab ─────────────────────────────────────────────────────
class _DonationsTab extends StatefulWidget {
  const _DonationsTab({required this.donations, required this.donorId, required this.donor});
  final List<Map<String, dynamic>> donations;
  final String donorId;
  final Map<String, dynamic> donor;
  @override
  State<_DonationsTab> createState() => _DonationsTabState();
}

class _DonationsTabState extends State<_DonationsTab> {
  bool _downloading = false;

  Color _typeColor(String t) {
    if (t.contains('Education') || t.contains('School')) return _violet500;
    if (t.contains('Child')) return _brand600;
    if (t.contains('Medical') || t.contains('Health')) return _coral500;
    if (t.contains('Food')) return _amber600;
    return _sky500;
  }

  DateTime? _donationDate(Map<String, dynamic> d) {
    final raw = d['date'] as String? ?? d['createdAt'] as String?;
    return raw != null ? DateTime.tryParse(raw) : null;
  }

  // Bottom sheet: quick presets (This Month / Last 3 Months / This Year /
  // All Time) plus a calendar-based custom range via showDateRangePicker.
  // Returns null if the user backs out without picking anything.
  Future<DateTimeRange?> _pickRange(List<Map<String, dynamic>> donations) async {
    final now = DateTime.now();
    final dates = donations.map(_donationDate).whereType<DateTime>().toList();
    final earliest = dates.isEmpty ? now : dates.reduce((a, b) => a.isBefore(b) ? a : b);
    final allTime = DateTimeRange(start: earliest, end: now);

    return showAppSheet<DateTimeRange>(
      context: context,
      backgroundColor: context.cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: SheetHandle(margin: const EdgeInsets.only(bottom: 16))),
          Text('Select Period', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: ctx.textPrimary)),
          const SizedBox(height: 4),
          Text('Choose the date range to include in the statement', style: TextStyle(fontSize: 12.5, color: ctx.textHint, fontWeight: FontWeight.w500)),
          const SizedBox(height: 16),
          _rangeOption(ctx, 'All Time', () => Navigator.pop(ctx, allTime)),
          _rangeOption(ctx, 'This Month', () => Navigator.pop(ctx, DateTimeRange(start: DateTime(now.year, now.month, 1), end: now))),
          _rangeOption(ctx, 'Last 3 Months', () => Navigator.pop(ctx, DateTimeRange(start: DateTime(now.year, now.month - 3, now.day), end: now))),
          _rangeOption(ctx, 'This Year', () => Navigator.pop(ctx, DateTimeRange(start: DateTime(now.year, 1, 1), end: now))),
          _rangeOption(ctx, 'Custom Range…', () async {
            final picked = await showDateRangePicker(
              context: ctx,
              firstDate: DateTime(2020),
              lastDate: DateTime(2030),
              initialDateRange: allTime,
              builder: (dctx, child) => Theme(data: Theme.of(dctx).copyWith(colorScheme: const ColorScheme.light(primary: _brand600)), child: child!),
            );
            if (ctx.mounted) Navigator.pop(ctx, picked);
          }, isLast: true),
        ]),
      )),
    );
  }

  Widget _rangeOption(BuildContext ctx, String label, VoidCallback onTap, {bool isLast = false}) => Padding(
    padding: EdgeInsets.only(bottom: isLast ? 0 : 8),
    child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: ctx.surface2, borderRadius: BorderRadius.circular(14)),
        child: Row(children: [
          Icon(Icons.calendar_today_outlined, size: 16, color: _brand600),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ctx.textPrimary)),
        ]),
      ),
    ),
  );

  // Builds one combined "Donation Contribution Statement" PDF covering the
  // donor's completed donations in a user-picked date range (Donor Profile →
  // Donations → Download All), mirroring the standard SKET invoice format
  // used for the single-donation receipt.
  Future<void> _downloadAll() async {
    if (_downloading) return; // ignore repeated taps
    final completed = widget.donations.where((d) => (d['status'] as String? ?? 'COMPLETED') == 'COMPLETED').toList();
    if (completed.isEmpty) {
      AppToast.warning(context, 'No completed donations to include');
      return;
    }
    final range = await _pickRange(completed);
    if (range == null || !mounted) return;
    final rangeEnd = DateTime(range.end.year, range.end.month, range.end.day, 23, 59, 59);
    final filtered = completed.where((d) {
      final dt = _donationDate(d);
      return dt != null && !dt.isBefore(range.start) && !dt.isAfter(rangeEnd);
    }).toList();
    if (filtered.isEmpty) {
      AppToast.warning(context, 'No donations in that date range', detail: 'Try a wider period.');
      return;
    }
    setState(() => _downloading = true);
    try {
      final org = await fetchOrgSettings();
      final bytes = await buildDonationStatementPdf(donor: widget.donor, donations: filtered, org: org);
      final donorName = (widget.donor['name'] as String? ?? 'Donor').replaceAll(RegExp(r'\s+'), '_');
      final filename = 'Donation_Statement_$donorName.pdf';
      final ok = await NativeFileSaver.saveBytes(filename, bytes, 'application/pdf');
      if (mounted) {
        if (ok) {
          AppToast.success(context, 'Statement downloaded', detail: filename);
        } else {
          AppToast.error(context, 'Unable to save statement', detail: 'Please try again.');
        }
      }
    } catch (_) {
      if (mounted) AppToast.error(context, 'Unable to generate statement', detail: 'Please try again.');
    }
    if (mounted) setState(() => _downloading = false);
  }

  @override
  Widget build(BuildContext context) {
    final allDonations = widget.donations;
    return Column(children: [
      // header
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
        child: Row(children: [
          Expanded(child: Text('${allDonations.length} Donation${allDonations.length == 1 ? '' : 's'}',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.textSub))),
          if (allDonations.isNotEmpty)
            GestureDetector(
              onTap: _downloading ? null : _downloadAll,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: _brand100, borderRadius: BorderRadius.circular(8), border: Border.all(color: _brand600.withValues(alpha: 0.25))),
                child: _downloading
                    ? const Row(mainAxisSize: MainAxisSize.min, children: [
                        AppSpinner(size: 12),
                        SizedBox(width: 6),
                        Text('Preparing…', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _brand600)),
                      ])
                    : const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.download_rounded, size: 14, color: _brand600),
                        SizedBox(width: 5),
                        Text('Download All', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _brand600)),
                      ]),
              ),
            ),
        ]),
      ),
      if (allDonations.isEmpty)
        Expanded(child: ListView(children: const [
          EmptyState(
            icon: Icons.volunteer_activism_outlined,
            title: 'No donations yet',
            message: 'Donations recorded for this donor will appear here.',
          ),
        ]))
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
        final date = _fmtDate(d['date'] as String? ?? d['createdAt'] as String?);
        final receipt = d['receiptNo'] as String? ?? '—';
        final method = (d['paymentMode'] as String? ?? d['paymentMethod'] as String? ?? '—')
            .replaceAll('_', ' ');
        final c = _typeColor(label);
        // Only a recorded (COMPLETED) donation has a real receipt to show —
        // one still awaiting approval has no invoice yet.
        final status = d['status'] as String? ?? '';
        final donorMap = (d['donor'] as Map?)?.cast<String, dynamic>() ?? const {};
        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.cardBg, borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.border),
            boxShadow: const [BoxShadow(color: Color(0x080D2822), blurRadius: 6, offset: Offset(0, 2))],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 44, height: 44,
                decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12)),
                child: Center(child: Icon(Icons.account_balance_wallet_outlined, color: c, size: 20))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.textPrimary))),
                  Text(_fmtAmount(amount), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: c)),
                ]),
                const SizedBox(height: 4),
                Text('$date  ·  $receipt', style: TextStyle(fontSize: 12, color: context.textHint, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: context.surface2, borderRadius: BorderRadius.circular(6)),
                  child: Text(method, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.textSub)),
                ),
              ])),
            ]),
            if (status == 'COMPLETED') ...[
              const SizedBox(height: 10),
              Divider(height: 1, color: context.border),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () => showReceiptSheet(context, DonationReceipt(
                    receiptNo:    receipt,
                    donorName:    donorMap['name'] as String? ?? 'Donor',
                    donorPhone:   donorMap['mobile'] as String? ?? '',
                    donorCity:    donorMap['city'] as String? ?? '',
                    donorPan:     donorMap['pan'] as String? ?? '',
                    donorEmail:   donorMap['email'] as String? ?? '',
                    donorAddress: donorMap['address'] as String? ?? '',
                    donorState:   donorMap['state'] as String? ?? '',
                    donorPincode: donorMap['pincode'] as String? ?? '',
                    donorCountry: donorMap['country'] as String? ?? '',
                    donationType: label,
                    amount:       amount,
                    paymentMode:  method,
                    date:         date,
                    taxExemption: d['taxExemption'] as bool? ?? false,
                    reference:    d['reference'] as String? ?? '',
                    notes:        d['notes'] as String? ?? '',
                  )),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: _brand100, borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _brand600.withValues(alpha: 0.25)),
                    ),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.receipt_long_outlined, size: 14, color: _brand600),
                      SizedBox(width: 5),
                      Text('Invoice', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _brand600)),
                    ]),
                  ),
                ),
              ),
            ],
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
final _donorDocFilenames = <String, Map<String, String>>{};

// Best-effort mime type from a filename's extension — used so downloads
// carry the correct type/extension instead of a generic octet-stream.
String _mimeFor(String filename) {
  final ext = filename.toLowerCase().split('.').last;
  switch (ext) {
    case 'pdf': return 'application/pdf';
    case 'png': return 'image/png';
    case 'jpg':
    case 'jpeg': return 'image/jpeg';
    case 'doc': return 'application/msword';
    case 'docx': return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    default: return 'application/octet-stream';
  }
}

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

  void _storeBytes(String docName, Uint8List? bytes, {String? originalFilename}) {
    if (bytes == null) return;
    _donorDocBytes.putIfAbsent(widget.donorId, () => {})[docName] = bytes;
    if (originalFilename != null && originalFilename.trim().isNotEmpty) {
      _donorDocFilenames.putIfAbsent(widget.donorId, () => {})[docName] = originalFilename;
    }
  }

  Uint8List? _getBytes(String docName) =>
      _donorDocBytes[widget.donorId]?[docName];

  String _getFilename(String docName) =>
      _donorDocFilenames[widget.donorId]?[docName] ?? docName;

  void _viewDoc(String docName) {
    final bytes = _getBytes(docName);
    if (bytes == null) return;
    openBytesInBrowser(bytes, _getFilename(docName));
  }

  Future<void> _downloadDoc(String docName) async {
    final bytes = _getBytes(docName);
    if (bytes == null) return;
    final filename = _getFilename(docName);
    final ok = await NativeFileSaver.saveBytes(filename, bytes, _mimeFor(filename));
    if (mounted) {
      if (ok) {
        AppToast.success(context, 'Document downloaded', detail: filename);
      } else {
        AppToast.error(context, 'Unable to download document', detail: 'Please try again.');
      }
    }
  }

  Future<void> _pick(String docName) async {
    setState(() => _uploading = true);
    try {
      final r = await FilePicker.platform.pickFiles(allowMultiple: false, withData: true);
      if (r != null && r.files.isNotEmpty && mounted) {
        _storeBytes(docName, r.files.single.bytes, originalFilename: r.files.single.name);
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
        _storeBytes(name, r.files.single.bytes, originalFilename: r.files.single.name);
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
          Text('DOCUMENTS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: context.textHint, letterSpacing: 1.2)),
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
          decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(18), border: Border.all(color: context.border)),
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
                      color: uploaded ? _brand100 : context.surface2,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(child: Icon(
                      uploaded ? Icons.insert_drive_file_rounded : Icons.insert_drive_file_outlined,
                      size: 20, color: uploaded ? _brand600 : context.textHint,
                    )),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(doc.name, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: context.textPrimary)),
                    const SizedBox(height: 2),
                    Row(children: [
                      Text(doc.type, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: context.textHint)),
                      Text('  ·  ', style: TextStyle(fontSize: 11.5, color: context.textHint)),
                      Text(
                        uploaded ? 'Uploaded' : 'Not uploaded',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: uploaded ? _brand600 : context.textHint),
                      ),
                    ]),
                  ])),
                  const SizedBox(width: 8),
                  if (uploaded) ...[
                    GestureDetector(
                      onTap: () => _downloadDoc(doc.name),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(color: context.surface2, borderRadius: BorderRadius.circular(8)),
                        child: Icon(Icons.download_rounded, size: 16, color: context.textSub),
                      ),
                    ),
                    const SizedBox(width: 6),
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
                        color: uploaded ? context.surface2 : _brand600,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        uploaded ? 'Replace' : 'Upload',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: uploaded ? context.textSub : Colors.white),
                      ),
                    ),
                  ),
                ]),
              ),
              if (!isLast) Divider(height: 1, color: context.border),
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
  List<Map<String, dynamic>> _children = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final r = await apiClient.get('/students', params: {'sponsorDonorId': widget.donorId, 'limit': '100', 'page': '1'});
      final inner = r['data'];
      final list = inner is Map ? (inner['data'] as List? ?? []) : (inner is List ? inner : []);
      if (mounted) setState(() {
        _children = list.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _removeSponsorship(String sponsorshipId, String childName) async {
    // Same request as before, run from a confirm dialog so the button shows
    // "Removing…" and a failure keeps the dialog open with an error toast.
    final ok = await AppConfirm.show(
      context,
      title: 'Remove sponsorship?',
      message: 'This donor will no longer be listed as the sponsor of ${childName.isNotEmpty ? childName : 'this child'}.',
      confirmLabel: 'Remove',
      busyLabel: 'Removing…',
      onConfirm: () => apiClient.delete('/students/sponsorships/$sponsorshipId'),
      errorText: (e) => ApiClient.errorMessage(e, fallback: 'Unable to remove sponsorship.'),
    );
    if (!ok || !mounted) return;
    AppToast.success(context, 'Sponsorship removed', detail: childName.isNotEmpty ? childName : null);
    await _load();
  }

  // Search-and-pick an existing student, then prompt for the annual amount —
  // mirrors student_detail_screen.dart's _assignSponsor (the reverse flow:
  // that screen picks a donor for a student, this picks a student for a donor).
  void _openAddSponsor() {
    final searchCtrl = TextEditingController();
    String query = '';
    List<Map<String, dynamic>> allStudents = [];
    bool loadingStudents = true;
    String? loadError;
    bool sheetOpen = true;
    StateSetter? setSheetRef;

    // Fetched ONCE, before the sheet opens — starting it inside the builder
    // fired a new request on every rebuild (each keystroke while loading).
    _fetchAllStudents().then((list) {
      allStudents = list;
      loadingStudents = false;
      if (sheetOpen) setSheetRef?.call(() {});
    }).catchError((Object e) {
      loadError = ApiClient.errorMessage(e, fallback: 'Could not load children');
      loadingStudents = false;
      if (sheetOpen) setSheetRef?.call(() {});
    });

    showAppSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(builder: (ctx, setSheet) {
        setSheetRef = setSheet;
        final q = query.trim().toLowerCase();
        final filtered = q.isEmpty
            ? allStudents
            : allStudents.where((s) {
                final name = (s['name'] as String? ?? '').toLowerCase();
                final childId = (s['childId'] as String? ?? '').toLowerCase();
                return name.contains(q) || childId.contains(q);
              }).toList();

        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.7,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(height: 8),
              const SheetHandle(),
              const SizedBox(height: 14),
              Text('Select a Child to Sponsor', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: context.textPrimary)),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: searchCtrl,
                  onChanged: (v) => setSheet(() => query = v),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Search by name or child ID',
                    hintStyle: TextStyle(color: context.textHint, fontWeight: FontWeight.w400),
                    prefixIcon: Icon(Icons.search, color: context.textHint, size: 20),
                    suffixIcon: query.isEmpty ? null : IconButton(
                      icon: Icon(Icons.close, color: context.textHint, size: 18),
                      onPressed: () { searchCtrl.clear(); setSheet(() => query = ''); },
                    ),
                    filled: true, fillColor: context.surface2,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _brand600, width: 1.5)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: loadingStudents
                  ? const SingleChildScrollView(child: SkeletonList(rows: 5, rowHeight: 60))
                  : loadError != null && allStudents.isEmpty
                  ? SingleChildScrollView(child: EmptyStateLike(
                      icon: Icons.cloud_off_rounded,
                      title: 'Couldn’t load children',
                      message: loadError,
                    ))
                  : filtered.isEmpty
                    ? const SingleChildScrollView(child: EmptyState(
                        icon: Icons.search_off_rounded,
                        title: 'No matching children',
                        message: 'Try a different name or child ID.',
                      ))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 20),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final s = filtered[i];
                          final existingSponsorships = (s['sponsorships'] as List?) ?? const [];
                          final currentSponsorName = existingSponsorships.isNotEmpty
                              ? (((existingSponsorships.first as Map?)?['donor'] as Map?)?['name'] as String?)
                              : null;
                          final centreName = (s['center'] as Map?)?['name'] as String? ?? '—';
                          return ListTile(
                            onTap: () { Navigator.pop(ctx); _promptAmountAndSave(s); },
                            // List rows carry no photo — only `hasPhoto`.
                            leading: ClipOval(child: SizedBox(width: 40, height: 40, child: LazyPhoto(
                              endpoint: '/students/${s['id']}/photo',
                              field: 'photo',
                              size: 40,
                              enabled: s['hasPhoto'] == true,
                              placeholder: CircleAvatar(backgroundColor: _brand100, child: Text(
                                ((s['name'] as String?)?.trim().isNotEmpty == true ? (s['name'] as String).trim() : '?').characters.first.toUpperCase(),
                                style: const TextStyle(color: _brand600, fontWeight: FontWeight.w800))),
                            ))),
                            title: Text(s['name'] as String? ?? '', style: TextStyle(fontWeight: FontWeight.w700, color: context.textPrimary)),
                            subtitle: Text(
                              currentSponsorName != null
                                ? '${s['childId']} · $centreName · Currently sponsored by $currentSponsorName'
                                : '${s['childId']} · $centreName',
                              style: TextStyle(fontSize: 12, color: currentSponsorName != null ? _coral500 : context.textHint),
                            ),
                          );
                        },
                      ),
              ),
            ]),
          ),
        );
      }),
    ).whenComplete(() => sheetOpen = false);
  }

  // Every page of students (backend caps limit at 100). Rows are light now —
  // no base64 photos — so paging through all of them is cheap.
  Future<List<Map<String, dynamic>>> _fetchAllStudents() async {
    final out = <Map<String, dynamic>>[];
    for (int page = 1; page <= 200; page++) {
      final r = await apiClient.get('/students', params: {'limit': '100', 'page': '$page'});
      final inner = r['data'];
      final list = inner is Map ? (inner['data'] as List? ?? []) : (inner is List ? inner : []);
      out.addAll(list.whereType<Map>().map((m) => m.cast<String, dynamic>()));
      final meta = r['meta'] as Map?;
      if (meta?['hasNext'] != true || list.isEmpty) break;
    }
    return out;
  }

  Future<void> _promptAmountAndSave(Map<String, dynamic> student) async {
    final name = student['name'] as String? ?? 'this child';
    // The request runs inside the dialog: "Assigning…" on the button, the
    // dialog stays open (with what was typed) if it fails.
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => _SponsorAmountDialog(
        childName: name,
        onSubmit: (amount, purpose) => apiClient.post('/students/${student['id']}/sponsorships', {
          'donorId': widget.donorId,
          'amount': amount,
          'frequency': 'ANNUAL',
          if (purpose.isNotEmpty) 'notes': purpose,
        }),
      ),
    );
    if (saved != true || !mounted) return;
    AppToast.success(context, 'Sponsorship added', detail: '$name is now sponsored by this donor');
    await _load();
  }

  String _fmtDate(String? iso) {
    if (iso == null) return '—';
    final d = DateTime.tryParse(iso);
    if (d == null) return '—';
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${months[d.month - 1]} ${d.year}';
  }

  String _fmtAmt(num v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000)   return '${(v / 1000).toStringAsFixed(0)}K';
    return v.toString();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(4, 12, 4, 0),
        child: SkeletonList(rows: 3, rowHeight: 72),
      );
    }

    if (_children.isEmpty) {
      return ListView(children: [
        EmptyState(
          icon: Icons.child_care_outlined,
          title: 'No children sponsored',
          message: 'This donor has not sponsored any child yet.',
          actionLabel: 'Add Sponsor',
          onAction: _openAddSponsor,
        ),
      ]);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 40),
      physics: const BouncingScrollPhysics(),
      children: [
        Row(children: [
          Text('SPONSORED CHILDREN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: context.textHint, letterSpacing: 1.2)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
            decoration: BoxDecoration(color: _brand100, borderRadius: BorderRadius.circular(8)),
            child: Text('${_children.length} active', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _brand600)),
          ),
        ]),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: _openAddSponsor,
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
        ..._children.map((child) {
          final name = child['name'] as String? ?? '';
          final initials = name.isEmpty ? '?' : name.split(' ').map((p) => p.isNotEmpty ? p[0] : '').take(2).join();
          final sponsorships = (child['sponsorships'] as List?) ?? const [];
          final sp = sponsorships.isNotEmpty ? (sponsorships.first as Map).cast<String, dynamic>() : null;
          final centreName = (child['center'] as Map?)?['name'] as String? ?? '—';
          final amount = sp?['amount'];
          final purpose = (sp?['notes'] as String?)?.trim() ?? '';
          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: context.cardBg, borderRadius: BorderRadius.circular(18),
              border: Border.all(color: context.border),
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
                  Text(name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: context.textPrimary)),
                  const SizedBox(height: 3),
                  Text('${child['childId'] ?? '—'}  ·  $centreName',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.textHint)),
                ])),
                GestureDetector(
                  onTap: sp == null ? null : () => _removeSponsorship(sp['id'] as String, name),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: context.surface2, borderRadius: BorderRadius.circular(20)),
                    child: Icon(Icons.close, size: 16, color: context.textSub),
                  ),
                ),
              ]),
              const SizedBox(height: 14),
              Divider(height: 1, color: context.border),
              const SizedBox(height: 12),
              Row(children: [
                _SpnDetail(label: 'Since', value: _fmtDate(sp?['startDate'] as String?)),
                _SpnDetail(label: 'Amount', value: amount != null ? '₹${_fmtAmt(amount as num)} / yr' : '—'),
                _SpnDetail(label: 'Centre', value: centreName),
              ]),
              if (purpose.isNotEmpty) ...[
                const SizedBox(height: 12),
                Divider(height: 1, color: context.border),
                const SizedBox(height: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Purpose', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.textHint)),
                  const SizedBox(height: 3),
                  Text(purpose, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: context.textPrimary)),
                ]),
              ],
            ]),
          );
        }),
      ],
    );
  }
}

// Compact "Add Sponsorship" dialog: validates the amount under the field,
// runs [onSubmit] with a loading button and closes (true) only on success.
class _SponsorAmountDialog extends StatefulWidget {
  const _SponsorAmountDialog({required this.childName, required this.onSubmit});
  final String childName;
  final Future<dynamic> Function(int amount, String purpose) onSubmit;
  @override
  State<_SponsorAmountDialog> createState() => _SponsorAmountDialogState();
}

class _SponsorAmountDialogState extends State<_SponsorAmountDialog> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _purpose = TextEditingController();
  bool _busy = false;

  @override
  void dispose() { _amount.dispose(); _purpose.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (_busy) return;
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await widget.onSubmit(int.parse(_amount.text.trim()), _purpose.text.trim());
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppToast.error(context, 'Unable to add sponsorship',
          detail: ApiClient.errorMessage(e, fallback: 'Check your connection and try again.'));
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    insetPadding: const EdgeInsets.all(20),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 420),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        child: Form(
          key: _form,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Add Sponsorship', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Annual sponsorship this donor will provide ${widget.childName}',
                style: TextStyle(fontSize: 12.5, color: context.textHint)),
            const SizedBox(height: 14),
            Text('Sponsorship Amount', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.textSub)),
            const SizedBox(height: 6),
            TextFormField(
              controller: _amount, autofocus: true, keyboardType: TextInputType.number, enabled: !_busy,
              decoration: const InputDecoration(prefixText: '₹ ', hintText: 'e.g. 18000'),
              validator: (v) {
                final n = int.tryParse((v ?? '').trim());
                return (n == null || n <= 0) ? 'Enter an amount greater than 0.' : null;
              },
            ),
            const SizedBox(height: 14),
            Text('Sponsorship Purpose', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.textSub)),
            const SizedBox(height: 6),
            TextFormField(
              controller: _purpose, enabled: !_busy,
              decoration: const InputDecoration(hintText: 'e.g. Education, Health, General welfare'),
              onFieldSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: 18),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              AppButton(label: 'Cancel', variant: AppButtonVariant.secondary,
                  onPressed: _busy ? null : () => Navigator.pop(context)),
              const SizedBox(width: 8),
              AppButton(label: 'Assign', busyLabel: 'Assigning…', loading: _busy, onPressed: _submit),
            ]),
          ]),
        ),
      ),
    ),
  );
}

class _SpnDetail extends StatelessWidget {
  const _SpnDetail({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.textHint)),
    const SizedBox(height: 3),
    Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: context.textPrimary)),
  ]));
}

// ── activities tab (photo + video uploads) ──────────────────────────────
const _allowedVideoExt = {'mp4', 'mov', 'avi', 'webm'};
const _allowedImageExt = {'jpg', 'jpeg', 'png', 'webp'};

enum _MediaKind { image, video }

class _ActivityItem {
  _ActivityItem({
    required this.kind, required this.id, required this.title, required this.activityDate,
    required this.fileName, this.mimeType, this.uploadedBy, required this.createdAt,
  });
  final _MediaKind kind;
  final String id, title, fileName;
  final DateTime activityDate, createdAt;
  final String? mimeType, uploadedBy;

  factory _ActivityItem.fromJson(Map<String, dynamic> j, _MediaKind kind) => _ActivityItem(
    kind: kind,
    id: j['id'] as String,
    title: j['title'] as String? ?? 'Untitled activity',
    activityDate: DateTime.tryParse(j['activityDate'] as String? ?? '') ?? DateTime.now(),
    fileName: j['fileName'] as String? ?? '',
    mimeType: j['mimeType'] as String?,
    uploadedBy: j['uploadedBy'] as String?,
    createdAt: DateTime.tryParse(j['createdAt'] as String? ?? '') ?? DateTime.now(),
  );

  String get _basePath => kind == _MediaKind.video ? '/donors/activity-videos' : '/donors/activity-images';
}

class _ActivitiesTab extends StatefulWidget {
  const _ActivitiesTab({required this.donorId});
  final String donorId;
  @override
  State<_ActivitiesTab> createState() => _ActivitiesTabState();
}

class _ActivitiesTabState extends State<_ActivitiesTab> {
  List<_ActivityItem> _items = [];
  bool _loading = true;
  bool _uploading = false;

  @override
  void initState() { super.initState(); _load(); }

  String get _uploaderName => currentLoggedInRole?.name ?? adminProfile.value.name;

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final results = await Future.wait([
        apiClient.get('/donors/${widget.donorId}/activity-videos'),
        apiClient.get('/donors/${widget.donorId}/activity-images'),
      ]);
      final videos = (results[0]['data'] as List<dynamic>? ?? const [])
          .whereType<Map>().map((m) => _ActivityItem.fromJson(m.cast<String, dynamic>(), _MediaKind.video));
      final images = (results[1]['data'] as List<dynamic>? ?? const [])
          .whereType<Map>().map((m) => _ActivityItem.fromJson(m.cast<String, dynamic>(), _MediaKind.image));
      final merged = [...videos, ...images]..sort((a, b) => b.activityDate.compareTo(a.activityDate));
      if (mounted) setState(() { _items = merged; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _mimeFromExt(String ext, _MediaKind kind) {
    if (kind == _MediaKind.video) {
      switch (ext) {
        case 'mp4': return 'video/mp4';
        case 'mov': return 'video/quicktime';
        case 'avi': return 'video/x-msvideo';
        case 'webm': return 'video/webm';
      }
    } else {
      switch (ext) {
        case 'jpg': case 'jpeg': return 'image/jpeg';
        case 'png': return 'image/png';
        case 'webp': return 'image/webp';
      }
    }
    return null;
  }

  void _toast(String msg, {bool error = false, String? detail}) {
    if (!mounted) return;
    if (error) {
      AppToast.error(context, msg, detail: detail);
    } else {
      AppToast.success(context, msg, detail: detail);
    }
  }

  // Which upload is in flight — its button shows "Uploading…".
  _MediaKind? _uploadingKind;

  Future<void> _upload(_MediaKind kind) async {
    if (_uploading) return; // ignore repeated taps
    final r = await FilePicker.platform.pickFiles(
      type: kind == _MediaKind.video ? FileType.video : FileType.image, withData: true);
    final file = r?.files.firstOrNull;
    if (file == null || file.bytes == null) return;

    final ext = (file.extension ?? file.name.split('.').last).toLowerCase();
    final allowed = kind == _MediaKind.video ? _allowedVideoExt : _allowedImageExt;
    if (!allowed.contains(ext)) {
      final formats = kind == _MediaKind.video ? 'MP4, MOV, AVI, or WebM' : 'JPG, PNG, or WebP';
      _toast('Unsupported file format', detail: 'Please upload $formats.', error: true);
      return;
    }

    final defaultTitle = file.name.contains('.') ? file.name.substring(0, file.name.lastIndexOf('.')) : file.name;
    final titleCtrl = TextEditingController(text: defaultTitle);
    DateTime activityDate = DateTime.now();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(kind == _MediaKind.video ? 'Upload Activity Video' : 'Upload Activity Photo',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          TextField(
            controller: titleCtrl, autofocus: true,
            decoration: InputDecoration(labelText: 'Activity Name', filled: true, fillColor: context.surface2,
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
              decoration: BoxDecoration(color: context.surface2, borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Icon(Icons.calendar_today_outlined, size: 16, color: context.textSub),
                const SizedBox(width: 10),
                Text('Activity Date: ${_fmtDate(activityDate.toIso8601String())}', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ]),
        actions: [
          AppButton(label: 'Cancel', variant: AppButtonVariant.secondary, onPressed: () => Navigator.pop(ctx, false)),
          AppButton(label: 'Upload', icon: Icons.upload_rounded, onPressed: () => Navigator.pop(ctx, true)),
        ],
      )),
    );
    if (confirmed != true || !mounted) return;

    setState(() { _uploading = true; _uploadingKind = kind; });
    try {
      final path = kind == _MediaKind.video ? 'activity-videos' : 'activity-images';
      await apiClient.post('/donors/${widget.donorId}/$path', {
        'title': titleCtrl.text.trim().isNotEmpty ? titleCtrl.text.trim() : defaultTitle,
        'activityDate': activityDate.toIso8601String(),
        'fileName': file.name,
        'mimeType': _mimeFromExt(ext, kind),
        'uploadedBy': _uploaderName,
        'data': base64Encode(file.bytes!),
      });
      _toast('${kind == _MediaKind.video ? 'Video' : 'Photo'} uploaded');
      await _load();
    } catch (e) {
      final tooLarge = e.toString().contains('too large');
      _toast('Unable to upload ${kind == _MediaKind.video ? 'video' : 'photo'}',
        detail: tooLarge ? 'The file is too large — please upload a smaller file.' : 'Please try again.',
        error: true);
    } finally {
      if (mounted) setState(() { _uploading = false; _uploadingKind = null; });
    }
  }

  Future<Uint8List?> _fetchBytes(_ActivityItem item) async {
    try {
      final r = await apiClient.get('${item._basePath}/${item.id}');
      final data = (r['data'] as Map?)?['data'] as String?;
      if (data == null) return null;
      return base64Decode(data);
    } catch (_) { return null; }
  }

  Future<void> _open(_ActivityItem item) async {
    if (item.kind == _MediaKind.video) {
      showDialog(context: context, barrierColor: Colors.black87, builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: FutureBuilder<Uint8List?>(
          future: _fetchBytes(item),
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
                AspectRatio(aspectRatio: 16 / 9, child: WebVideoPlayer(bytes: bytes, mimeType: item.mimeType)),
            ]);
          },
        ),
      ));
    } else {
      showDialog(context: context, barrierColor: Colors.black87, builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: FutureBuilder<Uint8List?>(
          future: _fetchBytes(item),
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
                Container(height: 300, width: double.infinity, color: const Color(0xFF15211E),
                  child: const Center(child: Text('Image Not Available', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700))))
              else
                ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
                  child: InteractiveViewer(child: Image.memory(bytes, fit: BoxFit.contain)),
                ),
            ]);
          },
        ),
      ));
    }
  }

  Future<void> _download(_ActivityItem item) async {
    final bytes = await _fetchBytes(item);
    if (bytes == null) { _toast('File not available', error: true); return; }
    downloadBytes(bytes, item.fileName, mimeType: item.mimeType);
  }

  Future<void> _delete(_ActivityItem item) async {
    final label = item.kind == _MediaKind.video ? 'Video' : 'Photo';
    final confirmed = await AppConfirm.show(
      context,
      title: 'Delete ${label.toLowerCase()}?',
      message: 'Are you sure you want to delete “${item.title}”? This action cannot be undone.',
      onConfirm: () => apiClient.delete('${item._basePath}/${item.id}'),
      errorText: (_) => 'Unable to delete ${label.toLowerCase()}. Please try again.',
    );
    if (!confirmed || !mounted) return;
    _toast('$label deleted', detail: item.title);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
        child: Row(children: [
          Expanded(child: Text('${_items.length} ${_items.length == 1 ? 'Item' : 'Items'}',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.textSub))),
          GestureDetector(
            onTap: _uploading ? null : () => _upload(_MediaKind.image),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(color: _brand100, borderRadius: BorderRadius.circular(10)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (_uploadingKind == _MediaKind.image)
                  const AppSpinner(size: 14)
                else
                  const Icon(Icons.add_photo_alternate_outlined, color: _brand600, size: 16),
                const SizedBox(width: 4),
                Text(_uploadingKind == _MediaKind.image ? 'Uploading…' : 'Photo',
                    style: const TextStyle(color: _brand600, fontSize: 12, fontWeight: FontWeight.w800)),
              ]),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _uploading ? null : () => _upload(_MediaKind.video),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(color: _brand600, borderRadius: BorderRadius.circular(10)),
              child: _uploadingKind == _MediaKind.video
                ? const Row(mainAxisSize: MainAxisSize.min, children: [
                    AppSpinner(size: 14, color: Colors.white),
                    SizedBox(width: 6),
                    Text('Uploading…', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                  ])
                : const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.videocam_outlined, color: Colors.white, size: 16),
                    SizedBox(width: 4),
                    Text('Video', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                  ]),
            ),
          ),
        ]),
      ),
      if (_loading)
        Expanded(child: ListView(padding: const EdgeInsets.fromLTRB(18, 4, 18, 40),
          children: List.generate(3, (_) => const Padding(padding: EdgeInsets.only(bottom: 10), child: _SkeletonCard()))))
      else if (_items.isEmpty)
        Expanded(child: ListView(children: const [
          EmptyState(
            icon: Icons.photo_library_outlined,
            title: 'No activities uploaded',
            message: 'Tap Photo or Video above to add the first one.',
          ),
        ]))
      else
        Expanded(child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 40),
          physics: const BouncingScrollPhysics(),
          itemCount: _items.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final item = _items[i];
            final isVideo = item.kind == _MediaKind.video;
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: context.cardBg, borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.border),
                boxShadow: const [BoxShadow(color: Color(0x080D2822), blurRadius: 6, offset: Offset(0, 2))],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                GestureDetector(
                  onTap: () => _open(item),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      height: 120, width: double.infinity,
                      child: isVideo
                        ? Container(color: const Color(0xFF15211E),
                            child: const Center(child: Icon(Icons.play_circle_fill_rounded, size: 44, color: Colors.white70)))
                        : _ActivityImageThumb(fetchBytes: () => _fetchBytes(item)),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Icon(isVideo ? Icons.videocam_outlined : Icons.image_outlined, size: 14, color: context.textHint),
                  const SizedBox(width: 5),
                  Expanded(child: Text(item.title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: context.textPrimary))),
                ]),
                const SizedBox(height: 3),
                Text(
                  'Activity date: ${_fmtDate(item.activityDate.toIso8601String())} · Uploaded ${_fmtDate(item.createdAt.toIso8601String())}${(item.uploadedBy ?? '').isNotEmpty ? ' by ${item.uploadedBy}' : ''}',
                  style: TextStyle(fontSize: 12, color: context.textHint, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 10),
                Row(children: [
                  _ActBtn(label: isVideo ? 'Play' : 'View', icon: isVideo ? Icons.play_arrow_rounded : Icons.visibility_outlined, onTap: () => _open(item)),
                  const SizedBox(width: 8),
                  _ActBtn(label: 'Download', icon: Icons.download_outlined, color: _sky500, onTap: () => _download(item)),
                  const SizedBox(width: 8),
                  _ActBtn(label: 'Delete', icon: Icons.delete_outline, color: _coral500, onTap: () => _delete(item)),
                ]),
              ]),
            );
          },
        )),
    ]);
  }
}

// Lazily fetches and displays a real thumbnail for an activity photo.
class _ActivityImageThumb extends StatelessWidget {
  const _ActivityImageThumb({required this.fetchBytes});
  final Future<Uint8List?> Function() fetchBytes;
  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List?>(
    future: fetchBytes(),
    builder: (ctx, snap) {
      if (snap.connectionState != ConnectionState.done) {
        return Container(color: context.surface2, child: const Center(child: CircularProgressIndicator(color: _brand600, strokeWidth: 2)));
      }
      final bytes = snap.data;
      if (bytes == null) {
        return Container(color: context.surface2, child: Center(child: Icon(Icons.broken_image_outlined, color: context.textHint, size: 28)));
      }
      return Image.memory(bytes, fit: BoxFit.cover, width: double.infinity, height: double.infinity);
    },
  );
}

// Loading-state placeholder shown while the video list is being fetched.
class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();
  @override
  Widget build(BuildContext context) => Container(
    height: 74, width: double.infinity,
    decoration: BoxDecoration(color: context.surface2, borderRadius: BorderRadius.circular(16)),
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
