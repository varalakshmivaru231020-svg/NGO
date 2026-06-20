import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/app_launcher.dart';

const _brand700 = Color(0xFF0B6E5D);
const _brand600 = Color(0xFF0E8C76);
const _brand100 = Color(0xFFD6F3EC);
const _amber600 = Color(0xFFE0921A);
const _amber100 = Color(0xFFFFF1D6);
const _coral500 = Color(0xFFF2685E);
const _coral100 = Color(0xFFFFE3DF);
const _violet500 = Color(0xFF7C6CF0);
const _violet100 = Color(0xFFE7E3FD);
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
  const _Link({required this.id, required this.donor, required this.amount, required this.purpose, required this.status, required this.via, required this.created});
  final String id, donor, purpose, status, via, created;
  final int amount;
}

const _recentLinks = [
  _Link(id:'p1', donor:'Rajesh Khanna',  amount:100000, purpose:'Education Fund',   status:'Paid',    via:'WhatsApp', created:'26 May 2026'),
  _Link(id:'p2', donor:'Meera Iyer',     amount:15000,  purpose:'General Donation', status:'Paid',    via:'SMS',      created:'01 Jun 2026'),
  _Link(id:'p3', donor:'Kavya Reddy',    amount:11000,  purpose:'Food Drive',       status:'Viewed',  via:'WhatsApp', created:'02 Jun 2026'),
  _Link(id:'p4', donor:'Arjun Mehta',    amount:50000,  purpose:'Corporate Match',  status:'Sent',    via:'Email',    created:'03 Jun 2026'),
  _Link(id:'p5', donor:'Deepak Nair',    amount:5000,   purpose:'Ramzan Ration Kit',status:'Expired', via:'SMS',      created:'12 May 2026'),
];

const _funnel = [('Sent', 5, _sky500, _sky100), ('Viewed', 4, _amber600, _amber100), ('Paid', 2, _green600, _green100), ('Expired', 1, _coral500, _coral100)];

Color _statusColor(String s) => switch (s) { 'Paid' => _green600, 'Viewed' => _amber600, 'Sent' => _sky500, 'Expired' => _coral500, _ => _onSurface3 };
Color _statusBg(String s) => switch (s) { 'Paid' => _green100, 'Viewed' => _amber100, 'Sent' => _sky100, 'Expired' => _coral100, _ => _surface2 };

Color _avColor(String seed) {
  final p = [_brand600, const Color(0xFFF6A723), _violet500, _sky500, _coral500, const Color(0xFF14A98C)];
  int h = 0;
  for (int i = 0; i < seed.length; i++) { h = ((h * 31) + seed.codeUnitAt(i)) & 0xFFFFFFFF; }
  return p[h % p.length];
}
String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+'));
  return ((parts[0].isNotEmpty ? parts[0][0] : '') + (parts.length > 1 && parts[1].isNotEmpty ? parts[1][0] : '')).toUpperCase();
}

// ══════════════════════════════════════════════════════════════════════
class PaymentLinksScreen extends StatefulWidget {
  const PaymentLinksScreen({super.key});
  @override
  State<PaymentLinksScreen> createState() => _PaymentLinksScreenState();
}

class _PaymentLinksScreenState extends State<PaymentLinksScreen> {
  final _amountCtrl = TextEditingController();
  final _purposeCtrl = TextEditingController();
  String _validity = '7 days';
  bool _linkGenerated = false;
  String _generatedUrl = 'pay.saksham.org/d/8Kd2Qm';

  @override
  void dispose() { _amountCtrl.dispose(); _purposeCtrl.dispose(); super.dispose(); }

