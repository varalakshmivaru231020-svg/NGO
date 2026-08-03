import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';

// ── colours ───────────────────────────────────────────────────────────
const _brand600  = Color(0xFFFF9933);
const _brand100  = Color(0xFFFFE8CC);
const _violet500 = Color(0xFF7C6CF0);
const _violet100 = Color(0xFFE7E3FD);
const _amber600  = Color(0xFFE0921A);
const _amber100  = Color(0xFFFFF1D6);
const _coral500  = Color(0xFFF2685E);
const _coral100  = Color(0xFFFFE3DF);
const _onSurface2 = Color(0xFF5A6B67);

// ── API model ─────────────────────────────────────────────────────────
String _sponsorFromJson(Map<String, dynamic> j) {
  final list = j['sponsorships'] as List<dynamic>?;
  if (list == null || list.isEmpty) return '';
  final first = list.first as Map<String, dynamic>;
  final donor = first['donor'] as Map<String, dynamic>?;
  return donor?['name'] as String? ?? '';
}

String _centreFromJson(Map<String, dynamic> j) {
  final center = j['center'] as Map<String, dynamic>?;
  return center?['name'] as String? ?? '';
}

class _Student {
  _Student({required this.id, required this.childId, required this.name,
    required this.gender, required this.dobRaw, required this.status,
    required this.classGrade, required this.school,
    required this.centreName, required this.sponsorName, this.category = '', this.photo});

  factory _Student.fromJson(Map<String, dynamic> j) => _Student(
    id:         j['id']      as String,
    childId:    j['childId'] as String? ?? '',
    name:       j['name']    as String,
    gender:     j['gender']  as String? ?? 'MALE',
    dobRaw:     j['dob']     as String? ?? '',
    status:     j['status']  as String? ?? 'ACTIVE',
    classGrade: j['class']   as String? ?? '',
    school:     j['school']  as String? ?? '',
    centreName:  _centreFromJson(j),
    sponsorName: _sponsorFromJson(j),
    category:   ((j['category'] as Map?)?['label'] ?? '').toString(),
    photo:      j['photo']   as String?,
  );

  final String id, childId, name, gender, dobRaw, status, classGrade, school, centreName, sponsorName, category;
  final String? photo;

  Uint8List? get photoBytes {
    final p = photo;
    if (p != null && p.isNotEmpty) {
      try { return base64Decode(p); } catch (_) {}
    }
    return null;
  }

  int get age {
    try {
      final dt = DateTime.parse(dobRaw);
      final now = DateTime.now();
      int a = now.year - dt.year;
      if (now.month < dt.month || (now.month == dt.month && now.day < dt.day)) a--;
      return a;
    } catch (_) { return 0; }
  }

  String get displayStatus => switch (status) {
    'ACTIVE'    => 'Active',
    'GRADUATED' => 'Graduated',
    'INACTIVE'  => 'Relieved',
    'DROPPED'   => 'Drop out',
    _           => status,
  };

  bool get isSponsored => sponsorName.isNotEmpty;
}

// ── status helpers ─────────────────────────────────────────────────────
Color _statusColor(String s) => switch (s) {
  'Active'    => _brand600,
  'Graduated' => _violet500,
  'Relieved'  => _amber600,
  'Drop out'  => _coral500,
  _           => _onSurface2,
};
Color _statusBg(String s) => switch (s) {
  'Active'    => _brand100,
  'Graduated' => _violet100,
  'Relieved'  => _amber100,
  'Drop out'  => _coral100,
  _           => const Color(0xFFF4F7F6),
};

// Shared in-memory student list — new enrollments are appended here
final demoLocalStudents = <Map<String, dynamic>>[];

// Raw backend student records from the last list load, so the detail screen can
// resolve a student opened by its backend id (keeps each profile its own data).
final loadedStudents = <Map<String, dynamic>>[];

// Shared centres list — loaded live from the backend (Manage Centres / Add
// Student). Starts empty so a clean database shows no demo centres.
final demoCentres = <({String id, String name})>[];

// Look up a single student record by id across newly-added enrollments and the
// demo dataset. Used by the detail screen so each student opens its OWN data.
Map<String, dynamic>? findStudentRecord(String id) {
  for (final s in demoLocalStudents) { if (s['id'] == id) return s; }
  for (final s in loadedStudents) { if (s['id'] == id) return s; }
  for (final s in _StudentsScreenState._mockStudents) { if (s['id'] == id) return s; }
  return null;
}

