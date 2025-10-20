class Validators {
  const Validators._();

  static const _EmailValidator _email = _EmailValidator();
  static const _PasswordValidator _password = _PasswordValidator();
  static const _ConfirmPasswordFactory _confirmPassword = _ConfirmPasswordFactory();
  static const _NameValidator _name = _NameValidator();
  static const _RequiredValidator _requiredField = _RequiredValidator();
  static const _NumberValidator _number = _NumberValidator();
  static const _PhoneValidator _phone = _PhoneValidator();

  static String? validateEmail(String? value) => _email(value);

  static String? validatePassword(String? value) => _password(value);

  static String? Function(String? value) validateConfirmPassword(
    String? Function() passwordProvider,
  ) {
    final validator = _confirmPassword(passwordProvider);
    return validator.call;
  }

  static String? validateName(String? value) => _name(value);

  static String? validateRequired(String? value) => _requiredField(value);

  static String? validateNumber(String? value) => _number(value);

  static String? validatePhone(String? value) => _phone(value);
}

class _EmailValidator {
  const _EmailValidator();

  String? call(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required.';
    }
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email address.';
    }
    return null;
  }
}

class _PasswordValidator {
  const _PasswordValidator();

  String? call(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required.';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters long.';
    }
    return null;
  }
}

class _ConfirmPasswordFactory {
  const _ConfirmPasswordFactory();

  _ConfirmPasswordValidator call(String? Function() passwordProvider) {
    return _ConfirmPasswordValidator(passwordProvider);
  }
}

class _ConfirmPasswordValidator {
  const _ConfirmPasswordValidator(this._passwordProvider);

  final String? Function() _passwordProvider;

  String? call(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password.';
    }
    if (value != _passwordProvider()) {
      return 'Passwords do not match.';
    }
    return null;
  }
}

class _NameValidator {
  const _NameValidator();

  String? call(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Name is required.';
    }
    if (value.trim().length < 3) {
      return 'Name must be at least 3 characters long.';
    }
    return null;
  }
}

class _RequiredValidator {
  const _RequiredValidator();

  String? call(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required.';
    }
    return null;
  }
}

class _NumberValidator {
  const _NumberValidator();

  String? call(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required.';
    }
    final number = double.tryParse(value.trim());
    if (number == null || number <= 0) {
      return 'Enter a valid number.';
    }
    return null;
  }
}

class _PhoneValidator {
  const _PhoneValidator();

  String? call(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    final cleaned = value.replaceAll(RegExp(r'[^0-9+]'), '');
    final phoneRegex = RegExp(r'^[+]?[0-9]{7,15}$');
    if (!phoneRegex.hasMatch(cleaned)) {
      return 'Enter a valid phone number.';
    }
    return null;
  }
}
