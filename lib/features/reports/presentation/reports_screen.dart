import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/native_file_saver.dart';
import '../../../core/theme/app_theme.dart';

const _brand700 = Color(0xFF0B6E5D);
const _brand600 = Color(0xFF0E8C76);
const _brand100 = Color(0xFFD6F3EC);
const _amber600 = Color(0xFFE0921A);
const _coral500 = Color(0xFFF2685E);
const _violet500 = Color(0xFF7C6CF0);
const _sky500 = Color(0xFF2D9CDB);
const _green500 = Color(0xFF14A98C);
const _onSurface1 = Color(0xFF15211E);
const _onSurface2 = Color(0xFF5A6B67);
const _onSurface3 = Color(0xFF93A29F);
const _border = Color(0xFFE5EBE9);
const _surface2 = Color(0xFFF4F7F6);

String _inr(int n) => '₹${NumberFormat("#,##,###","en_IN").format(n)}';
String _inrC(int n) {
  if (n >= 10000000) return '₹${(n / 10000000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}Cr';
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


const _trendLabels = ['Dec', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'];
const _trendValues = [340000.0, 520000.0, 280000.0, 610000.0, 490000.0, 730000.0, 890000.0];

const _allocation = [
  ('Education Fund', 0.34, _violet500),
  ('Child Sponsorship', 0.28, _brand600),
  ('General Fund', 0.18, _sky500),
  ('Medical Aid', 0.12, _coral500),
  ('Food Drive', 0.08, _amber600),
];

const _officePerf = [
  ('Sulibele', 890000, 1200000),
  ('Medahalli', 640000, 900000),
  ('Yelahanka', 320000, 600000),
  ('Electronic City', 180000, 500000),
];

const _topDonors = [
  ('Rajesh Khanna', 'Corporate', 320000),
  ('Arjun Mehta', 'Recurring', 210000),
  ('Priya Sharma', 'Recurring', 185000),
  ('Vikram Singh', 'One-Time', 150000),
  ('Deepak Nair', 'Corporate', 125000),
];

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  DateTimeRange? _dateRange;
  String _reportFilter = 'All';
  static const _filterOptions = ['All', 'Donations', 'Donors', 'Students'];

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      body: Column(children: [
        // header
        Container(color: context.headerBg, padding: EdgeInsets.fromLTRB(18, top + 14, 18, 16),
          child: Row(children: [
            IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20), onPressed: () => context.go('/more'), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Reports & Analytics', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
              Text('Performance overview', style: TextStyle(fontSize: 13, color: context.textSub, fontWeight: FontWeight.w600)),
            ])),
          ])),

        Expanded(child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Center(child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(children: [
            // ── filter controls ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Date range picker row
                Row(children: [
                  Expanded(child: GestureDetector(
                    onTap: () async {
                      final range = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                        initialDateRange: _dateRange,
                        builder: (ctx, child) => Theme(
                          data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: _brand600)),
                          child: child!,
                        ),
                      );
                      if (range != null) setState(() => _dateRange = range);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      decoration: BoxDecoration(
                        color: _dateRange != null ? _brand100 : context.cardBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _dateRange != null ? _brand600 : context.border, width: 1.5),
                      ),
                      child: Row(children: [
                        Icon(Icons.calendar_today_outlined, size: 16, color: _dateRange != null ? _brand600 : _onSurface2),
                        const SizedBox(width: 8),
                        Expanded(child: Text(
                          _dateRange != null
                            ? '${DateFormat('dd MMM').format(_dateRange!.start)} – ${DateFormat('dd MMM yyyy').format(_dateRange!.end)}'
                            : 'Select date range…',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600,
                            color: _dateRange != null ? _brand600 : _onSurface3),
                        )),
                        if (_dateRange != null)
                          GestureDetector(
                            onTap: () => setState(() => _dateRange = null),
                            child: const Icon(Icons.close_rounded, size: 16, color: _brand600)),
                      ]),
                    ),
                  )),
                ]),
                const SizedBox(height: 10),
                // Filter type chips + Export button
                Row(children: [
                  Expanded(child: SizedBox(height: 36, child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: _filterOptions.map((f) {
                      final active = _reportFilter == f;
                      return Padding(padding: const EdgeInsets.only(right: 8), child: GestureDetector(
                        onTap: () => setState(() => _reportFilter = f),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: active ? _brand600 : context.cardBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: active ? _brand600 : context.border, width: 1.5),
                          ),
                          child: Text(f, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: active ? Colors.white : context.textSub)),
                        ),
                      ));
                    }).toList(),
                  ))),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () async {
                      final buf = StringBuffer();
                      buf.writeln('Metric,Value');
                      buf.writeln('Filter,$_reportFilter');
                      if (_dateRange != null) buf.writeln('From,${DateFormat('dd MMM yyyy').format(_dateRange!.start)}');
                      if (_dateRange != null) buf.writeln('To,${DateFormat('dd MMM yyyy').format(_dateRange!.end)}');
                      buf.writeln('Generated,${DateFormat('dd MMM yyyy').format(DateTime.now())}');
                      buf.writeln('Total Raised,₹28,60,000');
                      buf.writeln('Unique Donors,836');
                      buf.writeln('Children Supported,178');
                      final filename = 'Saksham_Report_${DateFormat('ddMMyyyy').format(DateTime.now())}.csv';
                      final ok = await NativeFileSaver.saveCsv(filename, buf.toString());
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(ok ? '✓ Report saved: $filename' : 'Failed to save file', style: const TextStyle(fontWeight: FontWeight.w700)),
                          backgroundColor: ok ? _brand600 : Colors.red, behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                      decoration: BoxDecoration(color: _brand600, borderRadius: BorderRadius.circular(12)),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.download_outlined, color: Colors.white, size: 16),
                        SizedBox(width: 6),
                        Text('Export', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
                      ]),
                    ),
                  ),
                ]),
              ]),
            ),

            const SizedBox(height: 16),

            // KPI — 4 cards: single row on wide, 2×2 on narrow
            Padding(padding: const EdgeInsets.symmetric(horizontal: 18), child: LayoutBuilder(builder: (_, constraints) {
              final wide = constraints.maxWidth > 580;
              final card1 = _KPICard(label: 'Total Raised', value: _inrC(2860000), sub: '+18% vs last period', subColor: _green500, icon: Icons.account_balance_wallet_outlined, iconBg: _brand100, iconFg: _brand600);
              final card2 = _KPICard(label: 'Unique Donors', value: '836', sub: '↑ 42 new this period', subColor: _brand600, icon: Icons.people_outlined, iconBg: _brand100, iconFg: _brand600);
              final card3 = _KPICard(label: 'Avg Gift', value: '₹3,421', sub: '↑ ₹280 vs last period', subColor: _green500, icon: Icons.trending_up_rounded, iconBg: const Color(0xFFE7E3FD), iconFg: _violet500);
              final card4 = _KPICard(label: 'Children Supported', value: '178', sub: '12 graduated this period', subColor: _onSurface3, icon: Icons.child_care_outlined, iconBg: const Color(0xFFFFF1D6), iconFg: _amber600);
              if (wide) {
                return Row(children: [
                  Expanded(child: card1), const SizedBox(width: 10),
                  Expanded(child: card2), const SizedBox(width: 10),
                  Expanded(child: card3), const SizedBox(width: 10),
                  Expanded(child: card4),
                ]);
              }
              return Column(children: [
                Row(children: [Expanded(child: card1), const SizedBox(width: 10), Expanded(child: card2)]),
                const SizedBox(height: 10),
                Row(children: [Expanded(child: card3), const SizedBox(width: 10), Expanded(child: card4)]),
              ]);
            })),

            const SizedBox(height: 20),

            // Trend chart
            Padding(padding: const EdgeInsets.symmetric(horizontal: 18), child: _TrendCard()),

            const SizedBox(height: 16),

            // Fund allocation donut
            Padding(padding: const EdgeInsets.symmetric(horizontal: 18), child: _AllocationCard()),

            const SizedBox(height: 16),

            // Office performance
            Padding(padding: const EdgeInsets.symmetric(horizontal: 18), child: _OfficeCard()),

            const SizedBox(height: 16),

            // Top donors
            Padding(padding: const EdgeInsets.symmetric(horizontal: 18), child: _TopDonorsCard()),

            const SizedBox(height: 96),
          ]),
            )))),
      ]),
    );
  }
}

