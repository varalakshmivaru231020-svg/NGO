import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/open_bytes.dart';
import 'students_screen.dart' show findStudentRecord;

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
// Sponsor-picker donors are loaded live from the backend (see _fetchDonors).

class _StudentDetailScreenState extends State<StudentDetailScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late Map<String, String> _data;
  Uint8List? _photoBytes; // student's uploaded profile photo, shown in the header

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 6, vsync: this);
    _data = _resolveData(widget.id);
    _photoBytes = _resolvePhoto(widget.id);
  }

  // Decode the student's uploaded photo (base64) from their record, if any.
  Uint8List? _resolvePhoto(String id) {
    final rec = findStudentRecord(id);
    final raw = (rec?['photo'] ?? '').toString();
    if (raw.isEmpty) return null;
    try { return base64Decode(raw); } catch (_) { return null; }
  }

  // Resolve the student's own data: rich demo records first, then the live
  // student store (created enrollments + dataset). Never falls back to another
  // student, so each profile shows its own details.
  Map<String, String> _resolveData(String id) {
    if (_kChildren.containsKey(id)) return Map<String, String>.from(_kChildren[id]!);
    final rec = findStudentRecord(id);
    if (rec != null) return _dataFromRecord(id, rec);
    return _emptyData(id);
  }

  Map<String, String> _dataFromRecord(String id, Map<String, dynamic> r) {
    String s(String k) => (r[k] ?? '').toString();
    final gender = switch (s('gender')) { 'MALE' => 'Male', 'FEMALE' => 'Female', final g => g };
    const statusMap = {'ACTIVE': 'Active', 'GRADUATED': 'Graduated', 'INACTIVE': 'Relieved', 'DROPPED': 'Drop out'};
    final centre = ((r['center'] as Map?)?['name'] ?? '').toString();
    final sponsorships = (r['sponsorships'] as List?) ?? const [];
    final sponsorName = sponsorships.isNotEmpty
        ? (((sponsorships.first as Map?)?['donor'] as Map?)?['name'] ?? '').toString()
        : '';
    final age = _ageFromIso(s('dob'));
    // Prefer the explicit key, fall back to the backend's field name.
    String pick(String a, String b) => s(a).isNotEmpty ? s(a) : s(b);
    return {
      'childId':          s('childId').isNotEmpty ? s('childId') : id,
      'name':             s('name'),
      'centre':           centre,
      'age':              age.isNotEmpty ? age : '—',
      'gender':           gender.isNotEmpty ? gender : '—',
      'class':            s('class').isNotEmpty ? s('class') : '—',
      'status':           statusMap[s('status')] ?? (s('status').isNotEmpty ? s('status') : 'Active'),
      'dob':              s('dob'),
      'institution':      s('school'),
      'school':           s('school'),
      'sponsor':          sponsorName,
      'sponsorshipAmt':   sponsorName.isNotEmpty ? '—' : '—',
      'achievementCount': '0',
      // Detail fields shown on the Profile tab (local + backend field names).
      'admDate':     pick('admDate', 'admissionDate'),
      'father':      s('fatherName'),
      'mother':      s('motherName'),
      'guardian':    pick('guardian', 'guardianName'),
      'relation':    pick('relation', 'guardianRelation'),
      'mobile':      pick('mobile', 'guardianPhone'),
      'address':     s('address'),
      'familyNotes': pick('familyNotes', 'notes'),
      'height':      s('height'),
      'weight':      s('weight'),
      'medHistory':  pick('medHistory', 'medicalNotes'),
      // Identity & government IDs
      'aadhaar':          pick('aadhaar', 'aadhaarNumber'),
      'sat':              pick('sat', 'satNumber'),
      'penNumber':        s('penNumber'),
      'cwcNumber':        s('cwcNumber'),
      'abhaNumber':       s('abhaNumber'),
      'rationCardNumber': s('rationCardNumber'),
      'missionVatsalyaNumber': s('missionVatsalyaNumber'),
      'caste':            s('caste'),
      'subCaste':         s('subCaste'),
      // Financial / welfare
      'bankAccountDetails': s('bankAccountDetails'),
      'siblingNames':       s('siblingNames'),
      'incomeCertificateAmount':   s('incomeCertificateAmount'),
      'incomeCertificateRdNumber': s('incomeCertificateRdNumber'),
    };
  }

  Map<String, String> _emptyData(String id) => {
    'childId': id, 'name': 'Student', 'centre': '—', 'age': '—', 'gender': '—',
    'class': '—', 'status': 'Active', 'sponsor': '', 'sponsorshipAmt': '—', 'achievementCount': '0',
  };

  // Compute "N yrs" from an ISO yyyy-mm-dd date of birth.
  String _ageFromIso(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return '';
    final now = DateTime.now();
    var years = now.year - d.year;
    if (now.month < d.month || (now.month == d.month && now.day < d.day)) years--;
    return years >= 0 ? '$years yrs' : '';
  }

  Future<List<Map<String, dynamic>>> _fetchDonors() async {
    try {
      final res = await apiClient.get('/donors', params: {'limit': '100'});
      final inner = res['data'];
      final list = inner is List ? inner : (inner is Map ? (inner['data'] as List? ?? const []) : const []);
      return list.map((e) => (e as Map).cast<String, dynamic>()).toList();
    } catch (_) { return []; }
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
          Expanded(child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _fetchDonors(),
            builder: (c, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator(color: _brand600));
              }
              final donors = snap.data ?? const <Map<String, dynamic>>[];
              if (donors.isEmpty) {
                return const Center(child: Padding(padding: EdgeInsets.all(24),
                  child: Text('No donors yet. Add a donor first.', style: TextStyle(fontSize: 13.5, color: _onSurface3, fontWeight: FontWeight.w500))));
              }
              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                itemCount: donors.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final d = donors[i];
                  final name = (d['name'] ?? '') as String;
                  final city = (d['city'] ?? '') as String;
                  final id = (d['id'] ?? '') as String;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 6),
                    leading: Container(width: 44, height: 44,
                      decoration: const BoxDecoration(color: _brand100, shape: BoxShape.circle),
                      child: Center(child: Text(_initials(name), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _brand600)))),
                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                    subtitle: Text(city.isNotEmpty ? 'Donor · $city' : 'Donor', style: const TextStyle(fontSize: 12.5, color: _onSurface3)),
                    onTap: () {
                      final now = DateTime.now();
                      final dateStr = '${now.day.toString().padLeft(2,'0')} ${['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][now.month-1]} ${now.year}';
                      setState(() {
                        _data['sponsor']         = name;
                        _data['sponsorId']       = id;
                        _data['sponsorDonorId']  = id;
                        _data['sponsorCategory'] = 'Sponsor';
                        _data['sponsorCity']     = city;
                        _data['sponsorAmt']      = '';
                        _data['sponsorSince']    = dateStr;
                        _data['sponsorshipAmt']  = '—';
                      });
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('$name assigned as sponsor', style: const TextStyle(fontWeight: FontWeight.w700)),
                        backgroundColor: _brand600, behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
                    },
                  );
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

  // Backend enum ↔ display maps.
  static const _genderBack = {'Male': 'MALE', 'Female': 'FEMALE', 'Other': 'OTHER'};
  static const _statusBack = {'Active': 'ACTIVE', 'Graduated': 'GRADUATED', 'Relieved': 'INACTIVE', 'Drop out': 'DROPPED'};

  void _applyStatus(String status) {
    setState(() => _data['status'] = status);
    final rec = findStudentRecord(widget.id);
    if (rec != null) rec['status'] = _statusBack[status] ?? status;
  }

  Future<List<({String id, String name})>> _fetchCentres() async {
    try {
      final r = await apiClient.get('/students/centers');
      final list = (r['data'] as List<dynamic>? ?? const []);
      return list.whereType<Map>().map((m) => (id: m['id'] as String, name: m['name'] as String)).toList();
    } catch (_) { return const []; }
  }

  // Comprehensive edit sheet covering every field collected at enrolment
  // (Personal, Contact, Address, Guardian, Education, Health) — pre-filled
  // from the current record and persisted to the backend via PUT. Identity
  // & government-ID / financial fields have their own dedicated edit sheet
  // (_showIdentityEditSheet, opened from that section's own Edit button).
  void _showEditSheet(BuildContext context, Map<String, String> data) async {
    final centres = await _fetchCentres();
    if (!context.mounted) return;

    final nameCtrl      = TextEditingController(text: data['name']);
    final fatherCtrl    = TextEditingController(text: data['father']);
    final motherCtrl    = TextEditingController(text: data['mother']);
    final guardianCtrl  = TextEditingController(text: data['guardian']);
    final relationCtrl  = TextEditingController(text: data['relation']);
    final mobileCtrl    = TextEditingController(text: data['mobile']);
    final addressCtrl   = TextEditingController(text: data['address']);
    final schoolCtrl    = TextEditingController(text: data['school']);
    final classCtrl     = TextEditingController(text: data['class'] == '—' ? '' : data['class']);
    final medHistoryCtrl = TextEditingController(text: data['medHistory']);
    final familyNotesCtrl = TextEditingController(text: data['familyNotes']);
    String gender  = data['gender'] == 'Female' ? 'Female' : (data['gender'] == 'Other' ? 'Other' : 'Male');
    String status  = data['status'] ?? 'Active';
    String centre  = centres.any((c) => c.name == data['centre']) ? data['centre']! : (centres.isNotEmpty ? centres.first.name : '');
    String dob     = data['dob'] ?? '';
    String admDate = data['admDate'] ?? '';
    bool saving = false;

    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
        Widget sectionLabel(String text) => Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 10),
          child: Text(text, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _brand600, letterSpacing: 0.3)));

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

        Widget dateField(String label, String value, void Function(String) onPicked) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _onSurface2)),
            const SizedBox(height: 6),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () async {
                final initial = DateTime.tryParse(value) ?? DateTime.now();
                final picked = await showDatePicker(
                  context: ctx, initialDate: initial,
                  firstDate: DateTime(1990), lastDate: DateTime.now());
                if (picked != null) {
                  final iso = '${picked.year.toString().padLeft(4,'0')}-${picked.month.toString().padLeft(2,'0')}-${picked.day.toString().padLeft(2,'0')}';
                  setSheet(() => onPicked(iso));
                }
              },
              child: Container(
                height: 46, padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(color: _surface2, borderRadius: BorderRadius.circular(12)),
                child: Row(children: [
                  Expanded(child: Text(value.isEmpty ? 'Select date' : value,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: value.isEmpty ? _onSurface3 : _onSurface1))),
                  const Icon(Icons.calendar_today_outlined, size: 17, color: _onSurface3),
                ]),
              ),
            ),
          ]));

        Widget chips(String label, List<String> options, String selected, void Function(String) onSelected) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _onSurface2)),
            const SizedBox(height: 6),
            Wrap(spacing: 8, runSpacing: 8, children: options.map((o) {
              final active = selected == o;
              return GestureDetector(
                onTap: () => setSheet(() => onSelected(o)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(color: active ? _brand600 : _surface2, borderRadius: BorderRadius.circular(10)),
                  child: Text(o, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: active ? Colors.white : _onSurface2))));
            }).toList()),
          ]));

        return Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(ctx).viewInsets.bottom + 28),
          child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 36, height: 4, margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(2)))),
            const Text('Edit Student', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('All fields collected at enrolment can be edited here.',
              style: TextStyle(fontSize: 12.5, color: _onSurface3, fontWeight: FontWeight.w500)),

            sectionLabel('PERSONAL DETAILS'),
            field('Full Name', nameCtrl),
            dateField('Date of Birth', dob, (v) => dob = v),
            chips('Gender', const ['Male', 'Female', 'Other'], gender, (v) => gender = v),
            chips('Status', const ['Active', 'Graduated', 'Relieved', 'Drop out'], status, (v) => status = v),
            if (centres.isNotEmpty) chips('Centre', centres.map((c) => c.name).toList(), centre, (v) => centre = v),

            sectionLabel('GUARDIAN DETAILS'),
            field("Father's Name", fatherCtrl),
            field("Mother's Name", motherCtrl),
            field('Guardian Name', guardianCtrl),
            field('Relation to Child', relationCtrl),

            sectionLabel('CONTACT & ADDRESS'),
            field('Guardian Mobile', mobileCtrl, kb: TextInputType.phone),
            field('Address', addressCtrl, lines: 2),

            sectionLabel('EDUCATION DETAILS'),
            field('School / Institution', schoolCtrl),
            field('Class / Grade', classCtrl),
            dateField('Admission Date', admDate, (v) => admDate = v),

            sectionLabel('HEALTH & NOTES'),
            field('Medical History', medHistoryCtrl, lines: 2),
            field('Family Background Notes', familyNotesCtrl, lines: 2),

            const SizedBox(height: 6),
            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: saving ? null : () async {
                setSheet(() => saving = true);
                final centerId = centres.firstWhere(
                  (c) => c.name == centre, orElse: () => (id: '', name: '')).id;
                await _saveIdentityFields({
                  'name': nameCtrl.text.trim(),
                  if (dob.isNotEmpty) 'dob': dob,
                  'gender': _genderBack[gender] ?? 'MALE',
                  'status': _statusBack[status] ?? 'ACTIVE',
                  if (centerId.isNotEmpty) 'centerId': centerId,
                  'fatherName': fatherCtrl.text.trim(),
                  'motherName': motherCtrl.text.trim(),
                  'guardianName': guardianCtrl.text.trim(),
                  'guardianRelation': relationCtrl.text.trim(),
                  'guardianPhone': mobileCtrl.text.trim(),
                  'address': addressCtrl.text.trim(),
                  'school': schoolCtrl.text.trim(),
                  'class': classCtrl.text.trim(),
                  if (admDate.isNotEmpty) 'admissionDate': admDate,
                  'medicalNotes': medHistoryCtrl.text.trim(),
                  'notes': familyNotesCtrl.text.trim(),
                }, centreName: centre.isNotEmpty ? centre : null);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: const Text('Student updated successfully', style: TextStyle(fontWeight: FontWeight.w700)),
                    backgroundColor: _brand600, behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _brand600, foregroundColor: Colors.white, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 15)),
              child: saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : const Text('Save Changes', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            )),
          ])),
        );
      }),
    );
  }

  // Persist fields to the backend so edits survive a reload (PUT
  // /students/:id), then reflect them in the on-screen data + local cache.
  static const _genderDisplay = {'MALE': 'Male', 'FEMALE': 'Female', 'OTHER': 'Other'};
  static const _statusDisplay = {'ACTIVE': 'Active', 'GRADUATED': 'Graduated', 'INACTIVE': 'Relieved', 'DROPPED': 'Drop out'};

  Future<void> _saveIdentityFields(Map<String, dynamic> body, {String? centreName}) async {
    try {
      await apiClient.put('/students/${widget.id}', body);
    } catch (_) {
      // Best-effort: still reflect the edit locally so the UI isn't stuck,
      // even if the backend is briefly unreachable.
    }
    setState(() {
      body.forEach((k, v) {
        final val = v?.toString() ?? '';
        switch (k) {
          case 'aadhaarNumber': _data['aadhaar'] = val; break;
          case 'satNumber': _data['sat'] = val; break;
          case 'gender': _data['gender'] = _genderDisplay[val] ?? val; break;
          case 'status': _data['status'] = _statusDisplay[val] ?? val; break;
          case 'guardianName': _data['guardian'] = val; break;
          case 'guardianRelation': _data['relation'] = val; break;
          case 'centerId': break; // resolved via centreName below instead
          default: _data[k] = val;
        }
      });
      if (centreName != null) _data['centre'] = centreName;
    });
    final rec = findStudentRecord(widget.id);
    if (rec != null && centreName != null) rec['center'] = {'name': centreName};
    if (rec != null) body.forEach((k, v) => rec[k] = v);
  }

  void _showIdentityEditSheet(BuildContext context) {
    final pen        = TextEditingController(text: _data['penNumber']);
    final cwc        = TextEditingController(text: _data['cwcNumber']);
    final abha       = TextEditingController(text: _data['abhaNumber']);
    final ration     = TextEditingController(text: _data['rationCardNumber']);
    final vatsalya   = TextEditingController(text: _data['missionVatsalyaNumber']);
    final caste      = TextEditingController(text: _data['caste']);
    final subCaste   = TextEditingController(text: _data['subCaste']);
    final siblings   = TextEditingController(text: _data['siblingNames']);
    final bankInfo   = TextEditingController(text: _data['bankAccountDetails']);
    final incomeAmt  = TextEditingController(text: _data['incomeCertificateAmount']);
    final incomeRdNo = TextEditingController(text: _data['incomeCertificateRdNumber']);
    bool saving = false;

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
            const Text('Edit Identity Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            field('PEN Number', pen),
            field('CWC Number', cwc),
            field('ABHA Card Number', abha),
            field('Ration Card Number', ration),
            field('Mission Vatsalya Number', vatsalya),
            field('Caste', caste),
            field('Sub-caste', subCaste),
            field('Sibling Name(s)', siblings),
            field('Bank Account Details', bankInfo, lines: 2),
            field('Income Certificate Amount', incomeAmt, kb: TextInputType.number),
            field('Income Certificate RD Number', incomeRdNo),
            const SizedBox(height: 6),
            SizedBox(width: double.infinity, child: ElevatedButton(
              onPressed: saving ? null : () async {
                setSheet(() => saving = true);
                await _saveIdentityFields({
                  'penNumber': pen.text.trim(),
                  'cwcNumber': cwc.text.trim(),
                  'abhaNumber': abha.text.trim(),
                  'rationCardNumber': ration.text.trim(),
                  'missionVatsalyaNumber': vatsalya.text.trim(),
                  'caste': caste.text.trim(),
                  'subCaste': subCaste.text.trim(),
                  'siblingNames': siblings.text.trim(),
                  'bankAccountDetails': bankInfo.text.trim(),
                  'incomeCertificateAmount': int.tryParse(incomeAmt.text.trim()),
                  'incomeCertificateRdNumber': incomeRdNo.text.trim(),
                });
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: const Text('Identity details updated', style: TextStyle(fontWeight: FontWeight.w700)),
                    backgroundColor: _brand600, behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _brand600, foregroundColor: Colors.white, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 15)),
              child: saving
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : const Text('Save Changes', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
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
              _applyStatus(status);
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
                        gradient: _photoBytes == null ? LinearGradient(colors: [color, Color.lerp(color, Colors.black, 0.2)!]) : null,
                        color: _photoBytes != null ? Colors.white : null,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 3))],
                      ),
                      clipBehavior: Clip.hardEdge,
                      child: _photoBytes != null
                          ? Image.memory(_photoBytes!, fit: BoxFit.cover, width: 70, height: 70)
                          : Center(child: Text(_initials(name), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 24))),
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
            _ProfileTab(data: data, onEditIdentity: () => _showIdentityEditSheet(context)),
            _EducationTab(data: data, studentId: widget.id),
            _SponsorTab(data: data, onAssign: () => _showSponsorPicker(context)),
            _AchievementsTab(studentId: name),
            _DocumentsTab(studentId: widget.id),
            _ProgressTab(data: data, studentId: widget.id),
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
  const _ProfileTab({required this.data, required this.onEditIdentity});
  final Map<String, String> data;
  final VoidCallback onEditIdentity;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    physics: const BouncingScrollPhysics(),
    padding: const EdgeInsets.all(18),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Basic Profile
      _CardSection(title: 'Basic Profile', icon: Icons.person_outline, children: [
        _InfoRow('Child ID',          data['childId'] ?? '—'),
        _InfoRow('Centre',            (data['centre'] ?? '').isNotEmpty ? data['centre']! : '—'),
        _InfoRow('Date of Birth',     '${data['dob'] ?? ''} (${data['age'] ?? '—'})'),
        _InfoRow('Gender',            data['gender'] ?? '—'),
        _InfoRow('Aadhaar Number',    (data['aadhaar'] ?? '').isNotEmpty ? data['aadhaar']! : '—'),
        _InfoRow('Date of Admission', (data['admDate'] ?? '').isNotEmpty ? data['admDate']! : '—', last: true),
      ]),
      const SizedBox(height: 14),
      // Family Details
      _CardSection(title: 'Family Details', icon: Icons.family_restroom_outlined, children: [
        _InfoRow("Father's Name", (data['father'] ?? '').isNotEmpty ? data['father']! : '—'),
        _InfoRow("Mother's Name", (data['mother'] ?? '').isNotEmpty ? data['mother']! : '—'),
        _InfoRow('Guardian',      '${(data['guardian'] ?? '').isNotEmpty ? data['guardian']! : '—'}${(data['relation'] ?? '').isNotEmpty ? ' (${data['relation']})' : ''}'),
        _InfoRow('Mobile Number', (data['mobile'] ?? '').isNotEmpty ? data['mobile']! : '—'),
        _InfoRow('Address',       (data['address'] ?? '').isNotEmpty ? data['address']! : '—'),
        _InfoRow('SAT Number',    (data['sat'] ?? '').isNotEmpty ? data['sat']! : '—'),
        _InfoRow('Sibling Name(s)', (data['siblingNames'] ?? '').isNotEmpty ? data['siblingNames']! : '—', last: true),
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
      // Identity & Government IDs
      _CardSection(title: 'Identity & Government IDs', icon: Icons.badge_outlined,
        trailing: _sectionEditBtn(onEditIdentity),
        children: [
        _InfoRow('PEN Number',        (data['penNumber'] ?? '').isNotEmpty ? data['penNumber']! : '—'),
        _InfoRow('CWC Number',        (data['cwcNumber'] ?? '').isNotEmpty ? data['cwcNumber']! : '—'),
        _InfoRow('ABHA Card Number',  (data['abhaNumber'] ?? '').isNotEmpty ? data['abhaNumber']! : '—'),
        _InfoRow('Ration Card Number', (data['rationCardNumber'] ?? '').isNotEmpty ? data['rationCardNumber']! : '—'),
        _InfoRow('Mission Vatsalya Number', (data['missionVatsalyaNumber'] ?? '').isNotEmpty ? data['missionVatsalyaNumber']! : '—'),
        _InfoRow('Caste',             (data['caste'] ?? '').isNotEmpty ? data['caste']! : '—'),
        _InfoRow('Sub-caste',         (data['subCaste'] ?? '').isNotEmpty ? data['subCaste']! : '—', last: true),
      ]),
      const SizedBox(height: 14),
      // Financial & Welfare Details
      _CardSection(title: 'Financial & Welfare Details', icon: Icons.account_balance_outlined,
        trailing: _sectionEditBtn(onEditIdentity),
        children: [
        _InfoRow('Bank Account Details', (data['bankAccountDetails'] ?? '').isNotEmpty ? data['bankAccountDetails']! : '—'),
        _InfoRow('Income Certificate Amount', (data['incomeCertificateAmount'] ?? '').isNotEmpty ? '₹${data['incomeCertificateAmount']}' : '—'),
        _InfoRow('Income Cert. RD Number', (data['incomeCertificateRdNumber'] ?? '').isNotEmpty ? data['incomeCertificateRdNumber']! : '—', last: true),
      ]),
      const SizedBox(height: 14),
      // Health & Medical
      _CardSection(title: 'Health & Medical', icon: Icons.health_and_safety_outlined, children: [
        _InfoRow('Growth History', 'See the Progress tab for date-wise height/weight and the growth chart', last: true),
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
  const _EducationTab({required this.data, required this.studentId});
  final Map<String, String> data;
  final String studentId;
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
      _SingleDocSlot(studentId: studentId, category: 'Educational Documents',
        sublabel: 'Report cards, certificates, TC', icon: Icons.description_outlined),
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
                  child: Text(editing == null ? 'Save Achievement' : 'Update', style: const TextStyle(fontWeight: FontWeight.w800)),
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
          Text('${list.length} Achievement${list.length == 1 ? '' : 's'}',
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
                Text('Add Achievement', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
              ]),
            ),
          ),
        ]),
      ),
      if (list.isEmpty)
        Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.photo_library_outlined, size: 44, color: _onSurface3),
          const SizedBox(height: 12),
          const Text('No achievements yet', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: _onSurface3)),
          const SizedBox(height: 6),
          const Text('Tap + to add an achievement', style: TextStyle(fontSize: 13, color: _onSurface3)),
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
class _StudentDoc {
  _StudentDoc({required this.id, required this.category, required this.fileName, this.mimeType});
  final String id, category, fileName;
  final String? mimeType;
  factory _StudentDoc.fromJson(Map<String, dynamic> j) => _StudentDoc(
    id: j['id'] as String, category: j['category'] as String,
    fileName: j['fileName'] as String, mimeType: j['mimeType'] as String?);
}

