import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/app_launcher.dart';
import '../../../core/utils/native_file_saver.dart';
import '../../../core/theme/app_theme.dart';

const _brand700 = Color(0xFF0B6E5D);
const _brand600 = Color(0xFF0E8C76);
const _brand100 = Color(0xFFD6F3EC);
const _amber600 = Color(0xFFE0921A);
const _amber100 = Color(0xFFFFF1D6);
const _coral500 = Color(0xFFF2685E);
const _violet500 = Color(0xFF7C6CF0);
const _sky500 = Color(0xFF2D9CDB);
const _onSurface2 = Color(0xFF5A6B67);
const _onSurface3 = Color(0xFF93A29F);
const _border = Color(0xFFE5EBE9);
const _surface2 = Color(0xFFF4F7F6);

String _inr(int n) => '₹${NumberFormat("#,##,###","en_IN").format(n)}';
String _inrC(int n) {
  if (n >= 100000) return '₹${(n / 100000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}L';
  if (n >= 1000) return '₹${(n / 1000).round()}K';
  return '₹$n';
}

Color _avColor(String seed) {
  final p = [_brand600, const Color(0xFFF6A723), _violet500, _sky500, _coral500, const Color(0xFF14A98C)];
  int h = 0;
  for (int i = 0; i < seed.length; i++) { h = ((h * 31) + seed.codeUnitAt(i)) & 0xFFFFFFFF; }
  return p[h % p.length];
}
String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  return ((parts[0].isNotEmpty ? parts[0][0] : '') + (parts.length > 1 && parts[1].isNotEmpty ? parts[1][0] : '')).toUpperCase();
}

class _DItem {
  const _DItem({required this.id, required this.donor, required this.type, required this.amount,
    required this.method, required this.receipt, required this.date, required this.daysBefore});
  final String id, donor, type, method, receipt, date;
  final int amount, daysBefore;
}

const _typeColors = {
  'Education Fund': _violet500, 'General Donation': _brand600, 'Food Drive': _amber600,
  'Corporate Match': _sky500, 'Medical Aid': _coral500, 'Child Sponsorship': Color(0xFFEC5B8B),
};

const _allDonations = [
  _DItem(id:'d1', donor:'Meera Iyer',     type:'General Donation', amount:15000,  method:'Payment Link', receipt:'RCP-2026-0156', date:'Today',          daysBefore:0),
  _DItem(id:'d2', donor:'Kavya Reddy',    type:'Food Drive',       amount:11000,  method:'UPI',          receipt:'RCP-2026-0155', date:'02 Jun 2026',     daysBefore:2),
  _DItem(id:'d3', donor:'Vikram Singh',   type:'Child Sponsorship',amount:30000,  method:'UPI',          receipt:'RCP-2026-0154', date:'02 Jun 2026',     daysBefore:2),
  _DItem(id:'d4', donor:'Arjun Mehta',    type:'Corporate Match',  amount:50000,  method:'Bank Transfer',receipt:'RCP-2026-0153', date:'01 Jun 2026',     daysBefore:3),
  _DItem(id:'d5', donor:'Rajesh Khanna',  type:'Education Fund',   amount:100000, method:'Bank Transfer',receipt:'RCP-2026-0149', date:'26 May 2026',     daysBefore:9),
  _DItem(id:'d6', donor:'Priya Sharma',   type:'Child Sponsorship',amount:18000,  method:'UPI',          receipt:'RCP-2026-0148', date:'25 May 2026',     daysBefore:10),
  _DItem(id:'d7', donor:'Deepak Nair',    type:'Food Drive',       amount:5000,   method:'UPI',          receipt:'RCP-2026-0140', date:'12 May 2026',     daysBefore:23),
  _DItem(id:'d8', donor:'Sunita Iyer',    type:'Medical Aid',      amount:8500,   method:'Cash',         receipt:'RCP-2026-0130', date:'05 May 2026',     daysBefore:30),
  _DItem(id:'d9', donor:'Kiran Reddy',    type:'General Donation', amount:2000,   method:'UPI',          receipt:'RCP-2026-0110', date:'10 Apr 2026',     daysBefore:55),
];

const _ranges = ['All', 'Today', 'This Week', 'This Month', 'Last Month'];

// ══════════════════════════════════════════════════════════════════════
class DonationTrackerScreen extends StatefulWidget {
  const DonationTrackerScreen({super.key});
  @override
  State<DonationTrackerScreen> createState() => _DonationTrackerScreenState();
}

class _DonationTrackerScreenState extends State<DonationTrackerScreen> {
  String _range = 'All';
  String _typeFilter = 'All';

