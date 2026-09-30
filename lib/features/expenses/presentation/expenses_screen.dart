import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/native_file_saver.dart';
import 'expense_report_generator.dart';
import 'expense_voucher_generator.dart';
import 'package:saksham_app/core/ui/ui.dart';

const _orange   = Color(0xFFF97316);
const _orange700 = Color(0xFFC2410C);
const _orange100 = Color(0xFFFFE8D6);
const _violet500 = Color(0xFF7C6CF0);
const _sky500 = Color(0xFF2D9CDB);
const _coral500 = Color(0xFFF2685E);
const _green500 = Color(0xFF14A98C);
const _green100 = Color(0xFFD0F2E8);
const _amber600 = Color(0xFFE0921A);
const _amber100 = Color(0xFFFFF1D6);

String _inr(int n) => '₹${NumberFormat("#,##,###","en_IN").format(n)}';
String _inrC(int n) {
  if (n >= 100000) return '₹${(n / 100000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}L';
  if (n >= 1000) return '₹${(n / 1000).round()}K';
  return '₹$n';
}

const _categoryInfo = {
  'Salaries':           (_violet500, Icons.badge_outlined),
  'Utilities':          (_amber600,  Icons.bolt_outlined),
  'Maintenance':        (_sky500,    Icons.build_outlined),
  'Program & Welfare':  (_orange,    Icons.favorite_outline),
  'Administrative':     (_coral500, Icons.folder_outlined),
  'Transport':          (Color(0xFF5BAE8A), Icons.local_shipping_outlined),
  'Miscellaneous':      (Color(0xFF93A29F), Icons.more_horiz),
};

const _modeLabels = {
  'CASH': 'Cash', 'UPI': 'UPI', 'BANK_TRANSFER': 'Bank Transfer', 'CHEQUE': 'Cheque', 'CARD': 'Card',
};

// In-memory store: survives navigation, cleared on hot-restart
final demoLocalExpenses = <Map<String, dynamic>>[];

class _Expense {
  _Expense({required this.id, required this.paidTo, required this.purpose, required this.amount,
    required this.category, required this.method, required this.voucherNo, required this.date,
    required this.status, this.preparedBy = '', this.approvedBy = '', this.receivedBy = '', this.reference = '', this.notes = '',
    this.when, this.entryDate = ''});
  final String id, paidTo, purpose, category, method, voucherNo, date, status;
  final int amount;
  final String preparedBy, approvedBy, receivedBy, reference, notes;
  // Parsed local timestamp — the report's calendar-period filters need the
  // real date, not the display string.
  final DateTime? when;
  // When the voucher was ENTERED (createdAt) — shown on the list card; `date`
  // stays the actual expense date and prints on the voucher/report.
  final String entryDate;

  factory _Expense.fromApi(Map<String, dynamic> j) {
    final category = j['category'] as Map<String, dynamic>?;
    final rawDate = j['date'] as String? ?? '';
    String formattedDate = rawDate;
    DateTime? when;
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    try {
      final dt = DateTime.parse(rawDate).toLocal();
      when = dt;
      formattedDate = '${dt.day.toString().padLeft(2,'0')} ${m[dt.month-1]} ${dt.year}';
    } catch (_) {}
    String formattedEntry = '';
    try {
      final dt = DateTime.parse(j['createdAt'] as String? ?? '').toLocal();
      formattedEntry = '${dt.day.toString().padLeft(2,'0')} ${m[dt.month-1]} ${dt.year}';
    } catch (_) {}
    final rawMode = j['paymentMode'] as String? ?? 'CASH';
    final rawStatus = j['status'] as String? ?? 'COMPLETED';
    return _Expense(
      id:       j['id']       as String? ?? '',
      paidTo:   j['paidTo']   as String? ?? 'Unknown',
      purpose:  j['purpose']  as String? ?? '',
      amount:   j['amount']   as int?    ?? 0,
      category: category?['label'] as String? ?? 'Miscellaneous',
      method:   _modeLabels[rawMode] ?? rawMode,
      voucherNo: j['voucherNo'] as String? ?? '',
      date:     formattedDate,
      status:   rawStatus == 'COMPLETED' ? 'Paid' : rawStatus,
      preparedBy: j['preparedBy'] as String? ?? '',
      approvedBy: j['approvedBy'] as String? ?? '',
      receivedBy: j['receivedBy'] as String? ?? '',
      reference:  j['reference'] as String? ?? '',
      notes:      j['notes'] as String? ?? '',
      when:       when,
      entryDate:  formattedEntry,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});
  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  String _filter = 'All';
  List<_Expense> _expenses = [];
  bool _loading = true;
  String? _error;
  // Backend category labels — categories are user-creatable, so the chip row
  // can't be limited to the hardcoded _categoryInfo keys.
  List<String> _backendCategories = [];

