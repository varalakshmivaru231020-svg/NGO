import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart' as xl;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:saksham_app/core/ui/ui.dart';

import '../../../core/auth/role_auth.dart' show isAdmin;
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/native_file_saver.dart';
import 'donor_categories_screen.dart' show donorCategoriesProvider;
import 'donors_screen.dart' show donorRefreshProvider;

// ══════════════════════════════════════════════════════════════════════
// Import Donors — upload an .xlsx / .csv, preview what was understood,
// send it in batches to POST /donors/import, and show the per-row report.
// Parsing happens here so the server only ever sees clean JSON; the server
// owns the rules (required fields, duplicates, date formats) and reports
// per row, so a bad cell never blocks the rest of the file.
// ══════════════════════════════════════════════════════════════════════

const _brand600 = Color(0xFFFF9933);
const _green600 = Color(0xFF1E9E6A);
const _green100 = Color(0xFFDDF5EA);
const _amber600 = Color(0xFFD98A00);
const _amber100 = Color(0xFFFFF1D6);
const _coral500 = Color(0xFFE5484D);
const _coral100 = Color(0xFFFDE4E4);
const _sky600   = Color(0xFF2B7FD9);
const _sky100   = Color(0xFFE2EFFD);

// Rows per request. The backend accepts up to 500; smaller batches keep each
// call short on a phone connection and give a visible progress bar.
const _batchSize = 200;
const _xlsxMime = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

// ── Column map ───────────────────────────────────────────────────────
// A spreadsheet column is matched to a backend field by its header, compared
// with case, spacing and punctuation removed — "Mobile No." and "mobile_no"
// both land on `mobile`. Unknown columns are ignored and listed back.
class _Col {
  const _Col(this.key, this.header, this.aliases, {this.required = false, this.sample = ''});
  final String key;            // field name the backend expects
  final String header;         // header written into the template
  final List<String> aliases;  // normalised alternatives people actually use
  final bool required;
  final String sample;         // example row in the template
}

const _cols = <_Col>[
  _Col('name', 'Name', ['donorname', 'fullname', 'donor', 'nameofdonor'], required: true, sample: 'Asha Rao'),
  _Col('mobile', 'Mobile', ['mobileno', 'mobilenumber', 'phone', 'phoneno', 'phonenumber', 'contact', 'contactno', 'contactnumber', 'cell', 'cellno'], required: true, sample: '9876543210'),
  _Col('whatsapp', 'WhatsApp', ['whatsappno', 'whatsappnumber', 'wa', 'wano'], sample: '9876543210'),
  _Col('email', 'Email', ['emailid', 'emailaddress', 'mail', 'mailid'], sample: 'asha@example.com'),
  _Col('gender', 'Gender', ['sex'], sample: 'Female'),
  _Col('dob', 'Date of Birth', ['dob', 'birthdate', 'birthday', 'dateofbirth'], sample: '15/08/1980'),
  _Col('anniversary', 'Anniversary', ['anniversarydate', 'weddinganniversary', 'marriageanniversary', 'weddingdate'], sample: '20/11/2005'),
  _Col('address', 'Address', ['fulladdress', 'street', 'addressline', 'residentialaddress'], sample: '12, MG Road'),
  _Col('city', 'City', ['town', 'place', 'district'], sample: 'Bengaluru'),
  _Col('state', 'State', [], sample: 'Karnataka'),
  _Col('country', 'Country', [], sample: 'India'),
  _Col('pincode', 'Pincode', ['pin', 'pinno', 'pincodeno', 'zip', 'zipcode', 'postalcode', 'postcode'], sample: '560001'),
  _Col('occupation', 'Occupation', ['profession', 'job', 'work'], sample: 'Teacher'),
  _Col('company', 'Company', ['organisation', 'organization', 'firm', 'employer', 'companyname'], sample: 'ABC Pvt Ltd'),
  _Col('tier', 'Tier', ['donortier', 'level'], sample: 'Silver'),
  _Col('category', 'Category', ['categories', 'donorcategory', 'type', 'donortype', 'group'], sample: 'Regular Donor'),
  _Col('preferredContactMethod', 'Preferred Contact', ['preferredcontactmethod', 'contactmethod', 'contactpreference', 'preferredmode', 'preferredcontact'], sample: 'WhatsApp, Call'),
  _Col('pan', 'PAN', ['panno', 'pannumber', 'pancard', 'pancardno'], sample: 'ABCDE1234F'),
  _Col('aadhaar', 'Aadhaar', ['aadhar', 'aadhaarno', 'aadharno', 'aadhaarnumber', 'aadharnumber', 'uid'], sample: '1234 5678 9012'),
  _Col('notes', 'Notes', ['note', 'remarks', 'remark', 'comments', 'comment'], sample: ''),
];

