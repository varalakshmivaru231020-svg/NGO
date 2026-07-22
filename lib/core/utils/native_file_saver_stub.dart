import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

// Mobile/desktop "save" — there's no browser download folder to write into
// directly, so saving means handing the file to the OS share sheet (the same
// pattern already used for activity video downloads in video_player_stub.dart),
// letting the user save to Files, send it via WhatsApp, etc.
class NativeFileSaver {
  static Future<bool> saveCsv(String filename, String content) =>
      _shareText(filename.endsWith('.csv') ? filename : '$filename.csv', content);
  static Future<bool> saveText(String filename, String content) => _shareText(filename, content);
  static Future<bool> saveHtml(String filename, String content) =>
      _shareText(filename.endsWith('.html') ? filename : '$filename.html', content);
  static Future<bool> saveBytes(String filename, Uint8List bytes, String mimeType) =>
      _shareBytes(filename, bytes);

  static Future<bool> _shareText(String filename, String content) =>
      _shareBytes(filename, Uint8List.fromList(utf8.encode(content)));

  static Future<bool> _shareBytes(String filename, Uint8List bytes) async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], fileNameOverrides: [filename]);
      return true;
    } catch (_) {
      return false;
    }
  }
}
