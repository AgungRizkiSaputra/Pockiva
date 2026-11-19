import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/config/app_config.dart';
import '../../../core/security/error_mapper.dart';
import '../../../core/sync/offline_sync_service.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/application/auth_controller.dart';
import '../../gamification/application/gamification_controller.dart';
import '../../insights/domain/financial_summary.dart';
import '../data/transaction_repository.dart';
import '../domain/transaction_category.dart';
import '../domain/transaction_item.dart';

@immutable
class TransactionsState {
  const TransactionsState({
    this.syncedItems = const [],
    this.pendingItems = const [],
    this.summary = FinancialSummary.empty,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.isSubmitting = false,
    this.isSyncingQueue = false,
    this.hasMore = true,
    this.page = 0,
    this.typeFilter,
    this.errorMessage,
    this.isOfflineMode = false,
  });

  final List<TransactionItem> syncedItems;
  final List<TransactionItem> pendingItems;
  final FinancialSummary summary;
  final bool isLoading;
  final bool isLoadingMore;
  final bool isSubmitting;
  final bool isSyncingQueue;
  final bool hasMore;
  final int page;
  final TransactionType? typeFilter;
  final String? errorMessage;
  final bool isOfflineMode;

  /// Unified list showing pending/local items first, deduplicated by clientId.
  List<TransactionItem> get allTransactions {
    final syncedClientIds = syncedItems
        .map((e) => e.clientId)
        .whereType<String>()
        .toSet();

    final filteredPending = pendingItems.where((p) {
      if (p.clientId != null && syncedClientIds.contains(p.clientId)) {
        return false;
      }
      if (typeFilter != null && p.type != typeFilter) return false;
      return true;
    });

    final merged = [...filteredPending, ...syncedItems];
    merged.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    return merged;
  }

  /// Effective summary reflecting both server-confirmed totals and local pending entries.
  FinancialSummary get effectiveSummary {
    if (pendingItems.isEmpty) return summary;
    final syncedClientIds = syncedItems
        .map((e) => e.clientId)
        .whereType<String>()
        .toSet();
    final uniquePending = pendingItems
        .where((p) => p.clientId == null || !syncedClientIds.contains(p.clientId))
        .toList();
    if (uniquePending.isEmpty) return summary;

    final pendingDelta = FinancialSummary.fromTransactions(uniquePending);
    return FinancialSummary(
      totalSavings: summary.totalSavings + pendingDelta.totalSavings,
      totalExpenses: summary.totalExpenses + pendingDelta.totalExpenses,
      monthSavings: summary.monthSavings + pendingDelta.monthSavings,
      monthExpenses: summary.monthExpenses + pendingDelta.monthExpenses,
      monthlyTrends: _mergeMonthlyTrends(
        summary.monthlyTrends,
        pendingDelta.monthlyTrends,
      ),
      expenseCategories: summary.expenseCategories.isEmpty
          ? pendingDelta.expenseCategories
          : summary.expenseCategories,
      savingCategories: summary.savingCategories.isEmpty
          ? pendingDelta.savingCategories
          : summary.savingCategories,
    );
  }

  static List<MonthlyTrendPoint> _mergeMonthlyTrends(
    List<MonthlyTrendPoint> base,
    List<MonthlyTrendPoint> delta,
  ) {
    if (base.isEmpty) return delta;
    final deltaMap = {for (final d in delta) d.monthKey: d};
    return base.map((b) {
      final d = deltaMap[b.monthKey];
      if (d == null) return b;
      return MonthlyTrendPoint(
        monthKey: b.monthKey,
        savings: b.savings + d.savings,
        expenses: b.expenses + d.expenses,
      );
    }).toList();
  }

  int get pendingCount => pendingItems.length;

  TransactionsState copyWith({
    List<TransactionItem>? syncedItems,
    List<TransactionItem>? pendingItems,
    FinancialSummary? summary,
    bool? isLoading,
    bool? isLoadingMore,
    bool? isSubmitting,
    bool? isSyncingQueue,
    bool? hasMore,
    int? page,
    TransactionType? typeFilter,
    bool clearTypeFilter = false,
    String? errorMessage,
    bool clearError = false,
    bool? isOfflineMode,
  }) {
    return TransactionsState(
      syncedItems: syncedItems ?? this.syncedItems,
      pendingItems: pendingItems ?? this.pendingItems,
      summary: summary ?? this.summary,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isSyncingQueue: isSyncingQueue ?? this.isSyncingQueue,
      hasMore: hasMore ?? this.hasMore,
      page: page ?? this.page,
      typeFilter: clearTypeFilter ? null : (typeFilter ?? this.typeFilter),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isOfflineMode: isOfflineMode ?? this.isOfflineMode,
    );
  }
}

