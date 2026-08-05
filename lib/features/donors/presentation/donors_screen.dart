import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'donor_categories_screen.dart' show donorCategoriesProvider;
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';

// ── colours ───────────────────────────────────────────────────────────
const _brand700 = Color(0xFFE07C1F);
const _brand600 = Color(0xFFFF9933);
const _brand100 = Color(0xFFFFE8CC);
const _coral500 = Color(0xFFF2685E);
const _coral100 = Color(0xFFFFE3DF);
const _amber600 = Color(0xFFE0921A);
const _amber100 = Color(0xFFFFF1D6);
const _violet500 = Color(0xFF7C6CF0);
const _violet100 = Color(0xFFE7E3FD);
const _sky500 = Color(0xFF2D9CDB);
const _sky100 = Color(0xFFDCEFFB);
const _green600 = Color(0xFF1FA971);
const _green100 = Color(0xFFD4F3E7);
const _onSurface3 = Color(0xFF93A29F);

// ── API donor model ───────────────────────────────────────────────────
class _Donor {
  _Donor.fromJson(Map<String, dynamic> j)
      : id = j['id'] as String,
        name = j['name'] as String,
        mobile = (j['mobile'] ?? '') as String,
        city = (j['city'] ?? '') as String,
        tier = (j['tier'] ?? 'SILVER') as String,
        gender = (j['gender'] ?? 'MALE') as String,
        donationCount = (j['_count'] as Map<String, dynamic>?)?['donations'] as int? ?? 0,
        categories = (j['categories'] as List<dynamic>? ?? [])
            .map((c) => (c['category']?['name'] ?? '') as String)
            .where((s) => s.isNotEmpty)
            .toList(),
        categoryColor = (j['categories'] as List<dynamic>? ?? []).isNotEmpty
            ? (j['categories'][0]['category']?['color'] as String?)
            : null,
        avatar = j['avatar'] as String?,
        isPending = (j['_pendingApproval'] as bool?) ?? false;

  final String id, name, mobile, city, tier, gender;
  final int donationCount;
  final List<String> categories;
  final String? categoryColor;
  final String? avatar;
  // True for a non-Super-Admin's own just-submitted donor, awaiting approval —
  // synthesized from GET /approvals/mine, not a real backend donor yet.
  final bool isPending;

  // Profile photo bytes: locally-cached image (instant) or the DB avatar.
  Uint8List? get photoBytes {
    final local = localDonorPhotos[id];
    if (local != null) return local;
    final a = avatar;
    if (a != null && a.isNotEmpty) {
      try { return base64Decode(a); } catch (_) {}
    }
    return null;
  }

  String get displayCategory =>
      categories.isNotEmpty ? categories.first : _tierLabel(tier);

  Color get badgeBg {
    if (categories.isEmpty) return _tierBg(tier);
    try {
      final hex = (categoryColor ?? '').replaceAll('#', '');
      if (hex.length == 6) {
        final c = Color(int.parse('FF$hex', radix: 16));
        return c.withValues(alpha: 0.15);
      }
    } catch (_) {}
    return _tierBg(tier);
  }

