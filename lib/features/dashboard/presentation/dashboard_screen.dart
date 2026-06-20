import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _BrandHeader(onNotif: () => context.go('/notifications')),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 18),
                  _quickActionsSection(context),
                  const SizedBox(height: 18),
                  _kpiSection(context),
                  const SizedBox(height: 14),
                  _remindersStrip(context),
                  const SizedBox(height: 18),
                  _TrendCard(period: _period, onPeriodChange: (p) => setState(() => _period = p)),
                  const SizedBox(height: 14),
                  const _DonutCard(),
                  const SizedBox(height: 18),
                  _recentSection(context),
                  const SizedBox(height: 96),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Quick Actions ────────────────────────────────────────────────
  Widget _quickActionsSection(BuildContext ctx) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 18),
    child: IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _QA(label: 'Add Donation', icon: Icons.account_balance_wallet_outlined, bg: _brand100, fg: _brand600, onTap: () => ctx.go('/donations/new')),
          const SizedBox(width: 10),
          _QA(label: 'Add Donor',    icon: Icons.person_add_outlined,              bg: _violet100, fg: _violet500, onTap: () => ctx.go('/donors/new')),
          const SizedBox(width: 10),
          _QA(label: 'Pay Link',     icon: Icons.qr_code_2_outlined,               bg: _sky100,    fg: _sky500,    onTap: () => ctx.go('/payment-links')),
          const SizedBox(width: 10),
          _QA(label: 'Reminders',    icon: Icons.cake_outlined,                    bg: _amber100,  fg: _amber600,  onTap: () => ctx.go('/reminders')),
        ],
      ),
    ),
  );

  // ── KPI 2×2 ──────────────────────────────────────────────────────
  Widget _kpiSection(BuildContext ctx) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 18),
    child: GridView.count(
      crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.28,
      children: [
        _KPICard(label: 'Total Offices',  value: '4',      icon: Icons.business_outlined,              fg: _sky500,    bg: _sky100,    delta: null,   onTap: () {}),
        _KPICard(label: 'Total Donors',   value: '836',    icon: Icons.people_outlined,                fg: _brand600,  bg: _brand100,  delta: '+12',  onTap: () => ctx.go('/donors')),
        _KPICard(label: 'Total Students', value: '178',    icon: Icons.school_outlined,                fg: _violet500, bg: _violet100, delta: '+6',   onTap: () => ctx.go('/students')),
        _KPICard(label: 'Total Raised',   value: '₹56.1L', icon: Icons.account_balance_wallet_outlined, fg: _amber600,  bg: _amber100,  delta: '+8%',  onTap: () => ctx.go('/donations')),
      ],
    ),
  );

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
  Widget _recentSection(BuildContext ctx) => Column(
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
          child: Column(
            children: _recentDonations.asMap().entries.map((e) {
              final i = e.key; final d = e.value;
              return _DonationTile(
                donation: d,
                showDivider: i < _recentDonations.length - 1,
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
  const _BrandHeader({required this.onNotif});
  final VoidCallback onNotif;

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
            Row(children: [
              _Avatar(name: 'Farhan Ansari', size: 44, ring: true),
              const SizedBox(width: 12),
              const Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Good morning,', style: TextStyle(fontSize: 12.5, color: Colors.white70, fontWeight: FontWeight.w500)),
                  Text('Farhan Ansari',  style: TextStyle(fontSize: 17.5, color: Colors.white,  fontWeight: FontWeight.w800, letterSpacing: -0.2)),
                ],
              )),
              _NotifBtn(onTap: onNotif),
            ]),

            const SizedBox(height: 20),

            // today's donations hero
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
                  Text(_inr(26000), style: const TextStyle(fontSize: 36, color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: -1)),
                ],
              )),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(9)),
                child: const Row(children: [
                  Icon(Icons.trending_up, size: 13, color: Colors.white),
                  SizedBox(width: 3),
                  Text('+18%', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w800)),
                ]),
              ),
            ]),

            const SizedBox(height: 16),

            // Month + Year pills
            Row(children: [
              Expanded(child: _StatPill(label: 'This Month', value: _inr(155000, compact: true))),
              const SizedBox(width: 10),
              const Expanded(child: _StatPill(label: 'This Year', value: '₹56.1L')),
            ]),
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
          child: Container(
            width: 9, height: 9,
            decoration: BoxDecoration(color: _coral500, shape: BoxShape.circle, border: Border.all(color: _brand600, width: 2)),
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
  const _Avatar({required this.name, required this.size, this.ring = false});
  final String name;
  final double size;
  final bool ring;
  @override
  Widget build(BuildContext context) {
    final color = _avColor(name);
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: [color, Color.lerp(color, Colors.black, 0.22)!], begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: ring ? [BoxShadow(color: Colors.white, blurRadius: 0, spreadRadius: 2), BoxShadow(color: color, blurRadius: 0, spreadRadius: 4)] : [],
      ),
      child: Center(
        child: Text(_initials(name), style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: size * 0.36)),
      ),
    );
  }
}

