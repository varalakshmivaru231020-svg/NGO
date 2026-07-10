import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/utils/app_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/network/api_client.dart';

const _brand700 = Color(0xFF0B6E5D);
const _brand600 = Color(0xFF0E8C76);
const _brand100 = Color(0xFFD6F3EC);
const _amber600 = Color(0xFFE0921A);
const _amber100 = Color(0xFFFFF1D6);
const _coral500 = Color(0xFFF2685E);
const _coral100 = Color(0xFFFFE3DF);
const _sky500 = Color(0xFF2D9CDB);
const _sky100 = Color(0xFFDCEFFB);
const _green600 = Color(0xFF1FA971);
const _green100 = Color(0xFFD4F3E7);
const _onSurface1 = Color(0xFF15211E);
const _onSurface2 = Color(0xFF5A6B67);
const _onSurface3 = Color(0xFF93A29F);
const _border = Color(0xFFE5EBE9);
const _surface2 = Color(0xFFF4F7F6);

String _inr(int n) {
  if (n >= 100000) return '₹${(n / 100000).toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '')}L';
  return '₹${NumberFormat('#,##,###', 'en_IN').format(n)}';
}

class _Link {
  const _Link({required this.id, required this.purpose, required this.amount, required this.status, required this.created, required this.url, required this.isLive});
  final String id, purpose, status, created, url;
  final int amount;
  final bool isLive; // true = real Razorpay short_url; false = internal-only fallback

  factory _Link.fromJson(Map<String, dynamic> j) {
    final shortUrl = j['razorpayShortUrl'] as String?;
    final slug = j['slug'] as String? ?? '';
    String date = '';
    try {
      final dt = DateTime.parse(j['createdAt'] as String? ?? '').toLocal();
      const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
      date = '${dt.day.toString().padLeft(2,'0')} ${m[dt.month-1]} ${dt.year}';
    } catch (_) {}
    return _Link(
      id: j['id'] as String? ?? '',
      purpose: (j['purpose'] as String?)?.isNotEmpty == true ? j['purpose'] as String : 'General Donation',
      amount: (j['amount'] as num?)?.toInt() ?? 0,
      status: j['status'] as String? ?? 'ACTIVE',
      created: date,
      url: shortUrl != null && shortUrl.isNotEmpty ? shortUrl : 'internal:$slug',
      isLive: shortUrl != null && shortUrl.isNotEmpty,
    );
  }
}

// ── Foundation bank account — shown beside the QR on a generated link ──
const _bankDetails = <(String, String, bool)>[
  ('Bank Name',          'ICICI BANK',                          false),
  ('Account Name',       'Sri Krishnashraya Educational Trust', false),
  ('Account No',         '390405000044',                        true),
  ('IFSC Code',          'ICIC0003904',                         true),
  ('Branch',             'Ulsoor Road',                         false),
  ('UPI / Paytm / GPay', '+91 70199 77341',                     true),
];

Color _statusColor(String s) => switch (s) { 'PAID' => _green600, 'ACTIVE' => _sky500, 'EXPIRED' => _coral500, 'FAILED' => _coral500, _ => _onSurface3 };
Color _statusBg(String s) => switch (s) { 'PAID' => _green100, 'ACTIVE' => _sky100, 'EXPIRED' => _coral100, 'FAILED' => _coral100, _ => _surface2 };
String _statusLabel(String s) => switch (s) { 'PAID' => 'Paid', 'ACTIVE' => 'Active', 'EXPIRED' => 'Expired', 'FAILED' => 'Failed', _ => s };

// ══════════════════════════════════════════════════════════════════════
class PaymentLinksScreen extends StatefulWidget {
  const PaymentLinksScreen({super.key});
  @override
  State<PaymentLinksScreen> createState() => _PaymentLinksScreenState();
}

// Shared donation purpose categories — also updated by DonationTypesScreen
final paymentLinkCategories = <String>[
  'Education Fund', 'Child Sponsorship', 'General Fund', 'Food & Nutrition', 'Zakat',
];

class _PaymentLinksScreenState extends State<PaymentLinksScreen> {
  final _amountCtrl = TextEditingController();
  String _purpose = paymentLinkCategories.first;
  bool _generating = false;
  _Link? _current;

  List<_Link> _recentLinks = [];
  bool _loadingList = true;

  @override
  void initState() { super.initState(); _loadRecent(); }

  @override
  void dispose() { _amountCtrl.dispose(); super.dispose(); }