const _fixedDocCategories = [
  ('Aadhaar Card',        Icons.credit_card_outlined),
  ('Birth Certificate',   Icons.article_outlined),
  ('Transfer Certificate', Icons.transfer_within_a_station_outlined),
  ('Medical Reports',     Icons.medical_services_outlined),
  ('School Report Card',  Icons.school_outlined),
];

class _DocumentsTab extends StatefulWidget {
  const _DocumentsTab({required this.studentId});
  final String studentId;
  @override
  State<_DocumentsTab> createState() => _DocumentsTabState();
}

class _DocumentsTabState extends State<_DocumentsTab> {
  List<_StudentDoc> _docs = [];
  bool _loading = true;
  bool _uploadingOther = false;
  String? _uploadingCategory;
  String? _viewingId;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final r = await apiClient.get('/students/${widget.studentId}/documents');
      final list = (r['data'] as List<dynamic>? ?? const []);
      final docs = list.whereType<Map>().map((m) => _StudentDoc.fromJson(m.cast<String, dynamic>())).toList();
      if (mounted) setState(() { _docs = docs; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _upload(String category) async {
    setState(() => _uploadingCategory = category);
    try {
      final result = await FilePicker.platform.pickFiles(allowMultiple: false, withData: true);
      final bytes = result?.files.single.bytes;
      if (result != null && bytes != null && mounted) {
        final name = result.files.single.name;
        await apiClient.post('/students/${widget.studentId}/documents', {
          'category': category, 'fileName': name, 'data': base64Encode(bytes),
        });
        await _load();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$name uploaded successfully', style: const TextStyle(fontWeight: FontWeight.w700)),
          backgroundColor: _brand600, behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Upload failed — check your connection and try again', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: _coral500, behavior: SnackBarBehavior.floating));
    }
    if (mounted) setState(() => _uploadingCategory = null);
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
    setState(() => _uploadingOther = true);
    await _upload(name);
    if (mounted) setState(() => _uploadingOther = false);
  }

  Future<void> _view(_StudentDoc d) async {
    setState(() => _viewingId = d.id);
    try {
      final r = await apiClient.get('/students/documents/${d.id}');
      final data = (r['data'] as Map).cast<String, dynamic>();
      final b64 = data['data'] as String? ?? '';
      if (b64.isNotEmpty) openBytesInBrowser(base64Decode(b64), d.fileName);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not open document', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: _coral500, behavior: SnackBarBehavior.floating));
    }
    if (mounted) setState(() => _viewingId = null);
  }

  Future<void> _delete(_StudentDoc d) async {
    try { await apiClient.delete('/students/documents/${d.id}'); } catch (_) {}
    await _load();
  }

  Widget _docRow({required String label, required IconData icon, _StudentDoc? doc, required VoidCallback onUpload}) {
    final uploaded = doc != null;
    final uploading = _uploadingCategory == label;
    final viewing = doc != null && _viewingId == doc.id;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: _border)),
        child: Row(children: [
          Container(width: 44, height: 44,
            decoration: BoxDecoration(color: uploaded ? _brand100 : _surface2, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, size: 22, color: uploaded ? _brand600 : _onSurface3)),
          const SizedBox(width: 13),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Row(children: [
              Container(width: 6, height: 6, decoration: BoxDecoration(
                color: uploaded ? _brand600 : _onSurface3, shape: BoxShape.circle)),
              const SizedBox(width: 5),
              Expanded(child: Text(
                uploaded ? doc.fileName : 'Not uploaded',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600,
                  color: uploaded ? _brand600 : _onSurface3))),
            ]),
          ])),
          const SizedBox(width: 10),
          if (uploading)
            const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: _brand600))
          else if (uploaded) ...[
            GestureDetector(
              onTap: viewing ? null : () => _view(doc),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: _brand100, borderRadius: BorderRadius.circular(8)),
                child: viewing
                  ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: _brand600))
                  : const Text('View', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _brand600)),
              ),
            ),
            GestureDetector(
              onTap: () => _delete(doc),
              child: const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.close, size: 18, color: _coral500)),
            ),
          ] else
            GestureDetector(
              onTap: onUpload,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: _brand100, borderRadius: BorderRadius.circular(10), border: Border.all(color: _brand600.withValues(alpha: 0.3))),
                child: const Text('Upload', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _brand600)),
              ),
            ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _StudentDoc? findDoc(String category) {
      for (final d in _docs) { if (d.category == category) return d; }
      return null;
    }
    final fixedCategories = _fixedDocCategories.map((c) => c.$1).toSet();
    final otherDocs = _docs.where((d) => !fixedCategories.contains(d.category)).toList();
    final uploadedCount = _docs.length;

    if (_loading) {
      return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: _brand600)));
    }
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header row: upload button left, count badge right
        Row(children: [
          GestureDetector(
            onTap: _uploadingOther ? null : _uploadOther,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: _brand600, borderRadius: BorderRadius.circular(8)),
              child: _uploadingOther
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

        // Fixed document categories
        ..._fixedDocCategories.map((c) => _docRow(label: c.$1, icon: c.$2, doc: findDoc(c.$1), onUpload: () => _upload(c.$1))),

        // Extra uploaded files
        ...otherDocs.map((d) => _docRow(label: d.category, icon: Icons.insert_drive_file_outlined, doc: d, onUpload: () {})),

        const SizedBox(height: 80),
      ]),
    );
  }
}

