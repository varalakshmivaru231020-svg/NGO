import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';

// ── colours ───────────────────────────────────────────────────────────
const _brand700 = Color(0xFF0B6E5D);
const _brand600 = Color(0xFF0E8C76);
const _brand100 = Color(0xFFD6F3EC);
const _violet500 = Color(0xFF7C6CF0);
const _violet100 = Color(0xFFE7E3FD);
const _amber600 = Color(0xFFE0921A);
const _amber100 = Color(0xFFFFF1D6);
const _coral500 = Color(0xFFF2685E);
const _coral100 = Color(0xFFFFE3DF);
const _sky500 = Color(0xFF2D9CDB);
const _sky100 = Color(0xFFDCEFFB);
const _onSurface1 = Color(0xFF15211E);
const _onSurface2 = Color(0xFF5A6B67);
const _onSurface3 = Color(0xFF93A29F);
const _border = Color(0xFFE5EBE9);
const _surface2 = Color(0xFFF4F7F6);

// ── mock data ─────────────────────────────────────────────────────────
final _kChildren = {
  's1': {
    'childId': 'SKT-C-0001', 'name': 'Aarav Kumar', 'centre': 'Sulibele',
    'age': '12 yrs', 'dob': '14 Sept 2013', 'gender': 'Male', 'class': 'Class 6',
    'aadhaar': '4821 7765 0012', 'admDate': '01 Jun 2022', 'status': 'Active',
    'father': 'Ramesh Kumar', 'mother': 'Sunita Kumar',
    'guardian': 'Sunita Kumar', 'relation': 'Mother', 'mobile': '+91 98201 77432',
    'address': 'Dharavi, Mumbai', 'sat': 'SAT-1187',
    'familyNotes': 'Single-income household; father is a daily-wage labourer. Two siblings.',
    'eduType': 'School', 'institution': 'Sulibele Govt High School',
    'admNo': 'SGS-2022-0147', 'acadYear': '2025-26', 'performance': 'Above Average',
    'schoolAddr': 'Main Road, Sulibele, Karnataka 562129',
    'height': '132 cm', 'weight': '28 kg',
    'medHistory': 'Mild asthma — inhaler prescribed. Vaccinations up to date.',
    'sponsor': 'Priya Sharma', 'sponsorId': 'd2', 'sponsorDonorId': 'SF-D-0002',
    'sponsorCategory': 'Child Sponsor', 'sponsorCity': 'Delhi',
    'sponsorAmt': '₹18,000 / year', 'sponsorSince': '01 Jul 2022', 'enrollDate': '01 Jun 2022',
    'attendance': '94%', 'achievementCount': '4', 'sponsorshipAmt': '₹18K',
  },
  's2': {
    'childId': 'SKT-C-0002', 'name': 'Fatima Sheikh', 'centre': 'Medahalli',
    'age': '15 yrs', 'dob': '22 Aug 2009', 'gender': 'Female', 'class': 'Class 10',
    'aadhaar': '8812 4562 0019', 'admDate': '12 Jul 2018', 'status': 'Active',
    'father': 'Mohammed Sheikh', 'mother': 'Razia Sheikh',
    'guardian': 'Mohammed Sheikh', 'relation': 'Father', 'mobile': '+91 94501 77234',
    'address': '3rd Cross, Medahalli Colony, Bengaluru 560049', 'sat': 'SAT-0089',
    'familyNotes': 'Father drives auto-rickshaw, mother works as domestic help.',
    'eduType': 'School', 'institution': 'Medahalli Govt PU College',
    'admNo': 'MGP-2018-109', 'acadYear': '2025-26', 'performance': 'Excellent',
    'schoolAddr': 'Medahalli Main Road, Bengaluru 560049',
    'height': '157 cm', 'weight': '44 kg',
    'medHistory': 'Mild asthma (controlled). Uses inhaler as needed.',
    'sponsor': '', 'sponsorId': '', 'sponsorDonorId': '',
    'sponsorCategory': '', 'sponsorCity': '',
    'sponsorAmt': '', 'sponsorSince': '', 'enrollDate': '12 Jul 2018',
    'attendance': '88%', 'achievementCount': '6', 'sponsorshipAmt': '—',
  },
};

Color _avColor(String seed) {
  final palette = [_brand600, const Color(0xFFF6A723), _violet500, _sky500,
    const Color(0xFFEC5B8B), _coral500, const Color(0xFF14A98C), const Color(0xFF5BAE8A)];
  int h = 0;
  for (int i = 0; i < seed.length; i++) { h = ((h * 31) + seed.codeUnitAt(i)) & 0xFFFFFFFF; }
  return palette[h % palette.length];
}
String _initials(String name) {
  final p = name.trim().split(RegExp(r'\s+'));
  return ((p[0].isNotEmpty ? p[0][0] : '') + (p.length > 1 && p[1].isNotEmpty ? p[1][0] : '')).toUpperCase();
}
Color _statusColor(String s) => switch (s) {
  'Active' => _brand600, 'Graduated' => _violet500,
  'Relieved' => _amber600, 'Drop out' => _coral500, _ => _onSurface3,
};

final _vDivider = Container(
  width: 1, height: 32, margin: const EdgeInsets.symmetric(horizontal: 6),
  color: Colors.white.withValues(alpha: 0.25),
);

