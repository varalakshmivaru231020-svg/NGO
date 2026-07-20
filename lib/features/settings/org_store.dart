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
    this.city = '',
    this.state = '',
    this.country = '',
    this.pincode = '',
    this.email = '',
    this.reg12A = '',
    this.cert80G = '',
    this.updatedAt = '',
    this.logoBase64,
  });

  final String name, website, address, phone, regNo, pan, fcra;
  // Extra fields supported by the backend GET/PATCH /settings/organization
  // shape that the original local-only store didn't have.
  final String city, state, country, pincode, email, reg12A, cert80G, updatedAt;
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
    String? city,
    String? state,
    String? country,
    String? pincode,
    String? email,
    String? reg12A,
    String? cert80G,
    String? updatedAt,
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
        city: city ?? this.city,
        state: state ?? this.state,
        country: country ?? this.country,
        pincode: pincode ?? this.pincode,
        email: email ?? this.email,
        reg12A: reg12A ?? this.reg12A,
        cert80G: cert80G ?? this.cert80G,
        updatedAt: updatedAt ?? this.updatedAt,
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
        'city': city,
        'state': state,
        'country': country,
        'pincode': pincode,
        'email': email,
        'reg12A': reg12A,
        'cert80G': cert80G,
        'updatedAt': updatedAt,
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
        city: (j['city'] as String?) ?? '',
        state: (j['state'] as String?) ?? '',
        country: (j['country'] as String?) ?? '',
        pincode: (j['pincode'] as String?) ?? '',
        email: (j['email'] as String?) ?? '',
        reg12A: (j['reg12A'] as String?) ?? '',
        cert80G: (j['cert80G'] as String?) ?? '',
        updatedAt: (j['updatedAt'] as String?) ?? '',
        logoBase64: j['logo'] as String?,
      );

  // Maps the REAL backend shape (GET/PATCH /settings/organization) onto the
  // local cache. Falls back to whatever is already cached for any field the
  // backend didn't return, so a partial response never blanks the UI.
  factory OrgData.fromBackend(Map<String, dynamic> j, {OrgData? fallback}) {
    final f = fallback ?? _defaultOrg;
    String s(String key, String fallbackVal) => (j[key] as String?)?.isNotEmpty == true ? j[key] as String : fallbackVal;
    return OrgData(
      name: s('name', f.name),
      website: s('website', f.website),
      address: s('address', f.address),
      phone: s('phone', f.phone),
      regNo: s('registrationNumber', f.regNo),
      pan: s('pan', f.pan),
      fcra: s('fcra', f.fcra),
      city: s('city', f.city),
      state: s('state', f.state),
      country: s('country', f.country),
      pincode: s('pincode', f.pincode),
      email: s('email', f.email),
      reg12A: s('reg12A', f.reg12A),
      cert80G: s('cert80G', f.cert80G),
      updatedAt: (j['updatedAt'] as String?) ?? f.updatedAt,
      logoBase64: (j['logoBase64'] as String?)?.isNotEmpty == true ? j['logoBase64'] as String : f.logoBase64,
    );
  }

  // Maps this local cache onto the backend PATCH shape.
  Map<String, dynamic> toBackendJson() => {
        'name': name,
        'address': address,
        'city': city,
        'state': state,
        'country': country,
        'pincode': pincode,
        'phone': phone,
        'email': email,
        'website': website,
        'registrationNumber': regNo,
        'pan': pan,
        'reg12A': reg12A,
        'cert80G': cert80G,
        'fcra': fcra,
        if (logoBase64 != null) 'logoBase64': logoBase64,
      };
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
