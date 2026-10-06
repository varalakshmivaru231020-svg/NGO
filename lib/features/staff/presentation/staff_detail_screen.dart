import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/network/api_client.dart';
import '../../../core/theme/app_theme.dart';
import '../staff_model.dart';
import 'staff_salary_tab.dart';
import 'package:saksham_app/core/ui/ui.dart';

const _brand600 = Color(0xFFFF9933);
const _brand100 = Color(0xFFFFE8CC);

// ══════════════════════════════════════════════════════════════════════
// Staff profile (/staff/:id): Profile tab (read-only, Edit / Delete) and
// Salary & Reports tab (monthly records, pay slips, yearly statement).
// /staff/:id?tab=salary opens on the salary tab.
// ══════════════════════════════════════════════════════════════════════
class StaffDetailScreen extends StatefulWidget {
  const StaffDetailScreen({super.key, required this.id, this.initialTab = 0});
  final String id;
  final int initialTab;
  @override
  State<StaffDetailScreen> createState() => _StaffDetailScreenState();
}

class _StaffDetailScreenState extends State<StaffDetailScreen> with SingleTickerProviderStateMixin {
  StaffMember? _staff;
  String? _error;
  late final TabController _tabs = TabController(length: 2, vsync: this, initialIndex: widget.initialTab.clamp(0, 1));

  @override
  void initState() {
    super.initState();
    _load();
    StaffLookups.load().then((_) { if (mounted) setState(() {}); }); // status labels
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final r = await apiClient.get('/staff/${widget.id}');
      final s = StaffMember.fromJson((r['data'] as Map).cast<String, dynamic>());
      if (mounted) setState(() => _staff = s);
    } catch (e) {
      if (mounted) setState(() => _error = ApiClient.errorMessage(e, fallback: 'Could not load the staff member.'));
    }
  }

  Future<void> _delete() async {
    final s = _staff;
    if (s == null) return;
    final gone = await confirmDeleteStaff(context, id: s.id, name: s.name);
    if (gone && mounted) context.go('/staff');
  }

  Widget _header() {
    final s = _staff;
    return Container(
      padding: EdgeInsets.fromLTRB(8, MediaQuery.of(context).padding.top + 10, 16, 10),
      decoration: BoxDecoration(color: context.headerBg, border: Border(bottom: BorderSide(color: context.border))),
      child: Row(children: [
        IconButton(
          tooltip: 'Back to Staff',
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => context.go('/staff'),
        ),
        const SizedBox(width: 2),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(s?.name ?? 'Staff Profile', maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.2)),
          if (s != null)
            Text('${s.staffCode}  ·  ${s.designation}', maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12.5, color: context.textSub, fontWeight: FontWeight.w500)),
        ])),
        if (s != null) ...[
          AppButton(label: 'Delete', icon: Icons.delete_outline_rounded, variant: AppButtonVariant.secondary, onPressed: _delete),
          const SizedBox(width: 8),
          AppButton(label: 'Edit', icon: Icons.edit_outlined, onPressed: () => context.go('/staff/${s.id}/edit')),
        ],
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _staff;
    return Scaffold(
      body: Column(children: [
        _header(),
        Expanded(child: _error != null
            ? Center(child: Padding(padding: const EdgeInsets.all(16), child: ErrorState(message: _error!, onRetry: _load)))
            : s == null
                ? const Padding(padding: EdgeInsets.all(16), child: SkeletonList(rows: 6, rowHeight: 56))
                : Column(children: [
                    Container(
                      decoration: BoxDecoration(color: context.headerBg, border: Border(bottom: BorderSide(color: context.border))),
                      child: TabBar(
                        controller: _tabs,
                        isScrollable: true,
                        tabAlignment: TabAlignment.start,
                        labelColor: _brand600,
                        unselectedLabelColor: context.textSub,
                        indicatorColor: _brand600,
                        labelStyle: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                        tabs: const [
                          Tab(icon: Icon(Icons.badge_outlined, size: 18), iconMargin: EdgeInsets.zero, height: 44, text: 'Profile'),
                          Tab(icon: Icon(Icons.receipt_long_outlined, size: 18), iconMargin: EdgeInsets.zero, height: 44, text: 'Salary & Reports'),
                        ],
                      ),
                    ),
                    Expanded(child: TabBarView(controller: _tabs, children: [
                      RefreshIndicator(
                        color: _brand600,
                        onRefresh: _load,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                          child: Align(alignment: Alignment.topCenter, child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 880),
                            child: _body(s),
                          )),
                        ),
                      ),
                      StaffSalaryTab(staff: s),
                    ])),
                  ])),
      ]),
    );
  }

  Widget _body(StaffMember s) {
    final statusCol = staffStatusColor(s.status);
    final photo = s.photoBytes;
    String v(String x) => x.isEmpty ? '—' : x;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // ── summary card ─────────────────────────────────────────────
      _Card(child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(children: [
          Container(
            width: 64, height: 64, clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(color: _brand100, borderRadius: BorderRadius.circular(14)),
            child: photo != null
                ? Image.memory(photo, fit: BoxFit.cover)
                : Center(child: Text(s.name.isNotEmpty ? s.name[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: _brand600))),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.name, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: context.textPrimary)),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: [
              _Tag(s.staffCode, color: context.textSub),
              _Tag(s.designation, color: _brand600),
              _Tag(staffStatusLabel(s.status), color: statusCol),
              _Tag(staffEmploymentLabel(s.employmentType), color: context.textSub),
            ]),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(staffInr(s.gross), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: _brand600)),
            Text('gross / month', style: TextStyle(fontSize: 11.5, color: context.textHint)),
          ]),
        ]),
      )),
      const SizedBox(height: 14),

      _Section(title: 'Personal Details', items: [
        ('Gender', staffGenderLabel(s.gender)),
        ('Date of Birth', s.dob == null ? '—' : '${staffDate(s.dob)}  (${staffAge(s.dob)} yrs)'),
        ('Mobile', v(s.mobile)),
        ('WhatsApp', v(s.whatsapp)),
        ('Email', v(s.email)),
        ('Address', v(s.address)),
        ('Aadhaar', v(s.aadhaarNumber)),
        ('PAN', v(s.panNumber)),
      ]),
      const SizedBox(height: 14),

      _Section(title: 'Employment', items: [
        ('Designation', v(s.designation)),
        ('Centre / Office', v(s.centreName)),
        ('Joining Date', s.joiningDate == null ? '—' : staffDate(s.joiningDate)),
        ('Employment Type', staffEmploymentLabel(s.employmentType)),
        ('Status', staffStatusLabel(s.status)),
        ('Work Timings', v(s.workTimings)),
      ]),
      const SizedBox(height: 14),

      _Section(title: 'Salary (per month)', items: [
        ('Basic Salary', staffInr(s.basicSalary)),
        ('HRA', staffInr(s.hra)),
        ('Allowances', staffInr(s.allowances)),
        ('Gross', staffInr(s.gross)),
        ('PF Applicable', s.pfApplicable ? 'Yes' : 'No'),
      ]),
      const SizedBox(height: 14),

      _Section(title: 'Bank & Emergency Contact', items: [
        ('Bank', v(s.bankName)),
        ('Account Number', v(s.accountNumber)),
        ('IFSC', v(s.ifscCode)),
        ('Emergency Contact', v([s.emergencyContactName, s.emergencyContactPhone].where((x) => x.isNotEmpty).join('  ·  '))),
      ]),
      const SizedBox(height: 14),

      // ── children ────────────────────────────────────────────────
      _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const _CardTitle('Children / Family Details'),
        Divider(height: 1, color: context.border),
        if (s.children.isEmpty)
          Padding(padding: const EdgeInsets.all(16),
              child: Text('No children recorded.', style: TextStyle(fontSize: 13, color: context.textHint)))
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: DataTable(
              headingRowHeight: 38, dataRowMinHeight: 40, dataRowMaxHeight: 48, horizontalMargin: 12,
              headingTextStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.textHint),
              dataTextStyle: TextStyle(fontSize: 13.5, color: context.textPrimary),
              columns: const [
                DataColumn(label: Text('Name')), DataColumn(label: Text('Relation')),
                DataColumn(label: Text('Age')), DataColumn(label: Text('School / Class')),
              ],
              rows: [
                for (final c in s.children)
                  DataRow(cells: [
                    DataCell(Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                    DataCell(Text(v(c.relation))),
                    DataCell(Text(c.dob == null ? '—' : '${staffAge(c.dob)} yrs')),
                    DataCell(Text(v(c.school))),
                  ]),
              ],
            ),
          ),
      ])),

      if (s.notes.isNotEmpty) ...[
        const SizedBox(height: 14),
        _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const _CardTitle('Notes'),
          Divider(height: 1, color: context.border),
          Padding(padding: const EdgeInsets.all(16),
              child: Text(s.notes, style: TextStyle(fontSize: 13.5, height: 1.45, color: context.textPrimary))),
        ])),
      ],
    ]);
  }
}

