import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/native_file_saver.dart';
import 'package:saksham_app/core/ui/ui.dart';

// Shows a generated PDF inside the app (pay slip / salary statement) with a
// Download button. In-app rather than a new browser tab: the PDF is built
// asynchronously, and browsers block tabs opened after an async gap.
Future<void> showStaffPdfViewer(
  BuildContext context, {
  required String title,
  required String filename,
  required Future<Uint8List> Function() build,
}) {
  return Navigator.of(context).push(MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (_) => _StaffPdfViewer(title: title, filename: filename, build: build),
  ));
}

// Builds the PDF and saves it as a download (web) or file/share (mobile).
Future<void> downloadStaffPdf(BuildContext context, {required String filename, required Future<Uint8List> Function() build}) async {
  try {
    final ok = await NativeFileSaver.saveBytes(filename, await build(), 'application/pdf');
    if (!context.mounted) return;
    if (ok) {
      AppToast.success(context, 'Downloaded', detail: filename);
    } else {
      AppToast.error(context, 'Couldn’t save the PDF', detail: 'Please try again.');
    }
  } catch (_) {
    if (context.mounted) AppToast.error(context, 'Couldn’t create the PDF', detail: 'Please try again.');
  }
}

class _StaffPdfViewer extends StatefulWidget {
  const _StaffPdfViewer({required this.title, required this.filename, required this.build});
  final String title, filename;
  final Future<Uint8List> Function() build;
  @override
  State<_StaffPdfViewer> createState() => _StaffPdfViewerState();
}

class _StaffPdfViewerState extends State<_StaffPdfViewer> {
  // Built once and shared by the preview and the Download button.
  late final Future<Uint8List> _bytes = widget.build();
  bool _saving = false;

  Future<void> _download() async {
    setState(() => _saving = true);
    await downloadStaffPdf(context, filename: widget.filename, build: () => _bytes);
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Column(children: [
      Container(
        padding: EdgeInsets.fromLTRB(8, MediaQuery.of(context).padding.top + 10, 16, 10),
        decoration: BoxDecoration(color: context.headerBg, border: Border(bottom: BorderSide(color: context.border))),
        child: Row(children: [
          IconButton(tooltip: 'Close', icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.of(context).pop()),
          const SizedBox(width: 2),
          Expanded(child: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
          AppButton(label: 'Download', icon: Icons.download_rounded, busyLabel: 'Saving…', loading: _saving, onPressed: _download),
        ]),
      ),
      Expanded(child: Container(
        color: context.surface2,
        child: PdfPreview(
          build: (_) => _bytes,
          useActions: false,
          canChangeOrientation: false,
          canChangePageFormat: false,
          canDebug: false,
          maxPageWidth: 820,
          pdfFileName: widget.filename,
          loadingWidget: const Center(child: AppSpinner(size: 22)),
          onError: (ctx, e) => Center(child: Padding(
            padding: const EdgeInsets.all(24),
            child: EmptyStateLike(
              icon: Icons.picture_as_pdf_outlined,
              title: 'Preview isn’t available here',
              message: 'Use Download to save the PDF and open it.',
              action: AppButton(label: 'Download', icon: Icons.download_rounded, onPressed: _download),
            ),
          )),
        ),
      )),
    ]),
  );
}
