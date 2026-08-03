import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// ── PDF single-student report ─────────────────────────────────────────────
// Student detail → download sheet: the child's full profile on one statement —
// org header, photo, personal/family/education/identity sections, sponsorship,
// achievements table, and the statutory PAN/12AA/80G footer. Matches the look
// of the donation statement and expense report.

const _statutoryLine =
    'Trust PAN: AATTS6672D  |  12AA Registration: AATTS6672D25BL01  |  80G Certification: AATTS6672D25BL02';
const _orgName = 'Sri Krishnashraya Educational Trust';
const _orgAddress = 'No. 50, 2nd cross, Ripco Shanthinikethan layout, near SJES College, Medahalli, '
    'Virgo Nagar Post, Bangalore – 560049. Mob: 9986064411, 9620794141. '
    'Email: aakrishnashraya@gmail.com Website: www.krishnashraya.in';

class StudentAchievementRow {
  const StudentAchievementRow({required this.date, required this.title, required this.category});
  final String date, title, category;
}

const _months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

// ISO (or anything DateTime.parse understands) → "05 Mar 2015"; raw text
// passes through untouched so already-formatted dates keep working.
String _d(String raw) {
  final dt = DateTime.tryParse(raw);
  if (dt == null) return raw;
  return '${dt.day.toString().padLeft(2, '0')} ${_months[dt.month - 1]} ${dt.year}';
}