  @override
  void initState() {
    super.initState();
    _load();
    _loadCategories();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      // Paged to the end — a single page capped the list at 50 and made older
      // vouchers look deleted.
      final list = <dynamic>[];
      for (int page = 1; ; page++) {
        final r = await apiClient.get('/expenses', params: {'limit': '100', 'page': '$page'});
        final pageInner = r['data'];
        final pageList = pageInner is Map
            ? (pageInner['data'] as List<dynamic>? ?? [])
            : (pageInner is List ? pageInner : <dynamic>[]);
        list.addAll(pageList);
        final meta = (r['meta'] as Map?) ?? (pageInner is Map ? pageInner['meta'] as Map? : null);
        if (meta?['hasNext'] != true || pageList.isEmpty) break;
      }
      final apiExpenses = list.map((j) => _Expense.fromApi(j as Map<String, dynamic>)).toList();
      // The logged-in user's own submissions awaiting approval — shown at the
      // top with a "Pending Approval" badge (excluded from the totals).
      final pending = await _loadMyPending();
      final localExpenses = demoLocalExpenses.map(_Expense.fromApi).toList();
      final seenVouchers = apiExpenses.map((e) => e.voucherNo.toLowerCase().trim()).toSet();
      final uniqueLocal = localExpenses.where((e) => !seenVouchers.contains(e.voucherNo.toLowerCase().trim())).toList();
      if (mounted) {
        setState(() {
          _expenses = [...pending, ...uniqueLocal, ...apiExpenses];
          _loading = false;
        });
      }
      return;
    } catch (_) {}
    // Backend unreachable → local-only so the app still works offline.
    if (!mounted) return;
    setState(() {
      _expenses = demoLocalExpenses.map(_Expense.fromApi).toList();
      if (_expenses.isEmpty) _error = 'Could not load expenses';
      _loading = false;
    });
  }

  /// The current user's own submissions awaiting Super-Admin approval.
  /// Backend-driven (`GET /approvals/mine`) so they survive reloads and vanish
  /// once approved/rejected. Rendered with a "Pending Approval" status and
  /// excluded from the paid-out totals.
  Future<List<_Expense>> _loadMyPending() async {
    try {
      final r = await apiClient.get('/approvals/mine');
      final inner = r['data'];
      final reqs = inner is List
          ? inner
          : (inner is Map ? (inner['data'] as List<dynamic>? ?? const []) : const []);
      final expenseReqs = reqs.whereType<Map<String, dynamic>>().where((q) =>
          (q['module'] as String?)?.toLowerCase() == 'expenses' &&
          (q['action'] as String?)?.toUpperCase() == 'CREATE' &&
          (q['status'] as String?)?.toUpperCase() == 'PENDING').toList();
      if (expenseReqs.isEmpty) return const [];

      // The stored payload only has categoryId (category label isn't in the
      // request body) — resolve it to a display label.
      final categoryLabels = <String, String>{};
      try {
        final cr = await apiClient.get('/expenses/categories');
        final ci = cr['data'];
        final cl = ci is List ? ci : (ci is Map ? (ci['data'] as List<dynamic>? ?? const []) : const []);
        for (final c in cl.whereType<Map<String, dynamic>>()) {
          categoryLabels[c['id'] as String? ?? ''] = c['label'] as String? ?? '';
        }
      } catch (_) {}

      const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      return expenseReqs.map((q) {
        final payload = (q['payload'] as Map?)?.cast<String, dynamic>() ?? const {};
        final categoryId = payload['categoryId'] as String? ?? '';
        final rawMode = payload['paymentMode'] as String? ?? 'CASH';
        String date = '';
        try {
          final dt = DateTime.parse(q['createdAt'] as String? ?? '').toLocal();
          date = '${dt.day.toString().padLeft(2,'0')} ${m[dt.month-1]} ${dt.year}';
        } catch (_) {}
        return _Expense(
          id:       'pending-${q['id']}',
          paidTo:   payload['paidTo'] as String? ?? 'Unknown',
          purpose:  payload['purpose'] as String? ?? '',
          amount:   (payload['amount'] as num?)?.toInt() ?? 0,
          category: categoryLabels[categoryId] ?? 'Miscellaneous',
          method:   _modeLabels[rawMode] ?? rawMode,
          voucherNo: '',
          date:     date,
          status:   'Pending Approval',
          preparedBy: payload['preparedBy'] as String? ?? '',
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  List<String> get _categories {
    final merged = <String>{..._categoryInfo.keys, ..._backendCategories,
      // Categories present on loaded expenses always get a chip too.
      ..._expenses.map((e) => e.category).where((c) => c.isNotEmpty)};
    return ['All', ...merged.toList()..sort()];
  }

  Future<void> _loadCategories() async {
    try {
      final r = await apiClient.get('/expenses/categories');
      final inner = r['data'];
      final list = inner is List ? inner : (inner is Map ? (inner['data'] as List? ?? const []) : const []);
      if (mounted) setState(() {
        _backendCategories = list.whereType<Map>()
            .map((c) => c['label'] as String? ?? '')
            .where((l) => l.isNotEmpty).toList();
      });
    } catch (_) {}
  }

  List<_Expense> get _filtered =>
    _filter == 'All' ? _expenses : _expenses.where((e) => e.category == _filter).toList();

  // Real (recorded) expenses only — pending-approval submissions are shown in
  // the list but excluded from the paid-out totals.
  List<_Expense> get _real => _expenses.where((e) => e.status != 'Pending Approval').toList();

  bool _downloadingReport = false;

  // Calendar-style month picker: year arrows + tappable month names.
  Future<DateTime?> _pickMonth(BuildContext context) {
    final now = DateTime.now();
    int year = now.year;
    const monthAbbr = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return showDialog<DateTime>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setD) => AlertDialog(
        backgroundColor: ctx.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
        title: Row(children: [
          IconButton(icon: const Icon(Icons.chevron_left_rounded, size: 26),
              onPressed: () => setD(() => year--)),
          Expanded(child: Center(child: Text('$year',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)))),
          IconButton(icon: const Icon(Icons.chevron_right_rounded, size: 26),
              onPressed: year < now.year + 1 ? () => setD(() => year++) : null),
        ]),
        content: SizedBox(
          width: 280,
          child: Wrap(spacing: 8, runSpacing: 8, children: [
            for (int m = 1; m <= 12; m++)
              GestureDetector(
                onTap: () => Navigator.pop(ctx, DateTime(year, m)),
                child: Container(
                  width: 62,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: (year == now.year && m == now.month) ? _orange.withValues(alpha: 0.12) : ctx.surface2,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: (year == now.year && m == now.month) ? _orange : ctx.border),
                  ),
                  child: Center(child: Text(monthAbbr[m - 1],
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                          color: (year == now.year && m == now.month) ? _orange : ctx.textPrimary))),
                ),
              ),
          ]),
        ),
      )),
    );
  }

  // Period chooser → calendar-based Expense Report PDF (also respects the
  // active category filter).
  Future<void> _downloadReport() async {
    if (_downloadingReport) return; // ignore repeated taps
    final period = await showAppSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(color: ctx.cardBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: const SheetHandle()),
          const SizedBox(height: 16),
          const Text('Expense Report — choose period', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 12),
          for (final p in const ['This Month', 'Last 3 Months', 'This Year', 'All Time'])
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_month_outlined, color: _orange, size: 22),
              title: Text(p, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
              trailing: const Icon(Icons.chevron_right_rounded, size: 20),
              onTap: () => Navigator.pop(ctx, p),
            ),
          // A specific calendar month by name — a backdated expense (entered
          // today, dated 13 May) belongs to May's report, so any month must
          // be reachable, not just the rolling presets above.
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_outlined, color: _orange, size: 22),
            title: const Text('Choose Month…', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
            subtitle: Text('Pick any month by name, e.g. May 2026',
                style: TextStyle(fontSize: 11.5, color: ctx.textHint, fontWeight: FontWeight.w500)),
            trailing: const Icon(Icons.chevron_right_rounded, size: 20),
            onTap: () async {
              final picked = await _pickMonth(ctx);
              if (picked != null && ctx.mounted) {
                Navigator.pop(ctx, 'month:${picked.year}-${picked.month}');
              }
            },
          ),
        ]),
      ),
    );
    if (period == null || !mounted) return;

    // 'month:YYYY-M' → that exact calendar month.
    DateTime? pickedMonth;
    if (period.startsWith('month:')) {
      final parts = period.substring(6).split('-');
      pickedMonth = DateTime(int.parse(parts[0]), int.parse(parts[1]));
    }

    setState(() => _downloadingReport = true);
    try {
      final now = DateTime.now();
      // Calendar boundaries, not rolling windows. Matching is on the EXPENSE
      // date (the one entered in the form), so backdated entries land in
      // their own month.
      bool inPeriod(DateTime? dt) {
        if (pickedMonth != null) {
          return dt != null && dt.year == pickedMonth.year && dt.month == pickedMonth.month;
        }
        if (dt == null) return period == 'All Time';
        switch (period) {
          case 'This Month':
            return dt.year == now.year && dt.month == now.month;
          case 'Last 3 Months':
            return !dt.isBefore(DateTime(now.year, now.month - 2, 1));
          case 'This Year':
            return dt.year == now.year;
          default:
            return true;
        }
      }

      const monthNames = ['January','February','March','April','May','June','July',
        'August','September','October','November','December'];
      String periodLabel;
      if (pickedMonth != null) {
        periodLabel = '${monthNames[pickedMonth.month - 1]} ${pickedMonth.year}';
      } else
      switch (period) {
        case 'This Month':
          periodLabel = '${monthNames[now.month - 1]} ${now.year}';
        case 'Last 3 Months':
          final start = DateTime(now.year, now.month - 2, 1);
          // "to", not an en dash — the PDF's Helvetica drops U+2013 silently.
          periodLabel = '${monthNames[start.month - 1]} ${start.year} to ${monthNames[now.month - 1]} ${now.year}';
        case 'This Year':
          periodLabel = 'Year ${now.year}';
        default:
          periodLabel = 'All recorded expenses';
      }

      // Fetch the full history (the screen only holds the newest 50) — fall
      // back to the on-screen list if the fetch fails.
      var all = _real;
      try {
        final fetched = <_Expense>[];
        for (int page = 1; ; page++) {
          final r = await apiClient.get('/expenses', params: {'limit': '100', 'page': '$page'});
          final inner = r['data'];
          final list = inner is Map ? (inner['data'] as List? ?? const []) : (inner is List ? inner : const []);
          fetched.addAll(list.whereType<Map>().map((m) => _Expense.fromApi(m.cast<String, dynamic>())));
          final meta = (r['meta'] as Map?) ?? (inner is Map ? inner['meta'] as Map? : null);
          // `list.isEmpty` also breaks: a meta that always reports hasNext
          // would otherwise spin here forever with the spinner stuck on.
          if (meta?['hasNext'] != true || list.isEmpty) break;
        }
        if (fetched.isNotEmpty) all = fetched;
      } catch (_) {}

      final source = all
          .where((e) => e.status != 'Pending Approval' && inPeriod(e.when))
          .where((e) => _filter == 'All' || e.category == _filter)
          .toList();
      final rows = source.map((e) => ExpenseReportRow(
        date: e.date, voucherNo: e.voucherNo, paidTo: e.paidTo,
        category: e.category, method: e.method, amount: e.amount,
      )).toList();
      final bytes = await buildExpenseReportPdf(
        rows: rows,
        periodLabel: periodLabel,
        categoryFilter: _filter,
      );
      final dateStr = DateTime.now().toIso8601String().split('T').first.replaceAll('-', '');
      final ok = await NativeFileSaver.saveBytes('SKET_Expense_Report_$dateStr.pdf', bytes, 'application/pdf');
      if (mounted) {
        if (ok) {
          AppToast.success(context, 'Expense report downloaded', detail: periodLabel);
        } else {
          AppToast.error(context, 'Unable to save report', detail: 'Please try again.');
        }
      }
    } catch (_) {
      if (mounted) AppToast.error(context, 'Unable to generate report', detail: 'Please try again.');
    }
    if (mounted) setState(() => _downloadingReport = false);
  }

  int get _monthTotal => _real.fold(0, (s, e) => s + e.amount);
  int get _avgExpense => _real.isEmpty ? 0 : _monthTotal ~/ _real.length;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;

    return Scaffold(
      body: Column(children: [
        Container(color: context.headerBg, padding: EdgeInsets.fromLTRB(18, top + 14, 18, 14),
          child: Column(children: [
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Expenses', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                Text('${_real.length} expenses', style: TextStyle(fontSize: 13, color: context.textSub, fontWeight: FontWeight.w600)),
              ])),
              Tooltip(
                message: _downloadingReport ? 'Preparing report…' : 'Download expense report',
                child: GestureDetector(
                onTap: _downloadingReport ? null : _downloadReport,
                child: Container(width: 44, height: 44, margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: context.border)),
                  child: _downloadingReport
                    ? const Center(child: AppSpinner(size: 18, color: _orange))
                    : const Icon(Icons.download_outlined, color: _orange, size: 22))),
              ),
              GestureDetector(
                onTap: () => context.go('/expenses/new'),
                child: Container(width: 44, height: 44, decoration: BoxDecoration(color: _orange, borderRadius: BorderRadius.circular(14)),
                  child: const Icon(Icons.add_rounded, color: Colors.white, size: 24))),
            ]),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFFC2410C), Color(0xFFF97316)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                borderRadius: BorderRadius.all(Radius.circular(20)),
                boxShadow: [BoxShadow(color: Color(0x40C2410C), blurRadius: 12, offset: Offset(0, 5))],
              ),
              child: Column(children: [
                const Row(children: [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Spent this month', style: TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w600)),
                  ]),
                ]),
                Align(alignment: Alignment.centerLeft, child: Text(_inr(_monthTotal), style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.8))),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: _SumStat('Expenses', '${_real.length}')),
                  Container(width: 1, height: 34, color: Colors.white24),
                  Expanded(child: _SumStat('Avg Expense', _inrC(_avgExpense))),
                ]),
              ]),
            ),
            const SizedBox(height: 12),
            SizedBox(height: 36, child: ListView(scrollDirection: Axis.horizontal,
              children: _categories.map((t) {
                final active = _filter == t;
                final info = _categoryInfo[t];
                final color = info?.$1 ?? _orange;
                return Padding(padding: const EdgeInsets.only(right: 8), child: GestureDetector(
                  onTap: () => setState(() => _filter = t),
                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(color: active ? color.withValues(alpha: 0.12) : context.cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: active ? color : context.border)),
                    child: Row(children: [
                      if (info != null) ...[Icon(info.$2, size: 13, color: active ? color : context.textHint), const SizedBox(width: 5)],
                      Text(t, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: active ? color : context.textSub)),
                    ]))));
              }).toList())),
          ])),

        Expanded(child: _buildBody()),
      ]),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/expenses/new'),
        backgroundColor: _orange,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Expense', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildBody() {
    // First load: skeleton rows. Pull-to-refresh keeps the list on screen
    // with a thin progress bar — no layout jump.
    if (_loading && _expenses.isEmpty) {
      return const SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(4, 10, 4, 0),
        child: SkeletonList(rows: 6, rowHeight: 72),
      );
    }
    if (_error != null) {
      return ListView(children: [
        ErrorState(message: 'Could not load expenses. Check your connection and try again.', onRetry: _load),
      ]);
    }
    final items = _filtered;
    final Widget list = items.isEmpty
        ? ListView(physics: const AlwaysScrollableScrollPhysics(), children: [
            _filter != 'All'
                ? const EmptyState(
                    icon: Icons.filter_alt_off_outlined,
                    title: 'No expenses in this category',
                    message: 'Choose another category or All.',
                  )
                : EmptyState(
                    icon: Icons.receipt_long_outlined,
                    title: 'No expenses yet',
                    message: 'Recorded expenses will appear here.',
                    actionLabel: 'Add Expense',
                    onAction: () => context.go('/expenses/new'),
                  ),
          ])
        : ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 100),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _ExpenseCard(e: items[i]),
          );
    return Stack(children: [
      RefreshIndicator(onRefresh: _load, color: _orange, child: list),
      if (_loading)
        const Positioned(top: 0, left: 0, right: 0,
          child: LinearProgressIndicator(minHeight: 2, color: _orange, backgroundColor: Colors.transparent)),
    ]);
  }
}

