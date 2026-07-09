import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';

// ── palette ──────────────────────────────────────────────────────────
const _brand600   = Color(0xFF0E8C76);
const _brand100   = Color(0xFFD6F3EC);
const _coral500   = Color(0xFFF2685E);
const _coral100   = Color(0xFFFFE3DF);
const _onSurface2 = Color(0xFF5A6B67);
const _onSurface3 = Color(0xFF93A29F);
const _border     = Color(0xFFE5EBE9);
const _surface2   = Color(0xFFF4F7F6);

// ── data model ───────────────────────────────────────────────────────
class DonorCategory {
  DonorCategory({
    required this.id,
    required this.name,
    required this.desc,
    required this.iconKey,
    required this.colorHex,
    this.donorCount = 0,
  });

  String id;
  String name;
  String desc;
  String iconKey;
  String colorHex;
  int donorCount;

  IconData get icon => _iconByKey[iconKey] ?? _iconOptions.first.$1;
  Color get color {
    try { return Color(int.parse('FF${colorHex.replaceAll('#', '')}', radix: 16)); }
    catch (_) { return _brand600; }
  }
  Color get bgColor => color.withValues(alpha: 0.15);

  factory DonorCategory.fromJson(Map<String, dynamic> j) => DonorCategory(
    id: j['id'] as String,
    name: j['name'] as String? ?? '',
    desc: j['description'] as String? ?? '',
    iconKey: j['icon'] as String? ?? _iconOptions.first.$2,
    colorHex: j['color'] as String? ?? '#0E8C76',
    donorCount: (j['_count'] as Map?)?['donors'] as int? ?? 0,
  );

  DonorCategory copyWith({String? name, String? desc, String? iconKey, String? colorHex, int? donorCount}) => DonorCategory(
    id: id,
    name: name ?? this.name,
    desc: desc ?? this.desc,
    iconKey: iconKey ?? this.iconKey,
    colorHex: colorHex ?? this.colorHex,
    donorCount: donorCount ?? this.donorCount,
  );
}

// ── palette options for pickers ──────────────────────────────────────
const _colorOptions = [
  (Color(0xFF0E8C76), '#0E8C76'),   // teal
  (Color(0xFF7C6CF0), '#7C6CF0'),   // violet
  (Color(0xFF2D9CDB), '#2D9CDB'),   // sky
  (Color(0xFFE0921A), '#E0921A'),   // amber
  (Color(0xFFF2685E), '#F2685E'),   // coral
  (Color(0xFF1FA971), '#1FA971'),   // green
  (Color(0xFFEC5B8B), '#EC5B8B'),   // pink
  (Color(0xFF5BAE8A), '#5BAE8A'),   // sage
];

const _iconOptions = [
  (Icons.refresh_rounded,                  'Recurring'),
  (Icons.calendar_today_outlined,          'Annual'),
  (Icons.school_outlined,                  'Education'),
  (Icons.star_outline_rounded,             'Major'),
  (Icons.business_outlined,               'Corporate'),
  (Icons.history_rounded,                  'Inactive'),
  (Icons.person_add_outlined,             'Prospect'),
  (Icons.volunteer_activism_outlined,      'Volunteer'),
  (Icons.favorite_outline,                 'Sponsor'),
  (Icons.emoji_events_outlined,            'Premium'),
  (Icons.groups_outlined,                  'Community'),
  (Icons.handshake_outlined,               'Partner'),
  (Icons.local_hospital_outlined,          'Medical'),
  (Icons.child_care_outlined,              'Child'),
  (Icons.eco_outlined,                     'Green'),
  (Icons.public_outlined,                  'Global'),
];
final Map<String, IconData> _iconByKey = { for (final o in _iconOptions) o.$2: o.$1 };

// ── Riverpod state: backend-backed donor categories ───────────────────
class _CategoriesNotifier extends StateNotifier<List<DonorCategory>> {
  _CategoriesNotifier() : super([]);
  bool loading = true;
  String? error;

  Future<void> loadFromBackend() async {
    loading = true;
    try {
      final res = await apiClient.get('/categories');
      final list = (res['data'] as List<dynamic>? ?? const []);
      state = list.whereType<Map>().map((m) => DonorCategory.fromJson(m.cast<String, dynamic>())).toList();
      error = null;
    } catch (e) {
      error = 'Could not load categories';
    }
    loading = false;
    state = [...state]; // trigger listeners even if the list itself is unchanged
  }

  Future<bool> add(DonorCategory cat) async {
    try {
      await apiClient.post('/categories', {
        'name': cat.name, 'description': cat.desc, 'icon': cat.iconKey, 'color': cat.colorHex,
      });
      await loadFromBackend();
      return true;
    } catch (_) { return false; }
  }

  Future<bool> update(String id, DonorCategory updated) async {
    try {
      await apiClient.put('/categories/$id', {
        'name': updated.name, 'description': updated.desc, 'icon': updated.iconKey, 'color': updated.colorHex,
      });
      await loadFromBackend();
      return true;
    } catch (_) { return false; }
  }

  Future<bool> delete(String id) async {
    try {
      await apiClient.delete('/categories/$id');
      await loadFromBackend();
      return true;
    } catch (_) { return false; }
  }
}

final donorCategoriesProvider =
  StateNotifierProvider<_CategoriesNotifier, List<DonorCategory>>(
    (_) => _CategoriesNotifier());

// ════════════════════════════════════════════════════════════════════
// SCREEN
// ════════════════════════════════════════════════════════════════════
class DonorCategoriesScreen extends ConsumerStatefulWidget {
  const DonorCategoriesScreen({super.key});
  @override
  ConsumerState<DonorCategoriesScreen> createState() => _DonorCategoriesScreenState();
}

class _DonorCategoriesScreenState extends ConsumerState<DonorCategoriesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => ref.read(donorCategoriesProvider.notifier).loadFromBackend());
  }

