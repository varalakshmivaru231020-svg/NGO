import 'package:flutter/material.dart';
import '../../../core/auth/role_auth.dart';

const _brand600 = Color(0xFF0E8C76);
const _brand700 = Color(0xFF0B6E5D);
const _brand100 = Color(0xFFD6F3EC);
const _coral500 = Color(0xFFF2685E);
const _violet500 = Color(0xFF7C6CF0);
const _amber600 = Color(0xFFE0921A);
const _sky500 = Color(0xFF2D9CDB);
const _onSurface1 = Color(0xFF15211E);
const _onSurface2 = Color(0xFF5A6B67);
const _onSurface3 = Color(0xFF93A29F);
const _border = Color(0xFFE5EBE9);
const _surface2 = Color(0xFFF4F7F6);

// ── Module display info ───────────────────────────────────────────────
class _Mod {
  const _Mod(this.key, this.label, this.icon, this.color);
  final String key, label;
  final IconData icon;
  final Color color;
}

const _kMods = [
  _Mod('donors',      'Donors',            Icons.people_outlined,         _brand600),
  _Mod('donations',   'Donations',         Icons.receipt_long_outlined,   _amber600),
  _Mod('students',    'Children/Students', Icons.school_outlined,         _violet500),
  _Mod('offices',     'Offices',           Icons.business_outlined,       _sky500),
  _Mod('reports',     'Reports',           Icons.bar_chart_rounded,       Color(0xFF14A98C)),
  _Mod('reminders',   'Reminders',         Icons.cake_outlined,           _coral500),
  _Mod('tracker',     'Donation Tracker',  Icons.track_changes_outlined,  _amber600),
  _Mod('payments',    'Payment Links',     Icons.link_rounded,            _violet500),
  _Mod('achievements','Achievements',      Icons.emoji_events_outlined,   _amber600),
];

_Mod _modInfo(String key) =>
    _kMods.firstWhere((m) => m.key == key, orElse: () => _Mod(key, key, Icons.circle, _onSurface3));

// ══════════════════════════════════════════════════════════════════════
class RolesScreen extends StatefulWidget {
  const RolesScreen({super.key});
  @override
  State<RolesScreen> createState() => _RolesScreenState();
}

class _RolesScreenState extends State<RolesScreen> {
  void _openCreate() => _openSheet(context, null, () => setState(() {}));
  void _openEdit(AppRole r) => _openSheet(context, r, () => setState(() {}));

  void _delete(AppRole r) {
    setState(() => appRoles.remove(r));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('Role "${r.name}" deleted'),
      backgroundColor: _coral500,
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: const Color(0xFFF2F5F4),
      body: Column(children: [
        // ── Header ──────────────────────────────────────────────────
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(colors: [Color(0xFF0B6E5D), _brand600],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
          padding: EdgeInsets.fromLTRB(16, top + 14, 16, 20),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Roles & Access', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
              Text('${appRoles.length} role${appRoles.length == 1 ? '' : 's'} · each role has its own login',
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ])),
            GestureDetector(
              onTap: _openCreate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.4))),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.add_rounded, color: Colors.white, size: 18),
                  SizedBox(width: 5),
                  Text('Create Role', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                ]),
              ),
            ),
          ]),
        ),

        // ── Info banner ──────────────────────────────────────────────
        Container(
          margin: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(color: _brand100, borderRadius: BorderRadius.circular(12)),
          child: const Row(children: [
            Icon(Icons.info_outline_rounded, color: _brand600, size: 18),
            SizedBox(width: 10),
            Expanded(child: Text(
              'Create a role with a name, password, and select which modules they can manage. They log in using the role name and password.',
              style: TextStyle(fontSize: 12.5, color: _brand700, fontWeight: FontWeight.w500),
            )),
          ]),
        ),

        // ── Role cards ───────────────────────────────────────────────
        Expanded(
          child: appRoles.isEmpty
              ? const Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.manage_accounts_outlined, size: 64, color: _onSurface3),
                  SizedBox(height: 12),
                  Text('No roles yet', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _onSurface2)),
                  SizedBox(height: 4),
                  Text('Tap "Create Role" to add one', style: TextStyle(fontSize: 13, color: _onSurface3)),
                ]))
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 40),
                  itemCount: appRoles.length,
                  itemBuilder: (_, i) => _RoleCard(
                    role: appRoles[i],
                    onEdit: () => _openEdit(appRoles[i]),
                    onDelete: () => _delete(appRoles[i]),
                  ),
                ),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
// ROLE CARD
// ══════════════════════════════════════════════════════════════════════
class _RoleCard extends StatelessWidget {
  const _RoleCard({required this.role, required this.onEdit, required this.onDelete});
  final AppRole role;
  final VoidCallback onEdit, onDelete;