// ── shared widgets ─────────────────────────────────────────────────────
class _CardSection extends StatelessWidget {
  const _CardSection({required this.title, required this.icon, required this.children, this.trailing});
  final String title; final IconData icon; final List<Widget> children; final Widget? trailing;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: _border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Row(children: [
          Icon(icon, size: 17, color: _brand600),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: _onSurface1))),
          if (trailing != null) trailing!,
        ]),
      ),
      const Divider(height: 1, color: _border),
      ...children,
    ]),
  );
}

Widget _sectionEditBtn(VoidCallback onTap) => GestureDetector(
  onTap: onTap, behavior: HitTestBehavior.opaque,
  child: Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: _brand100, borderRadius: BorderRadius.circular(8)),
    child: const Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.edit_outlined, size: 13, color: _brand600),
      SizedBox(width: 4),
      Text('Edit', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: _brand600)),
    ]),
  ),
);

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

// A single named document slot (e.g. Educational Documents on the Education
// tab) backed by the same student-documents API as the Documents tab —
// fetches its own uploaded/not-uploaded state and supports upload/view/delete.
class _SingleDocSlot extends StatefulWidget {
  const _SingleDocSlot({required this.studentId, required this.category, required this.sublabel, required this.icon});
  final String studentId, category, sublabel;
  final IconData icon;
  @override
  State<_SingleDocSlot> createState() => _SingleDocSlotState();
}

