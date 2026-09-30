import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/lazy_photo.dart';
import '../student_lookups.dart';
import 'package:saksham_app/core/ui/ui.dart';

// ── colours ───────────────────────────────────────────────────────────
const _brand600  = Color(0xFFFF9933);
const _violet500 = Color(0xFF7C6CF0);
const _coral500  = Color(0xFFF2685E);
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
    AppToast.show(context, tone: ToastTone.error, title: 'Couldn’t load all children', detail: msg,
        action: SnackBarAction(label: 'Retry', onPressed: _load));
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

  Widget _header(String subtitle) => Container(
    decoration: BoxDecoration(color: context.headerBg, border: Border(bottom: BorderSide(color: context.border))),
    padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 10, 16, 10),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        const Text('Children', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.2)),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          child: Text(subtitle, key: ValueKey(subtitle),
              style: TextStyle(fontSize: 12.5, color: context.textSub, fontWeight: FontWeight.w500)),
        ),
      ])),
      // In the header rather than a floating button, so a toast can never
      // cover it.
      AppButton(label: 'Add Child', icon: Icons.add, onPressed: () => context.go('/students/new')),
    ]),
  );

  Widget _card(Widget child) => Container(
    width: double.infinity,
    decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: context.border)),
    clipBehavior: Clip.antiAlias,
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(body: Column(children: [
        _header('Loading…'),
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            _card(const Padding(padding: EdgeInsets.all(14), child: Row(children: [
              Expanded(child: Skeleton(height: 34, radius: 8)), SizedBox(width: 10),
              Expanded(child: Skeleton(height: 34, radius: 8)), SizedBox(width: 10),
              Expanded(child: Skeleton(height: 34, radius: 8)),
            ]))),
            const SizedBox(height: 12),
            _card(const SkeletonList(rows: 6, rowHeight: 68)),
          ]),
        )),
      ]));
    }

    if (_error != null) {
      return Scaffold(body: Column(children: [
        _header('Couldn’t load children'),
        Expanded(child: Center(child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: _card(ErrorState(message: _error!, onRetry: _load)),
        ))),
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
    final chips = _filterChips;

    return Scaffold(
      body: Column(children: [
        _header(_centre == 'All Centres' ? '$total children · ${_centres.length} centres' : '$total children · $_centre'),
        Expanded(child: RefreshIndicator(
          color: _brand600,
          onRefresh: _load,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                sliver: SliverToBoxAdapter(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // ── KPI strip ────────────────────────────────────────
                  _card(Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                    child: Row(children: [
                      _Stat(value: '$total', label: 'Total', color: context.textPrimary),
                      _VDiv(context),
                      _Stat(value: '$boys', label: 'Boys', color: _brand600),
                      _VDiv(context),
                      _Stat(value: '$girls', label: 'Girls', color: _coral500),
                      _VDiv(context),
                      _Stat(value: '$sponsored', label: 'Sponsored', color: _violet500),
                      _VDiv(context),
                      _Stat(value: '${total - sponsored}', label: 'Unsponsored', color: _onSurface2),
                    ]),
                  )),
                  const SizedBox(height: 12),

                  // ── centre tabs ──────────────────────────────────────
                  if (centreTabs.length > 1) ...[
                    Container(
                      height: 38,
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(color: context.surface2, borderRadius: BorderRadius.circular(10), border: Border.all(color: context.border)),
                      child: LayoutBuilder(builder: (_, c) {
                        final fits = centreTabs.length * 96.0 <= c.maxWidth;
                        Widget tab(String name) {
                          final active = _centre == name;
                          return InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => setState(() => _centre = name),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              alignment: Alignment.center,
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                color: active ? context.cardBg : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: active ? const [BoxShadow(color: Color(0x150D2822), blurRadius: 3, offset: Offset(0, 1))] : const [],
                              ),
                              child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: active ? _brand600 : context.textSub)),
                            ),
                          );
                        }
                        return fits
                          ? Row(children: [for (final t in centreTabs) Expanded(child: tab(t))])
                          : ListView(scrollDirection: Axis.horizontal, children: [for (final t in centreTabs) tab(t)]);
                      }),
                    ),
                    const SizedBox(height: 10),
                  ],

                  // ── search ───────────────────────────────────────────
                  TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _search = v),
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: context.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search name or Child ID…',
                      prefixIcon: Icon(Icons.search, color: context.textHint, size: 18),
                      suffixIcon: _search.isEmpty ? null : IconButton(
                        tooltip: 'Clear search',
                        icon: Icon(Icons.close_rounded, size: 16, color: context.textHint),
                        onPressed: () { _searchCtrl.clear(); setState(() => _search = ''); },
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // ── status / category chips ──────────────────────────
                  SizedBox(height: 32, child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: chips.map((chip) {
                      final count = centreFiltered.where(chip.test).length;
                      final active = _statusFilter == chip.id ||
                        (chip.id == 'All' && !chips.any((c) => c.id == _statusFilter));
                      final col = chip.color;
                      return Padding(padding: const EdgeInsets.only(right: 6), child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => setState(() => _statusFilter = chip.id),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 120),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: active ? col.withValues(alpha: 0.12) : context.cardBg,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: active ? col : context.border),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Text(chip.label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: active ? col : context.textSub)),
                            const SizedBox(width: 6),
                            Text('$count', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700,
                                color: active ? col : context.textHint)),
                          ]),
                        ),
                      ));
                    }).toList(),
                  )),
                  const SizedBox(height: 12),
                ])),
              ),

              // ── list ─────────────────────────────────────────────────
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                sliver: SliverToBoxAdapter(child: children.isEmpty
                  ? _card(_all.isEmpty
                      ? EmptyState(
                          icon: Icons.child_care,
                          title: 'No children yet',
                          message: 'Enrol the first child to start managing records.',
                          actionLabel: 'Add Child',
                          onAction: () => context.go('/students/new'),
                        )
                      : const EmptyState(
                          icon: Icons.search_off_rounded,
                          title: 'No children found',
                          message: 'Try a different search, centre or filter.',
                        ))
                  : _card(Column(children: [
                      for (var i = 0; i < children.length; i++)
                        _ChildCard(
                          student: children[i],
                          last: i == children.length - 1,
                          onTap: () => context.go('/students/${children[i].id}'),
                        ),
                    ]))),
              ),
            ],
          ),
        )),
      ]),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, required this.color});
  final String value, label;
  final Color color;
  @override
  Widget build(BuildContext context) => Expanded(child: Column(mainAxisSize: MainAxisSize.min, children: [
    Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: color, letterSpacing: -0.3, height: 1.1)),
    const SizedBox(height: 2),
    Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: context.textHint)),
  ]));
}

