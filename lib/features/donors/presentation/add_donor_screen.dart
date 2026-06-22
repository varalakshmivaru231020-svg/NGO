import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/widgets/phone_field_with_code.dart';
import '../../../core/widgets/photo_picker_widget.dart';
import 'donors_screen.dart' show donorsProvider, demoLocalDonors, donorRefreshProvider;

// ── colours ───────────────────────────────────────────────────────────
const _brand600 = Color(0xFF0E8C76);
const _brand100 = Color(0xFFD6F3EC);
const _errorColor = Color(0xFFF2685E);

const _donorCategories = [
  'Major Donor', 'Child Sponsor', 'Corporate Donor', 'Annual Donor',
  'One-Time Donor', 'Monthly', 'General Donor',
];

const _preferredMethods = ['Call', 'WhatsApp', 'Email'];

// ══════════════════════════════════════════════════════════════════════
class AddDonorScreen extends ConsumerStatefulWidget {
  const AddDonorScreen({super.key});
  @override
  ConsumerState<AddDonorScreen> createState() => _AddDonorScreenState();
}

class _AddDonorScreenState extends ConsumerState<AddDonorScreen> {
  final _form = GlobalKey<FormState>();

  // controllers
  final _name      = TextEditingController();
  final _mobile    = TextEditingController();
  final _whatsapp  = TextEditingController();
  final _email     = TextEditingController();
  final _pan       = TextEditingController();
  final _aadhaar   = TextEditingController();
  final _street    = TextEditingController();
  final _city      = TextEditingController();
  final _state     = TextEditingController();
  final _country   = TextEditingController(text: 'India');
  final _pincode   = TextEditingController();
  final _dob       = TextEditingController();
  final _anniv     = TextEditingController();
  final _occupation = TextEditingController();
  final _org       = TextEditingController();
  final _lang      = TextEditingController();
  final _notes     = TextEditingController();

  // state
  String _gender   = 'Male';
  String? _category;
  final Set<String> _commPref = {};
  final List<String> _attachments = [];
  bool _addingFile = false;
  bool _saving = false;

