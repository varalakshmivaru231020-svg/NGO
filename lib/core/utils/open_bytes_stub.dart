import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

// Mobile/desktop "view" — there's no in-browser tab to open a blob in, so
// viewing means handing the file to the OS share sheet, same as the save
// path (Android/iOS surface an "Open in <app>" option there, e.g. a PDF
// viewer or gallery app, which is the closest mobile equivalent of "view").
// Fire-and-forget to match the synchronous, non-awaited web implementation.
void openBytesInBrowser(Uint8List bytes, String filename) {
  _open(bytes, filename);
}

Future<void> _open(Uint8List bytes, String filename) async {
  try {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(file.path)], fileNameOverrides: [filename]);
  } catch (_) {
    // Best-effort — nothing sensible to surface to the user from a
    // fire-and-forget helper with no BuildContext.
  }
}
