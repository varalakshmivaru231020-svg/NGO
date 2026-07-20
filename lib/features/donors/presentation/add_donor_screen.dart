import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/widgets/phone_field_with_code.dart';
import '../../../core/widgets/photo_picker_widget.dart';
import '../../dashboard/presentation/dashboard_screen.dart' show dashboardRefreshProvider;
import 'donors_screen.dart' show donorsProvider, demoLocalDonors, donorRefreshProvider, localDonorPhotos;

// ── colours ───────────────────────────────────────────────────────────
const _brand600 = Color(0xFFFF9933);
const _brand100 = Color(0xFFFFE8CC);
const _errorColor = Color(0xFFF2685E);

const _preferredMethods = ['Call', 'WhatsApp', 'Email'];

void _toast(BuildContext ctx, String msg, {bool error = false}) {
  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
    content: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(error ? Icons.error_outline : Icons.check_circle_outline, color: Colors.white, size: 18),
      const SizedBox(width: 8),
      Flexible(child: Text(msg, style: const TextStyle(fontWeight: FontWeight.w700))),
    ]),
    backgroundColor: error ? _errorColor : _brand600,
    behavior: SnackBarBehavior.floating,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ));
}

String _donorSaveError(Object e) {
  if (e is DioException) {
    final code = e.response?.statusCode;
    final data = e.response?.data;
    final msg = (data is Map && data['message'] != null) ? data['message'].toString() : null;
    if (code == 401 || code == 403) return 'Saved locally — log in as admin to sync to server';
    return msg != null ? 'Not saved to server: $msg' : 'Saved locally (server unavailable)';
  }
  return 'Saved locally (server unavailable)';
}

// ══════════════════════════════════════════════════════════════════════
class AddDonorScreen extends ConsumerStatefulWidget {
  const AddDonorScreen({super.key, this.donorId});
  // When set, the form loads and edits this donor (PUT) instead of creating
  // a new one (POST).
  final String? donorId;
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
  bool _saving = false;
  Uint8List? _photoBytes;

