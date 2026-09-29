import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/utils/open_bytes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/phone_field_with_code.dart';
import '../../../core/widgets/photo_picker_widget.dart';
import '../../dashboard/presentation/dashboard_screen.dart' show dashboardRefreshProvider;
import '../../donors/presentation/donors_screen.dart' show demoLocalDonors, mockDonorData;
import '../student_lookups.dart';
import 'students_screen.dart' show demoLocalStudents, demoCentres;

// ── colours ───────────────────────────────────────────────────────────
const _brand600 = Color(0xFFFF9933);
const _brand100 = Color(0xFFFFE8CC);
const _amber600 = Color(0xFFE0921A);
const _coral500 = Color(0xFFF2685E);
const _onSurface1 = Color(0xFF15211E);
const _onSurface2 = Color(0xFF5A6B67);
const _onSurface3 = Color(0xFF93A29F);
const _border = Color(0xFFE5EBE9);
const _surface2 = Color(0xFFF4F7F6);
const _errorColor = Color(0xFFF2685E);

// ══════════════════════════════════════════════════════════════════════
class AddStudentScreen extends StatefulWidget {
  const AddStudentScreen({super.key});
  @override
  State<AddStudentScreen> createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends State<AddStudentScreen> {
  final _form = GlobalKey<FormState>();

  // controllers
  final _name        = TextEditingController();
  final _aadhaar     = TextEditingController();
  final _fatherName  = TextEditingController();
  final _motherName  = TextEditingController();
  final _guardian    = TextEditingController();
  final _relation    = TextEditingController();
  final _mobile      = TextEditingController();
  final _address     = TextEditingController();
  final _satNo       = TextEditingController();
  final _familyNotes = TextEditingController();
  final _schoolName  = TextEditingController();
  final _classGrade  = TextEditingController();
  final _admissionNo = TextEditingController();
  final _acadYear    = TextEditingController(text: '2025-26');
  final _performance = TextEditingController();
  final _schoolAddr  = TextEditingController();
  final _height      = TextEditingController();
  final _weight      = TextEditingController();
  final _medHistory  = TextEditingController();

  // Identity / government IDs
  final _penNo        = TextEditingController();
  final _cwcNo        = TextEditingController();
  final _abhaNo       = TextEditingController();
  final _rationCardNo = TextEditingController();
  final _missionVatsalyaNo = TextEditingController();
  final _caste         = TextEditingController();
  final _subCaste      = TextEditingController();

  // Financial / welfare
  final _bankDetails    = TextEditingController();
  final _siblingNames   = TextEditingController();
  final _incomeCertAmt  = TextEditingController();
  final _incomeCertRdNo = TextEditingController();

  // pickers
  String _dob         = '';
  String _admDate     = '';

  // toggles
  String _centreName  = '';
  String _centreId    = '';
  String _gender      = 'Male';
  // Keys from Settings → Student Status / Education Level (admin-managed).
  String _status      = 'ACTIVE';
  String? _eduLevel;
  bool   _sponsored   = false;
  final _sponsorAmt   = TextEditingController();
  String? _sponsorId;
  String? _sponsorName;

  bool _saving = false;
  Uint8List? _photoBytes;

  // Documents picked before the student exists — nothing to upload to yet, so
  // these are held here and pushed to /students/:id/documents right after
  // creation succeeds (mirrors the growth-record seeding below).
  final Map<String, ({String filename, Uint8List bytes})> _pendingDocs = {};
  final Map<String, List<({String filename, Uint8List bytes})>> _pendingMultiDocs = {};

  // loaded from API
  List<({String id, String name})> _centres = [];
  List<({String id, String name, String city, String phone})> _apiDonors = [];
  // Admin-managed support categories (Settings → Support Categories); the
  // picker is hidden entirely while this is empty.
  List<({String id, String label})> _categories = [];
  String? _categoryId;
  bool _loadingForm = true;

  @override
  void initState() {
    super.initState();
    _loadFormData();
    _loadCategories();
    StudentLookups.load(force: true).then((_) {
      if (!mounted) return;
      setState(() {
        final keys = StudentLookups.statuses.map((o) => o.key).toList();
        if (!keys.contains(_status) && keys.isNotEmpty) _status = keys.first;
      });
    });
  }

  // Separate from _loadFormData so a missing/older backend can't take the
  // whole form down with it — no categories just hides the picker.
  Future<void> _loadCategories() async {
    try {
      final r = await apiClient.get('/students/categories');
      final list = (r['data'] as List? ?? []);
      final cats = list.map<({String id, String label})>((c) {
        final m = c as Map<String, dynamic>;
        return (id: m['id'] as String? ?? '', label: m['label'] as String? ?? '');
      }).where((c) => c.id.isNotEmpty && c.label.isNotEmpty).toList();
      if (mounted) setState(() => _categories = cats);
    } catch (_) {/* picker stays hidden */}
  }

  List<({String id, String name, String city, String phone})> _fallbackDonors() {
    final all = [...demoLocalDonors, ...mockDonorData];
    return all.map<({String id, String name, String city, String phone})>((d) => (
      id:    d['id']     as String? ?? '',
      name:  d['name']   as String? ?? '',
      city:  d['city']   as String? ?? '',
      phone: (d['mobile'] ?? d['phone'] ?? d['whatsapp'] ?? '') as String,
    )).toList();
  }

  // Every donor, paged — a one-page fetch hid donor #101+ from the sponsor
  // picker (the backend caps limit at 100).
  static Future<List<dynamic>> _fetchAllDonors() async {
    final all = <dynamic>[];
    for (int page = 1; ; page++) {
      final r = await apiClient.get('/donors', params: {'limit': '100', 'page': '$page'});
      final inner = r['data'];
      final list = inner is List ? inner : <dynamic>[];
      all.addAll(list);
      final meta = r['meta'] as Map?;
      if (meta?['hasNext'] != true || list.isEmpty) break;
    }
    return all;
  }

  Future<void> _loadFormData() async {
    try {
      final donorsFuture = _fetchAllDonors();
      final cRaw = await apiClient.get('/students/centers');

      final cData = cRaw['data'];
      final cList = cData is List ? cData as List<dynamic> : <dynamic>[];
      final centres = cList.map<({String id, String name})>((c) {
        final m = c as Map<String, dynamic>;
        return (id: m['id'] as String, name: m['name'] as String);
      }).toList();

      final dList = await donorsFuture;
      final donors = dList.map<({String id, String name, String city, String phone})>((d) {
        final m = d as Map<String, dynamic>;
        return (id: m['id'] as String? ?? '', name: m['name'] as String? ?? '', city: m['city'] as String? ?? '',
                phone: (m['mobile'] ?? m['phone'] ?? '') as String);
      }).toList();

      if (mounted) setState(() {
        // Fall back to the shared centres list (managed via Manage Centres) so
        // newly added centres show up here dynamically when the API is unavailable.
        _centres    = centres.isNotEmpty ? centres : demoCentres;
        _apiDonors  = donors.isNotEmpty ? donors : _fallbackDonors();
        if (_centres.isNotEmpty) {
          _centreName = _centres.first.name;
          _centreId   = _centres.first.id;
        }
        _loadingForm = false;
      });
    } catch (_) {
      if (mounted) setState(() {
        _loadingForm = false;
        _centres    = demoCentres;
        if (_centres.isNotEmpty) {
          _centreName = _centres.first.name;
          _centreId   = _centres.first.id;
        }
        _apiDonors  = _fallbackDonors();
      });
    }
  }

  @override
  void dispose() {
    for (final c in [_name,_aadhaar,_fatherName,_motherName,_guardian,_relation,
      _mobile,_address,_satNo,_familyNotes,_schoolName,_classGrade,_admissionNo,
      _acadYear,_performance,_schoolAddr,_height,_weight,_medHistory,
      _penNo,_cwcNo,_abhaNo,_rationCardNo,_missionVatsalyaNo,_caste,_subCaste,
      _bankDetails,_siblingNames,_incomeCertAmt,_incomeCertRdNo,_sponsorAmt]) { c.dispose(); }
    super.dispose();
  }

  Future<void> _pickDate(void Function(String) onPicked) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(2010),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: const ColorScheme.light(primary: _brand600)),
        child: child!,
      ),
    );
    if (picked != null) {
      onPicked('${picked.day.toString().padLeft(2,'0')} / ${picked.month.toString().padLeft(2,'0')} / ${picked.year}');
    }
  }

  void _showSponsorPicker() {
    final searchCtrl = TextEditingController();
    String query = '';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(builder: (ctx, setSheet) {
        final q = query.trim().toLowerCase();
        final qDigits = q.replaceAll(RegExp(r'[^0-9]'), '');
        final filtered = q.isEmpty
            ? _apiDonors
            : _apiDonors.where((d) {
                final byName = d.name.toLowerCase().contains(q);
                final byPhone = qDigits.isNotEmpty &&
                    d.phone.replaceAll(RegExp(r'[^0-9]'), '').contains(qDigits);
                return byName || byPhone;
              }).toList();
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: SizedBox(
            height: MediaQuery.of(ctx).size.height * 0.7,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox(height: 8),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: context.border, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 14),
              const Text('Link a Donor as Sponsor', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: searchCtrl,
                  autofocus: false,
                  onChanged: (v) => setSheet(() => query = v),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: 'Search by name or mobile number',
                    hintStyle: TextStyle(color: context.textHint, fontWeight: FontWeight.w400),
                    prefixIcon: Icon(Icons.search, color: context.textHint, size: 20),
                    suffixIcon: query.isEmpty ? null : IconButton(
                      icon: Icon(Icons.close, color: context.textHint, size: 18),
                      onPressed: () { searchCtrl.clear(); setSheet(() => query = ''); },
                    ),
                    filled: true, fillColor: _surface2,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _brand600, width: 1.5)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: filtered.isEmpty
                    ? Center(child: Text(_apiDonors.isEmpty ? 'No donors available' : 'No donors match your search',
                        style: const TextStyle(color: _onSurface3, fontWeight: FontWeight.w600)))
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => Divider(height: 1, color: context.border),
                        itemBuilder: (_, i) {
                          final d = filtered[i];
                          return ListTile(
                            leading: CircleAvatar(backgroundColor: _brand100, child: Text(d.name.isNotEmpty ? d.name[0].toUpperCase() : '?', style: const TextStyle(color: _brand600, fontWeight: FontWeight.w800))),
                            title: Text(d.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                            subtitle: Text([d.city, d.phone].where((s) => s.isNotEmpty).join('  ·  '),
                                style: TextStyle(color: context.textHint, fontWeight: FontWeight.w500)),
                            trailing: Icon(Icons.chevron_right, color: context.textHint),
                            onTap: () {
                              setState(() { _sponsorId = d.id; _sponsorName = d.name; });
                              Navigator.pop(context);
                            },
                          );
                        },
                      ),
              ),
            ]),
          ),
        );
      }),
    );
  }

  String _toIso(String ddmmyyyy) {
    // Input: "dd / mm / yyyy" or "dd/mm/yyyy"
    final parts = ddmmyyyy.replaceAll(' ', '').split('/');
    if (parts.length != 3) return '';
    return '${parts[2]}-${parts[1].padLeft(2,'0')}-${parts[0].padLeft(2,'0')}';
  }

  void _setPendingDoc(String category, String? filename, Uint8List? bytes) {
    if (filename != null && bytes != null) {
      _pendingDocs[category] = (filename: filename, bytes: bytes);
    } else {
      _pendingDocs.remove(category);
    }
  }

  void _setPendingMultiDocs(String category, List<({String filename, Uint8List bytes})> files) {
    _pendingMultiDocs[category] = files;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    if (_dob.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please select Date of Birth', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: _coral500, behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    if (_centreId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Please select a centre', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: _coral500, behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    // The sponsorship is only created with an amount (backend requires it).
    final sponsorAmount = int.tryParse(_sponsorAmt.text.trim());
    if (_sponsored && _sponsorId != null && (sponsorAmount == null || sponsorAmount < 1)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Enter the annual sponsorship amount', style: TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: _coral500, behavior: SnackBarBehavior.floating,
      ));
      return;
    }
    setState(() => _saving = true);
    try {
      // Performance and school address have no columns of their own — keep
      // them in the education remarks instead of silently dropping them.
      final eduRemarks = [
        if (_performance.text.trim().isNotEmpty) 'Performance: ${_performance.text.trim()}',
        if (_schoolAddr.text.trim().isNotEmpty) 'Institution address: ${_schoolAddr.text.trim()}',
      ].join('\n');
      final photoB64 = _photoBytes != null ? base64Encode(_photoBytes!) : null;
      final body = <String, dynamic>{
        'name':       _name.text.trim(),
        'dob':        _toIso(_dob),
        'gender':     _gender == 'Male' ? 'MALE' : 'FEMALE',
        'centerId':   _centreId,
        'status':     _status,
        if (_categoryId != null) 'categoryId': _categoryId,
        if (_eduLevel != null) 'educationLevel': _eduLevel,
        if (eduRemarks.isNotEmpty) 'educationRemarks': eduRemarks,
        if (photoB64 != null) 'photo': photoB64,
        if (_classGrade.text.trim().isNotEmpty) 'class': _classGrade.text.trim(),
        if (_schoolName.text.trim().isNotEmpty) 'school': _schoolName.text.trim(),
        if (_fatherName.text.trim().isNotEmpty) 'fatherName': _fatherName.text.trim(),
        if (_motherName.text.trim().isNotEmpty) 'motherName': _motherName.text.trim(),
        if (_guardian.text.trim().isNotEmpty)   'guardianName': _guardian.text.trim(),
        if (_relation.text.trim().isNotEmpty)   'guardianRelation': _relation.text.trim(),
        if (_mobile.text.trim().isNotEmpty)     'guardianPhone': _mobile.text.trim(),
        if (_address.text.trim().isNotEmpty)    'address': _address.text.trim(),
        if (_admDate.isNotEmpty)                'admissionDate': _toIso(_admDate),
        if (_admissionNo.text.trim().isNotEmpty) 'admissionNo': _admissionNo.text.trim(),
        if (_acadYear.text.trim().isNotEmpty)   'academicYear': _acadYear.text.trim(),
        if (_medHistory.text.trim().isNotEmpty) 'medicalNotes': _medHistory.text.trim(),
        if (_familyNotes.text.trim().isNotEmpty) 'notes': _familyNotes.text.trim(),
        if (_aadhaar.text.trim().isNotEmpty)    'aadhaarNumber': _aadhaar.text.trim(),
        if (_satNo.text.trim().isNotEmpty)      'satNumber': _satNo.text.trim(),
        if (_penNo.text.trim().isNotEmpty)      'penNumber': _penNo.text.trim(),
        if (_cwcNo.text.trim().isNotEmpty)      'cwcNumber': _cwcNo.text.trim(),
        if (_abhaNo.text.trim().isNotEmpty)     'abhaNumber': _abhaNo.text.trim(),
        if (_rationCardNo.text.trim().isNotEmpty) 'rationCardNumber': _rationCardNo.text.trim(),
        if (_missionVatsalyaNo.text.trim().isNotEmpty) 'missionVatsalyaNumber': _missionVatsalyaNo.text.trim(),
        if (_caste.text.trim().isNotEmpty)      'caste': _caste.text.trim(),
        if (_subCaste.text.trim().isNotEmpty)   'subCaste': _subCaste.text.trim(),
        if (_bankDetails.text.trim().isNotEmpty) 'bankAccountDetails': _bankDetails.text.trim(),
        if (_siblingNames.text.trim().isNotEmpty) 'siblingNames': _siblingNames.text.trim(),
        if (_incomeCertAmt.text.trim().isNotEmpty) 'incomeCertificateAmount': int.tryParse(_incomeCertAmt.text.trim()),
        if (_incomeCertRdNo.text.trim().isNotEmpty) 'incomeCertificateRdNumber': _incomeCertRdNo.text.trim(),
      };

      // Bundle any documents picked before the student exists into this same
      // request (rather than a separate follow-up call) — so they're created
      // together with the real new student id, and survive verbatim if this
      // whole request gets queued for Super Admin approval instead of
      // executing immediately (see CreateStudentDto.documents on the backend).
      final documents = <Map<String, dynamic>>[
        for (final entry in _pendingDocs.entries)
          {
            'category': entry.key,
            'fileName': entry.value.filename,
            'data': base64Encode(entry.value.bytes),
          },
        for (final entry in _pendingMultiDocs.entries)
          for (final file in entry.value)
            {
              'category': entry.key,
              'fileName': file.filename,
              'data': base64Encode(file.bytes),
            },
      ];
      if (documents.isNotEmpty) body['documents'] = documents;

      Map<String, dynamic> res;
      try {
        res = await apiClient.post('/students', body);
      } catch (e) {
        // Never fall back to a local-only child: it showed up with empty
        // fields and vanished on reload. A timeout may still have saved it on
        // the server, so say so rather than inviting a duplicate.
        final timedOut = e is DioException && e.response == null &&
            (e.type == DioExceptionType.receiveTimeout || e.type == DioExceptionType.sendTimeout);
        if (mounted) {
          setState(() => _saving = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                timedOut
                    ? 'The server took too long to answer. Check the Students list before trying again, the child may already be saved.'
                    : ApiClient.errorMessage(e, fallback: 'Could not save the child.'),
                style: const TextStyle(fontWeight: FontWeight.w700)),
            backgroundColor: _coral500, behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 6),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ));
        }
        return;
      }

      // Non-Super-Admins: the backend queues this for approval instead of
      // creating it. Don't add anything locally — it must wait for approval.
      final pending = (res['meta'] as Map?)?['pendingApproval'] == true;
      if (pending) {
        if (mounted) {
          setState(() => _saving = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.hourglass_top_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Flexible(child: Text(
                documents.isNotEmpty
                    ? 'Submitted for Super Admin approval, documents included'
                    : 'Submitted for Super Admin approval',
                style: const TextStyle(fontWeight: FontWeight.w700),
              )),
            ]),
            backgroundColor: _amber600, behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ));
          context.go('/students');
        }
        return;
      }

      final created = (res['data'] as Map?)?.cast<String, dynamic>();
      final savedId = created?['id'] as String?;
      final studentId = savedId ?? 'local-${DateTime.now().microsecondsSinceEpoch}';

      // Link the chosen sponsor — the form collected it but never sent it,
      // so the sponsorship was lost on every save.
      String? sponsorWarning;
      if (savedId != null && _sponsored && _sponsorId != null && sponsorAmount != null) {
        try {
          await apiClient.post('/students/$savedId/sponsorships', {
            'donorId': _sponsorId,
            'amount': sponsorAmount,
            'frequency': 'ANNUAL',
          });
        } catch (e) {
          sponsorWarning = ApiClient.errorMessage(e, fallback: 'The sponsor could not be linked.');
        }
      }

      // Full local record so the detail Profile tab shows everything immediately.
      demoLocalStudents.insert(0, {
        'id':          studentId,
        'childId':     created?['childId'] ?? 'SKT-C-new',
        'name':        _name.text.trim(),
        'gender':      _gender == 'Male' ? 'MALE' : 'FEMALE',
        'dob':         _toIso(_dob),
        'status':      _status,
        'educationLevel': _eduLevel,
        'class':       _classGrade.text.trim(),
        'school':      _schoolName.text.trim(),
        'center':      {'name': _centreName},
        // Same nested shape the backend returns, so the detail screen and
        // list card show the category before the next server refresh.
        if (_categoryId != null)
          'category': created?['category'] ??
            {'id': _categoryId, 'label': _categories.firstWhere((c) => c.id == _categoryId, orElse: () => (id: '', label: '')).label},
        'aadhaar':     _aadhaar.text.trim(),
        'admDate':     _admDate.isNotEmpty ? _toIso(_admDate) : '',
        'admissionNo': _admissionNo.text.trim(),
        'academicYear': _acadYear.text.trim(),
        'fatherName':  _fatherName.text.trim(),
        'motherName':  _motherName.text.trim(),
        'guardian':    _guardian.text.trim(),
        'relation':    _relation.text.trim(),
        'mobile':      _mobile.text.trim(),
        'address':     _address.text.trim(),
        'sat':         _satNo.text.trim(),
        'familyNotes': _familyNotes.text.trim(),
        'height':      _height.text.trim(),
        'weight':      _weight.text.trim(),
        'medHistory':  _medHistory.text.trim(),
        'penNumber':        _penNo.text.trim(),
        'cwcNumber':        _cwcNo.text.trim(),
        'abhaNumber':       _abhaNo.text.trim(),
        'rationCardNumber': _rationCardNo.text.trim(),
        'missionVatsalyaNumber': _missionVatsalyaNo.text.trim(),
        'caste':            _caste.text.trim(),
        'subCaste':         _subCaste.text.trim(),
        'bankAccountDetails': _bankDetails.text.trim(),
        'siblingNames':       _siblingNames.text.trim(),
        'incomeCertificateAmount':   _incomeCertAmt.text.trim(),
        'incomeCertificateRdNumber': _incomeCertRdNo.text.trim(),
        if (photoB64 != null) 'photo': photoB64,
        'sponsorships': _sponsored && _sponsorId != null && sponsorWarning == null
            ? [{'donor': {'id': _sponsorId, 'name': _sponsorName ?? ''}, 'amount': sponsorAmount}]
            : <Map<String, dynamic>>[],
      });

      // Seed the first dated growth record from the intake height/weight, so
      // Growth History has a starting point instead of an ad-hoc snapshot.
      final h = double.tryParse(_height.text.trim());
      final w = double.tryParse(_weight.text.trim());
      if (savedId != null && (h != null || w != null)) {
        final today = DateTime.now();
        final iso = '${today.year.toString().padLeft(4,'0')}-${today.month.toString().padLeft(2,'0')}-${today.day.toString().padLeft(2,'0')}';
        try {
          await apiClient.post('/students/$savedId/growth', {
            'date': iso,
            if (h != null) 'heightCm': h,
            if (w != null) 'weightKg': w,
          });
        } catch (_) {}
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Flexible(child: Text(
              sponsorWarning == null ? 'Child enrolled successfully!' : 'Child enrolled, but: $sponsorWarning',
              style: const TextStyle(fontWeight: FontWeight.w700))),
          ]),
          backgroundColor: sponsorWarning == null ? _brand600 : _amber600,
          behavior: SnackBarBehavior.floating,
          width: sponsorWarning == null ? 280 : null,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
        ProviderScope.containerOf(context).read(dashboardRefreshProvider.notifier).state++;
        context.go('/students/$studentId');
      }
    } catch (e) {
      // Anything unexpected must still end the spinner and say what happened.
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ApiClient.errorMessage(e, fallback: 'Could not save the child.'),
              style: const TextStyle(fontWeight: FontWeight.w700)),
          backgroundColor: _coral500, behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      body: Column(children: [
        // ── Compact header (back + title only) ────────────────────
        Container(
          padding: EdgeInsets.fromLTRB(4, top + 6, 16, 10),
          decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFE5EBE9)))),
          child: Row(children: [
            IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Color(0xFF15211E)), onPressed: () => context.go('/students')),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Add Child', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF15211E))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: _brand100, borderRadius: BorderRadius.circular(6)),
                child: const Text('ID  ·  SKT-C-auto', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: _brand600)),
              ),
            ]),
          ]),
        ),

        // ── form ───────────────────────────────────────────────────
        Expanded(
          child: Form(
            key: _form,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // ── Profile Photo ─────────────────────────────────────
                Center(child: PhotoPickerCircle(
                  label: 'Child Photo', size: 88,
                  onImageChanged: (b) => setState(() => _photoBytes = b),
                )),
                const SizedBox(height: 16),

                // ── Basic Profile ────────────────────────────────────
                _SectionCard(title: 'Basic Profile', children: [
                  _FieldLabel('Centre'),
                  if (_loadingForm)
                    const Padding(padding: EdgeInsets.symmetric(vertical: 4),
                      child: Text('Loading centres…', style: TextStyle(color: _onSurface3, fontSize: 13)))
                  else if (_centres.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(children: [
                        const Expanded(child: Text('No centres yet — add one first.', style: TextStyle(color: _onSurface3, fontSize: 13))),
                        TextButton(
                          onPressed: () async {
                            await context.push('/centres');
                            if (mounted) _loadFormData();
                          },
                          child: const Text('Add Centre', style: TextStyle(fontWeight: FontWeight.w700)),
                        ),
                      ]),
                    )
                  else
                    _SegmentedToggle(
                      options: _centres.map((c) => c.name).toList(),
                      value: _centreName,
                      onChanged: (v) => setState(() {
                        _centreName = v;
                        _centreId = _centres.firstWhere((c) => c.name == v, orElse: () => _centres.first).id;
                      }),
                    ),
                  const SizedBox(height: 14),
                  _FieldLabel('Full Name'),
                  _textField(context, _name, hint: "Child's full name", validator: (v) => v!.isEmpty ? 'Required' : null),
                  const SizedBox(height: 14),
                  _FieldLabel('Date of Birth'),
                  _DateTapField(value: _dob, hint: 'DD / MM / YYYY', onTap: () => _pickDate((v) => setState(() => _dob = v))),
                  const SizedBox(height: 14),
                  _FieldLabel('Gender'),
                  _SegmentedToggle(options: const ['Male', 'Female'], value: _gender, onChanged: (v) => setState(() => _gender = v)),
                  const SizedBox(height: 14),
                  _FieldLabel('Aadhaar Number'),
                  _textField(context, _aadhaar, hint: '0000 0000 0000', keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(12)]),
                  const SizedBox(height: 14),
                  _FieldLabel('Date of Admission'),
                  _DateTapField(value: _admDate, hint: 'DD / MM / YYYY', onTap: () => _pickDate((v) => setState(() => _admDate = v))),
                  const SizedBox(height: 14),
                  _FieldLabel('Current Status'),
                  _StatusChips(value: _status, onChanged: (v) => setState(() => _status = v)),
                  if (_categories.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    _FieldLabel('Support Category (optional)'),
                    Wrap(spacing: 8, runSpacing: 8, children: _categories.map((c) {
                      final active = _categoryId == c.id;
                      return GestureDetector(
                        // Tapping the selected chip clears it — category stays optional.
                        onTap: () => setState(() => _categoryId = active ? null : c.id),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: active ? _brand100 : context.scaffoldBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: active ? _brand600 : context.border),
                          ),
                          child: Text(c.label, style: TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w700,
                            color: active ? _brand600 : context.textSub)),
                        ),
                      );
                    }).toList()),
                  ],
                ]),
                const SizedBox(height: 14),

                // ── Family Details ───────────────────────────────────
                _SectionCard(title: 'Family Details', children: [
                  _FieldLabel("Father's Name"),
                  _textField(context, _fatherName, hint: "Father's name"),
                  const SizedBox(height: 14),
                  _FieldLabel("Mother's Name"),
                  _textField(context, _motherName, hint: "Mother's name"),
                  const SizedBox(height: 14),
                  _FieldLabel('Guardian'),
                  _textField(context, _guardian, hint: 'Guardian name'),
                  const SizedBox(height: 14),
                  _FieldLabel('Relationship'),
                  _textField(context, _relation, hint: 'e.g. Mother'),
                  const SizedBox(height: 14),
                  _FieldLabel('Mobile Number'),
                  PhoneFieldWithCode(ctrl: _mobile, required: true),
                  const SizedBox(height: 14),
                  _FieldLabel('Address'),
                  _textField(context, _address, hint: 'Residential address', maxLines: 2),
                  const SizedBox(height: 14),
                  _FieldLabel('SAT Number'),
                  _textField(context, _satNo, hint: 'SAT-0000'),
                  const SizedBox(height: 14),
                  _FieldLabel('Family Photo'),
                  _UploadBox(label: 'Upload family photo', icon: Icons.family_restroom_outlined,
                    onFilesChanged: (f) => _setPendingMultiDocs('Family Photo', f)),
                  const SizedBox(height: 14),
                  _FieldLabel('Family Background Notes'),
                  _textField(context, _familyNotes, hint: 'Context about the family…', maxLines: 3),
                  const SizedBox(height: 14),
                  _FieldLabel("Parents' Aadhaar Photo"),
                  _UploadBox(label: "Upload parents' Aadhaar", icon: Icons.badge_outlined,
                    onFilesChanged: (f) => _setPendingMultiDocs("Parents' Aadhaar Photo", f)),
                ]),
                const SizedBox(height: 14),

                // ── Identity & Government IDs ────────────────────────
                _SectionCard(title: 'Identity & Government IDs', children: [
                  _FieldLabel('PEN Number'),
                  _textField(context, _penNo, hint: 'Permanent Enrolment Number'),
                  const SizedBox(height: 14),
                  _FieldLabel('CWC Number'),
                  _textField(context, _cwcNo, hint: 'Child Welfare Committee number'),
                  const SizedBox(height: 14),
                  _FieldLabel('ABHA Card Number'),
                  _textField(context, _abhaNo, hint: 'Ayushman Bharat Health Account'),
                  const SizedBox(height: 14),
                  _FieldLabel('Ration Card Number'),
                  _textField(context, _rationCardNo, hint: 'Ration card number'),
                  const SizedBox(height: 14),
                  _FieldLabel('Mission Vatsalya Number'),
                  _textField(context, _missionVatsalyaNo, hint: 'Mission Vatsalya scheme number'),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _FieldLabel('Caste'),
                      _textField(context, _caste, hint: 'Caste'),
                    ])),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _FieldLabel('Sub-caste'),
                      _textField(context, _subCaste, hint: 'Sub-caste'),
                    ])),
                  ]),
                ]),
                const SizedBox(height: 14),

                // ── Financial & Welfare Details ──────────────────────
                _SectionCard(title: 'Financial & Welfare Details', children: [
                  _FieldLabel('Sibling Name(s)'),
                  _textField(context, _siblingNames, hint: 'If any, comma-separated'),
                  const SizedBox(height: 14),
                  _FieldLabel('Bank Account Details'),
                  _textField(context, _bankDetails, hint: 'Account no., IFSC, bank name', maxLines: 2),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _FieldLabel('Income Certificate Amount'),
                      _textField(context, _incomeCertAmt, hint: '₹ amount', keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
                    ])),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _FieldLabel('Income Cert. RD Number'),
                      _textField(context, _incomeCertRdNo, hint: 'RD number'),
                    ])),
                  ]),
                ]),
                const SizedBox(height: 14),

                // ── Educational Details ──────────────────────────────
                _SectionCard(title: 'Educational Details', children: [
                  _FieldLabel('Education Level (optional)'),
                  if (StudentLookups.educationLevels.isEmpty)
                    Text('No education levels yet. Add them in Settings → Education Levels.',
                        style: TextStyle(fontSize: 12.5, color: context.textHint, fontWeight: FontWeight.w500))
                  else
                    Wrap(spacing: 8, runSpacing: 8, children: StudentLookups.educationLevels.map((o) {
                      final active = _eduLevel == o.key;
                      return GestureDetector(
                        // Tapping the selected level clears it — it stays optional.
                        onTap: () => setState(() => _eduLevel = active ? null : o.key),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: active ? _brand100 : context.scaffoldBg,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: active ? _brand600 : context.border),
                          ),
                          child: Text(o.label, style: TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w700,
                            color: active ? _brand600 : context.textSub)),
                        ),
                      );
                    }).toList()),
                  const SizedBox(height: 14),
                  _FieldLabel('School / College Name'),
                  _textField(context, _schoolName, hint: 'Institution name'),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _FieldLabel('Class / Grade'),
                      _textField(context, _classGrade, hint: 'e.g. Class 6'),
                    ])),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _FieldLabel('Admission No.'),
                      _textField(context, _admissionNo, hint: 'Number'),
                    ])),
                  ]),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _FieldLabel('Academic Year'),
                      _textField(context, _acadYear, hint: '2025-26'),
                    ])),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _FieldLabel('Performance'),
                      _textField(context, _performance, hint: 'e.g. Above Average'),
                    ])),
                  ]),
                  const SizedBox(height: 14),
                  _FieldLabel('Address'),
                  _textField(context, _schoolAddr, hint: 'School / college address', maxLines: 2),
                  const SizedBox(height: 14),
                  _FieldLabel('Educational Documents'),
                  _UploadBox(label: 'Upload report card / TC / certificates', icon: Icons.description_outlined,
                    onFilesChanged: (f) => _setPendingMultiDocs('Educational Documents', f)),
                ]),
                const SizedBox(height: 14),

                // ── Health & Medical ─────────────────────────────────
                _SectionCard(title: 'Health & Medical', children: [
                  Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _FieldLabel('Height (cm)'),
                      _textField(context, _height, hint: 'e.g. 132', keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                    ])),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _FieldLabel('Weight (kg)'),
                      _textField(context, _weight, hint: 'e.g. 28', keyboardType: const TextInputType.numberWithOptions(decimal: true)),
                    ])),
                  ]),
                  Padding(padding: const EdgeInsets.only(top: 6), child: Text(
                    'Saved as the first dated entry in Growth History (see the Progress tab).',
                    style: TextStyle(fontSize: 11.5, color: context.textHint, fontWeight: FontWeight.w500))),
                  const SizedBox(height: 14),
                  _FieldLabel('Medical History'),
                  _textField(context, _medHistory, hint: 'Allergies, conditions, notes…', maxLines: 3),
                  const SizedBox(height: 14),
                  _FieldLabel('Medical Documents'),
                  _UploadBox(label: 'Upload medical reports / prescriptions', icon: Icons.medical_services_outlined,
                    onFilesChanged: (f) => _setPendingMultiDocs('Medical Documents', f)),
                ]),
                const SizedBox(height: 14),

                // ── Sponsorship ──────────────────────────────────────
                _SectionCard(title: 'Sponsorship', children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Sponsored Child?', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.textPrimary)),
                      const SizedBox(height: 2),
                      Text('Link a donor as sponsor', style: TextStyle(fontSize: 12.5, color: context.textHint, fontWeight: FontWeight.w500)),
                    ]),
                    Switch(value: _sponsored, onChanged: (v) { setState(() { _sponsored = v; if (!v) { _sponsorId = null; _sponsorName = null; } else { _showSponsorPicker(); } }); }, activeColor: _brand600),
                  ]),
                  if (_sponsored && _sponsorName != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(13),
                      decoration: BoxDecoration(color: _brand100, borderRadius: BorderRadius.circular(14)),
                      child: Row(children: [
                        CircleAvatar(radius: 20, backgroundColor: _brand600, child: Text(_sponsorName![0], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800))),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(_sponsorName!, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                          Text('Sponsor ID · $_sponsorId', style: TextStyle(fontSize: 12, color: context.textSub, fontWeight: FontWeight.w500)),
                        ])),
                        GestureDetector(
                          onTap: _showSponsorPicker,
                          child: const Text('Change', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _brand600)),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 12),
                    _FieldLabel('Annual Sponsorship Amount (₹)'),
                    _textField(context, _sponsorAmt, hint: 'e.g. 24000', keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
                  ] else if (_sponsored) ...[
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: _showSponsorPicker,
                      child: Container(
                        width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(color: _brand100, borderRadius: BorderRadius.circular(14), border: Border.all(color: _brand600, width: 1.5)),
                        child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.link, color: _brand600, size: 18),
                          SizedBox(width: 8),
                          Text('Link a donor as sponsor', style: TextStyle(fontWeight: FontWeight.w700, color: _brand600)),
                        ]),
                      ),
                    ),
                  ],
                ]),
                const SizedBox(height: 14),

                // ── Documents ────────────────────────────────────────
                _SectionCard(title: 'Documents', children: [
                  _DocUploadRow(icon: Icons.credit_card_outlined,   label: 'Aadhaar Card',
                    onChanged: (fn, bytes) => _setPendingDoc('Aadhaar Card', fn, bytes)),
                  const SizedBox(height: 10),
                  _DocUploadRow(icon: Icons.article_outlined,        label: 'Birth Certificate',
                    onChanged: (fn, bytes) => _setPendingDoc('Birth Certificate', fn, bytes)),
                  const SizedBox(height: 10),
                  _DocUploadRow(icon: Icons.transfer_within_a_station_outlined, label: 'Transfer Certificate',
                    onChanged: (fn, bytes) => _setPendingDoc('Transfer Certificate', fn, bytes)),
                  const SizedBox(height: 10),
                  _DocUploadRow(icon: Icons.medical_services_outlined, label: 'Medical Reports',
                    onChanged: (fn, bytes) => _setPendingDoc('Medical Reports', fn, bytes)),
                ]),
                const SizedBox(height: 20),

                // ── Inline action buttons ──────────────────────────
                Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                  GestureDetector(
                    onTap: () => context.go('/students'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFD8E5E0), width: 1.5),
                      ),
                      child: const Text('Cancel', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF5A6B67))),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _saving ? null : _save,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 13),
                      decoration: BoxDecoration(
                        color: _saving ? const Color(0xFFFF9933).withValues(alpha: 0.6) : _brand600,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : const Text('Enrol Child', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                    ),
                  ),
                ])),
                const SizedBox(height: 24),
              ]),
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