  void _snack(String msg, {bool error = false}) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w700)),
      backgroundColor: error ? _coral500 : _brand600,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 2),
    ));

  void _openForm({DonorCategory? editing}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CategoryFormSheet(
        existing: editing,
        onSave: (cat) async {
          final notifier = ref.read(donorCategoriesProvider.notifier);
          final ok = editing != null ? await notifier.update(editing.id, cat) : await notifier.add(cat);
          if (!mounted) return;
          _snack(ok ? (editing != null ? 'Category updated' : 'Category added') : 'Could not save — check your connection', error: !ok);
        },
      ),
    );
  }

  void _confirmDelete(DonorCategory cat) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Delete Category?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
      content: Text(
        '"${cat.name}" has ${cat.donorCount} donor${cat.donorCount == 1 ? '' : 's'}. '
        'Donors will not be deleted but will become uncategorised.',
        style: const TextStyle(fontSize: 14, color: _onSurface2, fontWeight: FontWeight.w500, height: 1.45)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700, color: _onSurface2))),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(ctx);
            final ok = await ref.read(donorCategoriesProvider.notifier).delete(cat.id);
            if (!mounted) return;
            _snack(ok ? '${cat.name} deleted' : 'Could not delete — check your connection', error: !ok);
          },
          style: ElevatedButton.styleFrom(backgroundColor: _coral500, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(donorCategoriesProvider);
    final loading = ref.read(donorCategoriesProvider.notifier).loading;
    final top = MediaQuery.of(context).padding.top;
    final totalDonors = categories.fold(0, (s, c) => s + c.donorCount);

    return Scaffold(
      backgroundColor: _surface2,
      body: Column(children: [
        // ── header ───────────────────────────────────────────────────
        Container(
          color: Colors.white,
          padding: EdgeInsets.fromLTRB(8, top + 10, 18, 14),
          child: Row(children: [
            IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20), onPressed: () => context.go('/donors'), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
            const SizedBox(width: 6),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Donor Categorization', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
              Text('${categories.length} categories · $totalDonors donors', style: const TextStyle(fontSize: 12.5, color: _onSurface2, fontWeight: FontWeight.w500)),
            ])),
            GestureDetector(
              onTap: () => _openForm(),
              child: Container(width: 38, height: 38, decoration: const BoxDecoration(color: _brand600, shape: BoxShape.circle), child: const Icon(Icons.add, color: Colors.white, size: 22)),
            ),
          ]),
        ),

        // ── info banner ───────────────────────────────────────────────
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: _brand100, borderRadius: BorderRadius.circular(12), border: Border.all(color: _brand600.withValues(alpha: 0.2))),
            child: const Row(children: [
              Icon(Icons.info_outline, color: _brand600, size: 16),
              SizedBox(width: 8),
              Expanded(child: Text(
                'Tap a category to see its donors. Use the pencil to rename, recolour, or edit it.',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _onSurface2, height: 1.4))),
            ]),
          ),
        ),

        const SizedBox(height: 10),

        // ── list ─────────────────────────────────────────────────────
        Expanded(
          child: loading
            ? const Center(child: CircularProgressIndicator(color: _brand600))
            : categories.isEmpty
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.category_outlined, size: 52, color: _onSurface3.withValues(alpha: 0.5)),
                  const SizedBox(height: 12),
                  const Text('No categories yet', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _onSurface3)),
                  const SizedBox(height: 6),
                  const Text('Tap + to add your first category', style: TextStyle(fontSize: 13, color: _onSurface3, fontWeight: FontWeight.w500)),
                ]))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 100),
                  itemCount: categories.length,
                  itemBuilder: (ctx, i) {
                    final cat = categories[i];
                    return _CategoryCard(
                      key: ValueKey(cat.id),
                      category: cat,
                      onOpen: () => context.go('/donors/categories/${cat.id}', extra: cat),
                      onEdit: () => _openForm(editing: cat),
                      onDelete: () => _confirmDelete(cat),
                    );
                  },
                ),
        ),
      ]),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: _brand600, foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Category', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }
}

