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
import 'package:tabungan_pribadi/features/auth/domain/user_profile.dart';
import 'package:tabungan_pribadi/features/gamification/data/gamification_repository.dart';
import 'package:tabungan_pribadi/features/gamification/domain/gamification_models.dart';
import 'package:tabungan_pribadi/features/transactions/data/transaction_repository.dart';
import 'package:tabungan_pribadi/features/transactions/domain/transaction_category.dart';
import '../helpers/fakes.dart';

void main() {
  setUpAll(() async {
    AppTheme.useGoogleFonts = false;
    await initializeDateFormatting('id_ID');
  });

  void setViewport(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
  }

  Future<ProviderScope> buildTestApp({
    required FakeAuthRepository authRepo,
    required FakeTransactionRepository txRepo,
    FakeGamificationRepository? gamificationRepo,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final storage = InMemorySecureStorage();

    return ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        secureStorageProvider.overrideWithValue(storage),
        authRepositoryProvider.overrideWithValue(authRepo),
        transactionRepositoryProvider.overrideWithValue(txRepo),
        gamificationRepositoryProvider.overrideWithValue(
          gamificationRepo ?? FakeGamificationRepository(),
        ),
      ],
      child: const TabunganPribadiApp(),
    );
  }

  testWidgets(
    'PRD Acceptance Criteria: Dashboard FAB opens Quick Add bottom sheet, validates > 0, and records transaction',
    (tester) async {
      setViewport(tester, const Size(412, 915));

      final authRepo = FakeAuthRepository(
        signedIn: true,
        configuredPin: '482915',
        initialProfile: const UserProfile(
          id: 'user-test-1',
          email: 'nadia@example.com',
          fullName: 'Nadia Pratama',
          hasPin: true,
          savingsTarget: 5000000,
          savingsTargetTitle: 'Dana Darurat',
          onboardingCompleted: true,
          notificationsEnabled: true,
          reminderHour: 20,
        ),
      );
      final txRepo = FakeTransactionRepository();
      final gamificationRepo = FakeGamificationRepository(
        streak: UserStreak(
          currentStreak: 3,
          longestStreak: 5,
          totalActiveDays: 10,
          lastActive: DateTime.now(),
        ),
      );

      final app = await buildTestApp(
        authRepo: authRepo,
        txRepo: txRepo,
        gamificationRepo: gamificationRepo,
      );
      await tester.pumpWidget(app);
      await tester.pumpAndSettle();

      // Cold start requires 6-digit PIN verification
      for (final d in ['4', '8', '2', '9', '1', '5']) {
        await tester.tap(find.byKey(Key('pin_key_$d')));
        await tester.pump();
      }
      await tester.pumpAndSettle();

      // Empty state visible on Dashboard for new user
      expect(find.text('Mulai catatan pertamamu'), findsOneWidget);
      expect(find.byKey(const Key('quick_add_fab')), findsOneWidget);

      // Given user is on dashboard, When clicking FAB, Then Bottom Sheet opens
      await tester.tap(find.byKey(const Key('quick_add_fab')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('quick_add_amount_display')), findsOneWidget);

      // Attempting submit with Rp 0 displays validation error
      await tester.ensureVisible(find.byKey(const Key('quick_add_submit_button')));
      await tester.tap(find.byKey(const Key('quick_add_submit_button')));
      await tester.pump();
      expect(find.byKey(const Key('quick_add_error_text')), findsOneWidget);

      // Switch to Tabungan, enter Rp 500.000 via numpad, submit
      await tester.tap(find.byKey(const Key('quick_add_type_saving')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('numpad_5')));
      await tester.tap(find.byKey(const Key('numpad_0')));
      await tester.tap(find.byKey(const Key('numpad_0')));
      await tester.tap(find.byKey(const Key('numpad_000')));
      await tester.pump();

      await tester.tap(find.byKey(const Key('quick_add_submit_button')));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();

      expect(txRepo.items.length, 1);
      expect(txRepo.items.first.type, TransactionType.saving);
      expect(txRepo.items.first.amount, 500000);
      expect(find.text('10%'), findsOneWidget);

      authRepo.dispose();
    },
  );

  testWidgets('Settings switches between Light Mode and Dark Mode cleanly', (tester) async {
    setViewport(tester, const Size(412, 915));

    final authRepo = FakeAuthRepository(
      signedIn: true,
      configuredPin: '482915',
      initialProfile: const UserProfile(
        id: 'user-test-1',
        email: 'nadia@example.com',
        fullName: 'Nadia Pratama',
        hasPin: true,
        savingsTarget: 5000000,
        savingsTargetTitle: 'Dana Darurat',
        onboardingCompleted: true,
        notificationsEnabled: true,
        reminderHour: 20,
      ),
    );
    final txRepo = FakeTransactionRepository();

    final app = await buildTestApp(authRepo: authRepo, txRepo: txRepo);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    // Unlock PIN
    for (final d in ['4', '8', '2', '9', '1', '5']) {
      await tester.tap(find.byKey(Key('pin_key_$d')));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('settings_button')));
    await tester.pumpAndSettle();

    expect(find.text('Pengaturan'), findsOneWidget);
    await tester.tap(find.text('Gelap'));
    await tester.pumpAndSettle();

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.themeMode, ThemeMode.dark);

    await tester.tap(find.text('Terang'));
    await tester.pumpAndSettle();
    final updatedApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(updatedApp.themeMode, ThemeMode.light);

    authRepo.dispose();
  });

  testWidgets('Tablet / Desktop responsive layout renders NavigationRail without overflow', (tester) async {
    setViewport(tester, const Size(1200, 800));

    final authRepo = FakeAuthRepository(
      signedIn: true,
      configuredPin: '482915',
      initialProfile: const UserProfile(
        id: 'user-test-1',
        email: 'nadia@example.com',
        fullName: 'Nadia Pratama',
        hasPin: true,
        savingsTarget: 5000000,
        savingsTargetTitle: 'Dana Darurat',
        onboardingCompleted: true,
        notificationsEnabled: true,
        reminderHour: 20,
      ),
    );
    final txRepo = FakeTransactionRepository();

    final app = await buildTestApp(authRepo: authRepo, txRepo: txRepo);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    for (final d in ['4', '8', '2', '9', '1', '5']) {
      await tester.tap(find.byKey(Key('pin_key_$d')));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byKey(const Key('dashboard_total_balance')), findsOneWidget);

    authRepo.dispose();
  });

  testWidgets('Forgot PIN Flow: Tap Lupa PIN -> Send OTP -> Enter 6-digit OTP -> Set New PIN -> Enter Dashboard', (tester) async {
    setViewport(tester, const Size(412, 915));

    final authRepo = FakeAuthRepository(
      signedIn: true,
      configuredPin: '111222',
      initialProfile: const UserProfile(
        id: 'user-test-otp',
        email: 'agung@example.com',
        fullName: 'Agung Pratama',
        hasPin: true,
        savingsTarget: 10000000,
        savingsTargetTitle: 'Target Utama',
        onboardingCompleted: true,
        notificationsEnabled: true,
        reminderHour: 20,
      ),
    );
    final txRepo = FakeTransactionRepository();

    final app = await buildTestApp(authRepo: authRepo, txRepo: txRepo);
    await tester.pumpWidget(app);
    await tester.pumpAndSettle();

    // 1. We are on PIN Verify screen
    expect(find.byKey(const Key('forgot_pin_button')), findsOneWidget);

    // 2. Tap Lupa PIN button
    await tester.tap(find.byKey(const Key('forgot_pin_button')));
    await tester.pumpAndSettle();

    // 3. Confirm modal appears
    expect(find.byKey(const Key('confirm_forgot_pin_button')), findsOneWidget);
    await tester.tap(find.byKey(const Key('confirm_forgot_pin_button')));
    await tester.pumpAndSettle();

    // 4. Land on OtpVerificationScreen
    expect(find.text('Verifikasi Kode OTP'), findsOneWidget);
    expect(find.byKey(const Key('otp_cell_0')), findsOneWidget);

    // 5. Enter 6 digit OTP (123456)
    for (final d in ['1', '2', '3', '4', '5', '6']) {
      await tester.tap(find.byKey(Key('otp_keypad_$d')));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    // 6. OTP verified -> transitions to PinSetupScreen ("Buat PIN Baru")
    expect(find.text('Buat PIN Baru'), findsOneWidget);

    // 7. Input new PIN: 987654
    for (final d in ['9', '8', '7', '6', '5', '4']) {
      await tester.tap(find.byKey(Key('pin_key_$d')));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    // 8. Confirm new PIN: 987654
    for (final d in ['9', '8', '7', '6', '5', '4']) {
      await tester.tap(find.byKey(Key('pin_key_$d')));
      await tester.pump();
    }
    await tester.pumpAndSettle();

    // 9. Successfully arrives at Dashboard!
    expect(find.byKey(const Key('dashboard_total_balance')), findsOneWidget);

    authRepo.dispose();
  });
}
