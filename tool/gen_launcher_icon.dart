// One-off: generates Android launcher icons (all mipmap densities) from the
// SKET tree/hands mark cropped out of the wide logo lockup (icon + wordmark).
// Crop rectangle below was chosen by visual inspection (tool/preview_crop.dart)
// of the 1200x600 source: the mark sits within x[0,470], and this square
// keeps it centered with a small margin, well clear of the "SKET" wordmark.
// Run with: dart run tool/gen_launcher_icon.dart
import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final src = img.decodePng(File('assets/images/sket-logo.png').readAsBytesSync())!;
  print('source: ${src.width}x${src.height}');

  const side = 470;
  final cropY = ((src.height - side) / 2).round(); // vertically center
  final cropped = img.copyCrop(src, x: 0, y: cropY, width: side, height: side);

  const targets = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
  };
  targets.forEach((dir, size) {
    final resized = img.copyResize(cropped, width: size, height: size, interpolation: img.Interpolation.average);
    final path = 'android/app/src/main/res/$dir/ic_launcher.png';
    File(path).writeAsBytesSync(img.encodePng(resized));
    print('wrote $path ($size x $size)');
  });

  final large = img.copyResize(cropped, width: 512, height: 512, interpolation: img.Interpolation.average);
  File('assets/images/app_icon.png').writeAsBytesSync(img.encodePng(large));
  print('wrote assets/images/app_icon.png (512x512)');
}
