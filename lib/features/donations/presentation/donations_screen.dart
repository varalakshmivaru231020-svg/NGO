import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import 'receipt_generator.dart';

const _brand700 = Color(0xFFE07C1F);
const _brand600 = Color(0xFFFF9933);
const _brand100 = Color(0xFFFFE8CC);
const _amber600 = Color(0xFFE0921A);
const _coral500 = Color(0xFFF2685E);
const _violet500 = Color(0xFF7C6CF0);
const _sky500 = Color(0xFF2D9CDB);
const _green500 = Color(0xFF14A98C);
const _green100 = Color(0xFFD0F2E8);
const _amber100 = Color(0xFFFFF1D6);

String _inr(int n) => '₹${NumberFormat("#,##,###","en_IN").format(n)}';
String _inrC(int n) {
  if (n >= 100000) return '₹${(n / 100000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}L';
  if (n >= 1000) return '₹${(n / 1000).round()}K';
  return '₹$n';
}

Color _avColor(String seed) {
  final p = [_brand600, const Color(0xFFF6A723), _violet500, _sky500, _coral500, _green500];
  int h = 0;
  for (int i = 0; i < seed.length; i++) { h = ((h * 31) + seed.codeUnitAt(i)) & 0xFFFFFFFF; }
  return p[h % p.length];
}
String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  return ((parts[0].isNotEmpty ? parts[0][0] : '') + (parts.length > 1 && parts[1].isNotEmpty ? parts[1][0] : '')).toUpperCase();
}

const _typeInfo = {
  'Education Fund':    (_violet500, Icons.school_outlined),
  'Child Sponsorship': (_brand600,  Icons.favorite_outline),
  'Healthcare':        (_coral500,  Icons.medical_services_outlined),
  'General Donation':  (_sky500,    Icons.account_balance_wallet_outlined),
  'Food & Nutrition':  (_amber600,  Icons.restaurant_outlined),
  'Infrastructure':    (Color(0xFF5BAE8A), Icons.business_outlined),
};

const _modeLabels = {
  'UPI': 'UPI',
  'BANK_TRANSFER': 'Bank Transfer',
  'CASH': 'Cash',
  'CHEQUE': 'Cheque',
  'PAYMENT_LINK': 'Payment Link',
  'CARD': 'Card',
};

// In-memory store: survives navigation, cleared on hot-restart
final demoLocalDonations = <Map<String, dynamic>>[];

class _Donation {
  _Donation({required this.id, required this.donorId, required this.name, required this.amount,
    required this.type, required this.method, required this.receipt, required this.date,
    required this.status, required this.attach,
    this.donorPhone = '', this.donorCity = '', this.donorPan = '', this.donorEmail = '',
    this.donorAddress = '', this.donorState = '', this.donorPincode = '', this.donorCountry = '',
    this.reference = '', this.entryDate = '', this.notes = ''});
  final String id, donorId, name, type, method, receipt, date, status;
  final int amount, attach;
  final String donorPhone, donorCity, donorPan;
  final String donorEmail, donorAddress, donorState, donorPincode, donorCountry;
  final String reference;
  // Description typed while recording the donation — printed on the invoice.
  final String notes;
  // When the record was ENTERED into the system (createdAt) — shown on the
  // list card. `date` stays the actual donation date and prints on the invoice.
  final String entryDate;

