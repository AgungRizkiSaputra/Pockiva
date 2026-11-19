import 'dart:async';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Maps backend, network, and Edge Function errors into safe, user-facing messages
/// without exposing internal stack traces, SQL schemas, or tokens.
class ErrorMapper {
  const ErrorMapper._();

  static String toUserMessage(Object error) {
    if (error is AppException) {
      return error.message;
    }

    if (error is SocketException || error is TimeoutException) {
      return 'Koneksi internet tidak tersedia. Periksa jaringan Anda lalu coba lagi.';
    }

    if (error is AuthException) {
      final msg = error.message.toLowerCase();
      if (msg.contains('rate limit') || error.statusCode == '429') {
        return 'Terlalu banyak percobaan. Silakan tunggu beberapa menit lalu coba lagi.';
      }
      if (msg.contains('invalid login') || msg.contains('invalid credentials')) {
        return 'Autentikasi gagal. Periksa kembali akun Google Anda.';
      }
      if (msg.contains('cancelled') || msg.contains('canceled')) {
        return 'Proses masuk dibatalkan.';
      }
      return 'Gagal memverifikasi akun. Silakan coba masuk kembali.';
    }

    if (error is FunctionException) {
      final details = error.details;
      if (details is Map && details['message'] is String) {
        return details['message'] as String;
      }
      if (error.status == 429) {
        return 'Terlalu banyak percobaan. Coba lagi setelah 15 menit.';
      }
      if (error.status == 401) {
        return 'Sesi berakhir atau kredensial tidak valid. Silakan coba lagi.';
      }
      return 'Permintaan gagal diproses. Silakan coba beberapa saat lagi.';
    }

    if (error is PostgrestException) {
      if (error.code == '42501') {
        return 'Anda tidak memiliki izin untuk mengakses data ini.';
      }
      if (error.code == '23514') {
        return 'Data yang dimasukkan tidak memenuhi aturan validasi.';
      }
      if (error.code == '23505') {
        return 'Data transaksi sudah tercatat sebelumnya.';
      }
      return 'Gagal menyinkronkan data dengan server. Coba lagi.';
    }

    return 'Terjadi kendala tak terduga. Silakan coba lagi.';
  }

  static bool isNetworkError(Object error) {
    if (error is SocketException || error is TimeoutException) return true;
    final text = error.toString().toLowerCase();
    return text.contains('socketexception') ||
        text.contains('failed host lookup') ||
        text.contains('network is unreachable') ||
        text.contains('clientexception') ||
        text.contains('connection refused');
  }
}

class AppException implements Exception {
  const AppException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'AppException($code)';
}
