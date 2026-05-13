class Validators {
  Validators._();

  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'E-mel diperlukan.';
    }
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Format e-mel tidak sah.';
    }
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Kata laluan diperlukan.';
    }
    if (value.length < 8) {
      return 'Kata laluan mestilah sekurang-kurangnya 8 aksara.';
    }
    if (!RegExp(r'\d').hasMatch(value)) {
      return 'Kata laluan mesti mengandungi sekurang-kurangnya 1 nombor.';
    }
    if (!RegExp(r'[!@#\$&*~`%^()_\-+={\[}\]|:;"<>,.?/\\]').hasMatch(value)) {
      return 'Kata laluan mesti mengandungi sekurang-kurangnya 1 aksara khas.';
    }
    return null;
  }

  static String? validateConfirmPassword(String? value, String original) {
    if (value == null || value.isEmpty) {
      return 'Sila sahkan kata laluan anda.';
    }
    if (value != original) {
      return 'Kata laluan tidak sepadan.';
    }
    return null;
  }

  static String? validateDisplayName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Nama penuh diperlukan.';
    }
    if (value.trim().length < 2) {
      return 'Nama mestilah sekurang-kurangnya 2 aksara.';
    }
    return null;
  }

  static String? validateRequired(String? value, {String fieldName = 'Medan ini'}) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName diperlukan.';
    }
    return null;
  }

  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Nombor telefon diperlukan.';
    }
    final phoneRegex = RegExp(r'^(\+?6?01)[02-46-9]-*[0-9]{7,8}$');
    if (!phoneRegex.hasMatch(value.replaceAll(' ', '').replaceAll('-', ''))) {
      return 'Format nombor telefon Malaysia tidak sah.';
    }
    return null;
  }

  static String? validateIC(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Nombor kad pengenalan diperlukan.';
    }
    final icRegex = RegExp(r'^\d{12}$');
    final cleaned = value.replaceAll('-', '');
    if (!icRegex.hasMatch(cleaned)) {
      return 'Nombor kad pengenalan mestilah 12 digit.';
    }
    return null;
  }

  static String? validateBadgeNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Nombor lencana diperlukan.';
    }
    return null;
  }
}