class _KPICard extends StatelessWidget {
  const _KPICard({required this.label, required this.value, required this.sub, required this.subColor, required this.icon, required this.iconBg, required this.iconFg});
  final String label, value, sub; final Color subColor, iconBg, iconFg; final IconData icon;
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: context.border),
      boxShadow: const [BoxShadow(color: Color(0x080D2822), blurRadius: 6, offset: Offset(0, 2))]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(width: 36, height: 36, decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: iconFg, size: 18)),
      const SizedBox(height: 10),
      Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(fontSize: 12, color: context.textSub, fontWeight: FontWeight.w600)),
      const SizedBox(height: 4),
      Text(sub, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: subColor)),
    ]));
}

class _TrendCard extends StatefulWidget {
  @override
  State<_TrendCard> createState() => _TrendCardState();
}

class _TrendCardState extends State<_TrendCard> {
  @override
  Widget build(BuildContext context) {
    final spots = _trendValues.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value / 1000)).toList();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 8),
      decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(22), border: Border.all(color: context.border),
        boxShadow: const [BoxShadow(color: Color(0x080D2822), blurRadius: 8, offset: Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Text('Donation Trend', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
          Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: _brand100, borderRadius: BorderRadius.circular(10)),
            child: const Text('Dec – Jun', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _brand700))),
        ]),
        const SizedBox(height: 4),
        Text('Monthly collections (₹K)', style: TextStyle(fontSize: 12, color: context.textHint, fontWeight: FontWeight.w500)),
        const SizedBox(height: 18),
        SizedBox(height: 160, child: LineChart(LineChartData(
          gridData: FlGridData(show: true, drawVerticalLine: false,
            getDrawingHorizontalLine: (_) => FlLine(color: context.border, strokeWidth: 1)),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 22,
              getTitlesWidget: (v, _) {
                final i = v.toInt();
                if (i < 0 || i >= _trendLabels.length) return const SizedBox();
                return Padding(padding: const EdgeInsets.only(top: 5), child: Text(_trendLabels[i], style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: context.textHint)));
              })),
          ),
          lineTouchData: LineTouchData(touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (spots) => spots.map((s) => LineTooltipItem('₹${s.y.toStringAsFixed(0)}K', const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12))).toList(),
          )),
          lineBarsData: [LineChartBarData(
            spots: spots, isCurved: true, color: _brand600, barWidth: 2.5,
            dotData: FlDotData(getDotPainter: (s, p, bar, i) => FlDotCirclePainter(radius: 4, color: Colors.white, strokeWidth: 2, strokeColor: _brand600)),
            belowBarData: BarAreaData(show: true, gradient: LinearGradient(colors: [_brand600.withValues(alpha: 0.18), _brand600.withValues(alpha: 0)], begin: Alignment.topCenter, end: Alignment.bottomCenter)),
          )],
        ))),
      ]),
    );
  }
}