  // categories loaded from API: name → id
  Map<String, String> _categoryNameToId = {};

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final res = await apiClient.get('/categories');
      final list = res['data'] as List<dynamic>? ?? [];
      final map = <String, String>{};
      for (final c in list) {
        final m = c as Map<String, dynamic>;
        map[m['name'] as String? ?? ''] = m['id'] as String? ?? '';
      }
      if (mounted) setState(() => _categoryNameToId = map);
    } catch (_) {}
  }

  @override
  void dispose() {
    for (final c in [_name,_mobile,_whatsapp,_email,_pan,_aadhaar,
      _street,_city,_state,_country,_pincode,_dob,_anniv,
      _occupation,_org,_lang,_notes]) { c.dispose(); }
    super.dispose();
  }

  Future<void> _pickDate(TextEditingController ctrl) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1990),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: _brand600),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      final d = '${picked.day.toString().padLeft(2,'0')} / ${picked.month.toString().padLeft(2,'0')} / ${picked.year}';
      ctrl.text = d;
    }
  }

  String _toIso(String ddmmyyyy) {
    final parts = ddmmyyyy.replaceAll(' ', '').split('/');
    if (parts.length != 3) return '';
    return '${parts[2]}-${parts[1].padLeft(2,'0')}-${parts[0].padLeft(2,'0')}';
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final donorNum = demoLocalDonors.length + 13;
    final newId = 'local_${_name.text.trim().hashCode.abs()}';
    final newDonor = <String, dynamic>{
      'id':     newId,
      'donorId': 'SF-D-${donorNum.toString().padLeft(4, '0')}',
      'name':   _name.text.trim(),
      'mobile': _mobile.text.trim(),
      'gender': _gender == 'Male' ? 'MALE' : 'FEMALE',
      'whatsapp':   _whatsapp.text.trim(),
      'email':      _email.text.trim(),
      'city':       _city.text.trim(),
      'state':      _state.text.trim(),
      'pincode':    _pincode.text.trim(),
      'occupation': _occupation.text.trim(),
      'company':    _org.text.trim(),
      'notes':      _notes.text.trim(),
      'address':    _street.text.trim(),
      'pan':        _pan.text.trim(),
      'aadhaar':    _aadhaar.text.trim(),
      'country':    _country.text.trim(),
      'tier':       'SILVER',
      '_count':     {'donations': 0},
      if (_dob.text.trim().isNotEmpty)   'dob':         _toIso(_dob.text.trim()),
      if (_anniv.text.trim().isNotEmpty) 'anniversary': _toIso(_anniv.text.trim()),
      'categories': _category != null
          ? [{'category': {'name': _category!, 'color': '#0E8C76'}}]
          : <dynamic>[],
    };
    // Persist locally (survives navigation, cleared on restart)
    demoLocalDonors.insert(0, newDonor);

    try {
      await apiClient.post('/donors', {
        ...newDonor,
        if (_category != null && _categoryNameToId.containsKey(_category))
          'categoryIds': [_categoryNameToId[_category]!],
      });
    } catch (_) {
      // No backend in demo mode — local store is source of truth
    }
    if (mounted) {
      // Increment refresh counter → donorsProvider re-runs and picks up new donor
      ref.read(donorRefreshProvider.notifier).state++;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Row(children: [
          Icon(Icons.check_circle_outline, color: Colors.white),
          SizedBox(width: 10),
          Text('Donor saved successfully!', style: TextStyle(fontWeight: FontWeight.w700)),
        ]),
        backgroundColor: _brand600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      context.go('/donors');
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      body: Column(children: [
        // ── header ─────────────────────────────────────────────────
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF0B6E5D), _brand600], begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
          padding: EdgeInsets.fromLTRB(8, top + 8, 18, 20),
          child: Column(children: [
            Row(children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Colors.white),
                onPressed: () => context.go('/donors'),
              ),
              const Expanded(child: Text('Add Donor', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: Colors.white))),
            ]),
            const SizedBox(height: 14),
            const PhotoPickerCircle(label: 'Profile Photo', size: 96),
            const SizedBox(height: 16),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
              ),
              child: Row(children: [
                Icon(Icons.badge_outlined, size: 18, color: Colors.white.withValues(alpha: 0.9)),
                const SizedBox(width: 9),
                Text('Donor ID  ·  ', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.8))),
                const Text('SF-D-0009', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Colors.white)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8)),
                  child: Text('auto', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white.withValues(alpha: 0.8))),
                ),
              ]),
            ),
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
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // Basic Information
                _SectionCard(title: 'Basic Information', children: [
                  _FieldLabel('Full Name'),
                  _textField(context, _name, hint: 'e.g. Rajesh Khanna', validator: (v) => v!.isEmpty ? 'Required' : null),
                  const SizedBox(height: 14),
                  _FieldLabel('Gender'),
                  _GenderToggle(value: _gender, onChanged: (v) => setState(() => _gender = v)),
                  const SizedBox(height: 14),
                  _FieldLabel('Mobile'),
                  PhoneFieldWithCode(ctrl: _mobile, required: true),
                  const SizedBox(height: 14),
                  _FieldLabel('WhatsApp'),
                  PhoneFieldWithCode(ctrl: _whatsapp),
                  const SizedBox(height: 14),
                  _FieldLabel('Email'),
                  _textField(context, _email, hint: 'name@email.com', keyboardType: TextInputType.emailAddress),
                ]),
                const SizedBox(height: 14),

                // Categorization
                _SectionCard(title: 'Categorization', children: [
                  _FieldLabel('Donor Category'),
                  _CategoryDropdown(value: _category, onChanged: (v) => setState(() => _category = v)),
                ]),
                const SizedBox(height: 14),

                // Identity
                _SectionCard(title: 'Identity', children: [
                  _FieldLabel('PAN Number'),
                  _textField(context, _pan, hint: 'ABCDE1234F',
                    inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')), LengthLimitingTextInputFormatter(10)],
                    textCapitalization: TextCapitalization.characters,
                  ),
                  const SizedBox(height: 14),
                  _FieldLabel('Aadhaar (optional)'),
                  _textField(context, _aadhaar, hint: '0000 0000 0000', keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(12)]),
                ]),
                const SizedBox(height: 14),

                // Address
                _SectionCard(title: 'Address', children: [
                  _FieldLabel('Street Address'),
                  _textField(context, _street, hint: 'House / Street / Area', maxLines: 2),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _FieldLabel('City'),
                      _textField(context, _city, hint: 'City'),
                    ])),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _FieldLabel('State'),
                      _textField(context, _state, hint: 'State'),
                    ])),
                  ]),
                  const SizedBox(height: 14),
                  Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _FieldLabel('Country'),
                      _textField(context, _country, hint: 'Country'),
                    ])),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      _FieldLabel('Pincode'),
                      _textField(context, _pincode, hint: '000000', keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)]),
                    ])),
                  ]),
                ]),
                const SizedBox(height: 14),

                // Personal & Professional
                _SectionCard(title: 'Personal & Professional', children: [
                  _FieldLabel('Date of Birth'),
                  _DateField(ctrl: _dob, hint: 'DD / MM / YYYY', onTap: () => _pickDate(_dob)),
                  const SizedBox(height: 14),
                  _FieldLabel('Anniversary'),
                  _DateField(ctrl: _anniv, hint: 'DD / MM / YYYY', onTap: () => _pickDate(_anniv)),
                  const SizedBox(height: 14),
                  _FieldLabel('Occupation / Designation'),
                  _textField(context, _occupation, hint: 'e.g. Business Owner'),
                  const SizedBox(height: 14),
                  _FieldLabel('Organisation Name'),
                  _textField(context, _org, hint: 'Company / Trust / Employer'),
                ]),
                const SizedBox(height: 14),

                // Communication Preferences
                _SectionCard(title: 'Communication Preferences', children: [
                  _FieldLabel('Preferred Method'),
                  const SizedBox(height: 8),
                  StatefulBuilder(builder: (ctx, ss) => Wrap(spacing: 8, children: _preferredMethods.map((m) {
                    final active = _commPref.contains(m);
                    return GestureDetector(
                      onTap: () { ss(() { setState(() { active ? _commPref.remove(m) : _commPref.add(m); }); }); },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
                        decoration: BoxDecoration(
                          color: active ? _brand600 : ctx.cardBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: active ? _brand600 : ctx.border, width: 1.5),
                        ),
                        child: Text(m, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: active ? Colors.white : ctx.textSub)),
                      ),
                    );
                  }).toList())),
                  const SizedBox(height: 14),
                  _FieldLabel('Preferred Language'),
                  _textField(context, _lang, hint: 'e.g. English, Hindi'),
                ]),
                const SizedBox(height: 14),

                // Notes
                _SectionCard(title: 'Notes', children: [
                  _textField(context, _notes, hint: 'Preferences, giving history, context…', maxLines: 4),
                ]),
                const SizedBox(height: 14),

                // Attachments
                _SectionCard(title: 'Attachments', children: [
                  GestureDetector(
                    onTap: _addingFile ? null : () async {
                      setState(() => _addingFile = true);
                      try {
                        final result = await FilePicker.platform.pickFiles(
                          allowMultiple: false,
                          withData: true,
                        );
                        if (result != null && result.files.isNotEmpty && mounted) {
                          final name = result.files.single.name;
                          if (name.isNotEmpty) {
                            setState(() => _attachments.add(name));
                          }
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Could not pick file: $e'), backgroundColor: _errorColor),
                          );
                        }
                      }
                      if (mounted) setState(() => _addingFile = false);
                    },
                    child: Container(
                      width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(color: context.surface2, borderRadius: BorderRadius.circular(12), border: Border.all(color: context.border, width: 1.5)),
                      child: _addingFile
                        ? const Center(child: SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: _brand600)))
                        : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                            Icon(Icons.attach_file_rounded, size: 18, color: context.textHint),
                            const SizedBox(width: 8),
                            Text('Select File (PDF, Image, Doc — any type)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.textHint)),
                          ]),
                    ),
                  ),
                  if (_attachments.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ..._attachments.asMap().entries.map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                        decoration: BoxDecoration(color: _brand100, borderRadius: BorderRadius.circular(10)),
                        child: Row(children: [
                          const Icon(Icons.insert_drive_file_outlined, size: 16, color: _brand600),
                          const SizedBox(width: 8),
                          Expanded(child: Text(e.value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _brand600), overflow: TextOverflow.ellipsis)),
                          GestureDetector(
                            onTap: () => setState(() => _attachments.removeAt(e.key)),
                            child: const Icon(Icons.close, size: 16, color: _brand600),
                          ),
                        ]),
                      ),
                    )),
                  ],
                ]),
                const SizedBox(height: 24),
              ]),
                ),
              ),
            ),
          ),
        ),

        // ── bottom buttons ─────────────────────────────────────────
        Container(
          padding: EdgeInsets.fromLTRB(18, 14, 18, MediaQuery.of(context).padding.bottom + 14),
          decoration: BoxDecoration(
            color: context.headerBg,
            border: Border(top: BorderSide(color: context.border)),
            boxShadow: const [BoxShadow(color: Color(0x140D2822), blurRadius: 12, offset: Offset(0, -4))],
          ),
          child: Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => context.go('/donors'),
              style: OutlinedButton.styleFrom(
                foregroundColor: context.textSub,
                side: BorderSide(color: context.border, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Cancel', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            )),
            const SizedBox(width: 12),
            Expanded(flex: 2, child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: _brand600,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _brand600.withValues(alpha: 0.6),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 16),
                elevation: 0,
              ),
              child: _saving
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : const Text('Save Donor', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            )),
          ]),
        ),
      ]),
    );
  }
}