  Color get badgeFg {
    if (categories.isEmpty) return _tierFg(tier);
    try {
      final hex = (categoryColor ?? '').replaceAll('#', '');
      if (hex.length == 6) return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {}
    return _tierFg(tier);
  }
}

String _tierLabel(String tier) => switch (tier) {
  'PLATINUM' => 'Platinum',
  'GOLD'     => 'Gold Donor',
  'SILVER'   => 'Silver',
  'BRONZE'   => 'Bronze',
  _          => tier,
};

Color _tierBg(String tier) => switch (tier) {
  'PLATINUM' => _violet100,
  'GOLD'     => _amber100,
  'SILVER'   => _sky100,
  'BRONZE'   => _green100,
  _          => _brand100,
};

Color _tierFg(String tier) => switch (tier) {
  'PLATINUM' => _violet500,
  'GOLD'     => _amber600,
  'SILVER'   => _sky500,
  'BRONZE'   => _green600,
  _          => _brand600,
};

// ── In-memory store: survives navigation, cleared on hot-restart ──────
final demoLocalDonors = <Map<String, dynamic>>[];
final localDonorPhotos = <String, Uint8List>{};

// ── Refresh counter: increment to force list rebuild ─────────────────
final donorRefreshProvider = StateProvider<int>((ref) => 0);

// ── Mock data (used when API is unreachable) ──────────────────────────
// No demo donors — the list reflects only real backend data.
final mockDonorData = <Map<String, dynamic>>[];

// The logged-in (non-Super-Admin) user's own donor submissions still awaiting
// approval — otherwise a staff member's just-created donor simply disappears
// until a Super Admin approves it. Backend-driven (GET /approvals/mine) so it
// survives reloads and vanishes once approved/rejected.
Future<List<_Donor>> _loadMyPendingDonors() async {
  try {
    final r = await apiClient.get('/approvals/mine');
    final inner = r['data'];
    final reqs = inner is List
        ? inner
        : (inner is Map ? (inner['data'] as List<dynamic>? ?? const []) : const []);
    final donorReqs = reqs.whereType<Map<String, dynamic>>().where((q) =>
        (q['module'] as String?)?.toLowerCase() == 'donors' &&
        (q['action'] as String?)?.toUpperCase() == 'CREATE' &&
        (q['status'] as String?)?.toUpperCase() == 'PENDING').toList();
    return donorReqs.map((q) {
      final payload = (q['payload'] as Map?)?.cast<String, dynamic>() ?? const {};
      return _Donor.fromJson({
        ...payload,
        'id': 'pending-${q['id']}',
        'name': payload['name'] ?? 'Unknown',
        '_pendingApproval': true,
      });
    }).toList();
  } catch (_) {
    return const [];
  }
}

// ── Provider ──────────────────────────────────────────────────────────
final donorsProvider = FutureProvider<List<_Donor>>((ref) async {
  ref.watch(donorRefreshProvider); // re-run whenever refresh counter changes
  final pending = await _loadMyPendingDonors();
  try {
    // Page through EVERYTHING — the backend caps limit at 100, and a single
    // page made donor #101+ vanish from the app (they looked "deleted" even
    // though the database still had them).
    final list = <dynamic>[];
    for (int page = 1; page <= 50; page++) {
      final res = await apiClient.get('/donors', params: {'limit': '100', 'page': '$page'});
      final data = (res['data'] as List<dynamic>? ?? []);
      list.addAll(data);
      final meta = res['meta'] as Map<String, dynamic>?;
      if (meta?['hasNext'] != true || data.isEmpty) break;
    }
    // Backend is the source of truth even when empty (clean DB = empty list).
    return [
      ...pending,
      ...demoLocalDonors.map(_Donor.fromJson),
      ...list.map((e) => _Donor.fromJson(e as Map<String, dynamic>)),
    ];
  } catch (_) {}
  // Backend unreachable → demo/mock so the app still works offline.
  return [
    ...pending,
    ...demoLocalDonors.map(_Donor.fromJson),
    ...mockDonorData.map(_Donor.fromJson),
  ];
});

// ── avatar helpers ────────────────────────────────────────────────────
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
class DonorsScreen extends ConsumerStatefulWidget {
  const DonorsScreen({super.key});
  @override
  ConsumerState<DonorsScreen> createState() => _DonorsScreenState();
}

class _DonorsScreenState extends ConsumerState<DonorsScreen> {
  final _searchCtrl = TextEditingController();
  String _search = '';
  String _activeFilter = 'All';

