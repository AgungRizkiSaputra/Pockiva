import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/application/auth_controller.dart';
import '../../features/auth/presentation/otp_verification_screen.dart';
import '../../features/auth/presentation/pin_setup_screen.dart';
import '../../features/auth/presentation/pin_verify_screen.dart';
import '../../features/auth/presentation/unconfigured_screen.dart';
import '../../features/auth/presentation/welcome_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/gamification/presentation/gamification_screen.dart';
import '../../features/insights/presentation/insights_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/savings/presentation/savings_progress_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/transactions/presentation/transaction_history_screen.dart';
import '../widgets/responsive_shell.dart';

CustomTransitionPage<void> _buildFadeTransitionPage({
  required LocalKey key,
  required Widget child,
  Duration duration = const Duration(milliseconds: 600),
}) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionDuration: duration,
    reverseTransitionDuration: duration,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: Curves.easeInOutCubic,
        ),
        child: child,
      );
    },
  );
}

class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    ref.listen<AuthControllerState>(authControllerProvider, (_, _) {
      notifyListeners();
    });
    ref.listen<bool>(splashDoneProvider, (_, _) {
      notifyListeners();
    });
  }
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefreshNotifier(ref);
  ref.onDispose(refreshNotifier.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final isSplashDone = ref.read(splashDoneProvider);
      final loc = state.matchedLocation;

      if (!isSplashDone) {
        return loc == '/splash' ? null : '/splash';
      }

      final authStatus = ref.read(authControllerProvider).status;

      final target = switch (authStatus) {
        AuthStatus.loading => '/splash',
        AuthStatus.unconfigured => '/unconfigured',
        AuthStatus.unauthenticated => '/welcome',
        AuthStatus.needsPinSetup => '/pin-setup',
        AuthStatus.pinLocked => '/pin-verify',
        AuthStatus.otpVerification => '/otp-verify',
        AuthStatus.needsOnboarding => '/onboarding',
        AuthStatus.authenticated => null,
      };

      if (target != null) {
        return loc == target ? null : target;
      }

      // Authenticated: redirect away from auth/gate routes into /dashboard
      const gateRoutes = {
        '/splash',
        '/unconfigured',
        '/welcome',
        '/pin-setup',
        '/pin-verify',
        '/otp-verify',
        '/onboarding',
      };
      if (gateRoutes.contains(loc)) {
        return '/dashboard';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/splash',
        pageBuilder: (context, state) => _buildFadeTransitionPage(
          key: state.pageKey,
          child: const SplashScreen(),
        ),
      ),
      GoRoute(
        path: '/unconfigured',
        pageBuilder: (context, state) => _buildFadeTransitionPage(
          key: state.pageKey,
          child: const UnconfiguredScreen(),
        ),
      ),
      GoRoute(
        path: '/welcome',
        pageBuilder: (context, state) => _buildFadeTransitionPage(
          key: state.pageKey,
          child: const WelcomeScreen(),
        ),
      ),
      GoRoute(
        path: '/pin-setup',
        pageBuilder: (context, state) => _buildFadeTransitionPage(
          key: state.pageKey,
          child: const PinSetupScreen(),
        ),
      ),
      GoRoute(
        path: '/pin-verify',
        pageBuilder: (context, state) => _buildFadeTransitionPage(
          key: state.pageKey,
          child: const PinVerifyScreen(),
        ),
      ),
      GoRoute(
        path: '/otp-verify',
        pageBuilder: (context, state) => _buildFadeTransitionPage(
          key: state.pageKey,
          child: const OtpVerificationScreen(),
        ),
      ),
      GoRoute(
        path: '/onboarding',
        pageBuilder: (context, state) => _buildFadeTransitionPage(
          key: state.pageKey,
          child: const OnboardingScreen(),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ResponsiveAppShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                builder: (_, _) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/history',
                builder: (_, _) => const TransactionHistoryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/savings',
                builder: (_, _) => const SavingsProgressScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/insights',
                builder: (_, _) => const InsightsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/gamification',
                builder: (_, _) => const GamificationScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/settings',
        builder: (_, _) => const SettingsScreen(),
      ),
    ],
  );
});