class CreateTransactionResult {
  const CreateTransactionResult({
    required this.success,
    required this.syncStatus,
    this.errorMessage,
  });

  final bool success;
  final SyncStatus syncStatus;
  final String? errorMessage;
}

class TransactionsController extends StateNotifier<TransactionsState> {
  TransactionsController({
    required TransactionRepository? repository,
    required OfflineSyncStore offlineStore,
    required String? userId,
    required VoidCallback onDataMutated,
  })  : _repository = repository,
        _offlineStore = offlineStore,
        _userId = userId,
        _onDataMutated = onDataMutated,
        super(const TransactionsState());

  final TransactionRepository? _repository;
  final OfflineSyncStore _offlineStore;
  final String? _userId;
  final VoidCallback _onDataMutated;
  final Uuid _uuid = const Uuid();
  final Set<String> _inFlightClientIds = <String>{};

  Future<void> initialize() async {
    if (_userId == null) return;

    state = state.copyWith(isLoading: true, clearError: true);

    // 1. Hydrate immediately from encrypted local cache for <2s perceived load
    final cachedSynced = await _offlineStore.loadCachedSyncedTransactions();
    final pendingQueue = await _offlineStore.loadPendingQueue();

    if (cachedSynced.isNotEmpty || pendingQueue.isNotEmpty) {
      state = state.copyWith(
        syncedItems: cachedSynced,
        pendingItems: pendingQueue,
        summary: FinancialSummary.fromTransactions(cachedSynced),
        isLoading: false,
      );
    }

    // 2. Refresh live data from Supabase and flush offline queue if online
    await refresh();
    if (pendingQueue.isNotEmpty) {
      unawaited(syncPendingQueue());
    }
  }

  Future<void> refresh({TransactionType? typeFilter, bool keepFilter = true}) async {
    final repo = _repository;
    if (repo == null || _userId == null) return;

    final activeFilter = keepFilter ? state.typeFilter : typeFilter;
    state = state.copyWith(
      isLoading: state.syncedItems.isEmpty,
      typeFilter: activeFilter,
      clearTypeFilter: !keepFilter && typeFilter == null,
      clearError: true,
    );

    try {
      final results = await Future.wait([
        repo.fetchPage(
          page: 0,
          pageSize: AppConfig.transactionPageSize,
          typeFilter: activeFilter,
        ),
        repo.fetchFinancialSummary(months: 6),
      ]);

      final items = results[0] as List<TransactionItem>;
      final summary = results[1] as FinancialSummary;

      if (activeFilter == null) {
        await _offlineStore.saveCachedSyncedTransactions(items);
      }

      state = state.copyWith(
        syncedItems: items,
        summary: summary,
        isLoading: false,
        page: 0,
        hasMore: items.length >= AppConfig.transactionPageSize,
        isOfflineMode: false,
        clearError: true,
      );
    } catch (e) {
      final isOffline = ErrorMapper.isNetworkError(e);
      state = state.copyWith(
        isLoading: false,
        isOfflineMode: isOffline,
        errorMessage: isOffline && state.syncedItems.isNotEmpty
            ? null
            : ErrorMapper.toUserMessage(e),
      );
    }
  }

  Future<void> setTypeFilter(TransactionType? filter) async {
    await refresh(typeFilter: filter, keepFilter: false);
  }

  Future<void> loadMore() async {
    final repo = _repository;
    if (repo == null || state.isLoadingMore || !state.hasMore || state.isLoading) {
      return;
    }

    state = state.copyWith(isLoadingMore: true);
    final nextPage = state.page + 1;

    try {
      final more = await repo.fetchPage(
        page: nextPage,
        pageSize: AppConfig.transactionPageSize,
        typeFilter: state.typeFilter,
      );

      final combined = [...state.syncedItems, ...more];
      state = state.copyWith(
        syncedItems: combined,
        page: nextPage,
        hasMore: more.length >= AppConfig.transactionPageSize,
        isLoadingMore: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingMore: false,
        errorMessage: ErrorMapper.toUserMessage(e),
      );
    }
  }