class _SumStat extends StatelessWidget {
  const _SumStat(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Column(children: [
    Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
    Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
  ]);
}

class _ExpenseCard extends StatelessWidget {
  const _ExpenseCard({required this.e});
  final _Expense e;

  @override
  Widget build(BuildContext context) {
    final info = _categoryInfo[e.category];
    final catColor = info?.$1 ?? _orange;
    final catIcon = info?.$2 ?? Icons.receipt_long_outlined;

    return Container(
      decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: context.border),
        boxShadow: const [BoxShadow(color: Color(0x080D2822), blurRadius: 6, offset: Offset(0, 2))]),
      child: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(14, 12, 14, 10), child: Row(children: [
          Container(width: 42, height: 42, decoration: BoxDecoration(color: catColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(catIcon, color: catColor, size: 20)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(e.paidTo, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, height: 1, color: context.textPrimary)),
            const SizedBox(height: 4),
            Row(children: [
              Flexible(child: Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: catColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                child: Text(e.category, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: catColor), overflow: TextOverflow.ellipsis))),
              const SizedBox(width: 6),
              Flexible(child: Text(e.method, style: TextStyle(fontSize: 11.5, color: context.textHint, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
            ]),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(_inr(e.amount), style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: _orange700)),
            const SizedBox(height: 3),
            // The expense date entered in the Add Expense form — same date the
            // voucher prints, so the list and the voucher always agree.
            Text(e.date.isNotEmpty ? e.date : e.entryDate,
                style: TextStyle(fontSize: 11.5, color: context.textHint, fontWeight: FontWeight.w500)),
          ]),
        ])),
        Padding(padding: const EdgeInsets.fromLTRB(14, 0, 14, 10), child: Column(children: [
          _DashedDivider(borderColor: context.border),
          const SizedBox(height: 8),
          LayoutBuilder(builder: (_, constraints) {
            final narrow = constraints.maxWidth < 320;
            return Row(children: [
            if (!narrow) Expanded(child: Text(e.voucherNo, style: TextStyle(fontSize: 11.5, color: context.textHint, fontWeight: FontWeight.w600, letterSpacing: 0.2), overflow: TextOverflow.ellipsis)),
            if (!narrow) const SizedBox(width: 6),
            // Voucher button — only for recorded expenses (a pending submission
            // has no voucher number until it's approved).
            if (e.status == 'Paid') ...[
              GestureDetector(
                onTap: () => showVoucherSheet(context, ExpenseVoucher(
                  voucherNo:     e.voucherNo,
                  paidTo:        e.paidTo,
                  purpose:       e.purpose,
                  categoryLabel: e.category,
                  amount:        e.amount,
                  paymentMode:   e.method == 'Bank Transfer' ? 'BANK_TRANSFER' : e.method.toUpperCase(),
                  date:          e.date,
                  reference:     e.reference,
                  preparedBy:    e.preparedBy,
                  approvedBy:    e.approvedBy,
                  receivedBy:    e.receivedBy,
                  notes:         e.notes,
                )),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: _orange100,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: _orange.withValues(alpha: 0.25)),
                  ),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.receipt_long_outlined, size: 11, color: _orange),
                    SizedBox(width: 4),
                    Text('Voucher', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: _orange)),
                  ]),
                ),
              ),
              const SizedBox(width: 6),
            ] else
              const Spacer(),
            Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(color: e.status == 'Paid' ? _green100 : _amber100.withValues(alpha: 0.7), borderRadius: BorderRadius.circular(7)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(e.status == 'Paid' ? Icons.check_circle_outline : Icons.schedule_outlined, size: 11, color: e.status == 'Paid' ? _green500 : _amber600),
                const SizedBox(width: 4),
                Text(e.status, style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: e.status == 'Paid' ? _green500 : _amber600)),
              ])),
          ]);
          }),
        ])),
      ]),
    );
  }
}

class _DashedDivider extends StatelessWidget {
  const _DashedDivider({required this.borderColor});
  final Color borderColor;
  @override
  Widget build(BuildContext context) => CustomPaint(size: const Size(double.infinity, 1), painter: _DashPainter(borderColor: borderColor));
}

class _DashPainter extends CustomPainter {
  const _DashPainter({required this.borderColor});
  final Color borderColor;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = borderColor..strokeWidth = 1;
    double x = 0;
    while (x < size.width) { canvas.drawLine(Offset(x, 0), Offset(x + 4, 0), paint); x += 8; }
  }
  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}
