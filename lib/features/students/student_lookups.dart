import 'package:flutter/material.dart';
import '../../core/network/api_client.dart';

// ══════════════════════════════════════════════════════════════════════
// Admin-managed student option lists (Settings → Student Status /
// Education Level / Support Categories). Students store the stable `key`
// (status, educationLevel) or the category id; labels are looked up here so a
// rename in Settings shows everywhere without touching student rows.
// ══════════════════════════════════════════════════════════════════════

class StudentOption {
  const StudentOption({required this.id, required this.key, required this.label, this.isActive = true});
  final String id;
  final String key;   // STATUS / EDUCATION_LEVEL: lookup key; categories: the id
  final String label;
  final bool isActive;
}

// Used until the server answers (or if it can't be reached) so screens never
// show raw keys like "DROPPED". Mirrors the backend's seeded defaults.
const _fallbackStatuses = [
  StudentOption(id: '', key: 'ACTIVE', label: 'Active'),
  StudentOption(id: '', key: 'DROPPED', label: 'Drop Out'),
  StudentOption(id: '', key: 'INACTIVE', label: 'Relieved'),
  StudentOption(id: '', key: 'GRADUATED', label: 'Graduated'),
  StudentOption(id: '', key: 'FORMER', label: 'Former Student'),
];

class StudentLookups {
  StudentLookups._();

  static List<StudentOption> statuses = List.of(_fallbackStatuses);
  static List<StudentOption> educationLevels = [];
  static List<StudentOption> categories = [];

  static Future<void>? _inflight;
  static DateTime? _loadedAt;

  // Loads all three lists once; later calls reuse the result for a minute
  // unless [force] is set (Settings screens force after an edit).
  static Future<void> load({bool force = false}) {
    final fresh = _loadedAt != null && DateTime.now().difference(_loadedAt!) < const Duration(minutes: 1);
    if (!force && fresh) return Future.value();
    return _inflight ??= _load().whenComplete(() => _inflight = null);
  }

  static Future<void> _load() async {
    List<StudentOption> parse(dynamic raw, {bool byId = false}) {
      final list = raw is List ? raw : const [];
      return [
        for (final e in list)
          if (e is Map)
            StudentOption(
              id: (e['id'] ?? '').toString(),
              key: (byId ? e['id'] : e['key'] ?? '').toString(),
              label: (e['label'] ?? '').toString(),
              isActive: e['isActive'] != false,
            ),
      ].where((o) => o.key.isNotEmpty && o.label.isNotEmpty).toList();
    }

    final results = await Future.wait([
      apiClient.get('/students/lookups/STATUS').then((r) => r['data']).catchError((_) => null),
      apiClient.get('/students/lookups/EDUCATION_LEVEL').then((r) => r['data']).catchError((_) => null),
      apiClient.get('/students/categories').then((r) => r['data']).catchError((_) => null),
    ]);
    final st = parse(results[0]);
    if (st.isNotEmpty) statuses = st;
    if (results[1] != null) educationLevels = parse(results[1]);
    if (results[2] != null) categories = parse(results[2], byId: true);
    _loadedAt = DateTime.now();
  }

  static String statusLabel(String? key) {
    if (key == null || key.isEmpty) return '—';
    for (final o in statuses) { if (o.key == key) return o.label; }
    for (final o in _fallbackStatuses) { if (o.key == key) return o.label; }
    return _titleCase(key);
  }

  static String educationLabel(String? key) {
    if (key == null || key.isEmpty) return '—';
    for (final o in educationLevels) { if (o.key == key) return o.label; }
    return _titleCase(key);
  }

  static String categoryLabel(String? id) {
    if (id == null || id.isEmpty) return '—';
    for (final o in categories) { if (o.key == id) return o.label; }
    return '—';
  }

  // Stable colour per status. The long-standing keys keep their familiar
  // colours; admin-added ones get a colour derived from the key.
  static Color statusColor(String? key) {
    switch (key) {
      case 'ACTIVE':    return const Color(0xFF1FA67A);
      case 'GRADUATED': return const Color(0xFF7C6CF0);
      case 'INACTIVE':  return const Color(0xFFE0921A);
      case 'DROPPED':   return const Color(0xFFF2685E);
      case 'FORMER':    return const Color(0xFF2D9CDB);
    }
    const palette = [Color(0xFF2D9CDB), Color(0xFF8E6CD8), Color(0xFF0F9D8A), Color(0xFFD36B9A), Color(0xFF6B7F2A)];
    return palette[(key ?? '').hashCode.abs() % palette.length];
  }

  static String _titleCase(String key) => key
      .split(RegExp(r'[_\s]+'))
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
      .join(' ');
}
