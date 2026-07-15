import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

const _brand600 = Color(0xFFFF9933);
const _brand100 = Color(0xFFFFE8CC);
const _amber600 = Color(0xFFE0921A);
const _amber100 = Color(0xFFFFF1D6);
const _coral500 = Color(0xFFF2685E);
const _coral100 = Color(0xFFFFE3DF);
const _violet500 = Color(0xFF7C6CF0);
const _violet100 = Color(0xFFE7E3FD);
const _sky500 = Color(0xFF2D9CDB);
const _sky100 = Color(0xFFDCEFFB);
const _green500 = Color(0xFF14A98C);
const _onSurface2 = Color(0xFF5A6B67);
const _onSurface3 = Color(0xFF93A29F);
const _border = Color(0xFFE5EBE9);
const _surface2 = Color(0xFFF4F7F6);

const _topics = [
  ('Adding a new donor', Icons.person_add_outlined,           _brand100,  _brand600),
  ('Recording a donation', Icons.account_balance_wallet_outlined, _violet100, _violet500),
  ('Generating reports',   Icons.bar_chart_outlined,          _sky100,    _sky500),
  ('Managing offices',     Icons.business_outlined,           _brand100,  _brand600),
  ('Enrolling a child',    Icons.child_care_outlined,         _amber100,  _amber600),
  ('Setting reminders',    Icons.notifications_outlined,      _coral100,  _coral500),
];

const _faqs = [
  ('How do I reset my PIN?',       'Go to Settings → Security & PIN → Reset PIN. A verification link will be sent to your registered email.'),
  ('Can I export donor data?',     'Yes. Go to Settings → Data → Export Data to download a CSV of all donor records for the selected period.'),
  ('How are receipts generated?',  'Receipts are auto-generated on saving a donation. They follow the SF/{FY}/{seq} format and can be shared or emailed directly.'),
];

// ══════════════════════════════════════════════════════════════════════
class HelpScreen extends StatefulWidget {
  const HelpScreen({super.key});
  @override
  State<HelpScreen> createState() => _HelpScreenState();
}

class _HelpScreenState extends State<HelpScreen> {
  String _search = '';
  final Set<int> _expanded = {};

