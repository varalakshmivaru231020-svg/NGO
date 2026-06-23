// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

class NativeFileSaver {
  static Future<bool> saveCsv(String filename, String content) =>
      _download(filename.endsWith('.csv') ? filename : '$filename.csv', content, 'text/csv');
  static Future<bool> saveText(String filename, String content) =>
      _download(filename, content, 'text/plain');
  static Future<bool> saveHtml(String filename, String content) =>
      _download(filename.endsWith('.html') ? filename : '$filename.html', content, 'text/html');
  static Future<bool> saveBytes(String filename, Uint8List bytes, String mimeType) async {
    try {
      final blob = html.Blob([bytes], mimeType);
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', filename)
        ..click();
      html.Url.revokeObjectUrl(url);
      return true;
    } catch (_) {
      return false;
    }
  }
  static Future<bool> _download(String filename, String content, String mimeType) async {
    try {
      final blob = html.Blob([content], mimeType);
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', filename)
        ..click();
      html.Url.revokeObjectUrl(url);
      return true;
    } catch (_) {
      return false;
    }
  }
}
