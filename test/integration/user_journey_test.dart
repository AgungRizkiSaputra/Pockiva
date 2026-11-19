import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tabungan_pribadi/app.dart';
import 'package:tabungan_pribadi/core/security/secure_storage_service.dart';
import 'package:tabungan_pribadi/core/theme/app_theme.dart';
import 'package:tabungan_pribadi/core/theme/theme_provider.dart';
import 'package:tabungan_pribadi/features/auth/data/auth_repository.dart';
import 'package:tabungan_pribadi/features/gamification/data/gamification_repository.dart';
import 'package:tabungan_pribadi/features/gamification/domain/gamification_models.dart';
import 'package:tabungan_pribadi/features/transactions/data/transaction_repository.dart';
import '../helpers/fakes.dart';

void main() {
  setUpAll(() async {
    AppTheme.useGoogleFonts = false;
    await initializeDateFormatting('id_ID');
  });

  testWidgets(
    'Complete PRD User Journey: Welcome -> Google Auth -> PIN Setup -> Set Target -> Dashboard -> Quick Add -> Insights & Streak',
    (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final storage = InMemorySecureStorage();
      final authRepo = FakeAuthRepository(signedIn: false);
      final txRepo = FakeTransactionRepository();
      final gamificationRepo = FakeGamificationRepository(
        streak: UserStreak(
          currentStreak: 1,
          longestStreak: 1,
          totalActiveDays: 1,
          lastActive: DateTime.now(),
        ),
        badges: [
          UnlockedBadge(badgeCode: 'first_save', unlockedAt: DateTime.now()),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            secureStorageProvider.overrideWithValue(storage),
            authRepositoryProvider.overrideWithValue(authRepo),
            transactionRepositoryProvider.overrideWithValue(txRepo),
            gamificationRepositoryProvider.overrideWithValue(gamificationRepo),
          ],
          child: const TabunganPribadiApp(),
        ),
      );
      await tester.pumpAndSettle();

      // 1. Welcome Screen -> Google Sign-In
      final signInFinder = find.byKey(const Key('google_sign_in_button'));
      expect(signInFinder, findsOneWidget);
      await tester.ensureVisible(signInFinder);
      await tester.tap(signInFinder);
      await tester.pumpAndSettle();

      // 2. PIN Setup (reject weak PIN 123456, accept strong PIN 258369 twice)
      expect(find.text('Buat PIN Keamanan'), findsOneWidget);
      for (final d in ['1', '2', '3', '4', '5', '6']) {
        await tester.tap(find.byKey(Key('pin_key_$d')));
        await tester.pump();
      }
      expect(find.textContaining('terlalu mudah ditebak'), findsOneWidget);

      for (final d in ['2', '5', '8', '3', '6', '9']) {
        await tester.tap(find.byKey(Key('pin_key_$d')));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(find.text('Konfirmasi PIN 6 Digit'), findsOneWidget);

      for (final d in ['2', '5', '8', '3', '6', '9']) {
        await tester.tap(find.byKey(Key('pin_key_$d')));
        await tester.pump();
      }
      await tester.pumpAndSettle();

      // 3. Onboarding -> Set Savings Target
      expect(find.byKey(const Key('onboarding_next_button')), findsOneWidget);
      await tester.tap(find.byKey(const Key('onboarding_next_button')));
      await tester.pumpAndSettle();

      final saveTargetFinder = find.byKey(const Key('save_target_button'));
      await tester.ensureVisible(saveTargetFinder);
      await tester.tap(saveTargetFinder);
      await tester.pumpAndSettle();

      // 4. Dashboard Empty State -> First Saving Deposit Rp 100.000, then Expense Rp 50.000
      expect(find.text('Mulai catatan pertamamu'), findsOneWidget);
      await tester.tap(find.byKey(const Key('quick_add_fab')));
      await tester.pumpAndSettle();

      // Record first deposit (Rp 100.000) to fund the savings account
      await tester.tap(find.byKey(const Key('quick_add_type_saving')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('numpad_1')));
      await tester.tap(find.byKey(const Key('numpad_0')));
      await tester.tap(find.byKey(const Key('numpad_0')));
      await tester.tap(find.byKey(const Key('numpad_000')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('quick_add_submit_button')));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      // Now record an Expense of Rp 50.000 (valid because balance is Rp 100.000)
      await tester.tap(find.byKey(const Key('quick_add_fab')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('quick_add_type_expense')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('numpad_5')));
      await tester.tap(find.byKey(const Key('numpad_0')));
      await tester.tap(find.byKey(const Key('numpad_000')));
      await tester.tap(find.byKey(const Key('quick_add_cat_food')));
      await tester.pump();

      await tester.ensureVisible(find.byKey(const Key('quick_add_submit_button')));
      await tester.tap(find.byKey(const Key('quick_add_submit_button')));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      // 5. Navigate across History, Progres, Insight, Streak tabs
      await tester.tap(find.text('Riwayat'));
      await tester.pumpAndSettle();
      expect(find.text('Riwayat Transaksi'), findsOneWidget);
      expect(find.text('Makanan'), findsOneWidget);

      await tester.tap(find.text('Progres'));
      await tester.pumpAndSettle();
      expect(find.text('Progres Tabungan'), findsOneWidget);

      await tester.tap(find.text('Insight'));
      await tester.pumpAndSettle();
      expect(find.text('Smart Budget Insights'), findsOneWidget);
      expect(find.textContaining('Pengeluaran terbesar: Makanan'), findsOneWidget);

      await tester.tap(find.text('Streak'));
      await tester.pumpAndSettle();
      expect(find.text('Streak & Pencapaian'), findsOneWidget);
      expect(find.text('Langkah Pertama'), findsOneWidget);

      authRepo.dispose();
    },
  );
}