// ── widgets ───────────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Padding(padding: const EdgeInsets.only(left: 2, bottom: 8),
      child: Text(title, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: context.textSub, letterSpacing: 0.5))),
    Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(20), border: Border.all(color: context.border),
        boxShadow: const [BoxShadow(color: Color(0x080D2822), blurRadius: 6, offset: Offset(0, 2))]),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    ),
  ]);
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.textPrimary)),
  );
}

Widget _textField(BuildContext ctx, TextEditingController ctrl, {String hint='', TextInputType? keyboardType, int maxLines=1,
  TextCapitalization textCapitalization = TextCapitalization.words, List<TextInputFormatter>? inputFormatters, String? Function(String?)? validator}) =>
  TextFormField(
    controller: ctrl, keyboardType: maxLines > 1 ? TextInputType.multiline : keyboardType,
    textCapitalization: textCapitalization, maxLines: maxLines, inputFormatters: inputFormatters, validator: validator,
    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: ctx.textPrimary),
    decoration: InputDecoration(
      hintText: hint, hintStyle: TextStyle(color: ctx.textHint, fontWeight: FontWeight.w500, fontSize: 14),
      filled: true, fillColor: ctx.scaffoldBg, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13), isDense: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: ctx.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: ctx.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _brand600, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _errorColor)),
    ),
  );

