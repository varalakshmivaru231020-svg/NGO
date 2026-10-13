import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../network/api_client.dart';
import '../theme/app_theme.dart';
import '../ui/ui.dart';

// Admin-only log of deleted donation invoices / expense vouchers. The backend
// copies every record into the audit log before deleting it; this sheet lists
// those copies (GET /donations/deleted, GET /expenses/deleted).
Future<void> showDeletedRecordsSheet(
  BuildContext context, {
  required String title,
  required String path,
  // Picks the number + party name to show for one deleted record.
  required ({String number, String name}) Function(Map<String, dynamic> record) describe,
}) {
  return showAppSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _DeletedRecordsSheet(title: title, path: path, describe: describe),
  );
}

class _DeletedRecordsSheet extends StatefulWidget {
  const _DeletedRecordsSheet({required this.title, required this.path, required this.describe});
  final String title, path;
  final ({String number, String name}) Function(Map<String, dynamic> record) describe;
  @override
  State<_DeletedRecordsSheet> createState() => _DeletedRecordsSheetState();
}

class _DeletedRecordsSheetState extends State<_DeletedRecordsSheet> {
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final r = await apiClient.get(widget.path);
      final inner = r['data'];
      final list = inner is List ? inner : (inner is Map ? (inner['data'] as List? ?? const []) : const []);
      if (mounted) {
        setState(() {
          _rows = list.whereType<Map>().map((m) => m.cast<String, dynamic>()).toList();
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = ApiClient.errorMessage(e); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmtDate = DateFormat('dd MMM yyyy, hh:mm a');
    final inr = NumberFormat('#,##,###', 'en_IN');
    Widget body;
    if (_loading) {
      body = const SkeletonList(rows: 4, rowHeight: 60);
    } else if (_error != null) {
      body = ErrorState(message: _error!, onRetry: _load);
    } else if (_rows.isEmpty) {
      body = const EmptyState(icon: Icons.history_rounded, title: 'Nothing deleted yet',
          message: 'Deleted records will be listed here.');
    } else {
      body = Column(children: [
        for (final row in _rows)
          Builder(builder: (ctx) {
            final record = (row['record'] as Map?)?.cast<String, dynamic>() ?? const {};
            final d = widget.describe(record);
            final amount = (record['amount'] as num?)?.toInt() ?? 0;
            String when = '';
            try { when = fmtDate.format(DateTime.parse(row['deletedAt'] as String).toLocal()); } catch (_) {}
            final by = row['deletedBy'] as String?;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: ctx.surface2, borderRadius: BorderRadius.circular(12), border: Border.all(color: ctx.border)),
              child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(d.name, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: ctx.textPrimary), overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(d.number, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: ctx.textSub)),
                  Text('Deleted $when${by != null ? ' by $by' : ''}',
                      style: TextStyle(fontSize: 11, color: ctx.textHint, fontWeight: FontWeight.w500)),
                ])),
                const SizedBox(width: 8),
                Text('₹${inr.format(amount)}', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: ctx.textSub,
                    decoration: TextDecoration.lineThrough)),
              ]),
            );
          }),
      ]);
    }
    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.8),
      decoration: BoxDecoration(color: context.cardBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 24),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SheetHandle(),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: Text(widget.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
          IconButton(icon: const Icon(Icons.close_rounded, size: 20), onPressed: () => Navigator.pop(context)),
        ]),
        const SizedBox(height: 8),
        Flexible(child: SingleChildScrollView(child: body)),
      ]),
    );
  }
}
