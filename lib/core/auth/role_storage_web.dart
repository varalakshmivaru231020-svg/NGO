// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

const _storageKey = 'saksham_roles';

String? readRoleStorage() {
  try { return html.window.localStorage[_storageKey]; } catch (_) { return null; }
}

void writeRoleStorage(String data) {
  try { html.window.localStorage[_storageKey] = data; } catch (_) {}
}
