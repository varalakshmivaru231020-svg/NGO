import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';

class NativeImagePicker {
  static final _picker = ImagePicker();

  static Future<Uint8List?> fromCamera() async {
    try {
      final xfile = await _picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85,
        maxWidth: 1200,
      );
      if (xfile == null) return null;
      return await xfile.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  static Future<Uint8List?> fromGallery() async {
    try {
      final xfile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1200,
      );
      if (xfile == null) return null;
      return await xfile.readAsBytes();
    } catch (_) {
      return null;
    }
  }
}