// ══════════════════════════════════════════════════════════════════════
class StudentDetailScreen extends StatefulWidget {
  const StudentDetailScreen({super.key, required this.id});
  final String id;
  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

// mock donor list for sponsor picker
final _kDonors = [
  {'id': 'd1', 'donorId': 'SF-D-0001', 'name': 'Rajesh Mehta',   'category': 'Child Sponsor', 'city': 'Mumbai',    'amt': '₹18,000 / year'},
  {'id': 'd2', 'donorId': 'SF-D-0002', 'name': 'Priya Sharma',   'category': 'Child Sponsor', 'city': 'Delhi',     'amt': '₹18,000 / year'},
  {'id': 'd3', 'donorId': 'SF-D-0003', 'name': 'Ananya Iyer',    'category': 'Child Sponsor', 'city': 'Chennai',   'amt': '₹24,000 / year'},
  {'id': 'd4', 'donorId': 'SF-D-0004', 'name': 'Vikram Singh',   'category': 'General Donor', 'city': 'Bengaluru', 'amt': '₹12,000 / year'},
  {'id': 'd5', 'donorId': 'SF-D-0005', 'name': 'Sunita Kapoor',  'category': 'Child Sponsor', 'city': 'Pune',      'amt': '₹18,000 / year'},
];

class _StudentDetailScreenState extends State<StudentDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late Map<String, String> _data;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 6, vsync: this);
    _data = Map<String, String>.from(_kChildren[widget.id] ?? _kChildren['s1']!);
  }

  void _showSponsorPicker(BuildContext context) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.6,
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        child: Column(children: [
          Padding(padding: const EdgeInsets.fromLTRB(20, 14, 20, 10), child: Row(children: [
            Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(2)))),
            const Spacer(),
            const Text('Select Sponsor', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const Spacer(),
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
          ])),
          Expanded(child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
            itemCount: _kDonors.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final d = _kDonors[i];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 6),
                leading: Container(width: 44, height: 44,
                  decoration: const BoxDecoration(color: _brand100, shape: BoxShape.circle),
                  child: Center(child: Text(_initials(d['name']!), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _brand600)))),
                title: Text(d['name']!, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                subtitle: Text('${d['category']} · ${d['city']}', style: const TextStyle(fontSize: 12.5, color: _onSurface3)),
                trailing: Text(d['amt']!, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _brand600)),
                onTap: () {
                  final now = DateTime.now();
                  final dateStr = '${now.day.toString().padLeft(2,'0')} ${['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][now.month-1]} ${now.year}';
                  setState(() {
                    _data['sponsor']          = d['name']!;
                    _data['sponsorId']        = d['id']!;
                    _data['sponsorDonorId']   = d['donorId']!;
                    _data['sponsorCategory']  = d['category']!;
                    _data['sponsorCity']      = d['city']!;
                    _data['sponsorAmt']       = d['amt']!;
                    _data['sponsorSince']     = dateStr;
                    _data['sponsorshipAmt']   = d['amt']!.split(' ').first;
                  });
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('${d['name']} assigned as sponsor', style: const TextStyle(fontWeight: FontWeight.w700)),
                    backgroundColor: _brand600, behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
                },
              );
            },
          )),
        ]),
      ),
    );
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  void _showEditSheet(BuildContext context, Map<String, String> data) {
    final nameCtrl    = TextEditingController(text: data['name']);
    final centreCtrl  = TextEditingController(text: data['centre']);
    final mobileCtrl  = TextEditingController(text: data['mobile']);
    final addressCtrl = TextEditingController(text: data['address']);
    String gender     = data['gender'] ?? 'Male';
    String status     = data['status'] ?? 'Active';

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
        Widget field(String label, TextEditingController ctrl, {TextInputType? kb, int lines = 1}) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _onSurface2)),
            const SizedBox(height: 6),
            TextField(
              controller: ctrl, keyboardType: kb, maxLines: lines,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                filled: true, fillColor: _surface2,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _brand600, width: 1.5)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12))),
          ]));

        return Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 28),
          child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 36, height: 4, margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(2)))),
            const Text('Edit Student', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            field('Full Name', nameCtrl),
            field('Centre', centreCtrl),
            field('Guardian Mobile', mobileCtrl, kb: TextInputType.phone),
            field('Address', addressCtrl, lines: 2),
            const Text('Gender', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _onSurface2)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, children: ['Male', 'Female', 'Other'].map((g) {
              final active = gender == g;
              return GestureDetector(
                onTap: () => setSheet(() => gender = g),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: active ? _brand600 : _surface2, borderRadius: BorderRadius.circular(10)),
                  child: Text(g, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: active ? Colors.white : _onSurface2))));
            }).toList()),
            const SizedBox(height: 14),
            const Text('Status', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _onSurface2)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, children: ['Active', 'Graduated', 'Relieved', 'Drop out'].map((s) {
              final active = status == s;
              return GestureDetector(
                onTap: () => setSheet(() => status = s),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: active ? _statusColor(s).withValues(alpha: 0.15) : _surface2,
                    border: active ? Border.all(color: _statusColor(s), width: 1.5) : null,
                    borderRadius: BorderRadius.circular(10)),
                  child: Text(s, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                    color: active ? _statusColor(s) : _onSurface2))));
            }).toList()),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: const Text('Student updated successfully', style: TextStyle(fontWeight: FontWeight.w700)),
                  backgroundColor: _brand600, behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _brand600, foregroundColor: Colors.white, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 15)),
              child: const Text('Save Changes', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            )),
          ])),
        );
      }),
    );
  }

  void _showStatusSheet(BuildContext context, String current) {
    String status = current;
    const statuses = [
      ('Active',     'Currently enrolled and attending', Icons.check_circle_outline, _brand600,  _brand100),
      ('Graduated',  'Completed the programme',          Icons.school_outlined,      _violet500, _violet100),
      ('Relieved',   'Left on own / family request',     Icons.logout_rounded,       _amber600,  _amber100),
      ('Drop out',   'Left without completing',          Icons.cancel_outlined,      _coral500,  _coral100),
    ];
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 28),
        child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 36, height: 4, margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(2)))),
          const Text('Update Status', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text("Update the child's enrolment status.", style: TextStyle(fontSize: 13.5, color: _onSurface2, fontWeight: FontWeight.w500)),
          const SizedBox(height: 16),
          ...statuses.map((s) {
            final sel = status == s.$1;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: () => setSt(() => status = s.$1),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: sel ? s.$5 : _surface2,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: sel ? s.$4 : _border, width: sel ? 2 : 1),
                  ),
                  child: Row(children: [
                    Container(width: 40, height: 40,
                      decoration: BoxDecoration(color: sel ? s.$4 : Colors.white, borderRadius: BorderRadius.circular(10)),
                      child: Icon(s.$3, color: sel ? Colors.white : _onSurface3, size: 20)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(s.$1, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: sel ? s.$4 : _onSurface1)),
                      Text(s.$2, style: const TextStyle(fontSize: 12.5, color: _onSurface2, fontWeight: FontWeight.w500)),
                    ])),
                    if (sel) Icon(Icons.radio_button_checked, color: s.$4, size: 20)
                    else const Icon(Icons.radio_button_unchecked, color: _onSurface3, size: 20),
                  ]),
                ),
              ),
            );
          }),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text('Status updated to $status', style: const TextStyle(fontWeight: FontWeight.w700)),
                backgroundColor: _brand600, behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ));
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _brand600, foregroundColor: Colors.white, elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(vertical: 15)),
            child: const Text('Save Status', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          )),
        ])),
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final name = data['name']!;
    final color = _avColor(name);

    return Scaffold(
      backgroundColor: _surface2,
      body: NestedScrollView(
        headerSliverBuilder: (ctx, inner) => [
          SliverAppBar(
            expandedHeight: 390,
            pinned: true,
            backgroundColor: _brand700,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
              onPressed: () => context.go('/students'),
            ),
            actions: [
              IconButton(icon: const Icon(Icons.edit_outlined, color: Colors.white),
                onPressed: () => _showEditSheet(context, data)),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_brand700, color.withValues(alpha: 0.8)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                ),
                child: SafeArea(child: Padding(
                  padding: const EdgeInsets.only(bottom: 96),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    const SizedBox(height: 16),
                    Container(
                      width: 70, height: 70,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [color, Color.lerp(color, Colors.black, 0.2)!]),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 3))],
                      ),
                      child: Center(child: Text(_initials(name), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 24))),
                    ),
                    const SizedBox(height: 8),
                    Text(name, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 3),
                    Text(
                      '${data['age']} · ${data['gender']} · ${data['class']}',
                      style: const TextStyle(color: Colors.white70, fontSize: 12.5, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(data['centre']!, style: const TextStyle(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 8),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(10)),
                        child: Text(data['status']!, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white.withValues(alpha: 0.3))),
                        child: Text(data['childId']!, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14)),
                        child: Row(children: [
                          _StudentStat(label: 'Achievements',  value: data['achievementCount'] ?? '—'),
                          _vDivider,
                          _StudentStat(label: 'Sponsorship',   value: data['sponsorshipAmt'] ?? '—'),
                        ]),
                      ),
                    ),
                  ]),
                )),
              ),
            ),
            bottom: _AppBarBottom(
              tabController: _tabs,
              status: data['status']!,
              onUpdate: () => _showStatusSheet(context, data['status']!),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabs,
          children: [
            _ProfileTab(data: data),
            _EducationTab(data: data),
            _SponsorTab(data: data, onAssign: () => _showSponsorPicker(context)),
            _AchievementsTab(studentId: name),
            const _DocumentsTab(),
            _ProgressTab(data: data),
          ],
        ),
      ),
    );
  }
}