// ── Category card ─────────────────────────────────────────────────────
class _CategoryCard extends StatelessWidget {
  const _CategoryCard({super.key, required this.category, required this.onOpen, required this.onEdit, required this.onDelete});
  final DonorCategory category;
  final VoidCallback onOpen, onEdit, onDelete;

  @override
  Widget build(BuildContext context) => Dismissible(
    key: ValueKey(category.id),
    direction: DismissDirection.endToStart,
    confirmDismiss: (_) async {
      onDelete();
      return false; // we handle deletion ourselves
    },
    background: Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(color: _coral100, borderRadius: BorderRadius.circular(20)),
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 24),
      child: const Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.delete_outline, color: _coral500, size: 26),
        SizedBox(height: 4),
        Text('Delete', style: TextStyle(color: _coral500, fontWeight: FontWeight.w700, fontSize: 11)),
      ]),
    ),
    child: GestureDetector(
      onTap: onOpen,
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white, borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _border),
          boxShadow: const [BoxShadow(color: Color(0x080D2822), blurRadius: 6, offset: Offset(0, 2))],
        ),
        child: Row(children: [
          // colour strip
          Container(width: 5, height: 76, decoration: BoxDecoration(
            color: category.color,
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), bottomLeft: Radius.circular(20)),
          )),

          // icon
          Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Container(
            width: 46, height: 46,
            decoration: BoxDecoration(color: category.bgColor, borderRadius: BorderRadius.circular(14)),
            child: Icon(category.icon, color: category.color, size: 22),
          )),

          // text
          Expanded(child: Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(category.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: -0.2)),
            const SizedBox(height: 3),
            Text(category.desc, style: const TextStyle(fontSize: 12.5, color: _onSurface2, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
          ]))),

          // donor count badge
          Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(color: category.bgColor, borderRadius: BorderRadius.circular(10)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text('${category.donorCount}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: category.color)),
              Text('donors', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: category.color.withValues(alpha: 0.8))),
            ]),
          ),

          // edit button
          GestureDetector(
            onTap: onEdit,
            behavior: HitTestBehavior.opaque,
            child: Padding(padding: const EdgeInsets.fromLTRB(0, 16, 12, 16), child: Icon(Icons.edit_outlined, size: 18, color: _onSurface3)),
          ),

          Padding(padding: const EdgeInsets.only(right: 12), child: Icon(Icons.chevron_right_rounded, size: 20, color: _onSurface3.withValues(alpha: 0.7))),
        ]),
      ),
    ),
  );
}

// ── Form bottom sheet ─────────────────────────────────────────────────
class _CategoryFormSheet extends StatefulWidget {
  const _CategoryFormSheet({this.existing, required this.onSave});
  final DonorCategory? existing;
  final void Function(DonorCategory) onSave;
  @override
  State<_CategoryFormSheet> createState() => _CategoryFormSheetState();
}