  @override
  void initState() {
    super.initState();
    // Categories now load from the backend on demand rather than being
    // seeded — make sure the filter chips have real data even if the
    // Donor Categorization screen was never opened this session.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(donorCategoriesProvider).isEmpty) {
        ref.read(donorCategoriesProvider.notifier).loadFromBackend();
      }
    });
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  Future<void> _confirmDelete(_Donor d) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.delete_outline, color: _coral500, size: 40),
        title: const Text('Delete donor?', style: TextStyle(fontWeight: FontWeight.w800), textAlign: TextAlign.center),
        content: Text('Remove ${d.name}? This cannot be undone.', textAlign: TextAlign.center, style: const TextStyle(fontSize: 13.5)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: _coral500, fontWeight: FontWeight.w800))),
        ],
      ),
    );
    if (ok != true) return;

    // Soft-delete on the server for real (backend) donors first, so a
    // non-Super-Admin's delete goes to approval instead of vanishing locally.
    if (!d.id.startsWith('local_')) {
      try {
        final res = await apiClient.delete('/donors/${d.id}');
        if ((res?['meta'] as Map?)?['pendingApproval'] == true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: const Text('Submitted for Super Admin approval', style: TextStyle(fontWeight: FontWeight.w700)),
              backgroundColor: const Color(0xFFE0921A), behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ));
          }
          return; // don't remove locally — it's only pending
        }
      } catch (_) {}
    }

    // Remove from local stores so the UI updates instantly.
    demoLocalDonors.removeWhere((m) => m['id'] == d.id);
    mockDonorData.removeWhere((m) => m['id'] == d.id);
    localDonorPhotos.remove(d.id);
    ref.read(donorRefreshProvider.notifier).state++;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${d.name} deleted', style: const TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: _coral500, behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
    }
  }

  List<_Donor> _filtered(List<_Donor> all) {
    return all.where((d) {
      final matchSearch = _search.isEmpty ||
        d.name.toLowerCase().contains(_search.toLowerCase()) ||
        d.city.toLowerCase().contains(_search.toLowerCase()) ||
        d.mobile.contains(_search);
      final matchCat = _activeFilter == 'All' || d.displayCategory == _activeFilter;
      return matchSearch && matchCat;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final donorsAsync = ref.watch(donorsProvider);
    final categories = ref.watch(donorCategoriesProvider);

    return Scaffold(
      body: donorsAsync.when(
        loading: () => Column(children: [
          Container(color: context.headerBg, height: top + 70),
          Expanded(child: Center(child: ConstrainedBox(
            constraints: const BoxConstraints(),
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 40),
              itemCount: 6,
              itemBuilder: (_, __) => _skeletonCard(),
            ),
          ))),
        ]),
        error: (e, _) => Column(children: [
          Container(color: context.headerBg, height: top + 70),
          Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.wifi_off_rounded, size: 48, color: _onSurface3),
            const SizedBox(height: 12),
            Text('Could not load donors', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.textPrimary)),
            const SizedBox(height: 6),
            Text(e.toString(), style: TextStyle(fontSize: 12, color: context.textHint), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => ref.invalidate(donorsProvider),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(backgroundColor: _brand600, foregroundColor: Colors.white),
            ),
          ]))),
        ]),
        data: (allDonors) {
          final donors = _filtered(allDonors);
          // Pending (not-yet-approved) donors show up in the list so the staff
          // member who created them can track status, but aren't real donors
          // yet — excluded from every aggregate count below.
          final realDonors = allDonors.where((d) => !d.isPending).toList();
          final maleCount = realDonors.where((d) => d.gender == 'MALE').length;
          final femaleCount = realDonors.where((d) => d.gender != 'MALE').length;

          return RefreshIndicator(
            color: _brand600,
            onRefresh: () async => ref.invalidate(donorsProvider),
            child: Column(children: [
              // ── header ──────────────────────────────────────────────
              Container(
                color: context.headerBg,
                padding: EdgeInsets.fromLTRB(18, top + 14, 18, 16),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Donors', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5, height: 1, color: context.textPrimary)),
                    const SizedBox(height: 3),
                    Text('${realDonors.length} total · ${categories.length} categories',
                      style: TextStyle(fontSize: 13, color: context.textSub, fontWeight: FontWeight.w600)),
                  ])),
                  GestureDetector(
                    onTap: () => context.go('/donors/new'),
                    child: Container(
                      width: 40, height: 40,
                      decoration: const BoxDecoration(color: _brand600, shape: BoxShape.circle),
                      child: const Icon(Icons.add, color: Colors.white, size: 24),
                    ),
                  ),
                ]),
              ),

              // ── KPI bar ─────────────────────────────────────────────
              Container(
                color: context.headerBg,
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
                  decoration: BoxDecoration(
                    color: context.cardBg,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: context.border),
                    boxShadow: const [BoxShadow(color: Color(0x0D0D2822), blurRadius: 8, offset: Offset(0, 2))],
                  ),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Total Donors', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: context.textSub)),
                      const SizedBox(height: 3),
                      Text('${realDonors.length}', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: -1, height: 1, color: context.textPrimary)),
                    ])),
                    Row(children: [
                      _GenderPill(count: '$maleCount', label: 'Male', bg: _brand100, fg: _brand600),
                      const SizedBox(width: 8),
                      _GenderPill(count: '$femaleCount', label: 'Female', bg: _coral100, fg: _coral500),
                    ]),
                  ]),
                ),
              ),

              // ── search ──────────────────────────────────────────────
              Container(
                color: context.headerBg,
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 12),
                child: Row(children: [
                  Expanded(child: Container(
                    height: 44,
                    decoration: BoxDecoration(color: context.surface2, borderRadius: BorderRadius.circular(14), border: Border.all(color: context.border)),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (v) => setState(() => _search = v),
                      style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, color: context.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Search donors, city...',
                        hintStyle: TextStyle(color: context.textHint, fontSize: 14.5, fontWeight: FontWeight.w500),
                        prefixIcon: Icon(Icons.search, color: context.textHint, size: 20),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        isDense: true,
                      ),
                    ),
                  )),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => context.go('/donors/categories'),
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(color: context.surface2, borderRadius: BorderRadius.circular(14), border: Border.all(color: context.border)),
                      child: Icon(Icons.grid_view_rounded, color: context.textSub, size: 21),
                    ),
                  ),
                ]),
              ),

              // ── filter chips ──────────────────────────────────────────
              Container(
                color: context.headerBg,
                child: Column(children: [
                  SizedBox(
                    height: 44,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 0),
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setState(() => _activeFilter = 'All'),
                            child: _buildChip(context, 'All', realDonors.length, _activeFilter == 'All'),
                          ),
                        ),
                        ...categories.map((cat) {
                          final realCount = realDonors.where((d) => d.displayCategory == cat.name).length;
                          return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: GestureDetector(
                            onTap: () => setState(() => _activeFilter = cat.name),
                            child: _buildChip(context, cat.name, realCount, _activeFilter == cat.name,
                              activeColor: cat.color, activeBg: cat.bgColor),
                          ),
                        );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                ]),
              ),
              const SizedBox(height: 10),

              // ── list ─────────────────────────────────────────────────
              Expanded(
                child: donors.isEmpty
                  ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.people_outline, size: 48, color: _onSurface3.withValues(alpha: 0.5)),
                      const SizedBox(height: 12),
                      Text('No donors found', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: context.textHint)),
                    ]))
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(18, 0, 18, 100),
                      itemCount: donors.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (ctx, i) => _DonorCard(
                        donor: donors[i],
                        // A pending donor has no real backend record yet — no
                        // detail page to open, no delete action to send.
                        onTap: donors[i].isPending ? () {} : () => ctx.go('/donors/${donors[i].id}'),
                        onDelete: donors[i].isPending ? null : () => _confirmDelete(donors[i]),
                      ),
                    ),
              ),
            ]),
          );
        },
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/donors/new'),
        backgroundColor: _brand600,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.add, size: 22),
        label: const Text('Add Donor', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
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

// ── Filter chip builder ───────────────────────────────────────────────
Widget _buildChip(BuildContext ctx, String label, int count, bool active, {Color? activeColor, Color? activeBg}) {
  final fg = active ? (activeColor ?? _brand600) : ctx.textSub;
  final bg = active ? (activeBg ?? _brand100) : ctx.cardBg;
  final border = active ? (activeColor ?? _brand600) : ctx.border;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20), border: Border.all(color: border, width: 1.5)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fg)),
      const SizedBox(width: 5),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: active ? (activeColor ?? _brand600).withValues(alpha: 0.15) : ctx.surface2, borderRadius: BorderRadius.circular(8)),
        child: Text('$count', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: fg)),
      ),
    ]),
  );
}

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