  /// Submits a transaction with idempotent clientId, duplicate-submission lock,
  /// and automatic encrypted offline queue fallback when network is unavailable.
  Future<CreateTransactionResult> createTransaction({
    required TransactionType type,
    required double amount,
    required String category,
    String? note,
    DateTime? occurredAt,
    String? explicitClientId,
    bool validateBalance = false,
  }) async {
    if (state.isSubmitting) {
      return const CreateTransactionResult(
        success: false,
        syncStatus: SyncStatus.localOnly,
        errorMessage: 'Transaksi sebelumnya masih diproses.',
      );
    }

    final clientId = explicitClientId ?? _uuid.v4();
    if (_inFlightClientIds.contains(clientId)) {
      return const CreateTransactionResult(
        success: false,
        syncStatus: SyncStatus.pendingSync,
        errorMessage: 'Transaksi duplikat dicegah.',
      );
    }

    if (validateBalance && type == TransactionType.expense) {
      final currentBalance = state.effectiveSummary.totalBalance;
      if (amount > currentBalance) {
        return CreateTransactionResult(
          success: false,
          syncStatus: SyncStatus.localOnly,
          errorMessage: currentBalance <= 0
              ? 'Saldo tabungan masih Rp 0. Catat setoran tabungan terlebih dahulu.'
              : 'Pengeluaran melebihi saldo tabungan yang tersedia (${CurrencyFormatter.formatIdr(currentBalance)}).',
        );
      }
    }

    final uid = _userId ?? 'local';
    final timestamp = occurredAt ?? DateTime.now();
    _inFlightClientIds.add(clientId);
    state = state.copyWith(isSubmitting: true, clearError: true);

    try {
      final repo = _repository;
      if (repo == null) {
        throw const AppException('NO_BACKEND', 'Backend belum terkonfigurasi.');
      }

      final created = await repo.createTransaction(
        clientId: clientId,
        type: type,
        amount: amount,
        category: category,
        note: note,
        occurredAt: timestamp,
      );

      final updatedSynced = [created, ...state.syncedItems];
      await _offlineStore.saveCachedSyncedTransactions(updatedSynced);
      state = state.copyWith(
        syncedItems: updatedSynced,
        isSubmitting: false,
        isOfflineMode: false,
      );

      // Re-fetch accurate DB aggregations & server-computed streaks/badges
      unawaited(refresh());
      _onDataMutated();

      return const CreateTransactionResult(
        success: true,
        syncStatus: SyncStatus.synced,
      );
    } catch (e) {
      if (ErrorMapper.isNetworkError(e)) {
        final localItem = TransactionItem(
          id: 'local_$clientId',
          userId: uid,
          clientId: clientId,
          type: type,
          amount: amount,
          category: category,
          note: note,
          occurredAt: timestamp,
          createdAt: timestamp,
          syncStatus: SyncStatus.localOnly,
        );

        final updatedQueue = await _offlineStore.enqueue(
          localItem.copyWith(syncStatus: SyncStatus.pendingSync),
        );
        state = state.copyWith(
          pendingItems: updatedQueue,
          isSubmitting: false,
          isOfflineMode: true,
        );

        return const CreateTransactionResult(
          success: true,
          syncStatus: SyncStatus.pendingSync,
        );
      }

      state = state.copyWith(isSubmitting: false);
      return CreateTransactionResult(
        success: false,
        syncStatus: SyncStatus.syncFailed,
        errorMessage: ErrorMapper.toUserMessage(e),
      );
    } finally {
      _inFlightClientIds.remove(clientId);
    }
  }