String _normHeader(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

_Col? _colFor(String header) {
  final h = _normHeader(header);
  if (h.isEmpty) return null;
  for (final c in _cols) {
    if (_normHeader(c.header) == h || c.aliases.contains(h)) return c;
  }
  return null;
}

// ── Parsed file ──────────────────────────────────────────────────────
class _SheetRow {
  _SheetRow({required this.rowNo, required this.raw, required this.payload});
  final int rowNo;                    // spreadsheet row number (header = 1)
  final List<String> raw;             // original cells — for the problem-rows file
  final Map<String, dynamic> payload; // what goes to POST /donors/import
}

class _Parsed {
  _Parsed({required this.fileName, required this.headers, required this.matched, required this.ignored, required this.rows});
  final String fileName;
  final List<String> headers;
  final Map<String, int> matched; // backend key → column index
  final List<String> ignored;     // header text of columns we don't use
  final List<_SheetRow> rows;
  List<_Col> get missingRequired => _cols.where((c) => c.required && !matched.containsKey(c.key)).toList();
}

class _RowResult {
  _RowResult({required this.rowNo, required this.status, required this.name, required this.mobile, this.donorCode, this.reason, this.note});
  final int rowNo;
  final String status; // created | skipped | failed
  final String name, mobile;
  final String? donorCode, reason, note;

  factory _RowResult.fromJson(Map<String, dynamic> j) => _RowResult(
    rowNo: (j['row'] as num?)?.toInt() ?? 0,
    status: j['status'] as String? ?? 'failed',
    name: j['name'] as String? ?? '',
    mobile: j['mobile'] as String? ?? '',
    donorCode: j['donorCode'] as String?,
    reason: j['reason'] as String?,
    note: j['note'] as String?,
  );
}

// ── File → grid of strings ───────────────────────────────────────────
List<List<String>> _gridFromFile(String name, Uint8List bytes) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.csv') || lower.endsWith('.tsv') || lower.endsWith('.txt')) {
    return _parseCsv(utf8.decode(bytes, allowMalformed: true));
  }
  if (lower.endsWith('.xls')) {
    throw const FormatException('Old .xls files are not supported. Open it in Excel and save it as .xlsx first.');
  }
  final xl.Excel book;
  try {
    book = xl.Excel.decodeBytes(bytes);
  } catch (_) {
    throw const FormatException('This file could not be read as a spreadsheet. Save it as .xlsx or .csv and try again.');
  }
  // First sheet with more than a header row; else whatever comes first.
  xl.Sheet? sheet;
  for (final s in book.tables.values) {
    if (s.maxRows > 1) { sheet = s; break; }
  }
  sheet ??= book.tables.values.isEmpty ? null : book.tables.values.first;
  if (sheet == null) throw const FormatException('The workbook has no sheets.');
  return sheet.rows.map((r) => r.map(_cellText).toList()).toList();
}

String _two(int n) => n.toString().padLeft(2, '0');

String _cellText(xl.Data? d) {
  final v = d?.value;
  if (v == null) return '';
  if (v is xl.TextCellValue) return v.value.toString().trim();
  if (v is xl.IntCellValue) return v.value.toString();
  if (v is xl.DoubleCellValue) {
    // Mobile numbers and PINs arrive as doubles — never "9.8E9" or "560001.0".
    final x = v.value;
    if (x == x.roundToDouble() && x.abs() < 1e15) return x.toInt().toString();
    return x.toString();
  }
  if (v is xl.DateCellValue) return '${v.year}-${_two(v.month)}-${_two(v.day)}';
  if (v is xl.DateTimeCellValue) return '${v.year}-${_two(v.month)}-${_two(v.day)}';
  if (v is xl.BoolCellValue) return v.value ? 'Yes' : 'No';
  return '';
}

