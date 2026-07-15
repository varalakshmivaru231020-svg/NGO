import 'dart:typed_data';
import 'package:flutter/material.dart';

void downloadBytes(Uint8List bytes, String filename, {String? mimeType}) {
  // No-op outside web builds.
}

class WebVideoPlayer extends StatelessWidget {
  const WebVideoPlayer({super.key, required this.bytes, this.mimeType});
  final Uint8List bytes;
  final String? mimeType;

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: Colors.black,
    child: Center(
      child: Text('Video playback is only available on web.',
        style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600)),
    ),
  );
}
