class InputValidators {
  const InputValidators._();

  static const double maxTransactionAmount = 999999999999.99;
  static const int maxNoteLength = 140;
  static const int maxTargetTitleLength = 80;

  static final RegExp _controlAndAngle = RegExp(r'[\x00-\x1F\x7F<>]');
  static final RegExp _sixDigits = RegExp(r'^\d{6}$');
  static final RegExp _repeatedDigits = RegExp(r'^(\d)\1{5}$');

  static String? validateAmount(double? amount) {
    if (amount == null || !amount.isFinite || amount <= 0) {
      return 'Nominal harus lebih dari Rp 0.';
    }
    if (amount > maxTransactionAmount) {
      return 'Nominal melebihi batas maksimum yang diizinkan.';
    }
    return null;
  }

  static String? validateSavingsTarget(double? target) {
    if (target == null || !target.isFinite || target <= 0) {
      return 'Target tabungan harus lebih dari Rp 0.';
    }
    if (target > maxTransactionAmount) {
      return 'Target tabungan melebihi batas maksimum.';
    }
    return null;
  }

  static String? validatePinFormat(String pin) {
    if (!_sixDigits.hasMatch(pin)) {
      return 'PIN harus terdiri dari tepat 6 digit angka.';
    }
    return null;
  }

  static String? validateNewPin(String pin) {
    final formatError = validatePinFormat(pin);
    if (formatError != null) return formatError;

    if (_repeatedDigits.hasMatch(pin) || pin == '123456' || pin == '654321') {
      return 'PIN terlalu mudah ditebak. Pilih kombinasi angka lain.';
    }
    return null;
  }

  static String? sanitizeNote(String? raw) {
    if (raw == null) return null;
    final cleaned = raw.replaceAll(_controlAndAngle, '').trim();
    if (cleaned.isEmpty) return null;
    return cleaned.length > maxNoteLength
        ? cleaned.substring(0, maxNoteLength)
        : cleaned;
  }

  static String sanitizeTargetTitle(String raw) {
    final cleaned = raw.replaceAll(_controlAndAngle, '').trim();
    if (cleaned.isEmpty) return 'Target Tabungan Utama';
    return cleaned.length > maxTargetTitleLength
        ? cleaned.substring(0, maxTargetTitleLength)
        : cleaned;
  }

  /// Parses digits-only numeric keypad string into IDR double amount.
  static double parseKeypadAmount(String digits) {
    final onlyDigits = digits.replaceAll(RegExp(r'[^0-9]'), '');
    if (onlyDigits.isEmpty) return 0;
    return double.tryParse(onlyDigits) ?? 0;
  }
}
