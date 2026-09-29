import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../students/student_lookups.dart';

const _brand600 = Color(0xFFFF9933);
const _coral500 = Color(0xFFF2685E);

// ══════════════════════════════════════════════════════════════════════
// STUDENT MASTER LISTS — one screen, three lists, all admin-managed:
//   • Support Categories  (/students/categories…)
//   • Student Status      (/students/lookups/STATUS…)
//   • Education Levels    (/students/lookups/EDUCATION_LEVEL…)
// Each supports add, rename/edit, switch on/off and delete. Delete is refused
// by the server while students still use an entry — switch it off instead.
// ══════════════════════════════════════════════════════════════════════

class _MasterConfig {
  const _MasterConfig({
    required this.title,
    required this.noun,
    required this.icon,
    required this.listAllPath,
    required this.createPath,
    required this.itemPath,
    required this.hint,
    required this.emptyHelp,
  });
  final String title;
  final String noun;              // "category", "status", "education level"
  final IconData icon;
  final String listAllPath;
  final String createPath;
  final String Function(String id) itemPath;
  final String hint;
  final String emptyHelp;
}

final _supportCategories = _MasterConfig(
  title: 'Support Categories',
  noun: 'category',
  icon: Icons.volunteer_activism_outlined,
  listAllPath: '/students/categories/all',
  createPath: '/students/categories',
  itemPath: (id) => '/students/categories/$id',
  hint: 'e.g. Full Support, Semi Support, Orphan…',
  emptyHelp: 'Add categories like Full Support, Semi Support,\nOrphan — they appear in Add Student.',
);

final _studentStatuses = _MasterConfig(
  title: 'Student Status',
  noun: 'status',
  icon: Icons.flag_outlined,
  listAllPath: '/students/lookups/STATUS/all',
  createPath: '/students/lookups/STATUS',
  itemPath: (id) => '/students/lookup-items/$id',
  hint: 'e.g. Active, Drop Out, Relieved, Former Student…',
  emptyHelp: 'Add statuses like Active, Drop Out, Relieved,\nFormer Student — they appear on every student.',
);

final _educationLevels = _MasterConfig(
  title: 'Education Levels',
  noun: 'education level',
  icon: Icons.school_outlined,
  listAllPath: '/students/lookups/EDUCATION_LEVEL/all',
  createPath: '/students/lookups/EDUCATION_LEVEL',
  itemPath: (id) => '/students/lookup-items/$id',
  hint: 'e.g. Primary School, High School, College…',
  emptyHelp: 'Add levels like Primary School, High School,\nCollege — they appear in Add Student.',
);

class StudentCategoriesScreen extends StatelessWidget {
  const StudentCategoriesScreen({super.key});
  @override
  Widget build(BuildContext context) => _StudentMasterScreen(config: _supportCategories);
}

class StudentStatusesScreen extends StatelessWidget {
  const StudentStatusesScreen({super.key});
  @override
  Widget build(BuildContext context) => _StudentMasterScreen(config: _studentStatuses);
}

class EducationLevelsScreen extends StatelessWidget {
  const EducationLevelsScreen({super.key});
  @override
  Widget build(BuildContext context) => _StudentMasterScreen(config: _educationLevels);
}

class _StudentMasterScreen extends StatefulWidget {
  const _StudentMasterScreen({required this.config});
  final _MasterConfig config;
  @override
  State<_StudentMasterScreen> createState() => _StudentMasterScreenState();
}

