import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../students/student_lookups.dart';
import 'package:saksham_app/core/ui/ui.dart';

const _brand600 = Color(0xFFFF9933);
const _danger = Color(0xFFE5484D);

// ══════════════════════════════════════════════════════════════════════
// STUDENT MASTER LISTS — one screen, three lists, all admin-managed:
//   • Support Categories  (/students/categories…)
//   • Student Status      (/students/lookups/STATUS…)
//   • Education Levels    (/students/lookups/EDUCATION_LEVEL…)
// Each supports add, rename/edit, switch on/off and delete. Delete is refused
// by the server while students still use an entry — switch it off instead.
//
// This screen is the reference for the app's UI kit (lib/core/ui): compact
// header with the primary action, skeleton loading, compact rows, toggles
// with an in-place loading state, anchored ⋮ menu, AppConfirm for delete,
// AppToast for every outcome, and a compact add/edit modal.
// ══════════════════════════════════════════════════════════════════════

class _MasterConfig {
  const _MasterConfig({
    required this.title,
    required this.noun,
    required this.plural,
    required this.icon,
    required this.listAllPath,
    required this.createPath,
    required this.itemPath,
    required this.hint,
    required this.emptyHelp,
  });
  final String title;
  final String noun;              // "category", "status", "education level"
  final String plural;
  final IconData icon;
  final String listAllPath;
  final String createPath;
  final String Function(String id) itemPath;
  final String hint;
  final String emptyHelp;

  String get nounTitle => '${noun[0].toUpperCase()}${noun.substring(1)}';
}

final _supportCategories = _MasterConfig(
  title: 'Support Categories',
  noun: 'category',
  plural: 'categories',
  icon: Icons.volunteer_activism_outlined,
  listAllPath: '/students/categories/all',
  createPath: '/students/categories',
  itemPath: (id) => '/students/categories/$id',
  hint: 'e.g. Full Support',
  emptyHelp: 'Create a category like Full Support or Semi Support to classify students.',
);

final _studentStatuses = _MasterConfig(
  title: 'Student Status',
  noun: 'status',
  plural: 'statuses',
  icon: Icons.flag_outlined,
  listAllPath: '/students/lookups/STATUS/all',
  createPath: '/students/lookups/STATUS',
  itemPath: (id) => '/students/lookup-items/$id',
  hint: 'e.g. Former Student',
  emptyHelp: 'Create a status to start managing student records.',
);

final _educationLevels = _MasterConfig(
  title: 'Education Levels',
  noun: 'education level',
  plural: 'education levels',
  icon: Icons.school_outlined,
  listAllPath: '/students/lookups/EDUCATION_LEVEL/all',
  createPath: '/students/lookups/EDUCATION_LEVEL',
  itemPath: (id) => '/students/lookup-items/$id',
  hint: 'e.g. High School',
  emptyHelp: 'Create levels like Primary School, High School or College.',
);

final _documentTypes = _MasterConfig(
  title: 'Document Types',
  noun: 'document type',
  plural: 'document types',
  icon: Icons.description_outlined,
  listAllPath: '/students/lookups/DOCUMENT_TYPE/all',
  createPath: '/students/lookups/DOCUMENT_TYPE',
  itemPath: (id) => '/students/lookup-items/$id',
  hint: 'e.g. Caste Certificate',
  emptyHelp: 'Names offered when uploading a student document. Staff can also add one with “+ New name”.',
);