// ── Section card ──────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 8),
      child: Text(title, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: context.textSub, letterSpacing: 0.5)),
    ),
    Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.border),
        boxShadow: const [BoxShadow(color: Color(0x080D2822), blurRadius: 6, offset: Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    ),
  ]);
}

// ── Field label ───────────────────────────────────────────────────────
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(text, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.textPrimary)),
  );
}

// ── Text field ────────────────────────────────────────────────────────
Widget _textField(
  BuildContext ctx,
  TextEditingController ctrl, {
  String hint = '',
  TextInputType? keyboardType,
  int maxLines = 1,
  TextCapitalization textCapitalization = TextCapitalization.words,
  List<TextInputFormatter>? inputFormatters,
  String? Function(String?)? validator,
}) => TextFormField(
  controller: ctrl,
  keyboardType: maxLines > 1 ? TextInputType.multiline : keyboardType,
  textCapitalization: textCapitalization,
  maxLines: maxLines,
  inputFormatters: inputFormatters,
  validator: validator,
  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: ctx.textPrimary),
  decoration: InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: ctx.textHint, fontWeight: FontWeight.w500, fontSize: 14),
    filled: true,
    fillColor: ctx.surface2,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: ctx.border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: ctx.border)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _brand600, width: 1.5)),
    errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _errorColor)),
    focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _errorColor, width: 1.5)),
    isDense: true,
  ),
);

