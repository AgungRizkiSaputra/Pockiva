import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/sync_status_badge.dart';
import '../../auth/application/auth_controller.dart';
import '../../gamification/application/gamification_controller.dart';
import '../../transactions/application/transactions_controller.dart';
import '../../transactions/domain/transaction_category.dart';
import '../../transactions/domain/transaction_item.dart';
import '../../transactions/presentation/quick_add_sheet.dart';
import '../../transactions/presentation/transaction_detail_sheet.dart';
import '../../transactions/presentation/transaction_list_tile.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final txState = ref.watch(transactionsControllerProvider);
    final gamificationState = ref.watch(gamificationControllerProvider);
    final profile = authState.profile;
    final summary = txState.effectiveSummary;
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    final isWide = MediaQuery.sizeOf(context).width >= AppTokens.tabletBreakpoint;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final target = profile?.savingsTarget ?? 0;
    final progressRatio = summary.progressRatio(target);
    final progressPct = summary.progressPercentage(target);
    final remaining = summary.remainingToTarget(target);
    final effectiveStreak = gamificationState.streak.effectiveStreak();
    final recentItems = txState.allTransactions.take(5).toList();

    final greeting = DateFormatter.greetingForHour(DateTime.now().hour);
    final userInitials = profile?.initials ?? 'U';
    final userDisplayName = profile?.firstName ?? 'Kamu';

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 74,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: Colors.transparent,
        leadingWidth: 62,
        leading: Padding(
          padding: const EdgeInsets.only(left: AppTokens.space16),
          child: Center(
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                ),
                borderRadius: BorderRadius.circular(13),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.28),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Center(
                    child: Text(
                      userInitials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 2,
                    bottom: 2,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? const Color(0xFF0F172A) : Colors.white,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        titleSpacing: AppTokens.space8,
        title: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$greeting, $userDisplayName',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              DateFormatter.formatDayMonthYear(DateTime.now()),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodySmall?.copyWith(
                color: palette.inkSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          if (effectiveStreak > 0)
            Padding(
              padding: const EdgeInsets.only(right: AppTokens.space8),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                onTap: () => context.go('/gamification'),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTokens.space12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? const [Color(0xFF331B0A), Color(0xFF431F0A)]
                          : const [Color(0xFFFFF7ED), Color(0xFFFFEDD5)],
                    ),
                    borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                    border: Border.all(
                      color: const Color(0xFFF97316).withValues(alpha: isDark ? 0.4 : 0.25),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF97316).withValues(alpha: 0.15),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.local_fire_department_rounded,
                        size: 16,
                        color: Color(0xFFEA580C),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '$effectiveStreak hari',
                        style: textTheme.labelMedium?.copyWith(
                          color: isDark ? const Color(0xFFFDBA74) : const Color(0xFFC2410C),
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // Sleek squircle Settings Button
          Container(
            width: 40,
            height: 40,
            margin: const EdgeInsets.only(right: AppTokens.space16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : palette.border.withValues(alpha: 0.8),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.3)
                      : const Color(0x0A000000),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: Tooltip(
                message: 'Pengaturan',
                child: InkWell(
                  key: const Key('settings_button'),
                  borderRadius: BorderRadius.circular(13),
                  onTap: () => context.push('/settings'),
                  child: Icon(
                    Icons.settings_outlined,
                    size: 20,
                    color: palette.inkPrimary,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: palette.sageText,
        onRefresh: () async {
          await ref.read(transactionsControllerProvider.notifier).syncPendingQueue();
          await Future.wait([
            ref.read(transactionsControllerProvider.notifier).refresh(),
            ref.read(gamificationControllerProvider.notifier).refresh(),
          ]);
        },
        child: _buildBody(
          context: context,
          ref: ref,
          txState: txState,
          isWide: isWide,
          heroCard: _SavingsHeroCard(
            totalBalance: summary.totalBalance,
            totalIncome: summary.totalSavings,
            totalExpense: summary.totalExpenses,
            targetTitle: profile?.savingsTargetTitle ?? 'Target Tabungan Utama',
            targetAmount: target,
            progressRatio: progressRatio,
            progressPct: progressPct,
            remaining: remaining,
            onViewProgress: () => context.go('/savings'),
          ),
          summaryCard: _MonthlyFlowCard(
            monthSavings: summary.monthSavings,
            monthExpenses: summary.monthExpenses,
            monthNet: summary.monthNet,
            onViewInsights: () => context.go('/insights'),
          ),
          recentSection: _RecentTransactionsSection(
            items: recentItems,
            isLoading: txState.isLoading,
            onViewAll: () => context.go('/history'),
            onQuickAddSaving: () => QuickAddSheet.show(
              context,
              initialType: TransactionType.saving,
            ),
            onTapItem: (item) => TransactionDetailSheet.show(context, item),
          ),
        ),
      ),
    );
  }

  Widget _buildBody({
    required BuildContext context,
    required WidgetRef ref,
    required TransactionsState txState,
    required bool isWide,
    required Widget heroCard,
    required Widget summaryCard,
    required Widget recentSection,
  }) {
    if (txState.isLoading && txState.allTransactions.isEmpty) {
      return const AppLoadingView(message: 'Memuat ringkasan tabunganmu...');
    }

    if (txState.errorMessage != null && txState.allTransactions.isEmpty) {
      return AppErrorStateView(
        title: 'Tidak dapat memuat beranda',
        message: txState.errorMessage!,
        onRetry: () =>
            ref.read(transactionsControllerProvider.notifier).refresh(),
      );
    }

    final syncBanner = OfflineSyncBanner(
      pendingCount: txState.pendingCount,
      isSyncing: txState.isSyncingQueue,
      onSyncPressed: () =>
          ref.read(transactionsControllerProvider.notifier).syncPendingQueue(),
    );

    if (isWide) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(
          AppTokens.space24,
          AppTokens.space16,
          AppTokens.space24,
          AppTokens.space48,
        ),
        children: [
          syncBanner,
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 6,
                child: Column(
                  children: [
                    heroCard,
                    const SizedBox(height: AppTokens.space16),
                    summaryCard,
                  ],
                ),
              ),
              const SizedBox(width: AppTokens.space24),
              Expanded(
                flex: 5,
                child: recentSection,
              ),
            ],
          ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppTokens.space16,
        AppTokens.space12,
        AppTokens.space16,
        120, // Clean clearance above floating capsule nav
      ),
      children: [
        syncBanner,
        heroCard,
        const SizedBox(height: AppTokens.space16),
        summaryCard,
        const SizedBox(height: AppTokens.space24),
        recentSection,
      ],
    );
  }
}

