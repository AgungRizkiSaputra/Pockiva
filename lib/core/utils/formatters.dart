import 'package:intl/intl.dart';

class CurrencyFormatter {
  const CurrencyFormatter._();

  static final NumberFormat _idrFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  static final NumberFormat _decimalIdr = NumberFormat('#,##0', 'id_ID');

  static String formatIdr(num amount, {bool showSign = false}) {
    final absFormatted = _idrFormat.format(amount.abs());
    if (amount < 0) return '-$absFormatted';
    if (showSign && amount > 0) return '+$absFormatted';
    return absFormatted;
  }

  static String formatPlainNumber(num amount) => _decimalIdr.format(amount);

  static String formatCompactIdr(num amount) {
    final abs = amount.abs();
    final prefix = amount < 0 ? '-Rp ' : 'Rp ';
    if (abs >= 1000000000) {
      return '$prefix${(abs / 1000000000).toStringAsFixed(1).replaceAll('.', ',')} M';
    }
    if (abs >= 1000000) {
      return '$prefix${(abs / 1000000).toStringAsFixed(1).replaceAll('.', ',')} jt';
    }
    if (abs >= 1000) {
      return '$prefix${(abs / 1000).toStringAsFixed(0)} rb';
    }
    return '$prefix${abs.toStringAsFixed(0)}';
  }
}

class DateFormatter {
  const DateFormatter._();

  static String groupLabel(DateTime date, {DateTime? now}) {
    final ref = now ?? DateTime.now();
    final today = DateTime(ref.year, ref.month, ref.day);
    final target = DateTime(date.year, date.month, date.day);
    final diffDays = today.difference(target).inDays;

    if (diffDays == 0) return 'Hari ini';
    if (diffDays == 1) return 'Kemarin';
    return formatDayMonthYear(date);
  }

  static String formatDayMonthYear(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  static String formatMonthYear(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  static String formatShortMonth(String yyyyMm) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'Mei',
      'Jun',
      'Jul',
      'Agu',
      'Sep',
      'Okt',
      'Nov',
      'Des',
    ];
    final parts = yyyyMm.split('-');
    if (parts.length != 2) return yyyyMm;
    final monthIndex = int.tryParse(parts[1]);
    if (monthIndex == null || monthIndex < 1 || monthIndex > 12) return yyyyMm;
    return months[monthIndex - 1];
  }

  static String formatTime(DateTime date) {
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  static String greetingForHour(int hour) {
    if (hour < 11) return 'Selamat pagi';
    if (hour < 15) return 'Selamat siang';
    if (hour < 18) return 'Selamat sore';
    return 'Selamat malam';
  }
}
