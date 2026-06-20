import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../utils/native_image_picker.dart';

const _brand600   = Color(0xFF0E8C76);
const _brand100   = Color(0xFFD6F3EC);
const _coral500   = Color(0xFFF2685E);
const _onSurface3 = Color(0xFF93A29F);
const _border     = Color(0xFFE5EBE9);

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

  Future<void> _pick(Future<Uint8List?> Function() picker) async {
    setState(() => _loading = true);
    try {
      final bytes = await picker();
      if (bytes != null && mounted) {
        setState(() => _bytes = bytes);
        widget.onImageChanged?.call(_bytes);
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  void _remove() {
    setState(() => _bytes = null);
    widget.onImageChanged?.call(null);
  }

  void _openSheet() {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(widget.label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 18),
            Row(children: [
              Expanded(child: _Opt(icon: Icons.camera_alt_outlined,    label: 'Camera',  color: _brand600,
                onTap: () { Navigator.pop(ctx); _pick(NativeImagePicker.fromCamera); })),
              const SizedBox(width: 12),
              Expanded(child: _Opt(icon: Icons.photo_library_outlined, label: 'Gallery', color: _brand600,
                onTap: () { Navigator.pop(ctx); _pick(NativeImagePicker.fromGallery); })),
              if (_bytes != null) ...[
                const SizedBox(width: 12),
                Expanded(child: _Opt(icon: Icons.delete_outline, label: 'Remove', color: _coral500,
                  onTap: () { Navigator.pop(ctx); _remove(); })),
              ],
            ]),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
    GestureDetector(
      onTap: _openSheet,
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

class _Opt extends StatelessWidget {
  const _Opt({required this.icon, required this.label, required this.color, required this.onTap});
  final IconData icon; final String label; final Color color; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Column(children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 6),
        Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: color)),
      ]),
    ),
  );
}
