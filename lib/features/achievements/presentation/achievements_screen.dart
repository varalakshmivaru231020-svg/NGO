import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/api_client.dart';

const _brand700 = Color(0xFFE07C1F);
const _brand600 = Color(0xFFFF9933);
const _brand100 = Color(0xFFFFE8CC);
const _amber600 = Color(0xFFE0921A);
const _amber100 = Color(0xFFFFF1D6);
const _coral500 = Color(0xFFF2685E);
const _coral100 = Color(0xFFFFE3DF);
const _violet500 = Color(0xFF7C6CF0);
const _violet100 = Color(0xFFE7E3FD);
const _sky500 = Color(0xFF2D9CDB);
const _sky100 = Color(0xFFDCEFFB);

// Display label ↔ backend enum (kept in sync with the per-student
// Achievements tab in student_detail_screen.dart).
const _catBack = {'Arts': 'ARTS', 'Sports': 'SPORTS', 'Academics': 'ACADEMICS', 'Community': 'COMMUNITY', 'Leadership': 'LIFE_SKILLS', 'Other': 'OTHER'};
const _catDisplay = {'ARTS': 'Arts', 'SPORTS': 'Sports', 'ACADEMICS': 'Academics', 'COMMUNITY': 'Community', 'LIFE_SKILLS': 'Leadership', 'OTHER': 'Other'};

class _Ach {
  _Ach({required this.id, required this.studentId, required this.student, required this.title, required this.desc,
    required this.cat, required this.date});
  final String id, studentId, student, title, desc, cat;
  final DateTime date;

  factory _Ach.fromJson(Map<String, dynamic> j) {
    final student = (j['student'] as Map?)?.cast<String, dynamic>();
    return _Ach(
      id: j['id'] as String? ?? '',
      studentId: j['studentId'] as String? ?? student?['id'] as String? ?? '',
      student: student?['name'] as String? ?? 'Unknown Student',
      title: j['title'] as String? ?? '',
      desc: j['description'] as String? ?? '',
      cat: _catDisplay[j['category'] as String? ?? ''] ?? 'Other',
      date: DateTime.tryParse(j['date'] as String? ?? '') ?? DateTime.now(),
    );
  }

  String get dateLabel {
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${date.day.toString().padLeft(2,'0')} ${months[date.month-1]} ${date.year}';
  }
}

const _cats = ['All', 'Arts', 'Sports', 'Academics', 'Community', 'Leadership', 'Other'];

