import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../network/api_client.dart';
import 'role_auth.dart';
import '../../features/settings/profile_store.dart';

// ══════════════════════════════════════════════════════════════════════
// SESSION — keeps the logged-in identity across page reloads.
//
// The role (currentLoggedInRole) lives in memory, so without this a reload
// would reset it to null (= full admin). On startup we re-read the persisted
// backend token and ask the server who the user is, restoring their exact
// scoped access. The router uses [isLoggedIn] to send signed-out users to
// the login screen instead of ever showing an admin view.
// ══════════════════════════════════════════════════════════════════════

// True while a user is signed in (backend or local). Drives the auth redirect.
bool isLoggedIn = false;

// Maps a backend /auth/me user onto the frontend session and returns the
// landing route. SUPER_ADMIN/ADMIN get full access (currentLoggedInRole = null);
// everyone else is restricted to the modules stored on their account.
String applyBackendUser(Map<String, dynamic> me) {
  final role  = (me['role'] as String?) ?? 'STAFF';
  final email = (me['email'] as String?) ?? '';
  final nm    = (me['name'] as String?);
  final mName = (nm != null && nm.trim().isNotEmpty) ? nm : email;
  final csv   = me['modules'] as String?;

  isLoggedIn = true;
  if (role == 'SUPER_ADMIN' || role == 'ADMIN') {
    currentLoggedInRole = null; // full access
    updateProfile(adminProfile.value.copyWith(name: mName, email: email));
    return '/dashboard';
  }
  final modules = (csv != null && csv.trim().isNotEmpty)
      ? csv.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toSet()
      : modulesForBackendRole(role);
  currentLoggedInRole =
      AppRole(name: mName, email: email, password: '', roleName: role, modules: modules);
  return modules.isNotEmpty ? (moduleToRoute[modules.first] ?? '/dashboard') : '/dashboard';
}

Set<String> modulesForBackendRole(String role) => switch (role) {
      'MANAGER'   => {'donors', 'donations', 'students', 'reports', 'reminders', 'tracker'},
      'STAFF'     => {'students', 'reports', 'reminders'},
      'VOLUNTEER' => {'reports'},
      _           => {'reports'},
    };

// Restore the session from the persisted token on app startup. If the token is
// missing or can't be verified, sign the user out rather than defaulting to
// admin. Called (awaited) before the app renders.
Future<void> restoreSession() async {
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('access_token');
  if (token == null || token.isEmpty) {
    isLoggedIn = false;
    currentLoggedInRole = null;
    return;
  }
  try {
    final meResp = await apiClient.get('/auth/me');
    final me = (meResp['data'] as Map).cast<String, dynamic>();
    applyBackendUser(me);
  } on DioException catch (e) {
    // The refresh-token interceptor already retried once on a 401 before this
    // error reaches us. A response means the server genuinely rejected the
    // session (or the retry also failed) — sign out for real. No response at
    // all (timeout, connection refused, DB cold-start) is a transient network
    // hiccup, not an invalid session — don't destroy a possibly-valid token
    // over it, or a routine reload during a slow backend start logs the user
    // out for no reason. Just don't grant access on *this* load.
    if (e.response != null) {
      await apiClient.clearTokens();
      currentLoggedInRole = null;
    }
    isLoggedIn = false;
  } catch (_) {
    isLoggedIn = false;
  }
}

// Sign out: clear tokens + session so the router routes to login.
Future<void> logoutSession() async {
  await apiClient.clearTokens();
  currentLoggedInRole = null;
  isLoggedIn = false;
}