class _SingleDocSlotState extends State<_SingleDocSlot> {
  _StudentDoc? _doc;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final r = await apiClient.get('/students/${widget.studentId}/documents');
      final list = (r['data'] as List<dynamic>? ?? const []);
      final docs = list.whereType<Map>().map((m) => _StudentDoc.fromJson(m.cast<String, dynamic>())).toList();
      _StudentDoc? found;
      for (final d in docs) { if (d.category == widget.category) { found = d; break; } }
      if (mounted) setState(() { _doc = found; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _upload() async {
    setState(() => _busy = true);
    try {
      final result = await FilePicker.platform.pickFiles(allowMultiple: false, withData: true);
      final bytes = result?.files.single.bytes;
      if (result != null && bytes != null) {
        await apiClient.post('/students/${widget.studentId}/documents', {
          'category': widget.category, 'fileName': result.files.single.name, 'data': base64Encode(bytes),
        });
        await _load();
      }
    } catch (_) {}
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _view() async {
    final doc = _doc;
    if (doc == null) return;
    setState(() => _busy = true);
    try {
      final r = await apiClient.get('/students/documents/${doc.id}');
      final data = (r['data'] as Map).cast<String, dynamic>();
      final b64 = data['data'] as String? ?? '';
      if (b64.isNotEmpty) openBytesInBrowser(base64Decode(b64), doc.fileName);
    } catch (_) {}
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _delete() async {
    final doc = _doc;
    if (doc == null) return;
    try { await apiClient.delete('/students/documents/${doc.id}'); } catch (_) {}
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final uploaded = _doc != null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: _border)),
      child: Row(children: [
        Container(width: 44, height: 44, decoration: BoxDecoration(color: _brand100, borderRadius: BorderRadius.circular(12)), child: Icon(widget.icon, color: _brand600, size: 22)),
        const SizedBox(width: 13),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.category, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
          Text(uploaded ? _doc!.fileName : widget.sublabel, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5, color: _onSurface3, fontWeight: FontWeight.w500)),
        ])),
        if (_loading)
          const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: _brand600))
        else if (_busy)
          const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: _brand600))
        else if (uploaded) ...[
          GestureDetector(
            onTap: _view,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: _brand100, borderRadius: BorderRadius.circular(8)),
              child: const Text('View', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _brand600)),
            ),
          ),
          GestureDetector(onTap: _delete, child: const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.close, size: 18, color: _coral500))),
        ] else
          GestureDetector(
            onTap: _upload,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: _brand100, borderRadius: BorderRadius.circular(10), border: Border.all(color: _brand600.withValues(alpha: 0.3))),
              child: const Text('Upload', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _brand600)),
            ),
          ),
      ]),
    );
  }
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
  const _ProgressTab({required this.data, required this.studentId});
  final Map<String, String> data;
  final String studentId;
  @override
  State<_ProgressTab> createState() => _ProgressTabState();
}