class _DateTapField extends StatelessWidget {
  const _DateTapField({required this.value, required this.hint, required this.onTap});
  final String value, hint;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      height: 48, padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(color: context.scaffoldBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: context.border)),
      child: Row(children: [
        Expanded(child: Text(value.isEmpty ? hint : value,
          style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: value.isEmpty ? context.textHint : context.textPrimary))),
        Icon(Icons.calendar_today_outlined, size: 18, color: context.textHint),
      ]),
    ),
  );
}

class _SegmentedToggle extends StatelessWidget {
  const _SegmentedToggle({required this.options, required this.value, required this.onChanged});
  final List<String> options;
  final String value;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(color: context.scaffoldBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: context.border)),
    child: Row(children: options.map((o) {
      final active = value == o;
      return Expanded(child: GestureDetector(
        onTap: () => onChanged(o),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(color: active ? _brand600 : Colors.transparent, borderRadius: BorderRadius.circular(10)),
          child: Text(o, textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: active ? Colors.white : context.textSub)),
        ),
      ));
    }).toList()),
  );
}

class _StatusChips extends StatelessWidget {
  const _StatusChips({required this.value, required this.onChanged});
  final String value; // status key
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 8, runSpacing: 8, children: StudentLookups.statuses.map((o) {
      final active = value == o.key;
      final c = StudentLookups.statusColor(o.key);
      return GestureDetector(
        onTap: () => onChanged(o.key),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: active ? c : context.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: active ? c : context.border, width: 1.5),
          ),
          child: Text(o.label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: active ? Colors.white : context.textSub)),
        ),
      );
    }).toList());
  }
}