// Minimal RFC 4180 reader: quoted cells, doubled quotes, CR/LF line ends.
// Excel in some locales writes ";" between cells and tab-separated exports
// exist, so the separator is sniffed from the first non-empty line.
List<List<String>> _parseCsv(String input) {
  var text = input;
  if (text.startsWith('﻿')) text = text.substring(1);
  final firstLine = text.split(RegExp(r'\r?\n')).firstWhere((l) => l.trim().isNotEmpty, orElse: () => '');
  final sep = _pickSeparator(firstLine);

  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var quoted = false;
  for (var i = 0; i < text.length; i++) {
    final ch = text[i];
    if (quoted) {
      if (ch == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') { cell.write('"'); i++; } else { quoted = false; }
      } else {
        cell.write(ch);
      }
    } else if (ch == '"') {
      quoted = true;
    } else if (ch == sep) {
      row.add(cell.toString()); cell.clear();
    } else if (ch == '\r' || ch == '\n') {
      if (ch == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      row.add(cell.toString()); cell.clear();
      rows.add(row); row = <String>[];
    } else {
      cell.write(ch);
    }
  }
  if (cell.isNotEmpty || row.isNotEmpty) { row.add(cell.toString()); rows.add(row); }
  return rows;
}

String _pickSeparator(String line) {
  int count(String c) => c.allMatches(line).length;
  final tabs = count('\t'), semis = count(';'), commas = count(',');
  if (tabs > commas && tabs > semis) return '\t';
  if (semis > commas) return ';';
  return ',';
}

// Grid → header mapping + payload rows.
_Parsed _parseGrid(String fileName, List<List<String>> grid) {
  // Header = first row (within the top 10) naming Name plus at least one more
  // known column — a title line above the table is skipped.
  var headerIdx = -1;
  for (var i = 0; i < grid.length && i < 10; i++) {
    final cols = grid[i].map(_colFor).whereType<_Col>().toList();
    if (cols.any((c) => c.key == 'name') && cols.length >= 2) { headerIdx = i; break; }
  }
  if (headerIdx < 0) {
    throw const FormatException('No header row found. The first row should contain column names such as Name, Mobile, City — use the template if unsure.');
  }
  final headers = grid[headerIdx].map((h) => h.trim()).toList();
  final matched = <String, int>{};
  final ignored = <String>[];
  for (var c = 0; c < headers.length; c++) {
    final col = _colFor(headers[c]);
    if (col == null) {
      if (headers[c].isNotEmpty) ignored.add(headers[c]);
      continue;
    }
    matched.putIfAbsent(col.key, () => c); // first occurrence wins
  }
  final rows = <_SheetRow>[];
  for (var r = headerIdx + 1; r < grid.length; r++) {
    final cells = grid[r];
    if (cells.every((c) => c.trim().isEmpty)) continue;
    final payload = <String, dynamic>{'row': r + 1};
    matched.forEach((key, idx) {
      final v = idx < cells.length ? cells[idx].trim() : '';
      if (v.isNotEmpty) payload[key] = v;
    });
    rows.add(_SheetRow(rowNo: r + 1, raw: cells, payload: payload));
  }
  return _Parsed(fileName: fileName, headers: headers, matched: matched, ignored: ignored, rows: rows);
}

// ══════════════════════════════════════════════════════════════════════
class ImportDonorsScreen extends ConsumerStatefulWidget {
  const ImportDonorsScreen({super.key});
  @override
  ConsumerState<ImportDonorsScreen> createState() => _ImportDonorsScreenState();
}

enum _Stage { pick, importing, done }

class _ImportDonorsScreenState extends ConsumerState<ImportDonorsScreen> {
  _Parsed? _parsed;
  String? _fileError;
  bool _reading = false;
  bool _downloading = false;
  _Stage _stage = _Stage.pick;
  int _sent = 0;
  final List<_RowResult> _results = [];
  String? _stopError; // the request error that cut the import short, if any

  @override
  void initState() {
    super.initState();
    // Category names are shown as guidance and written into the template.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (ref.read(donorCategoriesProvider).isEmpty) {
        ref.read(donorCategoriesProvider.notifier).loadFromBackend();
      }
    });
  }

  xl.CellStyle get _headerStyle => xl.CellStyle(
    bold: true,
    backgroundColorHex: xl.ExcelColor.fromHexString('#FF9933'),
    fontColorHex: xl.ExcelColor.fromHexString('#FFFFFF'),
  );

  Future<bool> _saveBook(xl.Excel book, String filename) async {
    if (book.sheets.containsKey('Sheet1') && book.sheets.length > 1) book.delete('Sheet1');
    final bytes = book.encode();
    if (bytes == null) return false;
    return NativeFileSaver.saveBytes(filename, Uint8List.fromList(bytes), _xlsxMime);
  }

  // ── template ──────────────────────────────────────────────────────
  Future<void> _downloadTemplate() async {
    if (_downloading) return;
    setState(() => _downloading = true);
    final book = xl.Excel.createExcel();
    final sheet = book['Donors'];
    for (var c = 0; c < _cols.length; c++) {
      final cell = sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0));
      cell.value = xl.TextCellValue(_cols[c].header);
      cell.cellStyle = _headerStyle;
      sheet.setColumnWidth(c, _cols[c].header.length < 10 ? 16.0 : 22.0);
    }
    sheet.appendRow(_cols.map((c) => xl.TextCellValue(c.sample)).toList());

    final cats = ref.read(donorCategoriesProvider).map((c) => c.name).toList();
    final guide = book['Guide'];
    for (final line in <String>[
      'How to fill the Donors sheet',
      '',
      'Name and Mobile are required. Every other column is optional.',
      'Keep the header row as it is and delete the example row before importing.',
      'Dates: DD/MM/YYYY, e.g. 15/08/1980.',
      'Gender: Male, Female or Other. Tier: Platinum, Gold, Silver or Bronze (blank = Silver).',
      'Preferred Contact: any of Call, WhatsApp, Email — separate several with commas.',
      cats.isEmpty
          ? 'Category: must match a name from Donors → Categories.'
          : 'Category: one of — ${cats.join(', ')}',
      'A row whose Name + Mobile already exist is skipped, not added twice.',
    ]) {
      guide.appendRow([xl.TextCellValue(line)]);
    }
    guide.setColumnWidth(0, 95.0);

    const filename = 'SKET_Donor_Import_Template.xlsx';
    final ok = await _saveBook(book, filename);
    if (!mounted) return;
    setState(() => _downloading = false);
    if (ok) {
      AppToast.success(context, 'Template downloaded', detail: filename);
    } else {
      AppToast.error(context, 'Could not save the template');
    }
  }

  // ── pick + parse ──────────────────────────────────────────────────
  Future<void> _pickFile() async {
    if (_reading) return;
    FilePickerResult? res;
    try {
      res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['xlsx', 'xls', 'csv', 'tsv', 'txt'],
        withData: true,
      );
    } catch (_) {
      res = null;
    }
    final f = (res != null && res.files.isNotEmpty) ? res.files.first : null;
    if (f == null || f.bytes == null) return;
    setState(() { _reading = true; _fileError = null; _parsed = null; });
    try {
      final grid = _gridFromFile(f.name, f.bytes!);
      final parsed = _parseGrid(f.name, grid);
      if (parsed.rows.isEmpty) {
        throw const FormatException('The file has a header row but no donor rows under it.');
      }
      if (!mounted) return;
      setState(() { _parsed = parsed; _reading = false; });
    } on FormatException catch (e) {
      if (!mounted) return;
      setState(() { _fileError = e.message; _reading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _fileError = 'Could not read this file.'; _reading = false; });
    }
  }

  // ── upload ────────────────────────────────────────────────────────
  Future<void> _import() async {
    final parsed = _parsed;
    if (parsed == null || parsed.missingRequired.isNotEmpty || _stage != _Stage.pick) return;
    setState(() { _stage = _Stage.importing; _sent = 0; _results.clear(); _stopError = null; });

    final rows = parsed.rows;
    for (var start = 0; start < rows.length; start += _batchSize) {
      final end = start + _batchSize > rows.length ? rows.length : start + _batchSize;
      final batch = rows.sublist(start, end);
      try {
        final res = await apiClient.post('/donors/import', {
          'donors': batch.map((r) => r.payload).toList(),
        });
        final data = (res['data'] as Map?)?.cast<String, dynamic>() ?? const {};
        final list = (data['results'] as List? ?? const [])
            .whereType<Map>()
            .map((m) => _RowResult.fromJson(m.cast<String, dynamic>()));
        _results.addAll(list);
      } catch (e) {
        // Rows in this and later batches were never sent — report them as
        // such rather than silently dropping them from the counts.
        final msg = ApiClient.errorMessage(e, fallback: 'The server did not accept the upload.');
        for (final r in rows.sublist(start)) {
          _results.add(_RowResult(
            rowNo: r.rowNo, status: 'failed',
            name: (r.payload['name'] ?? '').toString(),
            mobile: (r.payload['mobile'] ?? '').toString(),
            reason: 'Not sent — $msg',
          ));
        }
        _stopError = msg;
        break;
      }
      if (!mounted) return;
      setState(() => _sent = end);
    }
    if (!mounted) return;
    ref.read(donorRefreshProvider.notifier).state++; // donors list re-fetches
    setState(() => _stage = _Stage.done);

    final created = _results.where((r) => r.status == 'created').length;
    if (_stopError != null) {
      AppToast.error(context, 'Import stopped early', detail: _stopError);
    } else if (created > 0) {
      AppToast.success(context, '$created donor${created == 1 ? '' : 's'} imported');
    } else {
      AppToast.warning(context, 'No new donors were added', detail: 'See the row-by-row report below.');
    }
  }

  // Problem rows back as a sheet the user can fix and upload again — same
  // headers as their file, with Row / Status / Reason in front (those three
  // are ignored on re-import).
  Future<void> _downloadProblems() async {
    final parsed = _parsed;
    final problems = _results.where((r) => r.status != 'created').toList();
    if (parsed == null || problems.isEmpty || _downloading) return;
    setState(() => _downloading = true);
    final byRow = {for (final r in parsed.rows) r.rowNo: r};
    final book = xl.Excel.createExcel();
    final sheet = book['Fix and re-import'];
    final headers = ['Row', 'Status', 'Reason', ...parsed.headers];
    for (var c = 0; c < headers.length; c++) {
      final cell = sheet.cell(xl.CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0));
      cell.value = xl.TextCellValue(headers[c]);
      cell.cellStyle = _headerStyle;
    }
    for (final p in problems) {
      final raw = byRow[p.rowNo]?.raw ?? const <String>[];
      sheet.appendRow([
        xl.TextCellValue('${p.rowNo}'),
        xl.TextCellValue(p.status),
        xl.TextCellValue(p.reason ?? ''),
        ...raw.map((v) => xl.TextCellValue(v)),
      ]);
    }
    sheet.setColumnWidth(2, 52.0);
    const filename = 'SKET_Donor_Import_Problems.xlsx';
    final ok = await _saveBook(book, filename);
    if (!mounted) return;
    setState(() => _downloading = false);
    if (ok) {
      AppToast.success(context, 'Problem rows downloaded', detail: filename);
    } else {
      AppToast.error(context, 'Could not save the file');
    }
  }

  void _reset() => setState(() {
    _parsed = null; _fileError = null; _results.clear();
    _sent = 0; _stopError = null; _stage = _Stage.pick;
  });

  // ── UI ────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: context.scaffoldBg,
      body: Column(children: [
        _header(context, top),
        Expanded(
          child: !isAdmin
              ? ListView(children: const [
                  EmptyState(
                    icon: Icons.lock_outline_rounded,
                    title: 'Admins only',
                    message: 'Bulk import is available to Admin and Super Admin accounts. Ask an admin to import the file, or add donors one at a time.',
                  ),
                ])
              : ListView(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 40),
                  children: [
                    Center(child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                        if (_stage == _Stage.pick) ...[
                          _templateCard(context),
                          const SizedBox(height: 14),
                          _fileCard(context),
                          if (_parsed != null) ...[const SizedBox(height: 14), _previewCard(context)],
                        ] else
                          _resultsCard(context),
                      ]),
                    )),
                  ],
                ),
        ),
      ]),
    );
  }

  Widget _header(BuildContext context, double top) => Container(
    color: context.headerBg,
    padding: EdgeInsets.fromLTRB(8, top + 10, 18, 14),
    child: Row(children: [
      IconButton(
        icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: context.textPrimary),
        onPressed: () => context.go('/donors'),
        padding: EdgeInsets.zero, constraints: const BoxConstraints(),
      ),
      const SizedBox(width: 6),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Import Donors', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.3, color: context.textPrimary)),
        Text('Add many donors at once from an Excel or CSV file',
          style: TextStyle(fontSize: 12.5, color: context.textSub, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
      ])),
    ]),
  );

  Widget _card(BuildContext context, {required String step, required String title, required List<Widget> children}) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(18), border: Border.all(color: context.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          width: 26, height: 26, alignment: Alignment.center,
          decoration: const BoxDecoration(color: _brand600, shape: BoxShape.circle),
          child: Text(step, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(title, style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: context.textPrimary))),
      ]),
      const SizedBox(height: 12),
      ...children,
    ]),
  );

  Widget _chip(BuildContext context, String text, {Color? bg, Color? fg, IconData? icon}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: bg ?? context.surface2,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: bg == null ? context.border : Colors.transparent),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      if (icon != null) ...[Icon(icon, size: 13, color: fg ?? context.textSub), const SizedBox(width: 5)],
      Flexible(child: Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg ?? context.textSub), overflow: TextOverflow.ellipsis)),
    ]),
  );

  Widget _banner(String text, {required Color bg, required Color fg, IconData icon = Icons.error_outline}) => Container(
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 18, color: fg),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: fg, height: 1.35))),
    ]),
  );

  Widget _body(BuildContext context, String text) =>
      Text(text, style: TextStyle(fontSize: 13.5, color: context.textSub, fontWeight: FontWeight.w500, height: 1.4));

  Widget _label(BuildContext context, String text) =>
      Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: context.textHint, letterSpacing: 0.3));

  // Step 1
  Widget _templateCard(BuildContext context) {
    final cats = ref.watch(donorCategoriesProvider);
    return _card(context, step: '1', title: 'Get the template', children: [
      _body(context, 'Download the template, fill one donor per row, then upload it here. Name and Mobile are required; everything else is optional. You can also upload your own sheet — columns are matched by their header names.'),
      const SizedBox(height: 12),
      Wrap(spacing: 8, runSpacing: 8, children: [
        _chip(context, 'Dates: DD/MM/YYYY', icon: Icons.event_outlined),
        _chip(context, 'Gender: Male / Female / Other', icon: Icons.wc_outlined),
        _chip(context, 'Tier: Platinum / Gold / Silver / Bronze', icon: Icons.workspace_premium_outlined),
        _chip(context, 'Same name + mobile is skipped', icon: Icons.copy_all_outlined),
      ]),
      if (cats.isNotEmpty) ...[
        const SizedBox(height: 14),
        _label(context, 'CATEGORY MUST BE ONE OF'),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final c in cats) _chip(context, c.name, bg: c.bgColor, fg: c.color),
        ]),
      ],
      const SizedBox(height: 14),
      AppButton(
        label: 'Download template (.xlsx)', icon: Icons.download_rounded,
        variant: AppButtonVariant.secondary,
        loading: _downloading, busyLabel: 'Preparing…',
        onPressed: _downloadTemplate,
      ),
    ]);
  }

  // Step 2
  Widget _fileCard(BuildContext context) {
    final p = _parsed;
    return _card(context, step: '2', title: 'Choose your file', children: [
      Row(children: [
        AppButton(
          label: p == null ? 'Choose file' : 'Choose another file', icon: Icons.upload_file_outlined,
          loading: _reading, busyLabel: 'Reading…',
          onPressed: _pickFile,
        ),
        const SizedBox(width: 12),
        Expanded(child: Text('.xlsx or .csv', style: TextStyle(fontSize: 12.5, color: context.textHint, fontWeight: FontWeight.w600))),
      ]),
      if (_fileError != null) ...[
        const SizedBox(height: 12),
        _banner(_fileError!, bg: _coral100, fg: _coral500),
      ],
      if (p != null) ...[
        const SizedBox(height: 14),
        Row(children: [
          const Icon(Icons.table_chart_outlined, size: 18, color: _green600),
          const SizedBox(width: 8),
          Expanded(child: Text(p.fileName, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: context.textPrimary), overflow: TextOverflow.ellipsis)),
          Text('${p.rows.length} row${p.rows.length == 1 ? '' : 's'}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: _green600)),
        ]),
        if (p.missingRequired.isNotEmpty) ...[
          const SizedBox(height: 12),
          _banner(
            'Missing required column${p.missingRequired.length == 1 ? '' : 's'}: ${p.missingRequired.map((c) => c.header).join(', ')}. '
            'Rename the header in your file to match, or start from the template.',
            bg: _coral100, fg: _coral500,
          ),
        ],
        const SizedBox(height: 14),
        _label(context, 'COLUMNS MATCHED'),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final c in _cols)
            if (p.matched.containsKey(c.key))
              _chip(
                context,
                p.headers[p.matched[c.key]!] == c.header ? c.header : '${c.header}  ←  ${p.headers[p.matched[c.key]!]}',
                bg: _green100, fg: _green600, icon: Icons.check_rounded,
              ),
        ]),
        if (p.ignored.isNotEmpty) ...[
          const SizedBox(height: 12),
          _label(context, 'IGNORED (NOT A DONOR FIELD)'),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [for (final h in p.ignored) _chip(context, h, icon: Icons.remove_rounded)]),
        ],
      ],
    ]);
  }

  // Step 3
  Widget _previewCard(BuildContext context) {
    final p = _parsed!;
    final preview = p.rows.take(5).toList();
    final blocked = p.missingRequired.isNotEmpty;
    String cell(_SheetRow r, String key) => (r.payload[key] ?? '').toString();
    TextStyle head = TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: context.textHint, letterSpacing: 0.3);
    TextStyle body = TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: context.textPrimary);

    return _card(context, step: '3', title: 'Check and import', children: [
      Container(
        decoration: BoxDecoration(color: context.surface2, borderRadius: BorderRadius.circular(12), border: Border.all(color: context.border)),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Row(children: [
              SizedBox(width: 40, child: Text('ROW', style: head)),
              Expanded(flex: 3, child: Text('NAME', style: head)),
              Expanded(flex: 2, child: Text('MOBILE', style: head)),
              Expanded(flex: 2, child: Text('CITY', style: head)),
            ]),
          ),
          for (final r in preview)
            Container(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              decoration: BoxDecoration(border: Border(top: BorderSide(color: context.border))),
              child: Row(children: [
                SizedBox(width: 40, child: Text('${r.rowNo}', style: body.copyWith(color: context.textHint))),
                Expanded(flex: 3, child: Text(cell(r, 'name').isEmpty ? '—' : cell(r, 'name'), style: body, overflow: TextOverflow.ellipsis)),
                Expanded(flex: 2, child: Text(cell(r, 'mobile').isEmpty ? '—' : cell(r, 'mobile'), style: body, overflow: TextOverflow.ellipsis)),
                Expanded(flex: 2, child: Text(cell(r, 'city').isEmpty ? '—' : cell(r, 'city'), style: body.copyWith(color: context.textSub), overflow: TextOverflow.ellipsis)),
              ]),
            ),
          if (p.rows.length > preview.length)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Align(alignment: Alignment.centerLeft,
                child: Text('+ ${p.rows.length - preview.length} more row${p.rows.length - preview.length == 1 ? '' : 's'}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: context.textHint))),
            ),
        ]),
      ),
      const SizedBox(height: 12),
      _body(context, 'Rows that already exist (same name and mobile) are skipped. Rows with a bad cell are reported, and the rest still go in.'),
      const SizedBox(height: 14),
      AppButton(
        label: 'Import ${p.rows.length} donor${p.rows.length == 1 ? '' : 's'}', icon: Icons.cloud_upload_outlined,
        expand: true,
        onPressed: blocked ? null : _import,
      ),
    ]);
  }

  Widget _stat(String label, int n, Color bg, Color fg) => Expanded(child: Container(
    padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(14)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('$n', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: fg, height: 1)),
      const SizedBox(height: 4),
      Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg)),
    ]),
  ));

  // Importing / done
  Widget _resultsCard(BuildContext context) {
    final total = _parsed?.rows.length ?? 0;
    if (_stage == _Stage.importing) {
      return _card(context, step: '3', title: 'Importing…', children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: total == 0 ? null : _sent / total, minHeight: 8,
            color: _brand600, backgroundColor: context.surface2,
          ),
        ),
        const SizedBox(height: 10),
        _body(context, '$_sent of $total rows sent. Keep this screen open until it finishes.'),
      ]);
    }

    final created = _results.where((r) => r.status == 'created').length;
    final skipped = _results.where((r) => r.status == 'skipped').length;
    final failed  = _results.where((r) => r.status == 'failed').length;
    final problems = _results.where((r) => r.status != 'created' || (r.note ?? '').isNotEmpty).toList()
      ..sort((a, b) => a.rowNo.compareTo(b.rowNo));

    return _card(context, step: '✓', title: 'Import finished', children: [
      Row(children: [
        _stat('Created', created, _green100, _green600),
        const SizedBox(width: 10),
        _stat('Skipped', skipped, _amber100, _amber600),
        const SizedBox(width: 10),
        _stat('Failed', failed, _coral100, _coral500),
      ]),
      if (_stopError != null) ...[
        const SizedBox(height: 12),
        _banner('The upload stopped part-way: $_stopError. Rows marked "Not sent" were never imported — fix the problem and import the problem-rows file.', bg: _coral100, fg: _coral500),
      ],
      const SizedBox(height: 14),
      if (problems.isEmpty)
        _banner('Every row was imported cleanly.', bg: _green100, fg: _green600, icon: Icons.check_circle_outline)
      else ...[
        _label(context, 'ROWS THAT NEED A LOOK (${problems.length})'),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(color: context.surface2, borderRadius: BorderRadius.circular(12), border: Border.all(color: context.border)),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: problems.length,
            separatorBuilder: (_, __) => Divider(height: 1, color: context.border),
            itemBuilder: (_, i) => _problemTile(context, problems[i]),
          ),
        ),
      ],
      const SizedBox(height: 16),
      Wrap(spacing: 10, runSpacing: 10, children: [
        if (skipped + failed > 0)
          AppButton(
            label: 'Download problem rows', icon: Icons.download_rounded,
            variant: AppButtonVariant.secondary,
            loading: _downloading, busyLabel: 'Preparing…',
            onPressed: _downloadProblems,
          ),
        AppButton(label: 'View donors', icon: Icons.people_outline, onPressed: () => context.go('/donors')),
        AppButton(label: 'Import another file', icon: Icons.refresh_rounded, variant: AppButtonVariant.ghost, onPressed: _reset),
      ]),
    ]);
  }

  Widget _problemTile(BuildContext context, _RowResult r) {
    final (pill, bg, fg) = switch (r.status) {
      'skipped' => ('Skipped', _amber100, _amber600),
      'failed'  => ('Failed', _coral100, _coral500),
      _         => ('Note', _sky100, _sky600),
    };
    final who = [r.name, r.mobile].where((s) => s.trim().isNotEmpty).join(' · ');
    final why = r.status == 'created' ? (r.note ?? '') : (r.reason ?? '');
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _chip(context, pill, bg: bg, fg: fg),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Row ${r.rowNo}${who.isEmpty ? '' : '  ·  $who'}${r.donorCode != null ? '  ·  ${r.donorCode}' : ''}',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: context.textPrimary)),
          if (why.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(why, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: context.textSub, height: 1.35)),
          ],
        ])),
      ]),
    );
  }
}
