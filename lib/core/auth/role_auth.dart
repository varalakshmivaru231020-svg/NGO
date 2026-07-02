// Shared role store + session state — used by login, sidebar, roles screen,
// the Manage Roles screen and the Team Members screen.
import 'dart:convert';
import 'role_storage.dart';
import '../storage/kv_store.dart';

// ══════════════════════════════════════════════════════════════════════
// TEAM MEMBER / LOGIN ACCOUNT
// Each AppRole is one staff login. `roleName` links it to a RoleTemplate
// (see below); `modules` is the effective set of modules it can access and
// is derived from that template.
// ══════════════════════════════════════════════════════════════════════
class AppRole {
  AppRole({
    required this.name,
    required this.email,
    required this.password,
    required this.modules,
    this.roleName = '',
    this.active = true,
    this.backendId,
  });
  String name;
  String email;
  String password;
  String roleName;
  Set<String> modules;
  bool active;
  String? backendId; // id of the matching backend user (for deactivate/delete)

  Map<String, dynamic> toJson() => {
    'name': name,
    'email': email,
    'password': password,
    'roleName': roleName,
    'modules': modules.toList(),
    'active': active,
    'backendId': backendId,
  };

  factory AppRole.fromJson(Map<String, dynamic> j) => AppRole(
    name:     j['name']     as String,
    email:    (j['email']   as String?) ?? '',
    password: j['password'] as String,
    roleName: (j['roleName'] as String?) ?? '',
    modules:  Set<String>.from(j['modules'] as List),
    active:   (j['active'] as bool?) ?? true,
    backendId: j['backendId'] as String?,
  );
}

// No built-in demo team members — the team starts empty (plus the seeded admin).
// Add real members via Settings → Team Members.
final _defaultRoles = <AppRole>[];

// Seeded team accounts — always available in every browser (including incognito),
// regardless of what's in local storage. Add built-in logins here.
const _allModules = {'donors', 'donations', 'students', 'offices', 'reports', 'reminders', 'tracker', 'payments', 'achievements'};
// The super admin logs in via the backend (and the offline fallback in the
// login screen), so it isn't listed here as a team member.
final _seededRoles = <AppRole>[];

// Global members list — loaded from storage, falls back to defaults, and always
// includes the seeded accounts.
final appRoles = _loadRoles();

// One-time cleanup: when the app's built-in defaults change, old locally-saved
// roles/team members from a previous version are cleared so the lists match the
// current build (org logo + admin profile are kept). Bump the version to force
// another reset.
const _dataVersionKey = 'saksham_data_version';
const _currentDataVersion = '2026-07-clean';
bool _migrated = false;
void _ensureMigrated() {
  if (_migrated) return;
  _migrated = true;
  try {
    if (readKv(_dataVersionKey) != _currentDataVersion) {
      writeRoleStorage('');          // clear saved team members
      writeKv(_templatesKey, '');    // clear saved role templates
      writeKv(_dataVersionKey, _currentDataVersion);
    }
  } catch (_) {}
}

List<AppRole> _loadRoles() {
  _ensureMigrated();
  List<AppRole> roles;
  try {
    final raw = readRoleStorage();
    if (raw != null && raw.isNotEmpty) {
      final list = jsonDecode(raw) as List;
      roles = list.map((e) => AppRole.fromJson(e as Map<String, dynamic>)).toList();
    } else {
      roles = [..._defaultRoles];
    }
  } catch (_) {
    roles = [..._defaultRoles];
  }
  // Guarantee seeded accounts exist even if storage was created before they were added.
  for (final s in _seededRoles) {
    if (!roles.any((r) => r.email.toLowerCase() == s.email.toLowerCase())) {
      roles.add(s);
    }
  }
  // Deduplicate by email (keep first occurrence), in case of any stored duplicates.
  final seen = <String>{};
  roles = roles.where((r) {
    final key = r.email.toLowerCase();
    if (seen.contains(key)) return false;
    seen.add(key);
    return true;
  }).toList();
  return roles;
}

// Call this whenever appRoles is mutated (add / edit / delete)
void saveRoles() {
  try {
    writeRoleStorage(jsonEncode(appRoles.map((r) => r.toJson()).toList()));
  } catch (_) {}
}

