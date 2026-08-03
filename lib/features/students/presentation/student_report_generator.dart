import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// ── Child Profile Report PDF ──────────────────────────────────────────────
// Student detail → download sheet. Matches the trust's printed "CHILD
// PROFILE REPORT" template: maroon page header with the org lockup and the
// child id/status, name + registration line with the profile photo in a
// bordered box top-right, numbered maroon section bars with two-column
// label-over-value cells, signature lines, and an address/page footer on
// every page.

const _orgName = 'SRI KRISHNASHRAYA EDUCATIONAL TRUST';
const _orgCity = 'Bengaluru, Karnataka, India';
const _orgFooter =
    'Sri Krishnashraya Educational Trust  •  No. 50, 2nd cross, Ripco Shanthinikethan layout, '
    'Near SJES College, Medahalli, Virgo Nagar Post, Bengaluru – 560049';

class StudentAchievementRow {
  const StudentAchievementRow({required this.date, required this.title, required this.category});
  final String date, title, category;
}

// ISO (or parseable) date → DD/MM/YYYY, matching the printed template.
String _d(String raw) {
  final dt = DateTime.tryParse(raw);
  if (dt == null) return raw;
  return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
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

  final maroon    = PdfColor.fromInt(0xFF8E2438);
  final gold      = PdfColor.fromInt(0xFFC9A227);
  final dark      = PdfColor.fromInt(0xFF2B2B2B);
  final grey      = PdfColor.fromInt(0xFF7A7A7A);
  final lightLine = PdfColor.fromInt(0xFFE3E3E3);
  final cream     = PdfColor.fromInt(0xFFFBF7EF);
  final bgSoft    = PdfColor.fromInt(0xFFF6F4F0);
  final white     = PdfColor.fromInt(0xFFFFFFFF);

  String v(String key) => (data[key] ?? '').trim();
  String show(String key) {
    final s = v(key);
    return (s.isEmpty || s == '—') ? '—' : s;
  }

  // Height/weight combined like "155 cm / 44 kg".
  final hw = [
    if (v('height').isNotEmpty && v('height') != '—') v('height'),
    if (v('weight').isNotEmpty && v('weight') != '—') v('weight'),
  ].join(' / ');

  final statusText = show('status');
  const eduStatusMap = {
    'Active': 'Currently enrolled',
    'Graduated': 'Completed / Graduated',
    'Relieved': 'Relieved',
    'Drop out': 'Dropped out',
  };

  final regNo = v('cwcNumber').isNotEmpty ? v('cwcNumber') : v('childId');
  final dobLine = v('dob').isNotEmpty ? '${_d(v('dob'))}${v('age').isNotEmpty && v('age') != '—' ? ' (${v('age')})' : ''}' : '—';

  // ── building blocks ────────────────────────────────────────────────────
  pw.Widget sectionBar(String title) => pw.Container(
    width: double.infinity, color: maroon,
    margin: const pw.EdgeInsets.only(top: 12),
    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    child: pw.Text(title,
        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: white, letterSpacing: 0.3)),
  );

  pw.Widget cell(String label, String value) => pw.Padding(
    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text(label.toUpperCase(),
          style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: grey, letterSpacing: 0.5)),
      pw.SizedBox(height: 3),
      pw.Text(value.isEmpty ? '—' : value, style: pw.TextStyle(fontSize: 9.5, color: dark)),
    ]),
  );

  pw.Widget pairRow(String l1, String v1, String l2, String v2, {bool last = false}) => pw.Container(
    decoration: last ? null : pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: lightLine, width: 0.6))),
    child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Expanded(child: cell(l1, v1)),
      pw.Expanded(child: l2.isEmpty ? pw.SizedBox() : cell(l2, v2)),
    ]),
  );

  pw.Widget fullCell(String label, String value, {bool shaded = false}) => pw.Container(
    width: double.infinity,
    color: shaded ? bgSoft : null,
    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
      pw.Text(label.toUpperCase(),
          style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: grey, letterSpacing: 0.5)),
      pw.SizedBox(height: 4),
      pw.Text(value.isEmpty ? '—' : value, style: pw.TextStyle(fontSize: 9.5, color: dark, height: 1.4)),
    ]),
  );

  pw.Widget sectionBox(List<pw.Widget> children) => pw.Container(
    decoration: pw.BoxDecoration(border: pw.Border.all(color: lightLine, width: 0.6)),
    child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: children),
  );

  // ── page header / footer (every page) ──────────────────────────────────
  pw.Widget pageHeader(pw.Context ctx) => pw.Column(children: [
    pw.Container(
      width: double.infinity, color: maroon,
      padding: const pw.EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
        pw.Container(
          color: white, padding: const pw.EdgeInsets.all(3),
          child: pw.Image(logo, height: 34),
        ),
        pw.SizedBox(width: 10),
        pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(_orgName, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: white)),
          pw.SizedBox(height: 2),
          pw.Text(_orgCity, style: pw.TextStyle(fontSize: 8, color: PdfColor.fromInt(0xFFEED9DD))),
        ])),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
          pw.Text('CHILD PROFILE REPORT',
              style: pw.TextStyle(fontSize: 10.5, fontWeight: pw.FontWeight.bold, color: white, letterSpacing: 0.4)),
          pw.SizedBox(height: 2),
          pw.Text('Child ID: ${show('childId')}   |   Status: $statusText',
              style: pw.TextStyle(fontSize: 7.5, color: PdfColor.fromInt(0xFFEED9DD))),
        ]),
      ]),
    ),
    pw.Container(width: double.infinity, height: 2.5, color: gold),
    pw.SizedBox(height: 14),
  ]);

  pw.Widget pageFooter(pw.Context ctx) => pw.Column(children: [
    pw.Divider(color: lightLine, thickness: 0.6, height: 10),
    pw.Row(children: [
      pw.Expanded(child: pw.Text(_orgFooter, style: pw.TextStyle(fontSize: 6.5, color: grey))),
      pw.Text('Page ${ctx.pageNumber}', style: pw.TextStyle(fontSize: 7, color: grey)),
    ]),
  ]);

  // ── document ───────────────────────────────────────────────────────────
  doc.addPage(pw.MultiPage(
    pageFormat: PdfPageFormat.a4,
    margin: const pw.EdgeInsets.fromLTRB(26, 20, 26, 22),
    header: pageHeader,
    footer: pageFooter,
    build: (ctx) => [
      // Name + registration line, photo box top-right.
      pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Expanded(child: pw.Padding(
          padding: const pw.EdgeInsets.only(top: 8),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text(v('name').toUpperCase(),
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: maroon, letterSpacing: 0.3)),
            pw.SizedBox(height: 5),
            pw.Text(
              'Registration No: $regNo | Centre: ${show('centre')} | DOB: $dobLine | Gender: ${show('gender')}',
              style: pw.TextStyle(fontSize: 8.5, color: dark),
            ),
            if (v('category').isNotEmpty && v('category') != '—') ...[
              pw.SizedBox(height: 4),
              pw.Text('Category: ${v('category')}', style: pw.TextStyle(fontSize: 8.5, color: dark)),
            ],
          ]),
        )),
        pw.SizedBox(width: 12),
        pw.Container(
          width: 82, height: 100,
          decoration: pw.BoxDecoration(color: cream, border: pw.Border.all(color: gold, width: 0.8)),
          child: photoImage != null
              ? pw.ClipRect(child: pw.Image(photoImage, fit: pw.BoxFit.cover, width: 82, height: 100))
              : pw.Center(child: pw.Text('PHOTO', style: pw.TextStyle(fontSize: 8, color: grey, letterSpacing: 1))),
        ),
      ]),
      pw.SizedBox(height: 4),

      // 1. BASIC PROFILE & CENTRE DETAILS
      sectionBar('1. BASIC PROFILE & CENTRE DETAILS'),
      sectionBox([
        pairRow('Child ID', show('childId'), 'Status', statusText),
        pairRow('Centre', show('centre'), 'Date of Admission', v('admDate').isNotEmpty ? _d(v('admDate')) : '—'),
        pairRow('Date of Birth', v('dob').isNotEmpty ? _d(v('dob')) : '—', 'Age', show('age')),
        pairRow('Gender', show('gender'), 'Height / Weight', hw.isEmpty ? '—' : hw),
        pairRow('Category', show('category'), 'Sponsor', show('sponsor'), last: true),
      ]),

      // 2. FAMILY & BACKGROUND INFORMATION
      sectionBar('2. FAMILY & BACKGROUND INFORMATION'),
      sectionBox([
        pairRow("Father's Name", show('father'), "Mother's Name", show('mother')),
        pairRow('Guardian', show('guardian'), 'Contact Number', show('mobile')),
        pairRow('SAT No.', show('sat'), 'Sibling(s)', show('siblingNames'), last: true),
        fullCell('Address', show('address')),
        fullCell('Family Background / Narrative', show('familyNotes'), shaded: true),
      ]),

      // 3. GOVERNMENT IDS & DEMOGRAPHICS
      sectionBar('3. GOVERNMENT IDS & DEMOGRAPHICS'),
      sectionBox([
        pairRow('PEN Number', show('penNumber'), 'CWC Number', show('cwcNumber')),
        pairRow('ABHA Card Number', show('abhaNumber'), 'Ration Card Number', show('rationCardNumber')),
        pairRow('Mission Vatsalya Number', show('missionVatsalyaNumber'), 'Aadhaar Number', show('aadhaar')),
        pairRow('Caste', show('caste'), 'Sub-caste', show('subCaste'), last: true),
      ]),

      // 4. HEALTH & MEDICAL HISTORY
      sectionBar('4. HEALTH & MEDICAL HISTORY'),
      sectionBox([
        pairRow('Medical Status', show('medHistory'), 'Growth Tracking',
            v('growthLine').isNotEmpty ? v('growthLine') : (hw.isEmpty ? '—' : hw), last: true),
      ]),
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 5),
        child: pw.Text(
          'Associated media/files: medical reports, ID scans and family photographs are attached as linked '
          'documents in the app record and are not reproduced on this printed sheet.',
          style: pw.TextStyle(fontSize: 7.5, color: grey),
        ),
      ),

      // 5. EDUCATION DETAILS
      sectionBar('5. EDUCATION DETAILS'),
      sectionBox([
        pairRow('Academic Year', show('acadYear'), 'Current Class / Grade', show('class')),
        pairRow('Section', show('section'), 'School / Institution',
            v('institution').isNotEmpty && v('institution') != '—' ? v('institution') : show('school')),
        pairRow('Admission No.', show('admNo'), 'Student Type', show('studentType')),
        pairRow('Education Status', eduStatusMap[statusText] ?? statusText, 'Remarks', show('eduRemarks'), last: true),
      ]),

      // 6. WELFARE & FINANCIAL
      sectionBar('6. WELFARE & FINANCIAL'),
      sectionBox([
        pairRow('Income Certificate (Rs.)', show('incomeCertificateAmount'),
            'Income Certificate RD No.', show('incomeCertificateRdNumber'), last: true),
        fullCell('Bank Account Details', show('bankAccountDetails')),
      ]),

      // 7. ACHIEVEMENTS
      sectionBar('7. ACHIEVEMENTS'),
      sectionBox([
        pw.Padding(
          padding: const pw.EdgeInsets.fromLTRB(10, 7, 10, 5),
          child: pw.Text('ARTS / SPORTS / ACADEMICS / COMMUNITY / LEADERSHIP / OTHER',
              style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: grey, letterSpacing: 0.5)),
        ),
        if (achievements.isEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(10, 0, 10, 8),
            child: pw.Text('—', style: pw.TextStyle(fontSize: 9.5, color: dark)),
          )
        else
          pw.Padding(
            padding: const pw.EdgeInsets.fromLTRB(10, 0, 10, 8),
            child: pw.Table(
              columnWidths: const {0: pw.FlexColumnWidth(0.5), 1: pw.FlexColumnWidth(1.2), 2: pw.FlexColumnWidth(3.2), 3: pw.FlexColumnWidth(1.4)},
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: lightLine, width: 0.6))),
                  children: [
                    for (final h in ['Sl.', 'Date', 'Achievement', 'Category'])
                      pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 4),
                          child: pw.Text(h, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: grey))),
                  ],
                ),
                ...achievements.asMap().entries.map((e) => pw.TableRow(children: [
                  for (final t in ['${e.key + 1}', _d(e.value.date), e.value.title, e.value.category])
                    pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 4),
                        child: pw.Text(t, style: pw.TextStyle(fontSize: 8.5, color: dark))),
                ])),
              ],
            ),
          ),
      ]),

      // Signatures
      pw.SizedBox(height: 34),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Container(width: 170, height: 0.8, color: dark),
          pw.SizedBox(height: 4),
          pw.Text('Caretaker / Centre In-charge', style: pw.TextStyle(fontSize: 8.5, color: dark)),
        ]),
        pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Container(width: 170, height: 0.8, color: dark),
          pw.SizedBox(height: 4),
          pw.Text('Authorised Signatory, SKET', style: pw.TextStyle(fontSize: 8.5, color: dark)),
        ]),
      ]),
    ],
  ));
  return doc.save();
}
