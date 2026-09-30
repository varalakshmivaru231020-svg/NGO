import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/open_bytes.dart';
import '../../../core/utils/native_file_saver.dart';
import '../../../core/widgets/lazy_photo.dart';
import '../../../core/widgets/photo_picker_widget.dart';
import '../student_lookups.dart';
import 'students_screen.dart' show findStudentRecord, loadedStudents;
import 'student_report_generator.dart';
import 'add_student_screen.dart' show StudentDocumentSheet, PickedStudentDoc, studentDocMime, studentDocIcon;
import 'package:saksham_app/core/ui/ui.dart';

// ── colours ───────────────────────────────────────────────────────────
const _brand700 = Color(0xFFE07C1F);
const _brand600 = Color(0xFFFF9933);
const _brand100 = Color(0xFFFFE8CC);
const _violet500 = Color(0xFF7C6CF0);
const _amber600 = Color(0xFFE0921A);
const _coral500 = Color(0xFFF2685E);
const _sky500 = Color(0xFF2D9CDB);
const _sky100 = Color(0xFFDCEFFB);
const _danger = Color(0xFFE5484D);
// NOTE: surface/text/border colors are theme-aware — sourced from
// context.textPrimary/textSub/textHint/border/surface2/cardBg/scaffoldBg
// (see core/theme/app_theme.dart) instead of local hardcoded constants.

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
// Indian-style digit grouping, e.g. 1234567 -> "12,34,567".
String _groupThousands(int n) {
  final s = n.toString();
  if (s.length <= 3) return s;
  final last3 = s.substring(s.length - 3);
  var rest = s.substring(0, s.length - 3);
  final parts = <String>[];
  while (rest.length > 2) { parts.insert(0, rest.substring(rest.length - 2)); rest = rest.substring(0, rest.length - 2); }
  if (rest.isNotEmpty) parts.insert(0, rest);
  return '${parts.join(',')},$last3';
}
// Icon + hint for the long-standing statuses in the Update Status sheet;
// admin-added statuses get a generic icon and no hint.
const _statusHints = <String, (String, IconData)>{
  'ACTIVE':    ('Currently enrolled and attending', Icons.check_circle_outline),
  'GRADUATED': ('Completed the programme',          Icons.school_outlined),
  'INACTIVE':  ('Left on own / family request',     Icons.logout_rounded),
  'DROPPED':   ('Left without completing',          Icons.cancel_outlined),
  'FORMER':    ('Former student of the programme',  Icons.history_edu_outlined),
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
  // True once _data comes from a real record (list cache or GET /students/:id)
  // rather than the "Student / — / 0" placeholder.
  bool _hasRecord = false;
  bool _fetching = false;
  String? _fetchError;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 6, vsync: this);
    _hasRecord = _kChildren.containsKey(widget.id) || findStudentRecord(widget.id) != null;
    _data = _resolveData(widget.id);
    _photoBytes = _resolvePhoto(widget.id);
    StudentLookups.load().then((_) {
      if (mounted) setState(_refreshLookupLabels);
    });
    _fetchRecord();
  }

  // The list cache only holds what the last list load returned (and list rows
  // carry no photo), so after a page refresh or right after adding a child
  // the profile would show placeholders. Always load the full record.
  Future<void> _fetchRecord() async {
    if (widget.id.startsWith('local-') || _kChildren.containsKey(widget.id)) return;
    setState(() { _fetching = true; _fetchError = null; });
    try {
      final r = await apiClient.get('/students/${widget.id}');
      final raw = r['data'];
      if (raw is! Map) throw StateError('Unexpected response');
      final full = raw.cast<String, dynamic>();
      // Keep the shared cache in step so the list / later opens agree.
      final rec = findStudentRecord(widget.id);
      if (rec != null) {
        rec.addAll(full);
      } else {
        loadedStudents.add(Map<String, dynamic>.from(full));
      }
      if (!mounted) return;
      setState(() {
        _data = _dataFromRecord(widget.id, rec ?? full);
        _refreshLookupLabels();
        final photo = decodePhoto(full['photo'] as String?);
        if (photo != null) _photoBytes = photo;
        _hasRecord = true;
        _fetching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _fetching = false;
        _fetchError = ApiClient.errorMessage(e, fallback: 'Could not load this child');
      });
      // Cached data is still on screen — just flag that it may be stale.
      if (_hasRecord) _snackMsg('Could not refresh this profile: $_fetchError', isError: true);
    }
  }

  // Labels come from the admin-managed lists; re-derive them once loaded so a
  // rename in Settings shows here too.
  void _refreshLookupLabels() {
    final key = _data['statusKey'];
    if (key != null && key.isNotEmpty) _data['status'] = StudentLookups.statusLabel(key);
    final catId = _data['categoryId'] ?? '';
    if (catId.isNotEmpty) {
      final l = StudentLookups.categoryLabel(catId);
      if (l != '—') _data['category'] = l;
    }
  }

  // Decode the student's uploaded photo (base64) from their record, if any.
  Uint8List? _resolvePhoto(String id) =>
      decodePhoto(findStudentRecord(id)?['photo']?.toString());

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
    final center = r['center'];
    final centre = center is Map ? (center['name'] ?? '').toString() : '';
    final sponsorships = r['sponsorships'] is List ? r['sponsorships'] as List : const [];
    final firstSp = sponsorships.isNotEmpty && sponsorships.first is Map ? sponsorships.first as Map : null;
    final donor = firstSp?['donor'] is Map ? firstSp!['donor'] as Map : null;
    final sponsorName = (donor?['name'] ?? '').toString();
    final spAmount = firstSp?['amount'];
    final spAmountStr = spAmount is num && spAmount > 0
        ? '₹${_groupThousands(spAmount.round())}${firstSp?['frequency'] == 'MONTHLY' ? ' / month' : ' / year'}'
        : '';
    final spSince = DateTime.tryParse((firstSp?['startDate'] ?? '').toString());
    final age = _ageFromIso(s('dob'));
    // Prefer the backend's field name (what GET /students and every edit
    // write), falling back to the key used by not-yet-synced local records —
    // otherwise a stale local value would win over a later edit (even one
    // that cleared the field).
    String pick(String backend, String local) => r[backend] != null ? s(backend) : s(local);
    final cat = r['category'];
    final categoryId = ((cat is Map ? cat['id'] : null) ?? r['categoryId'] ?? '').toString();
    var category = cat is Map ? (cat['label'] ?? '').toString() : '';
    if (category.isEmpty && categoryId.isNotEmpty) {
      final l = StudentLookups.categoryLabel(categoryId);
      if (l != '—') category = l;
    }
    final statusKey = s('status').isNotEmpty ? s('status') : 'ACTIVE';
    return {
      'childId':          s('childId').isNotEmpty ? s('childId') : id,
      'name':             s('name'),
      'centre':           centre,
      'centerId':         ((center is Map ? center['id'] : null) ?? r['centerId'] ?? '').toString(),
      // Admin-managed support category (Settings → Student Categories).
      'category':         category,
      'categoryId':       categoryId,
      'age':              age.isNotEmpty ? age : '—',
      'gender':           gender.isNotEmpty ? gender : '—',
      'class':            s('class').isNotEmpty ? s('class') : '—',
      // Stable key + its current label (Settings → Student Status).
      'statusKey':        statusKey,
      'status':           StudentLookups.statusLabel(statusKey),
      // Key from Settings → Education Level ('' = not set).
      'educationLevelKey': s('educationLevel'),
      'dob':              s('dob'),
      'institution':      s('school'),
      'school':           s('school'),
      'sponsor':          sponsorName,
      'sponsorId':        (donor?['id'] ?? '').toString(),
      'sponsorDonorId':   (donor?['donorCode'] ?? donor?['id'] ?? '').toString(),
      if (spAmountStr.isNotEmpty) 'sponsorAmt': spAmountStr,
      if (spSince != null) 'sponsorSince': _fmtDate(spSince),
      'sponsorshipAmt':   spAmountStr.isNotEmpty ? spAmountStr : '—',
      'achievementCount': ((r['_count'] is Map ? (r['_count'] as Map)['achievements'] : null) ?? 0).toString(),
      // Detail fields shown on the Profile tab (backend + local field names).
      'admDate':     pick('admissionDate', 'admDate'),
      // Education Details tab
      'admNo':       pick('admissionNo', 'admNo'),
      'acadYear':    pick('academicYear', 'acadYear'),
      'joiningDate': s('joiningDate'),
      'section':     s('section'),
      'permanence':  s('permanence'),
      'studentType': s('studentType'),
      'eduRemarks':  s('educationRemarks'),
      'createdAt':   s('createdAt'),
      'updatedAt':   s('updatedAt'),
      'father':      pick('fatherName', 'father'),
      'mother':      pick('motherName', 'mother'),
      'guardian':    pick('guardianName', 'guardian'),
      'relation':    pick('guardianRelation', 'relation'),
      'mobile':      pick('guardianPhone', 'mobile'),
      'address':     s('address'),
      'familyNotes': pick('notes', 'familyNotes'),
      'height':      s('height'),
      'weight':      s('weight'),
      'medHistory':  pick('medicalNotes', 'medHistory'),
      // Identity & government IDs
      'aadhaar':          pick('aadhaarNumber', 'aadhaar'),
      'sat':              pick('satNumber', 'sat'),
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
    'class': '—', 'statusKey': 'ACTIVE', 'status': StudentLookups.statusLabel('ACTIVE'),
    'sponsor': '', 'sponsorshipAmt': '—', 'achievementCount': '0',
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
      // Paged — a single page hid donor #101+ from the sponsor picker.
      final all = <dynamic>[];
      Map<String, dynamic> res = const {};
      for (int page = 1; ; page++) {
        res = await apiClient.get('/donors', params: {'limit': '100', 'page': '$page'});
        final inner = res['data'];
        final pageList = inner is List ? inner : <dynamic>[];
        all.addAll(pageList);
        final meta = res['meta'] as Map?;
        if (meta?['hasNext'] != true || pageList.isEmpty) break;
      }
      res = {'data': all};
      final inner = res['data'];
      final list = inner is List ? inner : (inner is Map ? (inner['data'] as List? ?? const []) : const []);
      return list.map((e) => (e as Map).cast<String, dynamic>()).toList();
    } catch (_) { return []; }
  }

  void _showSponsorPicker(BuildContext context) {
    final donorsFuture = _fetchDonors();
    showAppSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(ctx).size.height * 0.6,
        decoration: BoxDecoration(color: context.cardBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
        child: Column(children: [
          const SheetHandle(margin: EdgeInsets.only(top: 10)),
          Padding(padding: const EdgeInsets.fromLTRB(20, 10, 8, 6), child: Row(children: [
            const Expanded(child: Text('Select sponsor', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
            IconButton(tooltip: 'Close', icon: Icon(Icons.close_rounded, size: 20, color: context.textSub),
                onPressed: () => Navigator.pop(ctx)),
          ])),
          Divider(height: 1, color: context.border),
          Expanded(child: FutureBuilder<List<Map<String, dynamic>>>(
            future: donorsFuture,
            builder: (c, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const SingleChildScrollView(child: SkeletonList(rows: 5, rowHeight: 56));
              }
              final donors = snap.data ?? const <Map<String, dynamic>>[];
              if (donors.isEmpty) {
                return const Center(child: EmptyState(
                  icon: Icons.person_search_outlined,
                  title: 'No donors yet',
                  message: 'Add a donor first, then assign them here.',
                ));
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                itemCount: donors.length,
                itemBuilder: (_, i) {
                  final d = donors[i];
                  final name = (d['name'] ?? '').toString();
                  final city = (d['city'] ?? '').toString();
                  final id = (d['id'] ?? '').toString();
                  return ListTile(
                    dense: true,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    leading: Container(width: 34, height: 34,
                      decoration: BoxDecoration(color: _brand100, borderRadius: BorderRadius.circular(9)),
                      child: Center(child: Text(_initials(name), style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _brand600)))),
                    title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text(city.isNotEmpty ? 'Donor · $city' : 'Donor', style: TextStyle(fontSize: 12, color: context.textHint)),
                    trailing: Icon(Icons.chevron_right, size: 18, color: context.textHint),
                    onTap: () {
                      Navigator.pop(ctx);
                      _assignSponsor(donorId: id, name: name, city: city);
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

  // Asks for the annual sponsorship amount (required by the backend) and
  // persists the assignment via POST /students/:id/sponsorships. The amount
  // sheet shows its own loading state and stays open (amount kept) if the
  // request fails.
  Future<void> _assignSponsor({required String donorId, required String name, required String city}) async {
    final amount = await showAppSheet<int>(
      context: context, backgroundColor: Colors.transparent,
      builder: (_) => _SponsorAmountSheet(
        donorName: name,
        onSubmit: (amount) => apiClient.post('/students/${widget.id}/sponsorships', {
          'donorId': donorId,
          'amount': amount,
          'frequency': 'ANNUAL',
        }),
      ),
    );
    if (amount == null || !mounted) return;

    final now = DateTime.now();
    final dateStr = '${now.day.toString().padLeft(2,'0')} ${['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][now.month-1]} ${now.year}';
    final amtStr = '₹${_groupThousands(amount)} / year';
    setState(() {
      _data['sponsor']         = name;
      _data['sponsorId']       = donorId;
      _data['sponsorDonorId']  = donorId;
      _data['sponsorCategory'] = 'Sponsor';
      _data['sponsorCity']     = city;
      _data['sponsorAmt']      = amtStr;
      _data['sponsorSince']    = dateStr;
      _data['sponsorshipAmt']  = amtStr;
    });
    // Keep the cached list record in sync so re-opening this profile without
    // a fresh /students fetch still shows the sponsor.
    final rec = findStudentRecord(widget.id);
    if (rec != null) {
      rec['sponsorships'] = [
        {'donor': {'id': donorId, 'name': name, 'mobile': ''}, 'amount': amount},
      ];
    }
    AppToast.success(context, 'Sponsor assigned', detail: name);
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<List<({String id, String name})>> _fetchCentres() async {
    try {
      final r = await apiClient.get('/students/centers');
      final list = (r['data'] as List<dynamic>? ?? const []);
      return list.whereType<Map>()
          .where((m) => m['id'] != null)
          .map((m) => (id: m['id'].toString(), name: (m['name'] ?? '').toString())).toList();
    } catch (_) { return const []; }
  }

  // Outcome of a save: saved, or queued for Super Admin approval.
  void _toastSaved(bool saved, String okMsg) {
    if (!mounted) return;
    if (saved) {
      AppToast.success(context, okMsg);
    } else {
      AppToast.warning(context, 'Submitted for Super Admin approval', detail: 'The change applies once it is approved.');
    }
  }

  // Current values keyed by the backend field names PUT /students/:id takes,
  // normalised for the edit form (dates as YYYY-MM-DD, '—' as empty).
  Map<String, String> _editInitial() {
    String v(String k) { final x = (_data[k] ?? '').trim(); return x == '—' ? '' : x; }
    String d(String k) {
      final x = v(k);
      return x.length >= 10 && DateTime.tryParse(x) != null ? x.substring(0, 10) : x;
    }
    return {
      'name': v('name'),
      'gender': switch (v('gender')) { 'Male' => 'MALE', 'Female' => 'FEMALE', 'Other' => 'OTHER', final g => g.toUpperCase() },
      'dob': d('dob'),
      'centerId': v('centerId'),
      'categoryId': v('categoryId'),
      'status': v('statusKey'),
      'admissionDate': d('admDate'),
      'fatherName': v('father'),
      'motherName': v('mother'),
      'guardianName': v('guardian'),
      'guardianRelation': v('relation'),
      'guardianPhone': v('mobile'),
      'address': v('address'),
      'siblingNames': v('siblingNames'),
      'notes': v('familyNotes'),
      'educationLevel': v('educationLevelKey'),
      'school': v('school').isNotEmpty ? v('school') : v('institution'),
      'class': v('class'),
      'section': v('section'),
      'admissionNo': v('admNo'),
      'academicYear': v('acadYear'),
      'joiningDate': d('joiningDate'),
      'permanence': v('permanence'),
      'studentType': v('studentType'),
      'educationRemarks': v('eduRemarks'),
      'aadhaarNumber': v('aadhaar'),
      'satNumber': v('sat'),
      'penNumber': v('penNumber'),
      'cwcNumber': v('cwcNumber'),
      'abhaNumber': v('abhaNumber'),
      'rationCardNumber': v('rationCardNumber'),
      'missionVatsalyaNumber': v('missionVatsalyaNumber'),
      'caste': v('caste'),
      'subCaste': v('subCaste'),
      'medicalNotes': v('medHistory'),
      'bankAccountDetails': v('bankAccountDetails'),
      'incomeCertificateAmount': v('incomeCertificateAmount'),
      'incomeCertificateRdNumber': v('incomeCertificateRdNumber'),
    };
  }

  // Edit every field PUT /students/:id accepts — all sections (header Edit)
  // or just one (a card's Edit button). Only changed fields are sent; on
  // success the record is re-read from GET /students/:id.
  Future<void> _openEditor([_EditSection? only]) async {
    final result = await showAppSheet<bool>(
      context: context, backgroundColor: Colors.transparent,
      builder: (_) => _StudentEditSheet(
        initial: _editInitial(),
        centreName: _data['centre'] ?? '',
        categoryLabel: _data['category'] ?? '',
        statusLabel: _data['status'] ?? '',
        photo: _photoBytes,
        sections: only == null ? _EditSection.values.toList() : [only],
        loadCentres: _fetchCentres,
        onSave: (body, {centreName, categoryLabel}) async {
          final saved = await _saveIdentityFields(body, centreName: centreName, categoryLabel: categoryLabel);
          final photo = body['photo'];
          if (saved && photo is String && mounted) {
            evictLazyPhoto('/students/${widget.id}/photo');
            setState(() => _photoBytes = photo.isEmpty ? null : decodePhoto(photo));
          }
          return saved;
        },
      ),
    );
    if (result == null || !mounted) return;
    _toastSaved(result, only == null ? 'Student updated' : '${only.title} updated');
    if (result) _fetchRecord();
  }

  // Persist fields to the backend so edits survive a reload (PUT
  // /students/:id), then reflect them in the on-screen data + local cache.
  static const _genderDisplay = {'MALE': 'Male', 'FEMALE': 'Female', 'OTHER': 'Other'};

  // Returns true when saved, false when the backend queued the change for
  // Super Admin approval (nothing is applied locally then). Throws on
  // failure — callers show ApiClient.errorMessage(e).
  Future<bool> _saveIdentityFields(Map<String, dynamic> body, {String? centreName, String? categoryLabel}) async {
    final res = await apiClient.put('/students/${widget.id}', body);
    if ((res['meta'] as Map?)?['pendingApproval'] == true) return false;
    if (!mounted) return true;
    setState(() {
      // Backend field name → the UI key the tabs read.
      body.forEach((k, v) {
        final val = v?.toString() ?? '';
        switch (k) {
          case 'aadhaarNumber': _data['aadhaar'] = val; break;
          case 'satNumber': _data['sat'] = val; break;
          case 'gender': _data['gender'] = _genderDisplay[val] ?? val; break;
          case 'status':
            _data['statusKey'] = val;
            _data['status'] = StudentLookups.statusLabel(val);
            break;
          case 'educationLevel': _data['educationLevelKey'] = val; break;
          case 'fatherName': _data['father'] = val; break;
          case 'motherName': _data['mother'] = val; break;
          case 'guardianName': _data['guardian'] = val; break;
          case 'guardianRelation': _data['relation'] = val; break;
          case 'guardianPhone': _data['mobile'] = val; break;
          case 'medicalNotes': _data['medHistory'] = val; break;
          case 'notes': _data['familyNotes'] = val; break;
          case 'admissionDate': _data['admDate'] = val; break;
          case 'school': _data['school'] = val; _data['institution'] = val; break;
          case 'admissionNo': _data['admNo'] = val; break;
          case 'academicYear': _data['acadYear'] = val; break;
          case 'educationRemarks': _data['eduRemarks'] = val; break;
          case 'class': _data['class'] = val.isEmpty ? '—' : val; break;
          case 'dob':
            _data['dob'] = val;
            final age = _ageFromIso(val);
            _data['age'] = age.isNotEmpty ? age : '—';
            break;
          case 'photo': break;    // shown via _photoBytes, never kept as text
          case 'centerId': _data['centerId'] = val; break; // name via centreName below
          default: _data[k] = val;
        }
      });
      if (centreName != null) _data['centre'] = centreName;
      if (categoryLabel != null) _data['category'] = categoryLabel;
    });
    final rec = findStudentRecord(widget.id);
    if (rec != null && centreName != null) rec['center'] = {'id': body['centerId'], 'name': centreName};
    // Keep the cached record's nested shape in sync so _dataFromRecord (and
    // the list card) re-derive the same label after navigation.
    if (rec != null && categoryLabel != null) {
      rec['category'] = categoryLabel.isEmpty ? null : {'id': body['categoryId'], 'label': categoryLabel};
    }
    if (rec != null) body.forEach((k, v) => rec[k] = v);
    return true;
  }

  // Options come from Settings → Student Status; the chosen key is saved via
  // PUT /students/:id.
  Future<void> _showStatusSheet(BuildContext context, String currentKey) async {
    await StudentLookups.load();
    if (!context.mounted) return;
    String status = currentKey;
    bool saving = false;
    String? error;
    final statuses = [
      for (final o in _withCurrent(StudentLookups.statuses, currentKey, StudentLookups.statusLabel(currentKey)))
        (o.key, o.label, _statusHints[o.key]?.$1 ?? '', _statusHints[o.key]?.$2 ?? Icons.label_outline,
          StudentLookups.statusColor(o.key)),
    ];
    final saved = await showAppSheet<bool>(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) {
        Future<void> save() async {
          if (saving) return;
          if (status == currentKey) { Navigator.pop(ctx); return; }
          setSt(() { saving = true; error = null; });
          try {
            final ok = await _saveIdentityFields({'status': status});
            if (ctx.mounted) Navigator.pop(ctx, ok);
          } catch (e) {
            // Keep the sheet open with the server's reason.
            if (ctx.mounted) setSt(() { saving = false; error = ApiClient.errorMessage(e); });
          }
        }
        return Container(
          decoration: BoxDecoration(color: context.cardBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
          padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SheetHandle(margin: EdgeInsets.only(bottom: 10)),
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Update status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text("Update the child's enrolment status.", style: TextStyle(fontSize: 12.5, color: context.textSub)),
              ])),
              IconButton(tooltip: 'Close', icon: Icon(Icons.close_rounded, size: 20, color: context.textSub),
                  onPressed: saving ? null : () => Navigator.pop(ctx)),
            ]),
            const SizedBox(height: 12),
            ...statuses.map((s) {
              final (key, label, hint, icon, col) = s;
              final sel = status == key;
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: saving ? null : () => setSt(() => status = key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    constraints: const BoxConstraints(minHeight: 52),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? col.withValues(alpha: 0.08) : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: sel ? col : context.border, width: sel ? 1.5 : 1),
                    ),
                    child: Row(children: [
                      Container(width: 30, height: 30,
                        decoration: BoxDecoration(color: col.withValues(alpha: sel ? 0.18 : 0.08), borderRadius: BorderRadius.circular(8)),
                        child: Icon(icon, color: col, size: 16)),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Text(label, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: context.textPrimary)),
                        if (hint.isNotEmpty)
                          Text(hint, style: TextStyle(fontSize: 12, color: context.textHint)),
                      ])),
                      Icon(sel ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                          color: sel ? col : context.textHint, size: 18),
                    ]),
                  ),
                ),
              );
            }),
            const SizedBox(height: 6),
            if (error != null) Padding(padding: const EdgeInsets.only(bottom: 10), child: _InlineError(error!)),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              AppButton(label: 'Cancel', variant: AppButtonVariant.secondary,
                  onPressed: saving ? null : () => Navigator.pop(ctx)),
              const SizedBox(width: 8),
              AppButton(label: 'Save Status', busyLabel: 'Saving…', loading: saving, onPressed: save),
            ]),
          ])),
        );
      }),
    );
    if (saved == null || !mounted) return;
    _toastSaved(saved, 'Status updated to ${StudentLookups.statusLabel(status)}');
  }

  void _snackMsg(String msg, {bool isError = false}) {
    if (!mounted) return;
    if (isError) {
      AppToast.error(context, msg);
    } else {
      AppToast.success(context, msg);
    }
  }
  // Full profile PDF — includes live achievements fetched at download time.
  Future<void> _downloadReport() async {
    AppToast.info(context, 'Preparing report…');
    var achievements = <StudentAchievementRow>[];
    try {
      final r = await apiClient.get('/achievements', params: {'studentId': widget.id, 'limit': '100'});
      final list = ((r['data'] is Map ? (r['data'] as Map)['data'] : r['data']) as List? ?? []);
      const catDisplay = {'ARTS': 'Arts', 'SPORTS': 'Sports', 'ACADEMICS': 'Academics', 'COMMUNITY': 'Community', 'LIFE_SKILLS': 'Leadership', 'OTHER': 'Other'};
      achievements = list.map((a) => StudentAchievementRow(
        date:     (a as Map)['date'] as String? ?? '',
        title:    a['title'] as String? ?? '',
        category: catDisplay[a['category']] ?? (a['category'] as String? ?? 'Other'),
      )).toList();
    } catch (_) {
      // Offline or endpoint unavailable — the report still carries the profile.
    }
    // Latest height/weight from Growth History — the profile map only carries
    // demo values, real measurements live in growth records.
    final data = Map<String, String>.from(_data);
    // Labels (not keys) from the admin-managed lists for the PDF.
    data['status'] = StudentLookups.statusLabel(_data['statusKey'] ?? 'ACTIVE');
    data['educationLevel'] = StudentLookups.educationLabel(_data['educationLevelKey']);
    final catId = _data['categoryId'] ?? '';
    if (catId.isNotEmpty && StudentLookups.categoryLabel(catId) != '—') {
      data['category'] = StudentLookups.categoryLabel(catId);
    }
    try {
      final r = await apiClient.get('/students/${widget.id}/growth');
      final list = (r['data'] as List? ?? []).whereType<Map>().toList();
      Map? latest; DateTime? latestDt;
      for (final g in list) {
        final dt = DateTime.tryParse(g['date'] as String? ?? '');
        if (dt != null && (latestDt == null || dt.isAfter(latestDt))) { latestDt = dt; latest = g; }
      }
      if (latest != null) {
        String num_(Object? n) => n is num ? (n % 1 == 0 ? '${n.toInt()}' : '$n') : '$n';
        final parts = <String>[
          if (latest['heightCm'] != null) '${num_(latest['heightCm'])} cm',
          if (latest['weightKg'] != null) '${num_(latest['weightKg'])} kg',
        ];
        if (parts.isNotEmpty) {
          if (latest['heightCm'] != null) data['height'] = '${num_(latest['heightCm'])} cm';
          if (latest['weightKg'] != null) data['weight'] = '${num_(latest['weightKg'])} kg';
          final d = latestDt!;
          data['growthLine'] =
            '${parts.join(' / ')} recorded ${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
        }
      }
    } catch (_) {/* section falls back to profile height/weight */}
    try {
      final bytes = await buildStudentReportPdf(data: data, photo: _photoBytes, achievements: achievements);
      final childId = (_data['childId'] ?? widget.id).replaceAll(RegExp(r'[^A-Za-z0-9-]'), '_');
      final dateStr = DateTime.now().toIso8601String().split('T').first.replaceAll('-', '');
      final ok = await NativeFileSaver.saveBytes('SKET_Student_${childId}_$dateStr.pdf', bytes, 'application/pdf');
      _snackMsg(ok ? '✓ Student report downloaded' : 'Failed to save the report', isError: !ok);
    } catch (_) {
      _snackMsg('Failed to generate the report', isError: true);
    }
  }

  Future<void> _downloadPhoto() async {
    final bytes = _photoBytes;
    if (bytes == null || bytes.isEmpty) {
      _snackMsg('No profile photo uploaded yet — add one via Edit.', isError: true);
      return;
    }
    // PNG magic bytes → .png, everything else the picker produces is JPEG.
    final isPng = bytes.length > 4 && bytes[0] == 0x89 && bytes[1] == 0x50;
    final childId = (_data['childId'] ?? widget.id).replaceAll(RegExp(r'[^A-Za-z0-9-]'), '_');
    final ok = await NativeFileSaver.saveBytes(
      'SKET_Student_${childId}_photo.${isPng ? 'png' : 'jpg'}', bytes, isPng ? 'image/png' : 'image/jpeg');
    _snackMsg(ok ? '✓ Profile photo downloaded' : 'Failed to save the photo', isError: !ok);
  }

  void _showDownloadSheet(BuildContext context) {
    showAppSheet(
      context: context, backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 12, 16),
        decoration: BoxDecoration(color: ctx.cardBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SheetHandle(margin: EdgeInsets.only(bottom: 10)),
          Row(children: [
            const Expanded(child: Text('Download', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
            IconButton(tooltip: 'Close', icon: Icon(Icons.close_rounded, size: 20, color: ctx.textSub), onPressed: () => Navigator.pop(ctx)),
          ]),
          const SizedBox(height: 4),
          ListTile(
            dense: true,
            contentPadding: const EdgeInsets.only(right: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            leading: Container(width: 36, height: 36,
              decoration: BoxDecoration(color: _brand100, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.picture_as_pdf_outlined, color: _brand600, size: 18)),
            title: const Text('Student Report (PDF)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: Text('Full profile with photo, family, education & achievements',
                style: TextStyle(fontSize: 12, color: ctx.textHint, fontWeight: FontWeight.w500)),
            onTap: () { Navigator.pop(ctx); _downloadReport(); },
          ),
          ListTile(
            dense: true,
            contentPadding: const EdgeInsets.only(right: 8),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            leading: Container(width: 36, height: 36,
              decoration: BoxDecoration(color: _sky100, borderRadius: BorderRadius.circular(12)),
              child: const Icon(Icons.photo_outlined, color: _sky500, size: 18)),
            title: const Text('Profile Photo', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
            subtitle: Text(_photoBytes != null ? 'Save the photo as an image file' : 'No photo uploaded yet',
                style: TextStyle(fontSize: 12, color: ctx.textHint, fontWeight: FontWeight.w500)),
            onTap: () { Navigator.pop(ctx); _downloadPhoto(); },
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final name = data['name'] ?? '';
    final color = _avColor(name);

    // Opened by URL / right after adding: nothing cached yet, so wait for
    // GET /students/:id instead of showing "Student", "—", 0.
    if (!_hasRecord && (_fetching || _fetchError != null)) {
      return Scaffold(
        backgroundColor: context.scaffoldBg,
        appBar: AppBar(
          backgroundColor: _brand700,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            onPressed: () => context.go('/students'),
          ),
        ),
        body: _fetching
          ? SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Row(children: [
                  Skeleton(width: 56, height: 56, radius: 14),
                  SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Skeleton(width: 180, height: 14),
                    SizedBox(height: 8),
                    Skeleton(width: 120, height: 10),
                  ])),
                ]),
                const SizedBox(height: 18),
                Container(
                  decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: context.border)),
                  child: const SkeletonList(rows: 5, rowHeight: 56),
                ),
              ]),
            )
          : Center(child: ErrorState(message: _fetchError!, onRetry: _fetchRecord)),
      );
    }

    return Scaffold(
      backgroundColor: context.scaffoldBg,
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
              IconButton(icon: const Icon(Icons.download_rounded, color: Colors.white),
                tooltip: 'Download report / photo',
                onPressed: () => _showDownloadSheet(context)),
              IconButton(icon: const Icon(Icons.edit_outlined, color: Colors.white),
                tooltip: 'Edit all details',
                onPressed: () => _openEditor()),
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
              onUpdate: () => _showStatusSheet(context, data['statusKey'] ?? 'ACTIVE'),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabs,
          children: [
            _ProfileTab(data: data, onEdit: _openEditor),
            _EducationTab(data: data, onEdit: _openEditor),
            _SponsorTab(data: data, onAssign: () => _showSponsorPicker(context)),
            _AchievementsTab(studentId: widget.id),
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
  const _ProfileTab({required this.data, required this.onEdit});
  final Map<String, String> data;
  final void Function(_EditSection section) onEdit;

  String _v(String k) => (data[k] ?? '').isNotEmpty ? data[k]! : '—';

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    physics: const BouncingScrollPhysics(),
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _CardSection(title: 'Basic Profile', icon: Icons.person_outline,
        trailing: _sectionEditBtn(() => onEdit(_EditSection.basic)),
        children: [
        _InfoRow('Child ID',          data['childId'] ?? '—'),
        _InfoRow('Centre',            _v('centre')),
        _InfoRow('Category',          _v('category')),
        _InfoRow('Date of Birth',     '${_naDate(data['dob']) == _notAvailable ? _v('dob') : _naDate(data['dob'])} (${data['age'] ?? '—'})'),
        _InfoRow('Gender',            data['gender'] ?? '—'),
        _InfoRow('Status',            data['status'] ?? '—'),
        _InfoRow('Date of Admission', _naDate(data['admDate']) == _notAvailable ? _v('admDate') : _naDate(data['admDate']), last: true),
      ]),
      const SizedBox(height: 12),
      _CardSection(title: 'Family & Guardian', icon: Icons.family_restroom_outlined,
        trailing: _sectionEditBtn(() => onEdit(_EditSection.family)),
        children: [
        _InfoRow("Father's Name", _v('father')),
        _InfoRow("Mother's Name", _v('mother')),
        _InfoRow('Guardian',      '${_v('guardian')}${(data['relation'] ?? '').isNotEmpty ? ' (${data['relation']})' : ''}'),
        _InfoRow('Mobile Number', _v('mobile')),
        _InfoRow('Address',       _v('address')),
        _InfoRow('Sibling Name(s)', _v('siblingNames'), last: (data['familyNotes'] ?? '').isEmpty),
        if ((data['familyNotes'] ?? '').isNotEmpty)
          _InfoRow('Family Background', data['familyNotes']!, last: true),
      ]),
      const SizedBox(height: 12),
      _CardSection(title: 'Identity & Government IDs', icon: Icons.badge_outlined,
        trailing: _sectionEditBtn(() => onEdit(_EditSection.identity)),
        children: [
        _InfoRow('Aadhaar Number',    _v('aadhaar')),
        _InfoRow('SAT Number',        _v('sat')),
        _InfoRow('PEN Number',        _v('penNumber')),
        _InfoRow('CWC Number',        _v('cwcNumber')),
        _InfoRow('ABHA Card Number',  _v('abhaNumber')),
        _InfoRow('Ration Card Number', _v('rationCardNumber')),
        _InfoRow('Mission Vatsalya Number', _v('missionVatsalyaNumber')),
        _InfoRow('Caste',             _v('caste')),
        _InfoRow('Sub-caste',         _v('subCaste'), last: true),
      ]),
      const SizedBox(height: 12),
      _CardSection(title: 'Financial & Welfare', icon: Icons.account_balance_outlined,
        trailing: _sectionEditBtn(() => onEdit(_EditSection.financial)),
        children: [
        _InfoRow('Bank Account Details', _v('bankAccountDetails')),
        _InfoRow('Income Certificate Amount', (data['incomeCertificateAmount'] ?? '').isNotEmpty ? '₹${data['incomeCertificateAmount']}' : '—'),
        _InfoRow('Income Cert. RD Number', _v('incomeCertificateRdNumber'), last: true),
      ]),
      const SizedBox(height: 12),
      _CardSection(title: 'Health & Medical', icon: Icons.health_and_safety_outlined,
        trailing: _sectionEditBtn(() => onEdit(_EditSection.health)),
        children: [
        _InfoRow('Medical History', _v('medHistory')),
        _InfoRow('Growth History', 'See the Progress tab for date-wise height/weight and the growth chart', last: true),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        Icon(Icons.folder_outlined, size: 14, color: context.textHint),
        const SizedBox(width: 6),
        Expanded(child: Text('Certificates, ID copies and reports live in the Documents tab.',
            style: TextStyle(fontSize: 12, color: context.textHint))),
      ]),
      const SizedBox(height: 80),
    ]),
  );
}

