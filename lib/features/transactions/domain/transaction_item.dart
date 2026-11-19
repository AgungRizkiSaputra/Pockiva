import 'package:flutter/foundation.dart';
import 'transaction_category.dart';

/// Clearly distinguishes local-only, pending-sync, failed-sync, and server-synced records.
enum SyncStatus {
  synced('synced', 'Tersinkronisasi'),
  pendingSync('pending_sync', 'Menunggu sinkronisasi'),
  localOnly('local_only', 'Tersimpan lokal'),
  syncFailed('sync_failed', 'Gagal sinkronisasi');

  const SyncStatus(this.value, this.label);

  final String value;
  final String label;

  static SyncStatus fromValue(String? raw) {
    for (final s in SyncStatus.values) {
      if (s.value == raw) return s;
    }
    return SyncStatus.synced;
  }
}

@immutable
class TransactionItem {
  const TransactionItem({
    required this.id,
    required this.userId,
    this.clientId,
    required this.type,
    required this.amount,
    required this.category,
    this.note,
    required this.occurredAt,
    required this.createdAt,
    this.syncStatus = SyncStatus.synced,
  });

  final String id;
  final String userId;
  final String? clientId;
  final TransactionType type;
  final double amount;
  final String category;
  final String? note;
  final DateTime occurredAt;
  final DateTime createdAt;
  final SyncStatus syncStatus;

  TransactionCategory get categoryInfo =>
      TransactionCategory.byCode(category, fallbackType: type);

  bool get isSaving => type == TransactionType.saving;

  factory TransactionItem.fromJson(
    Map<String, dynamic> json, {
    SyncStatus defaultSyncStatus = SyncStatus.synced,
  }) {
    final occurredRaw = json['occurred_at'] ?? json['created_at'];
    final createdRaw = json['created_at'] ?? occurredRaw;
    return TransactionItem(
      id: json['id'] as String,
      userId: (json['user_id'] as String?) ?? '',
      clientId: json['client_id'] as String?,
      type: TransactionType.fromValue((json['type'] as String?) ?? 'expense'),
      amount: _toDouble(json['amount']),
      category: (json['category'] as String?) ?? 'other',
      note: json['note'] as String?,
      occurredAt: DateTime.parse(occurredRaw.toString()).toLocal(),
      createdAt: DateTime.parse(createdRaw.toString()).toLocal(),
      syncStatus: json['sync_status'] != null
          ? SyncStatus.fromValue(json['sync_status'] as String?)
          : defaultSyncStatus,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'client_id': clientId,
      'type': type.value,
      'amount': amount,
      'category': category,
      'note': note,
      'occurred_at': occurredAt.toUtc().toIso8601String(),
      'created_at': createdAt.toUtc().toIso8601String(),
      'sync_status': syncStatus.value,
    };
  }

  TransactionItem copyWith({
    String? id,
    TransactionType? type,
    double? amount,
    String? category,
    String? note,
    bool clearNote = false,
    DateTime? occurredAt,
    SyncStatus? syncStatus,
  }) {
    return TransactionItem(
      id: id ?? this.id,
      userId: userId,
      clientId: clientId,
      type: type ?? this.type,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      note: clearNote ? null : (note ?? this.note),
      occurredAt: occurredAt ?? this.occurredAt,
      createdAt: createdAt,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  static double _toDouble(dynamic val) {
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0;
    return 0;
  }
}
