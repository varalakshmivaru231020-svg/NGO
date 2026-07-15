import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../core/storage/kv_store.dart';

// ══════════════════════════════════════════════════════════════════════
// ORGANISATION PROFILE — shared, persisted NGO details.
// The Settings → Organization tab edits these; the sidebar header, login
// screen and receipts read them so a change in one place shows up
// everywhere and survives a reload. Persisted via kv_store (localStorage on
// web, in-memory elsewhere) — same pattern as adminProfile.
// ══════════════════════════════════════════════════════════════════════

const _orgKey = 'saksham_org_profile';

class OrgData {
  const OrgData({
    required this.name,
    required this.website,
    required this.address,
    required this.phone,
    required this.regNo,
    required this.pan,
    required this.fcra,
    this.logoBase64,
  });

  final String name, website, address, phone, regNo, pan, fcra;
  final String? logoBase64; // org logo image bytes, base64-encoded (null = default)

  Uint8List? get logoBytes {
    final raw = logoBase64;
    if (raw == null || raw.isEmpty) return null;
    try {
      return base64Decode(raw);
    } catch (_) {
      return null;
    }
  }

  // First word of the org name — used as the bold title line in the sidebar.
  // For longer (3+ word) names, use an acronym instead so it fits.
  String get shortName {
    final t = name.trim();
    if (t.isEmpty) return 'SKET';
    final words = t.split(RegExp(r'\s+'));
    if (words.length >= 3) {
      return words.map((w) => w[0]).join().toUpperCase();
    }
    final sp = t.indexOf(' ');
    return sp == -1 ? t : t.substring(0, sp);
  }

  // Everything after the first word — the smaller second line (may be empty).
  // For longer (3+ word) names, show the full name instead.
  String get tagline {
    final t = name.trim();
    final words = t.split(RegExp(r'\s+'));
    if (words.length >= 3) return t;
    final sp = t.indexOf(' ');
    return sp == -1 ? '' : t.substring(sp + 1).trim();
  }

  OrgData copyWith({
    String? name,
    String? website,
    String? address,
    String? phone,
    String? regNo,
    String? pan,
    String? fcra,
    Object? logoBase64 = _unset, // pass null explicitly to clear the logo
  }) =>
      OrgData(
        name: name ?? this.name,
        website: website ?? this.website,
        address: address ?? this.address,
        phone: phone ?? this.phone,
        regNo: regNo ?? this.regNo,
        pan: pan ?? this.pan,
        fcra: fcra ?? this.fcra,
        logoBase64: identical(logoBase64, _unset)
            ? this.logoBase64
            : logoBase64 as String?,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'website': website,
        'address': address,
        'phone': phone,
        'regNo': regNo,
        'pan': pan,
        'fcra': fcra,
        'logo': logoBase64,
      };

  factory OrgData.fromJson(Map<String, dynamic> j) => OrgData(
        name: (j['name'] as String?) ?? _defaultOrg.name,
        website: (j['website'] as String?) ?? _defaultOrg.website,
        address: (j['address'] as String?) ?? _defaultOrg.address,
        phone: (j['phone'] as String?) ?? _defaultOrg.phone,
        regNo: (j['regNo'] as String?) ?? _defaultOrg.regNo,
        pan: (j['pan'] as String?) ?? _defaultOrg.pan,
        fcra: (j['fcra'] as String?) ?? _defaultOrg.fcra,
        logoBase64: j['logo'] as String?,
      );
}

const _unset = Object();

const _defaultOrg = OrgData(
  name: 'Sri Krishnashraya Educational Trust',
  website: 'www.saksham.org',
  address: 'Mumbai, Maharashtra',
  phone: '+91 98765 43210',
  regNo: 'NGO-2019-MH-00123',
  pan: 'AABCS1234D',
  fcra: 'Active',
);

// Live, app-wide org profile. Listen with ValueListenableBuilder to rebuild
// when it changes.
final orgProfile = ValueNotifier<OrgData>(_load());

OrgData _load() {
  try {
    final raw = readKv(_orgKey);
    if (raw != null && raw.isNotEmpty) {
      return OrgData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    }
  } catch (_) {}
  return _defaultOrg;
}

// Persist + broadcast a new org profile. Call after any edit.
void updateOrg(OrgData org) {
  orgProfile.value = org;
  try {
    writeKv(_orgKey, jsonEncode(org.toJson()));
  } catch (_) {}
}

// Convenience: encode picked logo bytes for storage (null clears the logo).
String? encodeLogo(Uint8List? bytes) =>
    (bytes == null || bytes.isEmpty) ? null : base64Encode(bytes);