// ── stats widget ──────────────────────────────────────────────────────
class _StudentStat extends StatelessWidget {
  const _StudentStat({required this.label, required this.value});
  final String label, value;
  @override
  Widget build(BuildContext context) => Expanded(child: Column(children: [
    Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
    const SizedBox(height: 2),
    Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600)),
  ]));
}

// ── app bar bottom (current status + tab bar) ─────────────────────────
class _AppBarBottom extends StatelessWidget implements PreferredSizeWidget {
  const _AppBarBottom({required this.tabController, required this.status, required this.onUpdate});
  final TabController tabController;
  final String status;
  final VoidCallback onUpdate;

  @override
  Size get preferredSize => const Size.fromHeight(48.0 + 44.0);

  @override
  Widget build(BuildContext context) => Column(mainAxisSize: MainAxisSize.min, children: [
    Container(
      color: _brand700,
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 8),
      child: Row(children: [
        Text('Current Status', style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12.5, fontWeight: FontWeight.w600)),
        const SizedBox(width: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
          child: Text(status, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800)),
        ),
        const Spacer(),
        GestureDetector(
          onTap: onUpdate,
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
            child: const Text('Update', style: TextStyle(color: _brand700, fontSize: 12.5, fontWeight: FontWeight.w800)),
          ),
        ),
      ]),
    ),
    TabBar(
      controller: tabController,
      isScrollable: true,
      indicatorColor: Colors.white,
      indicatorWeight: 3,
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white60,
      labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
      tabAlignment: TabAlignment.start,
      tabs: const [
        Tab(text: 'Profile'),
        Tab(text: 'Education'),
        Tab(text: 'Sponsor'),
        Tab(text: 'Achievements'),
        Tab(text: 'Documents'),
        Tab(text: 'Progress'),
      ],
    ),
  ]);
}

// ══════════════════════════════════════════════════════════════════════
// PROFILE TAB
// ══════════════════════════════════════════════════════════════════════
class _ProfileTab extends StatelessWidget {
  const _ProfileTab({required this.data});
  final Map<String, String> data;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    physics: const BouncingScrollPhysics(),
    padding: const EdgeInsets.all(18),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Basic Profile
      _CardSection(title: 'Basic Profile', icon: Icons.person_outline, children: [
        _InfoRow('Child ID',          data['childId']!),
        _InfoRow('Centre',            data['centre']!),
        _InfoRow('Date of Birth',     '${data['dob']!} (${data['age']!})'),
        _InfoRow('Gender',            data['gender']!),
        _InfoRow('Aadhaar Number',    data['aadhaar']!),
        _InfoRow('Date of Admission', data['admDate']!, last: true),
      ]),
      const SizedBox(height: 14),
      // Family Details
      _CardSection(title: 'Family Details', icon: Icons.family_restroom_outlined, children: [
        _InfoRow("Father's Name", data['father']!),
        _InfoRow("Mother's Name", data['mother']!),
        _InfoRow('Guardian',      '${data['guardian']!} (${data['relation']!})'),
        _InfoRow('Mobile Number', data['mobile']!),
        _InfoRow('Address',       data['address']!),
        _InfoRow('SAT Number',    data['sat']!, last: true),
      ]),
      const SizedBox(height: 14),
      if (data['familyNotes'] != null && data['familyNotes']!.isNotEmpty)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(color: _amber100, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [Icon(Icons.notes_outlined, size: 16, color: _amber600), SizedBox(width: 7), Text('Family Background', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: _amber600))]),
            const SizedBox(height: 8),
            Text(data['familyNotes']!, style: const TextStyle(fontSize: 14, color: _onSurface1, fontWeight: FontWeight.w500, height: 1.5)),
          ]),
        ),
      const SizedBox(height: 14),
      // Health & Medical
      _CardSection(title: 'Health & Medical', icon: Icons.health_and_safety_outlined, children: [
        _InfoRow('Height', data['height']!),
        _InfoRow('Weight', data['weight']!, last: true),
      ]),
      if (data['medHistory'] != null && data['medHistory']!.isNotEmpty) ...[
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(color: _coral100, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [Icon(Icons.medication_outlined, size: 16, color: _coral500), SizedBox(width: 7), Text('Medical History', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: _coral500))]),
            const SizedBox(height: 8),
            Text(data['medHistory']!, style: const TextStyle(fontSize: 14, color: _onSurface1, fontWeight: FontWeight.w500, height: 1.5)),
          ]),
        ),
      ],
      const SizedBox(height: 14),
      // Document upload sections
      const _UploadSection(label: 'Medical Documents',  sublabel: 'Prescriptions, reports, discharge summaries'),
      const SizedBox(height: 10),
      const _UploadSection(label: "Parents' Aadhaar",   sublabel: 'Upload Aadhaar card images'),
      const SizedBox(height: 10),
      const _UploadSection(label: 'Family Photo',        sublabel: 'Family photograph'),
      const SizedBox(height: 80),
    ]),
  );
}

