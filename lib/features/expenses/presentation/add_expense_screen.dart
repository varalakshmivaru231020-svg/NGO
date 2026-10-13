import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/auth/role_auth.dart';
import '../../settings/profile_store.dart';
import 'expenses_screen.dart' show demoLocalExpenses;
import 'expense_voucher_generator.dart';
import 'package:saksham_app/core/ui/ui.dart';

const _orange   = Color(0xFFF97316);
const _orange700 = Color(0xFFC2410C);
const _orange100 = Color(0xFFFFE8D6);
const _coral500 = Color(0xFFF2685E);

const _methods = ['Cash', 'UPI', 'Bank Transfer', 'Cheque', 'Card'];
const _methodModes = {
  'Cash': 'CASH', 'UPI': 'UPI', 'Bank Transfer': 'BANK_TRANSFER',
  'Cheque': 'CHEQUE', 'Card': 'CARD',
};

const _quickAmounts = [500, 1000, 5000, 10000];

// The current session's display name, used to pre-fill "Prepared By" — same
// expression used for the profile footer in main_shell.dart.
String _currentUserName() => isAdmin ? adminProfile.value.name : (currentLoggedInRole?.name ?? 'Staff');

// ══════════════════════════════════════════════════════════════════════
class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key, this.expenseId});
  // Set → edit an existing (already-vouchered) expense instead of adding one.
  final String? expenseId;
  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _amountCtrl = TextEditingController();
  final _paidToCtrl = TextEditingController();
  final _purposeCtrl = TextEditingController();
  final _receivedByCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  late final TextEditingController _preparedByCtrl;
  String _method = 'Cash';
  String _date = '';
  DateTime _selectedDate = DateTime.now();
  bool _saving = false;

  bool get _isEdit => widget.expenseId != null;
  // Edit mode: the voucher number already issued (it never changes on edit).
  String? _existingVoucherNo;
  bool _loadingExisting = false;

  // Loaded from API
  List<({String id, String label})> _categories = [];
  String? _categoryId;
  bool _loadingData = true;

  // Authorized approvers (active staff) — GET /users/approvers. Shown as
  // quick-pick suggestions only; the field itself is always free text so
  // approval isn't limited to a fixed/preset list of names.
  List<({String id, String name, String role})> _approvers = [];
  final _approvedByCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    _selectedDate = now;
    _date = '${now.day.toString().padLeft(2,'0')} ${months[now.month-1]} ${now.year}';
    _preparedByCtrl = TextEditingController(text: _currentUserName());
    _loadCategories();
    _loadApprovers();
    if (_isEdit) _loadExisting();
  }

  Future<void> _loadExisting() async {
    setState(() => _loadingExisting = true);
    try {
      final r = await apiClient.get('/expenses/${widget.expenseId}');
      final j = (r['data'] as Map?)?.cast<String, dynamic>() ?? r;
      if (!mounted) return;
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      final dt = DateTime.tryParse(j['date'] as String? ?? '')?.toLocal() ?? DateTime.now();
      final mode = j['paymentMode'] as String? ?? 'CASH';
      setState(() {
        _existingVoucherNo = j['voucherNo'] as String?;
        _amountCtrl.text = '${(j['amount'] as num?)?.toInt() ?? ''}';
        _paidToCtrl.text = j['paidTo'] as String? ?? '';
        _purposeCtrl.text = j['purpose'] as String? ?? '';
        _preparedByCtrl.text = j['preparedBy'] as String? ?? '';
        _approvedByCtrl.text = j['approvedBy'] as String? ?? '';
        _receivedByCtrl.text = j['receivedBy'] as String? ?? '';
        _notesCtrl.text = j['notes'] as String? ?? '';
        _method = _methodModes.entries.where((e) => e.value == mode).firstOrNull?.key ?? 'Cash';
        _categoryId = j['categoryId'] as String? ?? _categoryId;
        _selectedDate = dt;
        _date = '${dt.day.toString().padLeft(2,'0')} ${months[dt.month-1]} ${dt.year}';
        _loadingExisting = false;
      });
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, 'Could not load expense', detail: ApiClient.errorMessage(e));
      context.go('/expenses');
    }
  }

  Future<void> _loadCategories() async {
    try {
      final r = await apiClient.get('/expenses/categories');
      final inner = r['data'];
      final list = inner is List ? inner : (inner is Map ? (inner['data'] as List? ?? []) : []);
      final categories = list.whereType<Map<String, dynamic>>()
          .map((m) => (id: m['id'] as String? ?? '', label: m['label'] as String? ?? ''))
          .toList();
      if (mounted) {
        setState(() {
          _categories = categories;
          // Edit mode keeps the expense's own category.
          if (categories.isNotEmpty && _categoryId == null) _categoryId = categories.first.id;
          _loadingData = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingData = false);
    }
  }

  Future<void> _loadApprovers() async {
    try {
      final r = await apiClient.get('/users/approvers');
      final inner = r['data'];
      final list = inner is List ? inner : (inner is Map ? (inner['data'] as List? ?? []) : []);
      final approvers = list.whereType<Map<String, dynamic>>()
          .map((m) => (id: m['id'] as String? ?? '', name: m['name'] as String? ?? '', role: m['role'] as String? ?? ''))
          .toList();
      if (mounted) setState(() => _approvers = approvers);
    } catch (_) {
      // Non-fatal — Approved By falls back to a free-text field if this fails.
    }
  }

  Future<void> _addCategory() async {
    // Same request as before, run inside the dialog: "Adding…" on the button,
    // and the typed name stays if it fails.
    final created = await showDialog<({String id, String label})>(
      context: context,
      builder: (ctx) => _NewCategoryDialog(onSubmit: (label) async {
        final r = await apiClient.post('/expenses/categories', {'label': label});
        final m = (r['data'] as Map).cast<String, dynamic>();
        return (id: m['id'] as String, label: m['label'] as String);
      }),
    );
    if (created == null || !mounted) return;
    setState(() {
      _categories = [..._categories, created];
      _categoryId = created.id;
      _categoryError = null;
    });
    AppToast.success(context, 'Category added', detail: created.label);
  }

  String get _voucherPreview => _existingVoucherNo ?? 'EXP/${DateTime.now().year}/${(DateTime.now().millisecondsSinceEpoch % 9999 + 1000)}';

  void _pickAmount(int amount) {
    _amountCtrl.text = amount.toString();
  }

  void _pickDate() async {
    final d = await showDatePicker(
      context: context, initialDate: _selectedDate,
      firstDate: DateTime(2020), lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: _orange)), child: child!),
    );
    if (d != null) setState(() {
      _selectedDate = d;
      _date = '${d.day.toString().padLeft(2, '0')} ${['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][d.month - 1]} ${d.year}';
    });
  }

  // Field-level validation messages, shown under the relevant field.
  String? _amountError, _paidToError, _purposeError, _categoryError;

  void _save() async {
    if (_saving) return; // ignore repeated taps while a save is in flight
    final parsed = int.tryParse(_amountCtrl.text.trim());
    setState(() {
      _amountError = (parsed == null || parsed <= 0) ? 'Please enter a valid amount.' : null;
      _paidToError = _paidToCtrl.text.trim().isEmpty ? 'Please enter who this was paid to.' : null;
      _purposeError = _purposeCtrl.text.trim().isEmpty ? 'Please describe what this expense was for.' : null;
      _categoryError = _categoryId == null ? 'Please select a category.' : null;
    });
    if (_amountError != null || _paidToError != null || _purposeError != null || _categoryError != null) {
      _snack('Please check the highlighted fields', isError: true);
      return;
    }
    final int amount = parsed!; // validated above

    setState(() => _saving = true);

    if (_isEdit) {
      await _update(amount);
      return;
    }

    final categoryLabel = _categories.where((c) => c.id == _categoryId).firstOrNull?.label ?? 'Miscellaneous';
    String voucherNo = _voucherPreview;
    bool backendOk = false;
    try {
      final resp = await apiClient.post('/expenses', {
        'categoryId': _categoryId,
        'paidTo': _paidToCtrl.text.trim(),
        'purpose': _purposeCtrl.text.trim(),
        'amount': amount,
        'paymentMode': _methodModes[_method] ?? 'CASH',
        'date': _selectedDate.toIso8601String(),
        'preparedBy': _preparedByCtrl.text.trim(),
        if (_approvedByCtrl.text.trim().isNotEmpty) 'approvedBy': _approvedByCtrl.text.trim(),
        if (_receivedByCtrl.text.trim().isNotEmpty) 'receivedBy': _receivedByCtrl.text.trim(),
        if (_notesCtrl.text.trim().isNotEmpty) 'notes': _notesCtrl.text.trim(),
      });
      // Non-Super-Admins: queued for approval — no voucher, nothing recorded yet.
      if ((resp['meta'] as Map?)?['pendingApproval'] == true) {
        if (mounted) {
          setState(() => _saving = false);
          AppToast.warning(context, 'Submitted for approval', detail: 'A Super Admin will review this expense.');
          context.go('/expenses');
        }
        return;
      }
      final data = resp['data'] as Map<String, dynamic>? ?? {};
      voucherNo = data['voucherNo'] as String? ?? voucherNo;
      backendOk = true;
    } catch (e) {
      // Server answered and rejected — don't fabricate a voucher for an
      // expense that was never recorded.
      if (e is DioException && e.response != null) {
        if (mounted) {
          setState(() => _saving = false);
          _snack('Unable to save expense', isError: true,
              detail: ApiClient.errorMessage(e, fallback: 'Please try again.'));
        }
        return;
      }
      // Backend unreachable — offline/demo fallback below.
    }

    if (!mounted) return;
    final voucher = ExpenseVoucher(
      voucherNo:     voucherNo,
      paidTo:        _paidToCtrl.text.trim(),
      purpose:       _purposeCtrl.text.trim(),
      categoryLabel: categoryLabel,
      amount:        amount,
      paymentMode:   _methodModes[_method] ?? 'CASH',
      date:          _date,
      preparedBy:    _preparedByCtrl.text.trim(),
      approvedBy:    _approvedByCtrl.text.trim().isNotEmpty ? _approvedByCtrl.text.trim() : _currentUserName(),
      receivedBy:    _receivedByCtrl.text.trim(),
      notes:         _notesCtrl.text.trim(),
    );
    // Persist locally so list shows it immediately
    if (!backendOk) {
      demoLocalExpenses.insert(0, {
        'id': 'local_${voucherNo.hashCode}',
        'paidTo': _paidToCtrl.text.trim(),
        'purpose': _purposeCtrl.text.trim(),
        'amount': amount,
        'category': {'label': categoryLabel},
        'paymentMode': _methodModes[_method] ?? 'CASH',
        'voucherNo': voucherNo,
        'date': _date,
        'status': 'COMPLETED',
        'preparedBy': _preparedByCtrl.text.trim(),
        'approvedBy': voucher.approvedBy,
        'receivedBy': _receivedByCtrl.text.trim(),
        'notes': _notesCtrl.text.trim(),
      });
    }
    if (backendOk) AppToast.success(context, 'Expense recorded', detail: voucherNo);
    await showVoucherSheet(context, voucher);
    if (mounted) context.go('/expenses');
  }

  // Edit mode save — PUT the corrected fields. Blank optional fields are sent
  // as '' so a correction can also clear them.
  Future<void> _update(int amount) async {
    try {
      final resp = await apiClient.put('/expenses/${widget.expenseId}', {
        'categoryId': _categoryId,
        'paidTo': _paidToCtrl.text.trim(),
        'purpose': _purposeCtrl.text.trim(),
        'amount': amount,
        'paymentMode': _methodModes[_method] ?? 'CASH',
        'date': _selectedDate.toIso8601String(),
        'preparedBy': _preparedByCtrl.text.trim(),
        'approvedBy': _approvedByCtrl.text.trim(),
        'receivedBy': _receivedByCtrl.text.trim(),
        'notes': _notesCtrl.text.trim(),
      });
      if (!mounted) return;
      if ((resp['meta'] as Map?)?['pendingApproval'] == true) {
        AppToast.warning(context, 'Submitted for approval', detail: 'A Super Admin will review this change.');
      } else {
        AppToast.success(context, 'Expense updated', detail: _existingVoucherNo);
      }
      context.go('/expenses');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack('Unable to update expense', isError: true,
          detail: ApiClient.errorMessage(e, fallback: 'Please try again.'));
    }
  }

  void _snack(String msg, {bool isError = false, String? detail}) {
    if (isError) {
      AppToast.error(context, msg, detail: detail);
    } else {
      AppToast.success(context, msg, detail: detail);
    }
  }

  // Small inline error line under a field.
  Widget _fieldError(String? msg) => AnimatedSize(
    duration: const Duration(milliseconds: 150),
    child: msg == null
        ? const SizedBox(width: double.infinity)
        : Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(msg, style: const TextStyle(fontSize: 12, color: _coral500, fontWeight: FontWeight.w600)),
          ),
  );

  @override
  void dispose() {
    _amountCtrl.dispose(); _paidToCtrl.dispose(); _purposeCtrl.dispose();
    _receivedByCtrl.dispose(); _notesCtrl.dispose(); _preparedByCtrl.dispose();
    _approvedByCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      body: Column(children: [
        Container(
          padding: EdgeInsets.fromLTRB(4, top + 6, 16, 10),
          decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFE5EBE9)))),
          child: Row(children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: () => context.go('/expenses'),
              padding: EdgeInsets.zero, constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 6),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_isEdit ? 'Edit Expense' : 'Add Expense', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF15211E))),
              Container(
                margin: const EdgeInsets.only(top: 3),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: _orange100, borderRadius: BorderRadius.circular(6)),
                child: Text(_voucherPreview, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _orange700, letterSpacing: 0.2)),
              ),
            ]),
          ]),
        ),

        if (_loadingExisting)
          const Expanded(child: Center(child: AppSpinner(size: 28, color: _orange)))
        else
        Expanded(child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), child: Column(children: [

            // amount entry card
            _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const _Label('Amount'),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(color: context.scaffoldBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: _amountError != null ? _coral500 : context.border, width: 1.5)),
                child: Row(children: [
                  Container(width: 44, height: 52, alignment: Alignment.center,
                    child: const Text('₹', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _orange))),
                  Expanded(child: TextField(
                    controller: _amountCtrl,
                    onChanged: (_) { if (_amountError != null) setState(() => _amountError = null); },
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: context.textPrimary),
                    decoration: InputDecoration(hintText: '0', hintStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: context.textHint), border: InputBorder.none, contentPadding: EdgeInsets.zero),
                  )),
                ]),
              ),
              _fieldError(_amountError),
              const SizedBox(height: 12),
              Row(children: _quickAmounts.map((a) {
                return Expanded(child: Padding(padding: EdgeInsets.only(right: a == _quickAmounts.last ? 0 : 8), child: GestureDetector(
                  onTap: () { _pickAmount(a); setState(() => _amountError = null); },
                  child: Container(padding: const EdgeInsets.symmetric(vertical: 7),
                    decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: context.border)),
                    child: Center(child: Text(a >= 1000 ? '₹${a ~/ 1000}K' : '₹$a', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _orange700)))),
                )));
              }).toList()),
            ])),

            const SizedBox(height: 12),

            // paid to
            _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const _Label('Paid To'),
              const SizedBox(height: 8),
              TextField(
                controller: _paidToCtrl,
                onChanged: (_) { if (_paidToError != null) setState(() => _paidToError = null); },
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.textPrimary),
                decoration: InputDecoration(
                  errorText: _paidToError,
                  hintText: 'Vendor / staff / payee name',
                  hintStyle: TextStyle(fontSize: 14, color: context.textHint, fontWeight: FontWeight.w500),
                  filled: true, fillColor: context.scaffoldBg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: context.border, width: 1.5)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: context.border, width: 1.5)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _orange, width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                ),
              ),
            ])),

            const SizedBox(height: 12),

            // being paid towards
            _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const _Label('Being Paid Towards'),
              const SizedBox(height: 8),
              TextField(
                controller: _purposeCtrl,
                maxLines: 3,
                onChanged: (_) { if (_purposeError != null) setState(() => _purposeError = null); },
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: context.textPrimary),
                decoration: InputDecoration(
                  errorText: _purposeError,
                  hintText: 'What is this payment for?',
                  hintStyle: TextStyle(fontSize: 14, color: context.textHint, fontWeight: FontWeight.w500),
                  filled: true, fillColor: context.scaffoldBg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: context.border, width: 1.5)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: context.border, width: 1.5)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _orange, width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                ),
              ),
            ])),

            const SizedBox(height: 12),

            // category
            _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const _Label('Category'),
              const SizedBox(height: 12),
              if (_loadingData)
                const Center(child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: _orange)))
              else
                Wrap(spacing: 8, runSpacing: 8, children: [
                  ..._categories.map((c) {
                    final active = _categoryId == c.id;
                    return GestureDetector(
                      onTap: () => setState(() { _categoryId = c.id; _categoryError = null; }),
                      child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(color: active ? _orange.withValues(alpha: 0.12) : context.scaffoldBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: active ? _orange : context.border)),
                        child: Text(c.label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: active ? _orange : context.textSub))),
                    );
                  }),
                  // Only the Super Admin can add a new category — a role
                  // member picks from the existing list.
                  if (isAdmin)
                    GestureDetector(
                      onTap: _addCategory,
                      child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(color: context.scaffoldBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: context.border, style: BorderStyle.solid)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.add, size: 14, color: context.textSub),
                          const SizedBox(width: 4),
                          Text('New', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: context.textSub)),
                        ])),
                    ),
                ]),
              _fieldError(_categoryError),
            ])),

            const SizedBox(height: 12),

            _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const _Label('Payment Method'),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: _methods.map((m) {
                final active = _method == m;
                return GestureDetector(
                  onTap: () => setState(() => _method = m),
                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: active ? _orange : context.scaffoldBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: active ? _orange : context.border)),
                    child: Text(m, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: active ? Colors.white : context.textSub))),
                );
              }).toList()),
            ])),

            const SizedBox(height: 12),

            // voucher no + date
            _Card(child: Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const _Label('Voucher No.'),
                const SizedBox(height: 8),
                Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(color: _orange100, borderRadius: BorderRadius.circular(12)),
                  child: Text(_voucherPreview, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _orange700, letterSpacing: 0.3))),
              ])),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const _Label('Date'),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _pickDate,
                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(color: context.scaffoldBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: context.border)),
                    child: Row(children: [
                      Expanded(child: Text(_date, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.textPrimary))),
                      Icon(Icons.calendar_today_outlined, size: 14, color: context.textHint),
                    ])),
                ),
              ])),
            ])),

            const SizedBox(height: 12),

            // prepared by / approved by / received by
            _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const _Label('Prepared / Approved / Received'),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Prepared By', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.textHint)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _preparedByCtrl,
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: context.textPrimary),
                    decoration: InputDecoration(
                      filled: true, fillColor: context.scaffoldBg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.border)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _orange)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                    ),
                  ),
                ])),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Received By', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.textHint)),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _receivedByCtrl,
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: context.textPrimary),
                    decoration: InputDecoration(
                      hintText: "Payee's name",
                      hintStyle: TextStyle(fontSize: 13, color: context.textHint, fontWeight: FontWeight.w500),
                      filled: true, fillColor: context.scaffoldBg,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.border)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.border)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _orange)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                    ),
                  ),
                ])),
              ]),
              const SizedBox(height: 14),
              Text('Approved By', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: context.textHint)),
              const SizedBox(height: 6),
              TextField(
                controller: _approvedByCtrl,
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: context.textPrimary),
                decoration: InputDecoration(
                  hintText: "Approver's name",
                  hintStyle: TextStyle(fontSize: 13, color: context.textHint, fontWeight: FontWeight.w500),
                  filled: true, fillColor: context.scaffoldBg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _orange)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                ),
              ),
              // Active staff shown only as quick-fill suggestions — tapping one
              // fills the text field above, but typing any other name is just
              // as valid. Approval is never limited to this fixed list.
              if (_approvers.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 8, children: _approvers.map((a) {
                  final active = _approvedByCtrl.text.trim() == a.name;
                  return GestureDetector(
                    onTap: () => setState(() => _approvedByCtrl.text = a.name),
                    child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: active ? _orange.withValues(alpha: 0.12) : context.scaffoldBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: active ? _orange : context.border)),
                      child: Text.rich(TextSpan(children: [
                        TextSpan(text: a.name, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: active ? _orange : context.textSub)),
                        TextSpan(text: ' (${a.role})', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: (active ? _orange : context.textSub).withValues(alpha: 0.7))),
                      ])),
                    ),
                  );
                }).toList()),
              ],
            ])),

            const SizedBox(height: 12),

            // notes
            _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const _Label('Internal Notes'),
              const SizedBox(height: 8),
              TextField(
                controller: _notesCtrl,
                maxLines: 2,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: context.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Any notes about this expense…',
                  hintStyle: TextStyle(fontSize: 14, color: context.textHint, fontWeight: FontWeight.w500),
                  filled: true, fillColor: context.scaffoldBg,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: context.border, width: 1.5)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: context.border, width: 1.5)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _orange, width: 1.5)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                ),
              ),
            ])),

            // ── Inline action buttons ──────────────────────────────
            // Right-aligned on wide screens, full-width pair on phones.
            const SizedBox(height: 20),
            Builder(builder: (context) {
              final narrow = MediaQuery.sizeOf(context).width < 600;
              final cancel = AppButton(
                label: 'Cancel', variant: AppButtonVariant.secondary, expand: narrow,
                onPressed: _saving ? null : () => context.go('/expenses'),
              );
              final save = AppButton(
                label: _isEdit ? 'Update Expense' : 'Save Expense', busyLabel: 'Saving…', icon: Icons.check_rounded,
                loading: _saving, expand: narrow, onPressed: _save,
              );
              return narrow
                  ? Row(children: [Expanded(child: cancel), const SizedBox(width: 10), Expanded(flex: 2, child: save)])
                  : Row(mainAxisAlignment: MainAxisAlignment.end, children: [cancel, const SizedBox(width: 8), save]);
            }),

          ])),
        )),
      ]),
    );
  }
}

