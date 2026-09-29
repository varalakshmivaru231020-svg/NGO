import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'ssl_bypass.dart' if (dart.library.io) 'ssl_bypass_io.dart';

class ApiClient {
  // Auto-detects the API URL so the SAME build works everywhere:
  //  • local dev (localhost / 127.0.0.1)  -> http://localhost:3001/api/v1
  //  • production (any other host)         -> https://<that host>/api/v1
  //    (the site reverse-proxies /api to the backend, so it's same-origin).
  // On a native build (APK/desktop) there's no "current host" to read —
  // Uri.base doesn't reflect a real domain — so it must point straight at
  // the live server instead of falling through to the web-only localhost case.
  static String get defaultBaseUrl {
    if (!kIsWeb) return 'https://sket.krishnashraya.in/api/v1';
    final host = Uri.base.host;
    if (host.isEmpty || host == 'localhost' || host == '127.0.0.1') {
      return 'http://localhost:3001/api/v1';
    }
    return '${Uri.base.origin}/api/v1';
  }

  static const serverUrlKey = 'server_url';
  late final Dio _dio;

  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: defaultBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      // Photos/documents travel base64 in the JSON body; on a slow uplink a
      // few MB can take well over 30s, which used to abort a save that the
      // server then completed anyway.
      sendTimeout: kIsWeb ? null : const Duration(minutes: 3),
      receiveTimeout: const Duration(seconds: 90),
      headers: {'Content-Type': 'application/json'},
    ));

    applySslBypass(_dio.httpClientAdapter);

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('access_token');
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        final custom = prefs.getString(serverUrlKey);
        if (custom != null && custom.isNotEmpty) options.baseUrl = custom;
        handler.next(options);
      },
      onError: (error, handler) async {
        // Only a 401 on a normal call is worth a refresh; a 401 from the
        // retried call itself means the fresh token was rejected too.
        if (error.response?.statusCode != 401 ||
            error.requestOptions.extra['_retried'] == true ||
            error.requestOptions.path.contains('/auth/login')) {
          handler.next(error);
          return;
        }
        final sentAuth = error.requestOptions.headers['Authorization'] as String?;
        final outcome = await _refreshOnce(sentAuth);
        if (outcome == _RefreshOutcome.refreshed) {
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('access_token');
          final opts = error.requestOptions
            ..headers['Authorization'] = 'Bearer $token'
            ..extra['_retried'] = true;
          try {
            handler.resolve(await _dio.fetch(opts));
          } on DioException catch (e) {
            handler.next(e);
          }
          return;
        }
        if (outcome == _RefreshOutcome.rejected) {
          await clearTokens();
          onSessionExpired?.call();
        }
        // transient: keep the tokens — the next call can try again.
        handler.next(error);
      },
    ));
  }

  // Called once the server has definitively refused the session, so the app
  // can route to the login screen instead of rendering every screen with
  // empty data (every call 401s once the tokens are gone).
  static void Function()? onSessionExpired;

  // Single-flight: when the access token expires, the dashboard fires a dozen
  // requests that all 401 together. Each used to call /auth/refresh with the
  // same token; the backend rotates it, so all but the first failed and the
  // user was logged out. Now they all await the one in-flight refresh.
  Future<_RefreshOutcome>? _inflightRefresh;

  Future<_RefreshOutcome> _refreshOnce(String? sentAuth) {
    return _inflightRefresh ??= _doRefresh(sentAuth).whenComplete(() => _inflightRefresh = null);
  }

  Future<_RefreshOutcome> _doRefresh(String? sentAuth) async {
    final prefs = await SharedPreferences.getInstance();
    // Another browser tab may have refreshed already and written new tokens
    // to localStorage; SharedPreferences caches per tab, so re-read it.
    try { await prefs.reload(); } catch (_) {}
    final current = prefs.getString('access_token');
    if (current != null && sentAuth != null && sentAuth != 'Bearer $current') {
      return _RefreshOutcome.refreshed; // already renewed elsewhere — just retry
    }
    final refresh = prefs.getString('refresh_token');
    if (refresh == null || refresh.isEmpty) return _RefreshOutcome.rejected;
    try {
      final custom = prefs.getString(serverUrlKey);
      final base = (custom != null && custom.isNotEmpty) ? custom : defaultBaseUrl;
      final refreshDio = Dio(BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 20),
      ));
      applySslBypass(refreshDio.httpClientAdapter);
      final res = await refreshDio.post('$base/auth/refresh', data: {'refreshToken': refresh});
      final data = res.data['data'] as Map;
      await prefs.setString('access_token', data['accessToken'] as String);
      // The backend rotates refresh tokens — persist the new one too, or the
      // next refresh uses a retired token.
      final newRefresh = data['refreshToken'] as String?;
      if (newRefresh != null) await prefs.setString('refresh_token', newRefresh);
      return _RefreshOutcome.refreshed;
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      // Only 401/403 mean the refresh token itself is dead. Timeouts, no
      // connection, 429 rate-limit or a 5xx are temporary — signing out over
      // them is what logged people out "randomly".
      if (code == 401 || code == 403) {
        // Last chance: another tab may have rotated it just now.
        try { await prefs.reload(); } catch (_) {}
        if (prefs.getString('refresh_token') != refresh) return _RefreshOutcome.refreshed;
        return _RefreshOutcome.rejected;
      }
      return _RefreshOutcome.transient;
    } catch (_) {
      return _RefreshOutcome.transient;
    }
  }

  Future<Map<String, dynamic>> get(String path, {Map<String, dynamic>? params}) async {
    final r = await _dio.get(path, queryParameters: params);
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> post(String path, Map<String, dynamic> body) async {
    final r = await _dio.post(path, data: body);
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> patch(String path, Map<String, dynamic> body) async {
    final r = await _dio.patch(path, data: body);
    return r.data as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> put(String path, Map<String, dynamic> body) async {
    final r = await _dio.put(path, data: body);
    return r.data as Map<String, dynamic>;
  }

  // Returns the decoded response body (or null) so callers can detect an
  // approval-pending result; existing callers that ignore it still work.
  Future<Map<String, dynamic>?> delete(String path) async {
    final r = await _dio.delete(path);
    return r.data is Map<String, dynamic> ? r.data as Map<String, dynamic> : null;
  }

  // Extract the backend's actual error message from a thrown DioException so
  // screens can show the real reason instead of a generic (or wrong) one.
  // Nest error bodies look like {statusCode, message, error} where message is
  // a string or a list of validation messages.
  static String errorMessage(Object e, {String fallback = 'Something went wrong. Please try again.'}) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map) {
        final msg = data['message'] ?? data['error'];
        final base = msg is List && msg.isNotEmpty
            ? msg.join('\n')
            : (msg is String && msg.trim().isNotEmpty ? msg : null);
        // The backend's exception filter puts validation details in `errors`
        // and flattens message to just 'Validation failed'.
        final errs = data['errors'];
        if (errs is List && errs.isNotEmpty) {
          return '${base ?? 'Validation failed'}\n${errs.join('\n')}';
        }
        if (base != null) return base;
      }
      if (e.response == null) return 'Could not reach the server. Check your connection and try again.';
      return '$fallback (HTTP ${e.response?.statusCode})';
    }
    return fallback;
  }

  Future<void> saveTokens(String access, String refresh) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', access);
    await prefs.setString('refresh_token', refresh);
  }

  Future<void> clearTokens() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    await prefs.remove('refresh_token');
  }
}

final apiClient = ApiClient();

enum _RefreshOutcome { refreshed, rejected, transient }
