import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import '../../../core/utils/open_bytes.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/phone_field_with_code.dart';
import '../../../core/widgets/photo_picker_widget.dart';
import '../../donors/presentation/donors_screen.dart' show demoLocalDonors, mockDonorData;
import 'students_screen.dart' show demoLocalStudents, demoCentres;

// ── colours ───────────────────────────────────────────────────────────
const _brand600 = Color(0xFF0E8C76);
const _brand100 = Color(0xFFD6F3EC);
const _violet500 = Color(0xFF7C6CF0);
const _violet100 = Color(0xFFE7E3FD);
const _amber600 = Color(0xFFE0921A);
const _amber100 = Color(0xFFFFF1D6);
const _coral500 = Color(0xFFF2685E);
const _coral100 = Color(0xFFFFE3DF);
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

  // pickers
  String _dob         = '';
  String _admDate     = '';

  // toggles
  String _centreName  = '';
  String _centreId    = '';
  String _gender      = 'Male';
  String _status      = 'Active';
  String _eduType     = 'School';
  bool   _sponsored   = false;
  String? _sponsorId;
  String? _sponsorName;

  bool _saving = false;
  Uint8List? _photoBytes;

  // loaded from API
  List<({String id, String name})> _centres = [];
  List<({String id, String name, String city, String phone})> _apiDonors = [];
  bool _loadingForm = true;

  @override
  void initState() {
    super.initState();
    _loadFormData();
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

  Future<void> _loadFormData() async {
    try {
      final results = await Future.wait([
        apiClient.get('/students/centers'),
        apiClient.get('/donors', params: {'limit': '100', 'page': '1'}),
      ]);

      final cRaw  = results[0];
      final cData = cRaw['data'];
      final cList = cData is List ? cData as List<dynamic> : <dynamic>[];
      final centres = cList.map<({String id, String name})>((c) {
        final m = c as Map<String, dynamic>;
        return (id: m['id'] as String, name: m['name'] as String);
      }).toList();

      final dRes  = results[1];
      final dData = dRes['data'];
      final dList = dData is List ? dData as List<dynamic> : <dynamic>[];
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
      _acadYear,_performance,_schoolAddr,_height,_weight,_medHistory]) { c.dispose(); }
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
    setState(() => _saving = true);
    try {
      final statusMap = {'Active': 'ACTIVE', 'Graduated': 'GRADUATED', 'Relieved': 'INACTIVE', 'Drop out': 'DROPPED'};
      final photoB64 = _photoBytes != null ? base64Encode(_photoBytes!) : null;
      final body = <String, dynamic>{
        'name':       _name.text.trim(),
        'dob':        _toIso(_dob),
        'gender':     _gender == 'Male' ? 'MALE' : 'FEMALE',
        'centerId':   _centreId,
        'status':     statusMap[_status] ?? 'ACTIVE',
        if (photoB64 != null) 'photo': photoB64,
        if (_classGrade.text.trim().isNotEmpty) 'class': _classGrade.text.trim(),
        if (_schoolName.text.trim().isNotEmpty) 'school': _schoolName.text.trim(),
        if (_fatherName.text.trim().isNotEmpty) 'fatherName': _fatherName.text.trim(),
        if (_motherName.text.trim().isNotEmpty) 'motherName': _motherName.text.trim(),
        if (_mobile.text.trim().isNotEmpty)     'guardianPhone': _mobile.text.trim(),
        if (_address.text.trim().isNotEmpty)    'address': _address.text.trim(),
        if (_admDate.isNotEmpty)                'admissionDate': _toIso(_admDate),
        if (_medHistory.text.trim().isNotEmpty) 'medicalNotes': _medHistory.text.trim(),
        if (_familyNotes.text.trim().isNotEmpty) 'notes': _familyNotes.text.trim(),
      };
      Map<String, dynamic>? res;
      try {
        res = await apiClient.post('/students', body);
      } catch (_) {
        // No backend reachable — fall back to a local-only record.
      }

      // Non-Super-Admins: the backend queues this for approval instead of
      // creating it. Don't add anything locally — it must wait for approval.
      final pending = res != null && (res['meta'] as Map?)?['pendingApproval'] == true;
      if (pending) {
        if (mounted) {
          setState(() => _saving = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.hourglass_top_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Flexible(child: Text('Submitted for Super Admin approval', style: TextStyle(fontWeight: FontWeight.w700))),
            ]),
            backgroundColor: _amber600, behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ));
          context.go('/students');
        }
        return;
      }

      final created = (res?['data'] as Map?)?.cast<String, dynamic>();
      final savedId = created?['id'] as String?;
      final studentId = savedId ?? 'local-${DateTime.now().microsecondsSinceEpoch}';

      // Full local record so the detail Profile tab shows everything immediately.
      demoLocalStudents.insert(0, {
        'id':          studentId,
        'childId':     'SKT-C-new',
        'name':        _name.text.trim(),
        'gender':      _gender == 'Male' ? 'MALE' : 'FEMALE',
        'dob':         _toIso(_dob),
        'status':      statusMap[_status] ?? 'ACTIVE',
        'class':       _classGrade.text.trim(),
        'school':      _schoolName.text.trim(),
        'center':      {'name': _centreName},
        'aadhaar':     _aadhaar.text.trim(),
        'admDate':     _admDate.isNotEmpty ? _toIso(_admDate) : '',
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
        if (photoB64 != null) 'photo': photoB64,
        'sponsorships': _sponsorId != null
            ? [{'donor': {'name': _sponsorName ?? ''}}]
            : <Map<String, dynamic>>[],
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Child enrolled successfully!', style: TextStyle(fontWeight: FontWeight.w700)),
          ]),
          backgroundColor: _brand600,
          behavior: SnackBarBehavior.floating,
          width: 280,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
        context.go('/students/$studentId');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
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
                  if (_centres.isEmpty)
                    const Text('Loading centres...', style: TextStyle(color: _onSurface3, fontSize: 13))
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
                  _UploadBox(label: 'Upload family photo', icon: Icons.family_restroom_outlined),
                  const SizedBox(height: 14),
                  _FieldLabel('Family Background Notes'),
                  _textField(context, _familyNotes, hint: 'Context about the family…', maxLines: 3),
                  const SizedBox(height: 14),
                  _FieldLabel("Parents' Aadhaar Photo"),
                  _UploadBox(label: "Upload parents' Aadhaar", icon: Icons.badge_outlined),
                ]),
                const SizedBox(height: 14),

                // ── Educational Details ──────────────────────────────
                _SectionCard(title: 'Educational Details', children: [
                  _FieldLabel('School or College'),
                  _SegmentedToggle(options: const ['School', 'College'], value: _eduType, onChanged: (v) => setState(() => _eduType = v)),
                  const SizedBox(height: 14),
                  _FieldLabel('${_eduType} Name'),
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
                  _textField(context, _schoolAddr, hint: '${_eduType} address', maxLines: 2),
                  const SizedBox(height: 14),
                  _FieldLabel('Educational Documents'),
                  _UploadBox(label: 'Upload report card / TC / certificates', icon: Icons.description_outlined),
                ]),
                const SizedBox(height: 14),

                // ── Health & Medical ─────────────────────────────────
                _SectionCard(title: 'Health & Medical', children: [
                  Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _FieldLabel('Height'),
                      _textField(context, _height, hint: 'e.g. 132 cm', keyboardType: TextInputType.number),
                    ])),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _FieldLabel('Weight'),
                      _textField(context, _weight, hint: 'e.g. 28 kg', keyboardType: TextInputType.number),
                    ])),
                  ]),
                  const SizedBox(height: 14),
                  _FieldLabel('Medical History'),
                  _textField(context, _medHistory, hint: 'Allergies, conditions, notes…', maxLines: 3),
                  const SizedBox(height: 14),
                  _FieldLabel('Medical Documents'),
                  _UploadBox(label: 'Upload medical reports / prescriptions', icon: Icons.medical_services_outlined),
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
                  _DocUploadRow(icon: Icons.credit_card_outlined,   label: 'Aadhaar Card'),
                  const SizedBox(height: 10),
                  _DocUploadRow(icon: Icons.article_outlined,        label: 'Birth Certificate'),
                  const SizedBox(height: 10),
                  _DocUploadRow(icon: Icons.transfer_within_a_station_outlined, label: 'Transfer Certificate'),
                  const SizedBox(height: 10),
                  _DocUploadRow(icon: Icons.medical_services_outlined, label: 'Medical Reports'),
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
                        color: _saving ? const Color(0xFF0E8C76).withValues(alpha: 0.6) : _brand600,
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
  final String value;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) {
    const statuses = ['Active', 'Graduated', 'Relieved', 'Drop out'];
    const colors = {'Active': _brand600, 'Graduated': _violet500, 'Relieved': _amber600, 'Drop out': _coral500};
    const bgs = {'Active': _brand100, 'Graduated': _violet100, 'Relieved': _amber100, 'Drop out': _coral100};
    return Wrap(spacing: 8, runSpacing: 8, children: statuses.map((s) {
      final active = value == s;
      return GestureDetector(
        onTap: () => onChanged(s),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: active ? (colors[s] ?? _brand600) : context.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: active ? (colors[s] ?? _brand600) : context.border, width: 1.5),
          ),
          child: Text(s, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: active ? Colors.white : context.textSub)),
        ),
      );
    }).toList());
  }
}

class _UploadBox extends StatefulWidget {
  const _UploadBox({required this.label, required this.icon});
  final String label;
  final IconData icon;
  @override
  State<_UploadBox> createState() => _UploadBoxState();
}

class _UploadBoxState extends State<_UploadBox> {
  final List<String> _names = [];
  bool _loading = false;

  Future<void> _pickFile() async {
    setState(() => _loading = true);
    try {
      final result = await FilePicker.platform.pickFiles(allowMultiple: false, withData: true);
      if (result != null && result.files.isNotEmpty && mounted) {
        setState(() => _names.add(result.files.single.name));
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
    if (_names.isNotEmpty) ...[
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 6, children: _names.asMap().entries.map((e) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: _brand100, borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.insert_drive_file_outlined, size: 14, color: _brand600),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(e.value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _brand600), overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 6),
          GestureDetector(onTap: () => setState(() => _names.removeAt(e.key)),
            child: const Icon(Icons.close, size: 13, color: _brand600)),
        ]),
      )).toList()),
    ],
  ]);
}

class _DocUploadRow extends StatefulWidget {
  const _DocUploadRow({required this.icon, required this.label});
  final IconData icon;
  final String label;
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
            onTap: () => setState(() { _filename = null; _bytes = null; }),
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
