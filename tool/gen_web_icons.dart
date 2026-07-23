// One-off: generates web favicon + PWA icons from the SKET tree/hands mark,
// using the same crop as tool/gen_launcher_icon.dart (Android). Standard
// icons keep a transparent background; maskable icons get a white backdrop
// with the logo padded into the ~70% safe zone, since the OS can crop
// maskable icons into a circle/squircle and content outside that zone may
// be clipped.
// Run with: dart run tool/gen_web_icons.dart
import 'dart:io';
import 'package:image/image.dart' as img;

void main() {
  final src = img.decodePng(File('assets/images/sket-logo.png').readAsBytesSync())!;

  const side = 470;
  final cropY = ((src.height - side) / 2).round();
  final cropped = img.copyCrop(src, x: 0, y: cropY, width: side, height: side);

  void writeStandard(String path, int size) {
    final resized = img.copyResize(cropped, width: size, height: size, interpolation: img.Interpolation.average);
    File(path).writeAsBytesSync(img.encodePng(resized));
    print('wrote $path (${size}x$size)');
  }

  void writeMaskable(String path, int size) {
    final canvas = img.Image(width: size, height: size, numChannels: 4);
    img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
    final logoSize = (size * 0.7).round();
    final logo = img.copyResize(cropped, width: logoSize, height: logoSize, interpolation: img.Interpolation.average);
    final offset = ((size - logoSize) / 2).round();
    img.compositeImage(canvas, logo, dstX: offset, dstY: offset);
    File(path).writeAsBytesSync(img.encodePng(canvas));
    print('wrote $path (${size}x$size, maskable)');
  }

  writeStandard('web/favicon.png', 32);
  writeStandard('web/icons/Icon-192.png', 192);
  writeStandard('web/icons/Icon-512.png', 512);
  writeMaskable('web/icons/Icon-maskable-192.png', 192);
  writeMaskable('web/icons/Icon-maskable-512.png', 512);
}
