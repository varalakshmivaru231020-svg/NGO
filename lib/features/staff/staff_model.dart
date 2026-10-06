import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/network/api_client.dart';
import '../../core/widgets/lazy_photo.dart';
import 'package:saksham_app/core/ui/ui.dart';

// ══════════════════════════════════════════════════════════════════════
// STAFF — model + option lists shared by the list, profile and form.
// Backend: /staff (see saksham-backend/src/staff). Salary figures are whole
// rupees per month.
// ══════════════════════════════════════════════════════════════════════

const kStaffEmploymentTypes = [
  (key: 'FULL_TIME', label: 'Full-time'),
  (key: 'PART_TIME', label: 'Part-time'),
  (key: 'CONTRACT',  label: 'Contract'),
  (key: 'VOLUNTEER', label: 'Volunteer'),
];

// ── Designation / Status option lists ─────────────────────────────────
// Server-side lists (GET /staff/lookups/:type) that grow with the "+" next to
// each field. Staff.status stores the option key; Staff.designation stores
// the label text.
class StaffOption {
  const StaffOption({required this.key, required this.label, this.isSystem = false});
  final String key, label;
  final bool isSystem;
}

// Used until the server answers, so screens never show raw keys.
const _fallbackStatuses = [
  StaffOption(key: 'ACTIVE', label: 'Active', isSystem: true),
  StaffOption(key: 'ON_LEAVE', label: 'On Leave'),
  StaffOption(key: 'RELIEVED', label: 'Relieved'),
];

class StaffLookups {
  StaffLookups._();

  static List<StaffOption> designations = [];
  static List<StaffOption> statuses = List.of(_fallbackStatuses);

  static Future<void>? _inflight;
  static DateTime? _loadedAt;

  // Loaded once; later calls reuse the result for a minute unless [force].
  static Future<void> load({bool force = false}) {
    final fresh = _loadedAt != null && DateTime.now().difference(_loadedAt!) < const Duration(minutes: 1);
    if (!force && fresh) return Future.value();
    return _inflight ??= _load().whenComplete(() => _inflight = null);
  }

  static List<StaffOption> _parse(Object? raw) => [
    for (final e in (raw is List ? raw : const []))
      if (e is Map && '${e['key'] ?? ''}'.isNotEmpty)
        StaffOption(key: '${e['key']}', label: '${e['label'] ?? e['key']}', isSystem: e['isSystem'] == true),
  ];

  static Future<void> _load() async {
    final res = await Future.wait([
      apiClient.get('/staff/lookups/DESIGNATION').then((r) => r['data']).catchError((_) => null),
      apiClient.get('/staff/lookups/STATUS').then((r) => r['data']).catchError((_) => null),
    ]);
    if (res[0] != null) designations = _parse(res[0]);
    final st = _parse(res[1]);
    if (st.isNotEmpty) statuses = st;
    _loadedAt = DateTime.now();
  }

  // "+" in the form. Returns the saved option — the existing one when the
  // label is already on the list. Throws on failure (caller shows the reason).
  static Future<StaffOption> add(String type, String label) async {
    final r = await apiClient.post('/staff/lookups/$type', {'label': label});
    final added = _parse([r['data']]).first;
    final list = type == 'STATUS' ? statuses : designations;
    if (!list.any((o) => o.key == added.key)) list.add(added);
    return added;
  }
}

String staffStatusLabel(String key) {
  for (final o in [...StaffLookups.statuses, ..._fallbackStatuses]) { if (o.key == key) return o.label; }
  return key.split('_').map((w) => w.isEmpty ? w : w[0] + w.substring(1).toLowerCase()).join(' ');
}

// Built-in statuses keep fixed colours; added ones get a stable colour from the key.
Color staffStatusColor(String key) {
  switch (key) {
    case 'ACTIVE':   return const Color(0xFF14A98C);
    case 'ON_LEAVE': return const Color(0xFFE0921A);
    case 'RELIEVED': return const Color(0xFF93A29F);
  }
  const palette = [Color(0xFF2D9CDB), Color(0xFF8E6CD8), Color(0xFFD36B9A), Color(0xFF0F9D8A), Color(0xFF6B7F2A)];
  var h = 0;
  for (final c in key.codeUnits) { h = (h * 31 + c) & 0x7FFFFFFF; }
  return palette[h % palette.length];
}

String staffEmploymentLabel(String key) =>
    kStaffEmploymentTypes.where((t) => t.key == key).map((t) => t.label).firstOrNull ?? key;
String staffGenderLabel(String key) => switch (key) { 'FEMALE' => 'Female', 'OTHER' => 'Other', _ => 'Male' };

String staffInr(int n) => '₹${NumberFormat('#,##,###', 'en_IN').format(n)}';