// ── avatar helpers ────────────────────────────────────────────────────
Color _avColor(String seed) {
  final palette = [_brand600, const Color(0xFFF6A723), _violet500, const Color(0xFF2D9CDB),
    const Color(0xFFEC5B8B), _coral500, const Color(0xFF14A98C), const Color(0xFF5BAE8A)];
  int h = 0;
  for (int i = 0; i < seed.length; i++) { h = ((h * 31) + seed.codeUnitAt(i)) & 0xFFFFFFFF; }
  return palette[h % palette.length];
}
String _initials(String name) {
  final p = name.trim().split(RegExp(r'\s+'));
  return ((p[0].isNotEmpty ? p[0][0] : '') + (p.length > 1 && p[1].isNotEmpty ? p[1][0] : '')).toUpperCase();
}

const _statusFilters = ['All', 'Active', 'Graduated', 'Relieved', 'Drop out'];

// ══════════════════════════════════════════════════════════════════════
class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key});
  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  final _searchCtrl = TextEditingController();
  String _search       = '';
  String _centre       = 'All Centres';
  String _statusFilter = 'All';

  List<_Student> _all    = [];
  List<({String id, String name})> _centres = [];
  // Admin-managed student categories (Settings → Student Categories) — shown
  // as extra filter chips after the fixed statuses.
  List<String> _categoryLabels = [];
  bool  _loading = true;
  String? _error;

  // Statuses first, then the dynamic categories; labels already on loaded
  // students always get a chip too (covers deactivated-but-assigned ones).
  List<String> get _filterChips {
    final cats = <String>{
      ..._categoryLabels,
      ..._all.map((s) => s.category).where((c) => c.isNotEmpty),
    }.toList()..sort();
    // A category named like a status can't be told apart in this row — the
    // status chip wins, so drop the duplicate label.
    cats.removeWhere((c) => _statusFilters.contains(c));
    return [..._statusFilters, ...cats];
  }

  bool _isStatusChip(String s) => _statusFilters.contains(s);

  @override
  void initState() { super.initState(); _load(); }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  // No demo students — the list reflects only real backend data.
  static final _mockStudents = <Map<String, dynamic>>[];

  static const _mockCentres = <({String id, String name})>[];

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    _loadCategoryLabels();
    try {
      final results = await Future.wait([
        apiClient.get('/students', params: {'limit': '100', 'page': '1'}),
        apiClient.get('/students/centers'),
      ]);

      final sRes = results[0];
      final sList = (sRes['data'] as List<dynamic>? ?? []);
      // Cache the raw records so the detail screen resolves the right student.
      loadedStudents
        ..clear()
        ..addAll(sList.map((e) => (e as Map).cast<String, dynamic>()));
      final students = sList.map((e) => _Student.fromJson(e as Map<String, dynamic>)).toList();

      final cRes = results[1];
      final cList = (cRes['data'] as List<dynamic>? ?? (cRes is List ? cRes : []));
      final centres = (cList as List<dynamic>).map<({String id, String name})>((c) {
        final m = c as Map<String, dynamic>;
        return (id: m['id'] as String, name: m['name'] as String);
      }).toList();

      // Backend is the source of truth even when empty (so a clean database
      // shows an empty list, not demo data). Any not-yet-synced local
      // enrollments show on top.
      if (mounted) {
        // Drop any optimistic local record the backend now returns (same id) so
        // a just-added student doesn't appear twice.
        final backendIds = students.map((s) => s.id).toSet();
        final locals = demoLocalStudents
            .where((m) => !backendIds.contains(m['id']))
            .map(_Student.fromJson);
        setState(() {
          _all = [...locals, ...students];
          _centres = centres;
          _loading = false;
        });
        return;
      }
    } catch (_) {}
    // Backend unreachable → demo/mock so the app still works offline.
    if (mounted) setState(() {
      _all     = [...demoLocalStudents.map(_Student.fromJson), ..._mockStudents.map(_Student.fromJson)];
      _centres = demoCentres;
      _loading = false;
    });
  }

  // Fire-and-forget — chips fall back to labels found on students if this fails.
  Future<void> _loadCategoryLabels() async {
    try {
      final r = await apiClient.get('/students/categories');
      final list = (r['data'] as List? ?? []);
      final labels = list.whereType<Map>()
          .map((c) => c['label'] as String? ?? '')
          .where((l) => l.isNotEmpty).toList();
      if (mounted) setState(() => _categoryLabels = labels);
    } catch (_) {}
  }

  List<_Student> get _filtered => _all.where((s) {
    final matchSearch = _search.isEmpty ||
      s.name.toLowerCase().contains(_search.toLowerCase()) ||
      s.childId.toLowerCase().contains(_search.toLowerCase());
    final matchCentre = _centre == 'All Centres' || s.centreName == _centre;
    // The chip row mixes fixed statuses and dynamic categories — decide which
    // field to match on by which kind of chip is selected.
    final matchStatus = _statusFilter == 'All' ||
      (_isStatusChip(_statusFilter) ? s.displayStatus == _statusFilter : s.category == _statusFilter);
    return matchSearch && matchCentre && matchStatus;
  }).toList();

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;

    if (_loading) {
      return Scaffold(body: Column(children: [
        Container(color: context.headerBg, height: top + 70),
        Expanded(child: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(),
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 40),
            itemCount: 6,
            itemBuilder: (_, __) => _skeletonCard(),
          ),
        ))),
      ]));
    }

    if (_error != null) {
      return Scaffold(body: Column(children: [
        Container(color: context.headerBg, height: top + 70),
        Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.wifi_off_rounded, size: 48, color: Color(0xFF93A29F)),
          const SizedBox(height: 12),
          Text('Could not load children', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.textPrimary)),
          const SizedBox(height: 6),
          Text(_error!, style: TextStyle(fontSize: 12, color: context.textHint), textAlign: TextAlign.center),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Retry'),
            style: ElevatedButton.styleFrom(backgroundColor: _brand600, foregroundColor: Colors.white),
          ),
        ]))),
      ]));
    }

    final children  = _filtered;
    final centreFiltered = _centre == 'All Centres'
        ? _all
        : _all.where((s) => s.centreName == _centre).toList();
    final total     = centreFiltered.length;
    final boys      = centreFiltered.where((s) => s.gender == 'MALE').length;
    final girls     = centreFiltered.where((s) => s.gender != 'MALE').length;
    final sponsored = centreFiltered.where((s) => s.isSponsored).length;

    final centreTabs = ['All Centres', ..._centres.map((c) => c.name)];

    return Scaffold(
      body: RefreshIndicator(
        color: _brand600,
        onRefresh: _load,
        child: Column(children: [
          // ── header ───────────────────────────────────────────────────
          Container(
            color: context.headerBg,
            padding: EdgeInsets.fromLTRB(18, top + 14, 18, 16),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Children', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5, height: 1, color: context.textPrimary)),
                const SizedBox(height: 3),
                Text(_centre == 'All Centres' ? '$total children · ${_centres.length} centres' : '$total children · $_centre', style: TextStyle(fontSize: 13, color: context.textSub, fontWeight: FontWeight.w600)),
              ])),
              GestureDetector(
                onTap: () => context.go('/students/new'),
                child: Container(width: 40, height: 40, decoration: const BoxDecoration(color: _brand600, shape: BoxShape.circle), child: const Icon(Icons.add, color: Colors.white, size: 24)),
              ),
            ]),
          ),

          // ── KPI card ─────────────────────────────────────────────────
          Container(
            color: context.headerBg,
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
              decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(18), border: Border.all(color: context.border),
                boxShadow: const [BoxShadow(color: Color(0x0D0D2822), blurRadius: 8, offset: Offset(0, 2))]),
              child: Column(children: [
                Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Total Children', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: context.textSub)),
                    const SizedBox(height: 3),
                    Text('$total', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -1, height: 1, color: context.textPrimary)),
                  ])),
                  Row(children: [
                    _GenderPill(count: '$boys',  label: 'Boys',  bg: _brand100, fg: _brand600),
                    const SizedBox(width: 8),
                    _GenderPill(count: '$girls', label: 'Girls', bg: _coral100, fg: _coral500),
                  ]),
                ]),
                const SizedBox(height: 12),
                Divider(height: 1, color: context.border),
                const SizedBox(height: 12),
                Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                  _StatItem(value: '$sponsored',       label: 'Sponsored',   color: _brand600),
                  _VDiv(context),
                  _StatItem(value: '${total-sponsored}', label: 'Unsponsored', color: _onSurface2),
                  _VDiv(context),
                  _StatItem(value: '$total',            label: 'Enrolled',    color: _violet500),
                ]),
              ]),
            ),
          ),

          // ── centre tabs ───────────────────────────────────────────────
          Container(
            color: context.headerBg,
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
            child: LayoutBuilder(builder: (_, constraints) {
              // If all tabs fit (≤4 tabs at ~80px each), use a Row; otherwise scroll
              final fitsInRow = centreTabs.length * 80.0 <= constraints.maxWidth;
              final tabWidgets = centreTabs.map((c) {
                final active = _centre == c;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _centre = c),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: active ? context.cardBg : Colors.transparent,
                      borderRadius: BorderRadius.circular(11),
                      boxShadow: active ? const [BoxShadow(color: Color(0x150D2822), blurRadius: 3, offset: Offset(0, 1))] : [],
                    ),
                    child: Text(c, textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: active ? _brand600 : context.textHint),
                      overflow: TextOverflow.ellipsis),
                  ),
                );
              }).toList();
              if (fitsInRow) {
                return Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(color: context.surface2, borderRadius: BorderRadius.circular(14), border: Border.all(color: context.border)),
                  child: Row(children: centreTabs.map((c) {
                    final active = _centre == c;
                    return Expanded(child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _centre = c),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: active ? context.cardBg : Colors.transparent,
                          borderRadius: BorderRadius.circular(11),
                          boxShadow: active ? const [BoxShadow(color: Color(0x150D2822), blurRadius: 3, offset: Offset(0, 1))] : [],
                        ),
                        child: Text(c, textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: active ? _brand600 : context.textHint),
                          overflow: TextOverflow.ellipsis),
                      ),
                    ));
                  }).toList()),
                );
              }
              return SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: tabWidgets,
                ),
              );
            }),
          ),

          // ── search ───────────────────────────────────────────────────
          Container(
            color: context.headerBg,
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
            child: Container(
              height: 44,
              decoration: BoxDecoration(color: context.surface2, borderRadius: BorderRadius.circular(14), border: Border.all(color: context.border)),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _search = v),
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, color: context.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search name or Child ID...',
                  hintStyle: TextStyle(color: context.textHint, fontSize: 14.5, fontWeight: FontWeight.w500),
                  prefixIcon: Icon(Icons.search, color: context.textHint, size: 20),
                  border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 12), isDense: true,
                ),
              ),
            ),
          ),

          // ── status chips ──────────────────────────────────────────────
          Container(
            color: context.headerBg,
            child: Column(children: [
              SizedBox(height: 42, child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
                children: _filterChips.map((s) {
                  final centreFiltered = _centre == 'All Centres'
                    ? _all
                    : _all.where((st) => st.centreName == _centre).toList();
                  final isStatus = _isStatusChip(s);
                  final count = s == 'All'
                    ? centreFiltered.length
                    : centreFiltered.where((st) => isStatus ? st.displayStatus == s : st.category == s).length;
                  final active = _statusFilter == s;
                  final col = s == 'All' ? _brand600 : (isStatus ? _statusColor(s) : _violet500);
                  return Padding(padding: const EdgeInsets.only(right: 8), child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _statusFilter = s),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: active ? col : context.cardBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: active ? col : context.border, width: 1.5),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(s, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: active ? Colors.white : context.textSub)),
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: active ? Colors.white.withValues(alpha: 0.3) : col.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text('$count', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: active ? Colors.white : col)),
                        ),
                      ]),
                    ),
                  ));
                }).toList(),
              )),
              const SizedBox(height: 10),
            ]),
          ),
          const SizedBox(height: 10),

          // ── list ─────────────────────────────────────────────────────
          Expanded(
            child: children.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.child_care, size: 48, color: context.textHint.withValues(alpha: 0.5)),
                  const SizedBox(height: 12),
                  Text('No children found', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: context.textHint)),
                ]))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 100),
                  itemCount: children.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) => _ChildCard(student: children[i], onTap: () => ctx.go('/students/${children[i].id}')),
                ),
          ),
        ]),
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/students/new'),
        backgroundColor: _brand600,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.add, size: 22),
        label: const Text('Add Child', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
      ),
    );
  }
}