class _AllocationCard extends StatelessWidget {
  const _AllocationCard();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(22), border: Border.all(color: context.border),
      boxShadow: const [BoxShadow(color: Color(0x080D2822), blurRadius: 8, offset: Offset(0, 2))]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Fund Allocation', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      const SizedBox(height: 2),
      Text('Where donations are directed', style: TextStyle(fontSize: 12, color: context.textHint, fontWeight: FontWeight.w500)),
      const SizedBox(height: 16),
      Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        SizedBox(width: 130, height: 130, child: PieChart(PieChartData(
          sectionsSpace: 2, centerSpaceRadius: 36, startDegreeOffset: -90,
          sections: _allocation.map((a) => PieChartSectionData(
            value: a.$2 * 100, color: a.$3, radius: 26, showTitle: false,
          )).toList(),
        ))),
        const SizedBox(width: 20),
        Expanded(child: Column(children: _allocation.map((a) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: a.$3, borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 8),
            Expanded(child: Text(a.$1, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: context.textSub))),
            Text('${(a.$2 * 100).round()}%', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: a.$3)),
          ]),
        )).toList())),
      ]),
    ]),
  );
}

class _OfficeCard extends StatelessWidget {
  const _OfficeCard();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(22), border: Border.all(color: context.border),
      boxShadow: const [BoxShadow(color: Color(0x080D2822), blurRadius: 8, offset: Offset(0, 2))]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Office Performance', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      const SizedBox(height: 2),
      Text('Collected vs target', style: TextStyle(fontSize: 12, color: context.textHint, fontWeight: FontWeight.w500)),
      const SizedBox(height: 16),
      ..._officePerf.map((o) {
        final pct = o.$2 / o.$3;
        return Padding(padding: const EdgeInsets.only(bottom: 14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(o.$1, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
            Row(children: [
              Text(_inrC(o.$2), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _brand700)),
              Text(' / ${_inrC(o.$3)}', style: TextStyle(fontSize: 12, color: context.textHint, fontWeight: FontWeight.w600)),
            ]),
          ]),
          const SizedBox(height: 6),
          Stack(children: [
            Container(height: 7, decoration: BoxDecoration(color: context.surface2, borderRadius: BorderRadius.circular(4))),
            FractionallySizedBox(widthFactor: pct.clamp(0.0, 1.0), child: Container(height: 7, decoration: BoxDecoration(
              gradient: LinearGradient(colors: pct >= 0.8 ? [_brand600, _green500] : pct >= 0.5 ? [_amber600, _amber600] : [_coral500, _coral500]),
              borderRadius: BorderRadius.circular(4)))),
          ]),
          const SizedBox(height: 3),
          Text('${(pct * 100).round()}% of target', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: pct >= 0.8 ? _brand600 : pct >= 0.5 ? _amber600 : _coral500)),
        ]));
      }),
    ]),
  );
}