// ── Donor card ────────────────────────────────────────────────────────
class _DonorCard extends StatelessWidget {
  const _DonorCard({required this.donor, required this.onTap, this.onDelete});
  final _Donor donor;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final color = _avColor(donor.name);
    final photo = donor.photoBytes;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: BoxDecoration(
          color: context.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.border),
          boxShadow: const [BoxShadow(color: Color(0x0A0D2822), blurRadius: 6, offset: Offset(0, 2))],
        ),
        child: Row(children: [
          Container(
            width: 52, height: 52,
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [color, Color.lerp(color, Colors.black, 0.2)!], begin: Alignment.topLeft, end: Alignment.bottomRight),
              shape: BoxShape.circle,
            ),
            child: photo != null
              ? Image.memory(photo, fit: BoxFit.cover, width: 52, height: 52)
              : Center(child: Text(_initials(donor.name), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18))),
          ),
          const SizedBox(width: 13),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              // Name gets layout priority — the chip keeps its natural size
              // and the name ellipsizes only when genuinely out of room.
              Flexible(child: Text(donor.name, maxLines: 1, style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, letterSpacing: -0.2, height: 1, color: context.textPrimary), overflow: TextOverflow.ellipsis)),
              if (donor.isPending) ...[
                const SizedBox(width: 7),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: _amber100, borderRadius: BorderRadius.circular(8)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.schedule_outlined, size: 11, color: _amber600),
                    SizedBox(width: 4),
                    Text('Pending Approval', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: _amber600)),
                  ]),
                ),
              ] else if (donor.categories.isNotEmpty) ...[
                const SizedBox(width: 7),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: donor.badgeBg, borderRadius: BorderRadius.circular(8)),
                  child: Text(donor.displayCategory, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: donor.badgeFg)),
                ),
              ],
            ]),
            const SizedBox(height: 5),
            Row(children: [
              if (donor.city.isNotEmpty) ...[
                Icon(Icons.location_on_outlined, size: 13, color: context.textHint),
                const SizedBox(width: 3),
                Flexible(child: Text('${donor.city} · ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.textSub), overflow: TextOverflow.ellipsis)),
              ],
              Text('${donor.donationCount} donations', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.textSub)),
            ]),
            // Phones: number moves under the name — beside it there isn't
            // room for name + chip + number, and the name loses.
            if (MediaQuery.sizeOf(context).width < 520) ...[
              const SizedBox(height: 3),
              Text(donor.mobile, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _brand700)),
            ],
          ])),
          const SizedBox(width: 8),
          if (MediaQuery.sizeOf(context).width >= 520)
            Text(donor.mobile, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _brand700)),
          if (onDelete != null)
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, size: 20, color: context.textHint),
              padding: EdgeInsets.zero,
              splashRadius: 18,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              onSelected: (v) { if (v == 'delete') onDelete!.call(); },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'delete', child: Row(children: [
                  Icon(Icons.delete_outline, size: 18, color: _coral500),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(fontWeight: FontWeight.w700)),
                ])),
              ],
            ),
        ]),
      ),
    );
  }
}
