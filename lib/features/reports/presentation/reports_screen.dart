import 'dart:typed_data';
import 'package:excel/excel.dart' as xl;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/native_file_saver.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/api_client.dart';

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

const _allocationPalette = [_brand600, _violet500, _sky500, _amber600, _coral500, _green500];

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  DateTimeRange? _dateRange;
  String _reportFilter = 'All';
  bool _exporting = false;
  static const _filterOptions = ['All', 'Donations', 'Donors', 'Students'];

  bool _loading = true;
  String? _error;

  // Real data, fetched from the backend.
  Map<String, dynamic> _overview = {};
  List<({String label, double amount})> _trend = [];
  List<({String name, String category, double amount, Color color})> _allocation = [];
  List<({String name, String tier, int total})> _topDonors = [];
  int _totalDonationsCount = 0;

  List<Map<String, dynamic>> _donations = [];
  List<Map<String, dynamic>> _students = [];
  List<Map<String, dynamic>> _donors = [];

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final results = await Future.wait([
        apiClient.get('/reports/overview'),
        apiClient.get('/reports/monthly-trend', params: {'months': '7'}),
        apiClient.get('/donations/types'),
        apiClient.get('/donations', params: {'limit': '100', 'page': '1'}),
        apiClient.get('/students', params: {'limit': '100', 'page': '1'}),
        apiClient.get('/donors', params: {'limit': '100', 'page': '1'}),
      ]);

      final overview = (results[0]['data'] as Map).cast<String, dynamic>();

      final trendList = (results[1]['data'] as List<dynamic>? ?? const []);
      final trend = trendList.whereType<Map>().map((m) => (
        label: m['label'] as String? ?? '', amount: (m['amount'] as num?)?.toDouble() ?? 0,
      )).toList();

      final typesList = (results[2]['data'] as List<dynamic>? ?? const []);
      final typeLabels = {
        for (final t in typesList.whereType<Map>()) (t['id'] as String? ?? ''): (t['label'] as String? ?? ''),
      };

      final byType = (overview['donationsByType'] as List<dynamic>? ?? const []);
      final typeTotal = byType.whereType<Map>().fold<int>(0, (s, t) => s + (((t['_sum'] as Map?)?['amount'] as num?)?.toInt() ?? 0));
      final allocation = <({String name, String category, double amount, Color color})>[];
      var colorIdx = 0;
      for (final t in byType.whereType<Map>()) {
        final amt = ((t['_sum'] as Map?)?['amount'] as num?)?.toInt() ?? 0;
        if (amt <= 0) continue;
        final label = typeLabels[t['typeId'] as String? ?? ''] ?? 'Other';
        allocation.add((
          name: label, category: label,
          amount: typeTotal > 0 ? amt / typeTotal : 0,
          color: _allocationPalette[colorIdx % _allocationPalette.length],
        ));
        colorIdx++;
      }
      allocation.sort((a, b) => b.amount.compareTo(a.amount));

      final topDonorsRaw = (overview['topDonors'] as List<dynamic>? ?? const []);
      final topDonors = topDonorsRaw.whereType<Map>().map((d) => (
        name: d['name'] as String? ?? 'Donor',
        tier: d['tier'] as String? ?? 'SILVER',
        total: (d['total'] as num?)?.toInt() ?? 0,
      )).toList()
        ..sort((a, b) => b.total.compareTo(a.total));

      // All-time donation count, for a real Average Gift figure (the overview
      // only breaks totals down by this-year/this-month).
      final donationsInner = results[3]['data'];
      final donationsMeta = donationsInner is Map ? (donationsInner['meta'] as Map?) : null;
      final totalDonationsCount = (donationsMeta?['total'] as int?) ?? 0;

      List<Map<String, dynamic>> extractList(dynamic inner) {
        final l = inner is Map ? (inner['data'] as List<dynamic>? ?? const []) : (inner is List ? inner : const []);
        return l.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
      }

      if (mounted) {
        setState(() {
          _overview = overview;
          _trend = trend;
          _allocation = allocation.take(6).toList();
          _topDonors = topDonors.take(5).toList();
          _totalDonationsCount = totalDonationsCount;
          _donations = extractList(results[3]['data']);
          _students = extractList(results[4]['data']);
          _donors = extractList(results[5]['data']);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = 'Could not load report data'; _loading = false; });
    }
  }

  // ── derived KPIs ──────────────────────────────────────────────────────
  int get _totalRaised => ((_overview['donations'] as Map?)?['totalRaised'] as num?)?.toInt() ?? 0;
  int get _uniqueDonors => ((_overview['donors'] as Map?)?['total'] as num?)?.toInt() ?? 0;
  int get _avgGift => _totalDonationsCount > 0 ? (_totalRaised / _totalDonationsCount).round() : 0;
  int get _childrenSupported => ((_overview['students'] as Map?)?['active'] as num?)?.toInt() ?? 0;

  // ── Excel helpers ────────────────────────────────────────────────────
  xl.CellStyle _headerStyle() => xl.CellStyle(
    bold: true,
    backgroundColorHex: xl.ExcelColor.fromHexString('#0E8C76'),
    fontColorHex: xl.ExcelColor.fromHexString('#FFFFFF'),
    horizontalAlign: xl.HorizontalAlign.Center,
  );

  xl.CellStyle _summaryStyle() => xl.CellStyle(
    bold: true,
    backgroundColorHex: xl.ExcelColor.fromHexString('#D6F3EC'),
    fontColorHex: xl.ExcelColor.fromHexString('#0B6E5D'),
  );

  void _setRow(xl.Sheet sheet, int row, List<String> values, {xl.CellStyle? style}) {
    for (int c = 0; c < values.length; c++) {
      final cell = sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: row));
      cell.value = xl.TextCellValue(values[c]);
      if (style != null) cell.cellStyle = style;
    }
  }

  // Filters _donations to the selected date range, if any.
  List<Map<String, dynamic>> get _filteredDonations {
    if (_dateRange == null) return _donations;
    return _donations.where((d) {
      final dt = DateTime.tryParse(d['date'] as String? ?? '');
      if (dt == null) return true;
      return !dt.isBefore(_dateRange!.start) && !dt.isAfter(_dateRange!.end.add(const Duration(days: 1)));
    }).toList();
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    final excel = xl.Excel.createExcel();
    final dateStr = DateFormat('ddMMyyyy').format(DateTime.now());

    if (_reportFilter == 'All' || _reportFilter == 'Donations') {
      final sheet = excel['Donations'];
      _setRow(sheet, 0, ['#', 'Donor Name', 'Date', 'Category', 'Payment Method', 'Amount (₹)'], style: _headerStyle());
      final rows = _filteredDonations;
      int totalAmt = 0;
      final uniqueDonors = <String>{};
      for (int i = 0; i < rows.length; i++) {
        final r = rows[i];
        final donor = (r['donor'] as Map?)?.cast<String, dynamic>() ?? const {};
        final type = (r['type'] as Map?)?.cast<String, dynamic>() ?? const {};
        final amount = (r['amount'] as num?)?.toInt() ?? 0;
        final name = donor['name'] as String? ?? 'Unknown';
        _setRow(sheet, i + 1, ['${i + 1}', name, (r['date'] as String? ?? '').split('T').first,
          type['label'] as String? ?? '', r['paymentMode'] as String? ?? '', amount.toString()]);
        totalAmt += amount;
        uniqueDonors.add(name);
      }
      final sumRow = rows.length + 2;
      _setRow(sheet, sumRow,     ['SUMMARY', '', '', '', '', ''],      style: _summaryStyle());
      _setRow(sheet, sumRow + 1, ['Total Donations', '${rows.length}', '', '', '', ''], style: _summaryStyle());
      _setRow(sheet, sumRow + 2, ['Total Donors',    '${uniqueDonors.length}',  '', '', '', ''], style: _summaryStyle());
      _setRow(sheet, sumRow + 3, ['Total Amount (₹)', totalAmt.toString(),      '', '', '', ''], style: _summaryStyle());
    }

    if (_reportFilter == 'All' || _reportFilter == 'Students') {
      final sheet = excel['Students'];
      _setRow(sheet, 0, ['#', 'Child ID', 'Name', 'Centre', 'Class', 'Status', 'Gender', 'Sponsor', 'Guardian Phone', 'Address'], style: _headerStyle());
      for (int i = 0; i < _students.length; i++) {
        final r = _students[i];
        final centre = (r['center'] as Map?)?['name'] as String? ?? '';
        final sponsorships = (r['sponsorships'] as List?) ?? const [];
        final sponsor = sponsorships.isNotEmpty ? (((sponsorships.first as Map?)?['donor'] as Map?)?['name'] as String? ?? '-') : '-';
        _setRow(sheet, i + 1, ['${i + 1}', r['childId'] as String? ?? '', r['name'] as String? ?? '',
          centre, r['class'] as String? ?? '', r['status'] as String? ?? '', r['gender'] as String? ?? '',
          sponsor, r['guardianPhone'] as String? ?? '', r['address'] as String? ?? '']);
      }
      final sumRow = _students.length + 2;
      _setRow(sheet, sumRow, ['SUMMARY', '', '', '', '', '', '', '', '', ''], style: _summaryStyle());
      _setRow(sheet, sumRow + 1, ['Total Students', '${_students.length}', '', '', '', '', '', '', '', ''], style: _summaryStyle());
      final active = _students.where((r) => r['status'] == 'ACTIVE').length;
      final sponsored = _students.where((r) => ((r['sponsorships'] as List?) ?? const []).isNotEmpty).length;
      _setRow(sheet, sumRow + 2, ['Active', '$active', '', '', '', '', '', '', '', ''], style: _summaryStyle());
      _setRow(sheet, sumRow + 3, ['Sponsored', '$sponsored', '', '', '', '', '', '', '', ''], style: _summaryStyle());
    }

    if (_reportFilter == 'All' || _reportFilter == 'Donors') {
      final sheet = excel['Donors'];
      _setRow(sheet, 0, ['#', 'Donor Code', 'Name', 'Mobile', 'City', 'Tier', 'Total Donations'], style: _headerStyle());
      for (int i = 0; i < _donors.length; i++) {
        final r = _donors[i];
        final donationCount = (r['_count'] as Map?)?['donations'] as int? ?? 0;
        _setRow(sheet, i + 1, ['${i + 1}', r['donorCode'] as String? ?? '', r['name'] as String? ?? '',
          r['mobile'] as String? ?? '', r['city'] as String? ?? '', r['tier'] as String? ?? '', donationCount.toString()]);
      }
      final sumRow = _donors.length + 2;
      _setRow(sheet, sumRow,     ['SUMMARY', '', '', '', '', '', ''],      style: _summaryStyle());
      _setRow(sheet, sumRow + 1, ['Total Donors', '${_donors.length}', '', '', '', '', ''], style: _summaryStyle());
    }

    if (excel.sheets.containsKey('Sheet1')) excel.delete('Sheet1');

    final bytes = excel.encode();
    if (bytes == null) { setState(() => _exporting = false); return; }

    final filename = 'Saksham_${_reportFilter}_Report_$dateStr.xlsx';
    final ok = await NativeFileSaver.saveBytes(filename, Uint8List.fromList(bytes),
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');

    if (mounted) {
      setState(() => _exporting = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(ok ? '✓ Saved: $filename' : 'Export failed', style: const TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: ok ? _brand600 : Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ));
    }
  }

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

        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator(color: _brand600)))
        else if (_error != null)
          Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.wifi_off_rounded, size: 44, color: _onSurface3),
            const SizedBox(height: 10),
            Text(_error!, style: const TextStyle(fontWeight: FontWeight.w700, color: _onSurface1)),
            const SizedBox(height: 10),
            TextButton(onPressed: _load, child: const Text('Retry', style: TextStyle(color: _brand600, fontWeight: FontWeight.w700))),
          ])))
        else
        Expanded(child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Center(child: ConstrainedBox(
            constraints: const BoxConstraints(),
            child: Column(children: [
            // ── filter controls ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Date range picker row (scopes the Excel export)
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
                            ? '${DateFormat('dd MMM').format(_dateRange!.start)} – ${DateFormat('dd MMM yyyy').format(_dateRange!.end)}  (Donations export)'
                            : 'Select date range for Donations export…',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600,
                            color: _dateRange != null ? _brand600 : _onSurface3),
                          overflow: TextOverflow.ellipsis,
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
                    onTap: _exporting ? null : _export,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                      decoration: BoxDecoration(
                        color: _exporting ? _brand600.withValues(alpha: 0.6) : _brand600,
                        borderRadius: BorderRadius.circular(12)),
                      child: _exporting
                        ? const SizedBox(width: 60, child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))))
                        : const Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.download_outlined, color: Colors.white, size: 16),
                            SizedBox(width: 6),
                            Text('Export Excel', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
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
              final card1 = _KPICard(label: 'Total Raised', value: _inrC(_totalRaised), sub: 'All time', subColor: _brand600, icon: Icons.account_balance_wallet_outlined, iconBg: _brand100, iconFg: _brand600);
              final card2 = _KPICard(label: 'Unique Donors', value: '$_uniqueDonors', sub: 'Total on record', subColor: _brand600, icon: Icons.people_outlined, iconBg: _brand100, iconFg: _brand600);
              final card3 = _KPICard(label: 'Avg Gift', value: _inrC(_avgGift), sub: 'Per donation', subColor: _violet500, icon: Icons.trending_up_rounded, iconBg: const Color(0xFFE7E3FD), iconFg: _violet500);
              final card4 = _KPICard(label: 'Children Supported', value: '$_childrenSupported', sub: 'Active students', subColor: _amber600, icon: Icons.child_care_outlined, iconBg: const Color(0xFFFFF1D6), iconFg: _amber600);
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
            Padding(padding: const EdgeInsets.symmetric(horizontal: 18), child: _TrendCard(trend: _trend)),

            const SizedBox(height: 16),

            // Fund allocation donut
            if (_allocation.isNotEmpty) ...[
              Padding(padding: const EdgeInsets.symmetric(horizontal: 18), child: _AllocationCard(allocation: _allocation)),
              const SizedBox(height: 16),
            ],

            // Top donors
            if (_topDonors.isNotEmpty)
              Padding(padding: const EdgeInsets.symmetric(horizontal: 18), child: _TopDonorsCard(topDonors: _topDonors)),

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

class _TrendCard extends StatelessWidget {
  const _TrendCard({required this.trend});
  final List<({String label, double amount})> trend;
  @override
  Widget build(BuildContext context) {
    final spots = trend.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.amount / 1000)).toList();
    final rangeLabel = trend.isNotEmpty ? '${trend.first.label} – ${trend.last.label}' : '';
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 8),
      decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(22), border: Border.all(color: context.border),
        boxShadow: const [BoxShadow(color: Color(0x080D2822), blurRadius: 8, offset: Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Text('Donation Trend', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
          if (rangeLabel.isNotEmpty)
            Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: _brand100, borderRadius: BorderRadius.circular(10)),
              child: Text(rangeLabel, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _brand700))),
        ]),
        const SizedBox(height: 4),
        Text('Monthly collections (₹K)', style: TextStyle(fontSize: 12, color: context.textHint, fontWeight: FontWeight.w500)),
        const SizedBox(height: 18),
        if (trend.every((t) => t.amount == 0))
          SizedBox(height: 160, child: Center(child: Text('No donations recorded yet', style: TextStyle(fontSize: 13, color: context.textHint, fontWeight: FontWeight.w600))))
        else
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
                if (i < 0 || i >= trend.length) return const SizedBox();
                return Padding(padding: const EdgeInsets.only(top: 5), child: Text(trend[i].label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: context.textHint)));
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
  const _AllocationCard({required this.allocation});
  final List<({String name, String category, double amount, Color color})> allocation;
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
          sections: allocation.map((a) => PieChartSectionData(
            value: a.amount * 100, color: a.color, radius: 26, showTitle: false,
          )).toList(),
        ))),
        const SizedBox(width: 20),
        Expanded(child: Column(children: allocation.map((a) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: a.color, borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 8),
            Expanded(child: Text(a.name, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: context.textSub), overflow: TextOverflow.ellipsis)),
            Text('${(a.amount * 100).round()}%', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: a.color)),
          ]),
        )).toList())),
      ]),
    ]),
  );
}

