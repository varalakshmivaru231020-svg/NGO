import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/lazy_photo.dart';
import '../staff_model.dart';
import 'package:saksham_app/core/ui/ui.dart';

// ── colours ───────────────────────────────────────────────────────────
const _brand600  = Color(0xFFFF9933);
const _violet500 = Color(0xFF7C6CF0);
const _coral500  = Color(0xFFF2685E);
const _sky500    = Color(0xFF2D9CDB);

Color _avColor(String seed) {
  final palette = [_brand600, const Color(0xFFF6A723), _violet500, _sky500,
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
class StaffScreen extends StatefulWidget {
  const StaffScreen({super.key});
  @override
  State<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends State<StaffScreen> {
  final _searchCtrl = TextEditingController();
  String _search = '';
  String _statusFilter = 'All';

  List<StaffMember> _all = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    // Status chips/badges come from the editable list — rebuild once it's in.
    StaffLookups.load(force: true).then((_) { if (mounted) setState(() {}); });
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() { _loading = _all.isEmpty; _error = null; });
    // Paged to the end — the backend caps a page at 100 rows.
    final fetched = <StaffMember>[];
    try {
      for (int page = 1; ; page++) {
        final r = await apiClient.get('/staff', params: {'limit': '100', 'page': '$page'});
        final data = r['data'];
        final list = data is List ? data : const [];
        fetched.addAll(list.map(StaffMember.tryParse).whereType<StaffMember>());
        final meta = r['meta'];
        if (meta is! Map || meta['hasNext'] != true || list.isEmpty) break;
      }
    } catch (e) {
      if (!mounted) return;
      final msg = ApiClient.errorMessage(e, fallback: 'Could not load staff');
      setState(() {
        _loading = false;
        if (_all.isEmpty) _error = msg;
      });
      if (_error == null) AppToast.error(context, 'Couldn’t refresh staff', detail: msg);
      return;
    }
    if (!mounted) return;
    setState(() { _all = fetched; _loading = false; });
  }

  List<StaffMember> get _filtered {
    final q = _search.trim().toLowerCase();
    return _all.where((s) {
      final matchStatus = _statusFilter == 'All' || s.status == _statusFilter;
      final matchSearch = q.isEmpty ||
          s.name.toLowerCase().contains(q) ||
          s.staffCode.toLowerCase().contains(q) ||
          s.designation.toLowerCase().contains(q) ||
          s.mobile.contains(q);
      return matchStatus && matchSearch;
    }).toList();
  }

  Future<void> _delete(StaffMember s) async {
    final gone = await confirmDeleteStaff(context, id: s.id, name: s.name);
    if (gone && mounted) setState(() => _all.removeWhere((x) => x.id == s.id));
  }

  Widget _header(String subtitle) => Container(
    decoration: BoxDecoration(color: context.headerBg, border: Border(bottom: BorderSide(color: context.border))),
    padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 10, 16, 10),
    child: Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        const Text('Staff', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.2)),
        Text(subtitle, style: TextStyle(fontSize: 12.5, color: context.textSub, fontWeight: FontWeight.w500)),
      ])),
      AppButton(label: 'Add Staff', icon: Icons.add, onPressed: () => context.go('/staff/new')),
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
          child: _card(const SkeletonList(rows: 6, rowHeight: 68)),
        )),
      ]));
    }
    if (_error != null) {
      return Scaffold(body: Column(children: [
        _header('Couldn’t load staff'),
        Expanded(child: Center(child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: _card(ErrorState(message: _error!, onRetry: _load)),
        ))),
      ]));
    }

    final rows = _filtered;
    final active = _all.where((s) => s.status == 'ACTIVE').toList();
    final onLeave = _all.where((s) => s.status == 'ON_LEAVE').length;
    final monthly = active.fold<int>(0, (sum, s) => sum + s.gross);

    return Scaffold(
      body: Column(children: [
        _header('${_all.length} staff · ${active.length} active'),
        Expanded(child: RefreshIndicator(
          color: _brand600,
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
            children: [
              // ── KPI strip ──────────────────────────────────────────
              _card(Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                child: Row(children: [
                  _Stat(value: '${_all.length}', label: 'Total', color: context.textPrimary),
                  _vDiv(context),
                  _Stat(value: '${active.length}', label: 'Active', color: staffStatusColor('ACTIVE')),
                  _vDiv(context),
                  _Stat(value: '$onLeave', label: 'On Leave', color: staffStatusColor('ON_LEAVE')),
                  _vDiv(context),
                  _Stat(value: staffInr(monthly), label: 'Monthly gross', color: _brand600),
                ]),
              )),
              const SizedBox(height: 12),

              // ── search ─────────────────────────────────────────────
              TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _search = v),
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: context.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Search name, Staff ID, designation or mobile…',
                  prefixIcon: Icon(Icons.search, color: context.textHint, size: 18),
                  suffixIcon: _search.isEmpty ? null : IconButton(
                    tooltip: 'Clear search',
                    icon: Icon(Icons.close_rounded, size: 16, color: context.textHint),
                    onPressed: () { _searchCtrl.clear(); setState(() => _search = ''); },
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // ── status chips ───────────────────────────────────────
              SizedBox(height: 32, child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  (key: 'All', label: 'All', color: _brand600),
                  for (final o in StaffLookups.statuses) (key: o.key, label: o.label, color: staffStatusColor(o.key)),
                  // A status still on someone but no longer in the list keeps its chip.
                  for (final k in _all.map((s) => s.status).toSet())
                    if (!StaffLookups.statuses.any((o) => o.key == k)) (key: k, label: staffStatusLabel(k), color: staffStatusColor(k)),
                ].map((chip) {
                  final count = chip.key == 'All' ? _all.length : _all.where((s) => s.status == chip.key).length;
                  final on = _statusFilter == chip.key;
                  return Padding(padding: const EdgeInsets.only(right: 6), child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => setState(() => _statusFilter = chip.key),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: on ? chip.color.withValues(alpha: 0.12) : context.cardBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: on ? chip.color : context.border),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(chip.label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: on ? chip.color : context.textSub)),
                        const SizedBox(width: 6),
                        Text('$count', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: on ? chip.color : context.textHint)),
                      ]),
                    ),
                  ));
                }).toList(),
              )),
              const SizedBox(height: 12),

              // ── list ───────────────────────────────────────────────
              if (rows.isEmpty)
                _card(_all.isEmpty
                    ? EmptyState(
                        icon: Icons.badge_outlined,
                        title: 'No staff yet',
                        message: 'Add your first staff member to keep their profile and salary details.',
                        actionLabel: 'Add Staff',
                        onAction: () => context.go('/staff/new'),
                      )
                    : const EmptyState(
                        icon: Icons.search_off_rounded,
                        title: 'No staff found',
                        message: 'Try a different search or filter.',
                      ))
              else
                _card(Column(children: [
                  for (var i = 0; i < rows.length; i++)
                    _StaffRow(
                      staff: rows[i],
                      last: i == rows.length - 1,
                      onOpen: () => context.go('/staff/${rows[i].id}'),
                      onEdit: () => context.go('/staff/${rows[i].id}/edit'),
                      onSalary: () => context.go('/staff/${rows[i].id}?tab=salary'),
                      onDelete: () => _delete(rows[i]),
                    ),
                ])),
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
    FittedBox(fit: BoxFit.scaleDown, child: Text(value,
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: color, letterSpacing: -0.3, height: 1.1))),
    const SizedBox(height: 2),
    Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: context.textHint)),
  ]));
}

