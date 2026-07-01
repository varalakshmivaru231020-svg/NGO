import 'package:flutter_test/flutter_test.dart';
import 'package:collection/collection.dart';
import 'package:saksham_app/core/auth/role_auth.dart';
import 'package:saksham_app/core/auth/role_storage.dart';

// Same predicate LoginScreen._login uses to resolve a team-member login.
AppRole? resolveLogin(String input, String password) => appRoles.firstWhereOrNull(
      (r) => (r.name.toLowerCase() == input.trim().toLowerCase() ||
              r.email.toLowerCase() == input.trim().toLowerCase()) &&
          r.password == password,
    );

void main() {
  group('Dynamic role + team creation', () {
    test('creating a role template updates the accessible modules', () {
      // Mirrors ManageRoles "create role": push a template + persist.
      roleTemplates.add({
        'name': 'Test Role',
        'desc': 'created in test',
        'isSystem': false,
        'perms': <String, dynamic>{
          'donors':   {'view': true, 'add': true, 'edit': false, 'delete': false},
          'students': {'view': true, 'add': false, 'edit': false, 'delete': false},
          'reports':  {'view': false, 'export': false},
        },
      });
      saveRoleTemplates();

      // The new role is immediately usable for deriving module access.
      expect(modulesForRoleName('Test Role'), {'donors', 'students'});
    });

    test('creating a team member makes them log in immediately + persists', () {
      final before = appRoles.length;

      // Mirrors "Create User": add an AppRole whose modules come from the role.
      appRoles.add(AppRole(
        name: 'Priya Sharma',
        email: 'priya@saksham.org',
        password: 'priya123',
        roleName: 'Test Role',
        modules: modulesForRoleName('Test Role'),
      ));
      saveRoles();

      // 1. The team list (derived from appRoles) grew by one.
      expect(appRoles.length, before + 1);

      // 2. Login works right away — by email and by name.
      expect(resolveLogin('priya@saksham.org', 'priya123'), isNotNull);
      expect(resolveLogin('Priya Sharma', 'priya123'), isNotNull);
      expect(resolveLogin('priya@saksham.org', 'wrong'), isNull);

      // 3. They only see the modules their role grants.
      expect(resolveLogin('priya@saksham.org', 'priya123')!.modules, {'donors', 'students'});

      // 4. It was persisted to storage (survives a reload / new tab).
      final saved = readRoleStorage();
      expect(saved, isNotNull);
      expect(saved!.contains('priya@saksham.org'), isTrue);
    });

    test('editing a role re-applies module access to its members', () {
      // Grant the Test Role access to reports, then re-apply to members.
      final tmpl = roleTemplates.firstWhere((t) => t['name'] == 'Test Role');
      (tmpl['perms'] as Map)['reports'] = {'view': true, 'export': false};
      saveRoleTemplates();
      applyTemplateToMembers('Test Role');

      final priya = resolveLogin('priya@saksham.org', 'priya123')!;
      expect(priya.modules, containsAll(<String>{'donors', 'students', 'reports'}));
    });
  });
}
