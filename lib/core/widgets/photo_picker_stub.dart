import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

const _brand600   = Color(0xFFFF9933);
const _brand100   = Color(0xFFFFE8CC);
const _coral500   = Color(0xFFF2685E);
const _onSurface3 = Color(0xFF93A29F);

class PhotoPickerCircle extends StatefulWidget {
  const PhotoPickerCircle({
    super.key,
    this.size = 88,
    this.label = 'Photo',
    this.initials,
    this.initialImage,
    this.placeholderAsset,
    this.onImageChanged,
  });
  final double size;
  final String label;
  final String? initials;
  final Uint8List? initialImage;
  final String? placeholderAsset; // shown when no photo is set
  final void Function(Uint8List?)? onImageChanged;

  @override
  State<PhotoPickerCircle> createState() => _PhotoPickerCircleState();
}

class _PhotoPickerCircleState extends State<PhotoPickerCircle> {
  Uint8List? _bytes;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _bytes = widget.initialImage;
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
              boxShadow: const [BoxShadow(color: Color(0x28000000), blurRadius: 24, offset: Offset(0, 8))],
            ),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(18, 18, 18, 10),
                child: Text('Upload Photo', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Color(0xFF15211E))),
              ),
              const Divider(height: 1, color: Color(0xFFE5EBE9)),
              InkWell(
                onTap: () { Navigator.pop(ctx); _pickImage(camera: true); },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  child: Row(children: [
                    Container(width: 40, height: 40,
                      decoration: BoxDecoration(color: _brand100, borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.camera_alt_outlined, color: _brand600, size: 20)),
                    const SizedBox(width: 14),
                    const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Take Photo', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF15211E))),
                      Text('Open camera', style: TextStyle(fontSize: 12, color: _onSurface3)),
                    ]),
                  ]),
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE5EBE9)),
              InkWell(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                onTap: () { Navigator.pop(ctx); _pickImage(camera: false); },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  child: Row(children: [
                    Container(width: 40, height: 40,
                      decoration: BoxDecoration(color: const Color(0xFFE7E3FD), borderRadius: BorderRadius.circular(12)),
                      child: const Icon(Icons.photo_library_outlined, color: Color(0xFF7C6CF0), size: 20)),
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
    setState(() => _loading = true);
    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(
        source: camera ? ImageSource.camera : ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (file != null && mounted) {
        final bytes = await file.readAsBytes();
        setState(() => _bytes = bytes);
        widget.onImageChanged?.call(bytes);
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
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
                  ? const LinearGradient(colors: [Color(0xFFE07C1F), Color(0xFFFFB25E)])
                  : null,
              border: Border.all(color: _brand600.withValues(alpha: 0.35), width: 2),
            ),
            clipBehavior: Clip.hardEdge,
            child: _loading
                ? Center(child: SizedBox(width: 24, height: 24,
                    child: CircularProgressIndicator(color: _brand600, strokeWidth: 2.5)))
                : _bytes != null
                    ? Image.memory(_bytes!, fit: BoxFit.contain, width: widget.size, height: widget.size)
                    : widget.placeholderAsset != null
                        ? Container(color: Colors.white, child: Image.asset(widget.placeholderAsset!, fit: BoxFit.cover, alignment: Alignment.centerLeft, width: widget.size, height: widget.size))
                        : Center(
                            child: widget.initials != null
                                ? Text(widget.initials!,
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: widget.size * 0.28))
                                : Icon(Icons.add_a_photo_outlined, size: widget.size * 0.35, color: Colors.white)),
          ),
          Positioned(
            bottom: 0, right: 0,
            child: Container(
              width: 26, height: 26,
              decoration: BoxDecoration(
                color: _bytes != null ? _coral500 : _brand600,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Icon(_bytes != null ? Icons.edit : Icons.camera_alt, size: 13, color: Colors.white),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 6),
      Text(widget.label,
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: _onSurface3)),
    ],
  );
}