// ── widgets ───────────────────────────────────────────────────────────
class _Card extends StatelessWidget {
  const _Card({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    decoration: BoxDecoration(color: context.cardBg, borderRadius: BorderRadius.circular(12), border: Border.all(color: context.border)),
    clipBehavior: Clip.antiAlias,
    child: child,
  );
}

class _CardTitle extends StatelessWidget {
  const _CardTitle(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
    child: Text(text, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: context.textPrimary)),
  );
}

// Label/value grid: two columns on wide screens, one on phones.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.items});
  final String title;
  final List<(String, String)> items;
  @override
  Widget build(BuildContext context) => _Card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _CardTitle(title),
    Divider(height: 1, color: context.border),
    Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      child: LayoutBuilder(builder: (_, c) {
        final w = c.maxWidth >= 520 ? (c.maxWidth - 16) / 2 : c.maxWidth;
        return Wrap(spacing: 16, runSpacing: 12, children: [
          for (final (label, value) in items)
            SizedBox(width: w, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: context.textHint)),
              const SizedBox(height: 2),
              SelectableText(value, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: context.textPrimary)),
            ])),
        ]);
      }),
    ),
  ]));
}

class _Tag extends StatelessWidget {
  const _Tag(this.text, {required this.color});
  final String text;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
    child: Text(text, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: color)),
  );
}