DateTime? staffParseDate(String raw) => raw.isEmpty ? null : DateTime.tryParse(raw)?.toLocal();
String staffDate(DateTime? d) => d == null ? '' : DateFormat('dd MMM yyyy').format(d);
// Date-only ISO for the API — avoids the UTC shift toIso8601String() would add.
String staffIsoDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

int staffAge(DateTime? dob) {
  if (dob == null) return 0;
  final now = DateTime.now();
  var a = now.year - dob.year;
  if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) a--;
  return a;
}

// Tolerant readers — one odd row must not blank the whole list.
String _str(Object? v) => v == null ? '' : v.toString();
int _int(Object? v) => v is num ? v.toInt() : int.tryParse(_str(v)) ?? 0;

class StaffChild {
  const StaffChild({required this.name, this.relation = '', this.dob, this.school = ''});
  final String name, relation, school;
  final DateTime? dob;

  factory StaffChild.fromJson(Map<String, dynamic> j) => StaffChild(
    name: _str(j['name']), relation: _str(j['relation']),
    dob: staffParseDate(_str(j['dob'])), school: _str(j['school']),
  );
}

class StaffMember {
  StaffMember({
    required this.id, required this.staffCode, required this.name, required this.designation,
    this.gender = 'MALE', this.dob, this.mobile = '', this.whatsapp = '', this.email = '', this.address = '',
    this.photo, this.hasPhoto = false, this.aadhaarNumber = '', this.panNumber = '',
    this.centerId = '', this.centreName = '', this.joiningDate, this.employmentType = 'FULL_TIME',
    this.status = 'ACTIVE', this.workTimings = '', this.basicSalary = 0, this.hra = 0, this.allowances = 0, this.pfApplicable = false,
    this.bankName = '', this.accountNumber = '', this.ifscCode = '',
    this.emergencyContactName = '', this.emergencyContactPhone = '', this.notes = '',
    this.children = const [], this.childCount = 0,
  });

  factory StaffMember.fromJson(Map<String, dynamic> j) {
    final center = j['center'];
    final kids = j['children'];
    final count = j['_count'];
    final children = [
      for (final c in (kids is List ? kids : const []))
        if (c is Map) StaffChild.fromJson(c.cast<String, dynamic>()),
    ];
    final photo = j['photo'] is String ? j['photo'] as String : null;
    return StaffMember(
      id: _str(j['id']), staffCode: _str(j['staffCode']), name: _str(j['name']),
      designation: _str(j['designation']), gender: _str(j['gender']).isEmpty ? 'MALE' : _str(j['gender']),
      dob: staffParseDate(_str(j['dob'])), mobile: _str(j['mobile']), whatsapp: _str(j['whatsapp']),
      email: _str(j['email']), address: _str(j['address']),
      photo: photo, hasPhoto: j['hasPhoto'] == true || (photo != null && photo.isNotEmpty),
      aadhaarNumber: _str(j['aadhaarNumber']), panNumber: _str(j['panNumber']),
      centerId: _str(j['centerId']), centreName: center is Map ? _str(center['name']) : '',
      joiningDate: staffParseDate(_str(j['joiningDate'])),
      employmentType: _str(j['employmentType']).isEmpty ? 'FULL_TIME' : _str(j['employmentType']),
      status: _str(j['status']).isEmpty ? 'ACTIVE' : _str(j['status']),
      workTimings: _str(j['workTimings']),
      basicSalary: _int(j['basicSalary']), hra: _int(j['hra']), allowances: _int(j['allowances']),
      pfApplicable: j['pfApplicable'] == true,
      bankName: _str(j['bankName']), accountNumber: _str(j['accountNumber']), ifscCode: _str(j['ifscCode']),
      emergencyContactName: _str(j['emergencyContactName']), emergencyContactPhone: _str(j['emergencyContactPhone']),
      notes: _str(j['notes']),
      children: children,
      childCount: count is Map ? _int(count['children']) : children.length,
    );
  }

  static StaffMember? tryParse(Object? raw) {
    if (raw is! Map) return null;
    try {
      final s = StaffMember.fromJson(raw.cast<String, dynamic>());
      return s.id.isEmpty ? null : s;
    } catch (_) {
      return null;
    }
  }

  final String id, staffCode, name, designation, gender, mobile, whatsapp, email, address;
  final String? photo;
  final bool hasPhoto;
  final String aadhaarNumber, panNumber, centerId, centreName, employmentType, status, workTimings;
  final DateTime? dob, joiningDate;
  final int basicSalary, hra, allowances;
  final bool pfApplicable;
  final String bankName, accountNumber, ifscCode, emergencyContactName, emergencyContactPhone, notes;
  final List<StaffChild> children;
  final int childCount;

