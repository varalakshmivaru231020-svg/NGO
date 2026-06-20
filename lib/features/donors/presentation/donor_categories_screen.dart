import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
    required this.icon,
    required this.color,
    required this.bgColor,
    this.donorCount = 0,
  });

  String id;
  String name;
  String desc;
  IconData icon;
  Color color;
  Color bgColor;
  int donorCount;

  DonorCategory copyWith({String? name, String? desc, IconData? icon, Color? color, Color? bgColor, int? donorCount}) => DonorCategory(
    id: id,
    name: name ?? this.name,
    desc: desc ?? this.desc,
    icon: icon ?? this.icon,
    color: color ?? this.color,
    bgColor: bgColor ?? this.bgColor,
    donorCount: donorCount ?? this.donorCount,
  );
}

// ── palette options for pickers ──────────────────────────────────────
const _colorOptions = [
  (Color(0xFF0E8C76), Color(0xFFD6F3EC)),   // teal
  (Color(0xFF7C6CF0), Color(0xFFE7E3FD)),   // violet
  (Color(0xFF2D9CDB), Color(0xFFDCEFFB)),   // sky
  (Color(0xFFE0921A), Color(0xFFFFF1D6)),   // amber
  (Color(0xFFF2685E), Color(0xFFFFE3DF)),   // coral
  (Color(0xFF1FA971), Color(0xFFD4F3E7)),   // green
  (Color(0xFFEC5B8B), Color(0xFFFFE1ED)),   // pink
  (Color(0xFF5BAE8A), Color(0xFFD9F0E6)),   // sage
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

// ── seed categories ──────────────────────────────────────────────────
List<DonorCategory> _seedCategories() => [
  DonorCategory(id: 'c1', name: 'Monthly Donor',   desc: 'Recurring monthly contributor',  icon: Icons.refresh_rounded,       color: const Color(0xFF0E8C76), bgColor: const Color(0xFFD6F3EC), donorCount: 98),
  DonorCategory(id: 'c2', name: 'Annual Donor',    desc: 'Gives once a year',               icon: Icons.calendar_today_outlined,color: const Color(0xFF1FA971), bgColor: const Color(0xFFD4F3E7), donorCount: 24),
  DonorCategory(id: 'c3', name: 'Child Sponsor',   desc: 'Sponsors a child\'s education',  icon: Icons.school_outlined,       color: const Color(0xFF7C6CF0), bgColor: const Color(0xFFE7E3FD), donorCount: 31),
  DonorCategory(id: 'c4', name: 'Major Donor',     desc: 'High-value patron',               icon: Icons.star_outline_rounded,  color: const Color(0xFFE0921A), bgColor: const Color(0xFFFFF1D6), donorCount: 52),
  DonorCategory(id: 'c5', name: 'Corporate Donor', desc: 'Company / CSR giving',            icon: Icons.business_outlined,    color: const Color(0xFF2D9CDB), bgColor: const Color(0xFFDCEFFB), donorCount: 18),
  DonorCategory(id: 'c6', name: 'Inactive Donor',  desc: 'No gift in 12+ months',           icon: Icons.history_rounded,       color: const Color(0xFF93A29F), bgColor: const Color(0xFFF4F7F6), donorCount: 0),
  DonorCategory(id: 'c7', name: 'Potential Donor', desc: 'Prospect / lead to cultivate',   icon: Icons.person_add_outlined,  color: const Color(0xFFF2685E), bgColor: const Color(0xFFFFE3DF), donorCount: 1),
];

// ── Riverpod state ───────────────────────────────────────────────────
class _CategoriesNotifier extends StateNotifier<List<DonorCategory>> {
  _CategoriesNotifier() : super(_seedCategories());

  void add(DonorCategory cat) => state = [...state, cat];

  void update(String id, DonorCategory updated) =>
    state = state.map((c) => c.id == id ? updated : c).toList();

  void delete(String id) =>
    state = state.where((c) => c.id != id).toList();

  void reorder(int oldIndex, int newIndex) {
    final list = [...state];
    if (newIndex > oldIndex) newIndex--;
    final item = list.removeAt(oldIndex);
    list.insert(newIndex, item);
    state = list;
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
        onSave: (cat) {
          if (editing != null) {
            ref.read(donorCategoriesProvider.notifier).update(editing.id, cat);
            _snack('Category updated');
          } else {
            ref.read(donorCategoriesProvider.notifier).add(cat);
            _snack('Category added');
          }
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
          onPressed: () {
            Navigator.pop(ctx);
            ref.read(donorCategoriesProvider.notifier).delete(cat.id);
            _snack('${cat.name} deleted', error: false);
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
                'Manage how donors are grouped. Categories are fully editable — add, rename, recolour, or remove to fit your programmes.',
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _onSurface2, height: 1.4))),
            ]),
          ),
        ),

        const SizedBox(height: 10),

        // ── list ─────────────────────────────────────────────────────
        Expanded(
          child: categories.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.category_outlined, size: 52, color: _onSurface3.withValues(alpha: 0.5)),
                const SizedBox(height: 12),
                const Text('No categories yet', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _onSurface3)),
                const SizedBox(height: 6),
                const Text('Tap + to add your first category', style: TextStyle(fontSize: 13, color: _onSurface3, fontWeight: FontWeight.w500)),
              ]))
            : ReorderableListView.builder(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 100),
                itemCount: categories.length,
                onReorder: (o, n) => ref.read(donorCategoriesProvider.notifier).reorder(o, n),
                proxyDecorator: (child, _, __) => Material(color: Colors.transparent, child: child),
                itemBuilder: (ctx, i) {
                  final cat = categories[i];
                  return _CategoryCard(
                    key: ValueKey(cat.id),
                    category: cat,
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
  const _CategoryCard({super.key, required this.category, required this.onEdit, required this.onDelete});
  final DonorCategory category;
  final VoidCallback onEdit, onDelete;

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
          child: Padding(padding: const EdgeInsets.fromLTRB(0, 16, 16, 16), child: Icon(Icons.edit_outlined, size: 18, color: _onSurface3)),
        ),

        // drag handle
        Padding(padding: const EdgeInsets.only(right: 12), child: Icon(Icons.drag_handle_rounded, size: 20, color: _onSurface3.withValues(alpha: 0.5))),
      ]),
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
  late Color _selBg;
  late IconData _selIcon;

  bool get _isEditing => widget.existing != null;
  String _nameErr = '';

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameCtrl = TextEditingController(text: e?.name ?? '');
    _descCtrl = TextEditingController(text: e?.desc ?? '');
    _selColor = e?.color ?? _colorOptions[0].$1;
    _selBg    = e?.bgColor ?? _colorOptions[0].$2;
    _selIcon  = e?.icon ?? _iconOptions[0].$1;
  }

  @override
  void dispose() { _nameCtrl.dispose(); _descCtrl.dispose(); super.dispose(); }

  void _save() {
    if (_nameCtrl.text.trim().isEmpty) { setState(() => _nameErr = 'Name is required'); return; }
    final cat = DonorCategory(
      id: widget.existing?.id ?? 'c${DateTime.now().millisecondsSinceEpoch}',
      name: _nameCtrl.text.trim(),
      desc: _descCtrl.text.trim(),
      icon: _selIcon,
      color: _selColor,
      bgColor: _selBg,
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
            Container(width: 40, height: 40, decoration: BoxDecoration(color: _selBg, borderRadius: BorderRadius.circular(12)), child: Icon(_selIcon, color: _selColor, size: 20)),
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
                  final sel = _selIcon == opt.$1;
                  return GestureDetector(
                    onTap: () => setState(() => _selIcon = opt.$1),
                    child: Container(
                      width: 48, height: 48, margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: sel ? _selBg : _surface2,
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
              final sel = _selColor == opt.$1;
              return GestureDetector(
                onTap: () => setState(() { _selColor = opt.$1; _selBg = opt.$2; }),
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
        width: 42, height: 42, decoration: BoxDecoration(color: _selBg, borderRadius: BorderRadius.circular(12)),
        child: Icon(_selIcon, color: _selColor, size: 20),
      )),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_nameCtrl.text.isEmpty ? 'Category Name' : _nameCtrl.text, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: _nameCtrl.text.isEmpty ? _onSurface3 : Colors.black)),
        const SizedBox(height: 3),
        Text(_descCtrl.text.isEmpty ? 'Description' : _descCtrl.text, style: const TextStyle(fontSize: 12, color: _onSurface2, fontWeight: FontWeight.w500), maxLines: 1, overflow: TextOverflow.ellipsis),
      ])),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(color: _selBg, borderRadius: BorderRadius.circular(10)),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('${widget.existing?.donorCount ?? 0}', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _selColor)),
          Text('donors', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: _selColor.withValues(alpha: 0.8))),
        ]),
      ),
    ]),
  );

  Widget _label(String t) => Text(t, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _onSurface2));
}
