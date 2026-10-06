import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../donations/presentation/receipt_generator.dart' show fetchOrgSettings;
import '../staff_model.dart';
import 'staff_pdf_viewer.dart';
import 'staff_salary_pdf.dart';
import 'package:saksham_app/core/ui/ui.dart';

const _brand600 = Color(0xFFFF9933);
const _brand100 = Color(0xFFFFE8CC);
const _green    = Color(0xFF14A98C);
const _amber    = Color(0xFFE0921A);
const _danger   = Color(0xFFE5484D);

// ══════════════════════════════════════════════════════════════════════
// Staff profile → Salary & Reports. One record per month: add / edit /
// delete it, view or download that month's pay slip, or a salary statement
// for any period picked on the calendar.
// ══════════════════════════════════════════════════════════════════════
class StaffSalaryTab extends StatefulWidget {
  const StaffSalaryTab({super.key, required this.staff});
  final StaffMember staff;
  @override
  State<StaffSalaryTab> createState() => _StaffSalaryTabState();
}

class _StaffSalaryTabState extends State<StaffSalaryTab> {
  List<StaffSalary> _rows = [];
  bool _loading = true;
  String? _error;
  int _year = DateTime.now().year;
  String? _busyPdf; // salary id whose pay slip download is running
  Future<Map<String, dynamic>?>? _org; // org header for PDFs, fetched once

