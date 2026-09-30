import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/api_client.dart';
import 'package:saksham_app/core/ui/ui.dart';

const _brand600 = Color(0xFFFF9933);
const _brand100 = Color(0xFFFFE8CC);
const _coral500 = Color(0xFFF2685E);
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
  String? _error;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  // Load offices from the backend so add / edit / delete persist and stay in
  // sync across devices.
  // [quiet] refreshes in place (pull-to-refresh) without the skeleton flash.
  Future<void> _load({bool quiet = false}) async {
    if (mounted && !quiet) setState(() { _loading = true; _error = null; });
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
      _error = null;
    } catch (e) {
      // Leave the list as-is; tell the user instead of showing an empty list.
      if (mounted) {
        if (_offices.isNotEmpty) {
          AppToast.error(context, 'Couldn’t refresh offices', detail: ApiClient.errorMessage(e));
        } else {
          _error = ApiClient.errorMessage(e, fallback: 'Could not load offices.');
        }
      }
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

    showAppSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => StatefulBuilder(builder: (ctx, ss) {
        Future<void> submit() async {
          if (saving) return;
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
            _showToast(office == null ? 'Office added' : 'Office updated', detail: '“$name”');
          } catch (e) {
            if (ctx.mounted) ss(() => saving = false);
            _showToast('Could not save office', error: true,
                detail: ApiClient.errorMessage(e, fallback: 'Check your connection and try again.'));
          }
        }

        return Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(ctx).viewInsets.bottom + 16),
        child: Form(
          key: formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            // handle
            const SheetHandle(margin: EdgeInsets.only(bottom: 10)),
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(office == null ? 'Add office' : 'Edit office',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                const Text('Members update automatically as staff are assigned here.',
                  style: TextStyle(fontSize: 12.5, color: _onSurface3, fontWeight: FontWeight.w500, height: 1.4)),
              ])),
              if (office != null)
                IconButton(
                  tooltip: 'Delete office',
                  onPressed: saving ? null : () => _confirmDelete(office, () { if (ctx.mounted) Navigator.pop(ctx); }),
                  icon: const Icon(Icons.delete_outline, color: _coral500, size: 20),
                ),
              IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close_rounded, size: 20, color: _onSurface2),
                onPressed: saving ? null : () => Navigator.pop(ctx),
              ),
            ]),
            const SizedBox(height: 16),
            _label('Office Name', required: true),
            _field(nameCtrl, 'e.g. Chennai Regional Centre', enabled: !saving, autofocus: office == null,
                validator: (v) => v!.trim().isEmpty ? 'Please enter the office name.' : null),
            const SizedBox(height: 12),
            _label('Location / City', required: true),
            _field(cityCtrl, 'e.g. Chennai', enabled: !saving, onSubmitted: submit,
                validator: (v) => v!.trim().isEmpty ? 'Please enter the city.' : null),
            const SizedBox(height: 18),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              AppButton(label: 'Cancel', variant: AppButtonVariant.secondary,
                  onPressed: saving ? null : () => Navigator.pop(ctx)),
              const SizedBox(width: 8),
              AppButton(
                label: office == null ? 'Add Office' : 'Save Changes',
                busyLabel: office == null ? 'Adding…' : 'Saving…',
                loading: saving,
                onPressed: submit,
              ),
            ]),
          ]),
        ),
      );
      }),
    );
  }

  void _confirmDelete(_Office office, VoidCallback onDone) {
    var pending = false;
    AppConfirm.show(
      context,
      title: 'Delete office?',
      message: 'Remove “${office.name}”? This cannot be undone.',
      confirmLabel: 'Delete Office',
      onConfirm: () async {
        final res = await apiClient.delete('/offices/${office.id}');
        pending = _isPending(res);
      },
      errorText: (e) => 'Could not delete office. Check your connection.',
    ).then((ok) {
      if (!ok || !mounted) return;
      if (pending) { onDone(); _showToast('Submitted for Super Admin approval'); return; }
      setState(() => _offices.removeWhere((o) => o.id == office.id));
      onDone();
      _showToast('Office deleted');
    });
  }

  void _showToast(String msg, {bool error = false, String? detail}) {
    if (error) {
      AppToast.error(context, msg, detail: detail);
    } else {
      AppToast.success(context, msg, detail: detail);
    }
  }

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
          padding: EdgeInsets.fromLTRB(8, top + 10, 16, 10),
          child: Row(children: [
            IconButton(tooltip: 'Back', icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18), onPressed: () => context.go('/more')),
            const SizedBox(width: 2),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              Text('Offices', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.2, color: context.textPrimary)),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: Text(
                  _loading ? 'Loading…' : '${_offices.length} location${_offices.length == 1 ? '' : 's'}  •  $totalMembers member${totalMembers == 1 ? '' : 's'} total',
                  key: ValueKey(_loading ? -1 : _offices.length * 100000 + totalMembers),
                  style: TextStyle(fontSize: 12.5, color: context.textSub, fontWeight: FontWeight.w500)),
              ),
            ])),
            AppButton(label: 'Add Office', icon: Icons.add_rounded, onPressed: () => _showSheet()),
          ]),
        ),
        // ── Search bar ────────────────────────────────────────────
        Container(
          color: context.headerBg,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
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
          const Expanded(child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: SkeletonList(rows: 4, rowHeight: 72),
          ))
        else if (_error != null && _offices.isEmpty)
          Expanded(child: Center(child: ErrorState(message: _error!, onRetry: _load)))
        else if (filtered.isEmpty)
          Expanded(
            child: Center(child: _searchQuery.isEmpty
              ? EmptyState(
                  icon: Icons.business_outlined,
                  title: 'No offices added yet',
                  message: 'Create your first office to start managing your team.',
                  actionLabel: 'Add Office',
                  onAction: () => _showSheet(),
                )
              : const EmptyStateLike(
                  icon: Icons.search_off_rounded,
                  title: 'No results found',
                  message: 'Try a different search term.',
                )),
          )
        else
          Expanded(child: RefreshIndicator(
            onRefresh: () => _load(quiet: true),
            color: _brand600,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Column(children: [
                ...filtered.map((o) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: _border),
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
                        tooltip: 'Actions for ${o.name}',
                        position: PopupMenuPosition.under,
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

Widget _label(String t, {bool required = false}) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text.rich(TextSpan(children: [
  TextSpan(text: t),
  if (required) const TextSpan(text: ' *', style: TextStyle(color: _coral500)),
]), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _onSurface2)));
Widget _field(TextEditingController c, String hint, {String? Function(String?)? validator, bool enabled = true, bool autofocus = false, VoidCallback? onSubmitted}) =>
  TextFormField(controller: c, validator: validator, enabled: enabled, autofocus: autofocus,
    textInputAction: onSubmitted != null ? TextInputAction.done : TextInputAction.next,
    onFieldSubmitted: onSubmitted == null ? null : (_) => onSubmitted(),
    style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
    decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(color: _onSurface3, fontSize: 14, fontWeight: FontWeight.w500),
      filled: true, fillColor: _surface2, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13), isDense: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _brand600, width: 1.5))));
