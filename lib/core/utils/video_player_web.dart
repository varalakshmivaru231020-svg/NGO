import 'dart:html' as html;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

void downloadBytes(Uint8List bytes, String filename, {String? mimeType}) {
  final blob = html.Blob([bytes], mimeType ?? 'application/octet-stream');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}

// Embeds a native HTML5 <video> element (controls, fullscreen, duration —
// all handled by the browser) inside the Flutter widget tree via a
// platform view. No extra pub package needed.
class WebVideoPlayer extends StatefulWidget {
  const WebVideoPlayer({super.key, required this.bytes, this.mimeType});
  final Uint8List bytes;
  final String? mimeType;

  @override
  State<WebVideoPlayer> createState() => _WebVideoPlayerState();
}

class _WebVideoPlayerState extends State<WebVideoPlayer> {
  late final String _viewType;
  late final String _blobUrl;

  @override
  void initState() {
    super.initState();
    final blob = html.Blob([widget.bytes], widget.mimeType ?? 'video/mp4');
    _blobUrl = html.Url.createObjectUrlFromBlob(blob);
    _viewType = 'web-video-player-${DateTime.now().microsecondsSinceEpoch}';

    ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) {
      final video = html.VideoElement()
        ..src = _blobUrl
        ..controls = true
        ..style.width = '100%'
        ..style.height = '100%'
        ..style.backgroundColor = '#000000';
      return video;
    });
  }

  @override
  void dispose() {
    html.Url.revokeObjectUrl(_blobUrl);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HtmlElementView(viewType: _viewType);
}
