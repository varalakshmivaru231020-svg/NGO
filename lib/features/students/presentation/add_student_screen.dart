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
import 'package:saksham_app/core/ui/ui.dart';

// ── colours ───────────────────────────────────────────────────────────
const _brand600 = Color(0xFFFF9933);
const _brand100 = Color(0xFFFFE8CC);
const _amber600 = Color(0xFFE0921A);
const _danger = Color(0xFFE5484D);

// ══════════════════════════════════════════════════════════════════════
// STUDENT DOCUMENTS — shared by Add Child (held until the child is saved)
// and the child's Documents tab (uploaded straight away). Any number of
// documents, each with a free-text name.
// ══════════════════════════════════════════════════════════════════════

// Fallback quick picks, used until the shared list (Settings → Document
// Types, GET /students/lookups/DOCUMENT_TYPE) has loaded.
const kStudentDocSuggestions = [
  'Aadhaar Card', 'Birth Certificate', 'Transfer Certificate', 'Medical Report',
  'Report Card', 'Family Photo', "Parents' Aadhaar",
];

// Files above this size still go through, but the user is warned first.
const kStudentDocWarnBytes = 10 * 1024 * 1024;

typedef PickedStudentDoc = ({String name, String fileName, Uint8List bytes});

String studentDocMime(String fileName) {
  final ext = fileName.contains('.') ? fileName.split('.').last.toLowerCase() : '';
  return switch (ext) {
    'pdf' => 'application/pdf',
    'jpg' || 'jpeg' => 'image/jpeg',
    'png' => 'image/png',
    'webp' => 'image/webp',
    'gif' => 'image/gif',
    'heic' => 'image/heic',
    'doc' => 'application/msword',
    'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls' => 'application/vnd.ms-excel',
    'xlsx' => 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'txt' => 'text/plain',
    _ => 'application/octet-stream',
  };
}

IconData studentDocIcon(String fileName) {
  final m = studentDocMime(fileName);
  if (m.startsWith('image/')) return Icons.image_outlined;
  if (m == 'application/pdf') return Icons.picture_as_pdf_outlined;
  return Icons.insert_drive_file_outlined;
}

String studentDocSize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

// "+ Add document" modal: choose a file, name it, confirm. With [onUpload]
// the sheet uploads the file itself (showing "Uploading…", staying open with
// everything kept if it fails); without it the pick is simply returned.
class StudentDocumentSheet extends StatefulWidget {
  const StudentDocumentSheet({super.key, this.onUpload});
  final Future<void> Function(PickedStudentDoc doc)? onUpload;
  @override
  State<StudentDocumentSheet> createState() => _StudentDocumentSheetState();
}

