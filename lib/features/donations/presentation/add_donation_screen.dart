import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../donors/presentation/donors_screen.dart' show demoLocalDonors;
import 'donations_screen.dart' show demoLocalDonations;
import 'receipt_generator.dart';
import 'package:saksham_app/core/ui/ui.dart';

const _brand700 = Color(0xFFE07C1F);
const _brand600 = Color(0xFFFF9933);
const _brand100 = Color(0xFFFFE8CC);
const _amber600 = Color(0xFFE0921A);
const _coral500 = Color(0xFFF2685E);
const _violet500 = Color(0xFF7C6CF0);
const _sky500 = Color(0xFF2D9CDB);
const _green500 = Color(0xFF14A98C);
const _onSurface1 = Color(0xFF15211E);
const _onSurface2 = Color(0xFF5A6B67);
const _onSurface3 = Color(0xFF93A29F);
const _border = Color(0xFFE5EBE9);
const _surface2 = Color(0xFFF4F7F6);

Color _avColor(String seed) {
  final p = [_brand600, const Color(0xFFF6A723), _violet500, _sky500, _coral500, _green500];
  int h = 0;
  for (int i = 0; i < seed.length; i++) { h = ((h * 31) + seed.codeUnitAt(i)) & 0xFFFFFFFF; }
  return p[h % p.length];
}
String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  return ((parts[0].isNotEmpty ? parts[0][0] : '') + (parts.length > 1 && parts[1].isNotEmpty ? parts[1][0] : '')).toUpperCase();
}

class _TypeInfo {
  const _TypeInfo(this.key, this.color, this.icon);
  final String key; final Color color; final IconData icon;
}

const _typeVisuals = {
  'Education Fund':    (_TypeInfo('Education Fund',    _violet500, Icons.school_outlined)),
  'Child Sponsorship': (_TypeInfo('Child Sponsorship', _brand600,  Icons.favorite_outline)),
  'Healthcare':        (_TypeInfo('Healthcare',        _coral500,  Icons.medical_services_outlined)),
  'General Donation':  (_TypeInfo('General Donation',  _sky500,    Icons.account_balance_wallet_outlined)),
  'Food & Nutrition':  (_TypeInfo('Food & Nutrition',  _amber600,  Icons.restaurant_outlined)),
};

const _methods = ['UPI', 'Bank Transfer', 'Cheque', 'Cash', 'Payment Link'];
const _methodModes = {
  'UPI': 'UPI', 'Bank Transfer': 'BANK_TRANSFER',
  'Cheque': 'CHEQUE', 'Cash': 'CASH', 'Payment Link': 'PAYMENT_LINK',
};

const _quickAmounts = [5000, 11000, 25000, 51000];

// ══════════════════════════════════════════════════════════════════════
class AddDonationScreen extends StatefulWidget {
  const AddDonationScreen({super.key, this.donationId});
  // Set → edit an existing (already-invoiced) donation instead of adding one.
  final String? donationId;
  @override
  State<AddDonationScreen> createState() => _AddDonationScreenState();
}

class _AddDonationScreenState extends State<AddDonationScreen> {
  final _amountCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  // Left blank on purpose when the transaction id isn't known yet — the
  // invoice prints a fill-in-by-hand blank line in that case.
  final _txnIdCtrl = TextEditingController();
  String? _selectedDonorId;
  String? _selectedDonorName;
  String _donationType = 'Education Fund';
  String _method = 'UPI';
  String _date = '';
  DateTime _selectedDate = DateTime.now();
  bool _saving = false;
  final List<String> _attachments = [];

  bool get _isEdit => widget.donationId != null;
  // Edit mode: the receipt number already issued (it never changes on edit),
  // and the stored payment mode when it has no chip here (e.g. CARD).
  String? _existingReceiptNo;
  String? _originalMode;
  bool _loadingExisting = false;
  bool _pickingFile = false;

