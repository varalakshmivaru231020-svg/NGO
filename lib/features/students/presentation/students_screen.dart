import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/lazy_photo.dart';
import '../student_lookups.dart';

// ── colours ───────────────────────────────────────────────────────────
const _brand600  = Color(0xFFFF9933);
const _brand100  = Color(0xFFFFE8CC);
const _violet500 = Color(0xFF7C6CF0);
const _coral500  = Color(0xFFF2685E);
const _coral100  = Color(0xFFFFE3DF);
const _onSurface2 = Color(0xFF5A6B67);

// ── API model ─────────────────────────────────────────────────────────
// Tolerant readers — one odd row (null name, numeric field, missing nested
// object) must not throw and blank the whole list.
String _str(Object? v, [String fallback = '']) {
  if (v == null) return fallback;
  final s = v.toString();
  return s.isEmpty ? fallback : s;
}

String _sponsorFromJson(Map<String, dynamic> j) {
  final list = j['sponsorships'];
  if (list is! List || list.isEmpty) return '';
  final first = list.first;
  final donor = first is Map ? first['donor'] : null;
  return donor is Map ? _str(donor['name']) : '';
}

String _centreFromJson(Map<String, dynamic> j) {
  final center = j['center'];
  return center is Map ? _str(center['name']) : '';
}

class _Student {
  _Student({required this.id, required this.childId, required this.name,
    required this.gender, required this.dobRaw, required this.status,
    required this.classGrade, required this.school,
    required this.centreName, required this.sponsorName, this.category = '',
    this.categoryId = '', this.photo, this.hasPhoto = false});

  factory _Student.fromJson(Map<String, dynamic> j) {
    final cat = j['category'];
    final categoryId = _str(cat is Map ? cat['id'] : null, _str(j['categoryId']));
    var category = cat is Map ? _str(cat['label']) : '';
    if (category.isEmpty && categoryId.isNotEmpty) {
      final l = StudentLookups.categoryLabel(categoryId);
      if (l != '—') category = l;
    }
    final photo = j['photo'] is String ? j['photo'] as String : null;
    return _Student(
      id:          _str(j['id']),
      childId:     _str(j['childId']),
      name:        _str(j['name']),
      gender:      _str(j['gender'], 'MALE'),
      dobRaw:      _str(j['dob']),
      status:      _str(j['status'], 'ACTIVE'),
      classGrade:  _str(j['class']),
      school:      _str(j['school']),
      centreName:  _centreFromJson(j),
      sponsorName: _sponsorFromJson(j),
      category:    category,
      categoryId:  categoryId,
      photo:       photo,
      hasPhoto:    j['hasPhoto'] == true || (photo != null && photo.isNotEmpty),
    );
  }

  // Parses one row; returns null (row skipped) instead of throwing.
  static _Student? tryParse(Object? raw) {
    if (raw is! Map) return null;
    try {
      final s = _Student.fromJson(raw.cast<String, dynamic>());
      return s.id.isEmpty ? null : s;
    } catch (_) {
      return null;
    }
  }

  final String id, childId, name, gender, dobRaw, status, classGrade, school, centreName, sponsorName, category, categoryId;
  final String? photo;   // only on local (not-yet-synced) records / full records
  final bool hasPhoto;   // list rows carry this flag instead of the photo

  Uint8List? get photoBytes => decodePhoto(photo);

  int get age {
    try {
      final dt = DateTime.parse(dobRaw);
      final now = DateTime.now();
      int a = now.year - dt.year;
      if (now.month < dt.month || (now.month == dt.month && now.day < dt.day)) a--;
      return a;
    } catch (_) { return 0; }
  }

  // Label from the admin-managed status list (Settings → Student Status).
  String get displayStatus => StudentLookups.statusLabel(status);

  bool get isSponsored => sponsorName.isNotEmpty;
}

