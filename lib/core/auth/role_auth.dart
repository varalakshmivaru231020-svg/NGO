// Shared role store + session state — used by login, sidebar, and roles screen

class AppRole {
  AppRole({required this.name, required this.password, required this.modules});
  String name;
  String password;
  Set<String> modules;
}

// Global roles — admin creates these; role members log in with name+password
final appRoles = <AppRole>[
  AppRole(name: 'Donations Manager', password: 'don123',   modules: {'donations', 'reports', 'tracker'}),
  AppRole(name: 'Donor Manager',     password: 'donor123', modules: {'donors', 'donations', 'reports'}),
  AppRole(name: 'Children Manager',  password: 'child123', modules: {'students', 'reports'}),
];

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
