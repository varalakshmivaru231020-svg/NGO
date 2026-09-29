import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../network/api_client.dart';

// ══════════════════════════════════════════════════════════════════════
// List endpoints no longer carry base64 photos (they made every page several
// MB and lists timed out to "0"). A card shows its photo through this widget,
// which fetches it once from [endpoint] — only for cards actually built on
// screen — and caches the bytes for the session.
// ══════════════════════════════════════════════════════════════════════

final Map<String, Uint8List?> _photoCache = {};
final Map<String, Future<Uint8List?>> _photoInflight = {};

Uint8List? decodePhoto(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    final comma = raw.indexOf(',');
    return base64Decode(raw.startsWith('data:') && comma >= 0 ? raw.substring(comma + 1) : raw);
  } catch (_) {
    return null;
  }
}

// Drop a cached photo after it was changed so the next build refetches it.
void evictLazyPhoto(String endpoint) => _photoCache.remove(endpoint);

Future<Uint8List?> _fetchPhoto(String endpoint, String field) {
  if (_photoCache.containsKey(endpoint)) return Future.value(_photoCache[endpoint]);
  return _photoInflight[endpoint] ??= () async {
    try {
      final r = await apiClient.get(endpoint);
      final data = r['data'];
      final bytes = data is Map ? decodePhoto(data[field] as String?) : null;
      _photoCache[endpoint] = bytes;
      return bytes;
    } catch (_) {
      return null; // not cached — a later build may retry
    } finally {
      _photoInflight.remove(endpoint);
    }
  }();
}

class LazyPhoto extends StatefulWidget {
  const LazyPhoto({
    super.key,
    required this.endpoint,
    required this.field,
    required this.placeholder,
    this.size = 52,
    this.enabled = true,
    this.initial,
  });

  final String endpoint;      // e.g. /students/<id>/photo
  final String field;         // 'photo' or 'avatar'
  final Widget placeholder;   // initials etc.
  final double size;
  final bool enabled;         // false when the row says it has no photo
  final Uint8List? initial;   // bytes already on hand (local cache, full record)

  @override
  State<LazyPhoto> createState() => _LazyPhotoState();
}

class _LazyPhotoState extends State<LazyPhoto> {
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(LazyPhoto old) {
    super.didUpdateWidget(old);
    if (old.endpoint != widget.endpoint || old.enabled != widget.enabled || old.initial != widget.initial) _resolve();
  }

  void _resolve() {
    _bytes = widget.initial ?? _photoCache[widget.endpoint];
    if (_bytes != null || !widget.enabled) return;
    final endpoint = widget.endpoint;
    _fetchPhoto(endpoint, widget.field).then((b) {
      if (mounted && b != null && widget.endpoint == endpoint) setState(() => _bytes = b);
    });
  }

  @override
  Widget build(BuildContext context) {
    final b = _bytes;
    if (b == null) return widget.placeholder;
    return Image.memory(b, fit: BoxFit.cover, width: widget.size, height: widget.size, gaplessPlayback: true,
        errorBuilder: (_, __, ___) => widget.placeholder);
  }
}
