import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tabungan_pribadi/core/security/error_mapper.dart';
import 'package:tabungan_pribadi/core/security/inactivity_guard.dart';
import 'package:tabungan_pribadi/core/sync/offline_sync_service.dart';
import 'package:tabungan_pribadi/features/transactions/application/transactions_controller.dart';
import 'package:tabungan_pribadi/features/transactions/domain/transaction_category.dart';
import 'package:tabungan_pribadi/features/transactions/domain/transaction_item.dart';
import '../helpers/fakes.dart';

void main() {
  group('InactivitySessionGuard (15-minute auto-logout)', () {
    test('triggers timeout callback after inactivity duration', () async {
      final storage = InMemorySecureStorage();
      var timedOut = false;

      final guard = InactivitySessionGuard(
        storage: storage,
        timeout: const Duration(milliseconds: 80),
        onTimeout: () async {
          timedOut = true;
        },
      );

      await guard.start();
      await Future<void>.delayed(const Duration(milliseconds: 140));
      expect(timedOut, isTrue);
      guard.dispose();
    });

    test('detects elapsed inactivity when app resumes from background', () async {
      final storage = InMemorySecureStorage();
      var now = DateTime(2026, 11, 18, 10, 0);
      var timedOut = false;

      final guard = InactivitySessionGuard(
        storage: storage,
        timeout: const Duration(minutes: 15),
        clock: () => now,
        onTimeout: () async {
          timedOut = true;
        },
      );

      await guard.start();
      now = now.add(const Duration(minutes: 16));
      final expired = await guard.checkExpiredOnResume();

      expect(expired, isTrue);
      expect(timedOut, isTrue);
      guard.dispose();
    });
  });

  group('Offline Sync Queue & Duplicate Prevention', () {
    test('queues transaction locally when offline and flushes once online', () async {
      final storage = InMemorySecureStorage();
      final offlineStore = OfflineSyncStore(storage);
      final repo = FakeTransactionRepository(simulateOffline: true);

      final controller = TransactionsController(
        repository: repo,
        offlineStore: offlineStore,
        userId: 'user-test-1',
        onDataMutated: () {},
      );

      final result = await controller.createTransaction(
        type: TransactionType.expense,
        amount: 50000,
        category: 'food',
        note: 'Makan siang',
        explicitClientId: '11111111-1111-4111-8111-111111111111',
      );

      expect(result.success, isTrue);
      expect(result.syncStatus, SyncStatus.pendingSync);
      expect(controller.state.pendingCount, 1);
      expect(controller.state.allTransactions.first.syncStatus, SyncStatus.pendingSync);
      expect(controller.state.effectiveSummary.totalExpenses, 50000);

      // Reconnect and sync queue
      repo.simulateOffline = false;
      final syncedCount = await controller.syncPendingQueue();

      expect(syncedCount, 1);
      expect(controller.state.pendingCount, 0);
      expect(controller.state.syncedItems.length, 1);
      expect(controller.state.syncedItems.first.syncStatus, SyncStatus.synced);
      expect(controller.state.syncedItems.first.amount, 50000);
    });
  });

  group('ErrorMapper safety', () {
    test('returns safe user-facing messages without exposing SQL internals', () {
      const pgError = PostgrestException(
        message: 'relation "public.profiles" permission denied for column pin_hash',
        code: '42501',
      );
      final mapped = ErrorMapper.toUserMessage(pgError);
      expect(mapped.contains('pin_hash'), isFalse);
      expect(mapped.contains('relation'), isFalse);
      expect(mapped, contains('izin'));

      expect(
        ErrorMapper.isNetworkError(const SocketException('Failed host lookup')),
        isTrue,
      );
    });
  });
}
