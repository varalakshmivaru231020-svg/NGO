import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

const _brand600 = Color(0xFFFF9933);

String _extFromMime(String? mime) {
  switch (mime) {
    case 'video/quicktime': return 'mov';
    case 'video/x-msvideo': return 'avi';
    case 'video/webm': return 'webm';
    default: return 'mp4';
  }
}

// "Download" on mobile means handing the file to the OS share sheet, so the
// user can save it to Files, send it via WhatsApp, etc. — there's no browser
// download folder to write into directly, and this avoids needing broad
// storage-write permissions on modern Android.
Future<void> downloadBytes(Uint8List bytes, String filename, {String? mimeType}) async {
  final dir = await getTemporaryDirectory();
  final safeName = filename.isNotEmpty ? filename : 'download.${_extFromMime(mimeType)}';
  final file = File('${dir.path}/$safeName');
  await file.writeAsBytes(bytes);
  await Share.shareXFiles([XFile(file.path)], fileNameOverrides: [safeName]);
}

class WebVideoPlayer extends StatefulWidget {
  const WebVideoPlayer({super.key, required this.bytes, this.mimeType});
  final Uint8List bytes;
  final String? mimeType;

  @override
  State<WebVideoPlayer> createState() => _WebVideoPlayerState();
}

class _WebVideoPlayerState extends State<WebVideoPlayer> {
  VideoPlayerController? _controller;
  File? _tempFile;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/activity_${DateTime.now().microsecondsSinceEpoch}.${_extFromMime(widget.mimeType)}');
      await file.writeAsBytes(widget.bytes);
      final controller = VideoPlayerController.file(file);
      await controller.initialize();
      if (!mounted) { controller.dispose(); return; }
      setState(() { _controller = controller; _tempFile = file; });
      controller.play();
    } catch (_) {
      if (mounted) setState(() => _error = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _tempFile?.delete().catchError((_) => File(''));
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(child: Text('Could not play video.', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600))),
      );
    }
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const ColoredBox(color: Colors.black, child: Center(child: CircularProgressIndicator(color: _brand600)));
    }
    return ColoredBox(
      color: Colors.black,
      child: GestureDetector(
        onTap: () => setState(() => controller.value.isPlaying ? controller.pause() : controller.play()),
        child: Stack(alignment: Alignment.center, children: [
          Center(child: AspectRatio(aspectRatio: controller.value.aspectRatio, child: VideoPlayer(controller))),
          ValueListenableBuilder<VideoPlayerValue>(
            valueListenable: controller,
            builder: (context, value, _) => value.isPlaying
              ? const SizedBox.shrink()
              : const Icon(Icons.play_arrow_rounded, size: 56, color: Colors.white70),
          ),
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: VideoProgressIndicator(controller, allowScrubbing: true,
              colors: const VideoProgressColors(playedColor: _brand600, bufferedColor: Colors.white30, backgroundColor: Colors.white12)),
          ),
        ]),
      ),
    );
  }
}
