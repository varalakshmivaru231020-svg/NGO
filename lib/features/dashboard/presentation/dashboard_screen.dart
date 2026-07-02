import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/auth/role_auth.dart';
import '../../../core/network/api_client.dart';
import '../../notifications/notification_store.dart';
import '../../settings/profile_store.dart';
import '../../donors/presentation/donors_screen.dart' show demoLocalDonors;
import '../../donations/presentation/donations_screen.dart' show demoLocalDonations;
import '../../students/presentation/students_screen.dart' show demoLocalStudents;

// ── colours ───────────────────────────────────────────────────────────
const _brand700 = Color(0xFF0B6E5D);
const _brand600 = Color(0xFF0E8C76);
const _brand500 = Color(0xFF14A98C);
const _brand100 = Color(0xFFD6F3EC);
const _amber600 = Color(0xFFE0921A);
const _amber100 = Color(0xFFFFF1D6);
const _coral500 = Color(0xFFF2685E);
const _coral100 = Color(0xFFFFE3DF);
const _violet500 = Color(0xFF7C6CF0);
const _violet100 = Color(0xFFE7E3FD);
const _sky500 = Color(0xFF2D9CDB);
const _sky100 = Color(0xFFDCEFFB);

// ── data ──────────────────────────────────────────────────────────────
const _trend7M = [
  MapEntry('Dec', 410.0), MapEntry('Jan', 520.0), MapEntry('Feb', 480.0),
  MapEntry('Mar', 690.0), MapEntry('Apr', 575.0), MapEntry('May', 740.0), MapEntry('Jun', 155.0),
];
const _trend1Y = [
  MapEntry('Jul', 320.0), MapEntry('Aug', 380.0), MapEntry('Sep', 290.0),
  MapEntry('Oct', 450.0), MapEntry('Nov', 480.0), MapEntry('Dec', 410.0),
  MapEntry('Jan', 520.0), MapEntry('Feb', 480.0), MapEntry('Mar', 690.0),
  MapEntry('Apr', 575.0), MapEntry('May', 740.0), MapEntry('Jun', 155.0),
];
const _typeSplit = [
  _TypeSlice('Education', 42, Color(0xFF7C6CF0)),
  _TypeSlice('General Fund', 24, Color(0xFF14A98C)),
  _TypeSlice('Medical', 16, Color(0xFFF2685E)),
  _TypeSlice('Food', 11, Color(0xFFF6A723)),
  _TypeSlice('Child Sponsorship', 7, Color(0xFF0E8C76)),
];
final _recentDonations = [
  _Donation('Priya Sharma',   'Child Sponsorship', 'UPI',          18000, '04 Jun'),
  _Donation('Sanjay Gupta',   'Education',         'Bank Transfer', 75000, '04 Jun'),
  _Donation('Vikram Singh',   'Medical',           'UPI',          30000, '03 Jun'),
  _Donation('Arjun Mehta',    'General Fund',      'Payment Link', 22000, '31 May'),
];
const _typeColors = {
  'Education':         Color(0xFF7C6CF0),
  'Child Sponsorship': Color(0xFF0E8C76),
  'Medical':           Color(0xFFF2685E),
  'General Fund':      Color(0xFF14A98C),
  'Food':              Color(0xFFF6A723),
  'Infrastructure':    Color(0xFF2D9CDB),
};
const _modeLabels = {
  'UPI': 'UPI',
  'BANK_TRANSFER': 'Bank Transfer',
  'CASH': 'Cash',
  'CHEQUE': 'Cheque',
  'PAYMENT_LINK': 'Payment Link',
  'CARD': 'Card',
};

// ── helpers ───────────────────────────────────────────────────────────
String _inr(int n, {bool compact = false}) {
  if (compact) {
    if (n >= 10000000) return '₹${(n / 10000000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}Cr';
    if (n >= 100000)   return '₹${(n / 100000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}L';
    if (n >= 1000)     return '₹${(n / 1000).round()}K';
    return '₹$n';
  }
  return '₹${NumberFormat('#,##,###', 'en_IN').format(n)}';
}