// ══════════════════════════════════════════════════════════════════════
// EDUCATION TAB
// ══════════════════════════════════════════════════════════════════════
class _EducationTab extends StatelessWidget {
  const _EducationTab({required this.data, required this.onEdit});
  final Map<String, String> data;
  final void Function(_EditSection section) onEdit;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    physics: const BouncingScrollPhysics(),
    padding: const EdgeInsets.all(16),
    child: Column(children: [
      _CardSection(title: 'Education Details', icon: Icons.school_outlined,
        trailing: _sectionEditBtn(() => onEdit(_EditSection.education)),
        children: [
        _InfoRow('Admission No.',    _na(data['admNo'])),
        _InfoRow('Education Level',  _na(StudentLookups.educationLabel(data['educationLevelKey']))),
        _InfoRow('Academic Year',    _na(data['acadYear'])),
        _InfoRow('Admission Date',   _naDate(data['admDate'])),
        _InfoRow('Joining Date',     _naDate(data['joiningDate'])),
        _InfoRow('Current Class',    _na(data['class'])),
        _InfoRow('Section',          _na(data['section'])),
        _InfoRow('School',           _na(data['school'] ?? data['institution'])),
        _InfoRow('Permanence',       _na(data['permanence'])),
        _InfoRow('Student Type',     _na(data['studentType'])),
        _InfoRow('Education Status', _na(data['status'])),
        _InfoRow('Remarks',          _na(data['eduRemarks'])),
        _InfoRow('Created Date',     _naDate(data['createdAt'])),
        _InfoRow('Updated Date',     _naDate(data['updatedAt']), last: true),
      ]),
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
            color: context.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.border),
          ),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_brand700, _brand600]),
                shape: BoxShape.circle,
              ),
              child: Center(child: Text(_initials(sponsor), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18))),
            ),
            const SizedBox(width: 13),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(sponsor, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: context.textPrimary)),
              const SizedBox(height: 3),
              Text(
                city.isNotEmpty ? '$category · $city' : category,
                style: TextStyle(fontSize: 12.5, color: context.textHint, fontWeight: FontWeight.w600),
              ),
            ])),
            AppButton(label: 'View Profile', variant: AppButtonVariant.ghost, dense: true,
                onPressed: donorId.isEmpty ? null : () => context.go('/donors/$donorId')),
          ]),
        ),
        const SizedBox(height: 10),

        // ── Sponsorship details ─────────────────────────────────────
        Container(
          decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: context.border)),
          child: Column(children: [
            _SpnRow('Sponsorship ID (Donor ID)', sponsorId, first: true),
            _SpnRow('Sponsorship Amount', amount),
            _SpnRow('Start Date', since),
            _SpnRow('Sponsorship Status', 'Active', valueBold: true, valueColor: _brand600, last: true),
          ]),
        ),
        const SizedBox(height: 14),

        // ── Change sponsor ─────────────────────────────────────────
        Align(
          alignment: Alignment.centerRight,
          child: AppButton(label: 'Change Sponsor', icon: Icons.swap_horiz_rounded,
              variant: AppButtonVariant.secondary, onPressed: onAssign),
        ),
        const SizedBox(height: 18),

        // ── Sponsorship history ─────────────────────────────────────
        Text('SPONSORSHIP HISTORY', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900, color: context.textHint, letterSpacing: 1.0)),
        const SizedBox(height: 12),
        _TimelineEvent(
          dot: _brand600,
          title: 'Sponsorship active',
          sub: '$sponsor · since $since',
          isFirst: true,
        ),
        _TimelineEvent(
          dot: context.textHint,
          title: 'Enrolled into programme',
          sub: enrollDate,
          isLast: true,
        ),
        const SizedBox(height: 80),
      ]),
    );
  }

  Widget _noSponsor(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(children: [
      _card(context, EmptyState(
        icon: Icons.favorite_border,
        title: 'No sponsor assigned',
        message: 'Assign a donor from the donor list to sponsor this child.',
        actionLabel: 'Assign Sponsor',
        onAction: onAssign,
      )),
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
      border: last ? null : Border(bottom: BorderSide(color: context.border)),
    ),
    child: Row(children: [
      Expanded(child: Text(label, style: TextStyle(fontSize: 13, color: context.textHint, fontWeight: FontWeight.w600))),
      Text(value, style: TextStyle(fontSize: 13.5, fontWeight: valueBold ? FontWeight.w800 : FontWeight.w700, color: valueColor ?? context.textPrimary)),
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
        if (!isLast) Expanded(child: Container(width: 1.5, color: context.border, margin: const EdgeInsets.symmetric(vertical: 3))),
      ])),
      const SizedBox(width: 12),
      Expanded(child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: context.textPrimary)),
          const SizedBox(height: 2),
          Text(sub, style: TextStyle(fontSize: 12.5, color: context.textHint, fontWeight: FontWeight.w500)),
        ]),
      )),
    ]),
  );
}


