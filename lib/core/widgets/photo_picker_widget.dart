// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/material.dart';

const _brand600   = Color(0xFF0E8C76);
const _brand100   = Color(0xFFD6F3EC);
const _coral500   = Color(0xFFF2685E);
const _onSurface3 = Color(0xFF93A29F);

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

  void _showOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 8),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFE5EBE9), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 18),
          const Text('Add Photo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF15211E))),
          const SizedBox(height: 16),
          ListTile(
            leading: Container(width: 44, height: 44, decoration: BoxDecoration(color: _brand100, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.camera_alt_outlined, color: _brand600, size: 22)),
            title: const Text('Take Photo', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            subtitle: const Text('Open camera', style: TextStyle(fontSize: 12.5, color: _onSurface3)),
            onTap: () { Navigator.pop(context); _pickImage(camera: true); },
          ),
          ListTile(
            leading: Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0xFFE7E3FD), borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.photo_library_outlined, color: Color(0xFF7C6CF0), size: 22)),
            title: const Text('Choose from Gallery', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            subtitle: const Text('Pick an existing photo', style: TextStyle(fontSize: 12.5, color: _onSurface3)),
            onTap: () { Navigator.pop(context); _pickImage(camera: false); },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  Future<void> _pickImage({required bool camera}) async {
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

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
    GestureDetector(
      onTap: _showOptions,
      child: Stack(children: [
        Container(
          width: widget.size, height: widget.size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _bytes != null ? Colors.transparent : _brand100,
            gradient: _bytes == null && widget.initials == null
              ? const LinearGradient(colors: [Color(0xFF0B6E5D), Color(0xFF14A98C)])
              : null,
            border: Border.all(color: _brand600.withValues(alpha: 0.35), width: 2),
          ),
          clipBehavior: Clip.hardEdge,
          child: _loading
            ? const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: _brand600, strokeWidth: 2.5)))
            : _bytes != null
              ? Image.memory(_bytes!, fit: BoxFit.cover, width: widget.size, height: widget.size)
              : Center(child: widget.initials != null
                  ? Text(widget.initials!, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: widget.size * 0.28))
                  : Icon(Icons.add_a_photo_outlined, size: widget.size * 0.35, color: Colors.white)),
        ),
        Positioned(bottom: 0, right: 0, child: Container(
          width: 26, height: 26,
          decoration: BoxDecoration(
            color: _bytes != null ? _coral500 : _brand600,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
          child: Icon(_bytes != null ? Icons.edit : Icons.camera_alt, size: 13, color: Colors.white),
        )),
      ]),
    ),
    const SizedBox(height: 6),
    Text(widget.label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: _onSurface3)),
  ]);
}