const _catColors = {
  'Sports':     (_sky500, _sky100),
  'Academics':  (_violet500, _violet100),
  'Arts':       (_coral500, _coral100),
  'Community':  (_brand600, _brand100),
  'Leadership': (_amber600, _amber100),
  'Other':      (_amber600, _amber100),
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
  String _search = '';
  List<_Ach> _items = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final r = await apiClient.get('/achievements', params: {'limit': '100'});
      final inner = r['data'];
      final list = inner is Map ? (inner['data'] as List<dynamic>? ?? const []) : (inner is List ? inner : const []);
      final items = list.whereType<Map>().map((m) => _Ach.fromJson(m.cast<String, dynamic>())).toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      if (mounted) setState(() { _items = items; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<_Ach> get _filtered {
    var list = _items;
    if (_cat != 'All') list = list.where((a) => a.cat == _cat).toList();
    if (_search.trim().isNotEmpty) {
      final q = _search.trim().toLowerCase();
      list = list.where((a) => a.title.toLowerCase().contains(q) || a.student.toLowerCase().contains(q)).toList();
    }
    return list;
  }

  Future<Map<String, dynamic>?> _pickStudent() => showModalBottomSheet<Map<String, dynamic>>(
    context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
    builder: (ctx) => _StudentPickerSheet(),
  );

  Future<void> _showLogDialog() async {
    Map<String, dynamic>? student;
    final titleCtrl   = TextEditingController();
    final descCtrl    = TextEditingController();
    String selectedCat = 'Sports';
    DateTime date = DateTime.now();
    bool saving = false;

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
            Text('Student', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ctx.textSub)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () async {
                final picked = await _pickStudent();
                if (picked != null) setSheet(() => student = picked);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                decoration: BoxDecoration(color: ctx.surface2, borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  Icon(Icons.person_search_outlined, color: ctx.textHint, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(
                    student != null ? '${student?['name']} (${student?['childId'] ?? ''})' : 'Tap to select a student',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: student != null ? ctx.textPrimary : ctx.textHint))),
                  Icon(Icons.chevron_right, color: ctx.textHint),
                ]),
              ),
            ),
            const SizedBox(height: 14),
            _sheetField(ctx, titleCtrl, 'Achievement Title', Icons.emoji_events_outlined),
            const SizedBox(height: 14),
            _sheetField(ctx, descCtrl, 'Description', Icons.notes_outlined, maxLines: 3),
            const SizedBox(height: 14),
            Text('Date', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ctx.textSub)),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () async {
                final picked = await showDatePicker(context: ctx, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime.now());
                if (picked != null) setSheet(() => date = picked);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                decoration: BoxDecoration(color: ctx.surface2, borderRadius: BorderRadius.circular(14)),
                child: Row(children: [
                  Icon(Icons.calendar_today_outlined, color: ctx.textHint, size: 18),
                  const SizedBox(width: 10),
                  Text(_Ach(id: '', studentId: '', student: '', title: '', desc: '', cat: 'Other', date: date).dateLabel,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: ctx.textPrimary)),
                ]),
              ),
            ),
            const SizedBox(height: 14),
            Text('Category', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ctx.textSub)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: _cats.where((c) => c != 'All').map((c) {
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
              onPressed: saving ? null : () async {
                final title = titleCtrl.text.trim();
                if (student == null || title.isEmpty) return;
                setSheet(() => saving = true);
                try {
                  await apiClient.post('/achievements', {
                    'studentId': student!['id'],
                    'title': title,
                    'description': descCtrl.text.trim(),
                    'category': _catBack[selectedCat] ?? 'OTHER',
                    'date': date.toIso8601String(),
                  });
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  await _load();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Achievement logged for ${student?['name']}!', style: const TextStyle(fontWeight: FontWeight.w700)),
                      backgroundColor: _brand600, behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
                  }
                } catch (_) {
                  setSheet(() => saving = false);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: const Text('Could not save achievement. Please try again.', style: TextStyle(fontWeight: FontWeight.w700)),
                      backgroundColor: _coral500, behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: _brand600, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
              child: saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : const Text('Save Achievement', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
            )),
          ])),
        );
      }),
    );
  }

  Future<void> _delete(_Ach a) async {
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text('Delete Achievement?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      content: Text('This will permanently remove "${a.title}".', style: const TextStyle(fontSize: 13.5)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: _coral500, fontWeight: FontWeight.w700))),
      ],
    ));
    if (confirmed != true) return;
    try { await apiClient.delete('/achievements/${a.id}'); } catch (_) {}
    await _load();
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
            TextField(
              onChanged: (v) => setState(() => _search = v),
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: context.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search by title or student…', isDense: true,
                prefixIcon: Icon(Icons.search, size: 18, color: context.textHint),
                filled: true, fillColor: context.surface2,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 10),
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

        Expanded(child: _loading
          ? ListView(padding: const EdgeInsets.fromLTRB(18, 16, 18, 100),
              children: List.generate(3, (_) => Padding(padding: const EdgeInsets.only(bottom: 12),
                child: Container(height: 120, decoration: BoxDecoration(color: context.surface2, borderRadius: BorderRadius.circular(20))))))
          : items.isEmpty
          ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('🏆', style: TextStyle(fontSize: 42)),
              const SizedBox(height: 12),
              Text(_items.isEmpty ? 'No achievements logged yet' : 'No matching achievements', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: context.textHint)),
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
                return _AchCard(ach: a, catColor: catColor, catBg: catBg, isFirst: i == 0, isLast: i == items.length - 1, onDelete: () => _delete(a));
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