// ══════════════════════════════════════════════════════════════════════
// ACHIEVEMENTS TAB
// ══════════════════════════════════════════════════════════════════════
// ── student activity model ────────────────────────────────────────────
class _AchRecord {
  String id, title, description, category;
  DateTime date;
  _AchRecord({required this.id, required this.title, this.description = '', required this.category, required this.date});

  factory _AchRecord.fromJson(Map<String, dynamic> j) => _AchRecord(
    id: j['id'] as String,
    title: j['title'] as String? ?? '',
    description: j['description'] as String? ?? '',
    category: j['category'] as String? ?? 'OTHER',
    date: DateTime.tryParse(j['date'] as String? ?? '') ?? DateTime.now(),
  );
}

class _AchievementsTab extends StatefulWidget {
  const _AchievementsTab({required this.studentId});
  final String studentId;
  @override
  State<_AchievementsTab> createState() => _AchievementsTabState();
}

class _AchievementsTabState extends State<_AchievementsTab> {
  // Display label ↔ backend enum. "Leadership" keeps the existing UI
  // wording while mapping to the backend's LIFE_SKILLS category.
  static const _catBack = {'Arts': 'ARTS', 'Sports': 'SPORTS', 'Academics': 'ACADEMICS', 'Community': 'COMMUNITY', 'Leadership': 'LIFE_SKILLS', 'Other': 'OTHER'};
  static const _catDisplay = {'ARTS': 'Arts', 'SPORTS': 'Sports', 'ACADEMICS': 'Academics', 'COMMUNITY': 'Community', 'LIFE_SKILLS': 'Leadership', 'OTHER': 'Other'};
  static const _cats = ['Arts', 'Sports', 'Academics', 'Community', 'Leadership', 'Other'];

