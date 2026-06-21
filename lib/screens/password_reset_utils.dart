const String kDefaultPassword = 'Welcome@123';

bool isTemporaryDefaultPassword(String value) {
  return value.trim().toLowerCase() == kDefaultPassword.toLowerCase();
}

bool shouldShowCreatePasswordOption(String? storedPassword) {
  return isTemporaryDefaultPassword(storedPassword ?? '');
}

String? validateNewPassword(String value) {
  final trimmed = value.trim();

  if (trimmed.isEmpty) {
    return 'Please enter a new password.';
  }

  if (isTemporaryDefaultPassword(trimmed)) {
    return 'This can not be your password.';
  }

  if (trimmed.length < 4) {
    return 'Password must be at least 4 digits long.';
  }

  final isDigitsOnly = RegExp(r'^\d+$').hasMatch(trimmed);
  if (!isDigitsOnly) {
    return 'Password must contain only digits.';
  }

  return null;
}
