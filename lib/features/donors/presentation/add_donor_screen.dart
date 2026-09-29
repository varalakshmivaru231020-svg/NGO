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
import '../../../core/widgets/lazy_photo.dart' show decodePhoto, evictLazyPhoto;
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
  // The already-registered donor this form collides with (same name + mobile),
  // shown as an inline banner above the form fields.
  Map<String, dynamic>? _duplicateOf;

  // categories loaded from API: name → id
  Map<String, String> _categoryNameToId = {};
  bool _loadingCategories = true;
  bool get _isEditing => widget.donorId != null;
  bool _loadingDonor = false;
  String? _loadError;
  // Only re-send the (large) base64 avatar when the user actually changed it.
  bool _photoChanged = false;

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
      final avatar = decodePhoto(s('avatar'));
      if (mounted) setState(() {
        if (gender == 'FEMALE') _gender = 'Female';
        if (gender == 'MALE') _gender = 'Male';
        if (firstCatName != null) _category = firstCatName;
        if (avatar != null) _photoBytes = avatar;
        _loadingDonor = false;
        _loadError = null;
      });
    } catch (e) {
      // Don't fall through to an empty form — saving it would wipe the donor.
      if (mounted) setState(() {
        _loadingDonor = false;
        _loadError = ApiClient.errorMessage(e, fallback: 'Could not load this donor');
      });
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

  // ── duplicate guard ────────────────────────────────────────────────
  // name + mobile together identify a donor. The backend rejects a repeat with
  // 409, but a non-Super-Admin's create is short-circuited into an approval
  // request before it ever reaches that check — so look for the clash here too
  // and tell the user straight away instead of queueing a doomed request.
  static String _normName(String s) => s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  static String _normMobile(String s) => s.replaceAll(RegExp(r'\D'), '');

  Future<Map<String, dynamic>?> _findDuplicate(String name, String mobile) async {
    final wantName = _normName(name);
    final wantMobile = _normMobile(mobile);
    if (wantName.isEmpty || wantMobile.isEmpty) return null;

    bool clashes(Map<String, dynamic> d) =>
        (d['id'] as String?) != widget.donorId &&
        _normName(d['name'] as String? ?? '') == wantName &&
        _normMobile(d['mobile'] as String? ?? '') == wantMobile;

    // Offline-only donors created earlier in this session.
    for (final d in demoLocalDonors) {
      if (clashes(d)) return d;
    }

    // Search on the number AND the name: the stored value may be spaced or
    // punctuated differently, so whichever field matches exactly surfaces the
    // record, and the normalised compare above then confirms both fields.
    try {
      final results = await Future.wait([
        apiClient.get('/donors', params: {'search': wantMobile, 'limit': '100'}),
        apiClient.get('/donors', params: {'search': name.trim(), 'limit': '100'}),
      ]);
      for (final res in results) {
        for (final d in (res['data'] as List<dynamic>? ?? const [])) {
          if (d is Map && clashes(d.cast<String, dynamic>())) return d.cast<String, dynamic>();
        }
      }
    } catch (_) {
      // Offline — the backend check still guards the real save.
    }

    // The user's own submissions still awaiting approval aren't in /donors
    // yet, so without this the same donor could be queued twice and the clash
    // would only surface to the Super Admin at approval time.
    try {
      final r = await apiClient.get('/approvals/mine');
      final inner = r['data'];
      final reqs = inner is List
          ? inner
          : (inner is Map ? (inner['data'] as List<dynamic>? ?? const []) : const []);
      for (final q in reqs.whereType<Map<String, dynamic>>()) {
        if ((q['module'] as String?)?.toLowerCase() != 'donors' ||
            (q['action'] as String?)?.toUpperCase() != 'CREATE' ||
            (q['status'] as String?)?.toUpperCase() != 'PENDING') continue;
        final payload = (q['payload'] as Map?)?.cast<String, dynamic>() ?? const {};
        if (_normName(payload['name'] as String? ?? '') == wantName &&
            _normMobile(payload['mobile'] as String? ?? '') == wantMobile) {
          return {...payload, 'id': 'pending-${q['id']}', '_pendingApproval': true};
        }
      }
    } catch (_) {}
    return null;
  }

  void _reportDuplicate(Map<String, dynamic> d) {
    final code = d['donorCode'] as String?;
    _toast(
      context,
      d['_pendingApproval'] == true
          ? '${d['name'] ?? 'This donor'} with mobile ${d['mobile'] ?? ''} is already submitted for approval'
          : '${d['name'] ?? 'This donor'} with mobile ${d['mobile'] ?? ''} is already added'
              '${code != null && code.isNotEmpty ? ' ($code)' : ''}',
      error: true,
    );
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);

    // Best-effort pre-check — a slow or failing lookup must never block the
    // save; the backend's own 409 check still guards the real write.
    Map<String, dynamic>? existing;
    try {
      existing = await _findDuplicate(_name.text, _mobile.text)
          .timeout(const Duration(seconds: 8), onTimeout: () => null);
    } catch (_) {
      existing = null;
    }
    if (!mounted) return;
    if (existing != null) {
      if (!mounted) return;
      setState(() { _saving = false; _duplicateOf = existing; });
      _reportDuplicate(existing);
      return;
    }
    if (_duplicateOf != null) setState(() => _duplicateOf = null);

    // Only fields the backend CreateDonorDto accepts (forbidNonWhitelisted →
    // anything else is a 400). preferredLanguage has no DTO field — not sent.
    //
    // Create: omit empty optionals. Edit: send every optional so a field the
    // user cleared really clears — '' for plain strings (backend maps '' →
    // null), null for email/dates whose validators reject ''.
    String t(TextEditingController c) => c.text.trim();
    final edit = _isEditing;
    void opt(Map<String, dynamic> m, String key, String v, {bool nullWhenEmpty = false}) {
      if (v.isNotEmpty) {
        m[key] = v;
      } else if (edit) {
        m[key] = nullWhenEmpty ? null : '';
      }
    }
    final payload = <String, dynamic>{
      'name':   t(_name),
      'mobile': t(_mobile),
      'gender': _gender == 'Male' ? 'MALE' : 'FEMALE',
      // Only a new donor gets the default tier — an edit must not reset it.
      if (!edit) 'tier': 'SILVER',
    };
    opt(payload, 'whatsapp', t(_whatsapp));
    opt(payload, 'email', t(_email), nullWhenEmpty: true);
    opt(payload, 'pan', t(_pan));
    opt(payload, 'aadhaar', t(_aadhaar));
    opt(payload, 'city', t(_city));
    opt(payload, 'state', t(_state));
    opt(payload, 'country', t(_country));
    opt(payload, 'pincode', t(_pincode));
    opt(payload, 'preferredContactMethod', _commPref.map((m) => m.toUpperCase()).join(','));
    opt(payload, 'occupation', t(_occupation));
    opt(payload, 'company', t(_org));
    opt(payload, 'notes', t(_notes));
    opt(payload, 'address', t(_street));
    opt(payload, 'dob', t(_dob).isNotEmpty ? _toIso(t(_dob)) : '', nullWhenEmpty: true);
    opt(payload, 'anniversary', t(_anniv).isNotEmpty ? _toIso(t(_anniv)) : '', nullWhenEmpty: true);
    // Avatar: always on create when picked; on edit only when changed (null = removed).
    if (!edit && _photoBytes != null) payload['avatar'] = base64Encode(_photoBytes!);
    if (edit && _photoChanged) payload['avatar'] = _photoBytes != null ? base64Encode(_photoBytes!) : null;
    if (_category != null && _categoryNameToId.containsKey(_category)) {
      payload['categoryIds'] = [_categoryNameToId[_category]!];
    } else if (edit && _category == null && _categoryNameToId.isNotEmpty) {
      payload['categoryIds'] = <String>[]; // user cleared the category
    }

    String? savedId = widget.donorId;
    Map<String, dynamic> res;
    try {
      res = edit
          ? await apiClient.put('/donors/${widget.donorId}', payload)
          : await apiClient.post('/donors', payload);
    } catch (e) {
      // 409 = this name + mobile is already registered. A deliberate refusal,
      // not an outage, so never soften it into a local-only save — that would
      // create the very duplicate the server just rejected.
      if (e is DioException && e.response?.statusCode == 409) {
        if (mounted) {
          setState(() { _saving = false; _duplicateOf = {'name': _name.text.trim(), 'mobile': _mobile.text.trim()}; });
          final data = e.response?.data;
          _toast(context,
              (data is Map && data['message'] != null)
                  ? data['message'].toString()
                  : 'This name and number is already added',
              error: true);
        }
        return;
      }
      // Any other failure (validation, auth, server down): NOT saved. Stay on
      // the form with the user's input intact and show the real reason — a
      // fake local donor here used to show up as a 0-donation "saved" record
      // that vanished on reload.
      if (mounted) {
        setState(() => _saving = false);
        _toast(context, ApiClient.errorMessage(e, fallback: 'Donor was not saved. Please try again.'), error: true);
      }
      return;
    }

    // The request succeeded — from here on nothing is treated as a save
    // failure, even if the response shape is unexpected.
    if (!mounted) return;
    // Non-Super-Admins: queued for approval — don't add/update locally.
    final meta = res['meta'];
    if (meta is Map && meta['pendingApproval'] == true) {
      setState(() => _saving = false);
      _toast(context, 'Submitted for approval');
      ref.read(donorRefreshProvider.notifier).state++; // shows it as pending
      context.go(edit ? '/donors/${widget.donorId}' : '/donors');
      return;
    }
    final data = res['data'];
    if (data is Map && data['id'] != null) savedId = data['id'].toString();

    // Saved to the database. Cache the photo by its real id for instant display.
    if (savedId != null) {
      evictLazyPhoto('/donors/$savedId/avatar');
      if (_photoBytes != null) {
        localDonorPhotos[savedId] = _photoBytes!;
      } else {
        localDonorPhotos.remove(savedId);
      }
    }
    ref.read(donorRefreshProvider.notifier).state++; // refetch list from backend
    ref.read(dashboardRefreshProvider.notifier).state++;
    setState(() => _saving = false);
    _toast(context, edit ? 'Donor updated successfully!' : 'Donor saved successfully!');
    // Open the donor so the change is clearly visible.
    context.go(savedId != null ? '/donors/$savedId' : '/donors');
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
        else if (_loadError != null)
          Expanded(child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, color: _errorColor, size: 44),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(_loadError!, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.textSub)),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () { setState(() => _loadError = null); _loadDonor(); },
              child: const Text('Retry', style: TextStyle(color: _brand600, fontWeight: FontWeight.w700)),
            ),
          ])))
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

                // Stays put after the toast fades, with a link to the donor
                // that already holds this name + number.
                if (_duplicateOf != null) _DuplicateBanner(
                  donor: _duplicateOf!,
                  onOpen: () {
                    final id = _duplicateOf!['id'] as String?;
                    if (id != null) context.go('/donors/$id');
                  },
                ),

                // ── Photo + Personal ──────────────────────────────────
                _Section(title: 'Personal Information', children: [
                  Center(child: PhotoPickerCircle(label: 'Photo', size: 92, initialImage: _photoBytes, onImageChanged: (b) => setState(() { _photoBytes = b; _photoChanged = true; }))),
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

// ── Duplicate donor banner ────────────────────────────────────────────
// name + mobile identify a donor; this is what the user sees when the pair is
// already registered.
class _DuplicateBanner extends StatelessWidget {
  const _DuplicateBanner({required this.donor, required this.onOpen});
  final Map<String, dynamic> donor;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final code = donor['donorCode'] as String? ?? '';
    final pending = donor['_pendingApproval'] == true;
    final id = donor['id'] as String?;
    // Only a real saved donor has a profile to open — local-only and
    // awaiting-approval entries have no route.
    final isSaved = id != null && !id.startsWith('local_') && !id.startsWith('pending-');
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: _errorColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _errorColor.withValues(alpha: 0.4)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.person_off_outlined, color: _errorColor, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(
              pending
                  ? 'This name and number is already submitted for approval'
                  : 'This name and number is already added',
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: _errorColor)),
          const SizedBox(height: 3),
          Text(
            '${donor['name'] ?? ''} · ${donor['mobile'] ?? ''}${code.isNotEmpty ? '  ($code)' : ''}',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: context.textSub),
          ),
          if (isSaved) Padding(
            padding: const EdgeInsets.only(top: 2),
            child: TextButton(
              onPressed: onOpen,
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 30)),
              child: const Text('Open existing donor',
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: _brand600)),
            ),
          ),
        ])),
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