  StaffMember get _staff => widget.staff;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = _rows.isEmpty; _error = null; });
    try {
      final r = await apiClient.get('/staff/${_staff.id}/salaries');
      final data = r['data'];
      final rows = (data is List ? data : const []).map(StaffSalary.tryParse).whereType<StaffSalary>().toList();
      if (mounted) setState(() { _rows = rows; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _error = ApiClient.errorMessage(e, fallback: 'Could not load salary records.'); });
    }
  }

  List<int> get _years {
    final now = DateTime.now().year;
    final ys = {now, _year, ..._rows.map((r) => r.year)}.toList()..sort((a, b) => b.compareTo(a));
    return ys;
  }

  // Months shown for the selected year: every month up to now (Jan–Dec for
  // past years), plus any later month that already has a record.
  List<int> get _months {
    final now = DateTime.now();
    final last = _year < now.year ? 12 : _year == now.year ? now.month : 0;
    final recorded = _rows.where((r) => r.year == _year).map((r) => salaryMonthDate(r.month)!.month);
    return {for (var m = 1; m <= last; m++) m, ...recorded}.toList()..sort((a, b) => b.compareTo(a));
  }

  StaffSalary? _recordFor(int month) =>
      _rows.where((r) => r.month == salaryMonthKey(DateTime(_year, month))).firstOrNull;

  Future<void> _openSheet({StaffSalary? existing, String? month}) async {
    final saved = await showAppSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _SalarySheet(
        staff: _staff,
        existing: existing,
        month: month ?? existing?.month ?? _nextMonth(),
        takenMonths: _rows.map((r) => r.month).toSet()..remove(existing?.month),
      ),
    );
    if (saved == true) _load();
  }

  // First month (newest first) of the selected year without a record.
  String _nextMonth() {
    for (final m in _months) {
      if (_recordFor(m) == null) return salaryMonthKey(DateTime(_year, m));
    }
    return salaryMonthKey(DateTime(DateTime.now().year, DateTime.now().month));
  }

  Future<void> _delete(StaffSalary s) async {
    var pending = false;
    final ok = await AppConfirm.show(
      context,
      title: 'Delete ${salaryMonthLabel(s.month)} salary?',
      message: 'The salary record for ${salaryMonthLabel(s.month)} (net ${staffInr(s.net)}) will be removed. '
          'This cannot be undone.',
      onConfirm: () async {
        final res = await apiClient.delete('/staff/salaries/${s.id}');
        pending = (res?['meta'] as Map?)?['pendingApproval'] == true;
      },
      errorText: (e) => ApiClient.errorMessage(e, fallback: 'Could not delete the record.'),
    );
    if (!ok || !mounted) return;
    if (pending) {
      AppToast.warning(context, 'Submitted for Super Admin approval');
    } else {
      AppToast.success(context, 'Salary record deleted');
      _load();
    }
  }

  Future<void> _markPaid(StaffSalary s) async {
    try {
      final res = await apiClient.put('/staff/salaries/${s.id}', {
        'status': 'PAID',
        'paidOn': staffIsoDate(DateTime.now()),
      });
      if (!mounted) return;
      if ((res['meta'] as Map?)?['pendingApproval'] == true) {
        AppToast.warning(context, 'Submitted for Super Admin approval');
      } else {
        AppToast.success(context, '${salaryMonthLabel(s.month)} marked as paid');
        _load();
      }
    } catch (e) {
      if (mounted) AppToast.error(context, 'Couldn’t update', detail: ApiClient.errorMessage(e));
    }
  }

  Future<Map<String, dynamic>?> _orgSettings() => _org ??= fetchOrgSettings();

  String get _fileName => _staff.name.trim().replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
  String _payslipFile(StaffSalary s) => 'Payslip_${_fileName}_${s.month}.pdf';
  Future<Uint8List> _payslipBytes(StaffSalary s) async =>
      buildStaffPayslipPdf(staff: _staff, salary: s, org: await _orgSettings());

  void _viewPayslip(StaffSalary s) => showStaffPdfViewer(context,
      title: 'Pay slip · ${salaryMonthLabel(s.month)}', filename: _payslipFile(s), build: () => _payslipBytes(s));

  Future<void> _downloadPayslip(StaffSalary s) async {
    if (_busyPdf != null) return;
    setState(() => _busyPdf = s.id);
    await downloadStaffPdf(context, filename: _payslipFile(s), build: () => _payslipBytes(s));
    if (mounted) setState(() => _busyPdf = null);
  }

  void _openReport() => showAppSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => _ReportSheet(staff: _staff, salaries: _rows, org: _orgSettings, fileStem: _fileName),
  );

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Padding(padding: EdgeInsets.all(16), child: SkeletonList(rows: 5, rowHeight: 56));
    if (_error != null) return Center(child: Padding(padding: const EdgeInsets.all(16), child: ErrorState(message: _error!, onRetry: _load)));

    final yearRows = _rows.where((r) => r.year == _year).toList();
    final paid = yearRows.where((r) => r.isPaid).fold<int>(0, (a, r) => a + r.net);
    final pending = yearRows.where((r) => !r.isPaid).fold<int>(0, (a, r) => a + r.net);
    final allTime = _rows.where((r) => r.isPaid).fold<int>(0, (a, r) => a + r.net);
    final months = _months;

    return RefreshIndicator(
      color: _brand600,
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [Align(alignment: Alignment.topCenter, child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 880),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── toolbar: year + actions ───────────────────────────────
            Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Container(
                height: 38,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: context.border)),
                child: DropdownButtonHideUnderline(child: DropdownButton<int>(
                  value: _year,
                  borderRadius: BorderRadius.circular(10),
                  icon: Icon(Icons.expand_more_rounded, size: 18, color: context.textSub),
                  items: [for (final y in _years) DropdownMenuItem(value: y, child: Text('Year $y',
                      style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: context.textPrimary)))],
                  onChanged: (y) { if (y != null) setState(() => _year = y); },
                )),
              ),
              AppButton(label: 'Salary report', icon: Icons.date_range_outlined, variant: AppButtonVariant.secondary,
                  onPressed: _openReport),
              AppButton(label: 'Add month’s salary', icon: Icons.add, onPressed: () => _openSheet()),
            ]),
            const SizedBox(height: 12),

            // ── year summary ─────────────────────────────────────────
            _Card(child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
              child: Row(children: [
                _Stat(value: staffInr(paid), label: 'Paid in $_year', color: _green),
                _vDiv(context),
                _Stat(value: staffInr(pending), label: 'Pending', color: _amber),
                _vDiv(context),
                _Stat(value: '${yearRows.length}/12', label: 'Months recorded', color: context.textPrimary),
                _vDiv(context),
                _Stat(value: staffInr(allTime), label: 'All-time paid', color: _brand600),
              ]),
            )),
            const SizedBox(height: 12),

            if (_staff.gross == 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text('Tip: set Basic / HRA / Allowances in Edit profile and every new month will be pre-filled.',
                    style: TextStyle(fontSize: 12.5, color: context.textHint)),
              ),

            // ── months ───────────────────────────────────────────────
            _Card(child: months.isEmpty
                ? EmptyState(icon: Icons.event_note_outlined, title: 'Nothing to show for $_year',
                    message: 'This year hasn’t started yet.')
                : Column(children: [
                    for (var i = 0; i < months.length; i++)
                      _MonthRow(
                        month: DateTime(_year, months[i]),
                        record: _recordFor(months[i]),
                        last: i == months.length - 1,
                        pdfBusy: _busyPdf != null && _busyPdf == _recordFor(months[i])?.id,
                        onAdd: () => _openSheet(month: salaryMonthKey(DateTime(_year, months[i]))),
                        onEdit: (s) => _openSheet(existing: s),
                        onView: _viewPayslip,
                        onDownload: _downloadPayslip,
                        onMarkPaid: _markPaid,
                        onDelete: _delete,
                      ),
                  ])),
          ]),
        ))],
      ),
    );
  }
}