Color _avColor(String seed) {
  final palette = [_brand600, const Color(0xFFF6A723), _violet500, _sky500,
    const Color(0xFFEC5B8B), _coral500, _brand500, const Color(0xFF5BAE8A)];
  int h = 0;
  for (int i = 0; i < seed.length; i++) h = ((h * 31) + seed.codeUnitAt(i)) & 0xFFFFFFFF;
  return palette[h % palette.length];
}

String _initials(String name) {
  final p = name.trim().split(RegExp(r'\s+'));
  return ((p[0].isNotEmpty ? p[0][0] : '') + (p.length > 1 && p[1].isNotEmpty ? p[1][0] : '')).toUpperCase();
}

// ── models ────────────────────────────────────────────────────────────
class _TypeSlice {
  const _TypeSlice(this.label, this.value, this.color);
  final String label;
  final int value;
  final Color color;
}

class _Donation {
  const _Donation(this.name, this.type, this.method, this.amount, this.date);
  final String name, type, method, date;
  final int amount;
}

// ══════════════════════════════════════════════════════════════════════
// SCREEN
// ══════════════════════════════════════════════════════════════════════
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});
  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String _period = '7M';

  // Live counts from the backend so the dashboard reflects real data.
  int? _students, _donors, _offices, _raised, _todayRaised;

  List<_Donation> _dynamicRecentDonations = [];
  List<_TypeSlice> _dynamicTypeSlices = [];
  List<MapEntry<String, double>> _dynamicTrend7M = [];
  List<MapEntry<String, double>> _dynamicTrend1Y = [];
  int _totalDonationsAmount = 0;

  @override
  void initState() {
    super.initState();
    _loadCounts();
  }

  Future<void> _loadCounts() async {
    Future<int?> count(String path) async {
      try {
        // Backend caps limit at 100; use the server's reported total for an
        // accurate count regardless of page size.
        final r = await apiClient.get(path, params: {'limit': '100', 'page': '1'});
        final meta = r['meta'];
        if (meta is Map && meta['total'] is int) return meta['total'] as int;
        final inner = r['data'];
        final list = inner is List ? inner : (inner is Map ? (inner['data'] as List? ?? const []) : const []);
        return list.length;
      } catch (_) { return null; }
    }
    
    final sCount = await count('/students');
    final dCount = await count('/donors');
    final oCount = await count('/offices');
    
    int? raised = 0;
    int? today = 0;
    List<_Donation> recent = [];
    List<_TypeSlice> slices = [];
    List<MapEntry<String, double>> trend7M = [];
    List<MapEntry<String, double>> trend1Y = [];
    int totalAmt = 0;

    try {
      final r = await apiClient.get('/donations', params: {'limit': '100', 'page': '1'});
      final inner = r['data'];
      final list = inner is List ? inner : (inner is Map ? (inner['data'] as List? ?? const []) : const []);
      
      // Map local donations to similar format
      final localDonationsMapped = demoLocalDonations.map((j) {
        final donor = j['donor'] as Map? ?? {};
        final type = j['type'] as Map? ?? {};
        return {
          'amount': j['amount'],
          'date': j['date'],
          'createdAt': j['date'],
          'paymentMode': j['paymentMode'],
          'donor': {'name': donor['name']},
          'type': {'label': type['label']},
          'receiptNo': j['receiptNo'],
        };
      }).toList();

      final allDonationsRaw = [...localDonationsMapped, ...list];
      final seenReceipts = <String>{};
      final uniqueDonationsRaw = <Map>[];
      for (final item in allDonationsRaw) {
        final rec = '${item['receiptNo'] ?? ''}'.toLowerCase().trim();
        if (rec.isNotEmpty && seenReceipts.contains(rec)) continue;
        if (rec.isNotEmpty) seenReceipts.add(rec);
        uniqueDonationsRaw.add(item);
      }

      // 1. Calculate raised and todayRaised
      final now = DateTime.now();
      for (final e in uniqueDonationsRaw) {
        final amt = (e['amount'] as num?)?.toInt() ?? 0;
        raised = raised! + amt;
        final rawDt = '${e['date'] ?? e['createdAt'] ?? ''}';
        final dt = DateTime.tryParse(rawDt)?.toLocal();
        if (dt != null && dt.year == now.year && dt.month == now.month && dt.day == now.day) {
          today = today! + amt;
        }
      }

      // 2. Format date for recent donations
      String formatDate(String rawDate) {
        try {
          final dt = DateTime.parse(rawDate).toLocal();
          const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
          return '${dt.day.toString().padLeft(2,'0')} ${m[dt.month-1]}';
        } catch (_) {
          return 'Recent';
        }
      }

      // 3. Populate recent donations list
      for (final e in uniqueDonationsRaw.take(4)) {
        final donor = e['donor'] as Map? ?? {};
        final type = e['type'] as Map? ?? {};
        final name = donor['name'] as String? ?? 'Unknown';
        final tLabel = type['label'] as String? ?? 'General Donation';
        final method = _modeLabels[e['paymentMode']] ?? e['paymentMode'] as String? ?? 'Cash';
        final amt = (e['amount'] as num?)?.toInt() ?? 0;
        final rawDt = '${e['date'] ?? e['createdAt'] ?? ''}';
        recent.add(_Donation(name, tLabel, method, amt, formatDate(rawDt)));
      }

      // 4. Calculate donations by type
      final typeSums = <String, int>{};
      for (final e in uniqueDonationsRaw) {
        final type = e['type'] as Map? ?? {};
        final label = type['label'] as String? ?? 'General Fund';
        final amt = (e['amount'] as num?)?.toInt() ?? 0;
        typeSums[label] = (typeSums[label] ?? 0) + amt;
        totalAmt += amt;
      }
      
      Color getSliceColor(String label) {
        if (_typeColors.containsKey(label)) return _typeColors[label]!;
        if (label == 'Education Fund') return const Color(0xFF7C6CF0);
        if (label == 'Healthcare' || label == 'Medical') return const Color(0xFFF2685E);
        if (label == 'General Donation' || label == 'General Fund') return const Color(0xFF14A98C);
        if (label == 'Food & Nutrition' || label == 'Food') return const Color(0xFFF6A723);
        return _avColor(label);
      }

      if (totalAmt > 0) {
        final sortedTypes = typeSums.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        int otherAmt = 0;
        for (int i = 0; i < sortedTypes.length; i++) {
          final entry = sortedTypes[i];
          final pct = ((entry.value / totalAmt) * 100).round();
          if (i < 4) {
            slices.add(_TypeSlice(entry.key, pct, getSliceColor(entry.key)));
          } else {
            otherAmt += entry.value;
          }
        }
        if (otherAmt > 0) {
          final otherPct = ((otherAmt / totalAmt) * 100).round();
          slices.add(_TypeSlice('Other', otherPct, const Color(0xFF64748B)));
        }
      }

      // 5. Calculate donation trend
      List<MapEntry<String, double>> computeTrend(int monthsLimit) {
        final months = <DateTime>[];
        for (int i = monthsLimit - 1; i >= 0; i--) {
          months.add(DateTime(now.year, now.month - i, 1));
        }
        
        final monthLabels = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
        final monthlySums = {for (final m in months) m.month: 0.0};
        
        for (final e in uniqueDonationsRaw) {
          final rawDt = '${e['date'] ?? e['createdAt'] ?? ''}';
          final dt = DateTime.tryParse(rawDt)?.toLocal();
          if (dt != null) {
            for (final m in months) {
              if (dt.year == m.year && dt.month == m.month) {
                final amt = (e['amount'] as num?)?.toDouble() ?? 0.0;
                monthlySums[m.month] = monthlySums[m.month]! + (amt / 1000.0);
              }
            }
          }
        }
        
        return months.map((m) => MapEntry(monthLabels[m.month - 1], monthlySums[m.month] ?? 0.0)).toList();
      }

      trend7M = computeTrend(7);
      trend1Y = computeTrend(12);

    } catch (_) {}

    if (mounted) {
      setState(() {
        _students = sCount;
        _donors = dCount;
        _offices = oCount;
        _raised = raised;
        _todayRaised = today;
        _dynamicRecentDonations = recent;
        _dynamicTypeSlices = slices;
        _dynamicTrend7M = trend7M;
        _dynamicTrend1Y = trend1Y;
        _totalDonationsAmount = totalAmt;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Real backend data only — no demo fallback (a clean DB shows empty).
    final recentList = _dynamicRecentDonations;
    final slices = _dynamicTypeSlices;
    final t7M = _dynamicTrend7M;
    final t1Y = _dynamicTrend1Y;
    final hasDonations = _totalDonationsAmount > 0;

    return Scaffold(
      body: Column(
        children: [
          _BrandHeader(onNotif: () => context.go('/notifications'), raised: _raised, todayRaised: _todayRaised),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 18),
                  _kpiSection(context),
                  const SizedBox(height: 18),
                  _quickActions(context),
                  // Donation analytics — shown only when there are donations and
                  // the role can see them (no fake charts on an empty database).
                  if ((canAccess('donations') || canAccess('reports')) && hasDonations) ...[
                    const SizedBox(height: 18),
                    LayoutBuilder(builder: (_, c) {
                      final trend = _TrendCard(
                        period: _period, 
                        onPeriodChange: (p) => setState(() => _period = p), 
                        padded: c.maxWidth < 800,
                        trend7M: t7M,
                        trend1Y: t1Y,
                      );
                      if (c.maxWidth >= 800) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Expanded(child: trend),
                            const SizedBox(width: 14),
                            Expanded(child: _DonutCard(slices: slices, totalAmount: _totalDonationsAmount, padded: false)),
                          ]),
                        );
                      }
                      return Column(children: [
                        trend,
                        const SizedBox(height: 14),
                        _DonutCard(slices: slices, totalAmount: _totalDonationsAmount),
                      ]);
                    }),
                  ],
                  if (canAccess('donations')) ...[
                    const SizedBox(height: 18),
                    _recentSection(context, recentList),
                  ],
                  const SizedBox(height: 96),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── KPI section — 6 cards, single row on desktop, wraps on mobile ──
  Widget _kpiSection(BuildContext ctx) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 18),
    child: LayoutBuilder(builder: (_, constraints) {
      final wide = constraints.maxWidth >= 800;
      // Each card is tagged with the module it belongs to; a card only shows if
      // the logged-in user can access that module (admins see everything).
      String n(int? v) => v?.toString() ?? '—';
      final all = <({String module, _KPICard card})>[
        (module: 'donations', card: _KPICard(label: 'Total Raised',      value: _raised != null ? _inr(_raised!, compact: true) : '—', icon: Icons.account_balance_wallet_outlined, fg: _amber600,  bg: _amber100,  onTap: () => ctx.go('/donations'), emphasis: true)),
        (module: 'donors',    card: _KPICard(label: 'Total Donors',      value: n(_donors),   icon: Icons.people_outlined,                 fg: _brand600,  bg: _brand100,  onTap: () => ctx.go('/donors'),    emphasis: true)),
        (module: 'students',  card: _KPICard(label: 'Total Students',    value: n(_students), icon: Icons.school_outlined,                 fg: _violet500, bg: _violet100, onTap: () => ctx.go('/students'))),
        (module: 'offices',   card: _KPICard(label: 'Total Offices',     value: n(_offices),  icon: Icons.business_outlined,               fg: _sky500,    bg: _sky100,    onTap: () => ctx.go('/offices'))),
        (module: 'reminders', card: _KPICard(label: 'Birthdays Today',   value: '0',          icon: Icons.cake_outlined,                   fg: _coral500,  bg: _coral100,  onTap: () => ctx.go('/reminders'))),
        (module: 'reminders', card: _KPICard(label: 'Anniversary Today', value: '0',          icon: Icons.favorite_border,                 fg: _coral500,  bg: _coral100,  onTap: () => ctx.go('/reminders'))),
      ];
      final cards = all.where((c) => canAccess(c.module)).map((c) => c.card).toList();
      if (cards.isEmpty) return const SizedBox.shrink();
      // Up to 3 per row on desktop (2 on mobile). With only 1–2 cards (e.g. a
      // restricted role) they stay a sensible size, left-aligned, not stretched.
      final maxPerRow = wide ? 3 : 2;
      final perRow = cards.length < maxPerRow ? cards.length : maxPerRow;
      const gap = 12.0;
      double cardW = (constraints.maxWidth - gap * (perRow - 1)) / perRow;
      if (wide && cards.length < 3 && cardW > 360) cardW = 360;
      return Wrap(
        alignment: WrapAlignment.start,
        spacing: gap, runSpacing: gap,
        children: cards.map((c) => SizedBox(width: cardW, child: c)).toList(),
      );
    }),
  );

  // ── Quick Actions — create shortcuts ──────────────────────────────
  Widget _quickActions(BuildContext ctx) {
    const actions = [
      (icon: Icons.person_add_alt_1_outlined, label: 'Add Donor',    bg: _brand100,  fg: _brand600,  route: '/donors/new',    module: 'donors'),
      (icon: Icons.volunteer_activism_outlined, label: 'Add Donation', bg: _amber100, fg: _amber600,  route: '/donations/new', module: 'donations'),
      (icon: Icons.school_outlined,           label: 'Add Student',  bg: _violet100, fg: _violet500, route: '/students/new',  module: 'students'),
      (icon: Icons.link_rounded,              label: 'Payment Link', bg: _sky100,    fg: _sky500,    route: '/payment-links', module: 'payments'),
    ];
    // Only show actions the current user can access.
    final visible = actions.where((a) => canAccess(a.module)).toList();
    if (visible.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(padding: EdgeInsets.only(left: 2, bottom: 10),
          child: Text('Quick Actions', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800))),
        LayoutBuilder(builder: (_, c) {
          final maxPerRow = c.maxWidth >= 560 ? 4 : 2;
          final perRow = visible.length < maxPerRow ? visible.length : maxPerRow;
          const gap = 12.0;
          double w = (c.maxWidth - gap * (perRow - 1)) / perRow;
          if (c.maxWidth >= 560 && visible.length < 4 && w > 240) w = 240;
          return Wrap(alignment: WrapAlignment.start, spacing: gap, runSpacing: gap, children: visible.map((a) => SizedBox(
            width: w,
            child: GestureDetector(
              onTap: () => ctx.go(a.route),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 10),
                decoration: BoxDecoration(
                  color: ctx.cardBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: ctx.border),
                  boxShadow: const [BoxShadow(color: Color(0x0A0D2822), blurRadius: 8, offset: Offset(0, 3))],
                ),
                child: Column(children: [
                  Container(width: 46, height: 46,
                    decoration: BoxDecoration(color: a.bg, borderRadius: BorderRadius.circular(14)),
                    child: Icon(a.icon, color: a.fg, size: 23)),
                  const SizedBox(height: 10),
                  Text(a.label, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: ctx.textPrimary)),
                ]),
              ),
            ),
          )).toList());
        }),
      ]),
    );
  }

  // ── Reminders strip ───────────────────────────────────────────────
  Widget _remindersStrip(BuildContext ctx) => GestureDetector(
    onTap: () => ctx.go('/reminders'),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          Expanded(child: _ReminderChip(icon: Icons.cake_outlined, iconBg: _amber100, iconColor: _amber600, count: '2', label: 'Birthdays today')),
          const SizedBox(width: 10),
          Expanded(child: _ReminderChip(icon: Icons.favorite_border, iconBg: _coral100, iconColor: _coral500, count: '1', label: 'Anniversary today')),
        ],
      ),
    ),
  );

  // ── Recent Donations ──────────────────────────────────────────────
  Widget _recentSection(BuildContext ctx, List<_Donation> recentList) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Recent Donations', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, letterSpacing: -0.2)),
            TextButton(
              onPressed: () => ctx.go('/donations'),
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(44, 32)),
              child: Row(children: [
                Text('View all', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _brand600)),
                Icon(Icons.chevron_right, size: 15, color: _brand600),
              ]),
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: _card(
          ctx: ctx,
          child: recentList.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 26, horizontal: 16),
                child: Center(child: Text('No donations yet.', style: TextStyle(fontSize: 13.5, color: Color(0xFF5A6B67), fontWeight: FontWeight.w500))),
              )
            : Column(
                children: recentList.asMap().entries.map((e) {
                  final i = e.key; final d = e.value;
                  return _DonationTile(
                    donation: d,
                    showDivider: i < recentList.length - 1,
                    onTap: () {},
                  );
                }).toList(),
              ),
        ),
      ),
    ],
  );
}