  static Color _catFg(String displayCat) => switch (displayCat) {
    'Arts'       => _amber600,
    'Sports'     => _sky500,
    'Academics'  => _violet500,
    'Community'  => _brand600,
    _            => _coral500,
  };

  List<_AchRecord> _all = [];
  bool _loading = true;
  String _search = '';
  String _catFilter = 'All';
  int? _yearFilter;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load({bool quiet = false}) async {
    if (mounted && !quiet) setState(() => _loading = true);
    try {
      final r = await apiClient.get('/achievements', params: {'studentId': widget.studentId, 'limit': '100'});
      final inner = r['data'];
      final list = inner is Map ? (inner['data'] as List<dynamic>? ?? const []) : (inner is List ? inner : const []);
      final records = list.whereType<Map>().map((m) => _AchRecord.fromJson(m.cast<String, dynamic>())).toList();
      if (mounted) setState(() { _all = records; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<_AchRecord> get _filtered {
    var list = _all;
    if (_search.trim().isNotEmpty) {
      final q = _search.trim().toLowerCase();
      list = list.where((a) => a.title.toLowerCase().contains(q)).toList();
    }
    if (_catFilter != 'All') list = list.where((a) => _catDisplay[a.category] == _catFilter).toList();
    if (_yearFilter != null) list = list.where((a) => a.date.year == _yearFilter).toList();
    return list;
  }

  Set<int> get _years => _all.map((a) => a.date.year).toSet();

  Future<void> _delete(_AchRecord a) async {
    final ok = await AppConfirm.show(
      context,
      title: 'Delete achievement?',
      message: 'Are you sure you want to delete “${a.title}”? This action cannot be undone.',
      onConfirm: () => apiClient.delete('/achievements/${a.id}'),
      errorText: (e) => ApiClient.errorMessage(e, fallback: 'Could not delete the achievement.'),
    );
    if (!ok || !mounted) return;
    AppToast.success(context, 'Achievement deleted');
    setState(() => _all.remove(a));
    _load(quiet: true);
  }

  void _openSheet({_AchRecord? editing}) {
    final formKey = GlobalKey<FormState>();
    final titleCtrl = TextEditingController(text: editing?.title ?? '');
    final descCtrl  = TextEditingController(text: editing?.description ?? '');
    String cat = editing != null ? (_catDisplay[editing.category] ?? 'Arts') : 'Arts';
    DateTime date = editing?.date ?? DateTime.now();
    bool saving = false;
    String? error;

    showAppSheet(
      context: context, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, ss) {
        Future<void> save() async {
          if (saving) return;
          ss(() => error = null);
          if (!formKey.currentState!.validate()) return;
          ss(() => saving = true);
          final body = {
            'title': titleCtrl.text.trim(),
            'description': descCtrl.text.trim(),
            'category': _catBack[cat] ?? 'OTHER',
            'date': date.toIso8601String(),
          };
          final Map<String, dynamic> res;
          try {
            res = editing == null
              ? await apiClient.post('/achievements', {'studentId': widget.studentId, ...body})
              : await apiClient.put('/achievements/${editing.id}', body);
          } catch (e) {
            // Sheet stays open with everything typed.
            if (ctx.mounted) ss(() { saving = false; error = ApiClient.errorMessage(e); });
            return;
          }
          if (ctx.mounted) Navigator.pop(ctx);
          final pending = (res['meta'] as Map?)?['pendingApproval'] == true;
          if (mounted) {
            _showResultSnack(context, pending ? 'Submitted for Super Admin approval'
                : (editing == null ? 'Achievement added' : 'Achievement updated'), pending: pending);
          }
          await _load(quiet: true);
        }

        Widget label(String t, {bool required = false}) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text.rich(TextSpan(children: [
            TextSpan(text: t),
            if (required) const TextSpan(text: ' *', style: TextStyle(color: _danger)),
          ]), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: context.textSub)));

        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(color: context.cardBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Form(
              key: formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                const SheetHandle(margin: EdgeInsets.only(bottom: 10)),
                Row(children: [
                  Expanded(child: Text(editing == null ? 'Add achievement' : 'Edit achievement',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                  IconButton(tooltip: 'Close', icon: Icon(Icons.close_rounded, size: 20, color: context.textSub),
                      onPressed: saving ? null : () => Navigator.pop(ctx)),
                ]),
                const SizedBox(height: 12),
                label('Category'),
                Wrap(spacing: 6, runSpacing: 6, children: _cats.map((c) {
                  final sel = cat == c;
                  return InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: saving ? null : () => ss(() => cat = c),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: sel ? _brand100 : context.surface2,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: sel ? _brand600.withValues(alpha: 0.6) : context.border),
                      ),
                      child: Text(c, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: sel ? _brand600 : context.textSub)),
                    ),
                  );
                }).toList()),
                const SizedBox(height: 12),
                label('Title', required: true),
                TextFormField(
                  controller: titleCtrl,
                  autofocus: editing == null,
                  enabled: !saving,
                  textCapitalization: TextCapitalization.sentences,
                  validator: (v) => (v ?? '').trim().isEmpty ? 'Please enter a title.' : null,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  decoration: const InputDecoration(hintText: 'e.g. Annual Sports Day'),
                ),
                const SizedBox(height: 12),
                label('Date'),
                InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: saving ? null : () async {
                    final picked = await showDatePicker(context: ctx, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime.now());
                    if (picked != null) ss(() => date = picked);
                  },
                  child: Container(
                    height: 42,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: Theme.of(context).inputDecorationTheme.fillColor ?? context.cardBg,
                      borderRadius: BorderRadius.circular(10), border: Border.all(color: context.border)),
                    child: Row(children: [
                      Expanded(child: Text(_fmtDate(date), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
                      Icon(Icons.calendar_today_outlined, size: 15, color: context.textHint),
                    ]),
                  ),
                ),
                const SizedBox(height: 12),
                label('Description'),
                TextFormField(
                  controller: descCtrl, maxLines: 3, minLines: 2, enabled: !saving,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  decoration: const InputDecoration(hintText: 'Brief description (optional)'),
                ),
                if (error != null) ...[const SizedBox(height: 12), _InlineError(error!)],
                const SizedBox(height: 18),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  AppButton(label: 'Cancel', variant: AppButtonVariant.secondary,
                      onPressed: saving ? null : () => Navigator.pop(ctx)),
                  const SizedBox(width: 8),
                  AppButton(label: editing == null ? 'Add Achievement' : 'Save Changes',
                      busyLabel: editing == null ? 'Adding…' : 'Saving…', loading: saving, onPressed: save),
                ]),
              ]),
            ),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Row(children: [
          Expanded(child: Text(_loading ? 'Loading…' : '${list.length} achievement${list.length == 1 ? '' : 's'}',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.textSub))),
          AppButton(label: 'Add Achievement', icon: Icons.add, onPressed: () => _openSheet()),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: TextField(
          onChanged: (v) => setState(() => _search = v),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: 'Search achievements…',
            prefixIcon: Icon(Icons.search, size: 18, color: context.textHint),
          ),
        ),
      ),
      SizedBox(
        height: 34,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          children: [
            ...['All', ..._cats].map((c) => _FilterPill(label: c, selected: _catFilter == c,
                onTap: () => setState(() => _catFilter = c))),
            if (_years.isNotEmpty) ...[
              Container(width: 1, height: 20, color: context.border, margin: const EdgeInsets.fromLTRB(2, 7, 8, 7)),
              ...(_years.toList()..sort((a, b) => b.compareTo(a))).map((y) => _FilterPill(label: '$y', selected: _yearFilter == y,
                  onTap: () => setState(() => _yearFilter = _yearFilter == y ? null : y))),
            ],
          ],
        ),
      ),
      const SizedBox(height: 8),
      Expanded(child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 60),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: KeyedSubtree(
            key: ValueKey(_loading ? 'l' : list.isEmpty ? 'x' : 'd'),
            child: _loading
              ? _card(context, const SkeletonList(rows: 3, rowHeight: 64))
              : list.isEmpty
                ? _card(context, EmptyState(
                    icon: Icons.emoji_events_outlined,
                    title: _all.isEmpty ? 'No achievements yet' : 'No matching achievements',
                    message: _all.isEmpty ? 'Record awards, events and milestones for this child.' : 'Try a different search or filter.',
                    actionLabel: _all.isEmpty ? 'Add Achievement' : null,
                    onAction: _all.isEmpty ? () => _openSheet() : null,
                  ))
                : _card(context, Column(children: [
                    for (var i = 0; i < list.length; i++) _achRow(list[i], i == list.length - 1),
                  ])),
          ),
        ),
      )),
    ]);
  }

  Widget _achRow(_AchRecord a, bool last) {
    final displayCat = _catDisplay[a.category] ?? 'Other';
    final fg = _catFg(displayCat);
    return _HoverRow(
      last: last,
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Container(width: 34, height: 34,
          decoration: BoxDecoration(color: fg.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(9)),
          child: Icon(Icons.emoji_events_outlined, size: 17, color: fg)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(a.title, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.textPrimary)),
          const SizedBox(height: 2),
          Text([displayCat, _fmtDate(a.date), if (a.description.isNotEmpty) a.description].join('  ·  '),
              maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: context.textHint, fontWeight: FontWeight.w500)),
        ])),
        PopupMenuButton<String>(
          tooltip: 'Actions for ${a.title}',
          icon: Icon(Icons.more_horiz_rounded, color: context.textSub, size: 20),
          position: PopupMenuPosition.under,
          offset: const Offset(0, 4),
          constraints: const BoxConstraints(minWidth: 150),
          onSelected: (v) {
            if (v == 'edit') _openSheet(editing: a);
            if (v == 'delete') _delete(a);
          },
          itemBuilder: (_) => [
            _menuItem(context, 'edit', Icons.edit_outlined, 'Edit'),
            const PopupMenuDivider(height: 8),
            _menuItem(context, 'delete', Icons.delete_outline_rounded, 'Delete', danger: true),
          ],
        ),
      ]),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 6),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? _brand100 : context.cardBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: selected ? _brand600.withValues(alpha: 0.6) : context.border),
        ),
        child: Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: selected ? _brand600 : context.textSub)),
      ),
    ),
  );
}

// Toast for sub-tab saves: success, queued for approval, or failed (with
// the server's message).
void _showResultSnack(BuildContext context, String msg, {bool isError = false, bool pending = false}) {
  if (isError) {
    AppToast.error(context, 'Couldn’t save', detail: msg);
  } else if (pending) {
    AppToast.warning(context, msg);
  } else {
    AppToast.success(context, msg);
  }
}

String _fmtDate(DateTime d) {
  const months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  return '${d.day.toString().padLeft(2,'0')} ${months[d.month - 1]} ${d.year}';
}

// "Not Available" fallback for any empty saved field, per spec.
const _notAvailable = 'Not Available';
String _na(String? v) => (v == null || v.trim().isEmpty || v == '—') ? _notAvailable : v;
String _naDate(String? iso) {
  if (iso == null || iso.isEmpty) return _notAvailable;
  final d = DateTime.tryParse(iso);
  return d == null ? _notAvailable : _fmtDate(d);
}

// ══════════════════════════════════════════════════════════════════════
// DOCUMENTS TAB
// ══════════════════════════════════════════════════════════════════════
class _StudentDoc {
  _StudentDoc({required this.id, required this.category, required this.fileName, this.mimeType, this.createdAt});
  final String id, category, fileName;
  final String? mimeType;
  final DateTime? createdAt;
  factory _StudentDoc.fromJson(Map<String, dynamic> j) => _StudentDoc(
    id: (j['id'] ?? '').toString(),
    category: (j['category'] ?? '').toString().isNotEmpty ? j['category'].toString() : 'Document',
    fileName: (j['fileName'] ?? '').toString().isNotEmpty ? j['fileName'].toString() : 'file',
    mimeType: j['mimeType'] as String?,
    createdAt: DateTime.tryParse((j['createdAt'] ?? '').toString())?.toLocal(),
  );
}

// Every document uploaded for the child, any number, each with its own name
// (GET /students/:id/documents). No fixed slots.
class _DocumentsTab extends StatefulWidget {
  const _DocumentsTab({required this.studentId});
  final String studentId;
  @override
  State<_DocumentsTab> createState() => _DocumentsTabState();
}