// ══════════════════════════════════════════════════════════════════════
// EDUCATION TAB
// ══════════════════════════════════════════════════════════════════════
class _EducationTab extends StatelessWidget {
  const _EducationTab({required this.data});
  final Map<String, String> data;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    physics: const BouncingScrollPhysics(),
    padding: const EdgeInsets.all(18),
    child: Column(children: [
      Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(color: _violet100, borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            const Icon(Icons.school_outlined, size: 16, color: _violet500),
            const SizedBox(width: 7),
            Text(data['eduType'] ?? 'School', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _violet500)),
          ]),
        ),
      ]),
      const SizedBox(height: 14),
      _CardSection(title: 'Institution Details', icon: Icons.account_balance_outlined, children: [
        _InfoRow('Institution',   data['institution'] ?? '—'),
        _InfoRow('Class / Grade', data['class'] ?? '—'),
        _InfoRow('Admission No.', data['admNo'] ?? '—'),
        _InfoRow('Academic Year', data['acadYear'] ?? '—'),
        _InfoRow('Performance',   data['performance'] ?? '—'),
        _InfoRow('Address',       data['schoolAddr'] ?? '—', last: true),
      ]),
      const SizedBox(height: 14),
      const _DocCard(label: 'Educational Documents', sublabel: 'Report cards, certificates, TC', icon: Icons.description_outlined, count: 3),
      const SizedBox(height: 80),
    ]),
  );
}

// ══════════════════════════════════════════════════════════════════════
// SPONSOR TAB
// ══════════════════════════════════════════════════════════════════════
class _SponsorTab extends StatelessWidget {
  const _SponsorTab({required this.data, required this.onAssign});
  final Map<String, String> data;
  final VoidCallback onAssign;

  @override
  Widget build(BuildContext context) {
    final hasSponsor = (data['sponsor'] ?? '').isNotEmpty;
    if (!hasSponsor) return _noSponsor(context);

    final sponsor     = data['sponsor']!;
    final sponsorId   = data['sponsorDonorId'] ?? data['sponsorId'] ?? '—';
    final donorId     = data['sponsorId'] ?? '';
    final category    = data['sponsorCategory'] ?? 'Donor';
    final city        = data['sponsorCity'] ?? '';
    final amount      = data['sponsorAmt'] ?? '—';
    final since       = data['sponsorSince'] ?? '—';
    final enrollDate  = data['enrollDate'] ?? '—';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── "Sponsored Child · Active" badge ───────────────────────
        Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(color: _brand100, borderRadius: BorderRadius.circular(12)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.favorite, color: _brand600, size: 15),
              SizedBox(width: 6),
              Text('Sponsored Child', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _brand600)),
            ]),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(color: _brand600, borderRadius: BorderRadius.circular(12)),
            child: const Text('Active', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Colors.white)),
          ),
        ]),
        const SizedBox(height: 14),

        // ── Sponsor profile card ────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _border),
            boxShadow: const [BoxShadow(color: Color(0x080D2822), blurRadius: 8, offset: Offset(0, 2))],
          ),
          child: Row(children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_brand700, _brand600]),
                shape: BoxShape.circle,
              ),
              child: Center(child: Text(_initials(sponsor), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18))),
            ),
            const SizedBox(width: 13),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(sponsor, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _onSurface1)),
              const SizedBox(height: 3),
              Text(
                city.isNotEmpty ? '$category · $city' : category,
                style: const TextStyle(fontSize: 12.5, color: _onSurface3, fontWeight: FontWeight.w600),
              ),
            ])),
            GestureDetector(
              onTap: () => context.go('/donors/$donorId'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(color: _brand100, borderRadius: BorderRadius.circular(10)),
                child: const Text('View Profile', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _brand600)),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 10),

        // ── Sponsorship details ─────────────────────────────────────
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: _border)),
          child: Column(children: [
            _SpnRow('Sponsorship ID (Donor ID)', sponsorId, first: true),
            _SpnRow('Sponsorship Amount', amount),
            _SpnRow('Start Date', since),
            _SpnRow('Sponsorship Status', 'Active', valueBold: true, valueColor: _brand600, last: true),
          ]),
        ),
        const SizedBox(height: 14),

        // ── Change sponsor button ───────────────────────────────────
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onAssign,
            icon: const Icon(Icons.swap_horiz_rounded, size: 18),
            label: const Text('Change Sponsor', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            style: OutlinedButton.styleFrom(
              foregroundColor: _brand600,
              side: const BorderSide(color: _brand600, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
        const SizedBox(height: 22),

        // ── Sponsorship history ─────────────────────────────────────
        const Text('SPONSORSHIP HISTORY', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: _onSurface3, letterSpacing: 1.0)),
        const SizedBox(height: 12),
        _TimelineEvent(
          dot: _brand600,
          title: 'Sponsorship active',
          sub: '$sponsor · since $since',
          isFirst: true,
        ),
        _TimelineEvent(
          dot: _onSurface3,
          title: 'Enrolled into programme',
          sub: enrollDate,
          isLast: true,
        ),
        const SizedBox(height: 80),
      ]),
    );
  }

  Widget _noSponsor(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(18),
    child: Column(children: [
      const SizedBox(height: 40),
      Container(
        width: double.infinity, padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: _border)),
        child: Column(children: [
          Container(width: 64, height: 64, decoration: const BoxDecoration(color: _brand100, shape: BoxShape.circle),
            child: const Icon(Icons.favorite_border, size: 30, color: _brand600)),
          const SizedBox(height: 16),
          const Text('No Sponsor Assigned', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text('Assign a donor from the donor list to sponsor this child.',
            textAlign: TextAlign.center, style: TextStyle(color: _onSurface2, fontSize: 13.5, fontWeight: FontWeight.w500)),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onAssign,
            style: ElevatedButton.styleFrom(backgroundColor: _brand600, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14), elevation: 0),
            icon: const Icon(Icons.person_search_outlined, size: 18),
            label: const Text('Assign Sponsor from Donors', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ]),
      ),
      const SizedBox(height: 80),
    ]),
  );
}

