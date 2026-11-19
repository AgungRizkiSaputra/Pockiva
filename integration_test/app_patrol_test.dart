import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:tabungan_pribadi/main.dart' as app;

/// Patrol E2E test suite (PRD Section 25 & 26).
/// Run on Android/iOS emulator or device:
///   patrol test -t integration_test/app_patrol_test.dart \
///     --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
void main() {
  patrolTest(
    'App boots under 2 seconds and renders authentication or configuration gate cleanly',
    ($) async {
      final stopwatch = Stopwatch()..start();
      await app.main();
      await $.pumpAndSettle();
      stopwatch.stop();

      expect(stopwatch.elapsedMilliseconds, lessThan(2000));

      final hasWelcome = $(const Key('google_sign_in_button')).exists;
      final hasConfigNotice = $('Konfigurasi Supabase Diperlukan').exists;
      final hasPinVerify = $('Ganti Akun').exists;

      expect(hasWelcome || hasConfigNotice || hasPinVerify, isTrue);
    },
  );
}
