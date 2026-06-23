class Validators {
  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return "Name is required.";
    }
    if (value.trim().length < 3) {
      return "Name must be at least 3 characters.";
    }
    if (!RegExp(r'^[a-zA-Z\s]+$').hasMatch(value.trim())) {
      return "Name can only contain letters and spaces.";
    }
    return null;
  }

  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return "Email is required.";
    }
    if (!RegExp(r'^[\w\.\-]+@[\w\.\-]+\.\w{2,}$').hasMatch(value.trim())) {
      return "Please enter a valid email address.";
    }
    return null;
  }

  static String? validatePhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return "Phone number is required.";
    }
    if (!RegExp(r'^[6-9]\d{9}$').hasMatch(value.trim())) {
      return "Please enter a valid 10-digit mobile number.";
    }
    return null;
  }

  static String? validateAadhar(String? value) {
    if (value == null || value.trim().isEmpty) {
      return "Aadhar number is required.";
    }
    final cleaned = value.replaceAll(RegExp(r'\s'), '');
    if (!RegExp(r'^\d{12}$').hasMatch(cleaned)) {
      return "Aadhar number must be exactly 12 digits.";
    }
    // Verhoeff algorithm check (simplified - first digit cannot be 0 or 1)
    if (cleaned.startsWith('0') || cleaned.startsWith('1')) {
      return "Please enter a valid Aadhar number.";
    }
    return null;
  }

  static String? validatePAN(String? value) {
    if (value == null || value.trim().isEmpty) {
      return "PAN number is required.";
    }
    // Indian PAN format: 5 letters + 4 digits + 1 letter (e.g., ABCDE1234F)
    if (!RegExp(r'^[A-Z]{5}\d{4}[A-Z]$', caseSensitive: false)
        .hasMatch(value.trim())) {
      return "Please enter a valid PAN number (e.g., ABCDE1234F).";
    }
    return null;
  }

  static String? validateDrivingLicence(String? value) {
    if (value == null || value.trim().isEmpty) {
      return "Driving licence number is required.";
    }
    // Indian DL format: XX00 0000000000 (state code + RTO + number)
    if (!RegExp(r'^[A-Z]{2}\d{2}\s?\d{4}\s?\d{7}$', caseSensitive: false)
        .hasMatch(value.trim())) {
      return "Please enter a valid driving licence number (e.g., MH02 2020 1234567).";
    }
    return null;
  }

  static String? validateDate(String? value, {String fieldName = "Date"}) {
    if (value == null || value.trim().isEmpty) {
      return "$fieldName is required.";
    }
    if (!RegExp(r'^\d{2}/\d{2}/\d{4}$').hasMatch(value.trim())) {
      return "Please select a valid date.";
    }
    return null;
  }

  static String? validateDOB(String? value) {
    final dateError = validateDate(value, fieldName: "Date of birth");
    if (dateError != null) return dateError;

    final parts = value!.trim().split('/');
    final day = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final year = int.parse(parts[2]);
    final dob = DateTime(year, month, day);
    final now = DateTime.now();
    final age = now.year - dob.year - ((now.month < month || (now.month == month && now.day < day)) ? 1 : 0);

    if (age < 18) {
      return "Driver must be at least 18 years old.";
    }
    if (age > 70) {
      return "Please enter a valid date of birth.";
    }
    return null;
  }

  static String? validateAccountNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return "Account number is required.";
    }
    if (!RegExp(r'^\d{9,18}$').hasMatch(value.trim())) {
      return "Account number must be 9-18 digits.";
    }
    return null;
  }

  static String? validateIFSC(String? value) {
    if (value == null || value.trim().isEmpty) {
      return "IFSC code is required.";
    }
    if (!RegExp(r'^[A-Z]{4}0[A-Z0-9]{6}$', caseSensitive: false)
        .hasMatch(value.trim())) {
      return "Please enter a valid IFSC code (e.g., SBIN0001234).";
    }
    return null;
  }

  static String? validateZipCode(String? value) {
    if (value == null || value.trim().isEmpty) {
      return "ZIP / Postal code is required.";
    }
    if (!RegExp(r'^\d{6}$').hasMatch(value.trim())) {
      return "Please enter a valid 6-digit PIN code.";
    }
    return null;
  }

  static String? validateAddress(String? value) {
    if (value == null || value.trim().isEmpty) {
      return "Address is required.";
    }
    if (value.trim().length < 10) {
      return "Please enter a complete address.";
    }
    return null;
  }

  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return "$fieldName is required.";
    }
    return null;
  }
}