// ══════════════════════════════════════════════════════════════════════
// BRAND HEADER
// ══════════════════════════════════════════════════════════════════════
class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.onNotif, this.raised, this.todayRaised});
  final VoidCallback onNotif;
  final int? raised, todayRaised;

  static String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning,';
    if (h < 17) return 'Good afternoon,';
    if (h < 21) return 'Good evening,';
    return 'Good night,';
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_brand700, _brand500],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.all(Radius.circular(28)),
        boxShadow: const [BoxShadow(color: Color(0x470B6E5D), blurRadius: 24, offset: Offset(0, 8))],
      ),
      margin: EdgeInsets.fromLTRB(12, top + 8, 12, 0),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // avatar + greeting + bell
            ValueListenableBuilder<ProfileData>(
              valueListenable: adminProfile,
              builder: (context, profile, _) {
                // Show the currently logged-in person: a role member sees their
                // own name + role; the admin sees the org profile.
                final member = currentLoggedInRole;
                final name = member?.name ?? profile.name;
                final photo = isAdmin ? profile.photoBytes : null;
                final roleLabel = member == null
                    ? null
                    : (member.roleName.isNotEmpty ? member.roleName : 'Team Member');
                return Row(children: [
                  _Avatar(name: name, size: 44, ring: true, image: photo, logoFallback: isAdmin),
                  const SizedBox(width: 12),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_greeting(), style: const TextStyle(fontSize: 12.5, color: Colors.white70, fontWeight: FontWeight.w500)),
                      Text(name, style: const TextStyle(fontSize: 17.5, color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: -0.2), overflow: TextOverflow.ellipsis),
                      if (roleLabel != null)
                        Text(roleLabel, style: const TextStyle(fontSize: 11.5, color: Colors.white70, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                    ],
                  )),
                  _NotifBtn(onTap: onNotif),
                ]);
              },
            ),

            // Today's Donations hero — only for roles that can see donations.
            if (canAccess('donations') || canAccess('reports')) ...[
              const SizedBox(height: 20),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: const [
                      Icon(Icons.account_balance_wallet_outlined, size: 15, color: Colors.white),
                      SizedBox(width: 6),
                      Text("Today's Donations", style: TextStyle(fontSize: 12.5, color: Colors.white, fontWeight: FontWeight.w600)),
                    ]),
                    const SizedBox(height: 4),
                    Text(_inr(todayRaised ?? 0), style: const TextStyle(fontSize: 36, color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: -1)),
                  ],
                )),
              ]),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: _StatPill(label: 'Total Raised', value: _inr(raised ?? 0, compact: true))),
                const SizedBox(width: 10),
                Expanded(child: _StatPill(label: "Today", value: _inr(todayRaised ?? 0, compact: true))),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}

