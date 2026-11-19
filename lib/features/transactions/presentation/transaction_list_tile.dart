import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/sync_status_badge.dart';
import '../domain/transaction_item.dart';

class TransactionListTile extends StatelessWidget {
  const TransactionListTile({
    super.key,
    required this.item,
    required this.onTap,
  });

  final TransactionItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    final category = item.categoryInfo;
    final isSaving = item.isSaving;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.space16,
          vertical: AppTokens.space12,
        ),
        child: Row(
          children: [
            // Squircle Category Icon with soft tinted background
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSaving
                    ? palette.successBg.withValues(alpha: isDark ? 0.35 : 0.8)
                    : palette.dangerBg.withValues(alpha: isDark ? 0.35 : 0.8),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSaving
                      ? palette.success.withValues(alpha: 0.2)
                      : palette.danger.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Icon(
                category.icon,
                size: 20,
                color: isSaving ? palette.success : palette.danger,
              ),
            ),
            const SizedBox(width: AppTokens.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          category.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.titleMedium?.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                      if (item.syncStatus != SyncStatus.synced) ...[
                        const SizedBox(width: AppTokens.space8),
                        SyncStatusTag(status: item.syncStatus),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    item.note?.isNotEmpty == true
                        ? '${item.note!} • ${DateFormatter.formatTime(item.occurredAt)}'
                        : DateFormatter.formatTime(item.occurredAt),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodySmall?.copyWith(
                      color: palette.inkSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppTokens.space12),
            Text(
              isSaving
                  ? '+${CurrencyFormatter.formatIdr(item.amount)}'
                  : '-${CurrencyFormatter.formatIdr(item.amount)}',
              style: textTheme.titleMedium?.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: isSaving ? palette.success : palette.danger,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
