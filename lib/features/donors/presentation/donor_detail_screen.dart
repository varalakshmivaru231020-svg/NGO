import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/network/api_client.dart';
import 'donors_screen.dart' show demoLocalDonors, mockDonorData;

const _brand600 = Color(0xFF0E8C76);
const _brand700 = Color(0xFF0B6E5D);
const _brand100 = Color(0xFFD6F3EC);
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
  if (iso == null || iso.isEmpty) return '—';
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

  String get _mobile => _donor?['mobile'] as String? ?? '';
  String get _whatsappNum => (_donor?['whatsapp'] as String?)?.isNotEmpty == true ? _donor!['whatsapp'] as String : _mobile;
  String get _email => _donor?['email'] as String? ?? '';
  String get _donorId => _donor?['donorId'] as String? ?? '—';
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
            GestureDetector(
              onTap: () => context.go('/donors'),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(height: 16),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [color, Color.lerp(color, Colors.black, 0.25)!]),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
                ),
                child: Center(child: Text(_initials(_name), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 22))),
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
            tabs: const [Tab(text: 'Overview'), Tab(text: 'Donations'), Tab(text: 'Sponsored'), Tab(text: 'Documents'), Tab(text: 'Achievements')],
          ),
        ),

        Expanded(child: TabBarView(controller: _tabs, children: [
          _OverviewTab(donor: _donor!),
          _DonationsTab(donations: _donations),
          _SponsoredTab(donor: _donor!),
          _DocumentsTab(donorId: widget.id),
          _AchievementsTab(donorId: widget.id),
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
    return (s != null && s.isNotEmpty) ? s : '—';
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
    final raw = donor['communicationPreferences'] ?? donor['preferredContact'];
    String prefs = '';
    if (raw is List) prefs = raw.map((e) => e.toString()).join(' · ');
    else if (raw is String && raw.isNotEmpty) prefs = raw;
    final lang = donor['language'] as String? ?? donor['preferredLanguage'] as String? ?? '';
    if (prefs.isNotEmpty && lang.isNotEmpty) return '$prefs · $lang';
    if (prefs.isNotEmpty) return prefs;
    if (lang.isNotEmpty) return lang;
    return '—';
  }

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('Donor ID',                _v(donor['donorId'])),
      ('Donor Category',          _categoryName),
      ('Full Name',               _v(donor['name'])),
      ('Gender',                  _gender(donor['gender'])),
      ('Mobile',                  _v(donor['mobile'])),
      ('WhatsApp',                _v(donor['whatsapp'])),
      ('Email',                   _v(donor['email'])),
      ('PAN Number',              _v(donor['pan'])),
      ('Address',                 _address()),
      ('Date of Birth',           _fmtDate(donor['dob'] as String?)),
      ('Anniversary',             _fmtDate(donor['anniversary'] as String?)),
      ('Occupation / Designation',_v(donor['occupation'])),
      ('Organisation Name',       _v(donor['company'])),
      ('Preferred Contact',       _prefContact()),
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

// ── donations tab ─────────────────────────────────────────────────────
class _DonationsTab extends StatelessWidget {
  const _DonationsTab({required this.donations});
  final List<Map<String, dynamic>> donations;

  Color _typeColor(String t) {
    if (t.contains('Education') || t.contains('School')) return _violet500;
    if (t.contains('Child')) return _brand600;
    if (t.contains('Medical') || t.contains('Health')) return _coral500;
    if (t.contains('Food')) return _amber600;
    return _sky500;
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // header with + button
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
        child: Row(children: [
          Text('${donations.length} Donation${donations.length == 1 ? '' : 's'}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _onSurface2)),
          const Spacer(),
          GestureDetector(
            onTap: () {},
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
      if (donations.isEmpty)
        const Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('💸', style: TextStyle(fontSize: 44)),
          SizedBox(height: 12),
          Text('No donations yet', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _onSurface3)),
        ])))
      else
      Expanded(child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(18, 4, 18, 40),
        physics: const BouncingScrollPhysics(),
        itemCount: donations.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final d = donations[i];
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
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.window.open(url, '_blank');
    html.Url.revokeObjectUrl(url);
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
    setState(() => _uploading = true);
    try {
      final r = await FilePicker.platform.pickFiles(allowMultiple: false, withData: true);
      if (r != null && r.files.isNotEmpty && mounted) {
        final name = r.files.single.name;
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
        const SizedBox(height: 12),
        GestureDetector(
          onTap: _uploading ? null : _pickOther,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _brand600.withValues(alpha: 0.4), width: 1.5),
            ),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.upload_file_outlined, size: 18, color: _brand600),
              const SizedBox(width: 8),
              const Text('Upload other attachment', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: _brand600)),
            ]),
          ),
        ),
      ],
    );
  }
}

