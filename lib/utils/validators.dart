class Validators {
  const Validators._();

  static const email = _EmailValidator();
  static const password = _PasswordValidator();
  static const confirmPassword = _ConfirmPasswordFactory();
  static const name = _NameValidator();
  static const requiredField = _RequiredValidator();
  static const number = _NumberValidator();
  static const phone = _PhoneValidator();
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