class DocumentTypesScreen extends StatelessWidget {
  const DocumentTypesScreen({super.key});
  @override
  Widget build(BuildContext context) => _StudentMasterScreen(config: _documentTypes);
}

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
  // Rows with a toggle request in flight — the switch shows a spinner and
  // ignores further taps until the server answers.
  final Set<String> _toggling = {};

  _MasterConfig get _c => widget.config;

  @override
  void initState() { super.initState(); _load(); }

  // [quiet] refreshes in place (after an edit) without the skeleton flash.
  Future<void> _load({bool quiet = false}) async {
    if (!quiet) setState(() { _loading = true; _error = null; });
    try {
      final r = await apiClient.get(_c.listAllPath);
      final list = (r['data'] as List? ?? []).whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
      if (!mounted) return;
      setState(() { _items = list; _loading = false; _error = null; });
    } catch (e) {
      if (!mounted) return;
      if (quiet && _items.isNotEmpty) {
        AppToast.error(context, 'Couldn’t refresh the list', detail: ApiClient.errorMessage(e));
        return;
      }
      setState(() { _error = ApiClient.errorMessage(e, fallback: 'Could not load ${_c.title.toLowerCase()}.'); _loading = false; });
    }
  }

  // Every change refreshes the shared cache so Add Student and the student
  // screens pick it up straight away.
  void _changed() {
    StudentLookups.load(force: true);
    _load(quiet: true);
  }

  Future<void> _toggle(Map<String, dynamic> item, bool v) async {
    final id = item['id'] as String;
    if (_toggling.contains(id)) return;
    setState(() => _toggling.add(id));
    try {
      await apiClient.put(_c.itemPath(id), {'isActive': v});
      if (!mounted) return;
      // Only flip once the server has accepted it — the UI always shows the
      // real state.
      setState(() { item['isActive'] = v; _toggling.remove(id); });
      AppToast.success(context, '“${item['label']}” ${v ? 'enabled' : 'disabled'}');
      StudentLookups.load(force: true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _toggling.remove(id));
      AppToast.error(context, 'Unable to update ${_c.noun}', detail: ApiClient.errorMessage(e));
    }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final label = item['label'] as String? ?? '';
    final ok = await AppConfirm.show(
      context,
      title: 'Delete ${_c.noun}?',
      message: 'Are you sure you want to delete “$label”? This action cannot be undone.',
      onConfirm: () => apiClient.delete(_c.itemPath(item['id'] as String)),
      errorText: (e) => ApiClient.errorMessage(e, fallback: 'Could not delete the ${_c.noun}.'),
    );
    if (!ok || !mounted) return;
    AppToast.success(context, '${_c.nounTitle} deleted');
    setState(() => _items.remove(item));
    _changed();
  }

  // Add (item == null) or edit an entry.
  Future<void> _showEditor([Map<String, dynamic>? item]) async {
    final saved = await showAppSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _MasterEditor(config: _c, item: item),
    );
    if (saved == null || !mounted) return;
    AppToast.success(context, item != null ? 'Changes saved' : '${_c.nounTitle} added', detail: '“$saved”');
    _changed();
  }

  Widget _header() => Container(
    decoration: BoxDecoration(color: context.headerBg, border: Border(bottom: BorderSide(color: context.border))),
    padding: EdgeInsets.fromLTRB(8, MediaQuery.of(context).padding.top + 10, 16, 10),
    child: Row(children: [
      IconButton(
        tooltip: 'Back to Settings',
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
        onPressed: () => context.go('/settings'),
      ),
      const SizedBox(width: 2),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        Text(_c.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.2)),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          child: Text(
            _loading ? 'Loading…' : '${_items.length} ${_items.length == 1 ? _c.noun : _c.plural} configured',
            key: ValueKey(_loading ? -1 : _items.length),
            style: TextStyle(fontSize: 12.5, color: context.textSub, fontWeight: FontWeight.w500)),
        ),
      ])),
      // In the header rather than a floating button, so a toast can never
      // cover it.
      AppButton(label: 'Add ${_c.nounTitle}', icon: Icons.add, onPressed: () => _showEditor()),
    ]),
  );

  Widget _row(Map<String, dynamic> t, bool last) {
    final label = t['label'] as String? ?? '';
    final desc = t['description'] as String? ?? '';
    final active = t['isActive'] as bool? ?? true;
    final system = t['isSystem'] == true;
    final busy = _toggling.contains(t['id']);
    final count = (t['studentCount'] as num?)?.toInt() ?? ((t['_count'] as Map?)?['students'] as num?)?.toInt();
    final docCount = (t['documentCount'] as num?)?.toInt();
    final key = t['key'] as String?;
    final color = _c == _studentStatuses ? StudentLookups.statusColor(key) : _brand600;
    final sub = [
      if (count != null) '$count student${count == 1 ? '' : 's'}',
      if (docCount != null) '$docCount document${docCount == 1 ? '' : 's'}',
      if (system) 'Built in',
      if (desc.isNotEmpty) desc,
    ].join('  ·  ');

    return _HoverRow(
      last: last,
      child: Row(children: [
        Container(width: 34, height: 34,
          decoration: BoxDecoration(color: color.withValues(alpha: active ? 0.12 : 0.06), borderRadius: BorderRadius.circular(9)),
          child: Icon(_c.icon, color: active ? color : context.textHint, size: 17)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: active ? context.textPrimary : context.textHint)),
          if (sub.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: context.textHint, fontWeight: FontWeight.w500)),
          ],
        ])),
        const SizedBox(width: 8),
        // Built-in entries are always on: a lock badge says so plainly instead
        // of a greyed-out switch that looks switched off.
        if (system)
          Tooltip(
            message: 'Built in — always active',
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: context.surface2, borderRadius: BorderRadius.circular(6)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.lock_outline_rounded, size: 12, color: context.textSub),
                const SizedBox(width: 4),
                Text('Always on', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: context.textSub)),
              ]),
            ),
          )
        else
          SizedBox(
            width: 48, height: 28,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: busy
                  ? const Center(key: ValueKey('busy'), child: AppSpinner())
                  : Transform.scale(
                      key: const ValueKey('sw'),
                      scale: 0.78,
                      child: Semantics(
                        label: '${active ? 'Disable' : 'Enable'} $label',
                        child: Switch(value: active, onChanged: (v) => _toggle(t, v)),
                      ),
                    ),
            ),
          ),
        const SizedBox(width: 4),
        PopupMenuButton<String>(
          tooltip: 'Actions for $label',
          icon: Icon(Icons.more_horiz_rounded, color: context.textSub, size: 20),
          position: PopupMenuPosition.under,
          offset: const Offset(0, 4),
          constraints: const BoxConstraints(minWidth: 150),
          onSelected: (v) {
            if (v == 'edit') _showEditor(t);
            if (v == 'toggle') _toggle(t, !active);
            if (v == 'delete') _delete(t);
          },
          itemBuilder: (_) => [
            _menuItem('edit', Icons.edit_outlined, 'Edit'),
            if (!system) _menuItem('toggle', active ? Icons.toggle_off_outlined : Icons.toggle_on_outlined, active ? 'Disable' : 'Enable'),
            if (!system) const PopupMenuDivider(height: 8),
            if (!system) _menuItem('delete', Icons.delete_outline_rounded, 'Delete', danger: true),
          ],
        ),
      ]),
    );
  }

  PopupMenuItem<String> _menuItem(String value, IconData icon, String text, {bool danger = false}) => PopupMenuItem(
    value: value,
    height: 36,
    child: Row(children: [
      Icon(icon, size: 17, color: danger ? _danger : context.textSub),
      const SizedBox(width: 10),
      Text(text, style: TextStyle(fontSize: 13.5, color: danger ? _danger : context.textPrimary, fontWeight: FontWeight.w500)),
    ]),
  );

  Widget _card(Widget child) => Container(
    decoration: BoxDecoration(
      color: context.cardBg, borderRadius: BorderRadius.circular(12),
      border: Border.all(color: context.border),
    ),
    clipBehavior: Clip.antiAlias,
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (_loading) {
      content = _card(const SkeletonList(rows: 4, rowHeight: 64));
    } else if (_error != null) {
      content = _card(ErrorState(message: _error!, onRetry: _load));
    } else if (_items.isEmpty) {
      content = _card(EmptyState(
        icon: _c.icon,
        title: 'No ${_c.title.toLowerCase()} yet',
        message: _c.emptyHelp,
        actionLabel: 'Add ${_c.nounTitle}',
        onAction: () => _showEditor(),
      ));
    } else {
      content = _card(Column(children: [
        for (var i = 0; i < _items.length; i++) _row(_items[i], i == _items.length - 1),
      ]));
    }

    return Scaffold(
      body: Column(children: [
        _header(),
        Expanded(child: RefreshIndicator(
          onRefresh: () => _load(quiet: true),
          color: _brand600,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 880),
                child: AnimatedSwitcher(duration: const Duration(milliseconds: 180), child: KeyedSubtree(
                  key: ValueKey(_loading ? 'l' : _error != null ? 'e' : _items.isEmpty ? 'x' : 'd'),
                  child: content,
                )),
              ),
            ),
          ),
        )),
      ]),
    );
  }
}