class _StudentDocumentSheetState extends State<StudentDocumentSheet> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _nameFocus = FocusNode();
  String? _fileName;
  Uint8List? _bytes;
  bool _picking = false;
  bool _busy = false;
  bool _submitted = false;
  String? _serverError;

  // Shared document names; "+ New name" adds one for every user.
  List<String> _types = StudentLookups.documentTypes.isNotEmpty
      ? StudentLookups.documentTypes.map((o) => o.label).toList()
      : List.of(kStudentDocSuggestions);
  bool _addingType = false;
  bool _savingType = false;
  final _newType = TextEditingController();
  String? _newTypeError;

  @override
  void initState() {
    super.initState();
    StudentLookups.load(force: true).then((_) {
      if (!mounted || StudentLookups.documentTypes.isEmpty) return;
      setState(() => _types = StudentLookups.documentTypes.map((o) => o.label).toList());
    });
  }

  @override
  void dispose() { _name.dispose(); _nameFocus.dispose(); _newType.dispose(); super.dispose(); }

  Future<void> _saveNewType() async {
    if (_savingType) return;
    final label = _newType.text.trim();
    if (label.isEmpty) { setState(() => _newTypeError = 'Enter a name.'); return; }
    final existing = _types.where((t) => t.toLowerCase() == label.toLowerCase()).firstOrNull;
    if (existing != null) {
      // Already in the list — just pick it.
      setState(() { _name.text = existing; _addingType = false; _newType.clear(); _newTypeError = null; });
      return;
    }
    setState(() { _savingType = true; _newTypeError = null; });
    try {
      await apiClient.post('/students/document-types', {'label': label});
      await StudentLookups.load(force: true);
      if (!mounted) return;
      setState(() {
        _types = StudentLookups.documentTypes.isNotEmpty
            ? StudentLookups.documentTypes.map((o) => o.label).toList()
            : [..._types, label];
        _name.text = label;
        _addingType = false;
        _savingType = false;
        _newType.clear();
      });
      _form.currentState?.validate();
      AppToast.success(context, 'Document name added', detail: '“$label” is now available to everyone');
    } catch (e) {
      if (!mounted) return;
      setState(() { _savingType = false; _newTypeError = ApiClient.errorMessage(e, fallback: 'Could not add the name.'); });
    }
  }

  Future<void> _pick() async {
    if (_picking || _busy) return;
    setState(() => _picking = true);
    try {
      final r = await FilePicker.platform.pickFiles(allowMultiple: false, withData: true);
      final f = r?.files.single;
      if (f != null && f.bytes != null && mounted) {
        setState(() { _fileName = f.name; _bytes = f.bytes; });
      }
    } catch (e) {
      if (mounted) AppToast.error(context, 'Couldn’t open the file', detail: e.toString());
    }
    if (mounted) setState(() => _picking = false);
  }

  Future<void> _submit() async {
    if (_busy) return;
    setState(() { _submitted = true; _serverError = null; });
    final okForm = _form.currentState!.validate();
    if (!okForm || _bytes == null) return;
    final doc = (name: _name.text.trim(), fileName: _fileName!, bytes: _bytes!);
    if (widget.onUpload == null) { Navigator.of(context).pop(doc); return; }
    setState(() => _busy = true);
    try {
      await widget.onUpload!(doc);
      if (mounted) Navigator.of(context).pop(doc);
    } catch (e) {
      if (!mounted) return;
      setState(() { _busy = false; _serverError = ApiClient.errorMessage(e, fallback: 'Upload failed. Please try again.'); });
    }
  }

  Widget _label(String t, {bool required = false}) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text.rich(TextSpan(children: [
      TextSpan(text: t),
      if (required) const TextSpan(text: ' *', style: TextStyle(color: _danger)),
    ]), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: context.textSub)),
  );

  @override
  Widget build(BuildContext context) {
    final uploadMode = widget.onUpload != null;
    final big = (_bytes?.length ?? 0) > kStudentDocWarnBytes;
    return Padding(
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
                const Text('Add document', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('Choose a file and give it a name.', style: TextStyle(fontSize: 12.5, color: context.textSub)),
              ])),
              IconButton(
                tooltip: 'Close',
                icon: Icon(Icons.close_rounded, size: 20, color: context.textSub),
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
              ),
            ]),
            const SizedBox(height: 14),
            _label('File', required: true),
            // File row: empty state is a compact drop-zone style button.
            InkWell(
              onTap: _busy ? null : _pick,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                constraints: const BoxConstraints(minHeight: 48),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: context.surface2,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _submitted && _bytes == null ? _danger : context.border),
                ),
                child: Row(children: [
                  if (_picking) const AppSpinner(size: 16)
                  else Icon(_fileName == null ? Icons.upload_file_outlined : studentDocIcon(_fileName!),
                      size: 18, color: _fileName == null ? context.textHint : _brand600),
                  const SizedBox(width: 10),
                  Expanded(child: _fileName == null
                    ? Text('Choose a file (PDF, image, document)', style: TextStyle(fontSize: 13.5, color: context.textHint))
                    : Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Text(_fileName!, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: context.textPrimary)),
                        Text(studentDocSize(_bytes!.length), style: TextStyle(fontSize: 11.5, color: context.textHint)),
                      ])),
                  Text(_fileName == null ? 'Browse' : 'Change',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: _brand600)),
                ]),
              ),
            ),
            if (_submitted && _bytes == null)
              const Padding(padding: EdgeInsets.only(top: 5, left: 2),
                child: Text('Please choose a file.', style: TextStyle(fontSize: 12, color: Color(0xFFD13438)))),
            if (big)
              Padding(padding: const EdgeInsets.only(top: 6, left: 2), child: Row(children: [
                const Icon(Icons.warning_amber_rounded, size: 14, color: _amber600),
                const SizedBox(width: 5),
                Expanded(child: Text('Large file (${studentDocSize(_bytes!.length)}). Files over 10 MB may upload slowly or fail.',
                    style: const TextStyle(fontSize: 12, color: _amber600, fontWeight: FontWeight.w500))),
              ])),
            const SizedBox(height: 14),
            _label('Document name', required: true),
            TextFormField(
              controller: _name,
              focusNode: _nameFocus,
              enabled: !_busy,
              textCapitalization: TextCapitalization.words,
              onFieldSubmitted: (_) => _submit(),
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return 'Please enter a document name.';
                if (t.length > 80) return 'Keep the name under 80 characters.';
                return null;
              },
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              decoration: const InputDecoration(hintText: 'e.g. Birth Certificate'),
            ),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
              for (final s in _types)
                _SuggestionChip(
                  label: s,
                  selected: _name.text.trim() == s,
                  onTap: _busy ? null : () {
                    setState(() => _name.text = s);
                    _form.currentState?.validate();
                  },
                ),
              if (!_addingType)
                _SuggestionChip(
                  label: '+ New name',
                  selected: false,
                  onTap: _busy ? null : () => setState(() { _addingType = true; _newTypeError = null; }),
                ),
            ]),
            // Inline "+ New name": saved to the shared list for all users.
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              child: !_addingType ? const SizedBox(width: double.infinity) : Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: TextField(
                    controller: _newType,
                    autofocus: true,
                    enabled: !_savingType,
                    textCapitalization: TextCapitalization.words,
                    onSubmitted: (_) => _saveNewType(),
                    onChanged: (_) { if (_newTypeError != null) setState(() => _newTypeError = null); },
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                    decoration: InputDecoration(
                      hintText: 'New document name, e.g. Caste Certificate',
                      errorText: _newTypeError,
                      helperText: 'Added to the list for everyone',
                    ),
                  )),
                  const SizedBox(width: 8),
                  AppButton(label: 'Add', busyLabel: 'Adding…', loading: _savingType, dense: true, onPressed: _saveNewType),
                  IconButton(
                    tooltip: 'Cancel',
                    icon: Icon(Icons.close_rounded, size: 18, color: context.textSub),
                    onPressed: _savingType ? null : () => setState(() { _addingType = false; _newType.clear(); _newTypeError = null; }),
                  ),
                ]),
              ),
            ),
            if (_serverError != null) ...[
              const SizedBox(height: 12),
              _InlineError(_serverError!),
            ],
            const SizedBox(height: 18),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              AppButton(label: 'Cancel', variant: AppButtonVariant.secondary,
                  onPressed: _busy ? null : () => Navigator.of(context).pop()),
              const SizedBox(width: 8),
              AppButton(
                label: uploadMode ? 'Upload' : 'Add document',
                icon: uploadMode ? Icons.cloud_upload_outlined : Icons.add,
                busyLabel: 'Uploading…',
                loading: _busy,
                onPressed: _submit,
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: selected ? _brand100 : context.surface2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: selected ? _brand600.withValues(alpha: 0.5) : context.border),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? _brand600 : context.textSub)),
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
  // Set on the first Enrol attempt so non-text fields (date of birth, centre)
  // show their message inline instead of a toast.
  bool _submitted = false;
  Uint8List? _photoBytes;

  // Documents picked before the student exists. They're bundled into the
  // POST /students body so they're created with the real student id (and
  // survive the approval queue verbatim).
  final List<PickedStudentDoc> _docs = [];

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
      final cList = cData is List ? cData : <dynamic>[];
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
    showAppSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
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
            height: MediaQuery.of(ctx).size.height * 0.62,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const SheetHandle(margin: EdgeInsets.only(top: 10)),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
                child: Row(children: [
                  const Expanded(child: Text('Link a donor as sponsor', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                  IconButton(tooltip: 'Close', icon: Icon(Icons.close_rounded, size: 20, color: context.textSub),
                      onPressed: () => Navigator.pop(ctx)),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: searchCtrl,
                  onChanged: (v) => setSheet(() => query = v),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: 'Search by name or mobile number',
                    prefixIcon: Icon(Icons.search, color: context.textHint, size: 18),
                    suffixIcon: query.isEmpty ? null : IconButton(
                      icon: Icon(Icons.close, color: context.textHint, size: 16),
                      onPressed: () { searchCtrl.clear(); setSheet(() => query = ''); },
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: filtered.isEmpty
                    ? Center(child: EmptyState(
                        icon: Icons.person_search_outlined,
                        title: _apiDonors.isEmpty ? 'No donors yet' : 'No donors match your search',
                        message: _apiDonors.isEmpty ? 'Add a donor first, then link them here.' : null,
                      ))
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final d = filtered[i];
                          return ListTile(
                            dense: true,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            leading: CircleAvatar(radius: 17, backgroundColor: _brand100,
                                child: Text(d.name.isNotEmpty ? d.name[0].toUpperCase() : '?',
                                    style: const TextStyle(color: _brand600, fontWeight: FontWeight.w700, fontSize: 13))),
                            title: Text(d.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                            subtitle: Text([d.city, d.phone].where((s) => s.isNotEmpty).join('  ·  '),
                                style: TextStyle(color: context.textHint, fontSize: 12)),
                            trailing: Icon(Icons.chevron_right, size: 18, color: context.textHint),
                            onTap: () {
                              setState(() { _sponsorId = d.id; _sponsorName = d.name; });
                              Navigator.pop(ctx);
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

  Future<void> _addDocument() async {
    final doc = await showAppSheet<PickedStudentDoc>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => const StudentDocumentSheet(),
    );
    if (doc == null || !mounted) return;
    setState(() => _docs.add(doc));
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _submitted = true);
    final formOk = _form.currentState!.validate();
    // The sponsorship is only created with an amount (backend requires it).
    final sponsorAmount = int.tryParse(_sponsorAmt.text.trim());
    if (!formOk || _dob.isEmpty || _centreId.isEmpty) {
      final missing = [
        if (_dob.isEmpty) 'Date of birth is required.',
        if (_centreId.isEmpty) 'Select a centre.',
      ].join(' ');
      AppToast.error(context, 'Please fix the highlighted fields', detail: missing.isEmpty ? null : missing);
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
      final genderKey = switch (_gender) { 'Female' => 'FEMALE', 'Other' => 'OTHER', _ => 'MALE' };
      final body = <String, dynamic>{
        'name':       _name.text.trim(),
        'dob':        _toIso(_dob),
        'gender':     genderKey,
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

      // Bundle the documents into this same request (rather than a separate
      // follow-up call) — so they're created together with the real new
      // student id, and survive verbatim if this whole request gets queued
      // for Super Admin approval (see CreateStudentDto.documents).
      final documents = <Map<String, dynamic>>[
        for (final d in _docs)
          {
            'category': d.name,
            'fileName': d.fileName,
            'mimeType': studentDocMime(d.fileName),
            'data': base64Encode(d.bytes),
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
          if (timedOut) {
            AppToast.warning(context, 'The server took too long to answer',
                detail: 'Check the Children list before trying again — the child may already be saved.');
          } else {
            AppToast.error(context, 'Couldn’t enrol the child', detail: ApiClient.errorMessage(e, fallback: 'Could not save the child.'));
          }
        }
        return;
      }

      // Non-Super-Admins: the backend queues this for approval instead of
      // creating it. Don't add anything locally — it must wait for approval.
      final pending = (res['meta'] as Map?)?['pendingApproval'] == true;
      if (pending) {
        if (mounted) {
          setState(() => _saving = false);
          AppToast.warning(context, 'Submitted for Super Admin approval',
              detail: documents.isNotEmpty ? 'Documents are included with the request.' : null);
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
        'gender':      genderKey,
        'dob':         _toIso(_dob),
        'status':      _status,
        'educationLevel': _eduLevel,
        'class':       _classGrade.text.trim(),
        'school':      _schoolName.text.trim(),
        'center':      {'id': _centreId, 'name': _centreName},
        'centerId':    _centreId,
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
        if (sponsorWarning == null) {
          AppToast.success(context, 'Child enrolled', detail: _name.text.trim());
        } else {
          AppToast.warning(context, 'Child enrolled, but the sponsor wasn’t linked', detail: sponsorWarning);
        }
        ProviderScope.containerOf(context).read(dashboardRefreshProvider.notifier).state++;
        context.go('/students/$studentId');
      }
    } catch (e) {
      // Anything unexpected must still end the spinner and say what happened.
      if (mounted) {
        setState(() => _saving = false);
        AppToast.error(context, 'Couldn’t enrol the child', detail: ApiClient.errorMessage(e, fallback: 'Could not save the child.'));
      }
    }
  }

  // Two short fields side by side on wider screens, stacked on phones.
  Widget _pair(Widget a, Widget b) => LayoutBuilder(builder: (_, c) {
    if (c.maxWidth < 420) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [a, const SizedBox(height: 12), b]);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: a), const SizedBox(width: 12), Expanded(child: b),
    ]);
  });

  Widget _field(String label, TextEditingController ctrl, {String hint = '', bool required = false, TextInputType? keyboardType,
      int maxLines = 1, List<TextInputFormatter>? inputFormatters, String? Function(String?)? validator,
      TextCapitalization cap = TextCapitalization.words}) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _FieldLabel(label, required: required),
      _textField(context, ctrl, hint: hint, keyboardType: keyboardType, maxLines: maxLines,
          inputFormatters: inputFormatters, validator: validator, textCapitalization: cap, enabled: !_saving),
    ]);

  Widget _optionChips({required List<({String key, String label})> options, required String? value,
      required ValueChanged<String?> onChanged, bool allowClear = true}) =>
    Wrap(spacing: 6, runSpacing: 6, children: options.map((o) {
      final active = value == o.key;
      return InkWell(
        borderRadius: BorderRadius.circular(8),
        // Tapping the selected chip clears it — these stay optional.
        onTap: () => onChanged(active && allowClear ? null : o.key),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: active ? _brand100 : context.surface2,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: active ? _brand600.withValues(alpha: 0.6) : context.border),
          ),
          child: Text(o.label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600,
            color: active ? _brand600 : context.textSub)),
        ),
      );
    }).toList());

  Widget _documentsSection() => _SectionCard(
    title: 'Documents',
    trailing: AppButton(label: 'Add document', icon: Icons.add, dense: true, variant: AppButtonVariant.secondary,
        onPressed: _saving ? null : _addDocument),
    children: [
      if (_docs.isEmpty)
        InkWell(
          onTap: _saving ? null : _addDocument,
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
            decoration: BoxDecoration(color: context.surface2, borderRadius: BorderRadius.circular(10),
                border: Border.all(color: context.border)),
            child: Column(children: [
              Icon(Icons.upload_file_outlined, size: 22, color: context.textHint),
              const SizedBox(height: 6),
              Text('No documents added', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.textSub)),
              const SizedBox(height: 2),
              Text('Aadhaar, birth certificate, TC, medical reports, family photo…',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: context.textHint)),
            ]),
          ),
        )
      else
        Container(
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: context.border)),
          clipBehavior: Clip.antiAlias,
          child: Column(children: [
            for (var i = 0; i < _docs.length; i++) _pendingDocRow(i),
          ]),
        ),
      if (_docs.isNotEmpty) ...[
        const SizedBox(height: 6),
        Text('Uploaded together with the child when you enrol.',
            style: TextStyle(fontSize: 11.5, color: context.textHint)),
      ],
    ],
  );

  Widget _pendingDocRow(int i) {
    final d = _docs[i];
    final big = d.bytes.length > kStudentDocWarnBytes;
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(border: i == _docs.length - 1 ? null : Border(bottom: BorderSide(color: context.border))),
      child: Row(children: [
        Container(width: 32, height: 32,
          decoration: BoxDecoration(color: _brand100, borderRadius: BorderRadius.circular(8)),
          child: Icon(studentDocIcon(d.fileName), size: 16, color: _brand600)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(d.name, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: context.textPrimary)),
          const SizedBox(height: 2),
          Text('${d.fileName}  ·  ${studentDocSize(d.bytes.length)}', maxLines: 1, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, color: big ? _amber600 : context.textHint)),
        ])),
        IconButton(
          tooltip: 'View',
          visualDensity: VisualDensity.compact,
          icon: Icon(Icons.visibility_outlined, size: 18, color: context.textSub),
          onPressed: () => openBytesInBrowser(d.bytes, d.fileName),
        ),
        IconButton(
          tooltip: 'Remove',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.close_rounded, size: 18, color: _danger),
          onPressed: _saving ? null : () => setState(() => _docs.removeAt(i)),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final wide = MediaQuery.sizeOf(context).width >= 700;
    final dobMissing = _submitted && _dob.isEmpty;
    return Scaffold(
      body: Column(children: [
        // ── Compact header: back, title, primary action ───────────
        Container(
          padding: EdgeInsets.fromLTRB(8, top + 10, 16, 10),
          decoration: BoxDecoration(color: context.headerBg, border: Border(bottom: BorderSide(color: context.border))),
          child: Row(children: [
            IconButton(
              tooltip: 'Back to Children',
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
              onPressed: _saving ? null : () => context.go('/students'),
            ),
            const SizedBox(width: 2),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              const Text('Add Child', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.2)),
              Text('Child ID is generated automatically', style: TextStyle(fontSize: 12.5, color: context.textSub, fontWeight: FontWeight.w500)),
            ])),
            if (wide) ...[
              AppButton(label: 'Cancel', variant: AppButtonVariant.secondary,
                  onPressed: _saving ? null : () => context.go('/students')),
              const SizedBox(width: 8),
            ],
            AppButton(label: 'Enrol Child', icon: Icons.check_rounded, busyLabel: 'Saving…', loading: _saving, onPressed: _save),
          ]),
        ),

        // ── form ───────────────────────────────────────────────────
        Expanded(
          child: Form(
            key: _form,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 880),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // ── Basic Profile ────────────────────────────────────
                _SectionCard(title: 'Basic Profile', children: [
                  Center(child: PhotoPickerCircle(
                    label: 'Child Photo', size: 76,
                    onImageChanged: (b) => setState(() => _photoBytes = b),
                  )),
                  const SizedBox(height: 12),
                  const _FieldLabel('Centre', required: true),
                  if (_loadingForm)
                    const Padding(padding: EdgeInsets.symmetric(vertical: 4), child: Skeleton(height: 40, radius: 10))
                  else if (_centres.isEmpty)
                    Row(children: [
                      Expanded(child: Text('No centres yet — add one first.',
                          style: TextStyle(color: _submitted ? const Color(0xFFD13438) : context.textHint, fontSize: 13))),
                      AppButton(
                        label: 'Add Centre', icon: Icons.add, dense: true, variant: AppButtonVariant.secondary,
                        onPressed: () async {
                          await context.push('/centres');
                          if (mounted) _loadFormData();
                        },
                      ),
                    ])
                  else
                    _SegmentedToggle(
                      options: _centres.map((c) => c.name).toList(),
                      value: _centreName,
                      onChanged: (v) => setState(() {
                        _centreName = v;
                        _centreId = _centres.firstWhere((c) => c.name == v, orElse: () => _centres.first).id;
                      }),
                    ),
                  const SizedBox(height: 12),
                  _field('Full Name', _name, hint: "Child's full name", required: true,
                    validator: (v) => (v ?? '').trim().isEmpty ? 'Please enter the child’s name.' : null),
                  const SizedBox(height: 12),
                  _pair(
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const _FieldLabel('Date of Birth', required: true),
                      _DateTapField(value: _dob, hint: 'DD / MM / YYYY', error: dobMissing,
                          onTap: _saving ? null : () => _pickDate((v) => setState(() => _dob = v))),
                      if (dobMissing)
                        const Padding(padding: EdgeInsets.only(top: 5, left: 2),
                          child: Text('Please select the date of birth.', style: TextStyle(fontSize: 12, color: Color(0xFFD13438)))),
                    ]),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const _FieldLabel('Date of Admission'),
                      _DateTapField(value: _admDate, hint: 'DD / MM / YYYY',
                          onTap: _saving ? null : () => _pickDate((v) => setState(() => _admDate = v))),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  const _FieldLabel('Gender'),
                  _SegmentedToggle(options: const ['Male', 'Female', 'Other'], value: _gender, onChanged: (v) => setState(() => _gender = v)),
                  const SizedBox(height: 12),
                  _field('Aadhaar Number', _aadhaar, hint: '12-digit number', keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(12)],
                    validator: (v) => (v ?? '').isNotEmpty && v!.length != 12 ? 'Aadhaar number must be 12 digits.' : null),
                  const SizedBox(height: 12),
                  const _FieldLabel('Current Status'),
                  _StatusChips(value: _status, onChanged: (v) => setState(() => _status = v)),
                  if (_categories.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const _FieldLabel('Support Category (optional)'),
                    _optionChips(
                      options: [for (final c in _categories) (key: c.id, label: c.label)],
                      value: _categoryId,
                      onChanged: (v) => setState(() => _categoryId = v),
                    ),
                  ],
                ]),
                const SizedBox(height: 14),

                // ── Family Details ───────────────────────────────────
                _SectionCard(title: 'Family Details', children: [
                  _pair(_field("Father's Name", _fatherName, hint: "Father's name"),
                        _field("Mother's Name", _motherName, hint: "Mother's name")),
                  const SizedBox(height: 12),
                  _pair(_field('Guardian', _guardian, hint: 'Guardian name'),
                        _field('Relationship', _relation, hint: 'e.g. Mother')),
                  const SizedBox(height: 12),
                  const _FieldLabel('Mobile Number', required: true),
                  PhoneFieldWithCode(ctrl: _mobile, required: true),
                  const SizedBox(height: 12),
                  _field('Address', _address, hint: 'Residential address', maxLines: 2),
                  const SizedBox(height: 12),
                  _pair(_field('SAT Number', _satNo, hint: 'SAT-0000'),
                        _field('Sibling Name(s)', _siblingNames, hint: 'If any, comma-separated')),
                  const SizedBox(height: 12),
                  _field('Family Background Notes', _familyNotes, hint: 'Context about the family…', maxLines: 3,
                      cap: TextCapitalization.sentences),
                ]),
                const SizedBox(height: 14),

                // ── Identity & Government IDs ────────────────────────
                _SectionCard(title: 'Identity & Government IDs', children: [
                  _pair(_field('PEN Number', _penNo, hint: 'Permanent Enrolment Number'),
                        _field('CWC Number', _cwcNo, hint: 'Child Welfare Committee number')),
                  const SizedBox(height: 12),
                  _pair(_field('ABHA Card Number', _abhaNo, hint: 'Ayushman Bharat Health Account'),
                        _field('Ration Card Number', _rationCardNo, hint: 'Ration card number')),
                  const SizedBox(height: 12),
                  _field('Mission Vatsalya Number', _missionVatsalyaNo, hint: 'Mission Vatsalya scheme number'),
                  const SizedBox(height: 12),
                  _pair(_field('Caste', _caste, hint: 'Caste'), _field('Sub-caste', _subCaste, hint: 'Sub-caste')),
                ]),
                const SizedBox(height: 14),

                // ── Financial & Welfare Details ──────────────────────
                _SectionCard(title: 'Financial & Welfare Details', children: [
                  _field('Bank Account Details', _bankDetails, hint: 'Account no., IFSC, bank name', maxLines: 2,
                      cap: TextCapitalization.none),
                  const SizedBox(height: 12),
                  _pair(
                    _field('Income Certificate Amount', _incomeCertAmt, hint: '₹ amount', keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
                    _field('Income Cert. RD Number', _incomeCertRdNo, hint: 'RD number'),
                  ),
                ]),
                const SizedBox(height: 14),

                // ── Educational Details ──────────────────────────────
                _SectionCard(title: 'Educational Details', children: [
                  const _FieldLabel('Education Level (optional)'),
                  if (StudentLookups.educationLevels.isEmpty)
                    Text('No education levels yet. Add them in Settings → Education Levels.',
                        style: TextStyle(fontSize: 12.5, color: context.textHint, fontWeight: FontWeight.w500))
                  else
                    _optionChips(
                      options: [for (final o in StudentLookups.educationLevels) (key: o.key, label: o.label)],
                      value: _eduLevel,
                      onChanged: (v) => setState(() => _eduLevel = v),
                    ),
                  const SizedBox(height: 12),
                  _field('School / College Name', _schoolName, hint: 'Institution name'),
                  const SizedBox(height: 12),
                  _pair(_field('Class / Grade', _classGrade, hint: 'e.g. Class 6'),
                        _field('Admission No.', _admissionNo, hint: 'Number')),
                  const SizedBox(height: 12),
                  _pair(_field('Academic Year', _acadYear, hint: '2025-26'),
                        _field('Performance', _performance, hint: 'e.g. Above Average')),
                  const SizedBox(height: 12),
                  _field('Institution Address', _schoolAddr, hint: 'School / college address', maxLines: 2),
                ]),
                const SizedBox(height: 14),

                // ── Health & Medical ─────────────────────────────────
                _SectionCard(title: 'Health & Medical', children: [
                  _pair(
                    _field('Height (cm)', _height, hint: 'e.g. 132', keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) => (v ?? '').trim().isNotEmpty && double.tryParse(v!.trim()) == null ? 'Enter a number.' : null),
                    _field('Weight (kg)', _weight, hint: 'e.g. 28', keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) => (v ?? '').trim().isNotEmpty && double.tryParse(v!.trim()) == null ? 'Enter a number.' : null),
                  ),
                  Padding(padding: const EdgeInsets.only(top: 6), child: Text(
                    'Saved as the first dated entry in Growth History (see the Progress tab).',
                    style: TextStyle(fontSize: 11.5, color: context.textHint, fontWeight: FontWeight.w500))),
                  const SizedBox(height: 12),
                  _field('Medical History', _medHistory, hint: 'Allergies, conditions, notes…', maxLines: 3,
                      cap: TextCapitalization.sentences),
                ]),
                const SizedBox(height: 14),

                // ── Sponsorship ──────────────────────────────────────
                _SectionCard(title: 'Sponsorship', children: [
                  Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Sponsored child?', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: context.textPrimary)),
                      const SizedBox(height: 2),
                      Text('Link a donor as sponsor', style: TextStyle(fontSize: 12, color: context.textHint)),
                    ])),
                    Transform.scale(scale: 0.8, child: Switch(
                      value: _sponsored,
                      onChanged: (v) { setState(() { _sponsored = v; if (!v) { _sponsorId = null; _sponsorName = null; } }); if (v) _showSponsorPicker(); },
                    )),
                  ]),
                  if (_sponsored && _sponsorName != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                      decoration: BoxDecoration(color: _brand100.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(10)),
                      child: Row(children: [
                        CircleAvatar(radius: 16, backgroundColor: _brand600,
                            child: Text(_sponsorName!.isNotEmpty ? _sponsorName![0] : '?',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13))),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(_sponsorName!, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
                          Text('Sponsor ID · $_sponsorId', maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11.5, color: context.textSub)),
                        ])),
                        AppButton(label: 'Change', variant: AppButtonVariant.ghost, dense: true, onPressed: _showSponsorPicker),
                      ]),
                    ),
                    const SizedBox(height: 12),
                    _field('Annual Sponsorship Amount (₹)', _sponsorAmt, hint: 'e.g. 24000', keyboardType: TextInputType.number,
                      required: true,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (v) => (int.tryParse((v ?? '').trim()) ?? 0) < 1 ? 'Enter the annual sponsorship amount.' : null),
                  ] else if (_sponsored) ...[
                    const SizedBox(height: 10),
                    AppButton(label: 'Link a donor as sponsor', icon: Icons.link, variant: AppButtonVariant.secondary,
                        onPressed: _showSponsorPicker),
                  ],
                ]),
                const SizedBox(height: 14),

                // ── Documents (any number, custom names) ────────────
                _documentsSection(),
                const SizedBox(height: 18),

                // ── Actions ─────────────────────────────────────────
                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  AppButton(label: 'Cancel', variant: AppButtonVariant.secondary,
                      onPressed: _saving ? null : () => context.go('/students')),
                  const SizedBox(width: 8),
                  AppButton(label: 'Enrol Child', icon: Icons.check_rounded, busyLabel: 'Saving…', loading: _saving, onPressed: _save),
                ]),
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
  const _SectionCard({required this.title, required this.children, this.trailing});
  final String title;
  final List<Widget> children;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: context.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: EdgeInsets.fromLTRB(16, trailing == null ? 12 : 8, trailing == null ? 16 : 10, trailing == null ? 12 : 8),
        child: Row(children: [
          Expanded(child: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.textPrimary))),
          if (trailing != null) trailing!,
        ]),
      ),
      Divider(height: 1, color: context.border),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      ),
    ]),
  );
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text, {this.required = false});
  final String text;
  final bool required;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text.rich(TextSpan(children: [
      TextSpan(text: text),
      if (required) const TextSpan(text: ' *', style: TextStyle(color: _danger)),
    ]), style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: context.textSub)),
  );
}

