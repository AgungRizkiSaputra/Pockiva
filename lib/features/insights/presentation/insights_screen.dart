import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/application/auth_controller.dart';
import '../../transactions/application/transactions_controller.dart';
import '../../transactions/domain/transaction_category.dart';
import '../../transactions/presentation/quick_add_sheet.dart';
import '../domain/financial_summary.dart';

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  TransactionType _categoryTab = TransactionType.expense;

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(authControllerProvider).profile;
    final txState = ref.watch(transactionsControllerProvider);
    final summary = txState.effectiveSummary;
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final hasAnyData = summary.totalSavings > 0 || summary.totalExpenses > 0;
    final insights = summary.deriveInsights(
      savingsTarget: profile?.savingsTarget ?? 0,
      targetDeadline: profile?.savingsTargetDeadline,
    );
    final activeCategories = _categoryTab == TransactionType.expense
        ? summary.expenseCategories
        : summary.savingCategories;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Smart Budget Insights',
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: txState.isLoading && !hasAnyData
          ? const AppLoadingView(message: 'Menganalisis tren keuanganmu...')
          : !hasAnyData
              ? AppEmptyStateView(
                  icon: Icons.bar_chart_rounded,
                  title: 'Belum cukup data untuk analisis',
                  description:
                      'Catat pengeluaran atau setoran tabunganmu terlebih dahulu. Grafik tren bulanan dan ringkasan kategori dihitung otomatis dari data aslimu.',
                  actionLabel: 'Catat Transaksi Pertama',
                  onAction: () => QuickAddSheet.show(context),
                )
              : RefreshIndicator(
                  color: palette.sageText,
                  onRefresh: () =>
                      ref.read(transactionsControllerProvider.notifier).refresh(),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppTokens.space16,
                      AppTokens.space12,
                      AppTokens.space16,
                      120, // Clear floating capsule nav
                    ),
                    children: [
                      // Monthly Trend Grouped Bar Chart
                      Text(
                        'Tren Tabungan vs Pengeluaran (6 Bulan)',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: AppTokens.space8),
                      Container(
                        decoration: BoxDecoration(
                          color: palette.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: palette.border.withValues(alpha: 0.8),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isDark
                                  ? Colors.black.withValues(alpha: 0.3)
                                  : const Color(0x08000000),
                              blurRadius: 14,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(AppTokens.space16),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                _LegendDot(
                                  color: palette.sageFill,
                                  label: 'Tabungan',
                                ),
                                const SizedBox(width: AppTokens.space16),
                                _LegendDot(
                                  color: palette.danger,
                                  label: 'Pengeluaran',
                                ),
                              ],
                            ),
                            const SizedBox(height: AppTokens.space16),
                            SizedBox(
                              height: 220,
                              child: _MonthlyComparisonBarChart(
                                trends: summary.monthlyTrends,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppTokens.space24),

                      // Smart Insights Cards (Strictly computed from real DB numbers)
                      if (insights.isNotEmpty) ...[
                        Text(
                          'Insight Finansial Aslimu',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: AppTokens.space8),
                        for (final insight in insights) ...[
                          Container(
                            margin: const EdgeInsets.only(bottom: AppTokens.space8),
                            decoration: BoxDecoration(
                              color: palette.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: palette.border.withValues(alpha: 0.8),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: isDark
                                      ? Colors.black.withValues(alpha: 0.2)
                                      : const Color(0x06000000),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(AppTokens.space16),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: BoxDecoration(
                                    color: insight.isPositive
                                        ? palette.successBg
                                        : palette.warningBg,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    insight.isPositive
                                        ? Icons.trending_up_rounded
                                        : Icons.info_outline_rounded,
                                    size: 20,
                                    color: insight.isPositive
                                        ? palette.success
                                        : palette.warning,
                                  ),
                                ),
                                const SizedBox(width: AppTokens.space12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        insight.title,
                                        style: textTheme.titleMedium?.copyWith(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        insight.detail,
                                        style: textTheme.bodySmall?.copyWith(
                                          color: palette.inkSecondary,
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: AppTokens.space16),
                      ],

                      // Category Breakdown for current month
                      Text(
                        'Distribusi Kategori Bulan Ini',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: AppTokens.space8),

                      // Filter Segmented Buttons
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<TransactionType>(
                          showSelectedIcon: false,
                          style: ButtonStyle(
                            visualDensity: VisualDensity.compact,
                            textStyle: WidgetStatePropertyAll(
                              textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                          segments: const [
                            ButtonSegment(
                              value: TransactionType.expense,
                              label: Text('Pengeluaran'),
                            ),
                            ButtonSegment(
                              value: TransactionType.saving,
                              label: Text('Tabungan'),
                            ),
                          ],
                          selected: {_categoryTab},
                          onSelectionChanged: (set) {
                            if (set.isNotEmpty) {
                              setState(() => _categoryTab = set.first);
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: AppTokens.space10),

                      Container(
                        decoration: BoxDecoration(
                          color: palette.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: palette.border.withValues(alpha: 0.8),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isDark
                                  ? Colors.black.withValues(alpha: 0.3)
                                  : const Color(0x06000000),
                              blurRadius: 12,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: activeCategories.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.all(AppTokens.space24),
                                child: Text(
                                  'Belum ada catatan ${_categoryTab.label.toLowerCase()} pada bulan ini.',
                                  textAlign: TextAlign.center,
                                  style: textTheme.bodyMedium?.copyWith(
                                    color: palette.inkSecondary,
                                  ),
                                ),
                              )
                            : Padding(
                                padding: const EdgeInsets.all(AppTokens.space16),
                                child: Column(
                                  children: [
                                    for (int i = 0;
                                        i < activeCategories.length;
                                        i++) ...[
                                      if (i > 0)
                                        const SizedBox(height: AppTokens.space16),
                                      _CategoryShareRow(
                                        category: activeCategories[i],
                                        barColor: _categoryTab == TransactionType.saving
                                            ? palette.sageFill
                                            : palette.danger,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _MonthlyComparisonBarChart extends StatelessWidget {
  const _MonthlyComparisonBarChart({required this.trends});

  final List<MonthlyTrendPoint> trends;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    if (trends.isEmpty) {
      return const Center(child: Text('Belum ada tren bulanan.'));
    }

    final maxVal = trends.fold<double>(
      0,
      (prev, el) => [prev, el.savings, el.expenses].reduce((a, b) => a > b ? a : b),
    );

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxVal > 0 ? maxVal * 1.15 : 1000000,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: palette.border.withValues(alpha: 0.5),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 54,
              getTitlesWidget: (val, _) => Text(
                CurrencyFormatter.formatCompactIdr(val),
                style: textTheme.labelSmall?.copyWith(
                  color: palette.inkSecondary,
                  fontSize: 10,
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, _) {
                final idx = val.toInt();
                if (idx < 0 || idx >= trends.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    DateFormatter.formatShortMonth(trends[idx].monthKey),
                    style: textTheme.labelSmall?.copyWith(
                      color: palette.inkSecondary,
                      fontSize: 10,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: [
          for (int i = 0; i < trends.length; i++)
            BarChartGroupData(
              x: i,
              barsSpace: 4,
              barRods: [
                BarChartRodData(
                  toY: trends[i].savings,
                  color: palette.sageFill,
                  width: 10,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
                BarChartRodData(
                  toY: trends[i].expenses,
                  color: palette.danger,
                  width: 10,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _CategoryShareRow extends StatelessWidget {
  const _CategoryShareRow({
    required this.category,
    required this.barColor,
  });

  final CategorySummary category;
  final Color barColor;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    final info = category.info;
    final pctString = (category.share * 100).toStringAsFixed(0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(info.icon, size: 16, color: palette.inkSecondary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                info.label,
                style: textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            Text(
              '$pctString% • ${CurrencyFormatter.formatIdr(category.total)}',
              style: textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: palette.inkPrimary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: category.share.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: palette.surfaceSubtle,
            valueColor: AlwaysStoppedAnimation<Color>(barColor),
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}