class _SpnRow extends StatelessWidget {
  const _SpnRow(this.label, this.value, {this.first = false, this.last = false, this.valueBold = false, this.valueColor});
  final String label, value;
  final bool first, last, valueBold;
  final Color? valueColor;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
    decoration: BoxDecoration(
      border: last ? null : const Border(bottom: BorderSide(color: _border)),
    ),
    child: Row(children: [
      Expanded(child: Text(label, style: const TextStyle(fontSize: 13, color: _onSurface3, fontWeight: FontWeight.w600))),
      Text(value, style: TextStyle(fontSize: 13.5, fontWeight: valueBold ? FontWeight.w800 : FontWeight.w700, color: valueColor ?? _onSurface1)),
    ]),
  );
}

class _TimelineEvent extends StatelessWidget {
  const _TimelineEvent({required this.dot, required this.title, required this.sub, this.isFirst = false, this.isLast = false});
  final Color dot;
  final String title, sub;
  final bool isFirst, isLast;
  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 20, child: Column(children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: dot, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2), boxShadow: [BoxShadow(color: dot.withValues(alpha: 0.4), blurRadius: 4)])),
        if (!isLast) Expanded(child: Container(width: 1.5, color: _border, margin: const EdgeInsets.symmetric(vertical: 3))),
      ])),
      const SizedBox(width: 12),
      Expanded(child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: _onSurface1)),
          const SizedBox(height: 2),
          Text(sub, style: const TextStyle(fontSize: 12.5, color: _onSurface3, fontWeight: FontWeight.w500)),
        ]),
      )),
    ]),
  );
}


// ══════════════════════════════════════════════════════════════════════
// ACHIEVEMENTS TAB
// ══════════════════════════════════════════════════════════════════════
// ── student activity model ────────────────────────────────────────────
class _StudentActivity {
  String title;
  String category;
  String description;
  final String date;
  final List<Uint8List> imageBytes;
  final List<String> videoNames;
  _StudentActivity({
    required this.title, required this.category,
    this.description = '', required this.date,
    List<Uint8List>? imageBytes, List<String>? videoNames,
  }) : imageBytes = imageBytes ?? [], videoNames = videoNames ?? [];
}

final _studentAchievements = <String, List<_StudentActivity>>{};

class _AchievementsTab extends StatefulWidget {
  const _AchievementsTab({required this.studentId});
  final String studentId;
  @override
  State<_AchievementsTab> createState() => _AchievementsTabState();
}

class _AchievementsTabState extends State<_AchievementsTab> {
  List<_StudentActivity> get _list => _studentAchievements.putIfAbsent(widget.studentId, () => []);

  static const _cats = ['Arts', 'Sports', 'Academics', 'Community', 'Leadership', 'Other'];

  static Color _catFg(String c) => switch (c) {
    'Arts'       => _amber600,
    'Sports'     => _sky500,
    'Academics'  => _violet500,
    'Community'  => _brand600,
    _            => _coral500,
  };

