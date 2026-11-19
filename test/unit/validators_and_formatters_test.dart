import 'package:flutter_test/flutter_test.dart';
import 'package:tabungan_pribadi/core/utils/formatters.dart';
import 'package:tabungan_pribadi/core/utils/validators.dart';

void main() {
  group('InputValidators', () {
    test('rejects zero, negative, NaN, and oversized transaction amounts', () {
      expect(InputValidators.validateAmount(null), isNotNull);
      expect(InputValidators.validateAmount(0), isNotNull);
      expect(InputValidators.validateAmount(-50000), isNotNull);
      expect(InputValidators.validateAmount(double.nan), isNotNull);
      expect(InputValidators.validateAmount(1e15), isNotNull);
      expect(InputValidators.validateAmount(50000), isNull);
    });

    test('validates 6-digit PIN format and rejects trivially weak PINs', () {
      expect(InputValidators.validateNewPin('12345'), isNotNull);
      expect(InputValidators.validateNewPin('1234567'), isNotNull);
      expect(InputValidators.validateNewPin('12a456'), isNotNull);
      expect(InputValidators.validateNewPin('000000'), isNotNull);
      expect(InputValidators.validateNewPin('777777'), isNotNull);
      expect(InputValidators.validateNewPin('123456'), isNotNull);
      expect(InputValidators.validateNewPin('654321'), isNotNull);
      expect(InputValidators.validateNewPin('482915'), isNull);
    });

    test('sanitizes control characters and angle brackets in notes', () {
      expect(InputValidators.sanitizeNote('   '), isNull);
      expect(
        InputValidators.sanitizeNote('  <script>alert(1)</script> Kopi\x00 '),
        'scriptalert(1)/script Kopi',
      );
      final longInput = 'a' * 200;
      expect(
        InputValidators.sanitizeNote(longInput)!.length,
        InputValidators.maxNoteLength,
      );
    });

    test('parses keypad digit strings reliably', () {
      expect(InputValidators.parseKeypadAmount(''), 0);
      expect(InputValidators.parseKeypadAmount('50000'), 50000);
      expect(InputValidators.parseKeypadAmount('Rp 150.000'), 150000);
    });
  });

  group('Formatters', () {
    test('formats IDR currency with thousands separators', () {
      expect(CurrencyFormatter.formatIdr(50000).replaceAll('\u00A0', ' '), 'Rp 50.000');
      expect(CurrencyFormatter.formatCompactIdr(1500000), 'Rp 1,5 jt');
      expect(CurrencyFormatter.formatCompactIdr(250000), 'Rp 250 rb');
    });

    test('formats relative date group labels accurately', () {
      final now = DateTime(2026, 11, 18, 14, 30);
      expect(DateFormatter.groupLabel(DateTime(2026, 11, 18, 9, 0), now: now), 'Hari ini');
      expect(DateFormatter.groupLabel(DateTime(2026, 11, 17, 21, 0), now: now), 'Kemarin');
      expect(
        DateFormatter.groupLabel(DateTime(2026, 11, 10, 10, 0), now: now),
        '10 Nov 2026',
      );
    });
  });
}
