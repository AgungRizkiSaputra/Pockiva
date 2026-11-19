import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/state_views.dart';
import '../../transactions/presentation/quick_add_sheet.dart';
import '../application/gamification_controller.dart';
import '../domain/gamification_models.dart';

class GamificationScreen extends ConsumerWidget {
  const GamificationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gamificationControllerProvider);
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    final width = MediaQuery.sizeOf(context).width;
    final gridCount = width >= AppTokens.tabletBreakpoint ? 4 : 2;

    final effectiveStreak = state.streak.effectiveStreak();
    final activeToday = state.streak.isActiveToday();
    final unlockedCount = state.unlockedBadges.length;
    final totalBadges = BadgeDefinition.catalog.length;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Streak & Pencapaian'),
      ),
      body: state.isLoading && state.streak.totalActiveDays == 0
          ? const AppLoadingView(message: 'Memuat data streak dan lencana...')
          : state.errorMessage != null && state.streak.totalActiveDays == 0
              ? AppErrorStateView(
                  title: 'Gagal memuat pencapaian',
                  message: state.errorMessage!,
                  onRetry: () => ref
                      .read(gamificationControllerProvider.notifier)
                      .refresh(),
                )
              : RefreshIndicator(
                  color: palette.sageText,
                  onRefresh: () => ref
                      .read(gamificationControllerProvider.notifier)
                      .refresh(),
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppTokens.space16,
                      AppTokens.space12,
                      AppTokens.space16,
                      120, // Clean clearance above floating Telegram-inspired capsule
                    ),
                    children: [
                      // Streak Hero Card - Modern Minimalist Fintech
                      Container(
                        decoration: BoxDecoration(
                          color: palette.surface,
                          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
                          border: Border.all(
                            color: effectiveStreak > 0
                                ? palette.sageBorder
                                : palette.border,
                            width: effectiveStreak > 0 ? 1.5 : 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: isDark
                                  ? Colors.black.withValues(alpha: 0.25)
                                  : Colors.black.withValues(alpha: 0.04),
                              offset: const Offset(0, 4),
                              blurRadius: 16,
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.all(AppTokens.space20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: effectiveStreak > 0
                                        ? palette.sageSurface
                                        : palette.surfaceSubtle,
                                    borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                                    border: Border.all(
                                      color: effectiveStreak > 0
                                          ? palette.sageBorder
                                          : Colors.transparent,
                                    ),
                                  ),
                                  child: Icon(
                                    Icons.local_fire_department_rounded,
                                    size: 32,
                                    color: effectiveStreak > 0
                                        ? const Color(0xFFF97316)
                                        : palette.inkSecondary,
                                  ),
                                ),
                                const SizedBox(width: AppTokens.space16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.baseline,
                                        textBaseline: TextBaseline.alphabetic,
                                        children: [
                                          Text(
                                            '$effectiveStreak',
                                            style: textTheme.headlineMedium?.copyWith(
                                              fontWeight: FontWeight.w800,
                                              color: palette.inkPrimary,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              'Hari Berturut-turut',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: textTheme.titleMedium?.copyWith(
                                                fontWeight: FontWeight.w600,
                                                color: palette.inkSecondary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        activeToday
                                            ? 'Hebat! Aktivitas hari ini sudah tercatat.'
                                            : 'Catat transaksi hari ini untuk mempertahankan streak kamu.',
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

                            // 7-Day Activity Dot Tracker
                            _SevenDayTracker(
                              streak: state.streak,
                              activeToday: activeToday,
                            ),

                            const SizedBox(height: AppTokens.space16),
                            Divider(color: palette.border, height: 1),
                            const SizedBox(height: AppTokens.space16),

                            Row(
                              children: [
                                Expanded(
                                  child: _StreakStat(
                                    label: 'Rekor Terpanjang',
                                    value: '${state.streak.longestStreak} Hari',
                                    icon: Icons.emoji_events_outlined,
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 36,
                                  color: palette.border,
                                ),
                                Expanded(
                                  child: _StreakStat(
                                    label: 'Total Hari Aktif',
                                    value: '${state.streak.totalActiveDays} Hari',
                                    icon: Icons.calendar_today_outlined,
                                  ),
                                ),
                                Container(
                                  width: 1,
                                  height: 36,
                                  color: palette.border,
                                ),
                                Expanded(
                                  child: _StreakStat(
                                    label: 'Lencana Didapat',
                                    value: '$unlockedCount / $totalBadges',
                                    icon: Icons.verified_outlined,
                                  ),
                                ),
                              ],
                            ),
                            if (!activeToday) ...[
                              const SizedBox(height: AppTokens.space20),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: palette.fabAccent,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                                    ),
                                  ),
                                  icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
                                  onPressed: () => QuickAddSheet.show(context),
                                  label: const Text(
                                    'Catat Aktivitas Hari Ini',
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: AppTokens.space24),

                      // Section Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Lencana Pencapaian',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: palette.inkPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: palette.surfaceSubtle,
                              borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                              border: Border.all(color: palette.border),
                            ),
                            child: Text(
                              '$unlockedCount dari $totalBadges terbuka',
                              style: textTheme.labelSmall?.copyWith(
                                color: palette.sageText,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppTokens.space12),

                      // Badges Grid
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: BadgeDefinition.catalog.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: gridCount,
                          crossAxisSpacing: AppTokens.space12,
                          mainAxisSpacing: AppTokens.space12,
                          childAspectRatio: 0.95,
                        ),
                        itemBuilder: (context, index) {
                          final badge = BadgeDefinition.catalog[index];
                          final unlockedAt = state.badgeUnlockedAt(badge.code);
                          final unlocked = unlockedAt != null;

                          return Container(
                            decoration: BoxDecoration(
                              color: unlocked ? palette.surface : palette.surfaceSubtle.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                              border: Border.all(
                                color: unlocked ? palette.sageBorder : palette.border,
                                width: unlocked ? 1.4 : 1,
                              ),
                              boxShadow: unlocked
                                  ? [
                                      BoxShadow(
                                        color: isDark
                                            ? Colors.black.withValues(alpha: 0.2)
                                            : Colors.black.withValues(alpha: 0.03),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            padding: const EdgeInsets.all(AppTokens.space16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: unlocked
                                            ? palette.sageSurface
                                            : palette.surface,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: unlocked
                                              ? palette.sageBorder
                                              : palette.border,
                                        ),
                                      ),
                                      child: Icon(
                                        badge.icon,
                                        size: 22,
                                        color: unlocked
                                            ? palette.sageText
                                            : palette.inkSecondary.withValues(alpha: 0.4),
                                      ),
                                    ),
                                    Icon(
                                      unlocked
                                          ? Icons.check_circle_rounded
                                          : Icons.lock_outline_rounded,
                                      size: 18,
                                      color: unlocked
                                          ? palette.success
                                          : palette.inkSecondary.withValues(alpha: 0.4),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppTokens.space12),
                                Text(
                                  badge.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: unlocked
                                        ? palette.inkPrimary
                                        : palette.inkSecondary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Expanded(
                                  child: Text(
                                    badge.description,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: textTheme.bodySmall?.copyWith(
                                      fontSize: 11,
                                      color: palette.inkSecondary,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  unlocked
                                      ? DateFormatter.formatDayMonthYear(unlockedAt)
                                      : 'Belum Terbuka',
                                  style: textTheme.labelSmall?.copyWith(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: unlocked
                                        ? palette.sageText
                                        : palette.inkSecondary.withValues(alpha: 0.6),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _SevenDayTracker extends StatelessWidget {
  const _SevenDayTracker({
    required this.streak,
    required this.activeToday,
  });

  final UserStreak streak;
  final bool activeToday;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    final now = DateTime.now();
    final effective = streak.effectiveStreak();

    const dayLabels = ['Min', 'Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab'];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: palette.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(7, (i) {
          final date = now.subtract(Duration(days: 6 - i));
          final isToday = i == 6;
          final daysAgo = 6 - i;
          final isActive = isToday ? activeToday : (daysAgo < effective);
          final dayName = dayLabels[date.weekday % 7];

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isToday ? 'Hari ini' : dayName,
                style: textTheme.labelSmall?.copyWith(
                  fontSize: 10,
                  fontWeight: isToday ? FontWeight.w700 : FontWeight.w500,
                  color: isToday ? palette.fabAccent : palette.inkSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isActive
                      ? palette.sageSurface
                      : (isToday ? palette.surface : Colors.transparent),
                  border: Border.all(
                    color: isActive
                        ? palette.sageBorder
                        : (isToday ? palette.fabAccent : palette.border),
                    width: isToday ? 1.5 : 1,
                  ),
                ),
                child: Center(
                  child: isActive
                      ? Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: palette.sageText,
                        )
                      : Text(
                          '${date.day}',
                          style: textTheme.labelSmall?.copyWith(
                            fontSize: 10,
                            color: isToday ? palette.inkPrimary : palette.inkSecondary,
                            fontWeight: isToday ? FontWeight.w700 : FontWeight.normal,
                          ),
                        ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _StreakStat extends StatelessWidget {
  const _StreakStat({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      children: [
        Icon(icon, size: 16, color: palette.inkSecondary),
        const SizedBox(height: 4),
        Text(
          value,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: palette.inkPrimary,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontSize: 10,
                color: palette.inkSecondary,
              ),
        ),
      ],
    );
  }
}