// ── one month row ─────────────────────────────────────────────────────
class _MonthRow extends StatelessWidget {
  const _MonthRow({required this.month, required this.record, required this.last, required this.pdfBusy,
    required this.onAdd, required this.onEdit, required this.onView, required this.onDownload,
    required this.onMarkPaid, required this.onDelete});
  final DateTime month;
  final StaffSalary? record;
  final bool last, pdfBusy;
  final VoidCallback onAdd;
  final ValueChanged<StaffSalary> onEdit, onView, onDownload, onMarkPaid, onDelete;

  @override
  Widget build(BuildContext context) {
    final s = record;
    final title = DateFormat('MMMM yyyy').format(month);
    return Container(
      constraints: const BoxConstraints(minHeight: 60),
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: BoxDecoration(border: last ? null : Border(bottom: BorderSide(color: context.border.withValues(alpha: 0.7)))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: s == null ? context.surface2 : (s.isPaid ? _green : _amber).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(child: Text(DateFormat('MMM').format(month).toUpperCase(), style: TextStyle(
              fontSize: 11.5, fontWeight: FontWeight.w800,
              color: s == null ? context.textHint : (s.isPaid ? _green : _amber)))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Flexible(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.textPrimary))),
            if (s != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: (s.isPaid ? _green : _amber).withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                child: Text(s.isPaid ? 'Paid' : 'Pending',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: s.isPaid ? _green : _amber)),
              ),
            ],
          ]),
          const SizedBox(height: 3),
          Text(
            s == null
                ? 'Not recorded'
                : 'Gross ${staffInr(s.gross)}  ·  Deductions ${staffInr(s.deductions)}'
                  '${s.isPaid && s.paidOn != null ? '  ·  Paid ${staffDate(s.paidOn)}' : ''}',
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: context.textHint),
          ),
        ])),
        const SizedBox(width: 8),
        if (s == null)
          AppButton(label: 'Add', icon: Icons.add, dense: true, variant: AppButtonVariant.secondary, onPressed: onAdd)
        else ...[
          Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisSize: MainAxisSize.min, children: [
            Text(staffInr(s.net), style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: context.textPrimary)),
            Text('net pay', style: TextStyle(fontSize: 11, color: context.textHint)),
          ]),
          const SizedBox(width: 4),
          PopupMenuButton<String>(
            tooltip: 'More actions',
            icon: Icon(Icons.more_horiz_rounded, size: 20, color: context.textSub),
            position: PopupMenuPosition.under,
            onSelected: (v) {
              if (v == 'edit') onEdit(s);
              if (v == 'paid') onMarkPaid(s);
              if (v == 'delete') onDelete(s);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'edit', height: 36, child: Text('Edit', style: TextStyle(fontSize: 13.5))),
              if (!s.isPaid)
                const PopupMenuItem(value: 'paid', height: 36, child: Text('Mark as paid today', style: TextStyle(fontSize: 13.5))),
              const PopupMenuDivider(height: 8),
              const PopupMenuItem(value: 'delete', height: 36,
                  child: Text('Delete', style: TextStyle(fontSize: 13.5, color: _danger))),
            ],
          ),
        ],
      ]),
        if (s != null)
          Padding(
            padding: const EdgeInsets.only(left: 52, top: 8, bottom: 2),
            child: Wrap(spacing: 8, runSpacing: 6, children: [
              AppButton(label: 'View pay slip', icon: Icons.visibility_outlined, dense: true,
                  variant: AppButtonVariant.secondary, onPressed: () => onView(s)),
              AppButton(label: 'Download pay slip', icon: Icons.download_rounded, dense: true,
                  variant: AppButtonVariant.secondary, loading: pdfBusy, busyLabel: 'Preparing…',
                  onPressed: () => onDownload(s)),
            ]),
          ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
// Salary report for a period: quick picks (this year, financial year…) or
// any range chosen on the calendar. Whole months count — 10 Jan to 5 Mar
// covers January, February and March.
// ══════════════════════════════════════════════════════════════════════
class _ReportSheet extends StatefulWidget {
  const _ReportSheet({required this.staff, required this.salaries, required this.org, required this.fileStem});
  final StaffMember staff;
  final List<StaffSalary> salaries;
  final Future<Map<String, dynamic>?> Function() org;
  final String fileStem;
  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  static const _maxMonths = 60;
  late DateTime _from, _to;
  String _preset = 'year';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _apply('year');
  }

  // Financial year (April-March) that contains [d].
  int _fyStart(DateTime d) => d.month >= 4 ? d.year : d.year - 1;

  void _apply(String preset) {
    final now = DateTime.now();
    final (from, to) = switch (preset) {
      'lastYear' => (DateTime(now.year - 1, 1), DateTime(now.year - 1, 12)),
      'fy'       => (DateTime(_fyStart(now), 4), DateTime(_fyStart(now) + 1, 3)),
      'lastFy'   => (DateTime(_fyStart(now) - 1, 4), DateTime(_fyStart(now), 3)),
      '6m'       => (DateTime(now.year, now.month - 5), DateTime(now.year, now.month)),
      _          => (DateTime(now.year, 1), DateTime(now.year, 12)),
    };
    setState(() { _preset = preset; _from = from; _to = to; });
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2015),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: DateTimeRange(start: _from, end: DateTime(_to.year, _to.month + 1, 0)),
      helpText: 'Select report period',
      saveText: 'Done',
    );
    if (range == null || !mounted) return;
    setState(() {
      _preset = 'custom';
      _from = DateTime(range.start.year, range.start.month);
      _to = DateTime(range.end.year, range.end.month);
    });
  }

  List<DateTime> get _months => salaryPeriodMonths(_from, _to);
  List<StaffSalary> get _recorded {
    final keys = _months.map(salaryMonthKey).toSet();
    return widget.salaries.where((s) => keys.contains(s.month)).toList();
  }

  String get _title => salaryPeriodTitle(_from, _to);
  String get _filename => 'Salary_Statement_${widget.fileStem}_${_title.replaceAll(' ', '_')}.pdf';
  Future<Uint8List> _build() async => buildStaffSalaryStatementPdf(
      staff: widget.staff, from: _from, to: _to, salaries: widget.salaries, org: await widget.org());

  Future<void> _download() async {
    setState(() => _saving = true);
    await downloadStaffPdf(context, filename: _filename, build: _build);
    if (mounted) setState(() => _saving = false);
  }

  Widget _chip(String key, String label) {
    final on = _preset == key;
    return InkWell(
      onTap: key == 'custom' ? _pickRange : () => _apply(key),
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: on ? _brand100 : context.surface2,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: on ? _brand600.withValues(alpha: 0.6) : context.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (key == 'custom') ...[
            Icon(Icons.calendar_month_outlined, size: 15, color: on ? _brand600 : context.textSub),
            const SizedBox(width: 5),
          ],
          Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: on ? _brand600 : context.textSub)),
        ]),
      ),
    );
  }

  Widget _dateBox(String label, DateTime d) => Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: context.textSub)),
    const SizedBox(height: 6),
    InkWell(
      onTap: _pickRange,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        height: 42, padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: context.border)),
        child: Row(children: [
          Expanded(child: Text(DateFormat('MMMM yyyy').format(d),
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.textPrimary))),
          Icon(Icons.calendar_today_outlined, size: 16, color: context.textHint),
        ]),
      ),
    ),
  ]));

  @override
  Widget build(BuildContext context) {
    final months = _months;
    final recorded = _recorded;
    final net = recorded.fold<int>(0, (a, s) => a + s.net);
    final paid = recorded.where((s) => s.isPaid).fold<int>(0, (a, s) => a + s.net);
    final tooLong = months.length > _maxMonths;
    final canBuild = !tooLong && recorded.isNotEmpty;

    return Container(
      decoration: BoxDecoration(color: context.cardBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SheetHandle(margin: EdgeInsets.only(bottom: 10)),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Salary report', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(widget.staff.name, style: TextStyle(fontSize: 12.5, color: context.textSub)),
          ])),
          IconButton(tooltip: 'Close', icon: Icon(Icons.close_rounded, size: 20, color: context.textSub),
              onPressed: () => Navigator.of(context).pop()),
        ]),
        const SizedBox(height: 12),
        Wrap(spacing: 6, runSpacing: 6, children: [
          _chip('year', 'This year'),
          _chip('lastYear', 'Last year'),
          _chip('fy', 'This financial year'),
          _chip('lastFy', 'Last financial year'),
          _chip('6m', 'Last 6 months'),
          _chip('custom', 'Pick on calendar'),
        ]),
        const SizedBox(height: 14),
        Row(children: [_dateBox('From', _from), const SizedBox(width: 10), _dateBox('To', _to)]),
        const SizedBox(height: 6),
        Text('Whole months are included. Tap a date to choose the period on the calendar.',
            style: TextStyle(fontSize: 11.5, color: context.textHint)),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: _brand100.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(10)),
          child: tooLong
              ? const Text('Pick ${_maxMonths ~/ 12} years or less.',
                  style: TextStyle(fontSize: 12.5, color: _danger, fontWeight: FontWeight.w600))
              : recorded.isEmpty
                  ? Text('No salary recorded in this period.',
                      style: TextStyle(fontSize: 12.5, color: context.textSub, fontWeight: FontWeight.w600))
                  : Text('${recorded.length} of ${months.length} months recorded  ·  Net ${staffInr(net)}  ·  Paid ${staffInr(paid)}',
                      style: TextStyle(fontSize: 12.5, color: context.textPrimary, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          AppButton(label: 'View', icon: Icons.visibility_outlined, variant: AppButtonVariant.secondary,
              onPressed: canBuild && !_saving
                  ? () => showStaffPdfViewer(context, title: 'Salary statement · $_title',
                      filename: _filename, build: _build)
                  : null),
          const SizedBox(width: 8),
          AppButton(label: 'Download', icon: Icons.download_rounded, busyLabel: 'Preparing…', loading: _saving,
              onPressed: canBuild ? _download : null),
        ]),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