  List<_DItem> get _filtered {
    const maxDays = {'All': 9999, 'Today': 0, 'This Week': 7, 'This Month': 30, 'Last Month': 60};
    final max = maxDays[_range] ?? 9999;
    final min = _range == 'Last Month' ? 31 : 0;
    var list = _allDonations.where((d) => d.daysBefore >= min && d.daysBefore <= max).toList();
    if (_typeFilter != 'All') list = list.where((d) => d.type == _typeFilter).toList();
    return list;
  }

  Map<String, List<_DItem>> _grouped(List<_DItem> items) {
    final map = <String, List<_DItem>>{};
    for (final d in items) {
      (map[d.date] ??= []).add(d);
    }
    return map;
  }

  _RangeSummary _summary(List<_DItem> items) {
    final total = items.fold(0, (s, d) => s + d.amount);
    final donors = items.map((d) => d.donor).toSet().length;
    final avg = items.isEmpty ? 0 : total ~/ items.length;
    return _RangeSummary(total: total, count: items.length, donors: donors, avg: avg);
  }

  Set<String> get _types => {'All', ..._allDonations.map((d) => d.type)};

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final items = _filtered;
    final summary = _summary(items);
    final grouped = _grouped(items);

    return Scaffold(
      body: Column(children: [
        Container(color: context.headerBg, padding: EdgeInsets.fromLTRB(18, top + 14, 18, 16),
          child: Row(children: [
            IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20), onPressed: () => context.go('/more'), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Donation Tracker', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
              Text('Track & follow up', style: TextStyle(fontSize: 13, color: context.textSub, fontWeight: FontWeight.w600)),
            ])),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () async {
                final rows = _filtered;
                final buf = StringBuffer();
                buf.writeln('Donor,Type,Amount,Method,Receipt,Date');
                for (final d in rows) {
                  buf.writeln('${d.donor},${d.type},${d.amount},${d.method},${d.receipt},${d.date}');
                }
                final filename = 'Saksham_Donations_${DateFormat('ddMMyyyy').format(DateTime.now())}.csv';
                final ok = await NativeFileSaver.saveCsv(filename, buf.toString());
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(ok ? '✓ ${rows.length} records saved to Downloads/$filename' : 'Failed to save file', style: const TextStyle(fontWeight: FontWeight.w700)),
                    backgroundColor: ok ? _brand600 : Colors.red, behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
                }
              },
              child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(color: _brand600, borderRadius: BorderRadius.circular(12)),
                child: const Row(children: [Icon(Icons.download_outlined, color: Colors.white, size: 16), SizedBox(width: 4), Text('Export CSV', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white))])),
            ),
          ])),

        Expanded(child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // range summary card
            Padding(padding: const EdgeInsets.fromLTRB(18, 16, 18, 0), child: Container(
              padding: const EdgeInsets.all(18),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFF0B6E5D), Color(0xFF0E8C76)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.all(Radius.circular(22)),
                boxShadow: [BoxShadow(color: Color(0x400B6E5D), blurRadius: 16, offset: Offset(0, 6))],
              ),
              child: Column(children: [
                Row(children: [
                  const Icon(Icons.account_balance_wallet_outlined, color: Colors.white70, size: 16),
                  const SizedBox(width: 7),
                  Text('Collected · $_range', style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
                ]),
                const SizedBox(height: 6),
                Text(_inr(summary.total), style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -1)),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: _SumStat('Donations', '${summary.count}')),
                  Container(width: 1, height: 36, color: Colors.white24),
                  Expanded(child: _SumStat('Donors', '${summary.donors}')),
                  Container(width: 1, height: 36, color: Colors.white24),
                  Expanded(child: _SumStat('Avg Gift', _inrC(summary.avg))),
                ]),
              ]),
            )),

            // range chips
            const SizedBox(height: 14),
            SizedBox(height: 40, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
              children: _ranges.map((r) {
                final active = _range == r;
                return Padding(padding: const EdgeInsets.only(right: 8), child: GestureDetector(
                  onTap: () => setState(() => _range = r),
                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: active ? _brand600 : context.cardBg, borderRadius: BorderRadius.circular(16), border: Border.all(color: active ? _brand600 : context.border, width: 1.5)),
                    child: Text(r, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: active ? Colors.white : context.textSub))),
                ));
              }).toList())),

            // type filter chips
            const SizedBox(height: 8),
            SizedBox(height: 36, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
              children: _types.map((t) {
                final active = _typeFilter == t;
                final color = t == 'All' ? _brand600 : (_typeColors[t] ?? _onSurface2);
                return Padding(padding: const EdgeInsets.only(right: 8), child: GestureDetector(
                  onTap: () => setState(() => _typeFilter = t),
                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: active ? color.withValues(alpha: 0.12) : context.cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: active ? color : context.border)),
                    child: Text(t, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: active ? color : context.textSub))),
                ));
              }).toList())),

            const SizedBox(height: 16),

            // grouped list
            if (items.isEmpty)
              Padding(padding: const EdgeInsets.all(40), child: Center(child: Column(children: [
                Icon(Icons.receipt_long_outlined, size: 48, color: context.textHint),
                const SizedBox(height: 12),
                Text('No donations in this range', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: context.textHint)),
              ])))
            else
              ...grouped.entries.map((e) => Padding(padding: const EdgeInsets.fromLTRB(18, 0, 18, 14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text(e.key, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: context.textSub)),
                  Text('Day total ${_inrC(e.value.fold(0, (s, d) => s + d.amount))}', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: context.textHint)),
                ]),
                const SizedBox(height: 8),
                Container(decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: context.border)),
                  child: Column(children: e.value.asMap().entries.map((en) {
                    final i = en.key; final d = en.value;
                    final typeColor = _typeColors[d.type] ?? _brand600;
                    final isOld = d.daysBefore > 60;
                    return Container(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      decoration: i < e.value.length - 1 ? BoxDecoration(border: Border(bottom: BorderSide(color: context.border))) : null,
                      child: Column(children: [
                        Row(children: [
                          Container(width: 44, height: 44,
                            decoration: BoxDecoration(gradient: LinearGradient(colors: [_avColor(d.donor), Color.lerp(_avColor(d.donor), Colors.black, 0.18)!]), shape: BoxShape.circle),
                            child: Center(child: Text(_initials(d.donor), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)))),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(d.donor, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, height: 1, color: context.textPrimary)),
                            const SizedBox(height: 3),
                            Row(children: [
                              Container(width: 8, height: 8, decoration: BoxDecoration(color: typeColor, borderRadius: BorderRadius.circular(2))),
                              const SizedBox(width: 6),
                              Text('${d.type} · ${d.method}', style: TextStyle(fontSize: 12.5, color: context.textSub, fontWeight: FontWeight.w500)),
                            ]),
                            Text(d.receipt, style: TextStyle(fontSize: 11, color: context.textHint, fontWeight: FontWeight.w500)),
                          ])),
                          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                            Text(_inr(d.amount), style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: _brand700)),
                            if (isOld) const SizedBox(height: 3),
                            if (isOld) const Row(children: [Icon(Icons.access_time, size: 11, color: _amber600), SizedBox(width: 3), Text('Follow up', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _amber600))]),
                          ]),
                        ]),
                        const SizedBox(height: 8),
                        Row(children: [
                          _ActBtn(icon: Icons.call_outlined, label: 'Call', color: _brand600, onTap: () => _launchUrl('tel:+919900000001', context)),
                          const SizedBox(width: 7),
                          _ActBtn(icon: Icons.message_outlined, label: 'WhatsApp', color: const Color(0xFF25D366), onTap: () => _launchUrl('https://wa.me/919900000001', context)),
                          const SizedBox(width: 7),
                          _ActBtn(icon: Icons.email_outlined, label: 'Email', color: _sky500, onTap: () => _launchUrl('mailto:donor@example.com', context)),
                        ]),
                      ]),
                    );
                  }).toList())),
              ]))),
            const SizedBox(height: 80),
          ]),
        )),
      ]),
    );
  }
}

void _launchUrl(String url, BuildContext context) {
  if (url.startsWith('tel:')) {
    launchPhone(url.substring(4), context);
  } else if (url.startsWith('https://wa.me')) {
    launchLink(url, context);
  } else if (url.startsWith('mailto:')) {
    launchEmail(url.substring(7), context);
  } else {
    launchLink(url, context);
  }
}

class _RangeSummary { const _RangeSummary({required this.total, required this.count, required this.donors, required this.avg}); final int total, count, donors, avg; }

class _SumStat extends StatelessWidget {
  const _SumStat(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
    Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
  ]);
}

class _ActBtn extends StatelessWidget {
  const _ActBtn({required this.icon, required this.label, required this.color, required this.onTap});
  final IconData icon; final String label; final Color color; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Expanded(child: GestureDetector(onTap: onTap,
    child: Container(padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 14, color: color), const SizedBox(width: 4), Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: color))]))));
}
