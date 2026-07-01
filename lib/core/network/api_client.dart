import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ssl_bypass.dart' if (dart.library.io) 'ssl_bypass_io.dart';

class ApiClient {
  // NOTE: points at the local backend for development/testing. For production,
  // set this to the deployed API URL (e.g. https://ngo.bestprime.live/api/v1).
  static const defaultBaseUrl = 'http://localhost:3001/api/v1';
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
              final newToken = res.data['data']['accessToken'] as String;
              await prefs.setString('access_token', newToken);
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