class _DocumentsTabState extends State<_DocumentsTab> {
  List<_StudentDoc> _docs = [];
  bool _loading = true;
  String? _error;
  String? _viewingId;
  String? _downloadingId;

  @override
  void initState() { super.initState(); _load(); }

  // [quiet] refreshes in place (after an upload/delete) without the skeleton.
  Future<void> _load({bool quiet = false}) async {
    if (!quiet) setState(() { _loading = true; _error = null; });
    try {
      final r = await apiClient.get('/students/${widget.studentId}/documents');
      final list = (r['data'] as List<dynamic>? ?? const []);
      final docs = list.whereType<Map>().map((m) => _StudentDoc.fromJson(m.cast<String, dynamic>()))
          .where((d) => d.id.isNotEmpty).toList();
      if (mounted) setState(() { _docs = docs; _loading = false; _error = null; });
    } catch (e) {
      if (!mounted) return;
      if (quiet && _docs.isNotEmpty) {
        AppToast.error(context, 'Couldn’t refresh documents', detail: ApiClient.errorMessage(e));
        return;
      }
      setState(() { _loading = false; _error = ApiClient.errorMessage(e, fallback: 'Could not load documents.'); });
    }
  }

  Future<void> _add() async {
    var pending = false;
    final doc = await showAppSheet<PickedStudentDoc>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => StudentDocumentSheet(onUpload: (d) async {
        final res = await apiClient.post('/students/${widget.studentId}/documents', {
          'category': d.name,
          'fileName': d.fileName,
          'mimeType': studentDocMime(d.fileName),
          'data': base64Encode(d.bytes),
        });
        // Document uploads are exempt from the approval queue today — but if
        // that ever changes, don't claim it was saved.
        pending = (res['meta'] as Map?)?['pendingApproval'] == true;
      }),
    );
    if (doc == null || !mounted) return;
    if (pending) {
      AppToast.warning(context, 'Submitted for Super Admin approval', detail: doc.name);
    } else {
      AppToast.success(context, 'Document uploaded', detail: '${doc.name} · ${doc.fileName}');
    }
    _load(quiet: true);
  }

  Future<({Uint8List bytes, String mime})?> _content(_StudentDoc d) async {
    final r = await apiClient.get('/students/documents/${d.id}');
    final data = (r['data'] as Map).cast<String, dynamic>();
    final b64 = data['data'] as String? ?? '';
    if (b64.isEmpty) return null;
    return (bytes: base64Decode(b64), mime: (data['mimeType'] as String?) ?? d.mimeType ?? studentDocMime(d.fileName));
  }

  Future<void> _view(_StudentDoc d) async {
    if (_viewingId != null) return;
    setState(() => _viewingId = d.id);
    try {
      final c = await _content(d);
      if (c == null) {
        if (mounted) AppToast.error(context, 'This document has no file content');
      } else {
        openBytesInBrowser(c.bytes, d.fileName);
      }
    } catch (e) {
      if (mounted) AppToast.error(context, 'Couldn’t open the document', detail: ApiClient.errorMessage(e));
    }
    if (mounted) setState(() => _viewingId = null);
  }

  Future<void> _download(_StudentDoc d) async {
    if (_downloadingId != null) return;
    setState(() => _downloadingId = d.id);
    try {
      final c = await _content(d);
      if (c == null) {
        if (mounted) AppToast.error(context, 'This document has no file content');
      } else {
        final ok = await NativeFileSaver.saveBytes(d.fileName, c.bytes, c.mime);
        if (mounted) {
          if (ok) { AppToast.success(context, 'Downloaded', detail: d.fileName); }
          else { AppToast.error(context, 'Couldn’t save the file'); }
        }
      }
    } catch (e) {
      if (mounted) AppToast.error(context, 'Couldn’t download the document', detail: ApiClient.errorMessage(e));
    }
    if (mounted) setState(() => _downloadingId = null);
  }

  Future<void> _delete(_StudentDoc d) async {
    final ok = await AppConfirm.show(
      context,
      title: 'Delete document?',
      message: 'Are you sure you want to delete “${d.category}” (${d.fileName})? This action cannot be undone.',
      onConfirm: () => apiClient.delete('/students/documents/${d.id}'),
      errorText: (e) {
        final m = ApiClient.errorMessage(e, fallback: 'Could not delete the document.');
        return m.toLowerCase().contains('forbidden') ? 'Only admins can delete documents. ($m)' : m;
      },
    );
    if (!ok || !mounted) return;
    AppToast.success(context, 'Document deleted', detail: d.category);
    setState(() => _docs.remove(d));
    _load(quiet: true);
  }

  Widget _row(_StudentDoc d, bool last) {
    final viewing = _viewingId == d.id;
    final downloading = _downloadingId == d.id;
    final sub = [
      d.fileName,
      if (d.createdAt != null) _fmtDate(d.createdAt!),
    ].join('  ·  ');
    return _HoverRow(
      last: last,
      child: Row(children: [
        Container(width: 34, height: 34,
          decoration: BoxDecoration(color: _brand600.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(9)),
          child: Icon(studentDocIcon(d.fileName), size: 17, color: _brand600)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(d.category, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.textPrimary)),
          const SizedBox(height: 2),
          Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: context.textHint, fontWeight: FontWeight.w500)),
        ])),
        const SizedBox(width: 8),
        SizedBox(width: 36, height: 36, child: viewing
          ? const Center(child: AppSpinner())
          : IconButton(
              tooltip: 'View',
              icon: Icon(Icons.visibility_outlined, size: 18, color: context.textSub),
              onPressed: () => _view(d),
            )),
        PopupMenuButton<String>(
          tooltip: 'Actions for ${d.category}',
          icon: downloading ? const AppSpinner() : Icon(Icons.more_horiz_rounded, color: context.textSub, size: 20),
          position: PopupMenuPosition.under,
          offset: const Offset(0, 4),
          constraints: const BoxConstraints(minWidth: 150),
          onSelected: (v) {
            if (v == 'view') _view(d);
            if (v == 'download') _download(d);
            if (v == 'delete') _delete(d);
          },
          itemBuilder: (_) => [
            _menuItem(context, 'view', Icons.visibility_outlined, 'View'),
            _menuItem(context, 'download', Icons.download_rounded, 'Download'),
            const PopupMenuDivider(height: 8),
            _menuItem(context, 'delete', Icons.delete_outline_rounded, 'Delete', danger: true),
          ],
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (_loading) {
      content = _card(context, const SkeletonList(rows: 3, rowHeight: 64));
    } else if (_error != null) {
      content = _card(context, ErrorState(message: _error!, onRetry: _load));
    } else if (_docs.isEmpty) {
      content = _card(context, EmptyState(
        icon: Icons.folder_open_outlined,
        title: 'No documents yet',
        message: 'Upload Aadhaar, birth certificate, TC, report cards, medical reports — any file, with any name.',
        actionLabel: 'Add document',
        onAction: _add,
      ));
    } else {
      content = _card(context, Column(children: [
        for (var i = 0; i < _docs.length; i++) _row(_docs[i], i == _docs.length - 1),
      ]));
    }
    return RefreshIndicator(
      color: _brand600,
      onRefresh: () => _load(quiet: true),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 80),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Documents', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.textPrimary)),
              Text(_loading ? 'Loading…' : '${_docs.length} file${_docs.length == 1 ? '' : 's'}',
                  style: TextStyle(fontSize: 12, color: context.textSub, fontWeight: FontWeight.w500)),
            ])),
            AppButton(label: 'Add document', icon: Icons.add, onPressed: _add),
          ]),
          const SizedBox(height: 12),
          AnimatedSwitcher(duration: const Duration(milliseconds: 180), child: KeyedSubtree(
            key: ValueKey(_loading ? 'l' : _error != null ? 'e' : _docs.isEmpty ? 'x' : 'd'),
            child: content,
          )),
        ]),
      ),
    );
  }
}

Widget _card(BuildContext context, Widget child) => Container(
  width: double.infinity,
  decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: context.border)),
  clipBehavior: Clip.antiAlias,
  child: child,
);

PopupMenuItem<String> _menuItem(BuildContext context, String value, IconData icon, String text, {bool danger = false}) => PopupMenuItem(
  value: value,
  height: 36,
  child: Row(children: [
    Icon(icon, size: 17, color: danger ? _danger : context.textSub),
    const SizedBox(width: 10),
    Text(text, style: TextStyle(fontSize: 13.5, color: danger ? _danger : context.textPrimary, fontWeight: FontWeight.w500)),
  ]),
);

// Row with a subtle hover tint and a hairline divider.
class _HoverRow extends StatefulWidget {
  const _HoverRow({required this.child, required this.last});
  final Widget child;
  final bool last;
  @override
  State<_HoverRow> createState() => _HoverRowState();
}

class _HoverRowState extends State<_HoverRow> {
  bool _hover = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
    onEnter: (_) => setState(() => _hover = true),
    onExit: (_) => setState(() => _hover = false),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      constraints: const BoxConstraints(minHeight: 64),
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: _hover ? context.surface2.withValues(alpha: 0.6) : Colors.transparent,
        border: widget.last ? null : Border(bottom: BorderSide(color: context.border.withValues(alpha: 0.7))),
      ),
      child: widget.child,
    ),
  );
}

class _InlineError extends StatelessWidget {
  const _InlineError(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    decoration: BoxDecoration(color: _danger.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _danger.withValues(alpha: 0.25))),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Icon(Icons.error_outline_rounded, size: 16, color: _danger),
      const SizedBox(width: 8),
      Expanded(child: Text(message, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: _danger))),
    ]),
  );
}

// ── shared widgets ─────────────────────────────────────────────────────
class _CardSection extends StatelessWidget {
  const _CardSection({required this.title, required this.icon, required this.children, this.trailing});
  final String title; final IconData icon; final List<Widget> children; final Widget? trailing;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: context.border)),
    clipBehavior: Clip.antiAlias,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: EdgeInsets.fromLTRB(14, trailing == null ? 12 : 6, trailing == null ? 14 : 6, trailing == null ? 12 : 6),
        child: Row(children: [
          Icon(icon, size: 16, color: _brand600),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: context.textPrimary))),
          if (trailing != null) trailing!,
        ]),
      ),
      Divider(height: 1, color: context.border),
      ...children,
    ]),
  );
}

Widget _sectionEditBtn(VoidCallback onTap) =>
    AppButton(label: 'Edit', icon: Icons.edit_outlined, variant: AppButtonVariant.ghost, dense: true, onPressed: onTap);

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value, {this.last = false});
  final String label, value; final bool last;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
    decoration: last ? null : BoxDecoration(border: Border(bottom: BorderSide(color: context.border.withValues(alpha: 0.7)))),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 136, child: Text(label, style: TextStyle(fontSize: 12.5, color: context.textHint, fontWeight: FontWeight.w500))),
      Expanded(child: Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.textPrimary))),
    ]),
  );
}

// Admin-managed options plus the student's current value if it's no longer
// in the list (deactivated / deleted), so opening a picker never hides it.
List<StudentOption> _withCurrent(List<StudentOption> opts, String currentKey, String currentLabel) => [
  ...opts,
  if (currentKey.isNotEmpty && !opts.any((o) => o.key == currentKey))
    StudentOption(id: '', key: currentKey, label: currentLabel),
];

// ══════════════════════════════════════════════════════════════════════
// SPONSOR AMOUNT — compact form; submits itself so the button can show
// "Assigning…" and the amount stays if the request fails.
// ══════════════════════════════════════════════════════════════════════
class _SponsorAmountSheet extends StatefulWidget {
  const _SponsorAmountSheet({required this.donorName, required this.onSubmit});
  final String donorName;
  final Future<dynamic> Function(int amount) onSubmit;
  @override
  State<_SponsorAmountSheet> createState() => _SponsorAmountSheetState();
}

class _SponsorAmountSheetState extends State<_SponsorAmountSheet> {
  final _form = GlobalKey<FormState>();
  final _amount = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() { _amount.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() => _error = null);
    if (!_form.currentState!.validate()) return;
    final v = int.parse(_amount.text.trim());
    setState(() => _busy = true);
    try {
      await widget.onSubmit(v);
      if (mounted) Navigator.of(context).pop(v);
    } catch (e) {
      if (!mounted) return;
      setState(() { _busy = false; _error = ApiClient.errorMessage(e, fallback: 'Could not save the sponsorship.'); });
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
    child: Container(
      decoration: BoxDecoration(color: context.cardBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Form(
        key: _form,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SheetHandle(margin: EdgeInsets.only(bottom: 10)),
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Sponsorship amount', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text('Annual amount ${widget.donorName} will sponsor this child with.',
                  style: TextStyle(fontSize: 12.5, color: context.textSub)),
            ])),
            IconButton(tooltip: 'Close', icon: Icon(Icons.close_rounded, size: 20, color: context.textSub),
                onPressed: _busy ? null : () => Navigator.of(context).pop()),
          ]),
          const SizedBox(height: 14),
          TextFormField(
            controller: _amount,
            autofocus: true,
            enabled: !_busy,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onFieldSubmitted: (_) => _submit(),
            validator: (v) => (int.tryParse((v ?? '').trim()) ?? 0) < 1 ? 'Enter an amount greater than 0.' : null,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            decoration: const InputDecoration(prefixText: '₹ ', hintText: 'e.g. 18000'),
          ),
          if (_error != null) ...[const SizedBox(height: 12), _InlineError(_error!)],
          const SizedBox(height: 18),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            AppButton(label: 'Cancel', variant: AppButtonVariant.secondary,
                onPressed: _busy ? null : () => Navigator.of(context).pop()),
            const SizedBox(width: 8),
            AppButton(label: 'Assign Sponsor', busyLabel: 'Assigning…', loading: _busy, onPressed: _submit),
          ]),
        ]),
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════════════
// FULL STUDENT EDIT — every field PUT /students/:id accepts, grouped in
// sections. Opened for all sections (header ✎) or one section (a card's
// Edit). Pre-filled from the record; only changed fields are sent ('' clears
// an optional text field); dates go out as YYYY-MM-DD.
// ══════════════════════════════════════════════════════════════════════
enum _EditSection { basic, family, education, identity, health, financial }

