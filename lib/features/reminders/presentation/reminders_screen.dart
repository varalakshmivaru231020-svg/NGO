import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/api_client.dart';

const _brand600 = Color(0xFFFF9933);
const _brand100 = Color(0xFFFFE8CC);
const _amber600 = Color(0xFFE0921A);
const _amber100 = Color(0xFFFFF1D6);
const _coral500 = Color(0xFFF2685E);
const _violet500 = Color(0xFF7C6CF0);
const _violet100 = Color(0xFFE7E3FD);
const _sky500 = Color(0xFF2D9CDB);
const _onSurface2 = Color(0xFF5A6B67);
const _onSurface3 = Color(0xFF93A29F);
const _border = Color(0xFFE5EBE9);
const _surface2 = Color(0xFFF4F7F6);

const _months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
String _fmtDayMonthYear(DateTime d) => '${d.day.toString().padLeft(2, '0')} ${_months[d.month - 1]} ${d.year}';

// ── data ──────────────────────────────────────────────────────────────
// Backed by GET /reminders/upcoming-birthdays and /reminders/upcoming-anniversaries
// — real donor + student dob/anniversary fields projected onto their next
// occurrence, not hardcoded sample data.
class _Reminder {
  const _Reminder({required this.id, required this.name, required this.type, required this.date,
    required this.count, required this.mobile, required this.isBday, required this.daysUntil});
  final String id, name, type, date, mobile;
  final int count;
  final bool isBday;
  final int daysUntil;

  factory _Reminder.fromBirthdayJson(Map<String, dynamic> j) {
    final dt = DateTime.tryParse(j['date'] as String? ?? '') ?? DateTime.now();
    final today = DateTime.now();
    final todayMid = DateTime(today.year, today.month, today.day);
    return _Reminder(
      id: j['id'] as String? ?? '',
      name: j['name'] as String? ?? '',
      type: j['type'] as String? ?? 'Donor',
      date: _fmtDayMonthYear(dt),
      count: j['turningAge'] as int? ?? 0,
      mobile: j['mobile'] as String? ?? '',
      isBday: true,
      daysUntil: dt.difference(todayMid).inDays,
    );
  }

  factory _Reminder.fromAnniversaryJson(Map<String, dynamic> j) {
    final dt = DateTime.tryParse(j['date'] as String? ?? '') ?? DateTime.now();
    final today = DateTime.now();
    final todayMid = DateTime(today.year, today.month, today.day);
    return _Reminder(
      id: j['id'] as String? ?? '',
      name: j['name'] as String? ?? '',
      type: j['type'] as String? ?? 'Donor',
      date: _fmtDayMonthYear(dt),
      count: j['years'] as int? ?? 0,
      mobile: j['mobile'] as String? ?? '',
      isBday: false,
      daysUntil: dt.difference(todayMid).inDays,
    );
  }
}

const _ranges = ['Today', 'This week', 'This month'];

String _rangeOf(_Reminder r) {
  if (r.daysUntil <= 0) return 'Today';
  if (r.daysUntil <= 7) return 'This week';
  if (r.daysUntil <= 31) return 'This month';
  return 'Future';
}

Color _avColor(String seed) {
  final palette = [_brand600, const Color(0xFFF6A723), _violet500, _sky500, const Color(0xFFEC5B8B), _coral500, const Color(0xFF14A98C)];
  int h = 0;
  for (int i = 0; i < seed.length; i++) { h = ((h * 31) + seed.codeUnitAt(i)) & 0xFFFFFFFF; }
  return palette[h % palette.length];
}
String _initials(String name) {
  final p = name.trim().split(RegExp(r'\s+'));
  return ((p[0].isNotEmpty ? p[0][0] : '') + (p.length > 1 && p[1].isNotEmpty ? p[1][0] : '')).toUpperCase();
}

// ══════════════════════════════════════════════════════════════════════
class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key});
  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

