import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../application/auth_controller.dart';

class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.space24,
              vertical: AppTokens.space20,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Brand Icon Monogram with glowing rim
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: isDark
                            ? const [Color(0xFF1B2433), Color(0xFF111722)]
                            : const [Colors.white, Color(0xFFF1F5F9)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.12)
                            : palette.border,
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: palette.sageFill.withValues(alpha: isDark ? 0.25 : 0.12),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Center(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.asset(
                          'assets/images/pockiva_logo.png',
                          width: 54,
                          height: 54,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTokens.space24),

                  // Headline & Description
                  Text(
                    'Catat tabungan\ndalam 5 detik.',
                    style: textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1.0,
                      height: 1.12,
                      color: palette.inkPrimary,
                    ),
                  ),
                  const SizedBox(height: AppTokens.space12),
                  Text(
                    'Pantau pengeluaran harian, jaga konsistensi menabung, dan lihat perkembangan target finansialmu dalam satu tempat yang tenang.',
                    style: textTheme.bodyMedium?.copyWith(
                      color: palette.inkSecondary,
                      height: 1.5,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: AppTokens.space24),

                  // Unified Value Proposition Card - Bento Style
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
                          color: isDark
                              ? Colors.black.withValues(alpha: 0.3)
                              : const Color(0x08000000),
                          blurRadius: 18,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(AppTokens.space20),
                    child: Column(
                      children: [
                        _ValuePoint(
                          icon: Icons.bolt_rounded,
                          iconBg: palette.sageSurface,
                          iconColor: palette.sageText,
                          title: 'Input super cepat',
                          subtitle: 'Numpad langsung siap dipakai tanpa formulir panjang.',
                          palette: palette,
                          textTheme: textTheme,
                        ),
                        Divider(color: palette.borderSubtle, height: AppTokens.space24),
                        _ValuePoint(
                          icon: Icons.bar_chart_rounded,
                          iconBg: isDark ? const Color(0xFF172554) : const Color(0xFFEFF6FF),
                          iconColor: palette.linkAccent,
                          title: 'Insight tren bulanan',
                          subtitle: 'Ringkasan kategori dan arus kas yang dihitung dari catatan aslimu.',
                          palette: palette,
                          textTheme: textTheme,
                        ),
                        Divider(color: palette.borderSubtle, height: AppTokens.space24),
                        _ValuePoint(
                          icon: Icons.lock_outline_rounded,
                          iconBg: isDark ? const Color(0xFF261933) : const Color(0xFFFAF5FF),
                          iconColor: const Color(0xFFA855F7),
                          title: 'Dilindungi PIN 6 digit',
                          subtitle: 'Akses akun aman dengan Google OAuth dan verifikasi PIN terenkripsi.',
                          palette: palette,
                          textTheme: textTheme,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTokens.space24),

                  // Notices (Inactivity or Error)
                  if (authState.inactivityNotice != null) ...[
                    _NoticeBox(
                      message: authState.inactivityNotice!,
                      fg: palette.warning,
                      bg: palette.warning.withValues(alpha: 0.12),
                      border: palette.warning.withValues(alpha: 0.3),
                      icon: Icons.schedule_rounded,
                    ),
                    const SizedBox(height: AppTokens.space16),
                  ],
                  if (authState.errorMessage != null) ...[
                    _NoticeBox(
                      message: authState.errorMessage!,
                      fg: palette.danger,
                      bg: palette.danger.withValues(alpha: 0.1),
                      border: palette.danger.withValues(alpha: 0.3),
                      icon: Icons.error_outline_rounded,
                    ),
                    const SizedBox(height: AppTokens.space16),
                  ],

                  // Primary CTA: Google Sign In
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      key: const Key('google_sign_in_button'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: palette.fabAccent,
                        foregroundColor: Colors.white,
                        elevation: 4,
                        shadowColor: palette.fabAccent.withValues(alpha: 0.4),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: authState.isBusy
                          ? null
                          : () => ref
                              .read(authControllerProvider.notifier)
                              .signInWithGoogle(),
                      child: authState.isBusy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.login_rounded, size: 20),
                                SizedBox(width: AppTokens.space8),
                                Text(
                                  'Masuk dengan Google',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: AppTokens.space16),

                  // Security Footnote
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shield_outlined, size: 14, color: palette.inkSecondary),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Data keuanganmu terenkripsi lokal dan otomatis terkunci.',
                          textAlign: TextAlign.center,
                          style: textTheme.bodySmall?.copyWith(
                            color: palette.inkSecondary,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ValuePoint extends StatelessWidget {
  const _ValuePoint({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.palette,
    required this.textTheme,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final AppColorPalette palette;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, size: 20, color: iconColor),
        ),
        const SizedBox(width: AppTokens.space16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: palette.inkPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: textTheme.bodySmall?.copyWith(
                  color: palette.inkSecondary,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NoticeBox extends StatelessWidget {
  const _NoticeBox({
    required this.message,
    required this.fg,
    required this.bg,
    required this.border,
    required this.icon,
  });

  final String message;
  final Color fg;
  final Color bg;
  final Color border;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: AppTokens.space8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