// ── Skeleton card ─────────────────────────────────────────────────────
Widget _skeletonCard() => Container(
  margin: const EdgeInsets.only(bottom: 10),
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE5EBE9))),
  child: Row(children: [
    _Shimmer(width: 48, height: 48, radius: 24),
    const SizedBox(width: 12),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _Shimmer(width: 140, height: 14, radius: 7),
      const SizedBox(height: 8),
      _Shimmer(width: 100, height: 11, radius: 5),
      const SizedBox(height: 6),
      _Shimmer(width: 80, height: 11, radius: 5),
    ])),
    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
      _Shimmer(width: 60, height: 14, radius: 7),
      const SizedBox(height: 8),
      _Shimmer(width: 50, height: 22, radius: 11),
    ]),
  ]),
);

// ── Gender pill ───────────────────────────────────────────────────────
class _GenderPill extends StatelessWidget {
  const _GenderPill({required this.count, required this.label, required this.bg, required this.fg});
  final String count, label;
  final Color bg, fg;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(11)),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(count, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: fg, letterSpacing: -0.3, height: 1.1)),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: fg.withValues(alpha: 0.8))),
    ]),
  );
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.value, required this.label, required this.color});
  final String value, label;
  final Color color;
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: color, letterSpacing: -0.3)),
    const SizedBox(height: 2),
    Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: context.textHint)),
  ]);
}