// Compact "New Category" dialog with an in-button loading state. Closes with
// the created category, or stays open (keeping the typed name) on failure.
class _NewCategoryDialog extends StatefulWidget {
  const _NewCategoryDialog({required this.onSubmit});
  final Future<({String id, String label})> Function(String label) onSubmit;
  @override
  State<_NewCategoryDialog> createState() => _NewCategoryDialogState();
}

class _NewCategoryDialogState extends State<_NewCategoryDialog> {
  final _ctrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (_busy) return;
    final label = _ctrl.text.trim();
    if (label.isEmpty) { setState(() => _error = 'Please enter a category name.'); return; }
    setState(() { _busy = true; _error = null; });
    try {
      final created = await widget.onSubmit(label);
      if (mounted) Navigator.pop(context, created);
    } catch (_) {
      if (!mounted) return;
      setState(() => _busy = false);
      AppToast.error(context, 'Unable to add category', detail: 'Check your connection and try again.');
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    insetPadding: const EdgeInsets.all(20),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 400),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('New Category', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          TextField(
            controller: _ctrl,
            autofocus: true,
            enabled: !_busy,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) { if (_error != null) setState(() => _error = null); },
            decoration: InputDecoration(hintText: 'e.g. Fuel & Travel', errorText: _error),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 18),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            AppButton(label: 'Cancel', variant: AppButtonVariant.secondary,
                onPressed: _busy ? null : () => Navigator.pop(context)),
            const SizedBox(width: 8),
            AppButton(label: 'Add', busyLabel: 'Adding…', loading: _busy, onPressed: _submit),
          ]),
        ]),
      ),
    ),
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity, padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: context.border),
      boxShadow: const [BoxShadow(color: Color(0x080D2822), blurRadius: 6, offset: Offset(0, 2))]),
    child: child);
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: context.textHint, letterSpacing: 0.6));
}
