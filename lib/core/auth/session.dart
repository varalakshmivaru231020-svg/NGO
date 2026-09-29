import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show ValueNotifier;
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

// Bumped whenever the session ends so the router re-runs its redirect and
// lands on /login (see routerProvider's refreshListenable).
final authChanges = ValueNotifier<int>(0);

// Hooked into the API client: when the server definitively rejects the
// session, end it here instead of leaving the user on screens that silently
// render zeros because every call now fails with 401.
void installSessionExpiryHandler() {
  ApiClient.onSessionExpired = () {
    if (!isLoggedIn) return;
    currentLoggedInRole = null;
    isLoggedIn = false;
    sessionExpiredNotice = true;
    authChanges.value++;
  };
}

// Set when the session was ended by the server (not by the user tapping
// Logout) so the login screen can explain why they are there.
bool sessionExpiredNotice = false;

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
    // Backend is the source of truth for name AND photo — profile edits save
    // there (PATCH /users/me/profile), so restores no longer revert them.
    final avatar = me['avatar'] as String?;
    updateProfile(adminProfile.value.copyWith(
      name: mName,
      email: email,
      photoBase64: (avatar != null && avatar.isNotEmpty) ? avatar : adminProfile.value.photoBase64,
    ));
    return '/dashboard';
  }
  final modules = (csv != null && csv.trim().isNotEmpty)
      ? csv.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toSet()
      : modulesForBackendRole(role);
  currentLoggedInRole =
      AppRole(name: mName, email: email, password: '', roleName: role, modules: modules, backendId: me['id'] as String?);
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
  // A cold backend / flaky connection on reload must not look like a logout:
  // retry transient failures a few times before giving up on this load.
  for (var attempt = 0; attempt < 3; attempt++) {
    try {
      final meResp = await apiClient.get('/auth/me');
      final me = (meResp['data'] as Map).cast<String, dynamic>();
      applyBackendUser(me);
      return;
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      // 401/403 survive the interceptor's refresh attempt, so the session is
      // genuinely gone. Anything else (no response, 429, 5xx) is transient —
      // keep the token so the next load can still use it.
      if (code == 401 || code == 403) {
        await apiClient.clearTokens();
        currentLoggedInRole = null;
        isLoggedIn = false;
        return;
      }
    } catch (_) {}
    await Future.delayed(Duration(milliseconds: 800 * (attempt + 1)));
  }
  isLoggedIn = false;
}

// Sign out: clear tokens + session so the router routes to login.
Future<void> logoutSession() async {
  await apiClient.clearTokens();
  currentLoggedInRole = null;
  isLoggedIn = false;
  authChanges.value++;
}
