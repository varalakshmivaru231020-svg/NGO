import 'package:flutter_test/flutter_test.dart';
import 'package:collection/collection.dart';
import 'package:saksham_app/core/auth/role_auth.dart';

// Replicates the credential-matching used by LoginScreen._login (step 2).
AppRole? resolveLogin(String input, String password) => appRoles.firstWhereOrNull(
      (r) => (r.name.toLowerCase() == input.trim().toLowerCase() ||
              r.email.toLowerCase() == input.trim().toLowerCase()) &&
          r.password == password,
    );

void main() {
  group('Seeded team-member login (Vara)', () {
    test('seeded account is present in appRoles at startup', () {
      final vara = appRoles.firstWhereOrNull((r) => r.email.toLowerCase() == 'vara@gmail.com');
      expect(vara, isNotNull, reason: 'Vara should be merged into appRoles regardless of storage');
      expect(vara!.password, '12345678');
    });

    test('login succeeds by email (exact)', () {
      expect(resolveLogin('Vara@gmail.com', '12345678'), isNotNull);
    });

    test('login succeeds by email (different case / whitespace)', () {
      expect(resolveLogin('  vara@GMAIL.com ', '12345678'), isNotNull);
    });

    test('login succeeds by role name', () {
      expect(resolveLogin('Vara', '12345678'), isNotNull);
    });

    test('wrong password is rejected', () {
      expect(resolveLogin('Vara@gmail.com', 'wrong'), isNull);
    });

    test('seeded member has full module access', () {
      final vara = resolveLogin('Vara@gmail.com', '12345678')!;
      expect(vara.modules, containsAll(<String>{'donors', 'donations', 'students', 'reports'}));
    });
  });
}
