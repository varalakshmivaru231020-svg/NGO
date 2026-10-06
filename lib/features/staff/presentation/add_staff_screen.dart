import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/lazy_photo.dart';
import '../../../core/widgets/phone_field_with_code.dart';
import '../../../core/widgets/photo_picker_widget.dart';
import '../staff_model.dart';
import 'package:saksham_app/core/ui/ui.dart';

// ── colours ───────────────────────────────────────────────────────────
const _brand600 = Color(0xFFFF9933);
const _brand100 = Color(0xFFFFE8CC);
const _danger = Color(0xFFE5484D);

final _panRe = RegExp(r'^[A-Z]{5}[0-9]{4}[A-Z]$');
final _ifscRe = RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$');
final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

// One editable row in the Children / Family section.
class _ChildRow {
  _ChildRow({String name = '', String relation = '', String school = '', this.dob})
      : name = TextEditingController(text: name),
        relation = TextEditingController(text: relation),
        school = TextEditingController(text: school);
  final TextEditingController name, relation, school;
  DateTime? dob;
  void dispose() { name.dispose(); relation.dispose(); school.dispose(); }
}

// ══════════════════════════════════════════════════════════════════════
// Add Staff (/staff/new) and Edit Staff (/staff/:id/edit).
// ══════════════════════════════════════════════════════════════════════
class AddStaffScreen extends StatefulWidget {
  const AddStaffScreen({super.key, this.staffId});
  final String? staffId;
  @override
  State<AddStaffScreen> createState() => _AddStaffScreenState();
}

class _AddStaffScreenState extends State<AddStaffScreen> {
  final _form = GlobalKey<FormState>();

  final _name        = TextEditingController();
  final _mobile      = TextEditingController();
  final _whatsapp    = TextEditingController();
  final _email       = TextEditingController();
  final _address     = TextEditingController();
  final _aadhaar     = TextEditingController();
  final _pan         = TextEditingController();
  final _basic       = TextEditingController();
  final _hra         = TextEditingController();
  final _allowances  = TextEditingController();
  final _bankName    = TextEditingController();
  final _accountNo   = TextEditingController();
  final _ifsc        = TextEditingController();
  final _emgName     = TextEditingController();
  final _emgPhone    = TextEditingController();
  final _notes       = TextEditingController();
  final _workTimings = TextEditingController();

  String _gender = 'MALE';
  String _employmentType = 'FULL_TIME';
  String _status = 'ACTIVE';
  String _designation = '';   // label text, picked from the Designation list
  String? _centerId;
  DateTime? _dob;
  DateTime? _joiningDate;
  bool _pf = false;
  final List<_ChildRow> _children = [];

  // Photo: only sent when it changed, so an edit never re-uploads it.
  Uint8List? _photoBytes;
  bool _photoChanged = false;

  List<({String id, String name})> _centres = [];
  bool _loading = false;      // edit mode: loading the record
  String? _loadError;
  bool _saving = false;
  bool _submitted = false;

  bool get _isEditing => widget.staffId != null;

