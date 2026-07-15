import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';
import 'donor_categories_screen.dart' show DonorCategory;

const _brand600   = Color(0xFFFF9933);
const _onSurface1 = Color(0xFF15211E);
const _onSurface2 = Color(0xFF5A6B67);
const _onSurface3 = Color(0xFF93A29F);
const _border     = Color(0xFFE5EBE9);
const _surface2   = Color(0xFFF4F7F6);

class _CatDonor {
  _CatDonor({required this.id, required this.name, required this.tier, required this.mobile});
  final String id, name, tier, mobile;
  factory _CatDonor.fromJson(Map<String, dynamic> j) {
    final d = (j['donor'] as Map?)?.cast<String, dynamic>() ?? const {};
    return _CatDonor(
      id: d['id'] as String? ?? '',
      name: d['name'] as String? ?? 'Donor',
      tier: d['tier'] as String? ?? 'SILVER',
      mobile: d['mobile'] as String? ?? '',
    );
  }
}

String _initials(String name) {
  final p = name.trim().split(RegExp(r'\s+'));
  return ((p[0].isNotEmpty ? p[0][0] : '') + (p.length > 1 && p[1].isNotEmpty ? p[1][0] : '')).toUpperCase();
}

class CategoryDonorsScreen extends StatefulWidget {
  const CategoryDonorsScreen({super.key, required this.categoryId, this.category});
  final String categoryId;
  // Passed via GoRouter `extra` when navigating from the categories list, so
  // the header can render instantly without waiting on the fetch.
  final DonorCategory? category;
  @override
  State<CategoryDonorsScreen> createState() => _CategoryDonorsScreenState();
}

class _CategoryDonorsScreenState extends State<CategoryDonorsScreen> {
  List<_CatDonor> _donors = [];
  String? _name;
  String? _desc;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = widget.category?.name;
    _desc = widget.category?.desc;
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final r = await apiClient.get('/categories/${widget.categoryId}');
      final data = (r['data'] as Map).cast<String, dynamic>();
      final list = (data['donors'] as List<dynamic>? ?? const []);
      final donors = list.whereType<Map>().map((m) => _CatDonor.fromJson(m.cast<String, dynamic>())).toList();
      if (mounted) setState(() {
        _donors = donors;
        _name = data['name'] as String? ?? _name;
        _desc = data['description'] as String? ?? _desc;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() { _error = 'Could not load this category'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final color = widget.category?.color ?? _brand600;
    return Scaffold(
      backgroundColor: _surface2,
      body: Column(children: [
        Container(
          color: Colors.white,
          padding: EdgeInsets.fromLTRB(8, top + 10, 18, 14),
          child: Row(children: [
            IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20), onPressed: () => context.go('/donors/categories'), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
            const SizedBox(width: 6),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_name ?? 'Category', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
              Text(_loading ? 'Loading…' : '${_donors.length} donor${_donors.length == 1 ? '' : 's'}${(_desc ?? '').isNotEmpty ? ' · $_desc' : ''}',
                style: const TextStyle(fontSize: 12.5, color: _onSurface2, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
            ])),
          ]),
        ),
        Expanded(
          child: _loading
            ? const Center(child: CircularProgressIndicator(color: _brand600))
            : _error != null
              ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.wifi_off_rounded, size: 44, color: _onSurface3),
                  const SizedBox(height: 10),
                  Text(_error!, style: const TextStyle(fontWeight: FontWeight.w700, color: _onSurface1)),
                  const SizedBox(height: 10),
                  TextButton(onPressed: _load, child: const Text('Retry', style: TextStyle(color: _brand600, fontWeight: FontWeight.w700))),
                ]))
              : _donors.isEmpty
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.people_outline, size: 52, color: _onSurface3.withValues(alpha: 0.5)),
                    const SizedBox(height: 12),
                    const Text('No donors in this category yet', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _onSurface3)),
                  ]))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(18, 14, 18, 40),
                    itemCount: _donors.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (ctx, i) {
                      final d = _donors[i];
                      return GestureDetector(
                        onTap: () => context.go('/donors/${d.id}'),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: _border)),
                          child: Row(children: [
                            Container(width: 46, height: 46,
                              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
                              child: Center(child: Text(_initials(d.name), style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 15)))),
                            const SizedBox(width: 13),
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(d.name, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 3),
                              Text(d.mobile.isNotEmpty ? d.mobile : d.tier, style: const TextStyle(fontSize: 12.5, color: _onSurface3, fontWeight: FontWeight.w500)),
                            ])),
                            const Icon(Icons.chevron_right_rounded, color: _onSurface3, size: 20),
                          ]),
                        ),
                      );
                    },
                  ),
        ),
      ]),
    );
  }
}
