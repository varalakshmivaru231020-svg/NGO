// Shared role store + session state — used by login, sidebar, and roles screen
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:convert';

class AppRole {
  AppRole({required this.name, required this.password, required this.modules});
  String name;
  String password;
  Set<String> modules;

  Map<String, dynamic> toJson() => {
    'name': name,
    'password': password,
    'modules': modules.toList(),
  };

  factory AppRole.fromJson(Map<String, dynamic> j) => AppRole(
    name:     j['name']     as String,
    password: j['password'] as String,
    modules:  Set<String>.from(j['modules'] as List),
  );
}

const _storageKey = 'saksham_roles';

final _defaultRoles = <AppRole>[
  AppRole(name: 'Donations Manager', password: 'don123',   modules: {'donations', 'reports', 'tracker'}),
  AppRole(name: 'Donor Manager',     password: 'donor123', modules: {'donors', 'donations', 'reports'}),
  AppRole(name: 'Children Manager',  password: 'child123', modules: {'students', 'reports'}),
];

// Global roles list — loaded from localStorage, falls back to defaults
final appRoles = _loadRoles();

List<AppRole> _loadRoles() {
  try {
    final raw = html.window.localStorage[_storageKey];
    if (raw != null && raw.isNotEmpty) {
      final list = jsonDecode(raw) as List;
      return list.map((e) => AppRole.fromJson(e as Map<String, dynamic>)).toList();
    }
  } catch (_) {}
  return [..._defaultRoles];
}

// Call this whenever appRoles is mutated (add / edit / delete)
void saveRoles() {
  try {
    html.window.localStorage[_storageKey] =
        jsonEncode(appRoles.map((r) => r.toJson()).toList());
  } catch (_) {}
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