class _GrowthRecord {
  _GrowthRecord({required this.id, required this.date, this.heightCm, this.weightKg});
  final String id;
  final DateTime date;
  final double? heightCm;
  final double? weightKg;

  factory _GrowthRecord.fromJson(Map<String, dynamic> j) => _GrowthRecord(
    id: j['id'] as String,
    date: DateTime.parse(j['date'] as String),
    heightCm: (j['heightCm'] as num?)?.toDouble(),
    weightKg: (j['weightKg'] as num?)?.toDouble(),
  );

  String get dateLabel {
    const m = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${date.day.toString().padLeft(2,'0')} ${m[date.month-1]} ${date.year}';
  }
}

class _ProgressTabState extends State<_ProgressTab> {
  late String _performance = widget.data['performance'] ?? 'Not specified';
  bool _editing = false;
  late final _perfCtrl = TextEditingController(text: _performance);

  List<_GrowthRecord> _growth = [];
  bool _loadingGrowth = true;

  @override
  void initState() { super.initState(); _loadGrowth(); }

  @override
  void dispose() { _perfCtrl.dispose(); super.dispose(); }

  Future<void> _loadGrowth() async {
    if (mounted) setState(() => _loadingGrowth = true);
    try {
      final r = await apiClient.get('/students/${widget.studentId}/growth');
      final list = (r['data'] as List<dynamic>? ?? const []);
      final records = list.whereType<Map>().map((m) => _GrowthRecord.fromJson(m.cast<String, dynamic>())).toList();
      if (mounted) setState(() { _growth = records; _loadingGrowth = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingGrowth = false);
    }
  }

  Future<void> _deleteGrowthRecord(String id) async {
    try { await apiClient.delete('/students/growth/$id'); } catch (_) {}
    await _loadGrowth();
  }

  void _showAddGrowthDialog(BuildContext context) {
    DateTime date = DateTime.now();
    final heightCtrl = TextEditingController();
    final weightCtrl = TextEditingController();
    bool saving = false;

    showDialog(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, setDlg) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: const Text('Add Growth Record', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        GestureDetector(
          onTap: () async {
            final picked = await showDatePicker(context: ctx, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime.now());
            if (picked != null) setDlg(() => date = picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(color: _surface2, borderRadius: BorderRadius.circular(12)),
            child: Row(children: [
              const Icon(Icons.calendar_today_outlined, size: 16, color: _onSurface2),
              const SizedBox(width: 10),
              Text('${date.day.toString().padLeft(2,'0')}/${date.month.toString().padLeft(2,'0')}/${date.year}',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: heightCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: 'Height (cm)', filled: true, fillColor: _surface2,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: weightCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: 'Weight (kg)', filled: true, fillColor: _surface2,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
        ),
      ]),
      actions: [
        TextButton(onPressed: saving ? null : () => Navigator.pop(ctx), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: saving ? null : () async {
            final h = double.tryParse(heightCtrl.text.trim());
            final w = double.tryParse(weightCtrl.text.trim());
            if (h == null && w == null) return;
            setDlg(() => saving = true);
            final iso = '${date.year.toString().padLeft(4,'0')}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}';
            try {
              await apiClient.post('/students/${widget.studentId}/growth', {
                'date': iso,
                if (h != null) 'heightCm': h,
                if (w != null) 'weightKg': w,
              });
            } catch (_) {}
            if (ctx.mounted) Navigator.pop(ctx);
            await _loadGrowth();
          },
          style: ElevatedButton.styleFrom(backgroundColor: _brand600, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
          child: saving
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Text('Save'),
        ),
      ],
    )));
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    physics: const BouncingScrollPhysics(),
    padding: const EdgeInsets.all(18),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('Progress Overview', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _onSurface1)),
        GestureDetector(
          onTap: () {
            setState(() {
              if (_editing) _performance = _perfCtrl.text.trim().isNotEmpty ? _perfCtrl.text.trim() : _performance;
              _editing = !_editing;
            });
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
      if (widget.data['medHistory'] != null && widget.data['medHistory']!.isNotEmpty) ...[
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
        const SizedBox(height: 14),
      ],
      // ── Growth History ───────────────────────────────────────────
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        const Text('Growth History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _onSurface1)),
        GestureDetector(
          onTap: () => _showAddGrowthDialog(context),
          behavior: HitTestBehavior.opaque,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(color: _brand600, borderRadius: BorderRadius.circular(10)),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.add_rounded, size: 16, color: Colors.white),
              SizedBox(width: 4),
              Text('Add Record', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white)),
            ]),
          ),
        ),
      ]),
      const SizedBox(height: 12),
      if (_loadingGrowth)
        const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: CircularProgressIndicator(color: _brand600)))
      else if (_growth.isEmpty)
        Container(
          width: double.infinity, padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border)),
          child: const Center(child: Text('No growth records yet — tap Add Record to log the first height/weight entry.',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: _onSurface3, fontWeight: FontWeight.w600))),
        )
      else ...[
        _GrowthChart(records: _growth),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border)),
          child: Column(children: _growth.reversed.toList().asMap().entries.map((e) {
            final r = e.value;
            final isLast = e.key == _growth.length - 1;
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: isLast ? null : const BoxDecoration(border: Border(bottom: BorderSide(color: _border))),
              child: Row(children: [
                Expanded(child: Text(r.dateLabel, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _onSurface1))),
                Expanded(child: Text(r.heightCm != null ? '${r.heightCm!.toStringAsFixed(1)} cm' : '—',
                  style: const TextStyle(fontSize: 13, color: _onSurface2, fontWeight: FontWeight.w600))),
                Expanded(child: Text(r.weightKg != null ? '${r.weightKg!.toStringAsFixed(1)} kg' : '—',
                  style: const TextStyle(fontSize: 13, color: _onSurface2, fontWeight: FontWeight.w600))),
                GestureDetector(
                  onTap: () => _deleteGrowthRecord(r.id),
                  child: const Icon(Icons.delete_outline, size: 18, color: _coral500),
                ),
              ]),
            );
          }).toList()),
        ),
      ],
      const SizedBox(height: 80),
    ]),
  );
}