  void _toast(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w700)),
    backgroundColor: _brand600, behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), duration: const Duration(seconds: 2),
  ));

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: _surface2,
      body: Column(children: [
        Container(color: Colors.white, padding: EdgeInsets.fromLTRB(18, top + 14, 18, 16),
          child: Row(children: [
            IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20), onPressed: () => context.go('/more'), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
            const SizedBox(width: 10),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Payment Links', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
              Text('Generate & track donation links', style: TextStyle(fontSize: 13, color: _onSurface2, fontWeight: FontWeight.w600)),
            ])),
          ])),

        Expanded(child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 100),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Create card ────────────────────────────────────────
            _card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Create a Link', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              _lbl('Amount (₹)'),
              _tf(_amountCtrl, 'e.g. 25000', keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
              const SizedBox(height: 12),
              _lbl('Purpose'),
              _tf(_purposeCtrl, 'e.g. Education Fund'),
              const SizedBox(height: 12),
              _lbl('Validity'),
              Row(children: ['3 days', '7 days', '30 days'].map((v) {
                final active = _validity == v;
                return Padding(padding: const EdgeInsets.only(right: 8), child: GestureDetector(
                  onTap: () => setState(() => _validity = v),
                  child: Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(color: active ? _brand600 : Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: active ? _brand600 : _border, width: 1.5)),
                    child: Text(v, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: active ? Colors.white : _onSurface2))),
                ));
              }).toList()),
              const SizedBox(height: 16),
              SizedBox(width: double.infinity, child: ElevatedButton.icon(
                onPressed: () { setState(() { _linkGenerated = true; _generatedUrl = 'pay.saksham.org/d/${_purposeCtrl.text.isEmpty ? "8Kd2Qm" : _purposeCtrl.text.hashCode.toRadixString(36).substring(0, 6)}'; }); },
                style: ElevatedButton.styleFrom(backgroundColor: _brand600, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), padding: const EdgeInsets.symmetric(vertical: 14), elevation: 0),
                icon: const Icon(Icons.link, size: 18),
                label: const Text('Generate Link', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              )),
            ]))),

            // ── Active link card ───────────────────────────────────
            if (_linkGenerated) ...[
              const SizedBox(height: 14),
              _card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: _green100, borderRadius: BorderRadius.circular(10)),
                    child: const Row(children: [Icon(Icons.circle, size: 8, color: _green600), SizedBox(width: 6), Text('Link Active · expires in 7d', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: _green600))])),
                ]),
                const SizedBox(height: 16),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // QR
                  Container(width: 120, height: 120, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border, width: 2)),
                    child: Padding(padding: const EdgeInsets.all(8), child: CustomPaint(painter: _QRPainter(_generatedUrl), size: const Size(104, 104)))),
                  const SizedBox(width: 16),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('₹${_amountCtrl.text.isEmpty ? "25,000" : NumberFormat("#,##,###","en_IN").format(int.tryParse(_amountCtrl.text) ?? 0)}',
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: _brand700, letterSpacing: -1)),
                    const SizedBox(height: 4),
                    Text(_purposeCtrl.text.isEmpty ? 'Education Fund' : _purposeCtrl.text,
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: _onSurface2)),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () { Clipboard.setData(ClipboardData(text: _generatedUrl)); _toast('Link copied!'); },
                      child: Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(color: _surface2, borderRadius: BorderRadius.circular(10), border: Border.all(color: _border)),
                        child: Row(children: [
                          Expanded(child: Text(_generatedUrl, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _brand600), overflow: TextOverflow.ellipsis)),
                          const SizedBox(width: 6),
                          const Icon(Icons.copy_rounded, size: 15, color: _onSurface3),
                        ])),
                    ),
                  ])),
                ]),
                const SizedBox(height: 16),
                const Divider(height: 1, color: _border),
                const SizedBox(height: 12),
                Row(children: [
                  _ShareBtn(icon: Icons.message_rounded, label: 'WhatsApp', color: const Color(0xFF25D366),
                    onTap: () => launchWhatsApp('', context, message: 'Donate to Saksham Foundation: https://$_generatedUrl')),
                  const SizedBox(width: 8),
                  _ShareBtn(icon: Icons.sms_outlined, label: 'SMS', color: _sky500,
                    onTap: () => launchSms('', context, body: 'Donate to Saksham Foundation: https://$_generatedUrl')),
                  const SizedBox(width: 8),
                  _ShareBtn(icon: Icons.email_outlined, label: 'Email', color: _coral500,
                    onTap: () => launchEmail('', context, subject: 'Donation Link – Saksham Foundation', body: 'Please find your donation link: https://$_generatedUrl')),
                ]),
              ]))),
            ],

            const SizedBox(height: 18),

            // ── Funnel ────────────────────────────────────────────
            const Text('Link Performance', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Row(children: _funnel.map((f) => Expanded(child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Container(padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: f.$4, borderRadius: BorderRadius.circular(18), border: Border.all(color: _border)),
                child: Column(children: [
                  Text('${f.$2}', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: f.$3)),
                  const SizedBox(height: 3),
                  Text(f.$1, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _onSurface2)),
                ])),
            ))).toList()),

            const SizedBox(height: 18),

            // ── Recent links ──────────────────────────────────────
            const Text('Recent Links', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            _card(child: Column(children: _recentLinks.asMap().entries.map((e) {
              final i = e.key; final l = e.value;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: i < _recentLinks.length - 1 ? const BoxDecoration(border: Border(bottom: BorderSide(color: _border))) : null,
                child: Row(children: [
                  Container(width: 42, height: 42,
                    decoration: BoxDecoration(gradient: LinearGradient(colors: [_avColor(l.donor), Color.lerp(_avColor(l.donor), Colors.black, 0.18)!]), shape: BoxShape.circle),
                    child: Center(child: Text(_initials(l.donor), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)))),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(l.donor, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, height: 1)),
                    const SizedBox(height: 3),
                    Text('${l.purpose} · ${l.via}', style: const TextStyle(fontSize: 12.5, color: _onSurface2, fontWeight: FontWeight.w500)),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(_inr(l.amount), style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: _brand700)),
                    const SizedBox(height: 4),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(color: _statusBg(l.status), borderRadius: BorderRadius.circular(7)),
                      child: Text(l.status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: _statusColor(l.status)))),
                  ]),
                ]),
              );
            }).toList())),
          ]),
        )),
      ]),
    );
  }
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

