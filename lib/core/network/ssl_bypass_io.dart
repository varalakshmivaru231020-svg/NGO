import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';

// Mobile / desktop — bypass ISP SSL interception
void applySslBypass(HttpClientAdapter adapter) {
  (adapter as IOHttpClientAdapter).createHttpClient = () {
    final client = HttpClient();
    client.badCertificateCallback = (cert, host, port) => true;
    return client;
  };
}