// One chip in the filter row: "All", a status (by key) or a category (by label).
typedef _FilterDef = ({String id, String label, Color color, bool Function(_Student) test});

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
  bool  _loading = true;
  String? _error;

  // "All", then every status from Settings → Student Status (plus any key
  // found on a loaded student that the list no longer has, so counts stay
  // complete), then the Settings → Student Categories labels (plus labels
  // already on students, covering deactivated-but-assigned ones).
  List<_FilterDef> get _filterChips {
    final keys = <String>[for (final o in StudentLookups.statuses) o.key];
    for (final s in _all) {
      if (s.status.isNotEmpty && !keys.contains(s.status)) keys.add(s.status);
    }
    final statusLabels = keys.map(StudentLookups.statusLabel).toSet();
    final cats = <String>{
      ...StudentLookups.categories.where((c) => c.isActive).map((c) => c.label),
      ..._all.map((s) => s.category).where((c) => c.isNotEmpty),
    }.toList()..sort();
    // A category named like a status can't be told apart in this row — the
    // status chip wins, so drop the duplicate label.
    cats.removeWhere(statusLabels.contains);
    return [
      (id: 'All', label: 'All', color: _brand600, test: (_) => true),
      for (final k in keys)
        (id: 'status:$k', label: StudentLookups.statusLabel(k), color: StudentLookups.statusColor(k),
          test: (s) => s.status == k),
      for (final c in cats)
        (id: 'cat:$c', label: c, color: _violet500, test: (s) => s.category == c),
    ];
  }

  @override
  void initState() {
    super.initState();
    _load();
    // Status / category lists drive the chips and badges — rebuild once they
    // arrive (fallback labels are used until then).
    StudentLookups.load().then((_) { if (mounted) setState(() {}); });
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  // No demo students — the list reflects only real backend data.
  static final _mockStudents = <Map<String, dynamic>>[];

  static const _mockCentres = <({String id, String name})>[];

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w700)),
      backgroundColor: _coral500, behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      action: SnackBarAction(label: 'Retry', textColor: Colors.white, onPressed: _load),
    ));
  }

  Future<void> _load() async {
    // Keep the current list on screen during a pull-to-refresh.
    setState(() { _loading = _all.isEmpty; _error = null; });

    // Students paged to the end — one page capped the list at 100 children
    // and made older ones look deleted. Rows from pages that did arrive are
    // kept even if a later page fails.
    final fetched = <Map<String, dynamic>>[];
    Object? pageError;
    Future<void> fetchAllStudents() async {
      try {
        for (int page = 1; ; page++) {
          final r = await apiClient.get('/students', params: {'limit': '100', 'page': '$page'});
          final data = r['data'];
          final pageList = data is List ? data : const [];
          for (final e in pageList) { if (e is Map) fetched.add(e.cast<String, dynamic>()); }
          final meta = r['meta'];
          if (meta is! Map || meta['hasNext'] != true || pageList.isEmpty) break;
        }
      } catch (e) {
        pageError = e;
      }
    }

    Future<List<({String id, String name})>?> fetchCentres() async {
      try {
        final r = await apiClient.get('/students/centers');
        final data = r['data'];
        return [
          for (final c in (data is List ? data : const []))
            if (c is Map && _str(c['id']).isNotEmpty) (id: _str(c['id']), name: _str(c['name'])),
        ];
      } catch (_) {
        return null; // centre tabs are secondary — keep what we had
      }
    }

    // Both run in parallel and catch their own errors, so neither can end up
    // as an unhandled async error while the other is awaited.
    final centresFuture = fetchCentres();
    await Future.wait([fetchAllStudents(), centresFuture]);
    final centres = await centresFuture;
    if (!mounted) return;

    final failed = pageError != null;
    final students = fetched.map(_Student.tryParse).whereType<_Student>().toList();

    // Cache the raw records so the detail screen resolves the right student.
    // A partial load only refreshes the rows it got.
    if (!failed) loadedStudents.clear();
    for (final m in fetched) {
      loadedStudents.removeWhere((x) => x['id'] == m['id']);
      loadedStudents.add(m);
    }

    // Drop any optimistic local record the backend now returns (same id) so
    // a just-added student doesn't appear twice.
    final backendIds = students.map((s) => s.id).toSet();
    final locals = demoLocalStudents
        .where((m) => !backendIds.contains(m['id']))
        .map(_Student.tryParse).whereType<_Student>();

    final msg = failed ? ApiClient.errorMessage(pageError!, fallback: 'Could not load children') : null;
    setState(() {
      if (!failed || students.isNotEmpty) {
        // Backend is the source of truth even when empty (so a clean database
        // shows an empty list, not demo data). Local enrollments show on top.
        _all = [...locals, ...students];
      } else if (_all.isEmpty) {
        // Nothing fetched and nothing shown yet: local enrollments if any,
        // otherwise the full-screen error with Retry.
        _all = [...locals, ..._mockStudents.map(_Student.tryParse).whereType<_Student>()];
        if (_all.isEmpty) _error = msg;
      }
      // (Refresh that fetched nothing keeps the list already on screen.)
      if (centres != null) {
        _centres = centres;
      } else if (_centres.isEmpty) {
        _centres = demoCentres.isNotEmpty ? demoCentres : _mockCentres;
      }
      _loading = false;
    });
    if (failed && _error == null) {
      _snack(students.isNotEmpty
          ? 'Showing ${students.length} children — the rest could not be loaded: $msg'
          : msg!);
    }
  }

  List<_Student> get _filtered {
    final chips = _filterChips;
    final chip = chips.firstWhere((c) => c.id == _statusFilter, orElse: () => chips.first);
    return _all.where((s) {
      final matchSearch = _search.isEmpty ||
        s.name.toLowerCase().contains(_search.toLowerCase()) ||
        s.childId.toLowerCase().contains(_search.toLowerCase());
      final matchCentre = _centre == 'All Centres' || s.centreName == _centre;
      return matchSearch && matchCentre && chip.test(s);
    }).toList();
  }

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
                children: _filterChips.map((chip) {
                  final count = centreFiltered.where(chip.test).length;
                  final active = _statusFilter == chip.id ||
                    (chip.id == 'All' && !_filterChips.any((c) => c.id == _statusFilter));
                  final col = chip.color;
                  final s = chip.label;
                  return Padding(padding: const EdgeInsets.only(right: 8), child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _statusFilter = chip.id),
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
    final statusCol = StudentLookups.statusColor(student.status);
    final initials = Center(child: Text(_initials(student.name), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)));
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
            // List rows no longer carry the photo — fetched lazily per card.
            child: LazyPhoto(
              endpoint: '/students/${student.id}/photo',
              field: 'photo',
              size: 52,
              enabled: student.hasPhoto && !student.id.startsWith('local-'),
              initial: student.photoBytes,
              placeholder: initials,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Flexible(child: Text(student.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: -0.2, height: 1, color: context.textPrimary), overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 7),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: statusCol.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                child: Text(statusLabel, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: statusCol)),
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