  void _toast(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w700)),
    backgroundColor: _brand600, behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    duration: const Duration(seconds: 2),
  ));

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final filtered = _topics.where((t) => _search.isEmpty || t.$1.toLowerCase().contains(_search.toLowerCase())).toList();

    return Scaffold(
      backgroundColor: _surface2,
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(children: [
          // header
          Container(color: Colors.white, padding: EdgeInsets.fromLTRB(18, top + 14, 18, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20), onPressed: () => context.go('/more'), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                const SizedBox(width: 10),
                const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Help & Support', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                  Text('We\'re here to help', style: TextStyle(fontSize: 13, color: _onSurface2, fontWeight: FontWeight.w600)),
                ])),
              ]),
              const SizedBox(height: 12),
              // search
              Container(
                decoration: BoxDecoration(color: _surface2, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border)),
                child: TextField(
                  onChanged: (v) => setState(() => _search = v),
                  decoration: const InputDecoration(
                    hintText: 'Search help topics…',
                    hintStyle: TextStyle(fontSize: 14, color: _onSurface3, fontWeight: FontWeight.w500),
                    prefixIcon: Icon(Icons.search, color: _onSurface3, size: 20),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ])),

          const SizedBox(height: 20),

          // quick contacts
          Padding(padding: const EdgeInsets.symmetric(horizontal: 18), child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFFE07C1F), Color(0xFFFF9933)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(22),
              boxShadow: const [BoxShadow(color: Color(0x400B6E5D), blurRadius: 14, offset: Offset(0, 6))],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Need help now?', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              const Text('Our team responds within 2 hours', style: TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w500)),
              const SizedBox(height: 14),
              Row(children: [
                _ContactBtn(icon: Icons.chat_outlined,      label: 'Chat',  onTap: () => _toast('Opening chat…')),
                const SizedBox(width: 10),
                _ContactBtn(icon: Icons.call_outlined,      label: 'Call',  onTap: () => _toast('Calling support…')),
                const SizedBox(width: 10),
                _ContactBtn(icon: Icons.email_outlined,     label: 'Email', onTap: () => _toast('Opening email…')),
              ]),
            ]),
          )),

          const SizedBox(height: 22),

          // help topics
          _secLabel('Help Topics'),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 18), child: Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: _border),
              boxShadow: const [BoxShadow(color: Color(0x080D2822), blurRadius: 6, offset: Offset(0, 2))]),
            child: Column(children: filtered.isEmpty
              ? [const Padding(padding: EdgeInsets.all(20), child: Center(child: Text('No topics matched', style: TextStyle(fontSize: 14, color: _onSurface3, fontWeight: FontWeight.w600))))]
              : filtered.asMap().entries.map((e) {
                  final i = e.key; final t = e.value;
                  return GestureDetector(
                    onTap: () => _toast('Opening: ${t.$1}'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                      decoration: i < filtered.length - 1 ? const BoxDecoration(border: Border(bottom: BorderSide(color: _border))) : null,
                      child: Row(children: [
                        Container(width: 38, height: 38, decoration: BoxDecoration(color: t.$3, borderRadius: BorderRadius.circular(10)), child: Icon(t.$2, color: t.$4, size: 19)),
                        const SizedBox(width: 12),
                        Expanded(child: Text(t.$1, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700))),
                        const Icon(Icons.chevron_right, color: _onSurface3, size: 20),
                      ]),
                    ),
                  );
                }).toList()),
          )),

          const SizedBox(height: 22),

          // FAQ
          _secLabel('Frequently Asked'),
          Padding(padding: const EdgeInsets.fromLTRB(18, 0, 18, 0), child: Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: _border),
              boxShadow: const [BoxShadow(color: Color(0x080D2822), blurRadius: 6, offset: Offset(0, 2))]),
            child: Column(children: _faqs.asMap().entries.map((e) {
              final i = e.key; final f = e.value;
              final isOpen = _expanded.contains(i);
              return GestureDetector(
                onTap: () => setState(() => isOpen ? _expanded.remove(i) : _expanded.add(i)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: i < _faqs.length - 1 ? const BoxDecoration(border: Border(bottom: BorderSide(color: _border))) : null,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Expanded(child: Text(f.$1, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700))),
                      AnimatedRotation(turns: isOpen ? 0.5 : 0.0, duration: const Duration(milliseconds: 200),
                        child: const Icon(Icons.keyboard_arrow_down_rounded, color: _onSurface3, size: 22)),
                    ]),
                    AnimatedCrossFade(
                      firstChild: const SizedBox(height: 0),
                      secondChild: Padding(padding: const EdgeInsets.only(top: 10), child: Text(f.$2, style: const TextStyle(fontSize: 13.5, color: _onSurface2, fontWeight: FontWeight.w500, height: 1.5))),
                      crossFadeState: isOpen ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                      duration: const Duration(milliseconds: 200),
                    ),
                  ]),
                ),
              );
            }).toList()),
          )),

          const SizedBox(height: 30),
          const Center(child: Text('Sri Krishnashraya Educational Trust · v2.4.0 · support@saksham.org',
            style: TextStyle(fontSize: 11.5, color: _onSurface3, fontWeight: FontWeight.w500))),
          const SizedBox(height: 96),
        ]),
      ),
    );
  }
}

Widget _secLabel(String t) => Padding(padding: const EdgeInsets.fromLTRB(20, 0, 0, 10),
  child: Text(t.toUpperCase(), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: _onSurface3, letterSpacing: 0.8)));

class _ContactBtn extends StatelessWidget {
  const _ContactBtn({required this.icon, required this.label, required this.onTap});
  final IconData icon; final String label; final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Expanded(child: GestureDetector(onTap: onTap,
    child: Container(padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.white.withValues(alpha: 0.3))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: Colors.white, size: 20),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
      ]))));
}