// Row with a subtle hover tint and a hairline divider.
class _HoverRow extends StatefulWidget {
  const _HoverRow({required this.child, required this.last});
  final Widget child;
  final bool last;
  @override
  State<_HoverRow> createState() => _HoverRowState();
}

class _HoverRowState extends State<_HoverRow> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hover = true),
    onExit: (_) => setState(() => _hover = false),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: _hover ? context.surface2.withValues(alpha: 0.6) : Colors.transparent,
        border: widget.last ? null : Border(bottom: BorderSide(color: context.border.withValues(alpha: 0.7))),
      ),
      child: widget.child,
    ),
  );
}

// Compact add/edit form. Validates on leaving the field and on submit, keeps
// what was typed if the save fails, and can't be submitted twice.
class _MasterEditor extends StatefulWidget {
  const _MasterEditor({required this.config, this.item});
  final _MasterConfig config;
  final Map<String, dynamic>? item;
  @override
  State<_MasterEditor> createState() => _MasterEditorState();
}

class _MasterEditorState extends State<_MasterEditor> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.item?['label'] as String? ?? '');
  late final _desc = TextEditingController(text: widget.item?['description'] as String? ?? '');
  bool _saving = false;
  String? _serverError;

  bool get _editing => widget.item != null;
  _MasterConfig get _c => widget.config;

  @override
  void dispose() { _name.dispose(); _desc.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _serverError = null);
    if (!_form.currentState!.validate()) return;
    final name = _name.text.trim();
    setState(() => _saving = true);
    try {
      if (_editing) {
        await apiClient.put(_c.itemPath(widget.item!['id'] as String), {'label': name, 'description': _desc.text.trim()});
      } else {
        await apiClient.post(_c.createPath, {
          'label': name,
          if (_desc.text.trim().isNotEmpty) 'description': _desc.text.trim(),
        });
      }
      if (mounted) Navigator.of(context).pop(name);
    } catch (e) {
      if (!mounted) return;
      // A duplicate/validation answer belongs under the name field; anything
      // else (network, server) is a toast.
      final msg = ApiClient.errorMessage(e, fallback: 'Could not save the ${_c.noun}.');
      final fieldLevel = msg.toLowerCase().contains('exist') || msg.toLowerCase().contains('name');
      setState(() { _saving = false; if (fieldLevel) _serverError = msg; });
      _form.currentState!.validate();
      if (!fieldLevel) AppToast.error(context, 'Unable to save changes', detail: msg);
    }
  }

  InputDecoration _deco(String hint) => InputDecoration(hintText: hint);

  Widget _label(String t, {bool required = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text.rich(TextSpan(children: [
      TextSpan(text: t),
      if (required) const TextSpan(text: ' *', style: TextStyle(color: _danger)),
    ]), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: context.textSub)),
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(color: context.cardBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Form(
          key: _form,
          // Errors appear once a field has been touched, not while typing
          // the first characters.
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SheetHandle(margin: EdgeInsets.only(bottom: 10)),
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_editing ? 'Edit ${_c.noun}' : 'Add ${_c.noun}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(_editing ? 'Update the name or description.' : 'Create a new ${_c.noun} for students.',
                    style: TextStyle(fontSize: 12.5, color: context.textSub)),
              ])),
              IconButton(
                tooltip: 'Close',
                icon: Icon(Icons.close_rounded, size: 20, color: context.textSub),
                onPressed: _saving ? null : () => Navigator.of(context).pop(),
              ),
            ]),
            const SizedBox(height: 16),
            _label('Name', required: true),
            TextFormField(
              controller: _name,
              autofocus: true,
              enabled: !_saving,
              textInputAction: TextInputAction.next,
              onChanged: (_) { if (_serverError != null) setState(() => _serverError = null); },
              validator: (v) {
                if ((v ?? '').trim().isEmpty) return 'Please enter a name.';
                if ((v ?? '').trim().length > 60) return 'Keep the name under 60 characters.';
                return _serverError;
              },
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              decoration: _deco(_c.hint),
            ),
            const SizedBox(height: 12),
            _label('Description'),
            TextFormField(
              controller: _desc,
              enabled: !_saving,
              maxLength: 300,
              buildCounter: (_, {required currentLength, required isFocused, maxLength}) => null,
              onFieldSubmitted: (_) => _save(),
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              decoration: _deco('Short description (optional)'),
            ),
            const SizedBox(height: 18),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              AppButton(label: 'Cancel', variant: AppButtonVariant.secondary,
                  onPressed: _saving ? null : () => Navigator.of(context).pop()),
              const SizedBox(width: 8),
              AppButton(
                label: _editing ? 'Save Changes' : 'Add ${_c.nounTitle}',
                busyLabel: _editing ? 'Saving…' : 'Adding…',
                loading: _saving,
                onPressed: _save,
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}