  // categories loaded from API: name → id
  Map<String, String> _categoryNameToId = {};
  bool _loadingCategories = true;
  bool get _isEditing => widget.donorId != null;
  bool _loadingDonor = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    if (_isEditing) _loadDonor();
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
      if (mounted) setState(() { _categoryNameToId = map; _loadingCategories = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingCategories = false);
    }
  }

  String _fromIso(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return '';
    return '${d.day.toString().padLeft(2,'0')} / ${d.month.toString().padLeft(2,'0')} / ${d.year}';
  }

  Future<void> _loadDonor() async {
    setState(() => _loadingDonor = true);
    try {
      final res = await apiClient.get('/donors/${widget.donorId}');
      final d = (res['data'] as Map).cast<String, dynamic>();
      String s(String k) => (d[k] ?? '').toString();
      _name.text = s('name');
      _mobile.text = s('mobile');
      _whatsapp.text = s('whatsapp');
      _email.text = s('email');
      _pan.text = s('pan');
      _aadhaar.text = s('aadhaar');
      _street.text = s('address');
      _city.text = s('city');
      _state.text = s('state');
      if (s('country').isNotEmpty) _country.text = s('country');
      _pincode.text = s('pincode');
      if (s('dob').isNotEmpty) _dob.text = _fromIso(s('dob'));
      if (s('anniversary').isNotEmpty) _anniv.text = _fromIso(s('anniversary'));
      _occupation.text = s('occupation');
      _org.text = s('company');
      _lang.text = s('preferredLanguage');
      _notes.text = s('notes');
      final prefCsv = s('preferredContactMethod');
      if (prefCsv.isNotEmpty) {
        const backToLabel = {'CALL': 'Call', 'WHATSAPP': 'WhatsApp', 'EMAIL': 'Email'};
        _commPref.addAll(prefCsv.split(',').map((c) => backToLabel[c.trim()] ?? c.trim()).where(_preferredMethods.contains));
      }
      final gender = s('gender');
      final categories = (d['categories'] as List?) ?? const [];
      final firstCatName = categories.isNotEmpty ? (((categories.first as Map?)?['category'] as Map?)?['name'] as String?) : null;
      Uint8List? avatar;
      final avatarB64 = s('avatar');
      if (avatarB64.isNotEmpty) {
        try { avatar = base64Decode(avatarB64); } catch (_) {}
      }
      if (mounted) setState(() {
        if (gender == 'FEMALE') _gender = 'Female';
        if (gender == 'MALE') _gender = 'Male';
        if (firstCatName != null) _category = firstCatName;
        if (avatar != null) _photoBytes = avatar;
        _loadingDonor = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingDonor = false);
    }
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

    // Only fields the backend CreateDonorDto accepts (others → 400 rejection).
    final avatarB64 = _photoBytes != null ? base64Encode(_photoBytes!) : null;
    final payload = <String, dynamic>{
      'name':   _name.text.trim(),
      'mobile': _mobile.text.trim(),
      'gender': _gender == 'Male' ? 'MALE' : 'FEMALE',
      'tier':   'SILVER',
      if (_whatsapp.text.trim().isNotEmpty)   'whatsapp':   _whatsapp.text.trim(),
      if (_email.text.trim().isNotEmpty)       'email':      _email.text.trim(),
      if (_pan.text.trim().isNotEmpty)         'pan':        _pan.text.trim(),
      if (_aadhaar.text.trim().isNotEmpty)     'aadhaar':    _aadhaar.text.trim(),
      if (_city.text.trim().isNotEmpty)        'city':       _city.text.trim(),
      if (_state.text.trim().isNotEmpty)       'state':      _state.text.trim(),
      if (_country.text.trim().isNotEmpty)     'country':    _country.text.trim(),
      if (_pincode.text.trim().isNotEmpty)     'pincode':    _pincode.text.trim(),
      if (_commPref.isNotEmpty)                'preferredContactMethod': _commPref.map((m) => m.toUpperCase()).join(','),
      if (_occupation.text.trim().isNotEmpty)  'occupation': _occupation.text.trim(),
      if (_org.text.trim().isNotEmpty)         'company':    _org.text.trim(),
      if (_notes.text.trim().isNotEmpty)       'notes':      _notes.text.trim(),
      if (_street.text.trim().isNotEmpty)      'address':    _street.text.trim(),
      if (_dob.text.trim().isNotEmpty)         'dob':         _toIso(_dob.text.trim()),
      if (_anniv.text.trim().isNotEmpty)       'anniversary': _toIso(_anniv.text.trim()),
      if (avatarB64 != null)                   'avatar':     avatarB64,
      if (_category != null && _categoryNameToId.containsKey(_category))
        'categoryIds': [_categoryNameToId[_category]!],
    };

    String? savedId = widget.donorId;
    try {
      final res = _isEditing
          ? await apiClient.put('/donors/${widget.donorId}', payload)
          : await apiClient.post('/donors', payload);
      // Non-Super-Admins: queued for approval — don't add/update locally.
      if ((res['meta'] as Map?)?['pendingApproval'] == true) {
        if (mounted) {
          setState(() => _saving = false);
          _toast(context, 'Submitted for Super Admin approval');
          context.go(_isEditing ? '/donors/${widget.donorId}' : '/donors');
        }
        return;
      }
      final saved = (res['data'] as Map).cast<String, dynamic>();
      savedId = saved['id'] as String? ?? savedId;
    } catch (e) {
      if (_isEditing) {
        // Editing must reflect real backend state — don't fake a local save.
        if (mounted) {
          setState(() => _saving = false);
          _toast(context, _donorSaveError(e), error: true);
        }
        return;
      }
      // Create: backend rejected/unreachable — fall back to a local-only
      // donor so the user isn't blocked, but tell them it wasn't saved.
      final localId = 'local_${DateTime.now().microsecondsSinceEpoch}';
      demoLocalDonors.insert(0, {
        ...payload,
        'id': localId,
        '_count': {'donations': 0},
        'categories': _category != null
            ? [{'category': {'name': _category!, 'color': '#FF9933'}}]
            : <dynamic>[],
      });
      if (_photoBytes != null) localDonorPhotos[localId] = _photoBytes!;
      if (mounted) {
        ref.read(donorRefreshProvider.notifier).state++;
        setState(() => _saving = false);
        _toast(context, _donorSaveError(e), error: true);
        context.go('/donors');
      }
      return;
    }

    // Saved to the database. Cache the photo by its real id for instant display.
    if (savedId != null && _photoBytes != null) localDonorPhotos[savedId] = _photoBytes!;
    if (mounted) {
      ref.read(donorRefreshProvider.notifier).state++; // refetch list from backend
      ref.read(dashboardRefreshProvider.notifier).state++;
      setState(() => _saving = false);
      _toast(context, _isEditing ? 'Donor updated successfully!' : 'Donor saved successfully!');
      // Open the donor so the change is clearly visible.
      context.go(savedId != null ? '/donors/$savedId' : '/donors');
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      body: Column(children: [
        // ── Compact header (back + title only) ────────────────────
        Container(
          padding: EdgeInsets.fromLTRB(4, top + 6, 16, 10),
          decoration: const BoxDecoration(color: Colors.white, border: Border(bottom: BorderSide(color: Color(0xFFE5EBE9)))),
          child: Row(children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Color(0xFF15211E)),
              onPressed: () => context.go('/donors'),
            ),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(_isEditing ? 'Edit Donor' : 'Add Donor', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF15211E))),
              if (!_isEditing) Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: _brand100, borderRadius: BorderRadius.circular(6)),
                child: const Text('ID  ·  SF-D-auto', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: _brand600)),
              ),
            ]),
          ]),
        ),

        if (_loadingDonor)
          const Expanded(child: Center(child: CircularProgressIndicator(color: _brand600)))
        else
        // ── form ───────────────────────────────────────────────────
        Expanded(
          child: Form(
            key: _form,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // ── Photo + Personal ──────────────────────────────────
                _Section(title: 'Personal Information', children: [
                  Center(child: PhotoPickerCircle(label: 'Photo', size: 92, initialImage: _photoBytes, onImageChanged: (b) => setState(() => _photoBytes = b))),
                  const SizedBox(height: 16),
                  _Row2(
                    left:  _Field(label: 'Full Name *', child: _textField(context, _name, hint: 'e.g. Rajesh Khanna', validator: (v) => v!.isEmpty ? 'Required' : null)),
                    right: _Field(label: 'Gender',      child: _GenderToggle(value: _gender, onChanged: (v) => setState(() => _gender = v))),
                  ),
                  _Row2(
                    left:  _Field(label: 'Date of Birth',   child: _DateField(ctrl: _dob,   hint: 'DD / MM / YYYY', onTap: () => _pickDate(_dob))),
                    right: _Field(label: 'Donor Category',  child: _loadingCategories
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          child: Text('Loading categories…',
                            style: TextStyle(color: context.textHint, fontSize: 13, fontWeight: FontWeight.w500)))
                      : _categoryNameToId.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(children: [
                              Expanded(child: Text('No categories yet.',
                                style: TextStyle(color: context.textHint, fontSize: 13, fontWeight: FontWeight.w500))),
                              TextButton(
                                onPressed: () async {
                                  await context.push('/donors/categories');
                                  if (mounted) _loadCategories();
                                },
                                child: const Text('Add Category', style: TextStyle(fontWeight: FontWeight.w700)),
                              ),
                            ]),
                          )
                        : _CategoryDropdown(
                            value: _category, categories: _categoryNameToId.keys.toList(),
                            onChanged: (v) => setState(() => _category = v))),
                  ),
                ]),
                const SizedBox(height: 14),

                // ── Contact Information ───────────────────────────────
                _Section(title: 'Contact Information', children: [
                  _Row2(
                    left:  _Field(label: 'Mobile *',  child: PhoneFieldWithCode(ctrl: _mobile,   required: true)),
                    right: _Field(label: 'WhatsApp',  child: PhoneFieldWithCode(ctrl: _whatsapp)),
                  ),
                  _Row2(
                    left:  _Field(label: 'Email',     child: _textField(context, _email, hint: 'name@email.com', keyboardType: TextInputType.emailAddress)),
                    right: _Field(label: 'Preferred Language', child: _textField(context, _lang, hint: 'e.g. English, Hindi')),
                  ),
                  _Field(label: 'Preferred Contact Method', child: StatefulBuilder(builder: (ctx, ss) =>
                    Wrap(spacing: 8, children: _preferredMethods.map((m) {
                      final active = _commPref.contains(m);
                      return GestureDetector(
                        onTap: () => ss(() => setState(() => active ? _commPref.remove(m) : _commPref.add(m))),
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 6, top: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: active ? _brand600 : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: active ? _brand600 : const Color(0xFFD8E5E0), width: 1.5),
                          ),
                          child: Text(m, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: active ? Colors.white : const Color(0xFF5A6B67))),
                        ),
                      );
                    }).toList()),
                  )),
                ]),
                const SizedBox(height: 14),

                // ── Address ───────────────────────────────────────────
                _Section(title: 'Address', children: [
                  _Field(label: 'Street Address', child: _textField(context, _street, hint: 'House / Street / Area', maxLines: 2)),
                  const SizedBox(height: 12),
                  _Row2(
                    left:  _Field(label: 'City',    child: _textField(context, _city,    hint: 'City')),
                    right: _Field(label: 'State',   child: _textField(context, _state,   hint: 'State')),
                  ),
                  _Row2(
                    left:  _Field(label: 'Country', child: _textField(context, _country, hint: 'Country')),
                    right: _Field(label: 'Pincode', child: _textField(context, _pincode, hint: '000000',
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)])),
                  ),
                ]),
                const SizedBox(height: 14),

                // ── Professional & Identity ───────────────────────────
                _Section(title: 'Professional & Identity', children: [
                  _Row2(
                    left:  _Field(label: 'Occupation',  child: _textField(context, _occupation, hint: 'e.g. Business Owner')),
                    right: _Field(label: 'Organisation', child: _textField(context, _org,        hint: 'Company / Trust')),
                  ),
                  _Row2(
                    left:  _Field(label: 'Anniversary', child: _DateField(ctrl: _anniv, hint: 'DD / MM / YYYY', onTap: () => _pickDate(_anniv))),
                    right: _Field(label: 'PAN Number',  child: _textField(context, _pan, hint: 'ABCDE1234F',
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')), LengthLimitingTextInputFormatter(10)],
                      textCapitalization: TextCapitalization.characters)),
                  ),
                  _Row2(
                    left:  _Field(label: 'Aadhaar', child: _textField(context, _aadhaar, hint: '0000 0000 0000',
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(12)])),
                    right: const SizedBox(),
                  ),
                ]),
                const SizedBox(height: 14),

                // ── Notes ────────────────────────────────────────────
                _Section(title: 'Notes', children: [
                  _Field(label: 'Notes', child: _textField(context, _notes, hint: 'Preferences, giving history, context…', maxLines: 4)),
                  const SizedBox(height: 6),
                ]),
                const SizedBox(height: 20),

                // ── Action buttons ─────────────────────────────────
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => context.go('/donors'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF5A6B67),
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFFD8E5E0), width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Cancel', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
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
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                        : Text(_isEditing ? 'Update Donor' : 'Save Donor', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                    ),
                  ),
                ]),
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