  int get gross => basicSalary + hra + allowances;
  Uint8List? get photoBytes => decodePhoto(photo);
}

// ── Monthly salary record (/staff/:id/salaries) ───────────────────────
const kSalaryPaymentModes = [
  (key: 'BANK_TRANSFER', label: 'Bank Transfer'),
  (key: 'CASH', label: 'Cash'),
  (key: 'UPI', label: 'UPI'),
  (key: 'CHEQUE', label: 'Cheque'),
];

String salaryPaymentModeLabel(String key) =>
    kSalaryPaymentModes.where((m) => m.key == key).map((m) => m.label).firstOrNull ?? key;

// '2026-01' → DateTime(2026, 1) and back.
DateTime? salaryMonthDate(String month) {
  final p = month.split('-');
  if (p.length != 2) return null;
  final y = int.tryParse(p[0]), m = int.tryParse(p[1]);
  return y == null || m == null ? null : DateTime(y, m);
}
String salaryMonthKey(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}';
String salaryMonthLabel(String month) {
  final d = salaryMonthDate(month);
  return d == null ? month : DateFormat('MMMM yyyy').format(d);
}

class StaffSalary {
  const StaffSalary({
    required this.id, required this.month,
    this.basic = 0, this.hra = 0, this.allowances = 0, this.overtime = 0, this.bonus = 0,
    this.leaveDeduction = 0, this.pf = 0, this.advance = 0, this.otherDeduction = 0,
    this.workingDays, this.leaveDays = 0, this.workedOnHolidays = false,
    this.status = 'PENDING', this.paidOn, this.paymentMode = '', this.notes = '',
  });

  factory StaffSalary.fromJson(Map<String, dynamic> j) => StaffSalary(
    id: _str(j['id']), month: _str(j['month']),
    basic: _int(j['basic']), hra: _int(j['hra']), allowances: _int(j['allowances']),
    overtime: _int(j['overtime']), bonus: _int(j['bonus']),
    leaveDeduction: _int(j['leaveDeduction']), pf: _int(j['pf']),
    advance: _int(j['advance']), otherDeduction: _int(j['otherDeduction']),
    workingDays: j['workingDays'] == null ? null : _int(j['workingDays']),
    leaveDays: j['leaveDays'] is num ? (j['leaveDays'] as num).toDouble() : 0,
    workedOnHolidays: j['workedOnHolidays'] == true,
    status: _str(j['status']).isEmpty ? 'PENDING' : _str(j['status']),
    paidOn: staffParseDate(_str(j['paidOn'])),
    paymentMode: _str(j['paymentMode']), notes: _str(j['notes']),
  );

  static StaffSalary? tryParse(Object? raw) {
    if (raw is! Map) return null;
    try {
      final s = StaffSalary.fromJson(raw.cast<String, dynamic>());
      return s.id.isEmpty || salaryMonthDate(s.month) == null ? null : s;
    } catch (_) {
      return null;
    }
  }

  final String id, month, status, paymentMode, notes;
  final int basic, hra, allowances, overtime, bonus;
  final int leaveDeduction, pf, advance, otherDeduction;
  final int? workingDays;
  final double leaveDays;
  final bool workedOnHolidays;
  final DateTime? paidOn;

  int get gross => basic + hra + allowances + overtime + bonus;
  int get deductions => leaveDeduction + pf + advance + otherDeduction;
  int get net => gross - deductions;
  bool get isPaid => status == 'PAID';
  int get year => salaryMonthDate(month)?.year ?? 0;

  // 1.0 → "1", 1.5 → "1.5"
  String get leaveDaysLabel => leaveDays == leaveDays.roundToDouble() ? '${leaveDays.toInt()}' : '$leaveDays';
}

// Permanently deletes a staff member after confirmation. Returns true when the
// record is gone; false if cancelled or queued for Super Admin approval.
Future<bool> confirmDeleteStaff(BuildContext context, {required String id, required String name}) async {
  var pending = false;
  final ok = await AppConfirm.show(
    context,
    title: 'Delete staff member?',
    message: 'Are you sure you want to delete “$name”? Their profile, salary details and '
        'children details will be removed. This action cannot be undone.',
    onConfirm: () async {
      final res = await apiClient.delete('/staff/$id');
      pending = (res?['meta'] as Map?)?['pendingApproval'] == true;
    },
    errorText: (e) => ApiClient.errorMessage(e, fallback: 'Could not delete the staff member.'),
  );
  if (!ok || !context.mounted) return false;
  if (pending) {
    AppToast.warning(context, 'Submitted for Super Admin approval', detail: '“$name” will be deleted once approved.');
    return false;
  }
  AppToast.success(context, 'Staff member deleted', detail: '“$name” was removed.');
  return true;
}
