// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:convert' show base64Decode;
import 'dart:typed_data';
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

const _brand600   = Color(0xFF0E8C76);
const _brand100   = Color(0xFFD6F3EC);
const _coral500   = Color(0xFFF2685E);
const _onSurface3 = Color(0xFF93A29F);

int _webcamIdCounter = 0;

class PhotoPickerCircle extends StatefulWidget {
  const PhotoPickerCircle({
    super.key,
    this.size = 88,
    this.label = 'Photo',
    this.initials,
    this.onImageChanged,
  });

  final double size;
  final String label;
  final String? initials;
  final void Function(Uint8List?)? onImageChanged;

  @override
  State<PhotoPickerCircle> createState() => _PhotoPickerCircleState();
}

class _PhotoPickerCircleState extends State<PhotoPickerCircle> {
  Uint8List? _bytes;
  bool _loading = false;

  bool get _isMobile {
    final ua = html.window.navigator.userAgent.toLowerCase();
    return ua.contains('android') || ua.contains('iphone') ||
        ua.contains('ipad') || ua.contains('mobile');
  }

  void _showOptions() {
    showDialog(
      context: context,
      barrierColor: Colors.black26,
      builder: (ctx) => Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            width: 280,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(color: Color(0x28000000), blurRadius: 24, offset: Offset(0, 8)),
              ],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(18, 18, 18, 10),
                child: Text('Upload Photo',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF15211E))),
              ),
              const Divider(height: 1, color: Color(0xFFE5EBE9)),
              // Take Photo
              InkWell(
                onTap: () { Navigator.pop(ctx); _pickImage(camera: true); },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  child: Row(children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: _brand100, borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.camera_alt_outlined, color: _brand600, size: 20),
                    ),
                    const SizedBox(width: 14),
                    const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Take Photo', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF15211E))),
                      Text('Open camera', style: TextStyle(fontSize: 12, color: _onSurface3)),
                    ]),
                  ]),
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE5EBE9)),
              // Choose from Gallery
              InkWell(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                onTap: () { Navigator.pop(ctx); _pickImage(camera: false); },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  child: Row(children: [
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: const Color(0xFFE7E3FD), borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.photo_library_outlined, color: Color(0xFF7C6CF0), size: 20),
                    ),
                    const SizedBox(width: 14),
                    const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Choose from Gallery', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF15211E))),
                      Text('Pick an existing photo', style: TextStyle(fontSize: 12, color: _onSurface3)),
                    ]),
                  ]),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage({required bool camera}) async {
    if (camera && !_isMobile) {
      await _openWebcam();
      return;
    }
    setState(() => _loading = true);
    try {
      final input = html.FileUploadInputElement()..accept = 'image/*';
      if (camera) input.setAttribute('capture', 'environment');
      input.click();
      await input.onChange.first;
      final files = input.files;
      if (files != null && files.isNotEmpty && mounted) {
        final reader = html.FileReader();
        reader.readAsArrayBuffer(files[0]);
        await reader.onLoadEnd.first;
        final buffer = reader.result;
        if (buffer is ByteBuffer && mounted) {
          final bytes = buffer.asUint8List();
          setState(() => _bytes = bytes);
          widget.onImageChanged?.call(bytes);
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _openWebcam() async {
    html.MediaStream? stream;
    try {
      stream = await html.window.navigator.mediaDevices!
          .getUserMedia({'video': {'facingMode': 'user'}, 'audio': false});
    } catch (_) {
      // No camera / permission denied → fall back to file picker
      await _pickImage(camera: false);
      return;
    }
    if (!mounted) {
      stream.getTracks().forEach((t) => t.stop());
      return;
    }
    final bytes = await showDialog<Uint8List?>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _WebcamDialog(stream: stream!),
    );
    stream.getTracks().forEach((t) => t.stop());
    if (bytes != null && mounted) {
      setState(() => _bytes = bytes);
      widget.onImageChanged?.call(bytes);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: _showOptions,
            child: Stack(children: [
              Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _bytes != null ? Colors.transparent : _brand100,
                  gradient: _bytes == null && widget.initials == null
                      ? const LinearGradient(
                          colors: [Color(0xFF0B6E5D), Color(0xFF14A98C)])
                      : null,
                  border: Border.all(
                      color: _brand600.withValues(alpha: 0.35), width: 2),
                ),
                clipBehavior: Clip.hardEdge,
                child: _loading
                    ? Center(
                        child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                                color: _brand600, strokeWidth: 2.5)))
                    : _bytes != null
                        ? Image.memory(_bytes!,
                            fit: BoxFit.cover,
                            width: widget.size,
                            height: widget.size)
                        : Center(
                            child: widget.initials != null
                                ? Text(widget.initials!,
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: widget.size * 0.28))
                                : Icon(Icons.add_a_photo_outlined,
                                    size: widget.size * 0.35,
                                    color: Colors.white)),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: _bytes != null ? _coral500 : _brand600,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: Icon(
                      _bytes != null ? Icons.edit : Icons.camera_alt,
                      size: 13,
                      color: Colors.white),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 6),
          Text(widget.label,
              style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: _onSurface3)),
        ],
      );
}

