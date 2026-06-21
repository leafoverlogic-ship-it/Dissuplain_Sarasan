import 'package:flutter_test/flutter_test.dart';

import 'package:dissuplain_app_web_mobile/screens/password_reset_utils.dart';

void main() {
  group('password reset rules', () {
    test('treats the default password as temporary', () {
      expect(isTemporaryDefaultPassword('Welcome@123'), isTrue);
      expect(isTemporaryDefaultPassword('welcome@123'), isTrue);
      expect(isTemporaryDefaultPassword('MyNewPass@2026'), isFalse);
    });

    test('shows the create-password option only while the default password is still active', () {
      expect(shouldShowCreatePasswordOption('Welcome@123'), isTrue);
      expect(shouldShowCreatePasswordOption('welcome@123'), isTrue);
      expect(shouldShowCreatePasswordOption('MyNewPass@2026'), isFalse);
      expect(shouldShowCreatePasswordOption(''), isFalse);
    });

    test('rejects the default password as a new password', () {
      expect(validateNewPassword('Welcome@123'), contains('This can not be your password.'));
      expect(validateNewPassword('welcome@123'), contains('This can not be your password.'));
    });

    test('accepts a numeric-only password', () {
      expect(validateNewPassword('1234'), isNull);
      expect(validateNewPassword('98765432'), isNull);
    });

    test('rejects non-numeric passwords', () {
      expect(validateNewPassword('Abc12345'), contains('only digits'));
      expect(validateNewPassword('12@34!'), contains('only digits'));
    });
  });
}