class _RemindersScreenState extends State<RemindersScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  String _range = 'Today';
  bool _loading = true;
  bool _error = false;
  List<_Reminder> _birthdays = [];
  List<_Reminder> _anniversaries = [];

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() => setState(() {}));
    _load();
  }
  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = false; });
    try {
      final results = await Future.wait([
        apiClient.get('/reminders/upcoming-birthdays', params: {'days': '31'}),
        apiClient.get('/reminders/upcoming-anniversaries', params: {'days': '31'}),
      ]);
      final bRaw = results[0]['data'];
      final bList = bRaw is List ? bRaw : const [];
      final aRaw = results[1]['data'];
      final aList = aRaw is List ? aRaw : const [];
      if (mounted) setState(() {
        _birthdays = bList.whereType<Map>().map((m) => _Reminder.fromBirthdayJson(m.cast<String, dynamic>())).toList();
        _anniversaries = aList.whereType<Map>().map((m) => _Reminder.fromAnniversaryJson(m.cast<String, dynamic>())).toList();
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = true; });
    }
  }

  List<_Reminder> _filter(List<_Reminder> list) {
    final order = {'Today': 1, 'This week': 2, 'This month': 3};
    final max = order[_range]!;
    return list.where((r) => (order[_rangeOf(r)] ?? 99) <= max).toList();
  }

  static Future<void> _call(String mobile) async {
    final digits = mobile.replaceAll(RegExp(r'[^\d+]'), '');
    if (digits.isEmpty) return;
    final uri = Uri.parse('tel:$digits');
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  static Future<void> _whatsapp(String mobile) async {
    final digits = mobile.replaceAll(RegExp(r'[^\d]'), '');
    if (digits.isEmpty) return;
    final uri = Uri.parse('https://wa.me/$digits');
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final isBdayTab = _tabs.index == 0;
    final todayCount = isBdayTab
        ? _birthdays.where((b) => _rangeOf(b) == 'Today').length
        : _anniversaries.where((a) => _rangeOf(a) == 'Today').length;

    return Scaffold(
      backgroundColor: _surface2,
      body: Column(children: [
        // header
        Container(
          color: context.headerBg,
          padding: EdgeInsets.fromLTRB(18, top + 14, 18, 0),
          child: Column(children: [
            Row(children: [
              IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20), onPressed: () => context.go('/more'), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
              const SizedBox(width: 10),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Reminders', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                Text('Birthdays & anniversaries', style: TextStyle(fontSize: 13, color: _onSurface2, fontWeight: FontWeight.w600)),
              ])),
              IconButton(icon: const Icon(Icons.refresh_rounded, size: 20), onPressed: _loading ? null : _load, padding: EdgeInsets.zero, constraints: const BoxConstraints()),
            ]),
            const SizedBox(height: 12),
            // celebration banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFE0921A), Color(0xFFF6A723)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(children: [
                Container(width: 46, height: 46, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.22), shape: BoxShape.circle),
                  child: const Center(child: Text('🎉', style: TextStyle(fontSize: 22)))),
                const SizedBox(width: 13),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('$todayCount Celebrations Today!', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  const Text('Reach out and spread joy 💛', style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w600)),
                ])),
              ]),
            ),
            const SizedBox(height: 14),
            // tabs
            TabBar(
              controller: _tabs,
              indicatorColor: _brand600,
              indicatorWeight: 3,
              labelColor: _brand600,
              unselectedLabelColor: _onSurface3,
              labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              tabs: const [Tab(text: '🎂  Birthdays'), Tab(text: '💍  Anniversaries')],
            ),
          ]),
        ),

        // range chips with counts
        Container(
          color: Colors.white,
          child: Column(children: [
            SizedBox(height: 44, child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 6),
              children: _ranges.map((r) {
                final active = _range == r;
                final order = {'Today': 1, 'This week': 2, 'This month': 3};
                final max = order[r]!;
                final isBdayTab = _tabs.index == 0;
                final bdayCount = isBdayTab ? _birthdays.where((b) => (order[_rangeOf(b)] ?? 99) <= max).length : 0;
                final annivCount = isBdayTab ? 0 : _anniversaries.where((a) => (order[_rangeOf(a)] ?? 99) <= max).length;
                final total = bdayCount + annivCount;
                return Padding(padding: const EdgeInsets.only(right: 8), child: GestureDetector(
                  onTap: () => setState(() => _range = r),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: active ? _brand600 : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: active ? _brand600 : _border, width: 1.5)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(r, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: active ? Colors.white : _onSurface2)),
                      if (total > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: active ? Colors.white.withValues(alpha: 0.3) : _amber600.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('$total', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: active ? Colors.white : _amber600)),
                        ),
                      ],
                    ]),
                  ),
                ));
              }).toList(),
            )),
            const SizedBox(height: 8),
          ]),
        ),

        // tab views
        Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator(color: _brand600))
          : _error
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.error_outline, color: _coral500, size: 40),
                const SizedBox(height: 10),
                Text('Failed to load reminders', style: TextStyle(fontWeight: FontWeight.w700, color: context.textPrimary)),
                const SizedBox(height: 8),
                TextButton(onPressed: _load, child: const Text('Retry', style: TextStyle(color: _brand600, fontWeight: FontWeight.w700))),
              ]))
            : TabBarView(
                controller: _tabs,
                children: [
                  _ReminderList(items: _filter(_birthdays), isBday: true, onCall: _call, onWhatsApp: _whatsapp),
                  _ReminderList(items: _filter(_anniversaries), isBday: false, onCall: _call, onWhatsApp: _whatsapp),
                ],
              )),
      ]),
    );
  }
}