  factory _Donation.fromApi(Map<String, dynamic> j) {
    final donor = j['donor'] as Map<String, dynamic>? ?? {};
    final type  = j['type']  as Map<String, dynamic>? ?? {};
    final rawDate = j['date'] as String? ?? '';
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    String formattedDate = rawDate;
    try {
      final dt = DateTime.parse(rawDate).toLocal();
      formattedDate = '${dt.day.toString().padLeft(2,'0')} ${m[dt.month-1]} ${dt.year}';
    } catch (_) {}
    String formattedEntry = '';
    try {
      final dt = DateTime.parse(j['createdAt'] as String? ?? '').toLocal();
      formattedEntry = '${dt.day.toString().padLeft(2,'0')} ${m[dt.month-1]} ${dt.year}';
    } catch (_) {}
    final rawMode = j['paymentMode'] as String? ?? 'CASH';
    final rawStatus = j['status'] as String? ?? 'COMPLETED';
    return _Donation(
      id:       j['id']       as String? ?? '',
      donorId:  donor['id']   as String? ?? '',
      name:     donor['name'] as String? ?? 'Unknown',
      donorPhone: donor['mobile'] as String? ?? '',
      donorCity:  donor['city']   as String? ?? '',
      donorPan:   donor['pan']    as String? ?? '',
      donorEmail:   donor['email']   as String? ?? '',
      donorAddress: donor['address'] as String? ?? '',
      donorState:   donor['state']   as String? ?? '',
      donorPincode: donor['pincode'] as String? ?? '',
      donorCountry: donor['country'] as String? ?? '',
      amount:   j['amount']   as int?    ?? 0,
      type:     type['label'] as String? ?? 'General Donation',
      method:   _modeLabels[rawMode] ?? rawMode,
      receipt:  j['receiptNo'] as String? ?? '',
      date:     formattedDate,
      entryDate: formattedEntry,
      status:   rawStatus == 'COMPLETED' ? 'Received' : rawStatus,
      attach:   0,
      reference: j['reference'] as String? ?? '',
      notes:     j['notes'] as String? ?? '',
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
class DonationsScreen extends StatefulWidget {
  const DonationsScreen({super.key});
  @override
  State<DonationsScreen> createState() => _DonationsScreenState();
}

class _DonationsScreenState extends State<DonationsScreen> {
  String _filter = 'All';
  List<_Donation> _donations = [];
  bool _loading = true;
  String? _error;
  // Server-side search (donor name / receipt no.) with a small debounce so we
  // don't fire a request per keystroke.
  final _searchCtrl = TextEditingController();
  String _search = '';
  Timer? _searchDebounce;

  void _onSearchChanged(String v) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      setState(() => _search = v.trim());
      _load();
    });
  }
  // Real donation types from the backend — falls back to _typeInfo's keys
  // (below) only until this loads, so newly added categories (Settings >
  // Donation Types) show up as filter chips without a hardcoded list to update.
  List<String> _typeLabels = [];

  Future<void> _loadTypes() async {
    try {
      final r = await apiClient.get('/donations/types');
      final inner = r['data'];
      final list = inner is List ? inner : (inner is Map ? (inner['data'] as List? ?? const []) : const []);
      final labels = list.whereType<Map>()
          .map((m) => m['label'] as String? ?? '')
          .where((s) => s.isNotEmpty)
          .toList();
      if (mounted && labels.isNotEmpty) setState(() => _typeLabels = labels);
    } catch (_) {}
  }