// ── Section (replaces SectionCard for new grid layout) ───────────────
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 10),
      child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFFFF9933), letterSpacing: 0.3)),
    ),
    Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5EBE9)),
        boxShadow: const [BoxShadow(color: Color(0x060D2822), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    ),
  ]);
}

// ── Two-column row (single column on narrow/mobile screens) ──────────
class _Row2 extends StatelessWidget {
  const _Row2({required this.left, required this.right});
  final Widget left, right;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (_, constraints) {
      final wide = constraints.maxWidth >= 480;
      if (wide) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: left),
            const SizedBox(width: 14),
            Expanded(child: right),
          ]),
        );
      }
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        left,
        const SizedBox(height: 14),
        right,
        const SizedBox(height: 14),
      ]);
    },
  );
}

// ── Labelled field wrapper ─────────────────────────────────────────────
class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});
  final String label;
  final Widget child;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF5A6B67))),
    const SizedBox(height: 6),
    child,
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
// Options come from the real backend categories (Donors > Categorization),
// not a hardcoded list — a hardcoded list here previously meant the chosen
// name almost never matched a real category id, so donors were created
// without any category link and every category filter showed 0 donors.
class _CategoryDropdown extends StatelessWidget {
  const _CategoryDropdown({required this.value, required this.categories, required this.onChanged});
  final String? value;
  final List<String> categories;
  final ValueChanged<String?> onChanged;
  @override
  Widget build(BuildContext context) {
    // Guard against a stale/loading value that isn't in the current item
    // list — DropdownButtonFormField throws if `value` has no matching item.
    final safeValue = categories.contains(value) ? value : null;
    return DropdownButtonFormField<String>(
      value: safeValue,
      onChanged: onChanged,
      hint: Text(categories.isEmpty ? 'Loading categories…' : 'Select category',
        style: TextStyle(color: context.textHint, fontSize: 14, fontWeight: FontWeight.w500)),
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
      items: categories.map((c) => DropdownMenuItem(
        value: c,
        child: Text(c, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
      )).toList(),
    );
  }
}