class _NotifBtn extends StatelessWidget {
  const _NotifBtn({required this.onTap});
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: SizedBox(
      width: 42, height: 42,
      child: Stack(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), shape: BoxShape.circle),
          child: const Icon(Icons.notifications_outlined, color: Colors.white, size: 21),
        ),
        Positioned(top: 8, right: 9,
          child: ValueListenableBuilder<int>(
            valueListenable: unreadNotifCount,
            builder: (_, count, __) => count == 0 ? const SizedBox.shrink() : Container(
              width: 9, height: 9,
              decoration: BoxDecoration(color: _coral500, shape: BoxShape.circle, border: Border.all(color: _brand600, width: 2)),
            ),
          ),
        ),
      ]),
    ),
  );
}

class _StatPill extends StatelessWidget {
  const _StatPill({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 11.5, color: Colors.white70, fontWeight: FontWeight.w600)),
      const SizedBox(height: 2),
      Text(value, style: const TextStyle(fontSize: 17, color: Colors.white, fontWeight: FontWeight.w800)),
    ]),
  );
}

// ── Avatar ────────────────────────────────────────────────────────────
class _Avatar extends StatelessWidget {
  const _Avatar({required this.name, required this.size, this.ring = false, this.image, this.logoFallback = false});
  final String name;
  final double size;
  final bool ring;
  final Uint8List? image;
  final bool logoFallback; // show the foundation logo when there's no photo
  @override
  Widget build(BuildContext context) {
    final color = _avColor(name);
    return Container(
      width: size, height: size,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [color, Color.lerp(color, Colors.black, 0.22)!], begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: ring ? [const BoxShadow(color: Colors.white, blurRadius: 0, spreadRadius: 2), BoxShadow(color: color, blurRadius: 0, spreadRadius: 4)] : [],
      ),
      child: image != null
          ? Image.memory(image!, fit: BoxFit.cover, width: size, height: size)
          : logoFallback
              ? Container(color: Colors.white, child: Image.asset(brandLogoAsset, fit: BoxFit.cover, alignment: Alignment.centerLeft, width: size, height: size))
              : Center(
                  child: Text(_initials(name), style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * 0.36)),
                ),
    );
  }
}

