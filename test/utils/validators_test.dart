import 'package:flutter_test/flutter_test.dart';

import 'package:freetask_app/utils/validators.dart';

void main() {
  group('Validators', () {
    test('validateEmail returns error for empty email', () {
      expect(Validators.validateEmail(''), 'Email is required.');
    });

    test('validateEmail returns null for valid email', () {
      expect(Validators.validateEmail('user@example.com'), isNull);
    });

    test('validatePassword validates minimum length', () {
      expect(Validators.validatePassword('123'),
          'Password must be at least 6 characters long.');
      expect(Validators.validatePassword('123456'), isNull);
    });

    test('validateName ensures at least 3 characters', () {
      expect(Validators.validateName('Jo'),
          'Name must be at least 3 characters long.');
      expect(Validators.validateName('John'), isNull);
    });
  });
}