  @override
  void initState() {
    super.initState();
    _loadCentres();
    if (_isEditing) _loadStaff();
    StaffLookups.load(force: true).then((_) { if (mounted) setState(() {}); });
    // Live gross total.
    for (final c in [_basic, _hra, _allowances]) {
      c.addListener(() { if (mounted) setState(() {}); });
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _mobile, _whatsapp, _email, _address, _aadhaar, _pan, _basic, _hra,
      _allowances, _bankName, _accountNo, _ifsc, _emgName, _emgPhone, _notes, _workTimings]) { c.dispose(); }
    for (final r in _children) { r.dispose(); }
    super.dispose();
  }

  Future<void> _loadCentres() async {
    try {
      final r = await apiClient.get('/students/centers');
      final data = r['data'];
      final list = [
        for (final c in (data is List ? data : const []))
          if (c is Map && c['id'] != null) (id: '${c['id']}', name: '${c['name'] ?? ''}'),
      ];
      if (mounted) setState(() => _centres = list);
    } catch (_) {/* centre picker just stays empty */}
  }

  Future<void> _loadStaff() async {
    setState(() { _loading = true; _loadError = null; });
    try {
      final r = await apiClient.get('/staff/${widget.staffId}');
      final s = StaffMember.fromJson((r['data'] as Map).cast<String, dynamic>());
      if (!mounted) return;
      setState(() {
        _name.text = s.name;
        _mobile.text = s.mobile;
        _whatsapp.text = s.whatsapp;
        _email.text = s.email;
        _address.text = s.address;
        _aadhaar.text = s.aadhaarNumber;
        _pan.text = s.panNumber;
        _designation = s.designation;
        _workTimings.text = s.workTimings;
        _basic.text = s.basicSalary > 0 ? '${s.basicSalary}' : '';
        _hra.text = s.hra > 0 ? '${s.hra}' : '';
        _allowances.text = s.allowances > 0 ? '${s.allowances}' : '';
        _bankName.text = s.bankName;
        _accountNo.text = s.accountNumber;
        _ifsc.text = s.ifscCode;
        _emgName.text = s.emergencyContactName;
        _emgPhone.text = s.emergencyContactPhone;
        _notes.text = s.notes;
        _gender = s.gender;
        _employmentType = s.employmentType;
        _status = s.status;
        _centerId = s.centerId.isEmpty ? null : s.centerId;
        _dob = s.dob;
        _joiningDate = s.joiningDate;
        _pf = s.pfApplicable;
        _photoBytes = s.photoBytes;
        for (final c in s.children) {
          _children.add(_ChildRow(name: c.name, relation: c.relation, school: c.school, dob: c.dob));
        }
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _loading = false; _loadError = ApiClient.errorMessage(e, fallback: 'Could not load the staff member.'); });
    }
  }

  Future<void> _pickDate({required DateTime? current, required DateTime fallback, required ValueChanged<DateTime> onPicked}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? fallback,
      firstDate: DateTime(1940),
      lastDate: DateTime.now().add(const Duration(days: 366)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: _brand600)),
        child: child!,
      ),
    );
    if (picked != null) setState(() => onPicked(picked));
  }

  int _amount(TextEditingController c) => int.tryParse(c.text.trim()) ?? 0;
  int get _gross => _amount(_basic) + _amount(_hra) + _amount(_allowances);

  // Empty text → null, so clearing a field on edit clears it on the server.
  String? _t(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _submitted = true);
    final childNamesOk = _children.every((r) => r.name.text.trim().isNotEmpty);
    if (!_form.currentState!.validate() || !childNamesOk) {
      AppToast.error(context, 'Please fix the highlighted fields');
      return;
    }
    setState(() => _saving = true);

    final body = <String, dynamic>{
      'name': _name.text.trim(),
      'gender': _gender,
      'dob': _dob == null ? null : staffIsoDate(_dob!),
      'mobile': _t(_mobile),
      'whatsapp': _t(_whatsapp),
      'email': _t(_email),
      'address': _t(_address),
      'aadhaarNumber': _t(_aadhaar),
      'panNumber': _t(_pan)?.toUpperCase(),
      'designation': _designation,
      'centerId': _centerId ?? '',
      'joiningDate': _joiningDate == null ? null : staffIsoDate(_joiningDate!),
      'employmentType': _employmentType,
      'status': _status,
      'workTimings': _t(_workTimings),
      'basicSalary': _amount(_basic),
      'hra': _amount(_hra),
      'allowances': _amount(_allowances),
      'pfApplicable': _pf,
      'bankName': _t(_bankName),
      'accountNumber': _t(_accountNo),
      'ifscCode': _t(_ifsc)?.toUpperCase(),
      'emergencyContactName': _t(_emgName),
      'emergencyContactPhone': _t(_emgPhone),
      'notes': _t(_notes),
      'children': [
        for (final r in _children)
          {
            'name': r.name.text.trim(),
            if (r.relation.text.trim().isNotEmpty) 'relation': r.relation.text.trim(),
            if (r.dob != null) 'dob': staffIsoDate(r.dob!),
            if (r.school.text.trim().isNotEmpty) 'school': r.school.text.trim(),
          },
      ],
      if (_photoChanged) 'photo': _photoBytes == null ? null : base64Encode(_photoBytes!),
    };
    // A new record has nothing to clear — leave empty fields out entirely.
    if (!_isEditing) body.removeWhere((_, v) => v == null);

    try {
      final res = _isEditing
          ? await apiClient.put('/staff/${widget.staffId}', body)
          : await apiClient.post('/staff', body);
      if (!mounted) return;
      if ((res['meta'] as Map?)?['pendingApproval'] == true) {
        AppToast.warning(context, 'Submitted for Super Admin approval',
            detail: 'The change will apply once it is approved.');
        context.go(_isEditing ? '/staff/${widget.staffId}' : '/staff');
        return;
      }
      final id = ((res['data'] as Map?)?['id'] as String?) ?? widget.staffId;
      if (_photoChanged && id != null) evictLazyPhoto('/staff/$id/photo');
      AppToast.success(context, _isEditing ? 'Staff details updated' : 'Staff member added', detail: _name.text.trim());
      context.go(id == null ? '/staff' : _isEditing ? '/staff/$id' : '/staff/$id?tab=salary');
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AppToast.error(context, _isEditing ? 'Couldn’t save changes' : 'Couldn’t add the staff member',
          detail: ApiClient.errorMessage(e, fallback: 'Could not save. Please try again.'));
    }
  }

  void _cancel() => context.go(_isEditing ? '/staff/${widget.staffId}' : '/staff');

  // ── "+" next to Designation / Status / Centre ──────────────────────
  Future<void> _addLookup(String type) async {
    final isStatus = type == 'STATUS';
    final added = await showAppSheet<StaffOption>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddOptionSheet<StaffOption>(
        title: isStatus ? 'Add status' : 'Add designation',
        fieldLabel: isStatus ? 'Status name' : 'Designation',
        hint: isStatus ? 'e.g. Probation, Resigned' : 'e.g. Librarian, Nurse',
        save: (label) => StaffLookups.add(type, label),
      ),
    );
    if (added == null || !mounted) return;
    setState(() { if (isStatus) { _status = added.key; } else { _designation = added.label; } });
    AppToast.success(context, '“${added.label}” added', detail: 'Now available in the list for everyone.');
  }

  Future<void> _addCentre() async {
    final added = await showAppSheet<({String id, String name})>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddOptionSheet<({String id, String name})>(
        title: 'Add centre / office',
        fieldLabel: 'Name',
        hint: 'e.g. Sulibele Office',
        save: (name) async {
          // Already on the list (any case) — just pick it.
          final existing = _centres.where((c) => c.name.toLowerCase() == name.toLowerCase()).firstOrNull;
          if (existing != null) return existing;
          final r = await apiClient.post('/students/centers', {'name': name});
          if ((r['meta'] as Map?)?['pendingApproval'] == true) {
            throw 'Sent to the Super Admin for approval. It will appear here once approved.';
          }
          final d = (r['data'] as Map?) ?? const {};
          return (id: '${d['id']}', name: '${d['name'] ?? name}');
        },
      ),
    );
    if (added == null || !mounted) return;
    setState(() {
      if (!_centres.any((c) => c.id == added.id)) _centres = [..._centres, added];
      _centerId = added.id;
    });
    AppToast.success(context, '“${added.name}” added', detail: 'Also available for students.');
  }

  // ── small building blocks ──────────────────────────────────────────
  Widget _pair(Widget a, Widget b) => LayoutBuilder(builder: (_, c) {
    if (c.maxWidth < 420) return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [a, const SizedBox(height: 12), b]);
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: a), const SizedBox(width: 12), Expanded(child: b),
    ]);
  });

  Widget _field(String label, TextEditingController ctrl, {String hint = '', bool required = false,
      TextInputType? keyboardType, int maxLines = 1, List<TextInputFormatter>? inputFormatters,
      String? Function(String?)? validator, TextCapitalization cap = TextCapitalization.words, String? prefix}) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _FieldLabel(label, required: required),
      TextFormField(
        controller: ctrl, enabled: !_saving,
        keyboardType: maxLines > 1 ? TextInputType.multiline : keyboardType,
        textCapitalization: cap, maxLines: maxLines, inputFormatters: inputFormatters, validator: validator,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: context.textPrimary),
        decoration: InputDecoration(hintText: hint, prefixText: prefix),
      ),
    ]);

  Widget _money(String label, TextEditingController ctrl) => _field(label, ctrl, hint: '0', prefix: '₹ ',
      keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(8)]);

  Widget _dateField(String label, DateTime? value, {required DateTime fallback, required ValueChanged<DateTime?> onChanged}) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _FieldLabel(label),
      _DateTapField(
        value: staffDate(value),
        onTap: _saving ? null : () => _pickDate(current: value, fallback: fallback, onPicked: onChanged),
        onClear: value == null || _saving ? null : () => setState(() => onChanged(null)),
      ),
    ]);

  Widget _chips<T>({required List<({T key, String label})> options, required T? value, required ValueChanged<T> onChanged}) =>
    Wrap(spacing: 6, runSpacing: 6, children: [
      for (final o in options)
        _Chip(label: o.label, selected: value == o.key, onTap: _saving ? null : () => setState(() => onChanged(o.key))),
    ]);

  // ── sections ───────────────────────────────────────────────────────
  Widget _childrenSection() => _SectionCard(
    title: 'Children / Family Details',
    trailing: AppButton(label: 'Add child', icon: Icons.add, dense: true, variant: AppButtonVariant.secondary,
        onPressed: _saving ? null : () => setState(() => _children.add(_ChildRow()))),
    children: [
      if (_children.isEmpty)
        Text('No children recorded.', style: TextStyle(fontSize: 13, color: context.textHint))
      else
        for (var i = 0; i < _children.length; i++) ...[
          if (i > 0) Divider(height: 24, color: context.border),
          _childEditor(i),
        ],
    ],
  );

  Widget _childEditor(int i) {
    final r = _children[i];
    final nameMissing = _submitted && r.name.text.trim().isEmpty;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: Text('Child ${i + 1}', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: context.textSub))),
        IconButton(
          tooltip: 'Remove child',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.close_rounded, size: 18, color: _danger),
          onPressed: _saving ? null : () {
            final row = _children[i];
            setState(() => _children.removeAt(i));
            // Its fields are still mounted this frame — dispose once they're gone.
            WidgetsBinding.instance.addPostFrameCallback((_) => row.dispose());
          },
        ),
      ]),
      _pair(
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _FieldLabel('Name', required: true),
          TextFormField(
            controller: r.name, enabled: !_saving, textCapitalization: TextCapitalization.words,
            onChanged: (_) { if (_submitted) setState(() {}); },
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: context.textPrimary),
            decoration: InputDecoration(hintText: "Child's name", errorText: nameMissing ? 'Enter a name or remove this row.' : null),
          ),
        ]),
        _field('Relation', r.relation, hint: 'e.g. Son, Daughter'),
      ),
      const SizedBox(height: 12),
      _pair(
        _dateField('Date of Birth', r.dob, fallback: DateTime(2015), onChanged: (d) => r.dob = d),
        _field('School / Class', r.school, hint: 'e.g. GHPS Sulibele, Class 4'),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    final wide = MediaQuery.sizeOf(context).width >= 700;
    final title = _isEditing ? 'Edit Staff' : 'Add Staff';
    final saveLabel = _isEditing ? 'Save Changes' : 'Save Staff';

    final header = Container(
      padding: EdgeInsets.fromLTRB(8, top + 10, 16, 10),
      decoration: BoxDecoration(color: context.headerBg, border: Border(bottom: BorderSide(color: context.border))),
      child: Row(children: [
        IconButton(
          tooltip: 'Back',
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: _saving ? null : _cancel,
        ),
        const SizedBox(width: 2),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.2)),
          Text(_isEditing ? 'Update profile, salary and family details' : 'Staff ID is generated automatically',
              style: TextStyle(fontSize: 12.5, color: context.textSub, fontWeight: FontWeight.w500)),
        ])),
        if (wide) ...[
          AppButton(label: 'Cancel', variant: AppButtonVariant.secondary, onPressed: _saving ? null : _cancel),
          const SizedBox(width: 8),
        ],
        AppButton(label: saveLabel, icon: Icons.check_rounded, busyLabel: 'Saving…', loading: _saving,
            onPressed: _loading || _loadError != null ? null : _save),
      ]),
    );

    if (_loading || _loadError != null) {
      return Scaffold(body: Column(children: [
        header,
        Expanded(child: Center(child: Padding(
          padding: const EdgeInsets.all(16),
          child: _loadError != null
              ? ErrorState(message: _loadError!, onRetry: _loadStaff)
              : const SizedBox(width: 600, child: SkeletonList(rows: 6, rowHeight: 56)),
        ))),
      ]));
    }

    return Scaffold(
      body: Column(children: [
        header,
        Expanded(child: Form(
          key: _form,
          autovalidateMode: _submitted ? AutovalidateMode.onUserInteraction : AutovalidateMode.disabled,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Align(alignment: Alignment.topCenter, child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 880),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // ── Basic Profile ────────────────────────────────────
                _SectionCard(title: 'Basic Profile', children: [
                  Center(child: PhotoPickerCircle(
                    label: 'Staff Photo', size: 76,
                    initialImage: _photoBytes,
                    onImageChanged: (b) => setState(() { _photoBytes = b; _photoChanged = true; }),
                  )),
                  const SizedBox(height: 12),
                  _field('Full Name', _name, hint: 'Staff member’s full name', required: true,
                      validator: (v) => (v ?? '').trim().isEmpty ? 'Please enter the name.' : null),
                  const SizedBox(height: 12),
                  _pair(
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const _FieldLabel('Gender'),
                      _chips(options: const [(key: 'MALE', label: 'Male'), (key: 'FEMALE', label: 'Female'), (key: 'OTHER', label: 'Other')],
                          value: _gender, onChanged: (v) => _gender = v),
                    ]),
                    _dateField('Date of Birth', _dob, fallback: DateTime(1990), onChanged: (d) => _dob = d),
                  ),
                  const SizedBox(height: 12),
                  _pair(
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const _FieldLabel('Mobile'),
                      PhoneFieldWithCode(ctrl: _mobile),
                    ]),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const _FieldLabel('WhatsApp'),
                      PhoneFieldWithCode(ctrl: _whatsapp, hint: 'WhatsApp number'),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  _field('Email', _email, hint: 'name@example.com', keyboardType: TextInputType.emailAddress,
                      cap: TextCapitalization.none,
                      validator: (v) => (v ?? '').trim().isNotEmpty && !_emailRe.hasMatch(v!.trim()) ? 'Enter a valid email.' : null),
                  const SizedBox(height: 12),
                  _field('Address', _address, hint: 'Residential address', maxLines: 2, cap: TextCapitalization.sentences),
                ]),
                const SizedBox(height: 14),

                // ── Identity ─────────────────────────────────────────
                _SectionCard(title: 'Identity', children: [
                  _pair(
                    _field('Aadhaar Number', _aadhaar, hint: '12-digit number', keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(12)],
                        validator: (v) => (v ?? '').isNotEmpty && v!.length != 12 ? 'Aadhaar number must be 12 digits.' : null),
                    _field('PAN Number', _pan, hint: 'ABCDE1234F', cap: TextCapitalization.characters,
                        inputFormatters: [LengthLimitingTextInputFormatter(10)],
                        validator: (v) => (v ?? '').trim().isNotEmpty && !_panRe.hasMatch(v!.trim().toUpperCase())
                            ? 'PAN looks like ABCDE1234F.' : null),
                  ),
                ]),
                const SizedBox(height: 14),

                // ── Employment ───────────────────────────────────────
                _SectionCard(title: 'Employment', children: [
                  _pair(
                    _DropdownWithAdd(
                      label: 'Role / Designation', required: true, enabled: !_saving,
                      value: _designation.isEmpty ? null : _designation,
                      // Labels are the values; a designation no longer on the list stays selectable.
                      options: [
                        for (final o in StaffLookups.designations) (key: o.label, label: o.label),
                        if (_designation.isNotEmpty && !StaffLookups.designations.any((o) => o.label == _designation))
                          (key: _designation, label: _designation),
                      ],
                      hint: 'Select designation',
                      addTooltip: 'Add a new designation',
                      onChanged: (v) => setState(() => _designation = v ?? ''),
                      onAdd: () => _addLookup('DESIGNATION'),
                      validator: (v) => (v ?? '').isEmpty ? 'Please choose a designation.' : null,
                    ),
                    _DropdownWithAdd(
                      label: 'Centre / Office', enabled: !_saving,
                      value: _centerId,
                      options: [(key: null, label: 'None'), for (final c in _centres) (key: c.id, label: c.name)],
                      hint: 'None',
                      addTooltip: 'Add a new centre / office',
                      onChanged: (v) => setState(() => _centerId = v),
                      onAdd: _addCentre,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _pair(
                    _dateField('Joining Date', _joiningDate, fallback: DateTime.now(), onChanged: (d) => _joiningDate = d),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const _FieldLabel('Employment Type'),
                      _chips(options: [for (final t in kStaffEmploymentTypes) (key: t.key, label: t.label)],
                          value: _employmentType, onChanged: (v) => _employmentType = v),
                    ]),
                  ),
                  const SizedBox(height: 12),
                  _pair(
                    _DropdownWithAdd(
                      label: 'Status', enabled: !_saving,
                      value: _status,
                      options: [
                        for (final o in StaffLookups.statuses) (key: o.key, label: o.label),
                        if (!StaffLookups.statuses.any((o) => o.key == _status)) (key: _status, label: staffStatusLabel(_status)),
                      ],
                      addTooltip: 'Add a new status',
                      onChanged: (v) => setState(() => _status = v ?? 'ACTIVE'),
                      onAdd: () => _addLookup('STATUS'),
                    ),
                    _field('Work Timings', _workTimings, hint: 'e.g. 9:00 AM - 6:00 PM', cap: TextCapitalization.characters),
                  ),
                ]),
                const SizedBox(height: 14),

                // ── Salary ───────────────────────────────────────────
                _SectionCard(title: 'Salary (per month)', children: [
                  _pair(_money('Basic Salary', _basic), _money('HRA', _hra)),
                  const SizedBox(height: 12),
                  _pair(
                    _money('Allowances', _allowances),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const _FieldLabel('Gross per month'),
                      Container(
                        height: 42, width: double.infinity,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(color: _brand100.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(10)),
                        child: Text(staffInr(_gross), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: _brand600)),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('PF applicable', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: context.textPrimary)),
                      Text('12% of basic is deducted when payroll is run', style: TextStyle(fontSize: 12, color: context.textHint)),
                    ])),
                    Switch(value: _pf, onChanged: _saving ? null : (v) => setState(() => _pf = v)),
                  ]),
                ]),
                const SizedBox(height: 14),

                // ── Bank ─────────────────────────────────────────────
                _SectionCard(title: 'Bank Details', children: [
                  _field('Bank Name', _bankName, hint: 'e.g. State Bank of India'),
                  const SizedBox(height: 12),
                  _pair(
                    _field('Account Number', _accountNo, hint: 'Account number', keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(20)]),
                    _field('IFSC Code', _ifsc, hint: 'SBIN0001234', cap: TextCapitalization.characters,
                        inputFormatters: [LengthLimitingTextInputFormatter(11)],
                        validator: (v) => (v ?? '').trim().isNotEmpty && !_ifscRe.hasMatch(v!.trim().toUpperCase())
                            ? 'IFSC looks like SBIN0001234.' : null),
                  ),
                ]),
                const SizedBox(height: 14),

                // ── Emergency contact ────────────────────────────────
                _SectionCard(title: 'Emergency Contact', children: [
                  _pair(
                    _field('Contact Name', _emgName, hint: 'Name and relation'),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const _FieldLabel('Contact Phone'),
                      PhoneFieldWithCode(ctrl: _emgPhone, hint: 'Phone number'),
                    ]),
                  ),
                ]),
                const SizedBox(height: 14),

                _childrenSection(),
                const SizedBox(height: 14),

                _SectionCard(title: 'Notes', children: [
                  _field('Notes', _notes, hint: 'Anything else to remember…', maxLines: 3, cap: TextCapitalization.sentences),
                ]),
                const SizedBox(height: 18),

                Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                  AppButton(label: 'Cancel', variant: AppButtonVariant.secondary, onPressed: _saving ? null : _cancel),
                  const SizedBox(width: 8),
                  AppButton(label: saveLabel, icon: Icons.check_rounded, busyLabel: 'Saving…', loading: _saving, onPressed: _save),
                ]),
              ]),
            )),
          ),
        )),
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