  @override
  void initState() {
    super.initState();
    _load();
    _loadTypes();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  // No demo donations — the list reflects only real backend data.
  static final _mockData = <Map<String, dynamic>>[];

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final r = await apiClient.get('/donations', params: {
        'limit': '50', 'page': '1',
        if (_search.isNotEmpty) 'search': _search,
      });
      final inner = r['data'];
      List<dynamic> list;
      if (inner is Map) {
        list = inner['data'] as List<dynamic>? ?? [];
      } else if (inner is List) {
        list = inner;
      } else {
        list = [];
      }
      // Backend is the source of truth even when empty (clean DB = empty list).
      final apiDonations = list.map((j) => _Donation.fromApi(j as Map<String, dynamic>)).toList();
      // The logged-in user's own submissions awaiting approval — shown at the
      // top with a "Pending Approval" badge (excluded from the totals).
      final pending = await _loadMyPending();
      final localDonations = demoLocalDonations.map(_Donation.fromApi).toList();
      final seenReceipts = apiDonations.map((d) => d.receipt.toLowerCase().trim()).toSet();
      final uniqueLocal = localDonations.where((d) => !seenReceipts.contains(d.receipt.toLowerCase().trim())).toList();
      if (mounted) {
        setState(() {
          _donations = [...pending, ...uniqueLocal, ...apiDonations];
          _loading = false;
        });
      }
      return;
    } catch (_) {}
    // Backend unreachable → demo/mock so the app still works offline.
    if (!mounted) return;
    setState(() {
      final mockDonations = _mockData.map(_Donation.fromApi).toList();
      final localDonations = demoLocalDonations.map(_Donation.fromApi).toList();

      final seenReceipts = mockDonations.map((d) => d.receipt.toLowerCase().trim()).toSet();
      final uniqueLocal = localDonations.where((d) => !seenReceipts.contains(d.receipt.toLowerCase().trim())).toList();

      _donations = [...uniqueLocal, ...mockDonations];
      // Surface the failure — the "Could not load" UI existed but was never
      // reachable because _error was never assigned.
      if (_donations.isEmpty) _error = 'Could not load donations';
      _loading = false;
    });
  }

  /// The current user's own submissions awaiting Super-Admin approval.
  /// Backend-driven (`GET /approvals/mine`) so they survive reloads and vanish
  /// once approved/rejected. Rendered with a "Pending Approval" status and
  /// excluded from the collected totals.
  Future<List<_Donation>> _loadMyPending() async {
    try {
      final r = await apiClient.get('/approvals/mine');
      final inner = r['data'];
      final reqs = inner is List
          ? inner
          : (inner is Map ? (inner['data'] as List<dynamic>? ?? const []) : const []);
      final donationReqs = reqs.whereType<Map<String, dynamic>>().where((q) =>
          (q['module'] as String?)?.toLowerCase() == 'donations' &&
          (q['action'] as String?)?.toUpperCase() == 'CREATE' &&
          (q['status'] as String?)?.toUpperCase() == 'PENDING').toList();
      if (donationReqs.isEmpty) return const [];

      // The stored payload only has donorId/typeId (extra fields are stripped by
      // the DTO) — resolve them to display names/labels.
      final donorNames = <String, String>{};
      final typeLabels = <String, String>{};
      try {
        final dr = await apiClient.get('/donors', params: {'limit': '100', 'page': '1'});
        final di = dr['data'];
        final dl = di is Map ? (di['data'] as List<dynamic>? ?? const []) : (di is List ? di : const []);
        for (final d in dl.whereType<Map<String, dynamic>>()) {
          donorNames[d['id'] as String? ?? ''] = d['name'] as String? ?? 'Unknown';
        }
      } catch (_) {}
      try {
        final tr = await apiClient.get('/donations/types');
        final ti = tr['data'];
        final tl = ti is Map ? (ti['data'] as List<dynamic>? ?? const []) : (ti is List ? ti : const []);
        for (final t in tl.whereType<Map<String, dynamic>>()) {
          typeLabels[t['id'] as String? ?? ''] = t['label'] as String? ?? '';
        }
      } catch (_) {}

      const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return donationReqs.map((q) {
        final payload = (q['payload'] as Map?)?.cast<String, dynamic>() ?? const {};
        final donorId = payload['donorId'] as String? ?? '';
        final typeId  = payload['typeId'] as String? ?? '';
        final rawMode = payload['paymentMode'] as String? ?? 'CASH';
        String date = '';
        try {
          final dt = DateTime.parse(q['createdAt'] as String? ?? '').toLocal();
          date = '${dt.day.toString().padLeft(2,'0')} ${m[dt.month-1]} ${dt.year}';
        } catch (_) {}
        return _Donation(
          id:      'pending-${q['id']}',
          donorId: donorId,
          name:    donorNames[donorId] ?? 'Unknown',
          amount:  (payload['amount'] as num?)?.toInt() ?? 0,
          type:    typeLabels[typeId] ?? 'General Donation',
          method:  _modeLabels[rawMode] ?? rawMode,
          receipt: '',
          date:    date,
          status:  'Pending Approval',
          attach:  0,
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  List<String> get _types => ['All', ...(_typeLabels.isNotEmpty ? _typeLabels : _typeInfo.keys)];

  List<_Donation> get _filtered =>
    _filter == 'All' ? _donations : _donations.where((d) => d.type == _filter).toList();

  // Real (recorded) donations only — pending-approval submissions are shown in
  // the list but excluded from the collected totals.
  List<_Donation> get _real => _donations.where((d) => d.status != 'Pending Approval').toList();

  int get _monthTotal => _real.fold(0, (s, d) => s + d.amount);
  int get _uniqueDonors => _real.map((d) => d.donorId).toSet().length;
  int get _avgGift => _real.isEmpty ? 0 : _monthTotal ~/ _real.length;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;

    return Scaffold(
      body: Column(children: [
        Container(color: context.headerBg, padding: EdgeInsets.fromLTRB(18, top + 14, 18, 14),
          child: Column(children: [
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Donations', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                Text('${_real.length} donations', style: TextStyle(fontSize: 13, color: context.textSub, fontWeight: FontWeight.w600)),
              ])),
              GestureDetector(
                onTap: () => context.go('/donations/new'),
                child: Container(width: 44, height: 44, decoration: BoxDecoration(color: _brand600, borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.add_rounded, color: Colors.white, size: 24))),
            ]),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFFE07C1F), Color(0xFFFF9933)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.all(Radius.circular(20)),
                boxShadow: [BoxShadow(color: Color(0x400B6E5D), blurRadius: 12, offset: Offset(0, 5))],
              ),
              child: Column(children: [
                Row(children: [
                  const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Collected this month', style: TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w600)),
                    SizedBox(height: 3),
                  ]),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => context.go('/payment-links'),
                    child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(10)),
                      child: const Row(children: [
                        Icon(Icons.link_rounded, color: Colors.white70, size: 14),
                        SizedBox(width: 5),
                        Text('Payment Link', style: TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700)),
                      ]))),
                ]),
                Align(alignment: Alignment.centerLeft, child: Text(_inr(_monthTotal), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.8))),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: _SumStat('Donations', '${_real.length}')),
                  Container(width: 1, height: 34, color: Colors.white24),
                  Expanded(child: _SumStat('Avg Gift', _inrC(_avgGift))),
                  Container(width: 1, height: 34, color: Colors.white24),
                  Expanded(child: _SumStat('Donors', '$_uniqueDonors')),
                ]),
              ]),
            ),
            const SizedBox(height: 12),
            // Search by donor name or receipt number (server-side)
            Container(
              decoration: BoxDecoration(color: context.scaffoldBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: context.border)),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _onSearchChanged,
                style: const TextStyle(fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Search by donor name or receipt no…',
                  hintStyle: TextStyle(fontSize: 13, color: context.textHint),
                  prefixIcon: Icon(Icons.search_rounded, size: 20, color: context.textHint),
                  suffixIcon: _search.isEmpty ? null : IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () { _searchCtrl.clear(); _onSearchChanged(''); },
                  ),
                  border: InputBorder.none, isDense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(height: 36, child: ListView(scrollDirection: Axis.horizontal,
              children: _types.map((t) {
                final active = _filter == t;
                final info = _typeInfo[t];
                final color = info?.$1 ?? _brand600;
                return Padding(padding: const EdgeInsets.only(right: 8), child: GestureDetector(
                  onTap: () => setState(() => _filter = t),
                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(color: active ? color.withValues(alpha: 0.12) : context.cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: active ? color : context.border)),
                    child: Row(children: [
                      if (info != null) ...[Icon(info.$2, size: 13, color: active ? color : context.textHint), const SizedBox(width: 5)],
                      Text(t, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: active ? color : context.textSub)),
                    ]))));
              }).toList())),
          ])),

        Expanded(child: _buildBody()),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/donations/new'),
        backgroundColor: _brand600,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Donation', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _brand600));
    }
    if (_error != null) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.wifi_off_outlined, size: 48, color: _coral500),
        const SizedBox(height: 12),
        Text('Could not load donations', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.textPrimary)),
        const SizedBox(height: 4),
        Text('Make sure the backend is running', style: TextStyle(fontSize: 13, color: context.textSub)),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _load,
          icon: const Icon(Icons.refresh),
          label: const Text('Retry'),
          style: ElevatedButton.styleFrom(backgroundColor: _brand600, foregroundColor: Colors.white),
        ),
      ]));
    }
    final items = _filtered;
    if (items.isEmpty) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.receipt_long_outlined, size: 48, color: context.textHint),
        const SizedBox(height: 12),
        Text('No donations found', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: context.textHint)),
      ]));
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: _brand600,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 100),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, i) => _DonationCard(d: items[i]),
      ),
    );
  }
}