Widget _VDiv(BuildContext context) =>
  SizedBox(height: 30, child: VerticalDivider(width: 1, color: context.border));

// ── Child card ────────────────────────────────────────────────────────
class _ChildCard extends StatelessWidget {
  const _ChildCard({required this.student, required this.onTap});
  final _Student student;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = _avColor(student.name);
    final statusLabel = student.displayStatus;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
        decoration: BoxDecoration(
          color: context.cardBg, borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.border),
          boxShadow: const [BoxShadow(color: Color(0x0A0D2822), blurRadius: 6, offset: Offset(0, 2))],
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Container(
            width: 52, height: 52,
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color, Color.lerp(color, Colors.black, 0.2)!], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(14),
            ),
            child: student.photoBytes != null
              ? Image.memory(student.photoBytes!, fit: BoxFit.cover, width: 52, height: 52)
              : Center(child: Text(_initials(student.name), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18))),
          ),
          const SizedBox(width: 13),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(student.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: -0.2, height: 1, color: context.textPrimary), overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 7),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: _statusBg(statusLabel), borderRadius: BorderRadius.circular(8)),
                child: Text(statusLabel, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: _statusColor(statusLabel))),
              ),
            ]),
            const SizedBox(height: 5),
            Row(children: [
              if (student.centreName.isNotEmpty) ...[
                Icon(Icons.location_on_outlined, size: 13, color: context.textHint),
                const SizedBox(width: 3),
                Flexible(child: Text('${student.centreName} · ', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: context.textSub), overflow: TextOverflow.ellipsis)),
              ],
              Flexible(child: Text('Age ${student.age}${student.classGrade.isNotEmpty ? " · ${student.classGrade}" : ""}${student.category.isNotEmpty ? " · ${student.category}" : ""}', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: context.textSub), overflow: TextOverflow.ellipsis)),
            ]),
            if (student.isSponsored) ...[
              const SizedBox(height: 3),
              Row(children: [
                Icon(Icons.favorite, size: 12, color: _brand600.withValues(alpha: 0.7)),
                const SizedBox(width: 4),
                Flexible(child: Text(student.sponsorName, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _brand600), overflow: TextOverflow.ellipsis)),
              ]),
            ],
          ])),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(student.childId, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.textHint)),
            if (student.gender.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(student.gender == 'MALE' ? 'Boy' : 'Girl', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: context.textHint)),
            ],
          ]),
        ]),
      ),
    );
  }
}

// ── Shimmer animation ─────────────────────────────────────────────────
class _Shimmer extends StatefulWidget {
  const _Shimmer({required this.width, required this.height, required this.radius});
  final double width, height, radius;
  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, __) => Container(
      width: widget.width, height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.radius),
        color: Color.lerp(const Color(0xFFE5EBE9), const Color(0xFFF4F7F6), _anim.value),
      ),
    ),
  );
}