// ── KPI Card ──────────────────────────────────────────────────────────
class _KPICard extends StatelessWidget {
  const _KPICard({required this.label, required this.value, required this.icon, required this.fg, required this.bg, required this.onTap, this.emphasis = false});
  final String label, value;
  final IconData icon;
  final Color fg, bg;
  final VoidCallback onTap;
  final bool emphasis;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
      decoration: BoxDecoration(
        color: emphasis ? fg.withValues(alpha: 0.07) : context.cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: emphasis ? fg.withValues(alpha: 0.35) : context.border, width: emphasis ? 1.5 : 1),
        boxShadow: const [BoxShadow(color: Color(0x0A0D2822), blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: fg, size: 24),
        ),
        const SizedBox(height: 14),
        Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: emphasis ? fg : context.textPrimary, height: 1)),
        const SizedBox(height: 6),
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.textSub)),
      ]),
    ),
  );
}

// ── Reminder chip ─────────────────────────────────────────────────────
class _ReminderChip extends StatelessWidget {
  const _ReminderChip({required this.icon, required this.iconBg, required this.iconColor, required this.count, required this.label});
  final IconData icon;
  final Color iconBg, iconColor;
  final String count, label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: context.cardBg, borderRadius: BorderRadius.circular(24),
      border: Border.all(color: context.border),
      boxShadow: const [BoxShadow(color: Color(0x0D0D2822), blurRadius: 10, offset: Offset(0, 4))],
    ),
    child: Row(children: [
      Container(width: 40, height: 40, decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: iconColor, size: 21)),
      const SizedBox(width: 11),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(count, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, height: 1)),
        const SizedBox(height: 3),
        Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: context.textSub)),
      ])),
    ]),
  );
}