// ignore: non_constant_identifier_names
Widget _VDiv(BuildContext context) =>
  SizedBox(height: 28, child: VerticalDivider(width: 1, color: context.border));

// ── Child row ─────────────────────────────────────────────────────────
class _ChildCard extends StatefulWidget {
  const _ChildCard({required this.student, required this.onTap, required this.last});
  final _Student student;
  final VoidCallback onTap;
  final bool last;
  @override
  State<_ChildCard> createState() => _ChildCardState();
}

class _ChildCardState extends State<_ChildCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final student = widget.student;
    final color = _avColor(student.name);
    final statusLabel = student.displayStatus;
    final statusCol = StudentLookups.statusColor(student.status);
    final initials = Center(child: Text(_initials(student.name), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)));
    final meta = [
      if (student.centreName.isNotEmpty) student.centreName,
      'Age ${student.age}',
      if (student.classGrade.isNotEmpty) student.classGrade,
      if (student.category.isNotEmpty) student.category,
    ].join('  ·  ');
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          constraints: const BoxConstraints(minHeight: 68),
          padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
          decoration: BoxDecoration(
            color: _hover ? context.surface2.withValues(alpha: 0.6) : Colors.transparent,
            border: widget.last ? null : Border(bottom: BorderSide(color: context.border.withValues(alpha: 0.7))),
          ),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              clipBehavior: Clip.hardEdge,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [color, Color.lerp(color, Colors.black, 0.2)!], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.circular(10),
              ),
              // List rows no longer carry the photo — fetched lazily per row.
              child: LazyPhoto(
                endpoint: '/students/${student.id}/photo',
                field: 'photo',
                size: 40,
                enabled: student.hasPhoto && !student.id.startsWith('local-'),
                initial: student.photoBytes,
                placeholder: initials,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Flexible(child: Text(student.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.textPrimary))),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: statusCol.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                  child: Text(statusLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusCol)),
                ),
              ]),
              const SizedBox(height: 3),
              Row(children: [
                Flexible(child: Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: context.textHint))),
                if (student.isSponsored) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.favorite, size: 11, color: _brand600.withValues(alpha: 0.8)),
                  const SizedBox(width: 3),
                  Flexible(child: Text(student.sponsorName, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _brand600))),
                ],
              ]),
            ])),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
              Text(student.childId, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.textSub)),
              if (student.gender.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(switch (student.gender) { 'MALE' => 'Boy', 'FEMALE' => 'Girl', _ => 'Other' },
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: context.textHint)),
              ],
            ]),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, size: 18, color: context.textHint),
          ]),
        ),
      ),
    );
  }
}