  @override
  Widget build(BuildContext context) {
    final initials = role.name.trim().split(' ').where((w) => w.isNotEmpty).map((w) => w[0].toUpperCase()).take(2).join();
    final colors = [_brand600, _violet500, _amber600, _sky500, _coral500];
    int h = 0;
    for (final c in role.name.codeUnits) { h = ((h * 31) + c) & 0xFFFFFFFF; }
    final avatarColor = colors[h % colors.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(color: avatarColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
              child: Center(child: Text(initials, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: avatarColor))),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(role.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: _onSurface1)),
              const SizedBox(height: 2),
              Row(children: [
                const Icon(Icons.lock_outline_rounded, size: 12, color: _onSurface3),
                const SizedBox(width: 4),
                Text('Password: ${role.password}', style: const TextStyle(fontSize: 12, color: _onSurface3, fontWeight: FontWeight.w500)),
              ]),
            ])),
            IconButton(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 18, color: _brand600),
              style: IconButton.styleFrom(backgroundColor: _brand100, fixedSize: const Size(34, 34), padding: EdgeInsets.zero),
            ),
            const SizedBox(width: 6),
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: _coral500),
              style: IconButton.styleFrom(backgroundColor: const Color(0xFFFFF0EE), fixedSize: const Size(34, 34), padding: EdgeInsets.zero),
            ),
          ]),
        ),
        const Divider(height: 1, color: _border),
        // Login info row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(color: _surface2, borderRadius: BorderRadius.circular(10)),
            child: Row(children: [
              const Icon(Icons.login_rounded, size: 14, color: _onSurface3),
              const SizedBox(width: 8),
              Text('Login: ', style: const TextStyle(fontSize: 12, color: _onSurface3)),
              Expanded(child: Text(
                '"${role.name}"  /  "${role.password}"',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _onSurface2),
                overflow: TextOverflow.ellipsis,
              )),
            ]),
          ),
        ),
        const Divider(height: 1, color: _border),
        // Module chips
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
          child: role.modules.isEmpty
              ? const Text('No modules assigned — this role cannot access anything',
                  style: TextStyle(fontSize: 12, color: _onSurface3))
              : Wrap(spacing: 6, runSpacing: 6, children: role.modules.map((key) {
                  final m = _modInfo(key);
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: m.color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: m.color.withValues(alpha: 0.3)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(m.icon, size: 13, color: m.color),
                      const SizedBox(width: 5),
                      Text(m.label, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: m.color)),
                    ]),
                  );
                }).toList()),
        ),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════
// CREATE / EDIT DIALOG
// ══════════════════════════════════════════════════════════════════════
void _openSheet(BuildContext context, AppRole? existing, VoidCallback onSaved) {
  final nameCtrl = TextEditingController(text: existing?.name ?? '');
  final passCtrl = TextEditingController(text: existing?.password ?? '');
  final selected = <String>{...existing?.modules ?? {}};
  bool obscure = true;

  showDialog(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setSt) {
      return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 680),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Title bar
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(colors: [Color(0xFF0B6E5D), _brand600]),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
              child: Row(children: [
                const Icon(Icons.manage_accounts_rounded, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Expanded(child: Text(existing == null ? 'Create New Role' : 'Edit Role',
                    style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800))),
                IconButton(onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                    padding: EdgeInsets.zero, constraints: const BoxConstraints()),
              ]),
            ),

            // Fields
            Flexible(child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Role name
                const Text('Role Name', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _onSurface2)),
                const SizedBox(height: 6),
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    hintText: 'e.g. Donations Manager',
                    hintStyle: const TextStyle(color: _onSurface3),
                    prefixIcon: const Icon(Icons.badge_outlined, size: 19),
                    filled: true, fillColor: _surface2,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _brand600, width: 1.5)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 14),

                // Password
                const Text('Password', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _onSurface2)),
                const SizedBox(height: 6),
                TextField(
                  controller: passCtrl,
                  obscureText: obscure,
                  decoration: InputDecoration(
                    hintText: 'Set a login password',
                    hintStyle: const TextStyle(color: _onSurface3),
                    prefixIcon: const Icon(Icons.lock_outline, size: 19),
                    suffixIcon: IconButton(
                      icon: Icon(obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18),
                      onPressed: () => setSt(() => obscure = !obscure),
                    ),
                    filled: true, fillColor: _surface2,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _border)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _brand600, width: 1.5)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
                const SizedBox(height: 18),

                // Modules
                const Text('Modules to Manage', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _onSurface2)),
                const SizedBox(height: 3),
                const Text('This role will ONLY see the selected modules in the sidebar.',
                    style: TextStyle(fontSize: 11.5, color: _onSurface3)),
                const SizedBox(height: 10),
                ..._kMods.map((m) {
                  final isOn = selected.contains(m.key);
                  return GestureDetector(
                    onTap: () => setSt(() { if (isOn) selected.remove(m.key); else selected.add(m.key); }),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: isOn ? m.color.withValues(alpha: 0.07) : _surface2,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isOn ? m.color.withValues(alpha: 0.4) : _border, width: isOn ? 1.5 : 1),
                      ),
                      child: Row(children: [
                        Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: isOn ? m.color.withValues(alpha: 0.15) : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: isOn ? m.color.withValues(alpha: 0.4) : _border),
                          ),
                          child: Icon(m.icon, size: 16, color: isOn ? m.color : _onSurface3),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(m.label,
                            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                                color: isOn ? _onSurface1 : _onSurface2))),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 22, height: 22,
                          decoration: BoxDecoration(
                            color: isOn ? m.color : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: isOn ? m.color : _onSurface3, width: 1.5),
                          ),
                          child: isOn ? const Icon(Icons.check_rounded, color: Colors.white, size: 14) : null,
                        ),
                      ]),
                    ),
                  );
                }),
                const SizedBox(height: 4),
              ]),
            )),

            // Buttons
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Row(children: [
                Expanded(child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: _border),
                    foregroundColor: _onSurface2,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w700)),
                )),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton(
                  onPressed: () {
                    final name = nameCtrl.text.trim();
                    final pass = passCtrl.text.trim();
                    if (name.isEmpty || pass.isEmpty) return;
                    if (existing == null) {
                      appRoles.add(AppRole(name: name, password: pass, modules: Set.from(selected)));
                    } else {
                      existing.name     = name;
                      existing.password = pass;
                      existing.modules  = Set.from(selected);
                    }
                    Navigator.pop(ctx);
                    onSaved();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brand600, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text(existing == null ? 'Create Role' : 'Save Changes',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                )),
              ]),
            ),
          ]),
        ),
      );
    }),
  );
}