// ── Trend Chart Card ──────────────────────────────────────────────────
class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.period, required this.onPeriodChange, required this.trend7M, required this.trend1Y, this.padded = true});
  final String period;
  final ValueChanged<String> onPeriodChange;
  final List<MapEntry<String, double>> trend7M, trend1Y;
  final bool padded;

  @override
  Widget build(BuildContext context) {
    final data = period == '7M' ? trend7M : trend1Y;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: padded ? 18 : 0),
      child: _card(
        ctx: context,
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Donation Trend', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
              const SizedBox(height: 1),
              Text('₹ collected per month', style: TextStyle(fontSize: 12, color: context.textSub, fontWeight: FontWeight.w600)),
            ]),
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(color: context.surface2, borderRadius: BorderRadius.circular(10)),
              child: Row(children: ['7M','1Y'].map((p) => GestureDetector(
                onTap: () => onPeriodChange(p),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                  decoration: BoxDecoration(
                    color: period == p ? context.cardBg : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: period == p ? const [BoxShadow(color: Color(0x150D2822), blurRadius: 3, offset: Offset(0, 1))] : [],
                  ),
                  child: Text(p, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: period == p ? _brand600 : context.textSub)),
                ),
              )).toList()),
            ),
          ]),
          const SizedBox(height: 8),
          SizedBox(
            height: 150,
            child: _TrendBarChart(data: data),
          ),
        ]),
      ),
    );
  }
}