extension _EditSectionX on _EditSection {
  String get title => switch (this) {
    _EditSection.basic => 'Basic details',
    _EditSection.family => 'Family & guardian',
    _EditSection.education => 'Education',
    _EditSection.identity => 'Identity & IDs',
    _EditSection.health => 'Health',
    _EditSection.financial => 'Financial & welfare',
  };
  IconData get icon => switch (this) {
    _EditSection.basic => Icons.person_outline,
    _EditSection.family => Icons.family_restroom_outlined,
    _EditSection.education => Icons.school_outlined,
    _EditSection.identity => Icons.badge_outlined,
    _EditSection.health => Icons.health_and_safety_outlined,
    _EditSection.financial => Icons.account_balance_outlined,
  };
}

typedef _TextSpec = ({String key, String label, String hint, int lines, bool wide, TextInputType? kb});

_TextSpec _t(String key, String label, {String hint = '', int lines = 1, bool wide = false, TextInputType? kb}) =>
    (key: key, label: label, hint: hint, lines: lines, wide: wide || lines > 1, kb: kb);

// Plain text fields per section (pickers/dates are laid out separately).
final _textSpecs = <_EditSection, List<_TextSpec>>{
  _EditSection.basic: [
    _t('name', 'Full name', hint: "Child's full name", wide: true),
  ],
  _EditSection.family: [
    _t('fatherName', "Father's name"),
    _t('motherName', "Mother's name"),
    _t('guardianName', 'Guardian name'),
    _t('guardianRelation', 'Relation to child', hint: 'e.g. Mother'),
    _t('guardianPhone', 'Guardian mobile', hint: 'e.g. +91 98200 00000', kb: TextInputType.phone),
    _t('siblingNames', 'Sibling name(s)', hint: 'Comma-separated'),
    _t('address', 'Address', lines: 2),
    _t('notes', 'Family background notes', lines: 3),
  ],
  _EditSection.education: [
    _t('school', 'School / institution', wide: true),
    _t('class', 'Class / grade', hint: 'e.g. Class 6'),
    _t('section', 'Section', hint: 'e.g. A'),
    _t('admissionNo', 'Admission no.'),
    _t('academicYear', 'Academic year', hint: 'e.g. 2025-26'),
    _t('studentType', 'Student type', hint: 'e.g. Day scholar'),
    _t('educationRemarks', 'Education remarks', lines: 2),
  ],
  _EditSection.identity: [
    _t('aadhaarNumber', 'Aadhaar number', hint: '12 digits', kb: TextInputType.number),
    _t('satNumber', 'SAT number'),
    _t('penNumber', 'PEN number'),
    _t('cwcNumber', 'CWC number'),
    _t('abhaNumber', 'ABHA card number'),
    _t('rationCardNumber', 'Ration card number'),
    _t('missionVatsalyaNumber', 'Mission Vatsalya number', wide: true),
    _t('caste', 'Caste'),
    _t('subCaste', 'Sub-caste'),
  ],
  _EditSection.health: [
    _t('medicalNotes', 'Medical history / notes', hint: 'Allergies, conditions, medication…', lines: 3),
  ],
  _EditSection.financial: [
    _t('bankAccountDetails', 'Bank account details', hint: 'Account no., IFSC, bank name', lines: 2),
    _t('incomeCertificateAmount', 'Income certificate amount (₹)', kb: TextInputType.number),
    _t('incomeCertificateRdNumber', 'Income certificate RD no.'),
  ],
};

typedef _SaveFn = Future<bool> Function(Map<String, dynamic> body, {String? centreName, String? categoryLabel});

class _StudentEditSheet extends StatefulWidget {
  const _StudentEditSheet({
    required this.initial, required this.centreName, required this.categoryLabel, required this.statusLabel,
    required this.photo, required this.sections, required this.loadCentres, required this.onSave,
  });
  final Map<String, String> initial; // backend field → current value
  final String centreName, categoryLabel, statusLabel;
  final Uint8List? photo;
  final List<_EditSection> sections;
  final Future<List<({String id, String name})>> Function() loadCentres;
  final _SaveFn onSave;
  @override
  State<_StudentEditSheet> createState() => _StudentEditSheetState();
}

class _StudentEditSheetState extends State<_StudentEditSheet> {
  final _form = GlobalKey<FormState>();
  final Map<String, TextEditingController> _c = {};
  late String _gender = _init('gender');
  late String _dob = _init('dob');
  late String _admDate = _init('admissionDate');
  late String _joinDate = _init('joiningDate');
  late String _categoryId = _init('categoryId');
  late String _status = _init('status');
  late String _eduLevel = _init('educationLevel');
  late String _permanence = _init('permanence');
  late String _centerId = _init('centerId');
  late String _initialCenterId = _init('centerId');
  List<({String id, String name})>? _centres; // null while loading
  Uint8List? _newPhoto;
  bool _photoChanged = false;
  bool _saving = false;
  String? _error;

  String _init(String k) => widget.initial[k] ?? '';
  bool _has(_EditSection s) => widget.sections.contains(s);
  bool get _single => widget.sections.length == 1;

  @override
  void initState() {
    super.initState();
    for (final s in widget.sections) {
      for (final f in _textSpecs[s]!) {
        _c[f.key] = TextEditingController(text: _init(f.key));
      }
    }
    if (_has(_EditSection.basic)) {
      widget.loadCentres().then((list) {
        if (!mounted) return;
        setState(() {
          _centres = list;
          // Older/local records may only carry the centre's name.
          if (_centerId.isEmpty) {
            for (final c in list) {
              if (c.name == widget.centreName) { _centerId = c.id; _initialCenterId = c.id; break; }
            }
          }
        });
      });
    }
    StudentLookups.load().then((_) { if (mounted) setState(() {}); });
  }

  @override
  void dispose() { for (final c in _c.values) { c.dispose(); } super.dispose(); }

  // Validators only judge values the user actually changed, so an old,
  // oddly-formatted value never blocks saving another field.
  String? _validate(String key, String? raw) {
    final v = (raw ?? '').trim();
    if (key == 'name' && v.isEmpty) return 'Please enter the child’s name.';
    if (v == _init(key).trim()) return null;
    switch (key) {
      case 'aadhaarNumber':
        final digits = v.replaceAll(RegExp(r'\s'), '');
        if (v.isNotEmpty && !RegExp(r'^\d{12}$').hasMatch(digits)) return 'Aadhaar number must be 12 digits.';
      case 'guardianPhone':
        final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
        if (v.isNotEmpty && (digits.length < 7 || digits.length > 15 || RegExp(r'[A-Za-z]').hasMatch(v))) {
          return 'Enter a valid phone number.';
        }
      case 'incomeCertificateAmount':
        if (v.isNotEmpty && int.tryParse(v) == null) return 'Enter a whole number.';
    }
    return null;
  }

  Map<String, dynamic> _changes() {
    final body = <String, dynamic>{};
    _c.forEach((key, ctrl) {
      final now = ctrl.text.trim();
      if (now == _init(key).trim()) return;
      body[key] = key == 'incomeCertificateAmount' ? (now.isEmpty ? null : int.parse(now)) : now;
    });
    void pick(String key, String now) { if (now != _init(key)) body[key] = now; }
    if (_has(_EditSection.basic)) {
      if (_gender.isNotEmpty) pick('gender', _gender);
      if (_dob.isNotEmpty) pick('dob', _dob);
      if (_admDate.isNotEmpty) pick('admissionDate', _admDate);
      if (_centerId.isNotEmpty && _centerId != _initialCenterId) body['centerId'] = _centerId;
      pick('categoryId', _categoryId);   // '' clears the category
      if (_status.isNotEmpty) pick('status', _status);
      if (_photoChanged) {
        if (_newPhoto != null) { body['photo'] = base64Encode(_newPhoto!); }
        else if (widget.photo != null) { body['photo'] = ''; }
      }
    }
    if (_has(_EditSection.education)) {
      pick('educationLevel', _eduLevel); // '' clears the level
      pick('permanence', _permanence);
      if (_joinDate.isNotEmpty) pick('joiningDate', _joinDate);
    }
    return body;
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _error = null);
    if (!_form.currentState!.validate()) {
      AppToast.error(context, 'Please fix the highlighted fields');
      return;
    }
    if (_has(_EditSection.basic) && _dob.isEmpty) {
      setState(() => _error = 'Please select the date of birth.');
      return;
    }
    final body = _changes();
    if (body.isEmpty) {
      AppToast.info(context, 'No changes to save');
      Navigator.of(context).pop();
      return;
    }
    String? centreName;
    if (body.containsKey('centerId')) {
      centreName = (_centres ?? const []).firstWhere((c) => c.id == _centerId, orElse: () => (id: '', name: '')).name;
    }
    String? categoryLabel;
    if (body.containsKey('categoryId')) {
      categoryLabel = _categoryId.isEmpty
          ? ''
          : _categoryOptions.firstWhere((o) => o.key == _categoryId, orElse: () => const StudentOption(id: '', key: '', label: '')).label;
    }
    setState(() => _saving = true);
    try {
      final saved = await widget.onSave(body, centreName: centreName, categoryLabel: categoryLabel);
      if (mounted) Navigator.of(context).pop(saved);
    } catch (e) {
      // Keep the form open with everything typed and the server's reason.
      if (!mounted) return;
      setState(() { _saving = false; _error = ApiClient.errorMessage(e, fallback: 'Could not save the changes.'); });
    }
  }

  List<StudentOption> get _categoryOptions => [
    const StudentOption(id: '', key: '', label: 'None'),
    ..._withCurrent(StudentLookups.categories, _init('categoryId'),
        widget.categoryLabel.isNotEmpty && widget.categoryLabel != '—' ? widget.categoryLabel : 'Current category'),
  ];

  // ── field builders ─────────────────────────────────────────────────
  Widget _label(String t, {bool required = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text.rich(TextSpan(children: [
      TextSpan(text: t),
      if (required) const TextSpan(text: ' *', style: TextStyle(color: _danger)),
    ]), maxLines: 1, overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: context.textSub)),
  );

  Widget _text(_TextSpec f) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _label(f.label, required: f.key == 'name'),
    TextFormField(
      controller: _c[f.key],
      enabled: !_saving,
      keyboardType: f.lines > 1 ? TextInputType.multiline : f.kb,
      maxLines: f.lines,
      minLines: 1,
      inputFormatters: f.key == 'incomeCertificateAmount' ? [FilteringTextInputFormatter.digitsOnly] : null,
      textCapitalization: f.kb == null && !f.key.contains('Number') && f.key != 'bankAccountDetails'
          ? TextCapitalization.sentences : TextCapitalization.none,
      validator: (v) => _validate(f.key, v),
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      decoration: InputDecoration(hintText: f.hint.isEmpty ? null : f.hint),
    ),
  ]);

  Widget _dropdown(String label, String value, List<({String key, String label})> options, ValueChanged<String> onChanged,
      {String hint = 'Select'}) {
    final has = options.any((o) => o.key == value);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label(label),
      DropdownButtonFormField<String>(
        key: ValueKey('$label:${options.length}'),
        initialValue: has ? value : null,
        isExpanded: true,
        hint: Text(hint, style: TextStyle(fontSize: 14, color: context.textHint)),
        items: [
          for (final o in options)
            DropdownMenuItem(value: o.key, child: Text(o.label, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
        ],
        onChanged: _saving ? null : (v) { if (v != null) setState(() => onChanged(v)); },
        decoration: const InputDecoration(),
        borderRadius: BorderRadius.circular(10),
        icon: Icon(Icons.keyboard_arrow_down_rounded, size: 20, color: context.textHint),
      ),
    ]);
  }

  Widget _date(String label, String value, ValueChanged<String> onPicked, {bool required = false, DateTime? last}) {
    final parsed = DateTime.tryParse(value);
    final shown = parsed != null ? _fmtDate(parsed) : value;
    final missing = required && value.isEmpty && _error != null;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label(label, required: required),
      InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: _saving ? null : () async {
          final lastDate = last ?? DateTime.now();
          var initial = parsed ?? lastDate;
          if (initial.isAfter(lastDate)) initial = lastDate;
          final picked = await showDatePicker(context: context, initialDate: initial, firstDate: DateTime(1950), lastDate: lastDate);
          if (picked != null) {
            setState(() => onPicked('${picked.year.toString().padLeft(4, '0')}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}'));
          }
        },
        child: Container(
          height: 42,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Theme.of(context).inputDecorationTheme.fillColor ?? context.cardBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: missing ? _danger : context.border),
          ),
          child: Row(children: [
            Expanded(child: Text(shown.isEmpty ? 'Select date' : shown, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: shown.isEmpty ? context.textHint : context.textPrimary))),
            Icon(Icons.calendar_today_outlined, size: 15, color: context.textHint),
          ]),
        ),
      ),
    ]);
  }

  // Short fields two per row when there's room; wide ones take the full row.
  Widget _grid(List<(Widget, bool)> items) => LayoutBuilder(builder: (_, c) {
    final two = c.maxWidth >= 400;
    final half = two ? (c.maxWidth - 12) / 2 : c.maxWidth;
    return Wrap(spacing: 12, runSpacing: 12, children: [
      for (final (w, wide) in items) SizedBox(width: wide ? c.maxWidth : half, child: w),
    ]);
  });

  List<(Widget, bool)> _textItems(_EditSection s) => [for (final f in _textSpecs[s]!) (_text(f), f.wide)];

  Widget _basic() {
    final statusOpts = _withCurrent(StudentLookups.statuses, _init('status'), widget.statusLabel);
    final catOpts = _categoryOptions;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Center(child: PhotoPickerCircle(
        label: 'Profile photo', size: 72,
        initialImage: widget.photo,
        onImageChanged: (b) => setState(() { _newPhoto = b; _photoChanged = true; }),
      )),
      const SizedBox(height: 12),
      _grid([
        ..._textItems(_EditSection.basic),
        (_date('Date of birth', _dob, (v) => _dob = v, required: true), false),
        (_dropdown('Gender', _gender, const [(key: 'MALE', label: 'Male'), (key: 'FEMALE', label: 'Female'), (key: 'OTHER', label: 'Other')],
            (v) => _gender = v), false),
        (_centres == null
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_label('Centre'), const Skeleton(height: 42, radius: 10)])
          : _centres!.isEmpty
            ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _label('Centre'),
                Text('${widget.centreName.isNotEmpty ? widget.centreName : '—'}  ·  couldn’t load centres',
                    style: TextStyle(fontSize: 12.5, color: context.textHint)),
              ])
            : _dropdown('Centre', _centerId, [for (final c in _centres!) (key: c.id, label: c.name)], (v) => _centerId = v), false),
        (_dropdown('Status', _status, [for (final o in statusOpts) (key: o.key, label: o.label)], (v) => _status = v), false),
        (_dropdown('Support category', _categoryId, [for (final o in catOpts) (key: o.key, label: o.label)], (v) => _categoryId = v,
            hint: 'None'), false),
        (_date('Admission date', _admDate, (v) => _admDate = v, last: DateTime.now().add(const Duration(days: 366))), false),
      ]),
    ]);
  }

  Widget _education() {
    final levels = [
      const StudentOption(id: '', key: '', label: 'None'),
      ..._withCurrent(StudentLookups.educationLevels, _init('educationLevel'), StudentLookups.educationLabel(_init('educationLevel'))),
    ];
    final perm = <({String key, String label})>[
      (key: '', label: 'Not set'),
      (key: 'Permanent', label: 'Permanent'),
      (key: 'Temporary', label: 'Temporary'),
      if (_init('permanence').isNotEmpty && !['Permanent', 'Temporary'].contains(_init('permanence')))
        (key: _init('permanence'), label: _init('permanence')),
    ];
    final items = _textItems(_EditSection.education);
    return _grid([
      (_dropdown('Education level', _eduLevel, [for (final o in levels) (key: o.key, label: o.label)], (v) => _eduLevel = v,
          hint: 'None'), false),
      items.first, // school (wide)
      ...items.sublist(1, items.length - 1),
      (_date('Joining date', _joinDate, (v) => _joinDate = v, last: DateTime.now().add(const Duration(days: 366))), false),
      (_dropdown('Permanence', _permanence, perm, (v) => _permanence = v, hint: 'Not set'), false),
      items.last, // remarks (wide)
    ]);
  }

  Widget _sectionBody(_EditSection s) => switch (s) {
    _EditSection.basic => _basic(),
    _EditSection.education => _education(),
    _ => _grid(_textItems(s)),
  };

  @override
  Widget build(BuildContext context) {
    final maxH = MediaQuery.sizeOf(context).height * (isWideLayout(context) ? 0.8 : 0.92);
    final title = _single ? 'Edit ${widget.sections.first.title.toLowerCase()}' : 'Edit student';
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: maxH),
        decoration: BoxDecoration(color: context.cardBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
        child: Form(
          key: _form,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 12, 10),
              child: Column(children: [
                const SheetHandle(margin: EdgeInsets.only(bottom: 10)),
                Row(children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('Only the fields you change are saved.', style: TextStyle(fontSize: 12.5, color: context.textSub)),
                  ])),
                  IconButton(
                    tooltip: 'Close',
                    icon: Icon(Icons.close_rounded, size: 20, color: context.textSub),
                    onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  ),
                ]),
              ]),
            ),
            Divider(height: 1, color: context.border),
            Flexible(child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                for (final s in widget.sections) ...[
                  if (!_single)
                    Padding(
                      padding: EdgeInsets.only(bottom: 10, top: s == widget.sections.first ? 0 : 18),
                      child: Row(children: [
                        Icon(s.icon, size: 15, color: _brand600),
                        const SizedBox(width: 6),
                        Text(s.title.toUpperCase(), style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700,
                            color: _brand600, letterSpacing: 0.6)),
                      ]),
                    ),
                  _sectionBody(s),
                ],
              ]),
            )),
            if (_error != null)
              Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 10), child: _InlineError(_error!)),
            Divider(height: 1, color: context.border),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                AppButton(label: 'Cancel', variant: AppButtonVariant.secondary,
                    onPressed: _saving ? null : () => Navigator.of(context).pop()),
                const SizedBox(width: 8),
                AppButton(label: 'Save Changes', busyLabel: 'Saving…', loading: _saving, onPressed: _save),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
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

