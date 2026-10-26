import 'package:flutter_test/flutter_test.dart';
import 'package:myoccasio/features/auth/domain/auth_validation.dart';

void main() {
  test(
    'email validation rejects missing parts, extra separators, and whitespace',
    () {
      for (final email in [
        null,
        '',
        '@.',
        'student@university',
        'student@@university.ca',
        'student @university.ca',
        'student@ university.ca',
        'student@university.ca\nother',
      ]) {
        expect(
          validateEmail(email),
          isNotNull,
          reason: 'Invalid email: $email',
        );
      }
    },
  );

  test(
    'email validation permits trimmed addresses, plus tags, and subdomains',
    () {
      for (final email in [
        ' student@university.ca ',
        'student+awards@dept.university.ca',
      ]) {
        expect(validateEmail(email), isNull);
      }
    },
  );
}