class _UploadBox extends StatefulWidget {
  const _UploadBox({required this.label, required this.icon, required this.onFilesChanged});
  final String label;
  final IconData icon;
  final void Function(List<({String filename, Uint8List bytes})> files) onFilesChanged;
  @override
  State<_UploadBox> createState() => _UploadBoxState();
}

class _UploadBoxState extends State<_UploadBox> {
  final List<({String filename, Uint8List bytes})> _files = [];
  bool _loading = false;

  Future<void> _pickFile() async {
    setState(() => _loading = true);
    try {
      final result = await FilePicker.platform.pickFiles(allowMultiple: false, withData: true);
      final bytes = result?.files.single.bytes;
      if (result != null && bytes != null && mounted) {
        setState(() => _files.add((filename: result.files.single.name, bytes: bytes)));
        widget.onFilesChanged(_files);
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    GestureDetector(
      onTap: _loading ? null : _pickFile,
      child: Container(
        width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(color: context.scaffoldBg, borderRadius: BorderRadius.circular(14), border: Border.all(color: context.border, width: 1.5)),
        child: Column(children: [
          _loading
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, color: _brand600))
            : Icon(widget.icon, size: 26, color: context.textHint),
          const SizedBox(height: 6),
          Text(widget.label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: context.textHint)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 7),
            decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: context.border)),
            child: Text('Select File', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.textSub)),
          ),
        ]),
      ),
    ),
    if (_files.isNotEmpty) ...[
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 6, children: _files.asMap().entries.map((e) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: _brand100, borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.insert_drive_file_outlined, size: 14, color: _brand600),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(e.value.filename, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _brand600), overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 6),
          GestureDetector(onTap: () {
            setState(() => _files.removeAt(e.key));
            widget.onFilesChanged(_files);
          }, child: const Icon(Icons.close, size: 13, color: _brand600)),
        ]),
      )).toList()),
    ],
  ]);
}

