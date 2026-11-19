import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/transactions/presentation/quick_add_sheet.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';

/// Responsive application shell:
/// - Mobile (<900px): Telegram-inspired floating unified capsule navigation bar
///   floating above bottom content + Electric Blue Quick Add FAB
/// - Tablet / Desktop (>=900px): Sidebar NavigationRail + Grid-friendly content canvas
class ResponsiveAppShell extends StatelessWidget {
  const ResponsiveAppShell({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  static const _destinations = [
    (
      label: 'Beranda',
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
    ),
    (
      label: 'Riwayat',
      icon: Icons.receipt_long_outlined,
      activeIcon: Icons.receipt_long_rounded,
    ),
    (
      label: 'Progres',
      icon: Icons.savings_outlined,
      activeIcon: Icons.savings_rounded,
    ),
    (
      label: 'Insight',
      icon: Icons.bar_chart_outlined,
      activeIcon: Icons.bar_chart_rounded,
    ),
    (
      label: 'Streak',
      icon: Icons.local_fire_department_outlined,
      activeIcon: Icons.local_fire_department_rounded,
    ),
  ];

  void _onSelectTab(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isWide = width >= AppTokens.tabletBreakpoint;
    final palette = context.palette;

    final fab = FloatingActionButton(
      key: const Key('quick_add_fab'),
      tooltip: 'Catat Transaksi Cepat',
      onPressed: () => QuickAddSheet.show(context),
      backgroundColor: palette.fabAccent,
      foregroundColor: Colors.white,
      elevation: 6,
      shape: const CircleBorder(),
      child: const Icon(Icons.add_rounded, size: 28),
    );

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              backgroundColor: palette.surface,
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: _onSelectTab,
              extended: width >= AppTokens.desktopBreakpoint,
              leading: Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppTokens.space12,
                  AppTokens.space16,
                  AppTokens.space12,
                  AppTokens.space24,
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [palette.sageFill, palette.sageText],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.account_balance_wallet_outlined,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        if (width >= AppTokens.desktopBreakpoint) ...[
                          const SizedBox(width: AppTokens.space12),
                          Text(
                            'Tabungan',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: AppTokens.space16),
                    SizedBox(
                      height: 44,
                      child: FilledButton.icon(
                        key: const Key('quick_add_fab'),
                        style: FilledButton.styleFrom(
                          backgroundColor: palette.fabAccent,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: width >= AppTokens.desktopBreakpoint
                                ? AppTokens.space16
                                : AppTokens.space12,
                          ),
                        ),
                        onPressed: () => QuickAddSheet.show(context),
                        icon: const Icon(Icons.add_rounded, size: 20),
                        label: width >= AppTokens.desktopBreakpoint
                            ? const Text('Catat Cepat')
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ),
              ),
              trailing: Expanded(
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: AppTokens.space16),
                    child: IconButton(
                      tooltip: 'Pengaturan',
                      icon: Icon(Icons.settings_outlined, color: palette.inkSecondary),
                      onPressed: () => context.push('/settings'),
                    ),
                  ),
                ),
              ),
              destinations: _destinations
                  .map(
                    (d) => NavigationRailDestination(
                      icon: Icon(d.icon),
                      selectedIcon: Icon(d.activeIcon),
                      label: Text(d.label),
                    ),
                  )
                  .toList(),
            ),
            VerticalDivider(width: 1, color: palette.border),
            Expanded(child: navigationShell),
          ],
        ),
      );
    }

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(child: navigationShell),
          Align(
            alignment: Alignment.bottomCenter,
            child: _FloatingCapsuleNavBar(
              currentIndex: navigationShell.currentIndex,
              onDestinationSelected: _onSelectTab,
              destinations: _destinations,
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 84),
        child: fab,
      ),
    );
  }
}

/// Floating capsule navigation container inspired by the Telegram reference.
/// Floats above the bottom edge with modern curved geometry, multi-layer ambient shadow,
/// and subtle hairline border while strictly preserving the buttons, order, icons, and active indicators.
class _FloatingCapsuleNavBar extends StatelessWidget {
  const _FloatingCapsuleNavBar({
    required this.currentIndex,
    required this.onDestinationSelected,
    required this.destinations,
  });

  final int currentIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<({String label, IconData icon, IconData activeIcon})> destinations;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return SafeArea(
      top: false,
      left: false,
      right: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, bottomInset > 0 ? bottomInset + 2 : 14),
        child: Center(
          heightFactor: 1.0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Container(
              height: 66,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF131A26) : Colors.white,
                borderRadius: BorderRadius.circular(34),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.12)
                      : palette.border.withValues(alpha: 0.8),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.5)
                        : const Color(0x18000000),
                    blurRadius: 28,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withValues(alpha: 0.25)
                        : const Color(0x08000000),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: List.generate(destinations.length, (index) {
                  final item = destinations[index];
                  final isSelected = index == currentIndex;

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(22),
                          onTap: () => onDestinationSelected(index),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            curve: Curves.easeInOut,
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (isDark
                                      ? palette.fabAccent.withValues(alpha: 0.22)
                                      : palette.fabAccent.withValues(alpha: 0.12))
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isSelected ? item.activeIcon : item.icon,
                                  size: 22,
                                  color: isSelected
                                      ? palette.fabAccent
                                      : palette.inkSecondary,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  item.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    height: 1.15,
                                    letterSpacing: -0.2,
                                    fontWeight: isSelected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? palette.fabAccent
                                        : palette.inkSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
