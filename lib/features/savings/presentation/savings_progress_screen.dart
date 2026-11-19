import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/state_views.dart';
import '../../auth/application/auth_controller.dart';
import '../../transactions/application/transactions_controller.dart';
import '../../transactions/domain/transaction_category.dart';
import '../../transactions/presentation/quick_add_sheet.dart';

class SavingsProgressScreen extends ConsumerWidget {
  const SavingsProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(authControllerProvider).profile;
    final txState = ref.watch(transactionsControllerProvider);
    final summary = txState.effectiveSummary;
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final target = profile?.savingsTarget ?? 0;
    final currentBalance = summary.totalBalance;
    final ratio = summary.progressRatio(target);
    final pct = summary.progressPercentage(target);
    final remaining = summary.remainingToTarget(target);

    final deadline = profile?.savingsTargetDeadline;
    int? daysLeft;
    double? dailyNeeded;
    if (deadline != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      daysLeft = deadline.difference(today).inDays;
      if (daysLeft > 0 && remaining > 0) {
        dailyNeeded = remaining / daysLeft;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Progres Tabungan',
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: profile == null
                ? null
                : () => _showEditTargetSheet(context, ref),
            icon: const Icon(Icons.edit_outlined, size: 16),
            label: const Text('Ubah Target'),
          ),
          const SizedBox(width: AppTokens.space8),
        ],
      ),
      body: txState.isLoading && txState.allTransactions.isEmpty
          ? const AppLoadingView(message: 'Menghitung progres tabungan...')
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
                  // Main Target Card
                  Container(
                    decoration: BoxDecoration(
                      color: palette.surface,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: palette.border.withValues(alpha: 0.8),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isDark
                              ? Colors.black.withValues(alpha: 0.35)
                              : const Color(0x0C000000),
                          blurRadius: 18,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(AppTokens.space24),
                    child: Column(
                      children: [
                        Text(
                          profile?.savingsTargetTitle ?? 'Target Tabungan Utama',
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        if (deadline != null) ...[
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: palette.surfaceSubtle.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                            ),
                            child: Text(
                              'Tenggat: ${DateFormatter.formatDayMonthYear(deadline)} ($daysLeft hari lagi)',
                              style: textTheme.bodySmall?.copyWith(
                                color: palette.inkSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: AppTokens.space24),

                        // Circular Progress Gauge
                        SizedBox(
                          height: 190,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              PieChart(
                                PieChartData(
                                  startDegreeOffset: -90,
                                  sectionsSpace: 0,
                                  centerSpaceRadius: 68,
                                  sections: [
                                    PieChartSectionData(
                                      value: ratio <= 0 ? 0.001 : ratio * 100,
                                      color: palette.sageFill,
                                      radius: 18,
                                      showTitle: false,
                                    ),
                                    PieChartSectionData(
                                      value: ((1 - ratio) * 100).clamp(0.0, 100.0),
                                      color: palette.surfaceSubtle,
                                      radius: 18,
                                      showTitle: false,
                                    ),
                                  ],
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${pct.toStringAsFixed(pct >= 10 ? 0 : 1)}%',
                                    style: textTheme.displaySmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: palette.sageText,
                                      letterSpacing: -0.5,
                                      fontFeatures: const [
                                        FontFeature.tabularFigures(),
                                      ],
                                    ),
                                  ),
                                  Text(
                                    'tercapai',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: palette.inkSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppTokens.space24),

                        // Key Metrics Row: Real Balance vs Target
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppTokens.space16,
                            vertical: AppTokens.space12,
                          ),
                          decoration: BoxDecoration(
                            color: palette.surfaceSubtle.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: _MetricColumn(
                                  label: 'Saldo Bersih Saat Ini',
                                  value: CurrencyFormatter.formatIdr(currentBalance),
                                  valueColor: palette.sageText,
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 32,
                                color: palette.border.withValues(alpha: 0.6),
                              ),
                              const SizedBox(width: AppTokens.space16),
                              Expanded(
                                child: _MetricColumn(
                                  label: 'Nominal Target',
                                  value: CurrencyFormatter.formatIdr(target),
                                  valueColor: palette.inkPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppTokens.space16),

                        // Sisa Menuju Target
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Sisa menuju target',
                                style: textTheme.bodySmall?.copyWith(
                                  color: palette.inkSecondary,
                                ),
                              ),
                            ),
                            Text(
                              remaining > 0
                                  ? CurrencyFormatter.formatIdr(remaining)
                                  : 'Target tercapai 100%! 🎉',
                              style: textTheme.titleMedium?.copyWith(
                                color: remaining == 0
                                    ? palette.success
                                    : palette.inkPrimary,
                                fontWeight: FontWeight.w700,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),

                        if (dailyNeeded != null) ...[
                          const Divider(height: AppTokens.space24),
                          Container(
                            padding: const EdgeInsets.all(AppTokens.space12),
                            decoration: BoxDecoration(
                              color: palette.sageSurface.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.lightbulb_outline_rounded,
                                  size: 18,
                                  color: palette.sageText,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Rekomendasi harian: Sisihkan Rp ${CurrencyFormatter.formatCompactIdr(dailyNeeded)}/hari untuk tepat waktu.',
                                    style: textTheme.bodySmall?.copyWith(
                                      color: palette.sageText,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: AppTokens.space20),

                        // CTA Button
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: palette.fabAccent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: () => QuickAddSheet.show(
                              context,
                              initialType: TransactionType.saving,
                            ),
                            icon: const Icon(Icons.add_rounded, size: 20),
                            label: const Text(
                              'Tambah Setoran Tabungan',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppTokens.space24),

                  // Trend Bar Chart Section
                  Text(
                    'Riwayat Setoran 6 Bulan Terakhir',
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
                              : const Color(0x06000000),
                          blurRadius: 12,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(AppTokens.space16),
                    child: summary.monthlyTrends.every((m) => m.savings == 0)
                        ? const AppEmptyStateView(
                            icon: Icons.bar_chart_outlined,
                            title: 'Belum ada grafik setoran',
                            description:
                                'Grafik perkembangan tabungan per bulan akan muncul otomatis setelah kamu mencatat setoran pertamamu.',
                          )
                        : SizedBox(
                            height: 200,
                            child: BarChart(
                              BarChartData(
                                alignment: BarChartAlignment.spaceAround,
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
                                      reservedSize: 56,
                                      getTitlesWidget: (val, _) => Text(
                                        CurrencyFormatter.formatCompactIdr(val),
                                        style: textTheme.labelSmall?.copyWith(
                                          color: palette.inkSecondary,
                                        ),
                                      ),
                                    ),
                                  ),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      getTitlesWidget: (val, _) {
                                        final idx = val.toInt();
                                        if (idx < 0 ||
                                            idx >= summary.monthlyTrends.length) {
                                          return const SizedBox.shrink();
                                        }
                                        return Padding(
                                          padding: const EdgeInsets.only(top: 6),
                                          child: Text(
                                            DateFormatter.formatShortMonth(
                                              summary.monthlyTrends[idx].monthKey,
                                            ),
                                            style: textTheme.labelSmall?.copyWith(
                                              color: palette.inkSecondary,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                barGroups: [
                                  for (int i = 0;
                                      i < summary.monthlyTrends.length;
                                      i++)
                                    BarChartGroupData(
                                      x: i,
                                      barRods: [
                                        BarChartRodData(
                                          toY: summary.monthlyTrends[i].savings,
                                          color: palette.sageFill,
                                          width: 18,
                                          borderRadius:
                                              const BorderRadius.vertical(
                                            top: Radius.circular(6),
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ),
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _showEditTargetSheet(BuildContext context, WidgetRef ref) async {
    final profile = ref.read(authControllerProvider).profile;
    if (profile == null) return;

    final formKey = GlobalKey<FormState>();
    final titleCtrl = TextEditingController(text: profile.savingsTargetTitle);
    final amountCtrl = TextEditingController(
      text: profile.savingsTarget > 0
          ? profile.savingsTarget.round().toString()
          : '',
    );
    DateTime? deadline = profile.savingsTargetDeadline;
    bool saving = false;
    String? errorMsg;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                AppTokens.space24,
                AppTokens.space16,
                AppTokens.space24,
                MediaQuery.viewInsetsOf(ctx).bottom + AppTokens.space24,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Ubah Target Tabungan',
                      style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppTokens.space16),
                    TextFormField(
                      controller: titleCtrl,
                      maxLength: InputValidators.maxTargetTitleLength,
                      decoration: const InputDecoration(
                        labelText: 'Nama Target',
                        counterText: '',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Nama target wajib diisi.'
                          : null,
                    ),
                    const SizedBox(height: AppTokens.space12),
                    TextFormField(
                      controller: amountCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: const InputDecoration(
                        labelText: 'Nominal Target (Rp)',
                        prefixText: 'Rp ',
                      ),
                      validator: (v) => InputValidators.validateSavingsTarget(
                        InputValidators.parseKeypadAmount(v ?? ''),
                      ),
                    ),
                    const SizedBox(height: AppTokens.space12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final now = DateTime.now();
                              final picked = await showDatePicker(
                                context: ctx,
                                initialDate:
                                    deadline ?? now.add(const Duration(days: 90)),
                                firstDate: now.add(const Duration(days: 1)),
                                lastDate: now.add(const Duration(days: 3650)),
                              );
                              if (picked != null) {
                                setModalState(() => deadline = picked);
                              }
                            },
                            icon: const Icon(Icons.calendar_today_outlined, size: 16),
                            label: Text(
                              deadline != null
                                  ? DateFormatter.formatDayMonthYear(deadline!)
                                  : 'Atur Tenggat (Opsional)',
                            ),
                          ),
                        ),
                        if (deadline != null)
                          IconButton(
                            tooltip: 'Hapus tenggat',
                            onPressed: () => setModalState(() => deadline = null),
                            icon: const Icon(Icons.close_rounded),
                          ),
                      ],
                    ),
                    if (errorMsg != null) ...[
                      const SizedBox(height: AppTokens.space12),
                      Text(
                        errorMsg!,
                        style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                              color: ctx.palette.danger,
                            ),
                      ),
                    ],
                    const SizedBox(height: AppTokens.space24),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: ctx.palette.fabAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: saving
                          ? null
                          : () async {
                              if (!(formKey.currentState?.validate() ?? false)) {
                                return;
                              }
                              setModalState(() {
                                saving = true;
                                errorMsg = null;
                              });
                              final err = await ref
                                  .read(authControllerProvider.notifier)
                                  .updateSavingsTarget(
                                    savingsTarget:
                                        InputValidators.parseKeypadAmount(
                                      amountCtrl.text,
                                    ),
                                    targetTitle:
                                        InputValidators.sanitizeTargetTitle(
                                      titleCtrl.text,
                                    ),
                                    deadline: deadline,
                                    clearDeadline: deadline == null,
                                  );
                              if (!ctx.mounted) return;
                              if (err != null) {
                                setModalState(() {
                                  saving = false;
                                  errorMsg = err;
                                });
                                return;
                              }
                              Navigator.of(ctx).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Target tabungan berhasil diperbarui.'),
                                ),
                              );
                            },
                      child: saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Simpan Target',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    titleCtrl.dispose();
    amountCtrl.dispose();
  }
}

class _MetricColumn extends StatelessWidget {
  const _MetricColumn({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontSize: 11,
            color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: valueColor,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
        ),
      ],
    );
  }
}