  // Loaded from API
  List<({String id, String name, String city, String tier, String mobile, String email, String pan, String address, String state, String pincode, String country})> _donors = [];
  Map<String, String> _typeLabelToId = {};
  List<String> _typeLabels = [];
  bool _loadingData = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    _selectedDate = now;
    _date = '${now.day.toString().padLeft(2,'0')} ${months[now.month-1]} ${now.year}';
    // pre-populate synchronously so the form always has data even if API fails
    _donors = _fallbackDonors();
    _typeLabelToId = {for (final k in _typeVisuals.keys) k: k};
    _typeLabels = _typeVisuals.keys.toList();
    _loadFormData();
    if (_isEdit) _loadExisting();
  }

  Future<void> _loadExisting() async {
    setState(() => _loadingExisting = true);
    try {
      final r = await apiClient.get('/donations/${widget.donationId}');
      final j = (r['data'] as Map?)?.cast<String, dynamic>() ?? r;
      if (!mounted) return;
      const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      final dt = DateTime.tryParse(j['date'] as String? ?? '')?.toLocal() ?? DateTime.now();
      final donor = (j['donor'] as Map?)?.cast<String, dynamic>() ?? const {};
      final type = (j['type'] as Map?)?.cast<String, dynamic>() ?? const {};
      final mode = j['paymentMode'] as String? ?? 'CASH';
      setState(() {
        _existingReceiptNo = j['receiptNo'] as String?;
        _amountCtrl.text = '${(j['amount'] as num?)?.toInt() ?? ''}';
        _selectedDonorId = donor['id'] as String? ?? j['donorId'] as String?;
        _selectedDonorName = donor['name'] as String?;
        final typeLabel = type['label'] as String?;
        if (typeLabel != null) {
          _donationType = typeLabel;
          final typeId = type['id'] as String? ?? j['typeId'] as String?;
          if (typeId != null) _typeLabelToId[typeLabel] = typeId;
        }
        final label = _methodModes.entries.where((e) => e.value == mode).firstOrNull?.key;
        _method = label ?? _method;
        _originalMode = label == null ? mode : null;
        _txnIdCtrl.text = j['reference'] as String? ?? '';
        _descriptionCtrl.text = j['notes'] as String? ?? '';
        _selectedDate = dt;
        _date = '${dt.day.toString().padLeft(2,'0')} ${months[dt.month-1]} ${dt.year}';
        _loadingExisting = false;
      });
    } catch (e) {
      if (!mounted) return;
      AppToast.error(context, 'Could not load donation', detail: ApiClient.errorMessage(e));
      context.go('/donations');
    }
  }

  // Edit mode save — PUT the corrected fields; the receipt number is kept.
  Future<void> _update(int amount, String typeId) async {
    try {
      final resp = await apiClient.put('/donations/${widget.donationId}', {
        'donorId': _selectedDonorId,
        'typeId': typeId,
        'amount': amount,
        'paymentMode': _methodModes[_method] ?? _originalMode ?? 'CASH',
        'date': _selectedDate.toIso8601String(),
        'reference': _txnIdCtrl.text.trim(),
        'notes': _descriptionCtrl.text.trim(),
      });
      if (!mounted) return;
      if ((resp['meta'] as Map?)?['pendingApproval'] == true) {
        AppToast.warning(context, 'Submitted for approval', detail: 'A Super Admin will review this change.');
      } else {
        AppToast.success(context, 'Donation updated', detail: _existingReceiptNo);
      }
      context.go('/donations');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      _snack('Unable to update donation', isError: true,
          detail: ApiClient.errorMessage(e, fallback: 'Please try again.'));
    }
  }

  List<({String id, String name, String city, String tier, String mobile, String email, String pan, String address, String state, String pincode, String country})> _fallbackDonors() {
    // Only not-yet-synced local donors — no demo/mock donors in the picker.
    final all = [...demoLocalDonors];
    return all.map<({String id, String name, String city, String tier, String mobile, String email, String pan, String address, String state, String pincode, String country})>((d) => (
      id:     d['id']     as String? ?? '',
      name:   d['name']   as String? ?? '',
      city:   d['city']   as String? ?? '',
      tier:   d['tier']   as String? ?? 'SILVER',
      mobile: d['mobile'] as String? ?? d['phone'] as String? ?? '',
      email:  d['email']  as String? ?? '',
      pan:    d['pan']    as String? ?? '',
      address: d['address'] as String? ?? '',
      state:   d['state']   as String? ?? '',
      pincode: d['pincode'] as String? ?? '',
      country: d['country'] as String? ?? '',
    )).toList();
  }

  // Every donor, paged — the backend caps limit at 100, and a one-page fetch
  // hid donor #101+ from this picker.
  static Future<List<dynamic>> _fetchAllDonors() async {
    final all = <dynamic>[];
    for (int page = 1; ; page++) {
      final r = await apiClient.get('/donors', params: {'limit': '100', 'page': '$page'});
      final inner = r['data'];
      final list = inner is Map ? (inner['data'] as List? ?? []) : (inner as List? ?? []);
      all.addAll(list);
      final meta = (r['meta'] as Map?) ?? (inner is Map ? inner['meta'] as Map? : null);
      if (meta?['hasNext'] != true || list.isEmpty) break;
    }
    return all;
  }

  Future<void> _loadFormData() async {
    try {
      final donorsFuture = _fetchAllDonors();
      final tRes = await apiClient.get('/donations/types');

      // Parse donors
      final List<dynamic> dList = await donorsFuture;
      var donors = dList.map<({String id, String name, String city, String tier, String mobile, String email, String pan, String address, String state, String pincode, String country})>((d) {
        final m = d as Map<String, dynamic>;
        return (id: m['id'] as String? ?? '', name: m['name'] as String? ?? '', city: m['city'] as String? ?? '', tier: m['tier'] as String? ?? 'SILVER', mobile: m['mobile'] as String? ?? m['phone'] as String? ?? '', email: m['email'] as String? ?? '', pan: m['pan'] as String? ?? '', address: m['address'] as String? ?? '', state: m['state'] as String? ?? '', pincode: m['pincode'] as String? ?? '', country: m['country'] as String? ?? '');
      }).toList();

      // Always include demo/local donors
      donors = [..._fallbackDonors(), ...donors];

      // Parse donation types
      final tInner = tRes['data'];
      List<dynamic> tList = tInner is List ? tInner : (tInner is Map ? (tInner['data'] as List? ?? []) : []);
      final labelToId = <String, String>{};
      for (final t in tList) {
        final m = t as Map<String, dynamic>;
        labelToId[m['label'] as String? ?? ''] = m['id'] as String? ?? '';
      }

      if (mounted) {
        setState(() {
          _donors = donors;
          _typeLabelToId = labelToId;
          _typeLabels = labelToId.keys.toList();
          if (_typeLabels.isNotEmpty && !_typeLabels.contains(_donationType)) {
            _donationType = _typeLabels.first;
          }
          _loadingData = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _donors = _fallbackDonors();
          // keep the static fallback types already set in initState
          if (_typeLabelToId.isEmpty) {
            _typeLabelToId = {for (final k in _typeVisuals.keys) k: k};
            _typeLabels = _typeVisuals.keys.toList();
          }
          _loadingData = false;
        });
      }
    }
  }

  // late final — a getter regenerated a different number on every rebuild.
  late final String _receiptPreview = 'SF/26-27/${DateTime.now().millisecondsSinceEpoch % 10000 + 400}';
  String get _receipt => _existingReceiptNo ?? _receiptPreview;

  void _pickAmount(int amount) {
    _amountCtrl.text = amount.toString();
  }

  void _pickDate() async {
    final d = await showDatePicker(
      context: context, initialDate: _selectedDate,
      firstDate: DateTime(2020), lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: _brand600)), child: child!),
    );
    if (d != null) setState(() {
      _selectedDate = d;
      _date = '${d.day.toString().padLeft(2, '0')} ${['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][d.month - 1]} ${d.year}';
    });
  }

  Future<void> _openDonorPicker() async {
    String search = '';
    await showAppSheet(
      context: context, isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) {
        final q = search.toLowerCase();
        final filtered = q.isEmpty
          ? _donors
          : _donors.where((d) =>
              d.name.toLowerCase().contains(q) ||
              d.mobile.toLowerCase().contains(q) ||
              d.email.toLowerCase().contains(q) ||
              d.city.toLowerCase().contains(q) ||
              d.id.toLowerCase().contains(q)).toList();
        final kb = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.only(bottom: kb),
          child: Container(
          height: MediaQuery.of(context).size.height * 0.72,
          decoration: BoxDecoration(color: ctx.cardBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
          child: Column(children: [
            const SizedBox(height: 8),
            const SheetHandle(),
            Padding(padding: const EdgeInsets.fromLTRB(18, 16, 18, 0), child: Row(children: [
              Expanded(child: Text('Select Donor', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: ctx.textPrimary))),
              IconButton(icon: const Icon(Icons.close, size: 20), onPressed: () => Navigator.pop(ctx), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
            ])),
            Padding(padding: const EdgeInsets.fromLTRB(18, 10, 18, 10), child: Container(
              decoration: BoxDecoration(color: ctx.scaffoldBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: ctx.border)),
              child: TextField(
                onChanged: (v) => setSt(() => search = v),
                decoration: InputDecoration(hintText: 'Search by name, mobile, email, city, ID…', hintStyle: TextStyle(fontSize: 13, color: ctx.textHint),
                  prefixIcon: Icon(Icons.search, color: ctx.textHint, size: 20), border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 12)),
              ))),
            if (_loadingData)
              const Expanded(child: SingleChildScrollView(child: SkeletonList(rows: 6, rowHeight: 60)))
            else
              Expanded(child: filtered.isEmpty
                ? SingleChildScrollView(child: EmptyState(
                    icon: search.isEmpty ? Icons.people_outline : Icons.search_off_rounded,
                    title: search.isEmpty ? 'No donors yet' : 'No matching donors',
                    message: search.isEmpty ? 'Add a donor first, then record the donation.' : 'Try a different name, mobile or city.',
                  ))
                : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 20),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) {
                    final d = filtered[i];
                    final isSelected = _selectedDonorId == d.id;
                    final av = _avColor(d.name);
                    return GestureDetector(
                      onTap: () {
                        setState(() { _selectedDonorId = d.id; _selectedDonorName = d.name; });
                        Navigator.pop(ctx);
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                        decoration: BoxDecoration(color: isSelected ? _brand100 : ctx.cardBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: isSelected ? _brand600 : ctx.border)),
                        child: Row(children: [
                          Container(width: 40, height: 40, decoration: BoxDecoration(gradient: LinearGradient(colors: [av, Color.lerp(av, Colors.black, 0.2)!]), shape: BoxShape.circle),
                            child: Center(child: Text(_initials(d.name), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14)))),
                          const SizedBox(width: 11),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(d.name, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ctx.textPrimary)),
                            if (d.mobile.isNotEmpty || d.city.isNotEmpty)
                              Text([if (d.mobile.isNotEmpty) d.mobile, if (d.city.isNotEmpty) d.city].join(' · '), style: TextStyle(fontSize: 12, color: ctx.textSub, fontWeight: FontWeight.w500)),
                            if (d.id.isNotEmpty) Text(d.id, style: TextStyle(fontSize: 11, color: ctx.textHint, fontWeight: FontWeight.w500)),
                          ])),
                          if (isSelected) const Icon(Icons.check_circle_rounded, color: _brand600, size: 22),
                        ]),
                      ),
                    );
                  }),
              ),
          ]),
        ));
      }),
    );
  }

  // Field-level validation messages, shown under the relevant field.
  String? _amountError, _donorError, _txnError;

  void _save() async {
    if (_saving) return; // ignore repeated taps while a save is in flight
    // Parse ONCE and reuse — a later bare int.parse threw uncaught on
    // over-long input.
    final parsed = int.tryParse(_amountCtrl.text.trim());
    setState(() {
      _amountError = (parsed == null || parsed <= 0) ? 'Please enter a valid amount.' : null;
      _donorError = _selectedDonorId == null ? 'Please select a donor.' : null;
      // Every non-cash payment has a reference (UTR/UPI ref/cheque no.) —
      // require it at entry so invoices carry it. Cash stays optional.
      _txnError = (_method != 'Cash' && _txnIdCtrl.text.trim().isEmpty)
          ? 'Required for $_method payments.' : null;
    });
    if (_amountError != null || _donorError != null || _txnError != null) {
      _snack('Please check the highlighted fields', isError: true);
      return;
    }
    final int amount = parsed!; // validated above
    final typeId = _typeLabelToId[_donationType] ?? _donationType;
    setState(() => _saving = true);

    if (_isEdit) {
      await _update(amount, typeId);
      return;
    }

    String receiptNo = 'SF/26-27/${(DateTime.now().millisecondsSinceEpoch % 9999 + 1000)}';
    bool backendOk = false;
    try {
      final resp = await apiClient.post('/donations', {
        'donorId': _selectedDonorId,
        'typeId': typeId,
        'amount': amount,
        'paymentMode': _methodModes[_method] ?? 'CASH',
        'date': _selectedDate.toIso8601String(),
        if (_txnIdCtrl.text.trim().isNotEmpty) 'reference': _txnIdCtrl.text.trim(),
        if (_descriptionCtrl.text.trim().isNotEmpty) 'notes': _descriptionCtrl.text.trim(),
      });
      // Non-Super-Admins: queued for approval — no receipt, nothing recorded yet.
      if ((resp['meta'] as Map?)?['pendingApproval'] == true) {
        if (mounted) {
          setState(() => _saving = false);
          AppToast.warning(context, 'Submitted for approval', detail: 'A Super Admin will review this donation.');
          context.go('/donations');
        }
        return;
      }
      final data = resp['data'] as Map<String, dynamic>? ?? {};
      receiptNo = data['receiptNo'] as String? ?? receiptNo;
      backendOk = true;
    } catch (e) {
      // The server answered and REJECTED the save — showing a receipt here
      // would fabricate a success for a donation that was never recorded.
      if (e is DioException && e.response != null) {
        if (mounted) {
          setState(() => _saving = false);
          _snack('Unable to save donation', isError: true,
              detail: ApiClient.errorMessage(e, fallback: 'Please try again.'));
        }
        return;
      }
      // Backend unreachable — offline/demo fallback below.
    }

    if (!mounted) return;
    final selectedDonor = _donors.where((d) => d.id == _selectedDonorId).firstOrNull;
    final receipt = DonationReceipt(
      receiptNo:    receiptNo,
      donorName:    _selectedDonorName ?? 'Donor',
      donorPhone:   selectedDonor?.mobile ?? '',
      donorCity:    selectedDonor?.city ?? '',
      donorPan:     selectedDonor?.pan ?? '',
      donorEmail:   selectedDonor?.email ?? '',
      donorAddress: selectedDonor?.address ?? '',
      donorState:   selectedDonor?.state ?? '',
      donorPincode: selectedDonor?.pincode ?? '',
      donorCountry: selectedDonor?.country ?? '',
      donationType: _donationType,
      amount:       amount,
      paymentMode:  _method,
      date:         _date,
      taxExemption: true,
      reference:    _txnIdCtrl.text.trim(),
      notes:        _descriptionCtrl.text.trim(),
    );
    // Persist locally so list shows it immediately
    if (!backendOk) {
      demoLocalDonations.insert(0, {
        'id': 'local_${receiptNo.hashCode}',
        'donor': {'id': _selectedDonorId ?? '', 'name': _selectedDonorName ?? 'Donor'},
        'amount': amount,
        'type': {'label': _donationType},
        'paymentMode': _methodModes[_method] ?? 'CASH',
        'receiptNo': receiptNo,
        'date': _date,
        'status': 'COMPLETED',
        'notes': _descriptionCtrl.text.trim(),
      });
    }
    if (backendOk) AppToast.success(context, 'Donation recorded', detail: receiptNo);
    await showReceiptSheet(context, receipt);
    if (mounted) context.go('/donations');
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
  void dispose() { _amountCtrl.dispose(); _descriptionCtrl.dispose(); _txnIdCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      body: Column(children: [
        // compact white header (back + title only)
        Container(
          padding: EdgeInsets.fromLTRB(4, top + 6, 16, 10),
          decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFE5EBE9)))),
          child: Row(children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
              onPressed: () => context.go('/donations'),
              padding: EdgeInsets.zero, constraints: const BoxConstraints(),
            ),
            const SizedBox(width: 6),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_isEdit ? 'Edit Donation' : 'Add Donation', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF15211E))),
              Container(
                margin: const EdgeInsets.only(top: 3),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: _brand100, borderRadius: BorderRadius.circular(6)),
                child: Text(_receipt, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _brand700, letterSpacing: 0.2)),
              ),
            ]),
          ]),
        ),

        if (_loadingExisting)
          const Expanded(child: Center(child: AppSpinner(size: 28, color: _brand600)))
        else
        Expanded(child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Center(child: ConstrainedBox(
            constraints: const BoxConstraints(),
            child: Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 32), child: Column(children: [

              // amount entry card
              _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const _Label('Amount'),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(color: context.scaffoldBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: _amountError != null ? _coral500 : context.border, width: 1.5)),
                  child: Row(children: [
                    Container(width: 44, height: 52, alignment: Alignment.center,
                      child: const Text('₹', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: _brand600))),
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
                      child: Center(child: Text(a >= 1000 ? '₹${a ~/ 1000}K' : '₹$a', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _brand700)))),
                  )));
                }).toList()),
              ])),

              const SizedBox(height: 12),

              // donor picker
              _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const _Label('Donor'),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _openDonorPicker,
                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                    decoration: BoxDecoration(color: context.scaffoldBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: _selectedDonorId != null ? _brand600 : (_donorError != null ? _coral500 : context.border), width: 1.5)),
                    child: Row(children: [
                      if (_selectedDonorName != null) ...[
                        Container(width: 32, height: 32, decoration: BoxDecoration(gradient: LinearGradient(colors: [_avColor(_selectedDonorName!), Color.lerp(_avColor(_selectedDonorName!), Colors.black, 0.2)!]), shape: BoxShape.circle),
                          child: Center(child: Text(_initials(_selectedDonorName!), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11)))),
                        const SizedBox(width: 10),
                        Expanded(child: Text(_selectedDonorName!, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.textPrimary))),
                        const Icon(Icons.check_circle_rounded, color: _brand600, size: 18),
                      ] else ...[
                        Icon(Icons.search, color: context.textHint, size: 18),
                        const SizedBox(width: 10),
                        Expanded(child: Text('Search & select donor…', style: TextStyle(fontSize: 14, color: context.textHint, fontWeight: FontWeight.w500))),
                        Icon(Icons.chevron_right, color: context.textHint, size: 20),
                      ],
                    ])),
                ),
                if (_selectedDonorId == null) _fieldError(_donorError),
              ])),

              const SizedBox(height: 12),

              // donation type + payment method — stacked always (clean mobile-first)
              _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const _Label('Allocate towards'),
                const SizedBox(height: 12),
                if (_loadingData)
                  const Center(child: SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: _brand600)))
                else
                  Wrap(spacing: 8, runSpacing: 8, children: (_typeLabels.isNotEmpty ? _typeLabels : _typeVisuals.keys.toList()).map((label) {
                    final active = _donationType == label;
                    final info = _typeVisuals[label] ?? _TypeInfo(label, _brand600, Icons.account_balance_wallet_outlined);
                    return GestureDetector(
                      onTap: () => setState(() => _donationType = label),
                      child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(color: active ? info.color.withValues(alpha: 0.12) : context.scaffoldBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: active ? info.color : context.border)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(info.icon, size: 15, color: active ? info.color : context.textHint),
                          const SizedBox(width: 6),
                          Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: active ? info.color : context.textSub)),
                        ])),
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
                    onTap: () => setState(() { _method = m; _originalMode = null; }),
                    child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(color: active ? _brand600 : context.scaffoldBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: active ? _brand600 : context.border)),
                      child: Text(m, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: active ? Colors.white : context.textSub))),
                  );
                }).toList()),
              ])),

              const SizedBox(height: 12),

              // description
              _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const _Label('Description'),
                const SizedBox(height: 8),
                TextField(
                  controller: _descriptionCtrl,
                  maxLines: 3,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: context.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'What is this donation for? (optional)',
                    hintStyle: TextStyle(fontSize: 14, color: context.textHint, fontWeight: FontWeight.w500),
                    filled: true, fillColor: context.scaffoldBg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: context.border, width: 1.5)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: context.border, width: 1.5)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _brand600, width: 1.5)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  ),
                ),
              ])),

              const SizedBox(height: 12),

              // receipt + date
              _Card(child: Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const _Label('Receipt No.'),
                  const SizedBox(height: 8),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(color: _brand100, borderRadius: BorderRadius.circular(12)),
                    child: Text(_receipt, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _brand700, letterSpacing: 0.3))),
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

              // transaction id — required for non-cash methods; for Cash it's
              // optional and the invoice prints a blank line to fill by hand
              _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _Label(_method == 'Cash'
                    ? 'Transaction ID / Reference No. (optional for Cash)'
                    : 'Transaction ID / Reference No. — required *'),
                const SizedBox(height: 8),
                TextField(
                  controller: _txnIdCtrl,
                  onChanged: (_) { if (_txnError != null) setState(() => _txnError = null); },
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.textPrimary),
                  decoration: InputDecoration(
                    // Only relevant while a non-cash method is selected.
                    errorText: _method == 'Cash' ? null : _txnError,
                    hintText: _method == 'Cash'
                        ? 'Leave blank to fill on printed invoice'
                        : 'Enter UTR / UPI Ref / Cheque No. for $_method',
                    hintStyle: TextStyle(fontSize: 12.5, color: context.textHint, fontWeight: FontWeight.w500),
                    filled: true, fillColor: context.scaffoldBg,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: context.border, width: 1.5)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: context.border, width: 1.5)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: _brand600, width: 1.5)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  ),
                ),
              ])),

              const SizedBox(height: 12),

              // attachment upload
              _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const _Label('Attachments'),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: _pickingFile ? null : () async {
                    setState(() => _pickingFile = true);
                    try {
                      final result = await FilePicker.platform.pickFiles(allowMultiple: false, withData: true);
                      if (result != null && result.files.isNotEmpty && mounted) {
                        setState(() => _attachments.add(result.files.single.name));
                      }
                    } catch (_) {}
                    if (mounted) setState(() => _pickingFile = false);
                  },
                  child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 20),
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: context.border, width: 1.5)),
                    child: _pickingFile
                      ? const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: _brand600)))
                      : Column(children: [
                          Icon(Icons.upload_file_outlined, color: context.textHint, size: 28),
                          const SizedBox(height: 7),
                          Text('Tap to attach receipt / proof', style: TextStyle(fontSize: 13, color: context.textHint, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 3),
                          Text('PDF, JPG, PNG — any file type', style: TextStyle(fontSize: 11, color: context.textHint, fontWeight: FontWeight.w500)),
                        ])),
                ),
                if (_attachments.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ..._attachments.asMap().entries.map((e) => Container(
                    margin: const EdgeInsets.only(bottom: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(color: _brand100, borderRadius: BorderRadius.circular(10)),
                    child: Row(children: [
                      const Icon(Icons.attach_file_rounded, size: 16, color: _brand600),
                      const SizedBox(width: 8),
                      Expanded(child: Text(e.value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _brand600), overflow: TextOverflow.ellipsis)),
                      GestureDetector(
                        onTap: () => setState(() => _attachments.removeAt(e.key)),
                        child: const Icon(Icons.close, size: 16, color: _brand600)),
                    ]),
                  )),
                ],
              ])),

            // ── Inline action buttons ──────────────────────────────
            // Right-aligned on wide screens, full-width pair on phones.
            const SizedBox(height: 20),
            Builder(builder: (context) {
              final narrow = MediaQuery.sizeOf(context).width < 600;
              final cancel = AppButton(
                label: 'Cancel', variant: AppButtonVariant.secondary, expand: narrow,
                onPressed: _saving ? null : () => context.go('/donations'),
              );
              final save = AppButton(
                label: _isEdit ? 'Update Donation' : 'Save Donation', busyLabel: 'Saving…', icon: Icons.check_rounded,
                loading: _saving, expand: narrow, onPressed: _save,
              );
              return narrow
                  ? Row(children: [Expanded(child: cancel), const SizedBox(width: 10), Expanded(flex: 2, child: save)])
                  : Row(mainAxisAlignment: MainAxisAlignment.end, children: [cancel, const SizedBox(width: 8), save]);
            }),

            ])),
          )),
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