// ── Growth chart: height + weight over time, dual y-axes ──────────────
class _GrowthChart extends StatelessWidget {
  const _GrowthChart({required this.records});
  final List<_GrowthRecord> records;

  @override
  Widget build(BuildContext context) {
    final heightSpots = <FlSpot>[];
    final weightSpots = <FlSpot>[];
    for (var i = 0; i < records.length; i++) {
      final r = records[i];
      if (r.heightCm != null) heightSpots.add(FlSpot(i.toDouble(), r.heightCm!));
      if (r.weightKg != null) weightSpots.add(FlSpot(i.toDouble(), r.weightKg!));
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 18, 16, 10),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(left: 6, bottom: 8), child: Row(children: [
          _LegendDot(color: _brand600, label: 'Height (cm)'),
          const SizedBox(width: 16),
          _LegendDot(color: _coral500, label: 'Weight (kg)'),
        ])),
        SizedBox(
          height: 180,
          child: LineChart(LineChartData(
            gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 10,
              getDrawingHorizontalLine: (_) => const FlLine(color: _border, strokeWidth: 1)),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 34,
                getTitlesWidget: (v, meta) => Text(v.toInt().toString(), style: const TextStyle(fontSize: 10, color: _onSurface3)))),
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28,
                getTitlesWidget: (v, meta) {
                  final i = v.toInt();
                  if (i < 0 || i >= records.length) return const SizedBox.shrink();
                  // Thin out labels so they don't overlap on longer histories.
                  if (records.length > 6 && i % (records.length / 5).ceil() != 0) return const SizedBox.shrink();
                  final d = records[i].date;
                  return Padding(padding: const EdgeInsets.only(top: 6),
                    child: Text('${d.day}/${d.month}', style: const TextStyle(fontSize: 10, color: _onSurface3)));
                })),
            ),
            lineBarsData: [
              if (heightSpots.isNotEmpty)
                LineChartBarData(spots: heightSpots, isCurved: true, color: _brand600, barWidth: 2.5,
                  dotData: const FlDotData(show: true), belowBarData: BarAreaData(show: false)),
              if (weightSpots.isNotEmpty)
                LineChartBarData(spots: weightSpots, isCurved: true, color: _coral500, barWidth: 2.5,
                  dotData: const FlDotData(show: true), belowBarData: BarAreaData(show: false)),
            ],
          )),
        ),
      ]),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color; final String label;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 5),
    Text(label, style: const TextStyle(fontSize: 11.5, color: _onSurface2, fontWeight: FontWeight.w600)),
  ]);
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
