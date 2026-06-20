import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

const _brand700 = Color(0xFF0B6E5D);
const _brand600 = Color(0xFF0E8C76);
const _brand100 = Color(0xFFD6F3EC);
const _amber600 = Color(0xFFE0921A);
const _amber100 = Color(0xFFFFF1D6);
const _coral500 = Color(0xFFF2685E);
const _coral100 = Color(0xFFFFE3DF);
const _violet500 = Color(0xFF7C6CF0);
const _violet100 = Color(0xFFE7E3FD);
const _sky500 = Color(0xFF2D9CDB);
const _sky100 = Color(0xFFDCEFFB);

class _Ach {
  _Ach({required this.id, required this.student, required this.title, required this.desc,
    required this.cat, required this.date, required this.hasMedia, required this.hasCert});
  final String id, student, title, desc, cat, date;
  final bool hasMedia, hasCert;
}

final _achievements = [
  _Ach(id:'a1', student:'Imran Qureshi',  title:'Gold Medal – District Athletics',  desc:'Won gold in the 100m sprint at District School Athletics 2026, clocking 11.2 seconds.',     cat:'Sports',    date:'02 Jun 2026', hasMedia:true,  hasCert:true),
  _Ach(id:'a2', student:'Diya Reddy',     title:'State Science Olympiad – Rank 3',   desc:'Secured 3rd rank across Karnataka in the State-level Science Olympiad, Class 9 category.',  cat:'Academics', date:'28 May 2026', hasMedia:false, hasCert:true),
  _Ach(id:'a3', student:'Ravi Kumar',     title:'Classical Dance Recital',           desc:'Performed Bharatanatyam at the Rajyotsava Cultural Evening, received standing ovation.',      cat:'Arts',      date:'21 May 2026', hasMedia:true,  hasCert:false),
  _Ach(id:'a4', student:'Ananya Patil',   title:'Zero Attendance Miss – 12 Months',  desc:'Maintained 100% attendance for an entire academic year, a first in Sulibele centre.',       cat:'Discipline', date:'15 May 2026', hasMedia:false, hasCert:true),
  _Ach(id:'a5', student:'Rohan Gowda',    title:'SSLC Distinction',                  desc:'Scored 94.6% in SSLC board exams; highest in Medahalli centre history.',                      cat:'Academics', date:'10 May 2026', hasMedia:true,  hasCert:true),
];

const _cats = ['All', 'Sports', 'Academics', 'Arts', 'Discipline'];

const _catColors = {
  'Sports':     (_sky500, _sky100),
  'Academics':  (_violet500, _violet100),
  'Arts':       (_coral500, _coral100),
  'Discipline': (_amber600, _amber100),
};

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

