import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/sync_status_badge.dart';
import '../application/transactions_controller.dart';
import '../domain/transaction_category.dart';
import '../domain/transaction_item.dart';
import 'quick_add_sheet.dart';
import 'transaction_detail_sheet.dart';
import 'transaction_list_tile.dart';

class TransactionHistoryScreen extends ConsumerStatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  ConsumerState<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState
    extends ConsumerState<TransactionHistoryScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 240) {
      ref.read(transactionsControllerProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final txState = ref.watch(transactionsControllerProvider);
    final items = txState.allTransactions;
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Riwayat Transaksi',
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: Column(
        children: [
          // Filter Tabs / Chips
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTokens.space16,
              AppTokens.space8,
              AppTokens.space16,
              AppTokens.space12,
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label: 'Semua',
                    selected: txState.typeFilter == null,
                    onTap: () => ref
                        .read(transactionsControllerProvider.notifier)
                        .setTypeFilter(null),
                  ),
                  const SizedBox(width: AppTokens.space8),
                  _FilterChip(
                    label: 'Tabungan / Masuk',
                    selected: txState.typeFilter == TransactionType.saving,
                    onTap: () => ref
                        .read(transactionsControllerProvider.notifier)
                        .setTypeFilter(TransactionType.saving),
                  ),
                  const SizedBox(width: AppTokens.space8),
                  _FilterChip(
                    label: 'Pengeluaran',
                    selected: txState.typeFilter == TransactionType.expense,
                    onTap: () => ref
                        .read(transactionsControllerProvider.notifier)
                        .setTypeFilter(TransactionType.expense),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _buildBody(context, txState, items, palette),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    TransactionsState txState,
    List<TransactionItem> items,
    AppColorPalette palette,
  ) {
    if (txState.isLoading && items.isEmpty) {
      return const AppLoadingView(message: 'Memuat riwayat transaksi...');
    }

    if (txState.errorMessage != null && items.isEmpty) {
      return AppErrorStateView(
        title: 'Gagal memuat riwayat',
        message: txState.errorMessage!,
        onRetry: () =>
            ref.read(transactionsControllerProvider.notifier).refresh(),
      );
    }

    if (items.isEmpty) {
      return AppEmptyStateView(
        icon: Icons.receipt_long_outlined,
        title: txState.typeFilter == null
            ? 'Belum ada transaksi'
            : 'Belum ada transaksi ${txState.typeFilter!.label.toLowerCase()}',
        description:
            'Catat tabungan atau pengeluaran pertamamu dalam 5 detik untuk mulai membangun riwayat keuangan.',
        actionLabel: 'Catat Transaksi',
        onAction: () => QuickAddSheet.show(
          context,
          initialType: txState.typeFilter ?? TransactionType.expense,
        ),
      );
    }

    final grouped = _groupByDate(items);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RefreshIndicator(
      color: palette.sageText,
      onRefresh: () async {
        await ref.read(transactionsControllerProvider.notifier).syncPendingQueue();
        await ref.read(transactionsControllerProvider.notifier).refresh();
      },
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(
          AppTokens.space16,
          AppTokens.space4,
          AppTokens.space16,
          120, // Clear floating capsule nav
        ),
        children: [
          OfflineSyncBanner(
            pendingCount: txState.pendingCount,
            isSyncing: txState.isSyncingQueue,
            onSyncPressed: () => ref
                .read(transactionsControllerProvider.notifier)
                .syncPendingQueue(),
          ),
          for (final entry in grouped.entries) ...[
            Padding(
              padding: const EdgeInsets.only(
                top: AppTokens.space16,
                bottom: AppTokens.space8,
                left: AppTokens.space4,
              ),
              child: Text(
                entry.key,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: palette.inkSecondary,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: palette.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: palette.border.withValues(alpha: 0.8),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.3)
                        : const Color(0x06000000),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  for (int i = 0; i < entry.value.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        indent: 68,
                        endIndent: 16,
                        color: palette.border.withValues(alpha: 0.6),
                      ),
                    TransactionListTile(
                      item: entry.value[i],
                      onTap: () =>
                          TransactionDetailSheet.show(context, entry.value[i]),
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (txState.isLoadingMore)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppTokens.space24),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2.4)),
            )
          else if (txState.hasMore)
            Padding(
              padding: const EdgeInsets.only(top: AppTokens.space16),
              child: OutlinedButton(
                onPressed: () =>
                    ref.read(transactionsControllerProvider.notifier).loadMore(),
                child: const Text('Muat Lebih Banyak'),
              ),
            ),
        ],
      ),
    );
  }

  Map<String, List<TransactionItem>> _groupByDate(List<TransactionItem> list) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final map = <String, List<TransactionItem>>{};

    for (final item in list) {
      final txDate = DateTime(
        item.occurredAt.year,
        item.occurredAt.month,
        item.occurredAt.day,
      );

      String groupTitle;
      if (txDate == today) {
        groupTitle = 'Hari Ini';
      } else if (txDate == yesterday) {
        groupTitle = 'Kemarin';
      } else {
        groupTitle = DateFormatter.formatDayMonthYear(item.occurredAt);
      }

      map.putIfAbsent(groupTitle, () => []).add(item);
    }

    return map;
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? palette.fabAccent
                : (isDark ? palette.surface : palette.surfaceSubtle.withValues(alpha: 0.6)),
            borderRadius: BorderRadius.circular(AppTokens.radiusPill),
            border: Border.all(
              color: selected ? palette.fabAccent : palette.border.withValues(alpha: 0.7),
              width: 1,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected
                  ? Colors.white
                  : (isDark ? palette.inkPrimary : palette.inkSecondary),
            ),
          ),
        ),
      ),
    );
  }
}