class _TopDonorsCard extends StatelessWidget {
  const _TopDonorsCard();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(22), border: Border.all(color: context.border),
      boxShadow: const [BoxShadow(color: Color(0x080D2822), blurRadius: 8, offset: Offset(0, 2))]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Top Donors', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      const SizedBox(height: 2),
      Text('Highest contribution this period', style: TextStyle(fontSize: 12, color: context.textHint, fontWeight: FontWeight.w500)),
      const SizedBox(height: 14),
      ..._topDonors.asMap().entries.map((e) {
        final idx = e.key; final d = e.value;
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: idx < _topDonors.length - 1 ? BoxDecoration(border: Border(bottom: BorderSide(color: context.border))) : null,
          child: Row(children: [
            Container(width: 28, height: 28, margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(color: idx == 0 ? _amber600 : idx == 1 ? _onSurface3 : _border, shape: BoxShape.circle),
              child: Center(child: Text('${idx + 1}', style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800)))),
            Container(width: 38, height: 38,
              decoration: BoxDecoration(gradient: LinearGradient(colors: [_avColor(d.$1), Color.lerp(_avColor(d.$1), Colors.black, 0.18)!]), shape: BoxShape.circle),
              child: Center(child: Text(_initials(d.$1), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)))),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d.$1, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(color: _brand100, borderRadius: BorderRadius.circular(5)),
                child: Text(d.$2, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: _brand700))),
            ])),
            Text(_inr(d.$3), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _brand700)),
          ]),
        );
      }),
    ]),
  );
}