/// The Sculptural Obsidian & Emerald Vault Card:
/// Real Total Balance (Income - Expense), target progress meter,
/// refined geometric accents, and high-impact tactile quick action bar.
class _SavingsHeroCard extends StatelessWidget {
  const _SavingsHeroCard({
    required this.totalBalance,
    required this.totalIncome,
    required this.totalExpense,
    required this.targetTitle,
    required this.targetAmount,
    required this.progressRatio,
    required this.progressPct,
    required this.remaining,
    required this.onViewProgress,
  });

  final double totalBalance;
  final double totalIncome;
  final double totalExpense;
  final String targetTitle;
  final double targetAmount;
  final double progressRatio;
  final double progressPct;
  final double remaining;
  final VoidCallback onViewProgress;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? const [
                      Color(0xFF131A26),
                      Color(0xFF0A231A),
                    ]
                  : const [
                      Color(0xFF0F172A),
                      Color(0xFF064E3B),
                    ],
            ),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : palette.sageBorder,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0A231A).withValues(alpha: isDark ? 0.6 : 0.28),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppTokens.space20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Brand Holographic Badge + Security Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        // Holographic Vault Prism Emblem
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF34D399), Color(0xFF059669)],
                            ),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF10B981).withValues(alpha: 0.4),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.all_inclusive_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'VAULT SECURED',
                              style: textTheme.labelSmall?.copyWith(
                                color: const Color(0xFF34D399),
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                fontSize: 10,
                              ),
                            ),
                            Text(
                              'Tabungan Utama',
                              style: textTheme.bodySmall?.copyWith(
                                color: Colors.white70,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppTokens.radiusFull),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF34D399),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'AKTIF',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.0,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTokens.space24),

                // Balance Label & Amount Display
                Row(
                  children: [
                    Text(
                      'Total Saldo Tabungan',
                      style: textTheme.bodySmall?.copyWith(
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.3,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF34D399).withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        'IDR',
                        style: TextStyle(
                          color: Color(0xFF34D399),
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    CurrencyFormatter.formatIdr(totalBalance),
                    key: const Key('dashboard_total_balance'),
                    style: textTheme.displaySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.2,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                const SizedBox(height: AppTokens.space20),

                // Target Progress Section inside card
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        targetTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF34D399).withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        targetAmount > 0
                            ? '${progressPct.toStringAsFixed(0)}%'
                            : '0%',
                        key: const Key('dashboard_progress_percent'),
                        style: textTheme.labelSmall?.copyWith(
                          color: const Color(0xFF34D399),
                          fontWeight: FontWeight.w800,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppTokens.radiusFull),
                  child: SizedBox(
                    height: 6,
                    child: LinearProgressIndicator(
                      value: progressRatio,
                      backgroundColor: Colors.white.withValues(alpha: 0.12),
                      valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF34D399)),
                    ),
                  ),
                ),
                const SizedBox(height: AppTokens.space16),

                // Card Footer: Sub-stat metrics
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        targetAmount > 0
                            ? 'Target: ${CurrencyFormatter.formatCompactIdr(targetAmount)}'
                            : 'Target belum diatur',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: Colors.white60,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: onViewProgress,
                      borderRadius: BorderRadius.circular(4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            targetAmount > 0 && remaining > 0
                                ? 'Sisa ${CurrencyFormatter.formatCompactIdr(remaining)}'
                                : 'Detail Progres',
                            style: textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF60A5FA),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 14,
                            color: Color(0xFF60A5FA),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
  }
}

