class Validators {
  Validators._();

  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'E-mel diperlukan';
    }
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Format e-mel tidak sah';
    }
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Kata laluan diperlukan';
    }
    if (value.length < 8) {
      return 'Minimum 8 aksara';
    }
    if (!RegExp(r'\d').hasMatch(value)) {
      return 'Perlu 1 nombor';
    }
    if (!RegExp(r'[!@#\$&*~`%^()_\-+={\[}\]|:;"<>,.?/\\]').hasMatch(value)) {
      return 'Perlu 1 aksara khas';
    }
    return null;
  }

  static String? validateConfirmPassword(String? value, String original) {
    if (value == null || value.isEmpty) {
      return 'Sahkan kata laluan';
    }
    if (value != original) {
      return 'Kata laluan tidak sepadan';
    }
    return null;
  }

  static String? validateDisplayName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Nama penuh diperlukan';
    }
    if (value.trim().length < 2) {
      return 'Minimum 2 aksara';
    }
    return null;
  }

  static String? validateRequired(String? value, {String fieldName = 'Medan ini'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName diperlukan';
    }
    return null;
  }

  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Nombor telefon diperlukan';
    }
    final phoneRegex = RegExp(r'^(\+?6?01)[02-46-9]-*[0-9]{7,8}$');
    if (!phoneRegex.hasMatch(value.replaceAll(' ', '').replaceAll('-', ''))) {
      return 'Format telefon tidak sah';
    }
    return null;
  }

  static String? validateIC(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'No. KP diperlukan';
    }
    final icRegex = RegExp(r'^\d{12}$');
    final cleaned = value.replaceAll('-', '');
    if (!icRegex.hasMatch(cleaned)) {
      return 'No. KP mestilah 12 digit';
    }
    return null;
  }

  static String? validateBadgeNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Nombor lencana diperlukan';
    }
    return null;
  }
}