// ══════════════════════════════════════════════════════════════════════
// ROLE TEMPLATE — a permission definition managed on the "Manage Roles"
// screen. Stored as a plain map so the existing screen UI keeps working.
// Shape: { name, desc, isSystem, perms: { <module>: { view, add, edit, ... } } }
// ══════════════════════════════════════════════════════════════════════

// Maps the Manage-Roles permission keys to the module keys the sidebar /
// canAccess() understand. A module is "accessible" when its `view` is true.
const _templateKeyToModule = <String, String>{
  'donors':          'donors',
  'donations':       'donations',
  'students':        'students',
  'offices':         'offices',
  'reports':         'reports',
  'reminders':       'reminders',
  'donationTracker': 'tracker',
  'paymentLinks':    'payments',
  'achievements':    'achievements',
};

List<Map<String, dynamic>> _defaultTemplates() => [
  {
    'name': 'Admin', 'desc': 'Full access to all features and settings',
    'isSystem': true,
    'perms': <String, dynamic>{
      'donors':          {'view': true, 'add': true, 'edit': true, 'delete': true},
      'donations':       {'view': true, 'add': true, 'edit': true, 'delete': true},
      'students':        {'view': true, 'add': true, 'edit': true, 'delete': true},
      'offices':         {'view': true, 'add': true, 'edit': true, 'delete': true},
      'reports':         {'view': true, 'export': true},
      'reminders':       {'view': true, 'add': true, 'edit': true, 'delete': true},
      'donationTracker': {'view': true, 'add': true, 'edit': true, 'delete': true},
      'paymentLinks':    {'view': true, 'add': true, 'edit': true, 'delete': true},
      'achievements':    {'view': true, 'add': true, 'edit': true, 'delete': true},
      'settings':        {'access': true},
    },
  },
  // Only the system Admin role ships by default — create the rest in Manage Roles.
];

const _templatesKey = 'saksham_role_templates';

final roleTemplates = _loadTemplates();

List<Map<String, dynamic>> _loadTemplates() {
  _ensureMigrated();
  try {
    final raw = readKv(_templatesKey);
    if (raw != null && raw.isNotEmpty) {
      final list = jsonDecode(raw) as List;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
  } catch (_) {}
  return _defaultTemplates();
}

void saveRoleTemplates() {
  try {
    writeKv(_templatesKey, jsonEncode(roleTemplates));
  } catch (_) {}
}

// Derive the accessible module set for a role-template name.
Set<String> modulesForRoleName(String roleName) {
  Map<String, dynamic>? tmpl;
  for (final t in roleTemplates) {
    if ((t['name'] as String).toLowerCase() == roleName.toLowerCase()) { tmpl = t; break; }
  }
  if (tmpl == null) return <String>{};
  final perms = (tmpl['perms'] as Map?) ?? {};
  final out = <String>{};
  _templateKeyToModule.forEach((tKey, module) {
    final p = perms[tKey];
    if (p is Map && p['view'] == true) out.add(module);
  });
  return out;
}

// Re-apply a template's permissions to every member assigned that role, then
// persist. Keeps logged-in members' access in sync after editing a role.
void applyTemplateToMembers(String roleName) {
  final mods = modulesForRoleName(roleName);
  for (final m in appRoles) {
    if (m.roleName.toLowerCase() == roleName.toLowerCase()) {
      m.modules = {...mods};
    }
  }
  saveRoles();
}

// Current session — null means admin (sees everything)
AppRole? currentLoggedInRole;

// Which routes each module unlocks
const moduleToRoute = <String, String>{
  'donors':       '/donors',
  'donations':    '/donations',
  'students':     '/students',
  'offices':      '/offices',
  'reports':      '/reports',
  'reminders':    '/reminders',
  'tracker':      '/donation-tracker',
  'payments':     '/payment-links',
  'achievements': '/achievements',
};

bool get isAdmin => currentLoggedInRole == null;

bool canAccess(String module) =>
    isAdmin || (currentLoggedInRole?.modules.contains(module) ?? false);
