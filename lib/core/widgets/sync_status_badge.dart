import 'package:flutter/material.dart';
import '../../features/transactions/domain/transaction_item.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';

/// Functional status label shown only for non-synced offline transactions.
class SyncStatusTag extends StatelessWidget {
  const SyncStatusTag({
    super.key,
    required this.status,
  });

  final SyncStatus status;

  @override
  Widget build(BuildContext context) {
    if (status == SyncStatus.synced) return const SizedBox.shrink();

    final palette = context.palette;
    final (Color fg, Color bg, IconData icon) = switch (status) {
      SyncStatus.localOnly => (
          palette.warning,
          palette.warningBg,
          Icons.save_outlined,
        ),
      SyncStatus.pendingSync => (
          palette.warning,
          palette.warningBg,
          Icons.cloud_upload_outlined,
        ),
      SyncStatus.syncFailed => (
          palette.danger,
          palette.dangerBg,
          Icons.sync_problem_outlined,
        ),
      SyncStatus.synced => (
          palette.success,
          palette.successBg,
          Icons.cloud_done_outlined,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.space8,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTokens.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

/// Banner surfacing pending offline queue count with one-tap retry.
class OfflineSyncBanner extends StatelessWidget {
  const OfflineSyncBanner({
    super.key,
    required this.pendingCount,
    required this.isSyncing,
    required this.onSyncPressed,
  });

  final int pendingCount;
  final bool isSyncing;
  final VoidCallback onSyncPressed;

  @override
  Widget build(BuildContext context) {
    if (pendingCount <= 0) return const SizedBox.shrink();

    final palette = context.palette;
    return Container(
      margin: const EdgeInsets.only(bottom: AppTokens.space16),
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.space16,
        vertical: AppTokens.space12,
      ),
      decoration: BoxDecoration(
        color: palette.warningBg,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(color: palette.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_outlined, size: 20, color: palette.warning),
          const SizedBox(width: AppTokens.space12),
          Expanded(
            child: Text(
              '$pendingCount transaksi menunggu sinkronisasi ke server.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: palette.warning,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          TextButton(
            onPressed: isSyncing ? null : onSyncPressed,
            child: isSyncing
                ? SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: palette.warning,
                    ),
                  )
                : const Text('Sinkronkan'),
          ),
        ],
      ),
    );
  }
}
