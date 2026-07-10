import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ssl_bypass.dart' if (dart.library.io) 'ssl_bypass_io.dart';

class ApiClient {
  // Auto-detects the API URL so the SAME build works everywhere:
  //  • local dev (localhost / 127.0.0.1)  -> http://localhost:3001/api/v1
  //  • production (any other host)         -> https://<that host>/api/v1
  //    (the site reverse-proxies /api to the backend, so it's same-origin).
  static String get defaultBaseUrl {
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
      receiveTimeout: const Duration(seconds: 30),
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
        if (error.response?.statusCode == 401) {
          final prefs = await SharedPreferences.getInstance();
          final refresh = prefs.getString('refresh_token');
          if (refresh != null) {
            try {
              final custom = prefs.getString(serverUrlKey);
              final base = (custom != null && custom.isNotEmpty) ? custom : defaultBaseUrl;
              final refreshDio = Dio();
              applySslBypass(refreshDio.httpClientAdapter);
              final res = await refreshDio.post('$base/auth/refresh', data: {'refreshToken': refresh});
              final data = res.data['data'] as Map;
              final newToken = data['accessToken'] as String;
              final newRefresh = data['refreshToken'] as String?;
              await prefs.setString('access_token', newToken);
              // The backend rotates refresh tokens (old one is deleted server-side
              // on every /auth/refresh call) — must persist the new one too, or
              // the *next* refresh fails and silently logs the user out.
              if (newRefresh != null) await prefs.setString('refresh_token', newRefresh);
              error.requestOptions.headers['Authorization'] = 'Bearer $newToken';
              handler.resolve(await _dio.fetch(error.requestOptions));
              return;
            } catch (_) {}
          }
          await clearTokens();
        }
        handler.next(error);
      },
    ));
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