class _CategoryFormSheetState extends State<_CategoryFormSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late Color _selColor;
  late String _selColorHex;
  late IconData _selIcon;
  late String _selIconKey;

  bool get _isEditing => widget.existing != null;
  String _nameErr = '';

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _descCtrl = TextEditingController(text: e?.desc ?? '');
    _selColor = e?.color ?? _colorOptions[0].$1;
    _selColorHex = e?.colorHex ?? _colorOptions[0].$2;
    _selIcon  = e?.icon ?? _iconOptions[0].$1;
    _selIconKey = e?.iconKey ?? _iconOptions[0].$2;
  }

  @override
  void dispose() { _nameCtrl.dispose(); _descCtrl.dispose(); super.dispose(); }

  void _save() {
    if (_nameCtrl.text.trim().isEmpty) { setState(() => _nameErr = 'Name is required'); return; }
    final cat = DonorCategory(
      id: widget.existing?.id ?? '',
      name: _nameCtrl.text.trim(),
      desc: _descCtrl.text.trim(),
      iconKey: _selIconKey,
      colorHex: _selColorHex,
      donorCount: widget.existing?.donorCount ?? 0,
    );
    Navigator.pop(context);
    widget.onSave(cat);
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
    child: Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // handle + title
        Padding(padding: const EdgeInsets.fromLTRB(20, 14, 20, 0), child: Column(children: [
          Container(width: 40, height: 4, decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 14),
          Row(children: [
            Container(width: 40, height: 40, decoration: BoxDecoration(color: _selColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)), child: Icon(_selIcon, color: _selColor, size: 20)),
            const SizedBox(width: 12),
            Text(_isEditing ? 'Edit Category' : 'New Category', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const Spacer(),
            IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(context), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
          ]),
        ])),

        const SizedBox(height: 6),
        const Divider(height: 1),

        // scrollable form body
        Flexible(child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Name
            _label('Category Name *'),
            const SizedBox(height: 6),
            TextField(
              controller: _nameCtrl,
              onChanged: (_) { if (_nameErr.isNotEmpty) setState(() => _nameErr = ''); },
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                hintText: 'e.g. Monthly Donor',
                hintStyle: const TextStyle(fontSize: 14, color: _onSurface3, fontWeight: FontWeight.w500),
                errorText: _nameErr.isEmpty ? null : _nameErr,
                filled: true, fillColor: _surface2,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _brand600, width: 1.5)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              ),
            ),
            const SizedBox(height: 14),

            // Description
            _label('Description'),
            const SizedBox(height: 6),
            TextField(
              controller: _descCtrl,
              style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                hintText: 'Short description (shown in filters)',
                hintStyle: const TextStyle(fontSize: 14, color: _onSurface3, fontWeight: FontWeight.w500),
                filled: true, fillColor: _surface2,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _brand600, width: 1.5)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              ),
            ),
            const SizedBox(height: 18),

            // Icon picker
            _label('Icon'),
            const SizedBox(height: 8),
            SizedBox(
              height: 52,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _iconOptions.length,
                itemBuilder: (_, i) {
                  final opt = _iconOptions[i];
                  final sel = _selIconKey == opt.$2;
                  return GestureDetector(
                    onTap: () => setState(() { _selIcon = opt.$1; _selIconKey = opt.$2; }),
                    child: Container(
                      width: 48, height: 48, margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: sel ? _selColor.withValues(alpha: 0.15) : _surface2,
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(color: sel ? _selColor : _border, width: sel ? 2 : 1),
                      ),
                      child: Icon(opt.$1, color: sel ? _selColor : _onSurface3, size: 22),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 18),

            // Colour picker
            _label('Colour'),
            const SizedBox(height: 8),
            Wrap(spacing: 10, runSpacing: 10, children: _colorOptions.map((opt) {
              final sel = _selColorHex == opt.$2;
              return GestureDetector(
                onTap: () => setState(() { _selColor = opt.$1; _selColorHex = opt.$2; }),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: opt.$1, shape: BoxShape.circle,
                    border: Border.all(color: sel ? Colors.black.withValues(alpha: 0.4) : Colors.transparent, width: 2.5),
                  ),
                  child: sel ? const Icon(Icons.check, color: Colors.white, size: 18) : null,
                ),
              );
            }).toList()),
            const SizedBox(height: 24),

            // Preview
            _label('Preview'),
            const SizedBox(height: 8),
            _buildPreview(),
            const SizedBox(height: 8),
          ]),
        )),

        // Action buttons
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          child: Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: _border, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14)),
              child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w800, color: _onSurface2)),
            )),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: _brand600, foregroundColor: Colors.white, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 14)),
              child: Text(_isEditing ? 'Save Changes' : 'Add Category', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            )),
          ]),
        ),
      ]),
    ),
  );

  Widget _buildPreview() => Container(
    padding: const EdgeInsets.fromLTRB(0, 0, 16, 0),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border)),
    child: Row(children: [
      Container(width: 5, height: 68, decoration: BoxDecoration(
        color: _selColor,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
      )),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 14), child: Container(
        width: 42, height: 42, decoration: BoxDecoration(color: _selColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
        child: Icon(_selIcon, color: _selColor, size: 20),
      )),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_nameCtrl.text.isEmpty ? 'Category Name' : _nameCtrl.text, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: _nameCtrl.text.isEmpty ? _onSurface3 : Colors.black)),
        const SizedBox(height: 3),
        Text(_descCtrl.text.isEmpty ? 'Description' : _descCtrl.text, style: const TextStyle(fontSize: 12, color: _onSurface2, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
      ])),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(color: _selColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${widget.existing?.donorCount ?? 0}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _selColor)),
          Text('donors', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: _selColor.withValues(alpha: 0.8))),
        ]),
      ),
    ]),
  );

  Widget _label(String t) => Text(t, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _onSurface2));
}