class _StudentMasterScreenState extends State<_StudentMasterScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  _MasterConfig get _c => widget.config;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final r = await apiClient.get(_c.listAllPath);
      final list = (r['data'] as List? ?? []).whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
      if (!mounted) return;
      setState(() { _items = list; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = ApiClient.errorMessage(e, fallback: 'Could not load ${_c.title.toLowerCase()}.'); _loading = false; });
    }
  }

  // Every change refreshes the shared cache so Add Student and the student
  // screens pick it up straight away.
  void _changed() {
    StudentLookups.load(force: true);
    _load();
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w700)),
      backgroundColor: error ? _coral500 : _brand600, behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: Duration(seconds: error ? 5 : 2),
    ));
  }

  Future<void> _toggle(Map<String, dynamic> item, bool v) async {
    setState(() => item['isActive'] = v);
    try {
      await apiClient.put(_c.itemPath(item['id'] as String), {'isActive': v});
      _changed();
    } catch (e) {
      if (!mounted) return;
      setState(() => item['isActive'] = !v);
      _snack(ApiClient.errorMessage(e, fallback: 'Could not update the ${_c.noun}.'), error: true);
    }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final label = item['label'] as String? ?? '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "$label"?', style: const TextStyle(fontWeight: FontWeight.w800)),
        content: Text('This removes the ${_c.noun} permanently. If students still use it, '
            'the delete is refused, so switch it off instead.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: _coral500, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await apiClient.delete(_c.itemPath(item['id'] as String));
      _snack('"$label" deleted');
      _changed();
    } catch (e) {
      _snack(ApiClient.errorMessage(e, fallback: 'Could not delete the ${_c.noun}.'), error: true);
    }
  }

  // Add (item == null) or edit an entry.
  void _showEditor([Map<String, dynamic>? item]) {
    final editing = item != null;
    final nameCtrl = TextEditingController(text: item?['label'] as String? ?? '');
    final descCtrl = TextEditingController(text: item?['description'] as String? ?? '');
    String? nameError;
    bool saving = false;

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
        Future<void> save() async {
          final name = nameCtrl.text.trim();
          if (name.isEmpty) { setSheet(() => nameError = 'Name is required'); return; }
          setSheet(() => saving = true);
          try {
            final body = {'label': name, 'description': descCtrl.text.trim()};
            if (editing) {
              await apiClient.put(_c.itemPath(item['id'] as String), body);
            } else {
              await apiClient.post(_c.createPath, {
                'label': name,
                if (descCtrl.text.trim().isNotEmpty) 'description': descCtrl.text.trim(),
              });
            }
            if (ctx.mounted) Navigator.pop(ctx);
            _snack(editing ? '"$name" updated' : '"$name" added');
            _changed();
          } catch (e) {
            if (!ctx.mounted) return;
            setSheet(() {
              saving = false;
              nameError = ApiClient.errorMessage(e, fallback: 'Could not save the ${_c.noun}.');
            });
          }
        }

        InputDecoration deco(String hint, {String? error}) => InputDecoration(
          hintText: hint, hintStyle: TextStyle(color: ctx.textHint),
          filled: true, fillColor: ctx.surface2, errorText: error, errorMaxLines: 4,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _brand600, width: 1.5)),
          errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _coral500, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12));

        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            decoration: BoxDecoration(color: ctx.cardBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: ctx.border, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 16),
              Text('${editing ? 'Edit' : 'Add'} ${_c.noun[0].toUpperCase()}${_c.noun.substring(1)}',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              Row(children: [
                Text('Name', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: ctx.textSub)),
                const Text(' *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _coral500)),
              ]),
              const SizedBox(height: 6),
              TextField(
                controller: nameCtrl, autofocus: true,
                onChanged: (_) { if (nameError != null) setSheet(() => nameError = null); },
                onSubmitted: (_) { if (!saving) save(); },
                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                decoration: deco(_c.hint, error: nameError)),
              const SizedBox(height: 12),
              Text('Description (optional)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: ctx.textSub)),
              const SizedBox(height: 6),
              TextField(
                controller: descCtrl,
                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
                decoration: deco('Short description')),
              const SizedBox(height: 20),
              SizedBox(width: double.infinity, child: ElevatedButton(
                onPressed: saving ? null : save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _brand600, foregroundColor: Colors.white, elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 15)),
                child: saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(editing ? 'Save Changes' : 'Add', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              )),
            ]),
          ),
        );
      }),
    );
  }

  Widget _header() => Container(
    color: context.headerBg,
    padding: EdgeInsets.fromLTRB(8, MediaQuery.of(context).padding.top + 10, 18, 14),
    child: Row(children: [
      IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        onPressed: () => context.go('/settings'),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(),
      ),
      const SizedBox(width: 6),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_c.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
        Text(_loading ? 'Loading…' : '${_items.length} ${_items.length == 1 ? 'entry' : 'entries'}',
            style: TextStyle(fontSize: 12.5, color: context.textSub, fontWeight: FontWeight.w500)),
      ])),
    ]),
  );

  Widget _row(Map<String, dynamic> t, bool last) {
    final label = t['label'] as String? ?? '';
    final desc = t['description'] as String? ?? '';
    final active = t['isActive'] as bool? ?? true;
    final system = t['isSystem'] == true;
    final count = (t['studentCount'] as num?)?.toInt() ?? ((t['_count'] as Map?)?['students'] as num?)?.toInt();
    final key = t['key'] as String?;
    final color = _c == _studentStatuses ? StudentLookups.statusColor(key) : _brand600;
    final sub = [
      if (desc.isNotEmpty) desc,
      if (count != null) '$count student${count == 1 ? '' : 's'}',
      if (system) 'Built in',
    ].join('  ·  ');
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
      decoration: last ? null : BoxDecoration(border: Border(bottom: BorderSide(color: context.border))),
      child: Row(children: [
        Container(width: 40, height: 40,
          decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(11)),
          child: Icon(_c.icon, color: color, size: 20)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700,
              color: active ? context.textPrimary : context.textHint)),
          if (sub.isNotEmpty)
            Text(sub, style: TextStyle(fontSize: 12, color: context.textHint, fontWeight: FontWeight.w500)),
        ])),
        Switch(value: active, onChanged: system ? null : (v) => _toggle(t, v), activeColor: _brand600),
        PopupMenuButton<String>(
          tooltip: 'More',
          icon: Icon(Icons.more_vert, color: context.textHint),
          onSelected: (v) => v == 'edit' ? _showEditor(t) : _delete(t),
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'edit', child: Row(children: [
              Icon(Icons.edit_outlined, size: 18), SizedBox(width: 10), Text('Edit'),
            ])),
            if (!system)
              const PopupMenuItem(value: 'delete', child: Row(children: [
                Icon(Icons.delete_outline, size: 18, color: _coral500), SizedBox(width: 10),
                Text('Delete', style: TextStyle(color: _coral500)),
              ])),
          ],
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(children: [
      _header(),
      Expanded(child: _loading
        ? const Center(child: CircularProgressIndicator(strokeWidth: 2.5, color: _brand600))
        : _error != null
          ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.cloud_off_outlined, size: 40, color: context.textHint),
              const SizedBox(height: 10),
              Text(_error!, textAlign: TextAlign.center, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: context.textSub)),
              const SizedBox(height: 14),
              OutlinedButton(onPressed: _load, child: const Text('Retry', style: TextStyle(fontWeight: FontWeight.w700, color: _brand600))),
            ])))
          : RefreshIndicator(
              onRefresh: _load,
              color: _brand600,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 100),
                child: _items.isEmpty
                  ? Padding(padding: const EdgeInsets.only(top: 60), child: Center(child: Column(children: [
                      Icon(_c.icon, size: 44, color: context.textHint),
                      const SizedBox(height: 10),
                      Text('Nothing here yet.', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: context.textSub)),
                      const SizedBox(height: 4),
                      Text(_c.emptyHelp, textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12.5, color: context.textHint, fontWeight: FontWeight.w500)),
                    ])))
                  : Container(
                      decoration: BoxDecoration(
                        color: context.cardBg, borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: context.border),
                        boxShadow: const [BoxShadow(color: Color(0x080D2822), blurRadius: 6, offset: Offset(0, 2))],
                      ),
                      child: Column(children: [
                        for (var i = 0; i < _items.length; i++) _row(_items[i], i == _items.length - 1),
                      ]),
                    ),
              ),
            )),
    ]),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: () => _showEditor(),
      backgroundColor: _brand600, foregroundColor: Colors.white,
      icon: const Icon(Icons.add),
      label: Text('Add ${_c.noun[0].toUpperCase()}${_c.noun.substring(1)}', style: const TextStyle(fontWeight: FontWeight.w700)),
    ),
  );
}
