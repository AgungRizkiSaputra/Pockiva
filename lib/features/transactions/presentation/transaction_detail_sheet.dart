import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../application/transactions_controller.dart';
import '../domain/transaction_item.dart';
import 'quick_add_sheet.dart';

class TransactionDetailSheet extends ConsumerStatefulWidget {
  const TransactionDetailSheet({
    super.key,
    required this.item,
  });

  final TransactionItem item;

  static Future<void> show(BuildContext context, TransactionItem item) {
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (_) => TransactionDetailSheet(item: item),
    );
  }

  @override
  ConsumerState<TransactionDetailSheet> createState() =>
      _TransactionDetailSheetState();
}

class _TransactionDetailSheetState
    extends ConsumerState<TransactionDetailSheet> {
  bool _deleting = false;

  Future<void> _confirmAndDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        ),
        title: const Text('Hapus Transaksi?'),
        content: Text(
          'Transaksi ${widget.item.categoryInfo.label} sebesar '
          '${CurrencyFormatter.formatIdr(widget.item.amount)} akan dihapus permanen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.palette.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _deleting = true);

    final err = await ref
        .read(transactionsControllerProvider.notifier)
        .deleteTransaction(widget.item);

    if (!mounted) return;
    setState(() => _deleting = false);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(err ?? 'Transaksi berhasil dihapus.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    final item = widget.item;
    final category = item.categoryInfo;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.space24,
        AppTokens.space12,
        AppTokens.space24,
        AppTokens.space28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: palette.borderSubtle,
                borderRadius: BorderRadius.circular(AppTokens.radiusFull),
              ),
            ),
          ),
          const SizedBox(height: AppTokens.space20),
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: item.isSaving ? palette.sageSurface : palette.surfaceSubtle,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: item.isSaving ? palette.sageBorder : palette.borderSubtle,
                  ),
                ),
                child: Icon(
                  category.icon,
                  size: 24,
                  color: item.isSaving ? palette.sageText : palette.inkPrimary,
                ),
              ),
              const SizedBox(width: AppTokens.space16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      category.label,
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.type.label,
                      style: textTheme.bodySmall?.copyWith(
                        color: palette.inkSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.space20),
          Text(
            item.isSaving
                ? '+${CurrencyFormatter.formatIdr(item.amount)}'
                : '-${CurrencyFormatter.formatIdr(item.amount)}',
            style: textTheme.displaySmall?.copyWith(
              color: item.isSaving ? palette.success : palette.inkPrimary,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: AppTokens.space24),
          Container(
            padding: const EdgeInsets.all(AppTokens.space16),
            decoration: BoxDecoration(
              color: palette.surfaceSubtle,
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
              border: Border.all(color: palette.borderSubtle),
            ),
            child: Column(
              children: [
                _DetailRow(
                  label: 'Tanggal',
                  value:
                      '${DateFormatter.formatDayMonthYear(item.occurredAt)}, ${DateFormatter.formatTime(item.occurredAt)}',
                ),
                const Divider(height: AppTokens.space24),
                _DetailRow(
                  label: 'Status Sinkronisasi',
                  value: item.syncStatus.label,
                ),
                if (item.note?.isNotEmpty == true) ...[
                  const Divider(height: AppTokens.space24),
                  _DetailRow(label: 'Catatan', value: item.note!),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppTokens.space28),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _deleting
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          QuickAddSheet.show(context, editingItem: item);
                        },
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Ubah'),
                ),
              ),
              const SizedBox(width: AppTokens.space12),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: palette.danger,
                    side: BorderSide(color: palette.danger.withValues(alpha: 0.4)),
                  ),
                  onPressed: _deleting ? null : _confirmAndDelete,
                  icon: _deleting
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: palette.danger,
                          ),
                        )
                      : const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Hapus'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(width: AppTokens.space16),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ],
    );
  }
}
