import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/transactions/domain/transaction_item.dart';
import '../security/secure_storage_service.dart';

/// Encrypted local persistence for offline transaction cache and pending sync queue.
/// Guarantees clear separation between synced, pendingSync, localOnly, and syncFailed items.
class OfflineSyncStore {
  OfflineSyncStore(this._storage);

  final SecureStorageService _storage;

  Future<List<TransactionItem>> loadPendingQueue() async {
    final raw = await _storage.read(SecureStorageKeys.offlineQueueJson);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(
            (m) => TransactionItem.fromJson(
              m,
              defaultSyncStatus: SyncStatus.pendingSync,
            ),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> savePendingQueue(List<TransactionItem> queue) async {
    final encoded = jsonEncode(queue.map((e) => e.toJson()).toList());
    await _storage.write(SecureStorageKeys.offlineQueueJson, encoded);
  }

  Future<List<TransactionItem>> enqueue(TransactionItem item) async {
    final queue = List<TransactionItem>.from(await loadPendingQueue());
    final existingIndex = queue.indexWhere(
      (q) =>
          (item.clientId != null && q.clientId == item.clientId) ||
          q.id == item.id,
    );
    if (existingIndex >= 0) {
      queue[existingIndex] = item;
    } else {
      queue.insert(0, item);
    }
    await savePendingQueue(queue);
    return queue;
  }

  Future<List<TransactionItem>> removeByClientId(String clientId) async {
    final queue = List<TransactionItem>.from(await loadPendingQueue());
    queue.removeWhere((item) => item.clientId == clientId || item.id == clientId);
    await savePendingQueue(queue);
    return queue;
  }

  Future<List<TransactionItem>> markStatus(
    String clientId,
    SyncStatus status,
  ) async {
    final queue = List<TransactionItem>.from(await loadPendingQueue());
    for (int i = 0; i < queue.length; i++) {
      if (queue[i].clientId == clientId || queue[i].id == clientId) {
        queue[i] = queue[i].copyWith(syncStatus: status);
      }
    }
    await savePendingQueue(queue);
    return queue;
  }

  Future<List<TransactionItem>> loadCachedSyncedTransactions() async {
    final raw = await _storage.read(SecureStorageKeys.cachedTransactionsJson);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map((m) => TransactionItem.fromJson(m, defaultSyncStatus: SyncStatus.synced))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveCachedSyncedTransactions(List<TransactionItem> items) async {
    // Keep up to 200 most recent items in encrypted local cache for <2s cold load
    final trimmed = items.take(200).map((e) => e.toJson()).toList();
    await _storage.write(
      SecureStorageKeys.cachedTransactionsJson,
      jsonEncode(trimmed),
    );
  }

  Future<void> clearAll() async {
    await _storage.delete(SecureStorageKeys.offlineQueueJson);
    await _storage.delete(SecureStorageKeys.cachedTransactionsJson);
    await _storage.delete(SecureStorageKeys.cachedProfileJson);
    await _storage.delete(SecureStorageKeys.cachedStreakJson);
    await _storage.delete(SecureStorageKeys.cachedBadgesJson);
  }
}

final offlineSyncStoreProvider = Provider<OfflineSyncStore>((ref) {
  return OfflineSyncStore(ref.watch(secureStorageProvider));
});

final connectivityStreamProvider = StreamProvider<bool>((ref) {
  final connectivity = Connectivity();
  return connectivity.onConnectivityChanged.map(
    (results) => results.any((r) => r != ConnectivityResult.none),
  );
});