class _ProgressRecordItem {
  _ProgressRecordItem({
    required this.id, required this.date, this.academicScore, this.attendancePercent,
    this.behaviourRating, this.communicationSkills, this.leadership, this.sportsPerformance,
    this.mentorRemarks, this.teacherRemarks, this.examResult, this.grade,
  });
  final String id;
  final DateTime date;
  final int? academicScore;
  final double? attendancePercent;
  final String? behaviourRating, communicationSkills, leadership, sportsPerformance;
  final String? mentorRemarks, teacherRemarks, examResult, grade;

  factory _ProgressRecordItem.fromJson(Map<String, dynamic> j) => _ProgressRecordItem(
    id: j['id'] as String,
    date: DateTime.tryParse(j['date'] as String? ?? '') ?? DateTime.now(),
    academicScore: (j['academicScore'] as num?)?.toInt(),
    attendancePercent: (j['attendancePercent'] as num?)?.toDouble(),
    behaviourRating: j['behaviourRating'] as String?,
    communicationSkills: j['communicationSkills'] as String?,
    leadership: j['leadership'] as String?,
    sportsPerformance: j['sportsPerformance'] as String?,
    mentorRemarks: j['mentorRemarks'] as String?,
    teacherRemarks: j['teacherRemarks'] as String?,
    examResult: j['examResult'] as String?,
    grade: j['grade'] as String?,
  );

  String get dateLabel => _fmtDate(date);
}

class _ProgressTabState extends State<_ProgressTab> {
  List<_GrowthRecord> _growth = [];
  bool _loadingGrowth = true;

  List<_ProgressRecordItem> _progress = [];
  bool _loadingProgress = true;
  bool _loadingMoreProgress = false;
  int _progressPage = 1;
  bool _progressHasMore = false;

  @override
  void initState() { super.initState(); _loadGrowth(); _loadProgress(); }