// ── Date field ────────────────────────────────────────────────────────
class _DateField extends StatelessWidget {
  const _DateField({required this.ctrl, required this.hint, required this.onTap});
  final TextEditingController ctrl;
  final String hint;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: ctrl,
    readOnly: true,
    onTap: onTap,
    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: context.textPrimary),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: context.textHint, fontSize: 14, fontWeight: FontWeight.w500),
      suffixIcon: Icon(Icons.calendar_today_outlined, size: 18, color: context.textHint),
      filled: true, fillColor: context.surface2,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _brand600, width: 1.5)),
      isDense: true,
    ),
  );
}

// ── Gender toggle ─────────────────────────────────────────────────────
class _GenderToggle extends StatelessWidget {
  const _GenderToggle({required this.value, required this.onChanged});
  final String value;
  final ValueChanged<String> onChanged;
  @override
  Widget build(BuildContext context) => Row(children: ['Male','Female'].map((g) {
    final active = value == g;
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: GestureDetector(
        onTap: () => onChanged(g),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
          decoration: BoxDecoration(
            color: active ? _brand600 : context.cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: active ? _brand600 : context.border, width: 1.5),
          ),
          child: Text(g, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: active ? Colors.white : context.textSub)),
        ),
      ),
    );
  }).toList());
}

// ── Category dropdown ─────────────────────────────────────────────────
class _CategoryDropdown extends StatelessWidget {
  const _CategoryDropdown({required this.value, required this.onChanged});
  final String? value;
  final ValueChanged<String?> onChanged;
  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
    value: value,
    onChanged: onChanged,
    hint: Text('Select category', style: TextStyle(color: context.textHint, fontSize: 14, fontWeight: FontWeight.w500)),
    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600, color: context.textPrimary),
    decoration: InputDecoration(
      filled: true, fillColor: context.surface2,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: context.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _brand600, width: 1.5)),
      isDense: true,
    ),
    icon: Icon(Icons.keyboard_arrow_down_rounded, color: context.textHint),
    dropdownColor: context.cardBg,
    borderRadius: BorderRadius.circular(16),
    items: _donorCategories.map((c) {
      final descriptions = {
        'Major Donor': 'High-value patron',
        'Child Sponsor': 'Sponsors a child',
        'Corporate Donor': 'Corporate giving',
        'Annual Donor': 'Yearly commitment',
        'One-Time Donor': 'Single donation',
        'Monthly': 'Recurring monthly',
        'General Donor': 'General contribution',
      };
      return DropdownMenuItem(
        value: c,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(c, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
          if (descriptions[c] != null)
            Text(descriptions[c]!, style: TextStyle(fontSize: 11.5, color: context.textHint, fontWeight: FontWeight.w500)),
        ]),
      );
    }).toList(),
  );
}