// Add / edit one month's salary. A new month is pre-filled from the staff
// member's salary structure (and 12% PF of basic when PF applies).
// ══════════════════════════════════════════════════════════════════════
class _SalarySheet extends StatefulWidget {
  const _SalarySheet({required this.staff, required this.existing, required this.month, required this.takenMonths});
  final StaffMember staff;
  final StaffSalary? existing;
  final String month;
  final Set<String> takenMonths;
  @override
  State<_SalarySheet> createState() => _SalarySheetState();
}

class _SalarySheetState extends State<_SalarySheet> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _basic, _hra, _allowances, _overtime, _bonus, _leaveDed, _pf, _advance, _other,
      _workingDays, _leaveDays, _notes;
  late int _year, _monthNo;
  late bool _holidays;
  late String _status;
  String _mode = 'BANK_TRANSFER';
  DateTime? _paidOn;
  bool _pfTouched = false;
  bool _busy = false;
  String? _error;

  bool get _isEditing => widget.existing != null;
  String get _monthKey => salaryMonthKey(DateTime(_year, _monthNo));

  TextEditingController _c(int v) => TextEditingController(text: v == 0 ? '' : '$v');

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    final st = widget.staff;
    final d = salaryMonthDate(widget.month) ?? DateTime.now();
    _year = d.year;
    _monthNo = d.month;
    _basic      = _c(e?.basic ?? st.basicSalary);
    _hra        = _c(e?.hra ?? st.hra);
    _allowances = _c(e?.allowances ?? st.allowances);
    _overtime   = _c(e?.overtime ?? 0);
    _bonus      = _c(e?.bonus ?? 0);
    _leaveDed   = _c(e?.leaveDeduction ?? 0);
    _pf         = _c(e?.pf ?? (st.pfApplicable ? (st.basicSalary * 0.12).round() : 0));
    _advance    = _c(e?.advance ?? 0);
    _other      = _c(e?.otherDeduction ?? 0);
    _workingDays = TextEditingController(text: e?.workingDays?.toString() ?? '');
    _leaveDays  = TextEditingController(text: e == null || e.leaveDays == 0 ? '' : e.leaveDaysLabel);
    _notes      = TextEditingController(text: e?.notes ?? '');
    _holidays   = e?.workedOnHolidays ?? false;
    _status     = e?.status ?? 'PENDING';
    _paidOn     = e?.paidOn;
    if (e != null && e.paymentMode.isNotEmpty) _mode = e.paymentMode;
    _pfTouched  = e != null;

    for (final c in [_basic, _hra, _allowances, _overtime, _bonus, _leaveDed, _pf, _advance, _other, _workingDays, _leaveDays]) {
      c.addListener(() { if (mounted) setState(() {}); });
    }
    // PF follows basic (12%) until the user types their own PF figure.
    _basic.addListener(() {
      if (_pfTouched || !widget.staff.pfApplicable) return;
      final v = '${(_n(_basic) * 0.12).round()}';
      if (_pf.text != v) _pf.text = v == '0' ? '' : v;
    });
  }

  @override
  void dispose() {
    for (final c in [_basic, _hra, _allowances, _overtime, _bonus, _leaveDed, _pf, _advance, _other, _workingDays, _leaveDays, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  int _n(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;
  int get _gross => _n(_basic) + _n(_hra) + _n(_allowances) + _n(_overtime) + _n(_bonus);
  int get _ded => _n(_leaveDed) + _n(_pf) + _n(_advance) + _n(_other);
  double get _leave => double.tryParse(_leaveDays.text.trim()) ?? 0;

  // Suggested leave deduction: (basic + HRA + allowances) / working days × leave days.
  int? get _suggestedLeaveDed {
    final wd = _n(_workingDays);
    if (wd <= 0 || _leave <= 0) return null;
    return ((_n(_basic) + _n(_hra) + _n(_allowances)) / wd * _leave).round();
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _error = null);
    if (!_form.currentState!.validate()) return;
    if (widget.takenMonths.contains(_monthKey)) {
      setState(() => _error = '${salaryMonthLabel(_monthKey)} is already recorded — edit that month instead.');
      return;
    }
    if (_ded > _gross) {
      setState(() => _error = 'Deductions (${staffInr(_ded)}) are more than the earnings (${staffInr(_gross)}).');
      return;
    }
    setState(() => _busy = true);
    final body = <String, dynamic>{
      'month': _monthKey,
      'basic': _n(_basic), 'hra': _n(_hra), 'allowances': _n(_allowances),
      'overtime': _n(_overtime), 'bonus': _n(_bonus),
      'leaveDeduction': _n(_leaveDed), 'pf': _n(_pf), 'advance': _n(_advance), 'otherDeduction': _n(_other),
      'workingDays': _workingDays.text.trim().isEmpty ? null : _n(_workingDays),
      'leaveDays': _leave,
      'workedOnHolidays': _holidays,
      'status': _status,
      'paidOn': _status == 'PAID' ? staffIsoDate(_paidOn ?? DateTime.now()) : null,
      'paymentMode': _status == 'PAID' ? _mode : null,
      'notes': _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    };
    if (!_isEditing) body.removeWhere((_, v) => v == null);
    try {
      final res = _isEditing
          ? await apiClient.put('/staff/salaries/${widget.existing!.id}', body)
          : await apiClient.post('/staff/${widget.staff.id}/salaries', body);
      if (!mounted) return;
      if ((res['meta'] as Map?)?['pendingApproval'] == true) {
        AppToast.warning(context, 'Submitted for Super Admin approval', detail: 'It will show here once approved.');
        Navigator.of(context).pop(false);
        return;
      }
      AppToast.success(context, '${salaryMonthLabel(_monthKey)} salary ${_isEditing ? 'updated' : 'saved'}',
          detail: 'Net pay ${staffInr(_gross - _ded)}');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() { _busy = false; _error = ApiClient.errorMessage(e, fallback: 'Could not save. Please try again.'); });
    }
  }

  // ── building blocks ────────────────────────────────────────────────
  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(t, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: context.textSub)),
  );

  Widget _money(String label, TextEditingController c, {ValueChanged<String>? onChanged}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label(label),
      TextFormField(
        controller: c, enabled: !_busy, onChanged: onChanged,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(8)],
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: context.textPrimary),
        decoration: const InputDecoration(hintText: '0', prefixText: '₹ '),
      ),
    ]);

  Widget _row(List<Widget> cells) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    for (var i = 0; i < cells.length; i++) ...[
      if (i > 0) const SizedBox(width: 10),
      Expanded(child: cells[i]),
    ],
  ]);

  Widget _heading(String t) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 8),
    child: Text(t.toUpperCase(), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8, color: context.textHint)),
  );

  Widget _chip(String label, bool on, VoidCallback onTap) => InkWell(
    onTap: _busy ? null : onTap,
    borderRadius: BorderRadius.circular(8),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: on ? _brand100 : context.surface2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: on ? _brand600.withValues(alpha: 0.6) : context.border),
      ),
      child: Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: on ? _brand600 : context.textSub)),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final years = [for (var y = now.year + 1; y >= now.year - 5; y--) y];
    if (!years.contains(_year)) years.add(_year);
    final suggested = _suggestedLeaveDed;

    final body = Form(
      key: _form,
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SheetHandle(margin: EdgeInsets.only(bottom: 10)),
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_isEditing ? 'Edit salary' : 'Add month’s salary', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(widget.staff.name, style: TextStyle(fontSize: 12.5, color: context.textSub)),
          ])),
          IconButton(tooltip: 'Close', icon: Icon(Icons.close_rounded, size: 20, color: context.textSub),
              onPressed: _busy ? null : () => Navigator.of(context).pop()),
        ]),
        const SizedBox(height: 10),

        // Month / year
        _row([
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _label('Month'),
            DropdownButtonFormField<int>(
              initialValue: _monthNo, isExpanded: true,
              items: [for (var m = 1; m <= 12; m++) DropdownMenuItem(value: m, child: Text(DateFormat('MMMM').format(DateTime(2000, m))))],
              onChanged: _busy ? null : (v) => setState(() => _monthNo = v ?? _monthNo),
            ),
          ]),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _label('Year'),
            DropdownButtonFormField<int>(
              initialValue: _year, isExpanded: true,
              items: [for (final y in years) DropdownMenuItem(value: y, child: Text('$y'))],
              onChanged: _busy ? null : (v) => setState(() => _year = v ?? _year),
            ),
          ]),
        ]),
        if (widget.takenMonths.contains(_monthKey))
          Padding(padding: const EdgeInsets.only(top: 6), child: Text(
              '${salaryMonthLabel(_monthKey)} is already recorded — pick another month or edit that one.',
              style: const TextStyle(fontSize: 12, color: _danger, fontWeight: FontWeight.w500))),

        _heading('Earnings'),
        _row([_money('Basic Salary', _basic), _money('HRA', _hra)]),
        const SizedBox(height: 10),
        _row([_money('Allowances', _allowances), _money('Overtime', _overtime)]),
        const SizedBox(height: 10),
        _row([_money('Bonus', _bonus), const SizedBox()]),

        _heading('Attendance'),
        _row([
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _label('Working Days'),
            TextFormField(
              controller: _workingDays, enabled: !_busy, keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(2)],
              validator: (v) => (int.tryParse(v ?? '') ?? 0) > 31 ? 'Max 31' : null,
              decoration: const InputDecoration(hintText: 'e.g. 26'),
            ),
          ]),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _label('Leave Taken (days)'),
            TextFormField(
              controller: _leaveDays, enabled: !_busy,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d{0,2}(\.\d?)?'))],
              validator: (v) => (double.tryParse(v ?? '') ?? 0) > 31 ? 'Max 31' : null,
              decoration: const InputDecoration(hintText: '0'),
            ),
          ]),
        ]),
        Row(children: [
          Expanded(child: Text('Worked on holidays', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: context.textPrimary))),
          Switch(value: _holidays, onChanged: _busy ? null : (v) => setState(() => _holidays = v)),
        ]),

        _heading('Deductions'),
        _row([_money('Leave Deduction', _leaveDed), _money('PF', _pf, onChanged: (_) => _pfTouched = true)]),
        if (suggested != null && suggested != _n(_leaveDed))
          Align(alignment: Alignment.centerLeft, child: TextButton(
            onPressed: _busy ? null : () => _leaveDed.text = '$suggested',
            style: TextButton.styleFrom(padding: EdgeInsets.zero, visualDensity: VisualDensity.compact),
            child: Text('Use ${staffInr(suggested)} for ${_leaveDays.text.trim()} day(s) leave',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _brand600)),
          )),
        const SizedBox(height: 10),
        _row([_money('Advance', _advance), _money('Other', _other)]),

        _heading('Payment'),
        Wrap(spacing: 6, runSpacing: 6, children: [
          _chip('Pending', _status == 'PENDING', () => setState(() => _status = 'PENDING')),
          _chip('Paid', _status == 'PAID', () => setState(() { _status = 'PAID'; _paidOn ??= DateTime.now(); })),
        ]),
        if (_status == 'PAID') ...[
          const SizedBox(height: 10),
          _label('Paid On'),
          InkWell(
            onTap: _busy ? null : () async {
              final d = await showDatePicker(context: context, initialDate: _paidOn ?? DateTime.now(),
                  firstDate: DateTime(2015), lastDate: DateTime.now().add(const Duration(days: 60)));
              if (d != null) setState(() => _paidOn = d);
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              height: 42, padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: context.border)),
              child: Row(children: [
                Expanded(child: Text(staffDate(_paidOn ?? DateTime.now()),
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: context.textPrimary))),
                Icon(Icons.calendar_today_outlined, size: 16, color: context.textHint),
              ]),
            ),
          ),
          const SizedBox(height: 10),
          _label('Payment Mode'),
          Wrap(spacing: 6, runSpacing: 6, children: [
            for (final m in kSalaryPaymentModes) _chip(m.label, _mode == m.key, () => setState(() => _mode = m.key)),
          ]),
        ],
        const SizedBox(height: 10),
        _label('Notes'),
        TextFormField(controller: _notes, enabled: !_busy, maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Optional')),

        // ── live total ─────────────────────────────────────────────
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: _brand100.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(10)),
          child: Row(children: [
            Expanded(child: Text('Gross ${staffInr(_gross)}  −  Deductions ${staffInr(_ded)}',
                style: TextStyle(fontSize: 12.5, color: context.textSub, fontWeight: FontWeight.w500))),
            Text('Net ${staffInr(_gross - _ded)}',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _gross - _ded < 0 ? _danger : _brand600)),
          ]),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: const TextStyle(fontSize: 12.5, color: _danger, fontWeight: FontWeight.w500)),
        ],
        const SizedBox(height: 16),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          AppButton(label: 'Cancel', variant: AppButtonVariant.secondary, onPressed: _busy ? null : () => Navigator.of(context).pop()),
          const SizedBox(width: 8),
          AppButton(label: _isEditing ? 'Save changes' : 'Save salary', icon: Icons.check_rounded,
              busyLabel: 'Saving…', loading: _busy, onPressed: _save),
        ]),
      ]),
    );

    final content = Container(
      decoration: BoxDecoration(color: context.cardBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: body,
    );
    // The desktop dialog frame already scrolls; a phone bottom sheet needs its own.
    if (isWideLayout(context)) return content;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.92),
        child: SingleChildScrollView(child: content),
      ),
    );
  }
}

// ── shared bits ───────────────────────────────────────────────────────
class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: context.border)),
    clipBehavior: Clip.antiAlias,
    child: child,
  );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, required this.color});
  final String value, label;
  final Color color;
  @override
  Widget build(BuildContext context) => Expanded(child: Column(mainAxisSize: MainAxisSize.min, children: [
    FittedBox(fit: BoxFit.scaleDown, child: Text(value,
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color, letterSpacing: -0.3, height: 1.1))),
    const SizedBox(height: 2),
    Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: context.textHint)),
  ]));
}

Widget _vDiv(BuildContext context) => SizedBox(height: 28, child: VerticalDivider(width: 1, color: context.border));