  void _toast(String msg, {bool error = false}) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w700)),
    backgroundColor: error ? _coral500 : _brand600, behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), duration: const Duration(seconds: 2),
  ));

  Future<void> _loadRecent() async {
    if (mounted) setState(() => _loadingList = true);
    try {
      final r = await apiClient.get('/payment-links');
      final list = (r['data'] as List<dynamic>? ?? const []);
      final links = list.whereType<Map>().map((m) => _Link.fromJson(m.cast<String, dynamic>())).toList();
      if (mounted) setState(() { _recentLinks = links; _loadingList = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingList = false);
    }
  }

  Future<void> _generate() async {
    final amount = int.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0) {
      _toast('Enter a valid amount', error: true);
      return;
    }
    setState(() => _generating = true);
    try {
      final r = await apiClient.post('/payment-links', {'amount': amount, 'purpose': _purpose});
      final data = (r['data'] as Map).cast<String, dynamic>();
      final link = _Link.fromJson(data);
      setState(() { _current = link; _generating = false; });
      if (!link.isLive) {
        _toast('Link created, but Razorpay isn\'t configured — this is an internal link, not a real payment page. Add Razorpay credentials in Settings.', error: true);
      }
      await _loadRecent();
    } catch (e) {
      setState(() => _generating = false);
      _toast('Could not generate link — check your connection', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final current = _current;
    return Scaffold(
      backgroundColor: _surface2,
      body: Column(children: [
        Container(color: context.headerBg, padding: EdgeInsets.fromLTRB(18, top + 14, 18, 16),
          child: Row(children: [
            IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20), onPressed: () => context.go('/more'), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Payment Links', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: context.textPrimary)),
              Text('Generate & track donation links', style: TextStyle(fontSize: 13, color: context.textSub, fontWeight: FontWeight.w600)),
            ])),
          ])),

        Expanded(child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 100),
          child: Center(child: ConstrainedBox(
            constraints: const BoxConstraints(),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Create card ────────────────────────────────────────
            _card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Create a Link', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              _lbl('Amount (₹)'),
              _tf(_amountCtrl, 'e.g. 25000', keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
              const SizedBox(height: 12),
              _lbl('Purpose'),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                decoration: BoxDecoration(
                  color: context.scaffoldBg, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: context.border)),
                child: DropdownButton<String>(
                  value: _purpose,
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.textPrimary),
                  items: paymentLinkCategories.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                  onChanged: (v) { if (v != null) setState(() => _purpose = v); },
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, child: ElevatedButton.icon(
                onPressed: _generating ? null : _generate,
                style: ElevatedButton.styleFrom(backgroundColor: _brand600, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), padding: const EdgeInsets.symmetric(vertical: 14), elevation: 0),
                icon: _generating
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.link, size: 18),
                label: Text(_generating ? 'Generating…' : 'Generate Link', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              )),
            ]))),

            // ── Active link card ───────────────────────────────────
            if (current != null) ...[
              const SizedBox(height: 14),
              _card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: current.isLive ? _green100 : _amber100, borderRadius: BorderRadius.circular(10)),
                    child: Row(children: [
                      Icon(Icons.circle, size: 8, color: current.isLive ? _green600 : _amber600),
                      const SizedBox(width: 6),
                      Text(current.isLive ? 'Live Razorpay Link' : 'Not Live — Razorpay Not Configured', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: current.isLive ? _green600 : _amber600)),
                    ])),
                  const Spacer(),
                  Text(_inr(current.amount), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: _brand700, letterSpacing: -1)),
                ]),
                const SizedBox(height: 4),
                Text(current.purpose, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: _onSurface2)),
                const SizedBox(height: 12),
                // ── QR scanner + bank details, side by side ───────────
                IntrinsicHeight(child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Column(children: [
                    Container(width: 120, height: 120, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border, width: 2)),
                      child: current.isLive
                        ? Padding(padding: const EdgeInsets.all(8), child: QrImageView(data: current.url, size: 104, backgroundColor: Colors.white))
                        : Padding(padding: const EdgeInsets.all(12), child: Center(child: Icon(Icons.qr_code_2_outlined, size: 60, color: _onSurface3.withValues(alpha: 0.4)))),
                    ),
                    const SizedBox(height: 6),
                    Text(current.isLive ? 'Scan to pay' : 'No live link', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _onSurface3)),
                  ]),
                  const SizedBox(width: 16),
                  Expanded(child: _BankDetailsPanel(onCopy: _toast)),
                ])),
                const SizedBox(height: 14),
                // ── Donation link (below QR + details) — tap anywhere to copy/open ─
                GestureDetector(
                  onTap: current.isLive
                    ? () { Clipboard.setData(ClipboardData(text: current.url)); _toast('Link copied!'); }
                    : () => _toast('Add Razorpay credentials in Settings to get a real payment link', error: true),
                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(color: _surface2, borderRadius: BorderRadius.circular(10), border: Border.all(color: _border)),
                    child: Row(children: [
                      const Icon(Icons.link_rounded, size: 16, color: _brand600),
                      const SizedBox(width: 8),
                      Expanded(child: Text(current.isLive ? current.url : 'No live payment link — configure Razorpay in Settings',
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _brand600), overflow: TextOverflow.ellipsis)),
                      if (current.isLive) ...[
                        const SizedBox(width: 8),
                        const Icon(Icons.copy_rounded, size: 16, color: _brand600),
                        const SizedBox(width: 3),
                        const Text('Copy', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: _brand600)),
                      ],
                    ])),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: _border),
                const SizedBox(height: 12),
                Row(children: [
                  _ShareBtn(icon: Icons.message_rounded, label: 'WhatsApp', color: const Color(0xFF25D366),
                    onTap: current.isLive ? () => launchWhatsApp('', context, message: 'Donate to Saksham Foundation: ${current.url}') : () => _toast('No live link to share', error: true)),
                  const SizedBox(width: 8),
                  _ShareBtn(icon: Icons.sms_outlined, label: 'SMS', color: _sky500,
                    onTap: current.isLive ? () => launchSms('', context, body: 'Donate to Saksham Foundation: ${current.url}') : () => _toast('No live link to share', error: true)),
                  const SizedBox(width: 8),
                  _ShareBtn(icon: Icons.email_outlined, label: 'Email', color: _coral500,
                    onTap: current.isLive ? () => launchEmail('', context, subject: 'Donation Link – Saksham Foundation', body: 'Please find your donation link: ${current.url}') : () => _toast('No live link to share', error: true)),
                ]),
              ]))),
            ],

            const SizedBox(height: 18),

            // ── Recent links ──────────────────────────────────────
            const Text('Recent Links', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            if (_loadingList)
              _card(child: const Padding(padding: EdgeInsets.symmetric(vertical: 26), child: Center(child: CircularProgressIndicator(color: _brand600))))
            else if (_recentLinks.isEmpty)
              _card(child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 26, horizontal: 16),
                child: Center(child: Text('No payment links yet. Generate one above.',
                  style: TextStyle(fontSize: 13.5, color: _onSurface2, fontWeight: FontWeight.w500))),
              ))
            else
            _card(child: Column(children: _recentLinks.asMap().entries.map((e) {
              final i = e.key; final l = e.value;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: i < _recentLinks.length - 1 ? const BoxDecoration(border: Border(bottom: BorderSide(color: _border))) : null,
                child: Row(children: [
                  Container(width: 42, height: 42,
                    decoration: BoxDecoration(color: l.isLive ? _brand100 : _amber100, shape: BoxShape.circle),
                    child: Icon(l.isLive ? Icons.link_rounded : Icons.link_off_rounded, color: l.isLive ? _brand600 : _amber600, size: 18)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(l.purpose, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, height: 1)),
                    const SizedBox(height: 3),
                    Text(l.isLive ? 'Live · ${l.created}' : 'Internal only · ${l.created}', style: const TextStyle(fontSize: 12.5, color: _onSurface2, fontWeight: FontWeight.w500)),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(_inr(l.amount), style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: _brand700)),
                    const SizedBox(height: 4),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: _statusBg(l.status), borderRadius: BorderRadius.circular(7)),
                      child: Text(_statusLabel(l.status), style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _statusColor(l.status)))),
                  ]),
                ]),
              );
            }).toList())),
          ]),
            )))),
      ]),
    );
  }
}