class _TrendBarChart extends StatelessWidget {
  const _TrendBarChart({required this.data});
  final List<MapEntry<String, double>> data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(child: Text('No trend data available'));
    }
    final maxV = data.map((e) => e.value).reduce((a, b) => a > b ? a : b) * 1.15;
    // Narrower bars when more months are shown (1Y) so they don't crowd.
    final barWidth = data.length > 8 ? 12.0 : 20.0;
    return BarChart(BarChartData(
      minY: 0,
      maxY: maxV > 0 ? maxV : 10,
      alignment: BarChartAlignment.spaceAround,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: maxV > 0 ? maxV * 0.33 : 3,
        getDrawingHorizontalLine: (_) => FlLine(color: context.border, strokeWidth: 1, dashArray: [2, 5]),
      ),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        leftTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles:    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:  const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true,
          interval: 1,
          getTitlesWidget: (v, _) {
            final i = v.toInt();
            if (i < 0 || i >= data.length) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(data[i].key, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: context.textHint)),
            );
          },
        )),
      ),
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          getTooltipColor: (_) => const Color(0xFF15211E),
          tooltipRoundedRadius: 8,
          getTooltipItem: (group, _, rod, __) => BarTooltipItem(
            '₹${rod.toY.toStringAsFixed(0)}K',
            const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
          ),
        ),
      ),
      barGroups: data.asMap().entries.map((e) {
        final isLast = e.key == data.length - 1;
        return BarChartGroupData(
          x: e.key,
          barRods: [
            BarChartRodData(
              toY: e.value.value,
              width: barWidth,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: isLast
                    ? const [Color(0xFF14A98C), Color(0xFF0B6E5D)]
                    : const [Color(0xFF3FBFA6), Color(0xFF14A98C)],
              ),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: maxV > 0 ? maxV : 10,
                color: _brand600.withValues(alpha: 0.06),
              ),
            ),
          ],
        );
      }).toList(),
    ));
  }
}