Widget _textField(BuildContext ctx, TextEditingController ctrl, {String hint='', TextInputType? keyboardType, int maxLines=1,
  TextCapitalization textCapitalization = TextCapitalization.words, List<TextInputFormatter>? inputFormatters,
  String? Function(String?)? validator, bool enabled = true}) =>
  TextFormField(
    controller: ctrl, keyboardType: maxLines > 1 ? TextInputType.multiline : keyboardType, enabled: enabled,
    textCapitalization: textCapitalization, maxLines: maxLines, inputFormatters: inputFormatters, validator: validator,
    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: ctx.textPrimary),
    decoration: InputDecoration(hintText: hint),
  );

class _DateTapField extends StatelessWidget {
  const _DateTapField({required this.value, required this.hint, required this.onTap, this.error = false});
  final String value, hint;
  final VoidCallback? onTap;
  final bool error;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Container(
      height: 42, padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Theme.of(context).inputDecorationTheme.fillColor ?? context.cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: error ? _danger : context.border),
      ),
      child: Row(children: [
        Expanded(child: Text(value.isEmpty ? hint : value,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: value.isEmpty ? context.textHint : context.textPrimary))),
        Icon(Icons.calendar_today_outlined, size: 16, color: context.textHint),
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
  Widget build(BuildContext context) {
    Widget seg(String o) {
      final active = value == o;
      return InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => onChanged(o),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 32,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: active ? _brand600 : Colors.transparent, borderRadius: BorderRadius.circular(8)),
          child: Text(o, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: active ? Colors.white : context.textSub)),
        ),
      );
    }
    return LayoutBuilder(builder: (_, c) {
      // Many centres don't fit in one row — scroll instead of squashing.
      final fits = options.length * 96.0 <= c.maxWidth;
      return Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(color: context.surface2, borderRadius: BorderRadius.circular(10), border: Border.all(color: context.border)),
        child: fits
          ? Row(children: [for (final o in options) Expanded(child: seg(o))])
          : SizedBox(height: 32, child: ListView(scrollDirection: Axis.horizontal, children: [for (final o in options) seg(o)])),
      );
    });
  }
}

class _StatusChips extends StatelessWidget {
  const _StatusChips({required this.value, required this.onChanged});
  final String value; // status key
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 6, runSpacing: 6, children: StudentLookups.statuses.map((o) {
      final active = value == o.key;
      final c = StudentLookups.statusColor(o.key);
      return InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => onChanged(o.key),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: active ? c.withValues(alpha: 0.12) : context.surface2,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: active ? c : context.border),
          ),
          child: Text(o.label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: active ? c : context.textSub)),
        ),
      );
    }).toList());
  }
}