// Search-by-name-or-childId student picker, backed by the real API.
class _StudentPickerSheet extends StatefulWidget {
  @override
  State<_StudentPickerSheet> createState() => _StudentPickerSheetState();
}

class _StudentPickerSheetState extends State<_StudentPickerSheet> {
  List<Map<String, dynamic>> _all = [];
  bool _loading = true;
  String _search = '';

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final r = await apiClient.get('/students', params: {'limit': '100'});
      final inner = r['data'];
      final list = inner is Map ? (inner['data'] as List<dynamic>? ?? const []) : (inner is List ? inner : const []);
      final students = list.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
      if (mounted) setState(() { _all = students; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_search.trim().isEmpty) return _all;
    final q = _search.trim().toLowerCase();
    return _all.where((s) =>
      (s['name'] as String? ?? '').toLowerCase().contains(q) ||
      (s['childId'] as String? ?? '').toLowerCase().contains(q)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(color: context.cardBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(20, 14, 20, 10), child: Row(children: [
          Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: context.border, borderRadius: BorderRadius.circular(2)))),
          const Spacer(),
          Text('Select Student', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: context.textPrimary)),
          const Spacer(),
          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
        ])),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 18), child: TextField(
          autofocus: true,
          onChanged: (v) => setState(() => _search = v),
          style: TextStyle(fontSize: 14, color: context.textPrimary),
          decoration: InputDecoration(
            hintText: 'Search by name or child ID…', isDense: true,
            prefixIcon: Icon(Icons.search, size: 18, color: context.textHint),
            filled: true, fillColor: context.surface2,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        )),
        const SizedBox(height: 8),
        Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator(color: _brand600))
          : items.isEmpty
          ? Center(child: Padding(padding: const EdgeInsets.all(24),
              child: Text('No students found.', style: TextStyle(fontSize: 13.5, color: context.textHint, fontWeight: FontWeight.w500))))
          : ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final s = items[i];
                final name = (s['name'] ?? '') as String;
                final childId = (s['childId'] ?? '') as String;
                final centre = ((s['center'] as Map?)?['name'] ?? '') as String;
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 6),
                  leading: Container(width: 44, height: 44,
                    decoration: BoxDecoration(color: _avColor(name).withValues(alpha: 0.15), shape: BoxShape.circle),
                    child: Center(child: Text(_initials(name), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _avColor(name))))),
                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                  subtitle: Text(centre.isNotEmpty ? '$childId · $centre' : childId, style: TextStyle(fontSize: 12.5, color: context.textHint)),
                  onTap: () => Navigator.pop(context, s),
                );
              },
            )),
      ]),
    );
  }
}

class _AchCard extends StatelessWidget {
  const _AchCard({required this.ach, required this.catColor, required this.catBg, required this.isFirst, required this.isLast, required this.onDelete});
  final _Ach ach; final Color catColor, catBg; final bool isFirst, isLast; final VoidCallback onDelete;

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
      // card — tap to open the student's profile
      Expanded(child: GestureDetector(
        onTap: ach.studentId.isNotEmpty ? () => context.go('/students/${ach.studentId}') : null,
        child: Container(
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
            GestureDetector(onTap: onDelete, child: Padding(padding: const EdgeInsets.only(left: 8),
              child: Icon(Icons.delete_outline, size: 17, color: context.textHint))),
          ]),
          const SizedBox(height: 10),
          Text(ach.title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: -0.2, color: context.textPrimary)),
          if (ach.desc.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(ach.desc, style: TextStyle(fontSize: 13, color: context.textSub, fontWeight: FontWeight.w500, height: 1.45)),
          ],
          const SizedBox(height: 10),
          // footer
          Row(children: [
            Icon(Icons.calendar_today_outlined, size: 12, color: context.textHint),
            const SizedBox(width: 4),
            Text(ach.dateLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.textHint)),
            const Spacer(),
            if (ach.studentId.isNotEmpty) Row(children: [
              Icon(Icons.chevron_right, size: 14, color: context.textHint),
              Text('View profile', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: context.textHint)),
            ]),
          ]),
        ]),
      ))),
    ]));
  }
}