  Future<String?> updateTransaction({
    required TransactionItem original,
    required TransactionType type,
    required double amount,
    required String category,
    String? note,
    required DateTime occurredAt,
  }) async {
    final currentBalance = state.effectiveSummary.totalBalance;
    final balanceWithoutOriginal = original.type == TransactionType.expense
        ? currentBalance + original.amount
        : currentBalance - original.amount;
    if (type == TransactionType.expense && amount > balanceWithoutOriginal) {
      return balanceWithoutOriginal <= 0
          ? 'Saldo tabungan tidak mencukupi untuk pengeluaran ini.'
          : 'Pengeluaran melebihi saldo tabungan yang tersedia (${CurrencyFormatter.formatIdr(balanceWithoutOriginal)}).';
    }
    // Allow editing locally queued offline items cleanly
    if (original.syncStatus != SyncStatus.synced && original.clientId != null) {
      final updatedLocal = original.copyWith(
        type: type,
        amount: amount,
        category: category,
        note: note,
        clearNote: note == null,
        occurredAt: occurredAt,
      );
      final updatedQueue = await _offlineStore.enqueue(updatedLocal);
      state = state.copyWith(pendingItems: updatedQueue);
      return null;
    }

    final repo = _repository;
    if (repo == null) return 'Backend belum terkonfigurasi.';

    try {
      final updated = await repo.updateTransaction(
        id: original.id,
        type: type,
        amount: amount,
        category: category,
        note: note,
        occurredAt: occurredAt,
      );

      final nextList = state.syncedItems
          .map((item) => item.id == updated.id ? updated : item)
          .toList();
      state = state.copyWith(syncedItems: nextList);
      await _offlineStore.saveCachedSyncedTransactions(nextList);
      unawaited(refresh());
      _onDataMutated();
      return null;
    } catch (e) {
      return ErrorMapper.toUserMessage(e);
    }
  }

  Future<String?> deleteTransaction(TransactionItem item) async {
    if (item.syncStatus != SyncStatus.synced) {
      final updatedQueue =
          await _offlineStore.removeByClientId(item.clientId ?? item.id);
      state = state.copyWith(pendingItems: updatedQueue);
      return null;
    }

    final repo = _repository;
    if (repo == null) return 'Backend belum terkonfigurasi.';

    try {
      await repo.deleteTransaction(item.id);
      final nextList = state.syncedItems.where((t) => t.id != item.id).toList();
      state = state.copyWith(syncedItems: nextList);
      await _offlineStore.saveCachedSyncedTransactions(nextList);
      unawaited(refresh());
      _onDataMutated();
      return null;
    } catch (e) {
      return ErrorMapper.toUserMessage(e);
    }
  }

  /// Flushes queued offline transactions safely using idempotent client_id.
  Future<int> syncPendingQueue() async {
    final repo = _repository;
    if (repo == null || state.isSyncingQueue) return 0;

    final queue = await _offlineStore.loadPendingQueue();
    if (queue.isEmpty) {
      if (state.pendingItems.isNotEmpty) {
        state = state.copyWith(pendingItems: const []);
      }
      return 0;
    }

    state = state.copyWith(isSyncingQueue: true);
    int syncedCount = 0;

    for (final pending in queue) {
      final key = pending.clientId ?? pending.id;
      try {
        await repo.createTransaction(
          clientId: pending.clientId ?? _uuid.v4(),
          type: pending.type,
          amount: pending.amount,
          category: pending.category,
          note: pending.note,
          occurredAt: pending.occurredAt,
        );
        final remaining = await _offlineStore.removeByClientId(key);
        state = state.copyWith(pendingItems: remaining, isOfflineMode: false);
        syncedCount++;
      } catch (e) {
        if (ErrorMapper.isNetworkError(e)) {
          state = state.copyWith(isOfflineMode: true);
          break;
        }
        final marked = await _offlineStore.markStatus(key, SyncStatus.syncFailed);
        state = state.copyWith(pendingItems: marked);
      }
    }

    state = state.copyWith(isSyncingQueue: false);
    if (syncedCount > 0) {
      await refresh();
      _onDataMutated();
    }
    return syncedCount;
  }
}

final transactionsControllerProvider =
    StateNotifierProvider<TransactionsController, TransactionsState>((ref) {
  final authState = ref.watch(authControllerProvider);
  final userId = authState.status == AuthStatus.authenticated
      ? authState.profile?.id
      : null;

  final controller = TransactionsController(
    repository: ref.watch(transactionRepositoryProvider),
    offlineStore: ref.watch(offlineSyncStoreProvider),
    userId: userId,
    onDataMutated: () {
      ref.read(gamificationControllerProvider.notifier).refresh();
    },
  );

  if (userId != null) {
    unawaited(controller.initialize());
  }

  // Auto-sync offline queue whenever internet connectivity returns
  ref.listen<AsyncValue<bool>>(connectivityStreamProvider, (_, next) {
    if (next.valueOrNull == true && userId != null) {
      unawaited(controller.syncPendingQueue());
    }
  });

  return controller;
});