// ── sponsored children tab ────────────────────────────────────────────
class _SponsoredTab extends StatelessWidget {
  const _SponsoredTab({required this.donor});
  final Map<String, dynamic> donor;

  bool get _isChildSponsor {
    final cats = donor['categories'] as List<dynamic>? ?? [];
    return cats.any((c) {
      final name = ((c as Map<String, dynamic>?)?['category'] as Map<String, dynamic>?)?['name'] as String? ?? '';
      return name.toLowerCase().contains('sponsor');
    });
  }

  @override
  Widget build(BuildContext context) {
    final id = donor['id'] as String? ?? '';
    final showMock = _isChildSponsor || id == 'd1' || id == 'd7' || id == 'd11';

    final children = showMock
        ? [
            {'name': 'Aarav Kumar',  'childId': 'SKT-C-0001', 'age': 12, 'centre': 'Sulibele',  'since': 'Jul 2022', 'amount': '₹18,000 / yr', 'status': 'Active'},
          ]
        : <Map<String, dynamic>>[];

    if (children.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.child_care_outlined, size: 44, color: _onSurface3),
        const SizedBox(height: 12),
        const Text('No children sponsored', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _onSurface3)),
        const SizedBox(height: 6),
        const Text('This donor has not sponsored any child yet.', style: TextStyle(fontSize: 13, color: _onSurface3)),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(color: _brand600, borderRadius: BorderRadius.circular(14)),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.add, color: Colors.white, size: 18),
            SizedBox(width: 6),
            Text('Add Sponsor', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
          ]),
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
            child: Text('${children.length} active', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _brand600)),
          ),
        ]),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () {},
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
        ...children.map((child) {
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

// ── achievements tab ──────────────────────────────────────────────────
class _Ach {
  _Ach({required this.title, required this.date, required this.desc});
  final String title, date, desc;
}

// persists across navigation
final _donorAchievements = <String, List<_Ach>>{};

class _AchievementsTab extends StatefulWidget {
  const _AchievementsTab({required this.donorId});
  final String donorId;
  @override
  State<_AchievementsTab> createState() => _AchievementsTabState();
}

class _AchievementsTabState extends State<_AchievementsTab> {
  List<_Ach> get _list => _donorAchievements.putIfAbsent(widget.donorId, () => []);

  void _openAddSheet() {
    final titleCtrl = TextEditingController();
    final descCtrl  = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Add Achievement', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: titleCtrl,
            decoration: InputDecoration(
              labelText: 'Title',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: descCtrl,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Description',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _brand600, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            onPressed: () {
              if (titleCtrl.text.trim().isEmpty) return;
              setState(() {
                _list.add(_Ach(
                  title: titleCtrl.text.trim(),
                  date: _fmtDate(DateTime.now().toIso8601String()),
                  desc: descCtrl.text.trim(),
                ));
              });
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _list;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
        child: Row(children: [
          Text('${list.length} Achievement${list.length == 1 ? '' : 's'}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _onSurface2)),
          const Spacer(),
          GestureDetector(
            onTap: _openAddSheet,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(color: _brand600, borderRadius: BorderRadius.circular(10)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add, color: Colors.white, size: 16),
                SizedBox(width: 4),
                Text('Add', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
              ]),
            ),
          ),
        ]),
      ),
      if (list.isEmpty)
        Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.emoji_events_outlined, size: 44, color: _onSurface3),
          const SizedBox(height: 12),
          const Text('No achievements yet', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _onSurface3)),
          const SizedBox(height: 6),
          const Text('Tap + to log an achievement', style: TextStyle(fontSize: 13, color: _onSurface3)),
        ])))
      else
        Expanded(child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 40),
          physics: const BouncingScrollPhysics(),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final a = list[i];
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _border),
                boxShadow: const [BoxShadow(color: Color(0x080D2822), blurRadius: 6, offset: Offset(0, 2))],
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: _brand100, borderRadius: BorderRadius.circular(12)),
                  child: const Center(child: Icon(Icons.emoji_events_outlined, color: _brand600, size: 20)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(a.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _onSurface1)),
                  const SizedBox(height: 3),
                  Text(a.date, style: const TextStyle(fontSize: 12, color: _onSurface3, fontWeight: FontWeight.w500)),
                  if (a.desc.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(a.desc, style: const TextStyle(fontSize: 13, color: _onSurface2, height: 1.45)),
                  ],
                ])),
              ]),
            );
          },
        )),
    ]);
  }
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