// ── Deterministic QR painter ──────────────────────────────────────────
class _QRPainter extends CustomPainter {
  const _QRPainter(this.data);
  final String data;

  @override
  void paint(Canvas canvas, Size size) {
    const cells = 21;
    final cs = size.width / cells;
    final h = data.runes.fold(5381, (p, c) => ((p << 5) + p + c) & 0xFFFFFF);

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = Colors.white);

    // finder patterns
    _drawFinder(canvas, Offset.zero, cs);
    _drawFinder(canvas, Offset(size.width - 7 * cs, 0), cs);
    _drawFinder(canvas, Offset(0, size.width - 7 * cs), cs);

    // data modules
    final paint = Paint()..color = const Color(0xFF15211E);
    for (int r = 0; r < cells; r++) {
      for (int col = 0; col < cells; col++) {
        if (_skip(r, col, cells)) continue;
        final bit = ((h ^ (r * 1664525 + col * 22695477 + 1013904223)) & 0xFFFFFF) % 3 != 0;
        if (bit) canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(col * cs + 0.4, r * cs + 0.4, cs - 0.8, cs - 0.8), Radius.circular(cs * 0.18)), paint);
      }
    }
  }

  bool _skip(int r, int c, int n) => (r < 9 && c < 9) || (r < 9 && c >= n - 8) || (r >= n - 8 && c < 9);

  void _drawFinder(Canvas canvas, Offset o, double cs) {
    final dp = Paint()..color = const Color(0xFF15211E);
    final lp = Paint()..color = Colors.white;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(o.dx, o.dy, 7*cs, 7*cs), Radius.circular(cs * 0.5)), dp);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(o.dx+cs, o.dy+cs, 5*cs, 5*cs), Radius.circular(cs * 0.3)), lp);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(o.dx+2*cs, o.dy+2*cs, 3*cs, 3*cs), Radius.circular(cs * 0.2)), dp);
  }

  @override
  bool shouldRepaint(_QRPainter old) => old.data != data;
}