// ── Webcam capture dialog ─────────────────────────────────────────────

class _WebcamDialog extends StatefulWidget {
  const _WebcamDialog({required this.stream});
  final html.MediaStream stream;

  @override
  State<_WebcamDialog> createState() => _WebcamDialogState();
}

class _WebcamDialogState extends State<_WebcamDialog> {
  late final String _viewId;
  late final html.VideoElement _video;
  bool _ready = false;
  Uint8List? _captured;

  @override
  void initState() {
    super.initState();
    _viewId = 'webcam-view-${_webcamIdCounter++}';
    _video = html.VideoElement()
      ..srcObject = widget.stream
      ..autoplay = true
      ..muted = true
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = 'cover'
      ..style.transform = 'scaleX(-1)'; // mirror for front-facing feel

    _video.onCanPlay.listen((_) {
      if (mounted) setState(() => _ready = true);
    });

    ui_web.platformViewRegistry.registerViewFactory(
      _viewId,
      (int id) => _video,
    );
  }

  void _capture() {
    final w = _video.videoWidth;
    final h = _video.videoHeight;
    if (w == 0 || h == 0) return;

    final canvas = html.CanvasElement(width: w, height: h);
    // mirror the capture too so it matches what user sees
    final ctx = canvas.context2D;
    ctx.translate(w.toDouble(), 0);
    ctx.scale(-1, 1);
    ctx.drawImage(_video, 0, 0);

    final dataUrl = canvas.toDataUrl('image/jpeg', 0.92);
    final bytes = base64Decode(dataUrl.split(',')[1]);
    setState(() => _captured = bytes);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // ── title bar ──
          Row(children: [
            const Expanded(
                child: Text('Take Photo',
                    style: TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800))),
            IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, size: 22)),
          ]),
          const SizedBox(height: 12),

          // ── video / captured preview ──
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 300,
              width: double.infinity,
              child: _captured != null
                  ? Image.memory(_captured!, fit: BoxFit.cover)
                  : Stack(children: [
                      HtmlElementView(viewType: _viewId),
                      if (!_ready)
                        const Center(
                            child: CircularProgressIndicator(
                                color: _brand600)),
                    ]),
            ),
          ),
          const SizedBox(height: 16),

          // ── action buttons ──
          if (_captured == null)
            GestureDetector(
              onTap: _ready ? _capture : null,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _ready ? _brand600 : _brand100,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.camera_alt_rounded,
                          color:
                              _ready ? Colors.white : _onSurface3,
                          size: 20),
                      const SizedBox(width: 8),
                      Text('Capture Photo',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _ready
                                  ? Colors.white
                                  : _onSurface3)),
                    ]),
              ),
            )
          else
            Row(children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _captured = null),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4F7F6),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE5EBE9)),
                    ),
                    child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.refresh_rounded,
                              size: 18,
                              color: Color(0xFF5A6B67)),
                          SizedBox(width: 8),
                          Text('Retake',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF5A6B67))),
                        ]),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(_captured),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    decoration: BoxDecoration(
                      color: _brand600,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.check_rounded,
                              size: 18, color: Colors.white),
                          SizedBox(width: 8),
                          Text('Use Photo',
                              style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white)),
                        ]),
                  ),
                ),
              ),
            ]),
        ]),
      ),
    );
  }
}
