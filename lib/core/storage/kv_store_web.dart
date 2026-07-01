// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

String? readKv(String key) {
  try { return html.window.localStorage[key]; } catch (_) { return null; }
}

void writeKv(String key, String data) {
  try { html.window.localStorage[key] = data; } catch (_) {}
}
