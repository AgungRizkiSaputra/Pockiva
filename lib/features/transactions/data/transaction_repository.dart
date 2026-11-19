import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/security/error_mapper.dart';
import '../../auth/data/auth_repository.dart';
import '../../insights/domain/financial_summary.dart';
import '../domain/transaction_category.dart';
import '../domain/transaction_item.dart';

abstract class TransactionRepository {
  Future<List<TransactionItem>> fetchPage({
    required int page,
    required int pageSize,
    TransactionType? typeFilter,
  });

  Future<TransactionItem> createTransaction({
    required String clientId,
    required TransactionType type,
    required double amount,
    required String category,
    String? note,
    required DateTime occurredAt,
  });

  Future<TransactionItem> updateTransaction({
    required String id,
    required TransactionType type,
    required double amount,
    required String category,
    String? note,
    required DateTime occurredAt,
  });

  Future<void> deleteTransaction(String id);

  Future<FinancialSummary> fetchFinancialSummary({int months = 6});
}

class SupabaseTransactionRepository implements TransactionRepository {
  SupabaseTransactionRepository(this._client);

  final SupabaseClient _client;

  @override
  Future<List<TransactionItem>> fetchPage({
    required int page,
    required int pageSize,
    TransactionType? typeFilter,
  }) async {
    final from = page * pageSize;
    final to = from + pageSize - 1;

    try {
      var query = _client.from('transactions').select(
            'id, user_id, client_id, type, amount, category, note, occurred_at, created_at',
          );

      if (typeFilter != null) {
        query = query.eq('type', typeFilter.value);
      }

      final rows = await query
          .order('occurred_at', ascending: false)
          .order('created_at', ascending: false)
          .range(from, to);

      return (rows as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(
            (r) => TransactionItem.fromJson(
              r,
              defaultSyncStatus: SyncStatus.synced,
            ),
          )
          .toList();
    } catch (e) {
      throw AppException('TX_FETCH_FAILED', ErrorMapper.toUserMessage(e));
    }
  }

  @override
  Future<TransactionItem> createTransaction({
    required String clientId,
    required TransactionType type,
    required double amount,
    required String category,
    String? note,
    required DateTime occurredAt,
  }) async {
    try {
      // Uses server-validated Edge Function `transactions-api` (PRD Section 18)
      // with idempotent client_id to prevent duplicate submissions.
      final response = await _client.functions.invoke(
        'transactions-api',
        body: {
          'client_id': clientId,
          'type': type.value,
          'amount': amount,
          'category': category,
          'note': note,
          'occurred_at': occurredAt.toUtc().toIso8601String(),
        },
      );

      if (response.status >= 400) {
        final data = response.data;
        final msg = (data is Map && data['message'] is String)
            ? data['message'] as String
            : 'Gagal mencatat transaksi.';
        final code = (data is Map && data['error'] is String)
            ? data['error'] as String
            : 'TX_CREATE_FAILED';
        throw AppException(code, msg);
      }

      final payload = response.data as Map<String, dynamic>;
      final txJson = payload['transaction'] as Map<String, dynamic>;
      return TransactionItem.fromJson(
        txJson,
        defaultSyncStatus: SyncStatus.synced,
      );
    } on AppException {
      rethrow;
    } catch (e) {
      if (ErrorMapper.isNetworkError(e)) {
        rethrow;
      }
      throw AppException('TX_CREATE_FAILED', ErrorMapper.toUserMessage(e));
    }
  }

  @override
  Future<TransactionItem> updateTransaction({
    required String id,
    required TransactionType type,
    required double amount,
    required String category,
    String? note,
    required DateTime occurredAt,
  }) async {
    try {
      final row = await _client
          .from('transactions')
          .update({
            'type': type.value,
            'amount': amount,
            'category': category,
            'note': note,
            'occurred_at': occurredAt.toUtc().toIso8601String(),
          })
          .eq('id', id)
          .select(
            'id, user_id, client_id, type, amount, category, note, occurred_at, created_at',
          )
          .single();

      return TransactionItem.fromJson(row, defaultSyncStatus: SyncStatus.synced);
    } catch (e) {
      throw AppException('TX_UPDATE_FAILED', ErrorMapper.toUserMessage(e));
    }
  }

  @override
  Future<void> deleteTransaction(String id) async {
    try {
      await _client.from('transactions').delete().eq('id', id);
    } catch (e) {
      throw AppException('TX_DELETE_FAILED', ErrorMapper.toUserMessage(e));
    }
  }

  @override
  Future<FinancialSummary> fetchFinancialSummary({int months = 6}) async {
    try {
      final result = await _client.rpc<Map<String, dynamic>>(
        'get_financial_summary',
        params: {'p_months': months},
      );
      return FinancialSummary.fromRpcJson(result);
    } catch (e) {
      if (ErrorMapper.isNetworkError(e)) rethrow;
      throw AppException('SUMMARY_FETCH_FAILED', ErrorMapper.toUserMessage(e));
    }
  }
}

final transactionRepositoryProvider = Provider<TransactionRepository?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return null;
  return SupabaseTransactionRepository(client);
});