class _ReminderList extends StatelessWidget {
  const _ReminderList({required this.items, required this.isBday, required this.onCall, required this.onWhatsApp});
  final List<_Reminder> items;
  final bool isBday;
  final Future<void> Function(String) onCall;
  final Future<void> Function(String) onWhatsApp;
  @override
  Widget build(BuildContext context) => items.isEmpty
    ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Text(isBday ? '🎂' : '💍', style: const TextStyle(fontSize: 42)),
        const SizedBox(height: 12),
        const Text('Nothing in this range', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _onSurface3)),
      ]))
    : SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 100),
        child: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(),
          child: Column(children: items.asMap().entries.map((e) => Padding(
            padding: EdgeInsets.only(bottom: e.key < items.length - 1 ? 10 : 0),
            child: _ReminderCard(item: e.value, isBday: isBday, onCall: onCall, onWhatsApp: onWhatsApp),
          )).toList()),
        )),
      );
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({required this.item, required this.isBday, required this.onCall, required this.onWhatsApp});
  final _Reminder item;
  final bool isBday;
  final Future<void> Function(String) onCall;
  final Future<void> Function(String) onWhatsApp;

  @override
  Widget build(BuildContext context) {
    final color = _avColor(item.name);
    final isToday = _rangeOf(item) == 'Today';
    return Container(
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: isToday ? _amber600.withValues(alpha: 0.4) : _border),
        boxShadow: const [BoxShadow(color: Color(0x0A0D2822), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(14, 14, 14, 10), child: Row(children: [
          Stack(children: [
            Container(width: 50, height: 50,
              decoration: BoxDecoration(gradient: LinearGradient(colors: [color, Color.lerp(color, Colors.black, 0.2)!]), shape: BoxShape.circle),
              child: Center(child: Text(_initials(item.name), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)))),
            Positioned(bottom: 0, right: 0,
              child: Container(width: 18, height: 18, decoration: BoxDecoration(color: isBday ? _amber600 : const Color(0xFFEC5B8B), shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                child: Center(child: Text(isBday ? '🎂' : '💍', style: const TextStyle(fontSize: 9))))),
          ]),
          const SizedBox(width: 13),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(item.name, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, letterSpacing: -0.2), overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 7),
              Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(color: item.type == 'Donor' ? _brand100 : _violet100, borderRadius: BorderRadius.circular(6)),
                child: Text(item.type, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: item.type == 'Donor' ? _brand600 : _violet500))),
            ]),
            const SizedBox(height: 4),
            Text(isBday ? 'Turning ${item.count}' : '${item.count} years together', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _onSurface2)),
            Text(item.date, style: const TextStyle(fontSize: 12, color: _onSurface3, fontWeight: FontWeight.w500)),
          ])),
          if (isToday)
            Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(color: _amber100, borderRadius: BorderRadius.circular(10), border: Border.all(color: _amber600.withValues(alpha: 0.4))),
              child: const Text('Today', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _amber600))),
        ])),
        const Divider(height: 1, color: _border),
        Padding(padding: const EdgeInsets.fromLTRB(14, 8, 14, 10), child: Row(children: [
          _ActionBtn(icon: Icons.call_outlined, label: 'Call', color: _brand600, onTap: () => onCall(item.mobile)),
          const SizedBox(width: 8),
          _ActionBtn(icon: Icons.message_outlined, label: 'WhatsApp', color: const Color(0xFF25D366), onTap: () => onWhatsApp(item.mobile)),
        ])),
      ]),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({required this.icon, required this.label, required this.color, required this.onTap});
  final IconData icon; final String label; final Color color; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Expanded(child: GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, size: 15, color: color), const SizedBox(width: 5), Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color))]),
    ),
  ));
}