class _DateTapField extends StatelessWidget {
  const _DateTapField({required this.value, required this.onTap, this.onClear});
  final String value;
  final VoidCallback? onTap, onClear;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(10),
    child: Container(
      height: 42, padding: const EdgeInsets.only(left: 14, right: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).inputDecorationTheme.fillColor ?? context.cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: context.border),
      ),
      child: Row(children: [
        Expanded(child: Text(value.isEmpty ? 'Select date' : value,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: value.isEmpty ? context.textHint : context.textPrimary))),
        if (onClear != null)
          IconButton(tooltip: 'Clear date', visualDensity: VisualDensity.compact, onPressed: onClear,
              icon: Icon(Icons.close_rounded, size: 16, color: context.textHint))
        else
          Padding(padding: const EdgeInsets.only(right: 8), child: Icon(Icons.calendar_today_outlined, size: 16, color: context.textHint)),
      ]),
    ),
  );
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: selected ? _brand100 : context.surface2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: selected ? _brand600.withValues(alpha: 0.6) : context.border),
      ),
      child: Text(label, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600,
          color: selected ? _brand600 : context.textSub)),
    ),
  );
}

// Dropdown with a "+" button beside it that adds a new option to the list.
class _DropdownWithAdd extends StatelessWidget {
  const _DropdownWithAdd({
    required this.label, required this.value, required this.options, required this.onChanged,
    required this.addTooltip, required this.onAdd, this.required = false, this.hint = 'Select',
    this.validator, this.enabled = true,
  });
  final String label, addTooltip, hint;
  final String? value;
  final List<({String? key, String label})> options;
  final ValueChanged<String?> onChanged;
  final VoidCallback onAdd;
  final bool required, enabled;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _FieldLabel(label, required: required),
    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: DropdownButtonFormField<String?>(
        // initialValue is only read once — the key rebuilds the field when
        // "+" (or a record load) changes the selection from outside.
        key: ValueKey('$label|$value|${options.length}'),
        initialValue: options.any((o) => o.key == value) ? value : null,
        isExpanded: true,
        hint: Text(hint, style: TextStyle(fontSize: 14, color: context.textHint)),
        items: [
          for (final o in options)
            DropdownMenuItem<String?>(value: o.key, child: Text(o.label, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: context.textPrimary))),
        ],
        onChanged: enabled ? onChanged : null,
        validator: validator,
        decoration: const InputDecoration(),
      )),
      const SizedBox(width: 8),
      Tooltip(message: addTooltip, child: InkWell(
        onTap: enabled ? onAdd : null,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 46, height: 46,
          decoration: BoxDecoration(
            color: _brand100,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _brand600.withValues(alpha: 0.5)),
          ),
          child: const Icon(Icons.add_rounded, color: _brand600, size: 22),
        ),
      )),
    ]),
  ]);
}