class _DocUploadRow extends StatefulWidget {
  const _DocUploadRow({required this.icon, required this.label, required this.onChanged});
  final IconData icon;
  final String label;
  final void Function(String? filename, Uint8List? bytes) onChanged;
  @override
  State<_DocUploadRow> createState() => _DocUploadRowState();
}

class _DocUploadRowState extends State<_DocUploadRow> {
  String? _filename;
  Uint8List? _bytes;
  bool _loading = false;

  Future<void> _pickFile() async {
    setState(() => _loading = true);
    try {
      final result = await FilePicker.platform.pickFiles(allowMultiple: false, withData: true);
      if (result != null && result.files.isNotEmpty && mounted) {
        setState(() {
          _filename = result.files.single.name;
          _bytes = result.files.single.bytes;
        });
        widget.onChanged(_filename, _bytes);
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  void _view() {
    if (_bytes == null) return;
    openBytesInBrowser(_bytes!, _filename ?? 'document');
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: _loading ? null : _pickFile,
    child: Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: _filename != null ? _brand100 : context.scaffoldBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _filename != null ? _brand600.withValues(alpha: 0.4) : context.border),
      ),
      child: Row(children: [
        Container(width: 38, height: 38,
          decoration: BoxDecoration(color: _filename != null ? _brand600 : context.cardBg, borderRadius: BorderRadius.circular(10)),
          child: _loading
            ? const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: _brand600)))
            : Icon(widget.icon, size: 20, color: _filename != null ? Colors.white : context.textSub)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.textPrimary)),
          if (_filename != null) Text(_filename!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _brand600), overflow: TextOverflow.ellipsis),
        ])),
        if (_filename != null) ...[
          GestureDetector(
            onTap: _view,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              margin: const EdgeInsets.only(left: 6),
              decoration: BoxDecoration(color: _brand600, borderRadius: BorderRadius.circular(8)),
              child: const Text('View', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
          ),
          GestureDetector(
            onTap: () {
              setState(() { _filename = null; _bytes = null; });
              widget.onChanged(null, null);
            },
            child: const Padding(padding: EdgeInsets.only(left: 8), child: Icon(Icons.close, size: 18, color: _coral500)),
          ),
        ] else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: context.border)),
            child: Text('Select', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: context.textSub)),
          ),
      ]),
    ),
  );
}