// ── Donut Card ────────────────────────────────────────────────────────
class _DonutCard extends StatelessWidget {
  const _DonutCard({required this.slices, required this.totalAmount, this.padded = true});
  final List<_TypeSlice> slices;
  final int totalAmount;
  final bool padded;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.symmetric(horizontal: padded ? 18 : 0),
    child: _card(
      ctx: context,
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Donations by Type', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        Row(children: [
          SizedBox(
            width: 134, height: 134,
            child: Stack(alignment: Alignment.center, children: [
              PieChart(PieChartData(
                sections: slices.isEmpty
                    ? [PieChartSectionData(color: Colors.grey.shade300, value: 100, title: '', radius: 28)]
                    : slices.map((t) => PieChartSectionData(
                  color: t.color,
                  value: t.value.toDouble(),
                  title: '',
                  radius: 28,
                )).toList(),
                centerSpaceRadius: 43,
                sectionsSpace: 2,
                startDegreeOffset: -90,
              )),
              Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_inr(totalAmount, compact: true), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: -0.5, height: 1)),
                const SizedBox(height: 2),
                Text('this year', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: context.textSub)),
              ]),
            ]),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(
            mainAxisSize: MainAxisSize.min,
            children: slices.isEmpty 
              ? [const Text('No data available')]
              : slices.map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(color: t.color, borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 8),
                Expanded(child: Text(t.label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 4),
                Text('${t.value}%', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: context.textSub)),
              ]),
            )).toList(),
          )),
        ]),
      ]),
    ),
  );
}

// ── Donation tile ─────────────────────────────────────────────────────
class _DonationTile extends StatelessWidget {
  const _DonationTile({required this.donation, required this.showDivider, required this.onTap});
  final _Donation donation;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _typeColors[donation.type] ?? _brand600;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: showDivider ? BoxDecoration(border: Border(bottom: BorderSide(color: context.border))) : null,
        child: Row(children: [
          _Avatar(name: donation.name, size: 42),
          const SizedBox(width: 13),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(donation.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: -0.1, height: 1), overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Row(children: [
              Container(width: 7, height: 7, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 6),
              Flexible(child: Text('${donation.type} · ${donation.method}', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: context.textSub), overflow: TextOverflow.ellipsis)),
            ]),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(_inr(donation.amount), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _brand700)),
            const SizedBox(height: 2),
            Text(donation.date, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.textHint)),
          ]),
        ]),
      ),
    );
  }
}

// ── Shared card widget ────────────────────────────────────────────────
Widget _card({required BuildContext ctx, required Widget child, EdgeInsets? padding}) => Container(
  padding: padding,
  decoration: BoxDecoration(
    color: ctx.cardBg,
    borderRadius: BorderRadius.circular(24),
    border: Border.all(color: ctx.border),
    boxShadow: const [
      BoxShadow(color: Color(0x0F0D2822), blurRadius: 10, offset: Offset(0, 4)),
      BoxShadow(color: Color(0x0A0D2822), blurRadius: 24, offset: Offset(0, 10)),
    ],
  ),
  child: child,
);