// "+" sheet: one name field; [save] runs the request and the sheet closes
// with its result, or stays open showing why it failed.
class _AddOptionSheet<T> extends StatefulWidget {
  const _AddOptionSheet({required this.title, required this.fieldLabel, required this.hint, required this.save});
  final String title, fieldLabel, hint;
  final Future<T> Function(String label) save;
  @override
  State<_AddOptionSheet<T>> createState() => _AddOptionSheetState<T>();
}

class _AddOptionSheetState<T> extends State<_AddOptionSheet<T>> {
  final _ctrl = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    final label = _ctrl.text.trim();
    if (label.isEmpty) { setState(() => _error = 'Please enter a name.'); return; }
    setState(() { _busy = true; _error = null; });
    try {
      final result = await widget.save(label);
      if (mounted) Navigator.of(context).pop(result);
    } catch (e) {
      if (!mounted) return;
      setState(() { _busy = false; _error = e is String ? e : ApiClient.errorMessage(e, fallback: 'Could not add it. Please try again.'); });
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
    child: Container(
      decoration: BoxDecoration(color: context.cardBg, borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SheetHandle(margin: EdgeInsets.only(bottom: 10)),
        Row(children: [
          Expanded(child: Text(widget.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
          IconButton(tooltip: 'Close', icon: Icon(Icons.close_rounded, size: 20, color: context.textSub),
              onPressed: _busy ? null : () => Navigator.of(context).pop()),
        ]),
        Text('It will be saved to the list for everyone.', style: TextStyle(fontSize: 12.5, color: context.textSub)),
        const SizedBox(height: 14),
        _FieldLabel(widget.fieldLabel, required: true),
        TextField(
          controller: _ctrl,
          autofocus: true,
          enabled: !_busy,
          textCapitalization: TextCapitalization.words,
          onSubmitted: (_) => _submit(),
          onChanged: (_) { if (_error != null) setState(() => _error = null); },
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          decoration: InputDecoration(hintText: widget.hint, errorText: _error, errorMaxLines: 3),
        ),
        const SizedBox(height: 18),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          AppButton(label: 'Cancel', variant: AppButtonVariant.secondary, onPressed: _busy ? null : () => Navigator.of(context).pop()),
          const SizedBox(width: 8),
          AppButton(label: 'Add', icon: Icons.add, busyLabel: 'Adding…', loading: _busy, onPressed: _submit),
        ]),
      ]),
    ),
  );
}