  void _openSheet({_StudentActivity? editing}) {
    final titleCtrl = TextEditingController(text: editing?.title ?? '');
    final descCtrl  = TextEditingController(text: editing?.description ?? '');
    String cat = editing?.category ?? 'Arts';
    final images = <Uint8List>[...?editing?.imageBytes];
    final videos = <String>[...?editing?.videoNames];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, ss) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 620),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 0),
              child: Row(children: [
                Expanded(child: Text(editing == null ? 'Add Achievement' : 'Edit Achievement',
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _onSurface1))),
                IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded, size: 22, color: _onSurface2)),
              ]),
            ),
            const Divider(height: 1, color: _border),
            Expanded(child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Category', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _onSurface2)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 6, children: _cats.map((c) {
                  final sel = cat == c;
                  return GestureDetector(
                    onTap: () => ss(() => cat = c),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                      decoration: BoxDecoration(
                        color: sel ? _brand600 : _surface2,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: sel ? _brand600 : _border),
                      ),
                      child: Text(c, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: sel ? Colors.white : _onSurface2)),
                    ),
                  );
                }).toList()),
                const SizedBox(height: 14),
                const Text('Title *', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _onSurface2)),
                const SizedBox(height: 6),
                TextField(
                  controller: titleCtrl,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: 'e.g. Annual Sports Day',
                    hintStyle: const TextStyle(color: _onSurface3, fontWeight: FontWeight.w400),
                    filled: true, fillColor: _surface2,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _brand600, width: 1.5)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
                ),
                const SizedBox(height: 14),
                const Text('Description', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _onSurface2)),
                const SizedBox(height: 6),
                TextField(
                  controller: descCtrl, maxLines: 3,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: 'Brief description…',
                    hintStyle: const TextStyle(color: _onSurface3, fontWeight: FontWeight.w400),
                    filled: true, fillColor: _surface2,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _brand600, width: 1.5)),
                    contentPadding: const EdgeInsets.all(14)),
                ),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: GestureDetector(
                    onTap: () async {
                      final r = await FilePicker.platform.pickFiles(allowMultiple: true, type: FileType.image, withData: true);
                      if (r != null && mounted) {
                        ss(() => images.addAll(r.files.where((f) => f.bytes != null).map((f) => f.bytes!)));
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(color: _brand100, borderRadius: BorderRadius.circular(12), border: Border.all(color: _brand600.withValues(alpha: 0.3))),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.add_photo_alternate_outlined, color: _brand600, size: 18),
                        const SizedBox(width: 6),
                        Text('Images${images.isNotEmpty ? ' (${images.length})' : ''}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _brand600)),
                      ]),
                    ),
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: GestureDetector(
                    onTap: () async {
                      final r = await FilePicker.platform.pickFiles(allowMultiple: true, type: FileType.video, withData: false);
                      if (r != null && mounted) {
                        ss(() => videos.addAll(r.files.map((f) => f.name)));
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(color: _violet100, borderRadius: BorderRadius.circular(12), border: Border.all(color: _violet500.withValues(alpha: 0.3))),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        const Icon(Icons.video_call_outlined, color: _violet500, size: 18),
                        const SizedBox(width: 6),
                        Text('Videos${videos.isNotEmpty ? ' (${videos.length})' : ''}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _violet500)),
                      ]),
                    ),
                  )),
                ]),
                if (images.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SizedBox(height: 70, child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: images.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, i) => Stack(children: [
                      ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.memory(images[i], width: 70, height: 70, fit: BoxFit.cover)),
                      Positioned(top: 2, right: 2, child: GestureDetector(
                        onTap: () => ss(() => images.removeAt(i)),
                        child: Container(width: 18, height: 18, decoration: const BoxDecoration(color: _coral500, shape: BoxShape.circle),
                          child: const Icon(Icons.close, size: 12, color: Colors.white)),
                      )),
                    ]),
                  )),
                ],
                if (videos.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...videos.asMap().entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Row(children: [
                      const Icon(Icons.videocam_outlined, color: _violet500, size: 15),
                      const SizedBox(width: 6),
                      Expanded(child: Text(e.value, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _onSurface2), overflow: TextOverflow.ellipsis)),
                      GestureDetector(onTap: () => ss(() => videos.removeAt(e.key)), child: const Icon(Icons.close, size: 15, color: _onSurface3)),
                    ]),
                  )),
                ],
              ]),
            )),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: Row(children: [
                Expanded(child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(foregroundColor: _onSurface2, side: const BorderSide(color: _border),
                    padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700)),
                )),
                const SizedBox(width: 12),
                Expanded(flex: 2, child: ElevatedButton(
                  onPressed: () {
                    if (titleCtrl.text.trim().isEmpty) return;
                    setState(() {
                      if (editing == null) {
                        _list.insert(0, _StudentActivity(
                          title: titleCtrl.text.trim(), category: cat,
                          description: descCtrl.text.trim(),
                          date: _fmtDate(DateTime.now()),
                          imageBytes: List.from(images), videoNames: List.from(videos),
                        ));
                      } else {
                        editing.title = titleCtrl.text.trim();
                        editing.category = cat;
                        editing.description = descCtrl.text.trim();
                      }
                    });
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: _brand600, foregroundColor: Colors.white, elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                  child: Text(editing == null ? 'Save Activity' : 'Update', style: const TextStyle(fontWeight: FontWeight.w800)),
                )),
              ]),
            ),
          ]),
        ),
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _list;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
        child: Row(children: [
          Text('${list.length} Activit${list.length == 1 ? 'y' : 'ies'}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _onSurface2)),
          const Spacer(),
          GestureDetector(
            onTap: () => _openSheet(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(color: _brand600, borderRadius: BorderRadius.circular(10)),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.add, color: Colors.white, size: 16),
                SizedBox(width: 4),
                Text('Add Activity', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
              ]),
            ),
          ),
        ]),
      ),
      if (list.isEmpty)
        Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.photo_library_outlined, size: 44, color: _onSurface3),
          const SizedBox(height: 12),
          const Text('No activities yet', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _onSurface3)),
          const SizedBox(height: 6),
          const Text('Tap + to add an activity', style: TextStyle(fontSize: 13, color: _onSurface3)),
        ])))
      else
        Expanded(child: ListView.separated(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 40),
          physics: const BouncingScrollPhysics(),
          itemCount: list.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final a = list[i];
            final fg = _catFg(a.category);
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _border),
                boxShadow: const [BoxShadow(color: Color(0x080D2822), blurRadius: 6, offset: Offset(0, 2))],
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(color: fg.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                    child: Text(a.category, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: fg)),
                  ),
                  const Spacer(),
                  Text(a.date, style: const TextStyle(fontSize: 12, color: _onSurface3, fontWeight: FontWeight.w500)),
                ]),
                const SizedBox(height: 8),
                Text(a.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _onSurface1)),
                if (a.description.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(a.description, style: const TextStyle(fontSize: 13, color: _onSurface2, height: 1.45)),
                ],
                if (a.imageBytes.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  SizedBox(height: 72, child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: a.imageBytes.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (_, j) => ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.memory(a.imageBytes[j], width: 72, height: 72, fit: BoxFit.cover),
                    ),
                  )),
                ],
                if (a.videoNames.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(children: [
                    const Icon(Icons.videocam_outlined, size: 15, color: _violet500),
                    const SizedBox(width: 5),
                    Text('${a.videoNames.length} video${a.videoNames.length == 1 ? '' : 's'}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _violet500)),
                  ]),
                ],
                const SizedBox(height: 10),
                Row(children: [
                  _SActBtn(label: 'Edit', icon: Icons.edit_outlined, onTap: () => _openSheet(editing: a)),
                  const SizedBox(width: 8),
                  _SActBtn(label: 'Delete', icon: Icons.delete_outline, color: _coral500,
                    onTap: () => setState(() => _list.removeAt(i))),
                ]),
              ]),
            );
          },
        )),
    ]);
  }
}

String _fmtDate(DateTime d) {
  const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  return '${d.day.toString().padLeft(2,'0')} ${months[d.month - 1]} ${d.year}';
}

