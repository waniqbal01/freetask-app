class Validators {
  const Validators._();

  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required.';
    }
    final emailRegex = RegExp('^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Please enter a valid email address.';
    }
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required.';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters long.';
    }
    return null;
  }

  static String? validateConfirmPassword(String? value, String? password) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password.';
    }
    if (value != password) {
      return 'Passwords do not match.';
    }
    return null;
  }

  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Name is required.';
    }
    if (value.trim().length < 3) {
      return 'Name must be at least 3 characters long.';
    }
    return null;
  }

  static String? validateRequired(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required.';
    }
    return null;
  }

  static String? validateNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'This field is required.';
    }
    final number = double.tryParse(value.trim());
    if (number == null || number <= 0) {
      return 'Enter a valid number.';
    }
    return null;
  }

  static String? validatePhone(String? value) {
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
