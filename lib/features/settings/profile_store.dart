import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../core/storage/kv_store.dart';

// ══════════════════════════════════════════════════════════════════════
// ADMIN PROFILE — shared, persisted account info for the logged-in admin.
// The Edit Profile screen (Settings), the More screen profile card and the
// sidebar avatar all read from [adminProfile] so a change in one place is
// reflected everywhere and survives a reload. Persisted via kv_store
// (localStorage on web, in-memory elsewhere) — same pattern as role_auth.
// ══════════════════════════════════════════════════════════════════════

const _profileKey = 'saksham_admin_profile';

// Foundation logo — used as the default profile image and in receipts.
const brandLogoAsset = 'assets/images/sket-logo.png';

class ProfileData {
  const ProfileData({
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.org,
    required this.bio,
    this.photoBase64,
  });

  final String name, email, phone, role, org, bio;
  final String? photoBase64; // raw image bytes, base64-encoded (null = initials)

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    final a = parts.isNotEmpty && parts[0].isNotEmpty ? parts[0][0] : '';
    final b = parts.length > 1 && parts[1].isNotEmpty ? parts[1][0] : '';
    final s = (a + b).toUpperCase();
    return s.isEmpty ? 'U' : s;
  }

  Uint8List? get photoBytes {
    final raw = photoBase64;
    if (raw == null || raw.isEmpty) return null;
    try {
      return base64Decode(raw);
    } catch (_) {
      return null;
    }
  }

  ProfileData copyWith({
    String? name,
    String? email,
    String? phone,
    String? role,
    String? org,
    String? bio,
    Object? photoBase64 = _unset, // pass null explicitly to clear the photo
  }) =>
      ProfileData(
        name: name ?? this.name,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        role: role ?? this.role,
        org: org ?? this.org,
        bio: bio ?? this.bio,
        photoBase64: identical(photoBase64, _unset)
            ? this.photoBase64
            : photoBase64 as String?,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'email': email,
        'phone': phone,
        'role': role,
        'org': org,
        'bio': bio,
        'photo': photoBase64,
      };

  factory ProfileData.fromJson(Map<String, dynamic> j) => ProfileData(
        name: (j['name'] as String?) ?? _defaultProfile.name,
        email: (j['email'] as String?) ?? _defaultProfile.email,
        phone: (j['phone'] as String?) ?? _defaultProfile.phone,
        role: (j['role'] as String?) ?? _defaultProfile.role,
        org: (j['org'] as String?) ?? _defaultProfile.org,
        bio: (j['bio'] as String?) ?? _defaultProfile.bio,
        photoBase64: j['photo'] as String?,
      );
}

const _unset = Object();

const _defaultProfile = ProfileData(
  name: 'Super Admin',
  email: 'admin@sket.org',
  phone: '',
  role: 'Super Admin',
  org: 'SKET',
  bio: '',
);

// Live, app-wide admin profile. Listen with ValueListenableBuilder to rebuild
// when it changes.
final adminProfile = ValueNotifier<ProfileData>(_load());

ProfileData _load() {
  try {
    final raw = readKv(_profileKey);
    if (raw != null && raw.isNotEmpty) {
      return ProfileData.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    }
  } catch (_) {}
  return _defaultProfile;
}

// Persist + broadcast a new profile. Call after any edit.
void updateProfile(ProfileData profile) {
  adminProfile.value = profile;
  try {
    writeKv(_profileKey, jsonEncode(profile.toJson()));
  } catch (_) {}
}

// Convenience: encode picked image bytes for storage (null clears the photo).
String? encodePhoto(Uint8List? bytes) =>
    (bytes == null || bytes.isEmpty) ? null : base64Encode(bytes);