Future<Uint8List> buildStudentReportPdf({
  required Map<String, String> data,
  Uint8List? photo,
  List<StudentAchievementRow> achievements = const [],
}) async {
  final doc = pw.Document();
  final logoData = await rootBundle.load('assets/images/sket-logo.png');
  final logo = pw.MemoryImage(logoData.buffer.asUint8List());
  final photoImage = (photo != null && photo.isNotEmpty) ? pw.MemoryImage(photo) : null;

  final orange   = PdfColor.fromInt(0xFFF97316);
  final grey     = PdfColor.fromInt(0xFF6B7280);
  final dark     = PdfColor.fromInt(0xFF1F2937);
  final bgLight  = PdfColor.fromInt(0xFFF8FAFC);
  final bgStripe = PdfColor.fromInt(0xFFF3F4F6);
  final white    = PdfColor.fromInt(0xFFFFFFFF);

  final now = DateTime.now();
  final generatedOn = '${now.day.toString().padLeft(2, '0')} ${_months[now.month - 1]} ${now.year}';

  String v(String key) => (data[key] ?? '').trim();
  bool has(String key) {
    final s = v(key);
    return s.isNotEmpty && s != '—';
  }

  pw.Widget sectionBar(String title) => pw.Container(
    width: double.infinity, color: orange,
    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    child: pw.Text(title, textAlign: pw.TextAlign.center,
        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: white, letterSpacing: 0.3)),
  );

  // Two label/value pairs per row — pass an empty label for a blank cell.
  pw.TableRow pairRow(String l1, String v1, String l2, String v2, {bool stripe = false}) => pw.TableRow(
    decoration: stripe ? pw.BoxDecoration(color: bgStripe) : null,
    children: [
      pw.Padding(padding: const pw.EdgeInsets.fromLTRB(10, 7, 4, 7),
          child: pw.Text(l1, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: grey))),
      pw.Padding(padding: const pw.EdgeInsets.fromLTRB(4, 7, 10, 7),
          child: pw.Text(v1.isEmpty ? '—' : v1, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: dark))),
      pw.Padding(padding: const pw.EdgeInsets.fromLTRB(10, 7, 4, 7),
          child: pw.Text(l2, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: grey))),
      pw.Padding(padding: const pw.EdgeInsets.fromLTRB(4, 7, 10, 7),
          child: pw.Text(l2.isEmpty ? '' : (v2.isEmpty ? '—' : v2), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: dark))),
    ],
  );

  // Build a striped 2-pairs-per-row table out of only the non-empty fields.
  pw.Widget pairTable(List<(String, String)> fields) {
    final present = fields.where((f) => f.$2.trim().isNotEmpty && f.$2.trim() != '—').toList();
    if (present.isEmpty) {
      return pw.Padding(padding: const pw.EdgeInsets.all(10),
          child: pw.Text('Not recorded.', style: pw.TextStyle(fontSize: 8.5, color: grey)));
    }
    final rows = <pw.TableRow>[];
    for (var i = 0; i < present.length; i += 2) {
      final a = present[i];
      final b = i + 1 < present.length ? present[i + 1] : ('', '');
      rows.add(pairRow(a.$1, a.$2, b.$1, b.$2, stripe: (i ~/ 2).isOdd));
    }
    return pw.Table(columnWidths: const {
      0: pw.FlexColumnWidth(1.3), 1: pw.FlexColumnWidth(2.0),
      2: pw.FlexColumnWidth(1.3), 3: pw.FlexColumnWidth(2.0),
    }, children: rows);
  }

  pw.Widget th(String label, {pw.TextAlign align = pw.TextAlign.left}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    child: pw.Text(label, textAlign: align,
        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: dark, letterSpacing: 0.2)),
  );

  pw.Widget td(String text, {bool bold = false}) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    child: pw.Text(text, style: pw.TextStyle(fontSize: 8.5, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal, color: dark)),
  );

  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(36, 30, 36, 30),
    build: (ctx) => [pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      // Header: logo + org lockup (left) | title (right)
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Image(logo, height: 58),
          pw.SizedBox(height: 6),
          pw.Text(_orgName, style: pw.TextStyle(fontSize: 10, color: dark)),
          pw.Text('(Registered Charitable Trust)', style: pw.TextStyle(fontSize: 8.5, color: grey)),
        ]),
        pw.Expanded(child: pw.Align(
          alignment: pw.Alignment.topRight,
          child: pw.Text('STUDENT REPORT',
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: dark, letterSpacing: 0.2,
                  decoration: pw.TextDecoration.underline, decorationColor: dark, decorationThickness: 1.2)),
        )),
      ]),
      pw.SizedBox(height: 14),

      pw.Container(
        width: double.infinity, color: orange,
        padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: pw.Text(_orgAddress, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: white)),
      ),
      pw.SizedBox(height: 16),

      // ── Identity strip: photo + headline details ───────────────────
      pw.Container(
        width: double.infinity,
        decoration: pw.BoxDecoration(color: bgLight, border: pw.Border.all(color: bgStripe)),
        padding: const pw.EdgeInsets.all(12),
        child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          if (photoImage != null) ...[
            pw.ClipRRect(
              horizontalRadius: 8, verticalRadius: 8,
              child: pw.Image(photoImage, width: 74, height: 74, fit: pw.BoxFit.cover),
            ),
            pw.SizedBox(width: 14),
          ],
          pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(v('name'), style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: dark)),
            pw.SizedBox(height: 4),
            pw.Text('Child ID: ${v('childId')}   |   ${v('gender')}   |   ${v('age')}',
                style: pw.TextStyle(fontSize: 9.5, color: grey)),
            pw.SizedBox(height: 3),
            pw.Text('Centre: ${v('centre')}   |   Status: ${v('status')}',
                style: pw.TextStyle(fontSize: 9.5, color: grey)),
            pw.SizedBox(height: 3),
            pw.Text('Generated on $generatedOn', style: pw.TextStyle(fontSize: 8.5, color: grey)),
          ])),
        ]),
      ),
      pw.SizedBox(height: 16),

      // ── PERSONAL DETAILS ───────────────────────────────────────────
      sectionBar('PERSONAL DETAILS'),
      pairTable([
        ('Date of Birth', has('dob') ? _d(v('dob')) : ''),
        ('Age', v('age')),
        ('Gender', v('gender')),
        ('Category', v('category')),
        ('Class', v('class')),
        ('School / College', has('institution') ? v('institution') : v('school')),
        ('Admission Date', has('admDate') ? _d(v('admDate')) : ''),
        ('Caste', v('caste')),
        ('Sub-caste', v('subCaste')),
        ('Address', v('address')),
      ]),
      pw.SizedBox(height: 14),

      // ── FAMILY DETAILS ─────────────────────────────────────────────
      sectionBar('FAMILY DETAILS'),
      pairTable([
        ("Father's Name", v('father')),
        ("Mother's Name", v('mother')),
        ('Guardian', v('guardian')),
        ('Relation', v('relation')),
        ('Contact Number', v('mobile')),
        ('Siblings', v('siblingNames')),
        ('Family Notes', v('familyNotes')),
      ]),
      pw.SizedBox(height: 14),

      // ── EDUCATION DETAILS ──────────────────────────────────────────
      sectionBar('EDUCATION DETAILS'),
      pairTable([
        ('Admission No.', v('admNo')),
        ('Academic Year', v('acadYear')),
        ('Joining Date', has('joiningDate') ? _d(v('joiningDate')) : ''),
        ('Section', v('section')),
        ('Permanence', v('permanence')),
        ('Student Type', v('studentType')),
        ('Remarks', v('eduRemarks')),
      ]),
      pw.SizedBox(height: 14),

      // ── IDENTITY & GOVERNMENT IDS ──────────────────────────────────
      sectionBar('IDENTITY & GOVERNMENT IDS'),
      pairTable([
        ('Aadhaar Number', v('aadhaar')),
        ('SAT Number', v('sat')),
        ('PEN Number', v('penNumber')),
        ('CWC Number', v('cwcNumber')),
        ('ABHA Number', v('abhaNumber')),
        ('Ration Card No.', v('rationCardNumber')),
        ('Mission Vatsalya No.', v('missionVatsalyaNumber')),
      ]),
      pw.SizedBox(height: 14),

      // ── HEALTH & WELFARE ───────────────────────────────────────────
      sectionBar('HEALTH & WELFARE'),
      pairTable([
        ('Height', v('height')),
        ('Weight', v('weight')),
        ('Medical History', v('medHistory')),
        ('Bank Account Details', v('bankAccountDetails')),
        ('Income Certificate (Rs.)', v('incomeCertificateAmount')),
        ('Income Cert. RD No.', v('incomeCertificateRdNumber')),
      ]),
      pw.SizedBox(height: 14),

      // ── SPONSORSHIP ────────────────────────────────────────────────
      sectionBar('SPONSORSHIP'),
      pairTable([
        ('Sponsor', v('sponsor')),
        ('Sponsorship', v('sponsorshipAmt')),
      ]),
      pw.SizedBox(height: 14),

      // ── ACHIEVEMENTS ───────────────────────────────────────────────
      sectionBar('ACHIEVEMENTS'),
      if (achievements.isEmpty)
        pw.Padding(padding: const pw.EdgeInsets.all(10),
            child: pw.Text('No achievements recorded yet.', style: pw.TextStyle(fontSize: 8.5, color: grey)))
      else
        pw.Table(
          columnWidths: const {0: pw.FlexColumnWidth(0.6), 1: pw.FlexColumnWidth(1.4), 2: pw.FlexColumnWidth(3.4), 3: pw.FlexColumnWidth(1.6)},
          children: [
            pw.TableRow(decoration: pw.BoxDecoration(color: bgStripe), children: [
              th('Sl.No'), th('Date'), th('Achievement'), th('Category'),
            ]),
            ...achievements.asMap().entries.map((e) => pw.TableRow(
              decoration: pw.BoxDecoration(color: e.key.isOdd ? bgLight : white),
              children: [
                td('${e.key + 1}'), td(_d(e.value.date)), td(e.value.title, bold: true), td(e.value.category),
              ],
            )),
          ],
        ),
      pw.SizedBox(height: 20),

      // ── Statutory footer ───────────────────────────────────────────
      sectionBar('STATUTORY REGISTRATION DETAILS'),
      pw.Container(
        width: double.infinity,
        color: bgStripe,
        padding: const pw.EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(_statutoryLine, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: dark)),
          pw.SizedBox(height: 5),
          pw.Text('This is an electronically generated student profile report for internal and sponsor records. No signature is required.',
              style: pw.TextStyle(fontSize: 7.5, color: grey)),
        ]),
      ),
    ])],
  ));
  return doc.save();
}