// ── Quick Action tile ─────────────────────────────────────────────────
class _QA extends StatelessWidget {
  const _QA({required this.label, required this.icon, required this.bg, required this.fg, required this.onTap});
  final String label;
  final IconData icon;
  final Color bg, fg;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: context.border),
          boxShadow: const [BoxShadow(color: Color(0x0D0D2822), blurRadius: 4, offset: Offset(0, 2))],
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 46, height: 46, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: fg, size: 22),
          ),
          const SizedBox(height: 8),
          Text(label, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: context.textPrimary, height: 1.3)),
        ]),
      ),
    ),
  );
}

// ── KPI Card ──────────────────────────────────────────────────────────
class _KPICard extends StatelessWidget {
  const _KPICard({required this.label, required this.value, required this.icon, required this.fg, required this.bg, required this.delta, required this.onTap});
  final String label, value;
  final IconData icon;
  final Color fg, bg;
  final String? delta;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardBg, borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.border),
        boxShadow: const [BoxShadow(color: Color(0x0D0D2822), blurRadius: 3, offset: Offset(0, 1))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Container(width: 38, height: 38, decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(11)), child: Icon(icon, color: fg, size: 20)),
          if (delta != null)
            Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.trending_up, size: 12, color: Color(0xFF1FA971)),
              const SizedBox(width: 2),
              Text(delta!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFF1FA971))),
            ]),
        ]),
        const SizedBox(height: 10),
        Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.6, height: 1)),
        const SizedBox(height: 5),
        Text(label, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.textSub)),
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
  const _TrendCard({required this.period, required this.onPeriodChange});
  final String period;
  final ValueChanged<String> onPeriodChange;

  @override
  Widget build(BuildContext context) {
    final data = period == '7M' ? _trend7M : _trend1Y;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
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
            child: _LineChart(data: data),
          ),
        ]),
      ),
    );
  }
}

class _LineChart extends StatelessWidget {
  const _LineChart({required this.data});
  final List<MapEntry<String, double>> data;

  @override
  Widget build(BuildContext context) {
    final maxV = data.map((e) => e.value).reduce((a, b) => a > b ? a : b) * 1.15;
    final spots = data.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.value)).toList();
    return LineChart(LineChartData(
      minY: 0,
      maxY: maxV,
      clipData: const FlClipData.all(),
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: maxV * 0.33,
        getDrawingHorizontalLine: (_) => FlLine(color: context.border, strokeWidth: 1, dashArray: [2, 5]),
      ),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        leftTitles:   AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles:    AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:  AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          curveSmoothness: 0.3,
          color: _brand600,
          barWidth: 3,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, _, __, i) => FlDotCirclePainter(
              radius: i == data.length - 1 ? 5 : 3,
              color: Colors.white,
              strokeWidth: 2.5,
              strokeColor: _brand600,
            ),
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0x47147A6A), Color(0x00147A6A)],
            ),
          ),
        ),
      ],
    ));
  }
}

// ── Donut Card ────────────────────────────────────────────────────────
class _DonutCard extends StatelessWidget {
  const _DonutCard();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 18),
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
                sections: _typeSplit.map((t) => PieChartSectionData(
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
                const Text('₹56.1L', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: -0.5, height: 1)),
                const SizedBox(height: 2),
                Text('this year', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w600, color: context.textSub)),
              ]),
            ]),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _typeSplit.map((t) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                Row(children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: t.color, borderRadius: BorderRadius.circular(3))),
                  const SizedBox(width: 8),
                  Text(t.label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                ]),
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
            Text(donation.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: -0.1, height: 1)),
            const SizedBox(height: 2),
            Row(children: [
              Container(width: 7, height: 7, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 6),
              Text('${donation.type} · ${donation.method}', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: context.textSub)),
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
