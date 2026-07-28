import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/api_client.dart';
import '../../../core/auth/role_auth.dart';
import '../approval_store.dart';

const _brand600 = Color(0xFFFF9933);
const _brand100 = Color(0xFFFFE8CC);
const _amber600 = Color(0xFFE0921A);
const _amber100 = Color(0xFFFFF1D6);
const _coral500 = Color(0xFFF2685E);
const _coral100 = Color(0xFFFFE3DF);
const _violet500 = Color(0xFF7C6CF0);
const _sky500 = Color(0xFF2D9CDB);
const _onSurface2 = Color(0xFF5A6B67);
const _onSurface3 = Color(0xFF93A29F);
const _border = Color(0xFFE5EBE9);
const _surface2 = Color(0xFFF4F7F6);

// Fields we never want to render literally in the diff (base64 blobs, ids).
const _hiddenKeys = {'photo', 'avatar', 'password', 'passwordHash', 'tier'};

class ApprovalsScreen extends StatefulWidget {
  const ApprovalsScreen({super.key});
  @override
  State<ApprovalsScreen> createState() => _ApprovalsScreenState();
}

class _ApprovalsScreenState extends State<ApprovalsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tab;
  List<Map<String, dynamic>> _all = [];
  Map<String, int> _stats = {'pending': 0, 'approved': 0, 'rejected': 0};
  bool _loading = true;
  String _search = '';
  String _moduleFilter = 'All';
  final Set<String> _selected = {};
  // Ids currently mid-approve/reject — the buttons had no loading/disabled
  // state at all, so clicking again before the first request's round trip
  // (server + DB) resolved fired duplicate requests. Guards against that.
  final Set<String> _actioning = {};

  // Lookups so the ids stored in a request payload (donorId, typeId, centerId)
  // render as human-readable names in the diff view and the card subject.
  Map<String, String> _donorNames = {};
  Map<String, String> _typeLabels = {};
  Map<String, String> _centreNames = {};

  static const _statuses = ['PENDING', 'APPROVED', 'REJECTED'];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 3, vsync: this);
    _tab.addListener(() { if (!_tab.indexIsChanging) setState(() => _selected.clear()); else setState(() {}); });
    _load();
  }

  @override
  void dispose() { _tab.dispose(); super.dispose(); }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final res = await apiClient.get('/approvals');
      final list = (res['data'] as List?) ?? const [];
      _all = list.map((e) => (e as Map).cast<String, dynamic>()).toList();
      final s = await apiClient.get('/approvals/stats');
      final sd = (s['data'] as Map?)?.cast<String, dynamic>() ?? {};
      _stats = {
        'pending':  (sd['pending'] as int?) ?? 0,
        'approved': (sd['approved'] as int?) ?? 0,
        'rejected': (sd['rejected'] as int?) ?? 0,
      };
      // Keep the sidebar badge in sync with what this screen just fetched.
      pendingApprovalsCount.value = _stats['pending']!;
      await _loadLookups();
    } catch (_) {
      // leave existing data; a toast on actions will surface errors
    }
    if (mounted) setState(() => _loading = false);
  }

  // Best-effort id → name maps used to humanise donation/student payloads.
  Future<void> _loadLookups() async {
    Future<List<Map<String, dynamic>>> fetch(String path, [Map<String, String>? params]) async {
      try {
        final r = await apiClient.get(path, params: params);
        final inner = r['data'];
        final l = inner is Map
            ? (inner['data'] as List<dynamic>? ?? const [])
            : (inner is List ? inner : const []);
        return l.whereType<Map<String, dynamic>>().toList();
      } catch (_) { return const []; }
    }
    final donors  = await fetch('/donors', {'limit': '100', 'page': '1'});
    final types   = await fetch('/donations/types');
    final centres = await fetch('/students/centers');
    _donorNames  = {for (final d in donors)  (d['id'] as String? ?? ''): (d['name'] as String? ?? '')};
    _typeLabels  = {for (final t in types)   (t['id'] as String? ?? ''): (t['label'] as String? ?? '')};
    _centreNames = {for (final c in centres) (c['id'] as String? ?? ''): (c['name'] as String? ?? '')};
  }

  // Resolve an id-bearing field to its display name (falls back to the raw value).
  String _resolveField(String key, dynamic raw) {
    final v = _fmt(raw);
    if (v.isEmpty) return v;
    switch (key) {
      case 'donorId':  return _donorNames[v] ?? v;
      case 'typeId':   return _typeLabels[v] ?? v;
      case 'centerId':
      case 'centreId': return _centreNames[v] ?? v;
      default:         return v;
    }
  }

  List<Map<String, dynamic>> _forStatus(String status) {
    return _all.where((r) {
      if ((r['status'] as String?) != status) return false;
      if (_moduleFilter != 'All' && (r['module'] as String?) != _moduleFilter) return false;
      if (_search.isEmpty) return true;
      final hay = '${r['requesterName']} ${r['module']} ${r['action']} ${r['requesterRole']}'.toLowerCase();
      return hay.contains(_search);
    }).toList();
  }

  List<String> get _modules {
    final set = <String>{for (final r in _all) (r['module'] as String?) ?? ''}..remove('');
    return ['All', ...(set.toList()..sort())];
  }

  void _toast(String msg, {bool error = false}) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w700)),
    backgroundColor: error ? _coral500 : _brand600, behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    // Errors carry the backend's real reason — give people time to read it.
    duration: Duration(seconds: error ? 6 : 2),
  ));

  Future<void> _approve(String id) async {
    if (_actioning.contains(id)) return;
    setState(() => _actioning.add(id));
    try {
      await apiClient.post('/approvals/$id/approve', {});
      _toast('Approved & applied');
      await _load();
    } catch (e) {
      _toast(_errMsg(e), error: true);
      // A failed execution is saved onto the row (error column) — refresh so
      // the card's failure banner shows it.
      await _load();
    }
    if (mounted) setState(() => _actioning.remove(id));
  }

  Future<void> _reject(String id, String reason) async {
    if (_actioning.contains(id)) return;
    setState(() => _actioning.add(id));
    try {
      await apiClient.post('/approvals/$id/reject', {'reason': reason});
      _toast('Request rejected');
      await _load();
    } catch (e) {
      _toast(_errMsg(e), error: true);
    }
    if (mounted) setState(() => _actioning.remove(id));
  }

  // Bulk endpoints return 200 with per-item results — report the real counts,
  // not a blanket success.
  Future<void> _bulkApprove(List<String> ids) async {
    try {
      final res = await apiClient.post('/approvals/bulk-approve', {'ids': ids});
      final d = (res['data'] as Map?)?.cast<String, dynamic>() ?? {};
      final ok = (d['approved'] as int?) ?? ids.length;
      final failed = (d['failed'] as int?) ?? 0;
      _toast(failed == 0 ? '$ok approved' : '$ok approved · $failed failed — see the card for the reason', error: failed > 0);
      setState(() => _selected.clear());
      await _load();
    } catch (e) { _toast(_errMsg(e), error: true); }
  }

  Future<void> _bulkReject(List<String> ids, String reason) async {
    try {
      final res = await apiClient.post('/approvals/bulk-reject', {'ids': ids, 'reason': reason});
      final d = (res['data'] as Map?)?.cast<String, dynamic>() ?? {};
      final ok = (d['rejected'] as int?) ?? ids.length;
      final failed = (d['failed'] as int?) ?? 0;
      _toast(failed == 0 ? '$ok rejected' : '$ok rejected · $failed failed', error: failed > 0);
      setState(() => _selected.clear());
      await _load();
    } catch (e) { _toast(_errMsg(e), error: true); }
  }

  String _errMsg(Object e) => ApiClient.errorMessage(e, fallback: 'Action failed. Please try again.');

  void _confirmReject({String? id, List<String>? ids}) {
    final ctrl = TextEditingController();
    String? err;
    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, ss) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Reject request', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('A reason is required and is sent to the requester.', style: TextStyle(fontSize: 13, color: _onSurface2)),
        const SizedBox(height: 12),
        TextField(
          controller: ctrl, autofocus: true, maxLines: 3,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          decoration: InputDecoration(
            hintText: 'e.g. Duplicate entry / incorrect details',
            errorText: err,
            filled: true, fillColor: _surface2,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _brand600, width: 1.5)),
            contentPadding: const EdgeInsets.all(14)),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            final r = ctrl.text.trim();
            if (r.length < 3) { ss(() => err = 'Please enter a reason'); return; }
            Navigator.pop(ctx);
            if (ids != null) { _bulkReject(ids, r); } else if (id != null) { _reject(id, r); }
          },
          style: ElevatedButton.styleFrom(backgroundColor: _coral500, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          child: const Text('Reject', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
      ],
    )));
  }

  void _showDiff(Map<String, dynamic> req) {
    final action = (req['action'] as String?) ?? '';
    final payload = (req['payload'] as Map?)?.cast<String, dynamic>() ?? {};
    final prev = (req['previousData'] as Map?)?.cast<String, dynamic>() ?? {};
    final keys = <String>{...prev.keys, ...payload.keys}
      ..removeWhere((k) => _hiddenKeys.contains(k) || k.startsWith('_'));
    final rows = <Widget>[];
    for (final k in keys) {
      final oldV = _resolveField(k, prev[k]);
      final newV = _resolveField(k, payload[k]);
      if (action == 'DELETE') {
        if (oldV.isEmpty) continue;
        rows.add(_diffRow(k, oldV, '(removed)', _coral500));
      } else if (action == 'CREATE') {
        if (newV.isEmpty) continue;
        rows.add(_diffRow(k, '—', newV, _brand600));
      } else {
        if (oldV == newV) continue;
        rows.add(_diffRow(k, oldV.isEmpty ? '—' : oldV, newV.isEmpty ? '—' : newV, _amber600));
      }
    }
    showDialog(context: context, builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 560),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(padding: const EdgeInsets.fromLTRB(20, 18, 12, 8), child: Row(children: [
            Expanded(child: Text('$action  ·  ${req['module']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
            IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded)),
          ])),
          const Divider(height: 1, color: _border),
          Flexible(child: rows.isEmpty
            ? const Padding(padding: EdgeInsets.all(28), child: Text('No field-level changes to show.', style: TextStyle(color: _onSurface2)))
            : SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(children: rows))),
        ]),
      ),
    ));
  }

  Widget _diffRow(String key, String oldV, String newV, Color accent) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(_label(key), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _onSurface3, letterSpacing: 0.3)),
      const SizedBox(height: 4),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Text(oldV, style: const TextStyle(fontSize: 13, color: _onSurface2, decoration: TextDecoration.lineThrough))),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Icon(Icons.arrow_forward_rounded, size: 14, color: _onSurface3)),
        Expanded(child: Text(newV, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: accent))),
      ]),
    ]),
  );

  static const _labelOverrides = {
    'donorId': 'Donor', 'typeId': 'Donation Type', 'centerId': 'Centre',
    'centreId': 'Centre', 'paymentMode': 'Payment Mode', 'sponsorId': 'Sponsor',
  };
  String _label(String k) {
    if (_labelOverrides.containsKey(k)) return _labelOverrides[k]!;
    final s = k.replaceAllMapped(RegExp(r'([A-Z])'), (m) => ' ${m[1]}');
    return s.isEmpty ? k : '${s[0].toUpperCase()}${s.substring(1)}';
  }

  String _fmt(dynamic v) {
    if (v == null) return '';
    if (v is Map || v is List) return '…';
    final s = v.toString();
    if (s.length > 80) return '${s.substring(0, 77)}…';
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    if (!isAdmin) {
      return Scaffold(body: Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.lock_outline, size: 48, color: _onSurface3),
        const SizedBox(height: 12),
        const Text('Super Admin only', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        const Text('Only the Super Admin can review approval requests.', textAlign: TextAlign.center, style: TextStyle(color: _onSurface2)),
        const SizedBox(height: 18),
        TextButton(onPressed: () => context.go('/dashboard'), child: const Text('Back to dashboard')),
      ]))));
    }
    return Scaffold(
      backgroundColor: _surface2,
      body: Column(children: [
        // Header + stats
        Container(
          color: context.headerBg,
          padding: EdgeInsets.fromLTRB(18, top + 14, 18, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20), onPressed: () => context.go('/dashboard'), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
              const SizedBox(width: 10),
              Expanded(child: Text('Approvals', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: context.textPrimary))),
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded, size: 22)),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              _statChip('Pending', _stats['pending'] ?? 0, _amber600, _amber100, 0),
              const SizedBox(width: 8),
              _statChip('Approved', _stats['approved'] ?? 0, _brand600, _brand100, 1),
              const SizedBox(width: 8),
              _statChip('Rejected', _stats['rejected'] ?? 0, _coral500, _coral100, 2),
            ]),
          ]),
        ),
        // Search + module filter
        Container(
          color: context.headerBg,
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
          child: Row(children: [
            Expanded(child: TextField(
              onChanged: (v) => setState(() => _search = v.toLowerCase()),
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search by requester, module, action…',
                hintStyle: const TextStyle(fontSize: 13, color: _onSurface3),
                prefixIcon: const Icon(Icons.search_rounded, size: 20, color: _onSurface3),
                filled: true, fillColor: context.scaffoldBg, isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.border)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _brand600, width: 1.5)),
              ),
            )),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(color: context.scaffoldBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: context.border)),
              child: DropdownButtonHideUnderline(child: DropdownButton<String>(
                value: _moduleFilter,
                items: _modules.map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)))).toList(),
                onChanged: (v) => setState(() => _moduleFilter = v ?? 'All'),
              )),
            ),
          ]),
        ),
        // Tabs
        Container(
          color: context.headerBg,
          child: TabBar(
            controller: _tab,
            indicatorColor: _brand600, indicatorWeight: 2.5,
            labelColor: _brand600, unselectedLabelColor: _onSurface3,
            labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            tabs: const [Tab(text: 'Pending'), Tab(text: 'Approved'), Tab(text: 'Rejected')],
          ),
        ),
        Expanded(child: _loading
          ? const Center(child: CircularProgressIndicator(color: _brand600))
          : TabBarView(
              controller: _tab,
              children: _statuses.map((s) => _list(s)).toList(),
            )),
      ]),
      // Bulk action bar (pending tab, when items selected)
      bottomNavigationBar: (_tab.index == 0 && _selected.isNotEmpty)
        ? SafeArea(child: Container(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            decoration: BoxDecoration(color: context.cardBg, border: Border(top: BorderSide(color: context.border))),
            child: Row(children: [
              Text('${_selected.length} selected', style: const TextStyle(fontWeight: FontWeight.w800)),
              const Spacer(),
              OutlinedButton(
                onPressed: () => _confirmReject(ids: _selected.toList()),
                style: OutlinedButton.styleFrom(foregroundColor: _coral500, side: const BorderSide(color: _coral500)),
                child: const Text('Reject', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: () => _bulkApprove(_selected.toList()),
                style: ElevatedButton.styleFrom(backgroundColor: _brand600, foregroundColor: Colors.white),
                child: const Text('Approve', style: TextStyle(fontWeight: FontWeight.w800)),
              ),
            ]),
          ))
        : null,
    );
  }

  Widget _statChip(String label, int n, Color fg, Color bg, int index) {
    final active = _tab.index == index;
    return GestureDetector(
      onTap: () { _tab.animateTo(index); setState(() {}); },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? fg : Colors.transparent, width: 1.5),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('$n', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: fg)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg)),
        ]),
      ),
    );
  }

  Widget _list(String status) {
    final items = _forStatus(status);
    if (items.isEmpty) {
      return RefreshIndicator(onRefresh: _load, color: _brand600, child: ListView(children: [
        const SizedBox(height: 120),
        Icon(status == 'PENDING' ? Icons.inbox_outlined : Icons.check_circle_outline, size: 48, color: _onSurface3),
        const SizedBox(height: 12),
        Center(child: Text('No ${status.toLowerCase()} requests', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _onSurface2))),
      ]));
    }
    return RefreshIndicator(
      onRefresh: _load, color: _brand600,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 90),
        itemCount: items.length,
        itemBuilder: (_, i) => _card(items[i], status),
      ),
    );
  }

  Widget _card(Map<String, dynamic> r, String status) {
    final id = r['id'] as String;
    final action = (r['action'] as String?) ?? '';
    final module = (r['module'] as String?) ?? '';
    final (aFg, aBg) = _actionColor(action);
    final selected = _selected.contains(id);
    // The subject of the request (e.g. the child's / donor's real name) so the
    // Super Admin sees WHO/what they're approving, not just the module.
    final payload = (r['payload'] as Map?)?.cast<String, dynamic>() ?? {};
    final prev = (r['previousData'] as Map?)?.cast<String, dynamic>() ?? {};
    final donorId = (payload['donorId'] ?? prev['donorId'] ?? '').toString();
    final subject = (payload['name'] ?? prev['name'] ?? payload['donorName']
        ?? (donorId.isNotEmpty ? _donorNames[donorId] : null) ?? '').toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(18),
        border: Border.all(color: selected ? _brand600 : _border, width: selected ? 1.5 : 1),
        boxShadow: const [BoxShadow(color: Color(0x0A0D2822), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (status == 'PENDING')
            GestureDetector(
              onTap: () => setState(() => selected ? _selected.remove(id) : _selected.add(id)),
              child: Container(
                width: 22, height: 22, margin: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  color: selected ? _brand600 : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: selected ? _brand600 : _onSurface3, width: 1.5)),
                child: selected ? const Icon(Icons.check, size: 15, color: Colors.white) : null,
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(color: aBg, borderRadius: BorderRadius.circular(8)),
            child: Text(action, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: aFg)),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text.rich(
            TextSpan(children: [
              TextSpan(text: module, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
              if (subject.isNotEmpty)
                TextSpan(text: '  ·  $subject', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: _onSurface2)),
            ]),
            overflow: TextOverflow.ellipsis,
          )),
          const SizedBox(width: 8),
          Text(_relTime(r['createdAt'] as String?), style: const TextStyle(fontSize: 11.5, color: _onSurface3, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Container(width: 34, height: 34,
            decoration: const BoxDecoration(color: _brand100, shape: BoxShape.circle),
            child: Center(child: Text(_initials('${r['requesterName']}'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _brand600)))),
          const SizedBox(width: 10),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${r['requesterName']}', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
            Text('${r['requesterRole']}${(r['department'] != null) ? '  ·  ${r['department']}' : ''}', style: const TextStyle(fontSize: 11.5, color: _onSurface3, fontWeight: FontWeight.w500)),
          ])),
          TextButton.icon(
            onPressed: () => _showDiff(r),
            icon: const Icon(Icons.difference_outlined, size: 16),
            label: const Text('View changes', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
            style: TextButton.styleFrom(foregroundColor: _sky500, padding: const EdgeInsets.symmetric(horizontal: 6)),
          ),
        ]),
        if (status == 'REJECTED' && (r['reason'] != null && '${r['reason']}'.isNotEmpty)) ...[
          const SizedBox(height: 8),
          Container(width: double.infinity, padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: _coral100, borderRadius: BorderRadius.circular(10)),
            child: Text('Reason: ${r['reason']}', style: const TextStyle(fontSize: 12.5, color: Color(0xFFB23B32), fontWeight: FontWeight.w600))),
        ],
        if (status != 'PENDING' && r['reviewerName'] != null) ...[
          const SizedBox(height: 8),
          Text('${status == 'APPROVED' ? 'Approved' : 'Rejected'} by ${r['reviewerName']}', style: const TextStyle(fontSize: 11.5, color: _onSurface3, fontWeight: FontWeight.w500)),
        ],
        if (status == 'PENDING' && (r['error'] != null && '${r['error']}'.isNotEmpty)) ...[
          const SizedBox(height: 8),
          Container(width: double.infinity, padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: _coral100, borderRadius: BorderRadius.circular(10)),
            child: Text('Last approval attempt failed: ${r['error']}', style: const TextStyle(fontSize: 12.5, color: Color(0xFFB23B32), fontWeight: FontWeight.w600))),
        ],
        if (status == 'PENDING') ...[
          const SizedBox(height: 12),
          Builder(builder: (_) {
            final busy = _actioning.contains(id);
            return Row(children: [
            Expanded(child: OutlinedButton.icon(
              onPressed: busy ? null : () => _confirmReject(id: id),
              icon: const Icon(Icons.close_rounded, size: 17),
              label: const Text('Reject', style: TextStyle(fontWeight: FontWeight.w800)),
              style: OutlinedButton.styleFrom(foregroundColor: _coral500, side: const BorderSide(color: _coral500), padding: const EdgeInsets.symmetric(vertical: 11)),
            )),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton.icon(
              onPressed: busy ? null : () => _approve(id),
              icon: busy
                  ? const SizedBox(width: 15, height: 15, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.check_rounded, size: 17),
              label: Text(busy ? 'Approving…' : 'Approve', style: const TextStyle(fontWeight: FontWeight.w800)),
              style: ElevatedButton.styleFrom(backgroundColor: _brand600, foregroundColor: Colors.white, elevation: 0, padding: const EdgeInsets.symmetric(vertical: 11)),
            )),
          ]);
          }),
        ],
      ]),
    );
  }

  (Color, Color) _actionColor(String a) => switch (a) {
    'CREATE' => (_brand600, _brand100),
    'EDIT'   => (_amber600, _amber100),
    'DELETE' => (_coral500, _coral100),
    _        => (_violet500, const Color(0xFFE7E3FD)),
  };

  String _initials(String name) {
    final p = name.trim().split(RegExp(r'\s+'));
    return ((p.isNotEmpty && p[0].isNotEmpty ? p[0][0] : '') + (p.length > 1 && p[1].isNotEmpty ? p[1][0] : '')).toUpperCase();
  }

  String _relTime(String? iso) {
    final d = DateTime.tryParse(iso ?? '');
    if (d == null) return '';
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
