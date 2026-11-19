import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';

final splashDoneProvider = StateProvider<bool>((ref) => false);

/// High-Concept Neo-Architectural animated splash screen.
/// Sets a confident, bespoke first impression with luminous geometry and fluid micro-transitions.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _textFadeAnimation;
  late final Animation<double> _glowAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutCubic),
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _textFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.35, 0.85, curve: Curves.easeOut),
      ),
    );

    _glowAnimation = Tween<double>(begin: 0.3, end: 0.9).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.9, curve: Curves.easeInOut),
      ),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        ref.read(splashDoneProvider.notifier).state = true;
      }
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Stack(
          children: [
            // Ambient Radial Bioluminescent Glow
            Center(
              child: AnimatedBuilder(
                animation: _glowAnimation,
                builder: (context, _) {
                  return Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          palette.sageFill.withValues(
                            alpha: (isDark ? 0.22 : 0.14) * _glowAnimation.value,
                          ),
                          palette.fabAccent.withValues(
                            alpha: (isDark ? 0.12 : 0.06) * _glowAnimation.value,
                          ),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.45, 1.0],
                      ),
                    ),
                  );
                },
              ),
            ),

            // Animated Branding Centerpiece
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ScaleTransition(
                    scale: _scaleAnimation,
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Outer ambient decorative ring
                          Container(
                            width: 112,
                            height: 112,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: palette.sageFill.withValues(
                                  alpha: isDark ? 0.25 : 0.15,
                                ),
                                width: 1.2,
                              ),
                            ),
                          ),
                          // Core luxury geometric squircle
                          Container(
                            width: 92,
                            height: 92,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: isDark
                                    ? const [Color(0xFF1B2433), Color(0xFF0F1520)]
                                    : [Colors.white, const Color(0xFFF1F5F9)],
                              ),
                              borderRadius: BorderRadius.circular(28),
                              border: Border.all(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.14)
                                    : palette.border,
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: palette.sageFill.withValues(
                                    alpha: isDark ? 0.35 : 0.20,
                                  ),
                                  blurRadius: 32,
                                  offset: const Offset(0, 12),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Icon(
                                    Icons.account_balance_wallet_rounded,
                                    size: 42,
                                    color: palette.sageText,
                                  ),
                                  // Radiant beacon spark
                                  Positioned(
                                    top: 22,
                                    right: 20,
                                    child: Container(
                                      width: 9,
                                      height: 9,
                                      decoration: BoxDecoration(
                                        color: palette.fabAccent,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: palette.fabAccent.withValues(alpha: 0.7),
                                            blurRadius: 8,
                                            spreadRadius: 1,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTokens.space28),

                  // Fading Brand Title & Tagline
                  FadeTransition(
                    opacity: _textFadeAnimation,
                    child: Column(
                      children: [
                        Text(
                          'TABUNGAN PRIBADI',
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 3.0,
                            color: palette.inkPrimary,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: AppTokens.space8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          decoration: BoxDecoration(
                            color: palette.surfaceSubtle.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(AppTokens.radiusFull),
                            border: Border.all(
                              color: palette.borderSubtle,
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            'Catat Finansial dengan Tenang & Teratur',
                            style: textTheme.bodySmall?.copyWith(
                              color: palette.inkSecondary,
                              letterSpacing: 0.3,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Bottom loading pulse indicator
            Positioned(
              bottom: AppTokens.space32,
              left: 0,
              right: 0,
              child: Center(
                child: FadeTransition(
                  opacity: _textFadeAnimation,
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: palette.surfaceSubtle,
                      borderRadius: BorderRadius.circular(AppTokens.radiusFull),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(AppTokens.radiusFull),
                      child: LinearProgressIndicator(
                        backgroundColor: palette.borderSubtle,
                        valueColor: AlwaysStoppedAnimation<Color>(palette.sageText),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