class _SActBtn extends StatelessWidget {
  const _SActBtn({required this.label, required this.icon, required this.onTap, this.color = _brand600});
  final String label; final IconData icon; final VoidCallback onTap; final Color color;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
      ]),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════
// DOCUMENTS TAB
// ══════════════════════════════════════════════════════════════════════
class _DocEntry {
  _DocEntry({required this.label, required this.icon, this.fileName, this.uploaded = false});
  final String label;
  final IconData icon;
  String? fileName;
  bool uploaded;
}

class _DocumentsTab extends StatefulWidget {
  const _DocumentsTab();
  @override
  State<_DocumentsTab> createState() => _DocumentsTabState();
}

class _DocumentsTabState extends State<_DocumentsTab> {
  final List<_DocEntry> _docs = [
    _DocEntry(label: 'Aadhaar Card',          icon: Icons.credit_card_outlined,                     uploaded: true,  fileName: 'aadhaar_card.pdf'),
    _DocEntry(label: 'Birth Certificate',      icon: Icons.article_outlined,                         uploaded: true,  fileName: 'birth_cert.pdf'),
    _DocEntry(label: 'Transfer Certificate',   icon: Icons.transfer_within_a_station_outlined,       uploaded: false),
    _DocEntry(label: 'Medical Reports',        icon: Icons.medical_services_outlined,                uploaded: true,  fileName: 'medical_report.pdf'),
    _DocEntry(label: 'School Report Card',     icon: Icons.school_outlined,                          uploaded: true,  fileName: 'report_card.pdf'),
  ];

  final List<String> _others = [];
  bool _uploadingIdx = false;
  int? _loadingDoc;

  Future<void> _uploadDoc(int idx) async {
    setState(() => _loadingDoc = idx);
    try {
      final result = await FilePicker.platform.pickFiles(allowMultiple: false, withData: true);
      if (result != null && result.files.isNotEmpty && mounted) {
        final name = result.files.single.name;
        setState(() { _docs[idx].fileName = name; _docs[idx].uploaded = true; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$name uploaded successfully', style: const TextStyle(fontWeight: FontWeight.w700)),
          backgroundColor: _brand600, behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingDoc = null);
  }

  Future<void> _uploadOther() async {
    final nameCtrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Document Name'),
        content: TextField(controller: nameCtrl, autofocus: true,
          decoration: const InputDecoration(hintText: 'Enter document name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () { final v = nameCtrl.text.trim(); if (v.isNotEmpty) Navigator.pop(ctx, v); }, child: const Text('Next')),
        ],
      ),
    );
    if (name == null || !mounted) return;
    setState(() => _uploadingIdx = true);
    try {
      final result = await FilePicker.platform.pickFiles(allowMultiple: false, withData: true);
      if (result != null && result.files.isNotEmpty && mounted) {
        setState(() => _others.add(name));
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$name attached', style: const TextStyle(fontWeight: FontWeight.w700)),
          backgroundColor: _brand600, behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
      }
    } catch (_) {}
    if (mounted) setState(() => _uploadingIdx = false);
  }

  @override
  Widget build(BuildContext context) {
    final uploadedCount = _docs.where((d) => d.uploaded).length + _others.length;
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header row: upload button left, count badge right
        Row(children: [
          GestureDetector(
            onTap: _uploadingIdx ? null : _uploadOther,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: _brand600, borderRadius: BorderRadius.circular(8)),
              child: _uploadingIdx
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.upload_file_outlined, size: 14, color: Colors.white),
                    SizedBox(width: 5),
                    Text('+ Upload document', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                  ]),
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: _brand100, borderRadius: BorderRadius.circular(12)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.folder_outlined, color: _brand600, size: 16),
              const SizedBox(width: 6),
              Text('$uploadedCount files', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _brand600)),
            ]),
          ),
        ]),
        const SizedBox(height: 14),

        // Document rows
        ..._docs.asMap().entries.map((entry) {
          final i = entry.key;
          final d = entry.value;
          final loading = _loadingDoc == i;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: _border)),
              child: Row(children: [
                Container(width: 44, height: 44,
                  decoration: BoxDecoration(color: d.uploaded ? _brand100 : _surface2, borderRadius: BorderRadius.circular(12)),
                  child: Icon(d.icon, size: 22, color: d.uploaded ? _brand600 : _onSurface3)),
                const SizedBox(width: 13),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(d.label, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Row(children: [
                    Container(width: 6, height: 6, decoration: BoxDecoration(
                      color: d.uploaded ? _brand600 : _onSurface3, shape: BoxShape.circle)),
                    const SizedBox(width: 5),
                    Text(
                      d.uploaded ? 'PDF · Uploaded' : 'Not uploaded',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600,
                        color: d.uploaded ? _brand600 : _onSurface3)),
                  ]),
                ])),
                const SizedBox(width: 10),
                loading
                  ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: _brand600))
                  : d.uploaded
                    ? const Icon(Icons.check_circle_rounded, color: _brand600, size: 22)
                    : GestureDetector(
                        onTap: () => _uploadDoc(i),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: _brand100, borderRadius: BorderRadius.circular(10), border: Border.all(color: _brand600.withValues(alpha: 0.3))),
                          child: const Text('Upload', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _brand600)),
                        ),
                      ),
              ]),
            ),
          );
        }),

        // Extra uploaded files
        ..._others.map((name) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: _border)),
            child: Row(children: [
              Container(width: 44, height: 44, decoration: BoxDecoration(color: _brand100, borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.insert_drive_file_outlined, size: 22, color: _brand600)),
              const SizedBox(width: 13),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                const Row(children: [
                  SizedBox(width: 6, height: 6, child: DecoratedBox(decoration: BoxDecoration(color: _brand600, shape: BoxShape.circle))),
                  SizedBox(width: 5),
                  Text('PDF · Uploaded', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _brand600)),
                ]),
              ])),
              const Icon(Icons.check_circle_rounded, color: _brand600, size: 22),
            ]),
          ),
        )),

        const SizedBox(height: 80),
      ]),
    );
  }
}