// ── Bank details panel — sits beside the QR on a generated link ───────
class _BankDetailsPanel extends StatelessWidget {
  const _BankDetailsPanel({required this.onCopy});
  final void Function(String) onCopy;

  // The entire block as one copy-friendly string.
  String get _allText => _bankDetails.map((r) => '${r.$1}: ${r.$2}').join('\n');

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
    decoration: BoxDecoration(
      color: _surface2,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: _border),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Icon(Icons.account_balance_outlined, size: 16, color: _brand600),
        const SizedBox(width: 6),
        const Text('Bank Details', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: _onSurface1)),
        const Spacer(),
        // Single button — copies ALL the bank details at once.
        GestureDetector(
          onTap: () { Clipboard.setData(ClipboardData(text: _allText)); onCopy('Bank details copied'); },
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: _brand100, borderRadius: BorderRadius.circular(8)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.copy_rounded, size: 13, color: _brand600),
              SizedBox(width: 4),
              Text('Copy', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: _brand600)),
            ]),
          ),
        ),
      ]),
      const SizedBox(height: 10),
      ..._bankDetails.map((row) {
        final (label, value, _) = row;
        return Padding(
          padding: const EdgeInsets.only(bottom: 9),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: _onSurface3, letterSpacing: 0.2)),
            const SizedBox(height: 1),
            Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _onSurface1, height: 1.25)),
          ]),
        );
      }),
    ]),
  );
}

class _ShareBtn extends StatelessWidget {
  const _ShareBtn({required this.icon, required this.label, required this.color, required this.onTap});
  final IconData icon; final String label; final Color color; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Expanded(child: GestureDetector(onTap: onTap,
    child: Container(padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Column(children: [Icon(icon, size: 20, color: color), const SizedBox(height: 4), Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color))]))));
}

Widget _card({required Widget child}) => Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: _border),
  boxShadow: const [BoxShadow(color: Color(0x0A0D2822), blurRadius: 8, offset: Offset(0, 3))]), child: child);
Widget _lbl(String t) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(t, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)));
Widget _tf(TextEditingController c, String hint, {TextInputType? keyboardType, List<TextInputFormatter>? inputFormatters}) => TextFormField(
  controller: c, keyboardType: keyboardType, inputFormatters: inputFormatters,
  style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
  decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(color: _onSurface3, fontSize: 14, fontWeight: FontWeight.w500),
    filled: true, fillColor: _surface2, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), isDense: true,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _border)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _brand600, width: 1.5))));