// ══════════════════════════════════════════════════════════════════════
class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});
  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  String _cat = 'All';
  final List<_Ach> _items = List.from(_achievements);

  List<_Ach> get _filtered => _cat == 'All' ? _items : _items.where((a) => a.cat == _cat).toList();

  Future<void> _showLogDialog() async {
    final studentCtrl = TextEditingController();
    final titleCtrl   = TextEditingController();
    final descCtrl    = TextEditingController();
    String selectedCat = 'Sports';

    await showModalBottomSheet(
      context: context, isScrollControlled: true, useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
        return Container(
          decoration: BoxDecoration(color: ctx.cardBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
          padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 36, height: 4, margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: ctx.border, borderRadius: BorderRadius.circular(2)))),
            Text('Log Achievement', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: ctx.textPrimary)),
            const SizedBox(height: 20),
            _sheetField(ctx, studentCtrl, 'Student Name', Icons.person_outline),
            const SizedBox(height: 14),
            _sheetField(ctx, titleCtrl, 'Achievement Title', Icons.emoji_events_outlined),
            const SizedBox(height: 14),
            _sheetField(ctx, descCtrl, 'Description', Icons.notes_outlined, maxLines: 3),
            const SizedBox(height: 14),
            Text('Category', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ctx.textSub)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: ['Sports','Academics','Arts','Discipline'].map((c) {
              final colors = _catColors[c]!;
              final active = selectedCat == c;
              return GestureDetector(
                onTap: () => setSheet(() => selectedCat = c),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: active ? colors.$2 : ctx.cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: active ? colors.$1 : ctx.border),
                  ),
                  child: Text(c, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: active ? colors.$1 : ctx.textSub)),
                ),
              );
            }).toList()),
            const SizedBox(height: 24),
            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: () {
                final student = studentCtrl.text.trim();
                final title   = titleCtrl.text.trim();
                final desc    = descCtrl.text.trim();
                if (student.isEmpty || title.isEmpty) return;
                final newAch = _Ach(
                  id: 'a${DateTime.now().millisecondsSinceEpoch}',
                  student: student, title: title,
                  desc: desc.isEmpty ? 'No description provided.' : desc,
                  cat: selectedCat, date: _today(), hasMedia: false, hasCert: false,
                );
                Navigator.of(ctx).pop();
                setState(() => _items.insert(0, newAch));
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Achievement logged for $student!', style: const TextStyle(fontWeight: FontWeight.w700)),
                  backgroundColor: _brand600, behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
              },
              style: ElevatedButton.styleFrom(backgroundColor: _brand600, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: const Text('Save Achievement', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
            )),
          ])),
        );
      }),
    );
  }

  static Widget _sheetField(BuildContext ctx, TextEditingController ctrl, String hint, IconData icon, {int maxLines = 1}) => TextField(
    controller: ctrl, maxLines: maxLines,
    decoration: InputDecoration(
      hintText: hint, prefixIcon: Icon(icon, color: ctx.textHint, size: 20),
      filled: true, fillColor: ctx.surface2,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    ),
  );

  static String _today() {
    final now = DateTime.now();
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${now.day.toString().padLeft(2,'0')} ${months[now.month-1]} ${now.year}';
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final items = _filtered;

    return Scaffold(
      body: Column(children: [
        Container(color: context.headerBg, padding: EdgeInsets.fromLTRB(18, top + 14, 18, 14),
          child: Column(children: [
            Row(children: [
              IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20), onPressed: () => context.go('/more'), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Student Achievements', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: context.textPrimary)),
                Text('Milestones & recognition', style: TextStyle(fontSize: 13, color: context.textSub, fontWeight: FontWeight.w600)),
              ])),
              Container(padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                decoration: BoxDecoration(color: _amber100, borderRadius: BorderRadius.circular(10)),
                child: Row(children: [
                  const Icon(Icons.emoji_events_outlined, size: 14, color: _amber600),
                  const SizedBox(width: 5),
                  Text('${_items.length} Total', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _amber600)),
                ])),
            ]),
            const SizedBox(height: 12),
            // category filter
            SizedBox(height: 36, child: ListView(scrollDirection: Axis.horizontal, children: _cats.map((c) {
              final active = _cat == c;
              final colors = _catColors[c];
              final color = active ? (colors?.$1 ?? _brand600) : context.textSub;
              final bg = active ? (colors?.$2 ?? _brand100) : context.cardBg;
              return Padding(padding: const EdgeInsets.only(right: 8), child: GestureDetector(
                onTap: () => setState(() => _cat = c),
                behavior: HitTestBehavior.opaque,
                child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12), border: Border.all(color: active ? color : context.border)),
                  child: Text(c, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: color)))));
            }).toList())),
          ])),

        Expanded(child: items.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('🏆', style: TextStyle(fontSize: 42)),
              const SizedBox(height: 12),
              Text('No achievements in this category', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: context.textHint)),
            ]))
          : ListView.separated(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 100),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) {
                final a = items[i];
                final colors = _catColors[a.cat];
                final catColor = colors?.$1 ?? _brand600;
                final catBg = colors?.$2 ?? _brand100;
                return _AchCard(ach: a, catColor: catColor, catBg: catBg, isFirst: i == 0, isLast: i == items.length - 1);
              })),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showLogDialog,
        backgroundColor: _brand600,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Log Achievement', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _AchCard extends StatelessWidget {
  const _AchCard({required this.ach, required this.catColor, required this.catBg, required this.isFirst, required this.isLast});
  final _Ach ach; final Color catColor, catBg; final bool isFirst, isLast;

  @override
  Widget build(BuildContext context) {
    final color = _avColor(ach.student);
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // timeline
      Column(mainAxisSize: MainAxisSize.max, children: [
        Container(width: 14, height: 14,
          decoration: BoxDecoration(color: catColor, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2),
            boxShadow: [BoxShadow(color: catColor.withValues(alpha: 0.35), blurRadius: 6, offset: const Offset(0, 2))])),
        if (!isLast) Expanded(child: Container(width: 2, color: context.border)),
      ]),
      const SizedBox(width: 12),
      // card
      Expanded(child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: context.border),
          boxShadow: const [BoxShadow(color: Color(0x080D2822), blurRadius: 6, offset: Offset(0, 2))]),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // student + category
          Row(children: [
            Container(width: 34, height: 34,
              decoration: BoxDecoration(gradient: LinearGradient(colors: [color, Color.lerp(color, Colors.black, 0.18)!]), shape: BoxShape.circle),
              child: Center(child: Text(_initials(ach.student), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)))),
            const SizedBox(width: 9),
            Expanded(child: Text(ach.student, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: context.textPrimary))),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: catBg, borderRadius: BorderRadius.circular(8)),
              child: Text(ach.cat, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: catColor))),
          ]),
          const SizedBox(height: 10),
          Text(ach.title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: -0.2, color: context.textPrimary)),
          const SizedBox(height: 5),
          Text(ach.desc, style: TextStyle(fontSize: 13, color: context.textSub, fontWeight: FontWeight.w500, height: 1.45)),
          const SizedBox(height: 10),
          // media thumbnails
          if (ach.hasMedia) Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [
            Container(width: 64, height: 48, decoration: BoxDecoration(color: catBg, borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.photo_outlined, color: catColor, size: 22)),
            const SizedBox(width: 7),
            Container(width: 64, height: 48, decoration: BoxDecoration(color: catBg, borderRadius: BorderRadius.circular(10)),
              child: Icon(Icons.videocam_outlined, color: catColor, size: 22)),
            const SizedBox(width: 7),
            GestureDetector(
              onTap: () {},
              child: Container(width: 48, height: 48, decoration: BoxDecoration(color: context.surface2, borderRadius: BorderRadius.circular(10)),
                child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.add, size: 16, color: context.textHint),
                  Text('Add', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: context.textHint)),
                ]))),
          ])),
          // footer
          Row(children: [
            Icon(Icons.calendar_today_outlined, size: 12, color: context.textHint),
            const SizedBox(width: 4),
            Text(ach.date, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.textHint)),
            const Spacer(),
            if (ach.hasCert) Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(color: _amber100, borderRadius: BorderRadius.circular(7)),
              child: const Row(children: [
                Icon(Icons.workspace_premium_outlined, size: 12, color: _amber600),
                SizedBox(width: 4),
                Text('Certificate', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: _amber600)),
              ])),
          ]),
        ]),
      )),
    ]));
  }
}