// ── shared widgets ─────────────────────────────────────────────────────
class _CardSection extends StatelessWidget {
  const _CardSection({required this.title, required this.icon, required this.children});
  final String title; final IconData icon; final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: _border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Row(children: [
          Icon(icon, size: 17, color: _brand600),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _onSurface1)),
        ]),
      ),
      const Divider(height: 1, color: _border),
      ...children,
    ]),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value, {this.last = false});
  final String label, value; final bool last;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
    decoration: last ? null : const BoxDecoration(border: Border(bottom: BorderSide(color: _border))),
    child: Row(children: [
      SizedBox(width: 120, child: Text(label, style: const TextStyle(fontSize: 12.5, color: _onSurface3, fontWeight: FontWeight.w600))),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: _onSurface1))),
    ]),
  );
}

class _DocCard extends StatelessWidget {
  const _DocCard({required this.label, required this.sublabel, required this.icon, required this.count});
  final String label, sublabel; final IconData icon; final int count;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: _border)),
    child: Row(children: [
      Container(width: 44, height: 44, decoration: BoxDecoration(color: _brand100, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: _brand600, size: 22)),
      const SizedBox(width: 13),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
        Text(sublabel, style: const TextStyle(fontSize: 12.5, color: _onSurface3, fontWeight: FontWeight.w500)),
      ])),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(color: _brand100, borderRadius: BorderRadius.circular(8)),
        child: Text('$count files', style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: _brand600)),
      ),
    ]),
  );
}

class _UploadSection extends StatelessWidget {
  const _UploadSection({required this.label, required this.sublabel});
  final String label, sublabel;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: _border)),
    child: Row(children: [
      Container(width: 44, height: 44, decoration: BoxDecoration(color: _surface2, borderRadius: BorderRadius.circular(12)),
        child: const Icon(Icons.upload_file_outlined, color: _onSurface3, size: 22)),
      const SizedBox(width: 13),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: _onSurface1)),
        Text(sublabel, style: const TextStyle(fontSize: 12.5, color: _onSurface3, fontWeight: FontWeight.w500)),
      ])),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(color: _surface2, borderRadius: BorderRadius.circular(10), border: Border.all(color: _border)),
        child: const Text('Upload', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _onSurface2)),
      ),
    ]),
  );
}

// ══════════════════════════════════════════════════════════════════════
// PROGRESS TAB
// ══════════════════════════════════════════════════════════════════════
class _ProgressTab extends StatefulWidget {
  const _ProgressTab({required this.data});
  final Map<String, String> data;
  @override
  State<_ProgressTab> createState() => _ProgressTabState();
}

class _ProgressTabState extends State<_ProgressTab> {
  late String _performance = widget.data['performance'] ?? 'Not specified';
  late String _height      = widget.data['height']      ?? '—';
  late String _weight      = widget.data['weight']      ?? '—';
  bool _editing = false;

  late final _perfCtrl   = TextEditingController(text: _performance);
  late final _heightCtrl = TextEditingController(text: _height);
  late final _weightCtrl = TextEditingController(text: _weight);

  @override
  void dispose() { _perfCtrl.dispose(); _heightCtrl.dispose(); _weightCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    physics: const BouncingScrollPhysics(),
    padding: const EdgeInsets.all(18),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('Progress Overview', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _onSurface1)),
        GestureDetector(
          onTap: () {
            if (_editing) {
              setState(() {
                _performance = _perfCtrl.text.trim().isNotEmpty ? _perfCtrl.text.trim() : _performance;
                _height      = _heightCtrl.text.trim().isNotEmpty ? _heightCtrl.text.trim() : _height;
                _weight      = _weightCtrl.text.trim().isNotEmpty ? _weightCtrl.text.trim() : _weight;
                _editing = false;
              });
            } else {
              setState(() => _editing = true);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _editing ? _brand600 : _surface2,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _editing ? _brand600 : _border),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(_editing ? Icons.check_rounded : Icons.edit_outlined, size: 15, color: _editing ? Colors.white : _onSurface2),
              const SizedBox(width: 5),
              Text(_editing ? 'Save' : 'Edit', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _editing ? Colors.white : _onSurface2)),
            ]),
          ),
        ),
      ]),
      const SizedBox(height: 14),
      _CardSection(title: 'Academic Performance', icon: Icons.bar_chart_outlined, children: [
        _InfoRow('Class / Grade',    widget.data['class'] ?? 'Not specified'),
        _InfoRow('Academic Year',    widget.data['acadYear'] ?? '2025-26'),
        _editing
          ? _EditableRow('Performance', _perfCtrl)
          : _InfoRow('Performance', _performance),
        _InfoRow('Admission No.',    widget.data['admNo'] ?? 'Not specified'),
        _InfoRow('Institution',      widget.data['institution'] ?? 'Not specified', last: true),
      ]),
      const SizedBox(height: 14),
      _CardSection(title: 'Health Snapshot', icon: Icons.health_and_safety_outlined, children: [
        _editing ? _EditableRow('Height', _heightCtrl) : _InfoRow('Height', _height),
        _editing ? _EditableRow('Weight', _weightCtrl, last: true) : _InfoRow('Weight', _weight, last: true),
      ]),
      if (widget.data['medHistory'] != null && widget.data['medHistory']!.isNotEmpty) ...[
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(color: _coral100, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.medication_outlined, size: 16, color: _coral500),
              SizedBox(width: 7),
              Text('Medical Notes', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: _coral500)),
            ]),
            const SizedBox(height: 8),
            Text(widget.data['medHistory']!, style: const TextStyle(fontSize: 14, color: _onSurface1, fontWeight: FontWeight.w500, height: 1.5)),
          ]),
        ),
      ],
      const SizedBox(height: 80),
    ]),
  );
}

class _EditableRow extends StatelessWidget {
  const _EditableRow(this.label, this.ctrl, {this.last = false});
  final String label;
  final TextEditingController ctrl;
  final bool last;
  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: last ? 0 : 12),
    child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      SizedBox(width: 130, child: Text(label, style: const TextStyle(fontSize: 13, color: _onSurface3, fontWeight: FontWeight.w600))),
      Expanded(child: TextField(
        controller: ctrl,
        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: _onSurface1),
        decoration: InputDecoration(
          isDense: true,
          filled: true, fillColor: _surface2,
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _brand600, width: 1.5)),
        ),
      )),
    ]),
  );
}