class _MonthlyFlowCard extends StatelessWidget {
  const _MonthlyFlowCard({
    required this.monthSavings,
    required this.monthExpenses,
    required this.monthNet,
    required this.onViewInsights,
  });

  final double monthSavings;
  final double monthExpenses;
  final double monthNet;
  final VoidCallback onViewInsights;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : palette.border,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.3) : const Color(0x08000000),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onViewInsights,
          child: Padding(
            padding: const EdgeInsets.all(AppTokens.space16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: palette.sageFill,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'ARUS KAS BULAN INI',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.labelSmall?.copyWith(
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.w800,
                                color: palette.inkSecondary,
                                fontSize: 10,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Lihat Insight',
                          style: textTheme.bodySmall?.copyWith(
                            color: palette.linkAccent,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 16,
                          color: palette.linkAccent,
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppTokens.space16),

                // Bento 2-column: In vs Out
                Row(
                  children: [
                    // Masuk Bento
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(AppTokens.space12),
                        decoration: BoxDecoration(
                          color: palette.successBg.withValues(alpha: isDark ? 0.35 : 0.7),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: palette.success.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: palette.success.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.arrow_downward_rounded,
                                    size: 14,
                                    color: palette.success,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Pemasukan',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: textTheme.bodySmall?.copyWith(
                                      color: palette.inkSecondary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              CurrencyFormatter.formatIdr(monthSavings),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.titleMedium?.copyWith(
                                color: palette.success,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTokens.space10),

                    // Keluar Bento
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(AppTokens.space12),
                        decoration: BoxDecoration(
                          color: palette.dangerBg.withValues(alpha: isDark ? 0.3 : 0.6),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: palette.danger.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: palette.danger.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.arrow_upward_rounded,
                                    size: 14,
                                    color: palette.danger,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    'Pengeluaran',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: textTheme.bodySmall?.copyWith(
                                      color: palette.inkSecondary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              CurrencyFormatter.formatIdr(monthExpenses),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.titleMedium?.copyWith(
                                color: palette.danger,
                                fontWeight: FontWeight.w900,
                                fontSize: 16,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTokens.space12),

                // Net summary pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: (monthNet >= 0 ? palette.successBg : palette.dangerBg)
                        .withValues(alpha: isDark ? 0.4 : 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          monthNet >= 0 ? 'Surplus Bersih:' : 'Defisit Bersih:',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: textTheme.bodySmall?.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: palette.inkSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        CurrencyFormatter.formatIdr(monthNet, showSign: true),
                        style: textTheme.labelMedium?.copyWith(
                          color: monthNet >= 0 ? palette.success : palette.danger,
                          fontWeight: FontWeight.w900,
                          fontSize: 12,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentTransactionsSection extends StatelessWidget {
  const _RecentTransactionsSection({
    required this.items,
    required this.isLoading,
    required this.onViewAll,
    required this.onQuickAddSaving,
    required this.onTapItem,
  });

  final List<TransactionItem> items;
  final bool isLoading;
  final VoidCallback onViewAll;
  final VoidCallback onQuickAddSaving;
  final ValueChanged<TransactionItem> onTapItem;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final palette = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Aktivitas Terbaru',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  fontSize: 17,
                ),
              ),
            ),
            if (items.isNotEmpty)
              TextButton(
                onPressed: onViewAll,
                child: const Text('Lihat Semua'),
              ),
          ],
        ),
        const SizedBox(height: AppTokens.space8),
        if (items.isEmpty)
          Container(
            padding: const EdgeInsets.all(AppTokens.space24),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : palette.border,
              ),
            ),
            child: AppEmptyStateView(
              icon: Icons.savings_outlined,
              title: 'Mulai catatan pertamamu',
              description:
                  'Belum ada transaksi tercatat. Tekan tombol biru di pojok kanan bawah atau mulai dengan setoran tabungan pertamamu.',
              actionLabel: 'Catat Tabungan Pertama',
              onAction: onQuickAddSaving,
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : palette.border,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.black.withValues(alpha: 0.3) : const Color(0x06000000),
                  blurRadius: 16,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                for (int i = 0; i < items.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      indent: 68,
                      endIndent: 16,
                      color: palette.borderSubtle,
                    ),
                  TransactionListTile(
                    item: items[i],
                    onTap: () => onTapItem(items[i]),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