class _SumStat extends StatelessWidget {
  const _SumStat(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
    Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
  ]);
}

class _DonationCard extends StatelessWidget {
  const _DonationCard({required this.d});
  final _Donation d;

  @override
  Widget build(BuildContext context) {
    final info = _typeInfo[d.type];
    final typeColor = info?.$1 ?? _brand600;
    final typeIcon = info?.$2 ?? Icons.account_balance_wallet_outlined;

    return Container(
      decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: context.border),
        boxShadow: const [BoxShadow(color: Color(0x080D2822), blurRadius: 6, offset: Offset(0, 2))]),
      child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(14, 12, 14, 10), child: Row(children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(color: typeColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(typeIcon, color: typeColor, size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(d.name, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, height: 1, color: context.textPrimary)),
            const SizedBox(height: 4),
            Row(children: [
              Flexible(child: Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: typeColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                child: Text(d.type, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: typeColor), overflow: TextOverflow.ellipsis))),
              const SizedBox(width: 6),
              Flexible(child: Text(d.method, style: TextStyle(fontSize: 11.5, color: context.textHint, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
            ]),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(_inr(d.amount), style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: _brand700)),
            const SizedBox(height: 3),
            // Entry date (when it was added) — the invoice carries the actual
            // donation date. Falls back to the donation date for older rows.
            Text(d.entryDate.isNotEmpty ? d.entryDate : d.date,
                style: TextStyle(fontSize: 11.5, color: context.textHint, fontWeight: FontWeight.w500)),
          ]),
        ])),
        Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 10), child: Column(children: [
          _DashedDivider(borderColor: context.border),
          const SizedBox(height: 8),
          LayoutBuilder(builder: (_, constraints) {
            final narrow = constraints.maxWidth < 320;
            return Row(children: [
            if (!narrow) Expanded(child: Text(d.receipt, style: TextStyle(fontSize: 11.5, color: context.textHint, fontWeight: FontWeight.w600, letterSpacing: 0.2), overflow: TextOverflow.ellipsis)),
            if (!narrow) const SizedBox(width: 6),
            // View Invoice button — only for recorded donations (a pending
            // submission has no receipt/invoice until it's approved).
            if (d.status == 'Received') ...[
              GestureDetector(
                onTap: () => showReceiptSheet(context, DonationReceipt(
                  receiptNo:    d.receipt,
                  donorName:    d.name,
                  donorPhone:   d.donorPhone,
                  donorCity:    d.donorCity,
                  donorPan:     d.donorPan,
                  donorEmail:   d.donorEmail,
                  donorAddress: d.donorAddress,
                  donorState:   d.donorState,
                  donorPincode: d.donorPincode,
                  donorCountry: d.donorCountry,
                  donationType: d.type,
                  amount:       d.amount,
                  paymentMode:  d.method,
                  date:         d.date,
                  taxExemption: true,
                  reference:    d.reference,
                  notes:        d.notes,
                )),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: _brand100,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: _brand600.withValues(alpha: 0.25)),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.receipt_long_outlined, size: 11, color: _brand600),
                    SizedBox(width: 4),
                    Text('Invoice', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: _brand600)),
                  ]),
                ),
              ),
              const SizedBox(width: 6),
            ] else
              const Spacer(),
            Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(color: d.status == 'Received' ? _green100 : _amber100.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(7)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(d.status == 'Received' ? Icons.check_circle_outline : Icons.schedule_outlined, size: 11, color: d.status == 'Received' ? _green500 : _amber600),
                const SizedBox(width: 4),
                Text(d.status, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: d.status == 'Received' ? _green500 : _amber600)),
              ])),
          ]);
          }),
        ])),
      ]),
    );
  }
}

class _DashedDivider extends StatelessWidget {
  const _DashedDivider({required this.borderColor});
  final Color borderColor;
  @override
  Widget build(BuildContext context) => CustomPaint(size: const Size(double.infinity, 1), painter: _DashPainter(borderColor: borderColor));
}

class _DashPainter extends CustomPainter {
  const _DashPainter({required this.borderColor});
  final Color borderColor;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = borderColor..strokeWidth = 1;
    double x = 0;
    while (x < size.width) { canvas.drawLine(Offset(x, 0), Offset(x + 4, 0), paint); x += 8; }
  }
  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}