Widget _vDiv(BuildContext context) => SizedBox(height: 28, child: VerticalDivider(width: 1, color: context.border));

// ── Staff row ─────────────────────────────────────────────────────────
class _StaffRow extends StatefulWidget {
  const _StaffRow({required this.staff, required this.last, required this.onOpen, required this.onEdit,
    required this.onSalary, required this.onDelete});
  final StaffMember staff;
  final bool last;
  final VoidCallback onOpen, onEdit, onSalary, onDelete;
  @override
  State<_StaffRow> createState() => _StaffRowState();
}

class _StaffRowState extends State<_StaffRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.staff;
    final color = _avColor(s.name);
    final statusCol = staffStatusColor(s.status);
    final meta = [
      s.designation,
      if (s.centreName.isNotEmpty) s.centreName,
      staffEmploymentLabel(s.employmentType),
    ].join('  ·  ');
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onOpen,
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
              child: LazyPhoto(
                endpoint: '/staff/${s.id}/photo',
                field: 'photo',
                size: 40,
                enabled: s.hasPhoto,
                placeholder: Center(child: Text(_initials(s.name),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14))),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Flexible(child: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.textPrimary))),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(color: statusCol.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                  child: Text(staffStatusLabel(s.status), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: statusCol)),
                ),
              ]),
              const SizedBox(height: 3),
              Text(meta, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: context.textHint)),
            ])),
            const SizedBox(width: 10),
            Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
              Text(s.staffCode, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.textSub)),
              const SizedBox(height: 3),
              Text('${staffInr(s.gross)}/mo', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: context.textHint)),
            ]),
            const SizedBox(width: 2),
            PopupMenuButton<String>(
              tooltip: 'Actions for ${s.name}',
              icon: Icon(Icons.more_horiz_rounded, size: 20, color: context.textSub),
              position: PopupMenuPosition.under,
              offset: const Offset(0, 4),
              constraints: const BoxConstraints(minWidth: 150),
              onSelected: (v) {
                if (v == 'open') widget.onOpen();
                if (v == 'edit') widget.onEdit();
                if (v == 'salary') widget.onSalary();
                if (v == 'delete') widget.onDelete();
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'open', height: 36, child: Row(children: [
                  Icon(Icons.open_in_new_rounded, size: 17, color: context.textSub),
                  const SizedBox(width: 10),
                  const Text('Open profile', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500)),
                ])),
                PopupMenuItem(value: 'edit', height: 36, child: Row(children: [
                  Icon(Icons.edit_outlined, size: 17, color: context.textSub),
                  const SizedBox(width: 10),
                  const Text('Edit', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500)),
                ])),
                PopupMenuItem(value: 'salary', height: 36, child: Row(children: [
                  Icon(Icons.receipt_long_outlined, size: 17, color: context.textSub),
                  const SizedBox(width: 10),
                  const Text('Salary & reports', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500)),
                ])),
                const PopupMenuDivider(height: 8),
                const PopupMenuItem(value: 'delete', height: 36, child: Row(children: [
                  Icon(Icons.delete_outline_rounded, size: 17, color: Color(0xFFE5484D)),
                  SizedBox(width: 10),
                  Text('Delete', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: Color(0xFFE5484D))),
                ])),
              ],
            ),
          ]),
        ),
      ),
    );
  }
}
