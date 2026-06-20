import 'package:file_picker/file_picker.dart';

class NativeFilePicker {
  static Future<({String path, String name})?> pickAny() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withData: true, // required on web to get file metadata
      );
      if (result == null || result.files.isEmpty) return null;
      final file = result.files.single;
      if (file.name.isEmpty) return null;
      return (path: file.path ?? file.name, name: file.name);
    } catch (_) {
      return null;
    }
  }
}