class _TopDonorsCard extends StatelessWidget {
  const _TopDonorsCard({required this.topDonors});
  final List<({String name, String tier, int total})> topDonors;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(22), border: Border.all(color: context.border),
      boxShadow: const [BoxShadow(color: Color(0x080D2822), blurRadius: 8, offset: Offset(0, 2))]),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Top Donors', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      const SizedBox(height: 2),
      Text('Highest all-time contribution', style: TextStyle(fontSize: 12, color: context.textHint, fontWeight: FontWeight.w500)),
      const SizedBox(height: 14),
      ...topDonors.asMap().entries.map((e) {
        final idx = e.key; final d = e.value;
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: idx < topDonors.length - 1 ? BoxDecoration(border: Border(bottom: BorderSide(color: context.border))) : null,
          child: Row(children: [
            Container(width: 28, height: 28, margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(color: idx == 0 ? _amber600 : idx == 1 ? _onSurface3 : _border, shape: BoxShape.circle),
              child: Center(child: Text('${idx + 1}', style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w800)))),
            Container(width: 38, height: 38,
              decoration: BoxDecoration(gradient: LinearGradient(colors: [_avColor(d.name), Color.lerp(_avColor(d.name), Colors.black, 0.18)!]), shape: BoxShape.circle),
              child: Center(child: Text(_initials(d.name), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)))),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), margin: const EdgeInsets.only(top: 2),
                decoration: BoxDecoration(color: _brand100, borderRadius: BorderRadius.circular(5)),
                child: Text(d.tier, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: _brand700))),
            ])),
            Text(_inr(d.total), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _brand700)),
          ]),
        );
      }),
    ]),
  );
}
