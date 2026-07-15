import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/api_client.dart';

const _brand600 = Color(0xFFFF9933);
const _brand100 = Color(0xFFFFE8CC);
const _coral500 = Color(0xFFF2685E);
const _coral100 = Color(0xFFFFE3DF);
const _onSurface2 = Color(0xFF5A6B67);
const _onSurface3 = Color(0xFF93A29F);
const _border = Color(0xFFE5EBE9);
const _surface2 = Color(0xFFF4F7F6);

class _Office {
  _Office({required this.id, required this.name, required this.city, required this.members});
  final String id;
  String name, city;
  int members;
}

class OfficesScreen extends StatefulWidget {
  const OfficesScreen({super.key});
  @override
  State<OfficesScreen> createState() => _OfficesScreenState();
}

class _OfficesScreenState extends State<OfficesScreen> {
  final List<_Office> _offices = [];
  bool _loading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  // Load offices from the backend so add / edit / delete persist and stay in
  // sync across devices.
  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final res = await apiClient.get('/offices');
      final list = (res['data'] as List?) ?? const [];
      _offices
        ..clear()
        ..addAll(list.map((e) {
          final m = (e as Map).cast<String, dynamic>();
          final count = ((m['_count'] as Map?)?['users'] as int?) ?? 0;
          return _Office(
            id: m['id'] as String,
            name: (m['name'] ?? '') as String,
            city: (m['city'] ?? '') as String,
            members: count,
          );
        }));
    } catch (_) {
      // leave the list as-is; the empty state / a toast will inform the user
    }
    if (mounted) setState(() => _loading = false);
  }

  bool _isPending(Map<String, dynamic>? res) =>
      res != null && (res['meta'] as Map?)?['pendingApproval'] == true;

  void _showSheet({_Office? office}) {
    final nameCtrl = TextEditingController(text: office?.name ?? '');
    final cityCtrl = TextEditingController(text: office?.city ?? '');
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, ss) => Padding(
        padding: EdgeInsets.fromLTRB(20, 20, 20, MediaQuery.of(ctx).viewInsets.bottom + 24),
        child: Form(
          key: formKey,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            // handle
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(child: Text(office == null ? 'Add New Office' : 'Edit Office',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
              if (office != null)
                GestureDetector(
                  onTap: () => _confirmDelete(office, () => Navigator.pop(ctx)),
                  child: Container(width: 40, height: 40,
                    decoration: BoxDecoration(color: _coral100, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.delete_outline, color: _coral500, size: 20)),
                ),
            ]),
            const SizedBox(height: 6),
            const Text('Note: No. of members updates automatically as staff are assigned here.',
              style: TextStyle(fontSize: 12.5, color: _onSurface3, fontWeight: FontWeight.w500, height: 1.4)),
            const SizedBox(height: 18),
            _label('Office Name'),
            _field(nameCtrl, 'e.g. Chennai Regional Centre', validator: (v) => v!.trim().isEmpty ? 'Required' : null),
            const SizedBox(height: 14),
            _label('Location / City'),
            _field(cityCtrl, 'e.g. Chennai', validator: (v) => v!.trim().isEmpty ? 'Required' : null),
            const SizedBox(height: 22),
            Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: saving ? null : () => Navigator.pop(ctx),
                style: OutlinedButton.styleFrom(foregroundColor: _onSurface2, side: const BorderSide(color: _border, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), padding: const EdgeInsets.symmetric(vertical: 15)),
                child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700)),
              )),
              const SizedBox(width: 12),
              Expanded(flex: 2, child: ElevatedButton(
                onPressed: saving ? null : () async {
                  if (!formKey.currentState!.validate()) return;
                  final name = nameCtrl.text.trim();
                  final city = cityCtrl.text.trim();
                  ss(() => saving = true);
                  try {
                    if (office == null) {
                      final res = await apiClient.post('/offices', {'name': name, 'city': city});
                      if (_isPending(res)) {
                        if (ctx.mounted) Navigator.pop(ctx);
                        _showToast('Submitted for Super Admin approval');
                        return;
                      }
                      final m = (res['data'] as Map).cast<String, dynamic>();
                      setState(() => _offices.add(_Office(id: m['id'] as String, name: name, city: city, members: 0)));
                    } else {
                      final res = await apiClient.put('/offices/${office.id}', {'name': name, 'city': city});
                      if (_isPending(res)) {
                        if (ctx.mounted) Navigator.pop(ctx);
                        _showToast('Submitted for Super Admin approval');
                        return;
                      }
                      setState(() { office.name = name; office.city = city; });
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                    _showToast(office == null ? 'Office added!' : 'Office updated!');
                  } catch (_) {
                    ss(() => saving = false);
                    _showToast('Could not save office. Check your connection.');
                  }
                },
                style: ElevatedButton.styleFrom(backgroundColor: _brand600, foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), padding: const EdgeInsets.symmetric(vertical: 15), elevation: 0),
                child: saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : Text(office == null ? 'Add Office' : 'Save', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              )),
            ]),
          ]),
        ),
      )),
    );
  }

  void _confirmDelete(_Office office, VoidCallback onDone) {
    showDialog(
      context: context,
      builder: (dctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Office?', style: TextStyle(fontWeight: FontWeight.w800)),
        content: Text('Remove "${office.name}"? This cannot be undone.', style: const TextStyle(color: _onSurface2, fontSize: 14)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dctx), child: const Text('Cancel', style: TextStyle(color: _onSurface2))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dctx);
              try {
                final res = await apiClient.delete('/offices/${office.id}');
                if (_isPending(res)) { onDone(); _showToast('Submitted for Super Admin approval'); return; }
                setState(() => _offices.removeWhere((o) => o.id == office.id));
                onDone();
                _showToast('Office deleted');
              } catch (_) {
                _showToast('Could not delete office. Check your connection.');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: _coral500, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), elevation: 0),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  void _showToast(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w700)),
    backgroundColor: _brand600, behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    duration: const Duration(seconds: 2),
  ));

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final totalMembers = _offices.fold(0, (s, o) => s + o.members);
    final filtered = _offices.where((o) =>
      _searchQuery.isEmpty ||
      o.name.toLowerCase().contains(_searchQuery) ||
      o.city.toLowerCase().contains(_searchQuery)
    ).toList();

    return Scaffold(
      backgroundColor: _surface2,
      body: Column(children: [
        // ── Header ────────────────────────────────────────────────
        Container(
          color: context.headerBg,
          padding: EdgeInsets.fromLTRB(18, top + 14, 18, 16),
          child: Row(children: [
            IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20), onPressed: () => context.go('/more'), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Offices', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: context.textPrimary)),
              Text('${_offices.length} Locations  •  $totalMembers Members Total', style: TextStyle(fontSize: 13, color: context.textSub, fontWeight: FontWeight.w600)),
            ])),
            GestureDetector(
              onTap: () => _showSheet(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(color: _brand600, borderRadius: BorderRadius.circular(12)),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.add_rounded, color: Colors.white, size: 17),
                  SizedBox(width: 5),
                  Text('Add Office', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                ]),
              ),
            ),
          ]),
        ),
        // ── Search bar ────────────────────────────────────────────
        Container(
          color: context.headerBg,
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 14),
          child: TextField(
            onChanged: (v) => setState(() => _searchQuery = v.toLowerCase()),
            style: TextStyle(fontSize: 14, color: context.textPrimary),
            decoration: InputDecoration(
              hintText: 'Search offices by name or city...',
              hintStyle: TextStyle(fontSize: 13.5, color: context.textHint),
              prefixIcon: Icon(Icons.search_rounded, size: 20, color: context.textHint),
              filled: true,
              fillColor: context.scaffoldBg,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              isDense: true,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFFF9933), width: 1.5)),
            ),
          ),
        ),
        // ── Content ───────────────────────────────────────────────
        if (_loading)
          const Expanded(child: Center(child: CircularProgressIndicator(color: _brand600)))
        else if (filtered.isEmpty)
          Expanded(
            child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 80, height: 80, decoration: const BoxDecoration(color: _brand100, shape: BoxShape.circle),
                child: const Icon(Icons.business_outlined, size: 40, color: _brand600)),
              const SizedBox(height: 16),
              Text(_searchQuery.isEmpty ? 'No Offices Added Yet' : 'No results found',
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF15211E))),
              const SizedBox(height: 6),
              Text(_searchQuery.isEmpty ? 'Create your first office to start managing your team.' : 'Try a different search term.',
                style: const TextStyle(fontSize: 13.5, color: _onSurface2, fontWeight: FontWeight.w500)),
              if (_searchQuery.isEmpty) ...[
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => _showSheet(),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(color: _brand600, borderRadius: BorderRadius.circular(14)),
                    child: const Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.add_rounded, color: Colors.white, size: 18),
                      SizedBox(width: 6),
                      Text('Add Office', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)),
                    ]),
                  ),
                ),
              ],
            ])),
          )
        else
          Expanded(child: RefreshIndicator(
            onRefresh: _load,
            color: _brand600,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 100),
              child: Column(children: [
                ...filtered.map((o) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: _border),
                      boxShadow: const [BoxShadow(color: Color(0x0A0D2822), blurRadius: 6, offset: Offset(0, 2))]),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(width: 48, height: 48, decoration: BoxDecoration(color: _brand100, borderRadius: BorderRadius.circular(14)),
                        child: const Icon(Icons.business_outlined, color: _brand600, size: 24)),
                      const SizedBox(width: 13),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(o.name, style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, letterSpacing: -0.2)),
                        const SizedBox(height: 4),
                        Row(children: [
                          const Icon(Icons.location_on_outlined, size: 13, color: _onSurface3),
                          const SizedBox(width: 3),
                          Text(o.city, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _onSurface2)),
                        ]),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(color: _brand100, borderRadius: BorderRadius.circular(8)),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.people_outline, size: 13, color: _brand600),
                            const SizedBox(width: 5),
                            Text('${o.members} Members', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _brand600)),
                          ]),
                        ),
                      ])),
                      PopupMenuButton<String>(
                        onSelected: (v) {
                          if (v == 'edit') _showSheet(office: o);
                          if (v == 'delete') _confirmDelete(o, () {});
                        },
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 4,
                        itemBuilder: (_) => [
                          const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit_outlined, size: 17, color: Color(0xFFFF9933)), SizedBox(width: 10), Text('Edit', style: TextStyle(fontWeight: FontWeight.w700))])),
                          const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete_outline, size: 17, color: Color(0xFFF2685E)), SizedBox(width: 10), Text('Delete', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFF2685E)))])),
                        ],
                        child: Container(
                          width: 34, height: 34,
                          decoration: BoxDecoration(color: _surface2, borderRadius: BorderRadius.circular(10), border: Border.all(color: _border)),
                          child: const Icon(Icons.more_vert_rounded, size: 18, color: _onSurface2),
                        ),
                      ),
                    ]),
                  ),
                )),
              ]),
            ),
          )),
      ]),
    );
  }
}

Widget _label(String t) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(t, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)));
Widget _field(TextEditingController c, String hint, {String? Function(String?)? validator}) =>
  TextFormField(controller: c, validator: validator,
    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
    decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(color: _onSurface3, fontSize: 14, fontWeight: FontWeight.w500),
      filled: true, fillColor: _surface2, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13), isDense: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _brand600, width: 1.5))));