  Future<void> _loadGrowth({bool quiet = false}) async {
    if (mounted && !quiet) setState(() => _loadingGrowth = true);
    try {
      final r = await apiClient.get('/students/${widget.studentId}/growth');
      final list = (r['data'] as List<dynamic>? ?? const []);
      final records = list.whereType<Map>().map((m) => _GrowthRecord.fromJson(m.cast<String, dynamic>())).toList();
      if (mounted) setState(() { _growth = records; _loadingGrowth = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingGrowth = false);
    }
  }

  Future<void> _deleteGrowthRecord(_GrowthRecord r) async {
    final ok = await AppConfirm.show(
      context,
      title: 'Delete growth record?',
      message: 'Are you sure you want to delete the entry from ${r.dateLabel}? This action cannot be undone.',
      onConfirm: () => apiClient.delete('/students/growth/${r.id}'),
      errorText: (e) => ApiClient.errorMessage(e, fallback: 'Could not delete the record.'),
    );
    if (!ok || !mounted) return;
    AppToast.success(context, 'Growth record deleted');
    await _loadGrowth(quiet: true);
  }

  Future<void> _loadProgress({bool quiet = false}) async {
    if (mounted) setState(() { if (!quiet) _loadingProgress = true; _progressPage = 1; });
    try {
      final r = await apiClient.get('/students/${widget.studentId}/progress', params: {'page': '1', 'limit': '10'});
      final inner = r['data'];
      final list = inner is Map ? (inner['data'] as List<dynamic>? ?? const []) : (inner is List ? inner : const []);
      // meta sits BESIDE data in the response, not inside it — reading it from
      // inside made totalPages always 1, so "Load more" never appeared.
      final meta = (r['meta'] as Map?) ?? (inner is Map ? inner['meta'] as Map? : null);
      final totalPages = (meta?['totalPages'] as num?)?.toInt() ?? 1;
      final records = list.whereType<Map>().map((m) => _ProgressRecordItem.fromJson(m.cast<String, dynamic>())).toList();
      if (mounted) setState(() {
        _progress = records;
        _loadingProgress = false;
        _progressHasMore = totalPages > 1;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingProgress = false);
    }
  }

  Future<void> _loadMoreProgress() async {
    if (_loadingMoreProgress || !_progressHasMore) return;
    setState(() => _loadingMoreProgress = true);
    final nextPage = _progressPage + 1;
    try {
      final r = await apiClient.get('/students/${widget.studentId}/progress', params: {'page': '$nextPage', 'limit': '10'});
      final inner = r['data'];
      final list = inner is Map ? (inner['data'] as List<dynamic>? ?? const []) : (inner is List ? inner : const []);
      final meta = (r['meta'] as Map?) ?? (inner is Map ? inner['meta'] as Map? : null);
      final totalPages = (meta?['totalPages'] as num?)?.toInt() ?? 1;
      final records = list.whereType<Map>().map((m) => _ProgressRecordItem.fromJson(m.cast<String, dynamic>())).toList();
      if (mounted) setState(() {
        _progress = [..._progress, ...records];
        _progressPage = nextPage;
        _progressHasMore = nextPage < totalPages;
        _loadingMoreProgress = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _loadingMoreProgress = false);
        AppToast.error(context, 'Couldn’t load more records', detail: ApiClient.errorMessage(e));
      }
    }
  }

  Future<void> _deleteProgressRecord(_ProgressRecordItem r) async {
    final ok = await AppConfirm.show(
      context,
      title: 'Delete performance record?',
      message: 'Are you sure you want to delete the record from ${r.dateLabel}? This action cannot be undone.',
      onConfirm: () => apiClient.delete('/students/progress/${r.id}'),
      errorText: (e) => ApiClient.errorMessage(e, fallback: 'Could not delete the record.'),
    );
    if (!ok || !mounted) return;
    AppToast.success(context, 'Performance record deleted');
    await _loadProgress(quiet: true);
  }

  // Compact date picker field shared by the two record sheets.
  Widget _dateBox(BuildContext ctx, DateTime date, bool enabled, ValueChanged<DateTime> onPicked) => InkWell(
    borderRadius: BorderRadius.circular(10),
    onTap: !enabled ? null : () async {
      final picked = await showDatePicker(context: ctx, initialDate: date, firstDate: DateTime(2000), lastDate: DateTime.now());
      if (picked != null) onPicked(picked);
    },
    child: Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).inputDecorationTheme.fillColor ?? context.cardBg,
        borderRadius: BorderRadius.circular(10), border: Border.all(color: context.border)),
      child: Row(children: [
        Expanded(child: Text(_fmtDate(date), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500))),
        Icon(Icons.calendar_today_outlined, size: 15, color: context.textHint),
      ]),
    ),
  );

  Widget _sheetHeader(BuildContext ctx, String title, bool busy) => Column(children: [
    const SheetHandle(margin: EdgeInsets.only(bottom: 10)),
    Row(children: [
      Expanded(child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
      IconButton(tooltip: 'Close', icon: Icon(Icons.close_rounded, size: 20, color: context.textSub),
          onPressed: busy ? null : () => Navigator.pop(ctx)),
    ]),
  ]);

  Widget _fieldLabel(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(t, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: context.textSub)));

  void _showAddProgressDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    DateTime date = DateTime.now();
    final academicScoreCtrl = TextEditingController();
    final attendanceCtrl = TextEditingController();
    final behaviourCtrl = TextEditingController();
    final communicationCtrl = TextEditingController();
    final leadershipCtrl = TextEditingController();
    final sportsCtrl = TextEditingController();
    final mentorCtrl = TextEditingController();
    final teacherCtrl = TextEditingController();
    final examResultCtrl = TextEditingController();
    final gradeCtrl = TextEditingController();
    bool saving = false;
    String? error;

    showAppSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
        Future<void> save() async {
          if (saving) return;
          setSheet(() => error = null);
          if (!formKey.currentState!.validate()) return;
          setSheet(() => saving = true);
          final iso = '${date.year.toString().padLeft(4,'0')}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}';
          final Map<String, dynamic> res;
          try {
            res = await apiClient.post('/students/${widget.studentId}/progress', {
              'date': iso,
              if (academicScoreCtrl.text.trim().isNotEmpty) 'academicScore': int.tryParse(academicScoreCtrl.text.trim()),
              if (attendanceCtrl.text.trim().isNotEmpty) 'attendancePercent': double.tryParse(attendanceCtrl.text.trim()),
              if (behaviourCtrl.text.trim().isNotEmpty) 'behaviourRating': behaviourCtrl.text.trim(),
              if (communicationCtrl.text.trim().isNotEmpty) 'communicationSkills': communicationCtrl.text.trim(),
              if (leadershipCtrl.text.trim().isNotEmpty) 'leadership': leadershipCtrl.text.trim(),
              if (sportsCtrl.text.trim().isNotEmpty) 'sportsPerformance': sportsCtrl.text.trim(),
              if (mentorCtrl.text.trim().isNotEmpty) 'mentorRemarks': mentorCtrl.text.trim(),
              if (teacherCtrl.text.trim().isNotEmpty) 'teacherRemarks': teacherCtrl.text.trim(),
              if (examResultCtrl.text.trim().isNotEmpty) 'examResult': examResultCtrl.text.trim(),
              if (gradeCtrl.text.trim().isNotEmpty) 'grade': gradeCtrl.text.trim(),
            });
          } catch (e) {
            // Sheet stays open (inline error) so nothing typed is lost.
            if (ctx.mounted) setSheet(() { saving = false; error = ApiClient.errorMessage(e); });
            return;
          }
          if (ctx.mounted) Navigator.pop(ctx);
          final pending = (res['meta'] as Map?)?['pendingApproval'] == true;
          if (mounted) _showResultSnack(this.context, pending ? 'Submitted for Super Admin approval' : 'Performance record added', pending: pending);
          await _loadProgress(quiet: true);
        }

        String? pct(String? v, {bool whole = false}) {
          final t = (v ?? '').trim();
          if (t.isEmpty) return null;
          final n = whole ? int.tryParse(t)?.toDouble() : double.tryParse(t);
          if (n == null) return whole ? 'Enter a whole number.' : 'Enter a number.';
          if (n < 0 || n > 100) return 'Enter a value from 0 to 100.';
          return null;
        }

        Widget field(String label, TextEditingController ctrl, {TextInputType? kb, int lines = 1, String? Function(String?)? validator}) =>
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _fieldLabel(label),
            TextFormField(
              controller: ctrl, keyboardType: kb, maxLines: lines, minLines: 1, enabled: !saving, validator: validator,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              decoration: const InputDecoration()),
          ]);

        Widget pair(Widget a, Widget b) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: a), const SizedBox(width: 12), Expanded(child: b),
        ]);

        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * (isWideLayout(ctx) ? 0.8 : 0.92)),
            decoration: BoxDecoration(color: context.cardBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
            child: Form(
              key: formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(padding: const EdgeInsets.fromLTRB(20, 12, 12, 6), child: _sheetHeader(ctx, 'Add performance record', saving)),
                Flexible(child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _fieldLabel('Date'),
                    _dateBox(ctx, date, !saving, (d) => setSheet(() => date = d)),
                    const SizedBox(height: 12),
                    pair(field('Academic score (%)', academicScoreCtrl, kb: TextInputType.number, validator: (v) => pct(v, whole: true)),
                         field('Attendance (%)', attendanceCtrl, kb: const TextInputType.numberWithOptions(decimal: true), validator: pct)),
                    const SizedBox(height: 12),
                    pair(field('Behaviour rating', behaviourCtrl), field('Communication skills', communicationCtrl)),
                    const SizedBox(height: 12),
                    pair(field('Leadership', leadershipCtrl), field('Sports performance', sportsCtrl)),
                    const SizedBox(height: 12),
                    pair(field('Exam result', examResultCtrl), field('Grade', gradeCtrl)),
                    const SizedBox(height: 12),
                    field('Mentor remarks', mentorCtrl, lines: 2),
                    const SizedBox(height: 12),
                    field('Teacher remarks', teacherCtrl, lines: 2),
                    if (error != null) ...[const SizedBox(height: 12), _InlineError(error!)],
                  ]),
                )),
                Divider(height: 1, color: context.border),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                  child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                    AppButton(label: 'Cancel', variant: AppButtonVariant.secondary, onPressed: saving ? null : () => Navigator.pop(ctx)),
                    const SizedBox(width: 8),
                    AppButton(label: 'Save Record', busyLabel: 'Saving…', loading: saving, onPressed: save),
                  ]),
                ),
              ]),
            ),
          ),
        );
      }),
    );
  }

  void _showAddGrowthDialog(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    DateTime date = DateTime.now();
    final heightCtrl = TextEditingController();
    final weightCtrl = TextEditingController();
    bool saving = false;
    String? error;

    showAppSheet(
      context: context, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
        Future<void> save() async {
          if (saving) return;
          setSheet(() => error = null);
          if (!formKey.currentState!.validate()) return;
          final h = double.tryParse(heightCtrl.text.trim());
          final w = double.tryParse(weightCtrl.text.trim());
          if (h == null && w == null) { setSheet(() => error = 'Enter a height, a weight, or both.'); return; }
          setSheet(() => saving = true);
          final iso = '${date.year.toString().padLeft(4,'0')}-${date.month.toString().padLeft(2,'0')}-${date.day.toString().padLeft(2,'0')}';
          final Map<String, dynamic> res;
          try {
            res = await apiClient.post('/students/${widget.studentId}/growth', {
              'date': iso,
              if (h != null) 'heightCm': h,
              if (w != null) 'weightKg': w,
            });
          } catch (e) {
            if (ctx.mounted) setSheet(() { saving = false; error = ApiClient.errorMessage(e); });
            return;
          }
          if (ctx.mounted) Navigator.pop(ctx);
          final pending = (res['meta'] as Map?)?['pendingApproval'] == true;
          if (mounted) _showResultSnack(this.context, pending ? 'Submitted for Super Admin approval' : 'Growth record added', pending: pending);
          await _loadGrowth(quiet: true);
        }

        String? num_(String? v) {
          final t = (v ?? '').trim();
          if (t.isEmpty) return null;
          final n = double.tryParse(t);
          return n == null || n <= 0 ? 'Enter a positive number.' : null;
        }

        Widget field(String label, TextEditingController ctrl) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _fieldLabel(label),
          TextFormField(
            controller: ctrl, enabled: !saving, validator: num_,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            decoration: const InputDecoration()),
        ]);

        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(color: context.cardBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            child: Form(
              key: formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                _sheetHeader(ctx, 'Add growth record', saving),
                const SizedBox(height: 8),
                _fieldLabel('Date'),
                _dateBox(ctx, date, !saving, (d) => setSheet(() => date = d)),
                const SizedBox(height: 12),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: field('Height (cm)', heightCtrl)),
                  const SizedBox(width: 12),
                  Expanded(child: field('Weight (kg)', weightCtrl)),
                ]),
                if (error != null) ...[const SizedBox(height: 12), _InlineError(error!)],
                const SizedBox(height: 18),
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  AppButton(label: 'Cancel', variant: AppButtonVariant.secondary, onPressed: saving ? null : () => Navigator.pop(ctx)),
                  const SizedBox(width: 8),
                  AppButton(label: 'Save', busyLabel: 'Saving…', loading: saving, onPressed: save),
                ]),
              ]),
            ),
          ),
        );
      }),
    );
  }

  Widget _blockHeader(String title, String action, VoidCallback onAction) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(children: [
      Expanded(child: Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: context.textPrimary))),
      AppButton(label: action, icon: Icons.add, dense: true, variant: AppButtonVariant.secondary, onPressed: onAction),
    ]),
  );

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    physics: const BouncingScrollPhysics(),
    padding: const EdgeInsets.all(16),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _CardSection(title: 'Academic Summary', icon: Icons.bar_chart_outlined, children: [
        _InfoRow('Class / Grade',    _na(widget.data['class'])),
        _InfoRow('Academic Year',    _na(widget.data['acadYear'])),
        _InfoRow('Admission No.',    _na(widget.data['admNo'])),
        _InfoRow('Institution',      _na(widget.data['institution'] ?? widget.data['school']), last: true),
      ]),
      const SizedBox(height: 18),

      // ── Performance History ─────────────────────────────────────
      _blockHeader('Performance History', 'Add Record', () => _showAddProgressDialog(context)),
      if (_loadingProgress)
        _card(context, const SkeletonList(rows: 3, rowHeight: 64))
      else if (_progress.isEmpty)
        _card(context, EmptyState(
          icon: Icons.insights_outlined,
          title: 'No performance records yet',
          message: 'Log scores, attendance and remarks to track progress over time.',
          actionLabel: 'Add Record',
          onAction: () => _showAddProgressDialog(context),
        ))
      else ...[
        ..._progress.map((r) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _ProgressRecordCard(record: r, onDelete: () => _deleteProgressRecord(r)),
        )),
        if (_progressHasMore)
          Center(child: AppButton(label: 'Load More', busyLabel: 'Loading…', variant: AppButtonVariant.secondary, dense: true,
              loading: _loadingMoreProgress, onPressed: _loadMoreProgress)),
      ],
      if ((widget.data['medHistory'] ?? '').isNotEmpty) ...[
        const SizedBox(height: 18),
        _CardSection(title: 'Medical Notes', icon: Icons.medication_outlined, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Text(widget.data['medHistory']!, style: TextStyle(fontSize: 13.5, color: context.textPrimary, height: 1.5)),
          ),
        ]),
      ],
      const SizedBox(height: 18),

      // ── Growth History ───────────────────────────────────────────
      _blockHeader('Growth History', 'Add Record', () => _showAddGrowthDialog(context)),
      if (_loadingGrowth)
        _card(context, const SkeletonList(rows: 3, rowHeight: 48))
      else if (_growth.isEmpty)
        _card(context, EmptyState(
          icon: Icons.straighten_outlined,
          title: 'No growth records yet',
          message: 'Log the first height/weight entry to start the growth chart.',
          actionLabel: 'Add Record',
          onAction: () => _showAddGrowthDialog(context),
        ))
      else ...[
        _GrowthChart(records: _growth),
        const SizedBox(height: 10),
        _card(context, Column(children: _growth.reversed.toList().asMap().entries.map((e) {
          final r = e.value;
          final isLast = e.key == _growth.length - 1;
          return Container(
            constraints: const BoxConstraints(minHeight: 48),
            padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
            decoration: isLast ? null : BoxDecoration(border: Border(bottom: BorderSide(color: context.border.withValues(alpha: 0.7)))),
            child: Row(children: [
              Expanded(child: Text(r.dateLabel, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.textPrimary))),
              Expanded(child: Text(r.heightCm != null ? '${r.heightCm!.toStringAsFixed(1)} cm' : '—',
                style: TextStyle(fontSize: 13, color: context.textSub, fontWeight: FontWeight.w500))),
              Expanded(child: Text(r.weightKg != null ? '${r.weightKg!.toStringAsFixed(1)} kg' : '—',
                style: TextStyle(fontSize: 13, color: context.textSub, fontWeight: FontWeight.w500))),
              IconButton(
                tooltip: 'Delete',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: _danger),
                onPressed: () => _deleteGrowthRecord(r),
              ),
            ]),
          );
        }).toList())),
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
      padding: const EdgeInsets.fromLTRB(12, 14, 16, 10),
      decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: context.border)),
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
              getDrawingHorizontalLine: (_) => FlLine(color: context.border, strokeWidth: 1)),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 34,
                getTitlesWidget: (v, meta) => Text(v.toInt().toString(), style: TextStyle(fontSize: 10, color: context.textHint)))),
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 28,
                getTitlesWidget: (v, meta) {
                  final i = v.toInt();
                  if (i < 0 || i >= records.length) return const SizedBox.shrink();
                  // Thin out labels so they don't overlap on longer histories.
                  if (records.length > 6 && i % (records.length / 5).ceil() != 0) return const SizedBox.shrink();
                  final d = records[i].date;
                  return Padding(padding: const EdgeInsets.only(top: 6),
                    child: Text('${d.day}/${d.month}', style: TextStyle(fontSize: 10, color: context.textHint)));
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
    Text(label, style: TextStyle(fontSize: 11.5, color: context.textSub, fontWeight: FontWeight.w600)),
  ]);
}

// A single Performance History entry — academic score, attendance, behaviour,
// etc. for one dated check-in.
class _ProgressRecordCard extends StatelessWidget {
  const _ProgressRecordCard({required this.record, required this.onDelete});
  final _ProgressRecordItem record;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final r = record;
    final chips = <({String label, String value})>[
      if (r.academicScore != null) (label: 'Academic Score', value: '${r.academicScore}%'),
      if (r.attendancePercent != null) (label: 'Attendance', value: '${r.attendancePercent!.toStringAsFixed(0)}%'),
      if (r.grade != null && r.grade!.isNotEmpty) (label: 'Grade', value: r.grade!),
      if (r.examResult != null && r.examResult!.isNotEmpty) (label: 'Exam Result', value: r.examResult!),
      if (r.behaviourRating != null && r.behaviourRating!.isNotEmpty) (label: 'Behaviour', value: r.behaviourRating!),
      if (r.communicationSkills != null && r.communicationSkills!.isNotEmpty) (label: 'Communication', value: r.communicationSkills!),
      if (r.leadership != null && r.leadership!.isNotEmpty) (label: 'Leadership', value: r.leadership!),
      if (r.sportsPerformance != null && r.sportsPerformance!.isNotEmpty) (label: 'Sports', value: r.sportsPerformance!),
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 12),
      decoration: BoxDecoration(
        color: context.cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: context.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.event_note_outlined, size: 15, color: _brand600),
          const SizedBox(width: 6),
          Expanded(child: Text(r.dateLabel, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: context.textPrimary))),
          SizedBox(width: 30, height: 30, child: IconButton(
            tooltip: 'Delete', padding: EdgeInsets.zero,
            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: _danger),
            onPressed: onDelete)),
        ]),
        if (chips.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: chips.map((c) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: context.surface2, borderRadius: BorderRadius.circular(8)),
            child: Text('${c.label}: ${c.value}', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: context.textSub)),
          )).toList()),
        ],
        if ((r.mentorRemarks ?? '').isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('Mentor: ${r.mentorRemarks}', style: TextStyle(fontSize: 12.5, color: context.textSub, fontWeight: FontWeight.w500, height: 1.4)),
        ],
        if ((r.teacherRemarks ?? '').isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('Teacher: ${r.teacherRemarks}', style: TextStyle(fontSize: 12.5, color: context.textSub, fontWeight: FontWeight.w500, height: 1.4)),
        ],
        if (chips.isEmpty && (r.mentorRemarks ?? '').isEmpty && (r.teacherRemarks ?? '').isEmpty) ...[
          const SizedBox(height: 6),
          Text('No details recorded for this entry.', style: TextStyle(fontSize: 12.5, color: context.textHint, fontWeight: FontWeight.w500)),
        ],
      ]),
    );
  }
}
