import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/auth/role_auth.dart';
import '../../settings/profile_store.dart';
import 'expenses_screen.dart' show demoLocalExpenses;
import 'expense_voucher_generator.dart';

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
  const AddExpenseScreen({super.key});
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
  bool _saving = false;

  // Loaded from API
  List<({String id, String label})> _categories = [];
  String? _categoryId;
  bool _loadingData = true;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    _date = '${now.day.toString().padLeft(2,'0')} ${months[now.month-1]} ${now.year}';
    _preparedByCtrl = TextEditingController(text: _currentUserName());
    _loadCategories();
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
          if (categories.isNotEmpty) _categoryId = categories.first.id;
          _loadingData = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingData = false);
    }
  }

  String get _voucherPreview => 'EXP/${DateTime.now().year}/${(DateTime.now().millisecondsSinceEpoch % 9999 + 1000)}';

  void _pickAmount(int amount) {
    _amountCtrl.text = amount.toString();
  }

  void _pickDate() async {
    final d = await showDatePicker(
      context: context, initialDate: DateTime.now(),
      firstDate: DateTime(2020), lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: _orange)), child: child!),
    );
    if (d != null) setState(() => _date = '${d.day.toString().padLeft(2, '0')} ${['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][d.month - 1]} ${d.year}');
  }

  void _save() async {
    final amountText = _amountCtrl.text.trim();
    if (amountText.isEmpty) { _snack('Please enter an amount', isError: true); return; }
    if (_paidToCtrl.text.trim().isEmpty) { _snack('Please enter who this was paid to', isError: true); return; }
    if (_purposeCtrl.text.trim().isEmpty) { _snack('Please describe what this expense was for', isError: true); return; }
    if (_categoryId == null) { _snack('Please select a category', isError: true); return; }

    setState(() => _saving = true);

    final categoryLabel = _categories.where((c) => c.id == _categoryId).firstOrNull?.label ?? 'Miscellaneous';
    String voucherNo = _voucherPreview;
    bool backendOk = false;
    try {
      final resp = await apiClient.post('/expenses', {
        'categoryId': _categoryId,
        'paidTo': _paidToCtrl.text.trim(),
        'purpose': _purposeCtrl.text.trim(),
        'amount': int.parse(amountText),
        'paymentMode': _methodModes[_method] ?? 'CASH',
        'preparedBy': _preparedByCtrl.text.trim(),
        if (_receivedByCtrl.text.trim().isNotEmpty) 'receivedBy': _receivedByCtrl.text.trim(),
        if (_notesCtrl.text.trim().isNotEmpty) 'notes': _notesCtrl.text.trim(),
      });
      // Non-Super-Admins: queued for approval — no voucher, nothing recorded yet.
      if ((resp['meta'] as Map?)?['pendingApproval'] == true) {
        if (mounted) {
          setState(() => _saving = false);
          _snack('Submitted for Super Admin approval');
          context.go('/expenses');
        }
        return;
      }
      final data = resp['data'] as Map<String, dynamic>? ?? {};
      voucherNo = data['voucherNo'] as String? ?? voucherNo;
      backendOk = true;
    } catch (_) {
      // No backend in demo mode — continue with local voucher
    }

    if (!mounted) return;
    final voucher = ExpenseVoucher(
      voucherNo:     voucherNo,
      paidTo:        _paidToCtrl.text.trim(),
      purpose:       _purposeCtrl.text.trim(),
      categoryLabel: categoryLabel,
      amount:        int.parse(amountText),
      paymentMode:   _methodModes[_method] ?? 'CASH',
      date:          _date,
      preparedBy:    _preparedByCtrl.text.trim(),
      approvedBy:    _currentUserName(),
      receivedBy:    _receivedByCtrl.text.trim(),
    );
    // Persist locally so list shows it immediately
    if (!backendOk) {
      demoLocalExpenses.insert(0, {
        'id': 'local_${voucherNo.hashCode}',
        'paidTo': _paidToCtrl.text.trim(),
        'purpose': _purposeCtrl.text.trim(),
        'amount': int.tryParse(amountText) ?? 0,
        'category': {'label': categoryLabel},
        'paymentMode': _methodModes[_method] ?? 'CASH',
        'voucherNo': voucherNo,
        'date': _date,
        'status': 'COMPLETED',
        'preparedBy': _preparedByCtrl.text.trim(),
        'approvedBy': _currentUserName(),
        'receivedBy': _receivedByCtrl.text.trim(),
      });
    }
    await showVoucherSheet(context, voucher);
    if (mounted) context.go('/expenses');
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w700)),
      backgroundColor: isError ? _coral500 : _orange,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
  }

  @override
  void dispose() {
    _amountCtrl.dispose(); _paidToCtrl.dispose(); _purposeCtrl.dispose();
    _receivedByCtrl.dispose(); _notesCtrl.dispose(); _preparedByCtrl.dispose();
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
              const Text('Add Expense', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF15211E))),
              Container(
                margin: const EdgeInsets.only(top: 3),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: _orange100, borderRadius: BorderRadius.circular(6)),
                child: Text(_voucherPreview, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _orange700, letterSpacing: 0.2)),
              ),
            ]),
          ]),
        ),

        Expanded(child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), child: Column(children: [

            // amount entry card
            _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const _Label('Amount'),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(color: context.scaffoldBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: context.border, width: 1.5)),
                child: Row(children: [
                  Container(width: 44, height: 52, alignment: Alignment.center,
                    child: const Text('₹', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _orange))),
                  Expanded(child: TextField(
                    controller: _amountCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: context.textPrimary),
                    decoration: InputDecoration(hintText: '0', hintStyle: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: context.textHint), border: InputBorder.none, contentPadding: EdgeInsets.zero),
                  )),
                ]),
              ),
              const SizedBox(height: 12),
              Row(children: _quickAmounts.map((a) {
                return Expanded(child: Padding(padding: EdgeInsets.only(right: a == _quickAmounts.last ? 0 : 8), child: GestureDetector(
                  onTap: () { _pickAmount(a); setState(() {}); },
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
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.textPrimary),
                decoration: InputDecoration(
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
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: context.textPrimary),
                decoration: InputDecoration(
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
                Wrap(spacing: 8, runSpacing: 8, children: _categories.map((c) {
                  final active = _categoryId == c.id;
                  return GestureDetector(
                    onTap: () => setState(() => _categoryId = c.id),
                    child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: active ? _orange.withValues(alpha: 0.12) : context.scaffoldBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: active ? _orange : context.border)),
                      child: Text(c.label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: active ? _orange : context.textSub))),
                  );
                }).toList()),
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

            // prepared by / received by
            _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const _Label('Prepared / Received'),
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
            const SizedBox(height: 4),
            Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () => context.go('/expenses'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF5A6B67),
                  backgroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFFD8E5E0), width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('Cancel', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              )),
              const SizedBox(width: 14),
              Expanded(flex: 2, child: ElevatedButton(
                onPressed: _saving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _orange,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _orange.withValues(alpha: 0.6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                ),
                child: _saving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                  : const Text('Save Expense', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
              )),
            ]),

          ])),
        )),
      ]),
    );
  }
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
