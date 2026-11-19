import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';

/// Shown honestly when Supabase environment variables have not been injected via
/// `--dart-define` or `--dart-define-from-file`, avoiding hardcoded secrets or fake data.
class UnconfiguredScreen extends StatelessWidget {
  const UnconfiguredScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTokens.space24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Container(
                padding: const EdgeInsets.all(AppTokens.space28),
                decoration: BoxDecoration(
                  color: palette.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: palette.borderSubtle),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 20,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: palette.sageSurface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: palette.sageBorder),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.settings_input_component_outlined,
                          size: 26,
                          color: palette.sageText,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTokens.space20),
                    Text(
                      'Konfigurasi Supabase Diperlukan',
                      style: textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: AppTokens.space8),
                    Text(
                      'Aplikasi ini tidak menyimpan kunci API di dalam kode sumber. Jalankan aplikasi dengan menyertakan SUPABASE_URL dan SUPABASE_ANON_KEY.',
                      style: textTheme.bodyMedium?.copyWith(
                        color: palette.inkSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: AppTokens.space20),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppTokens.space16),
                      decoration: BoxDecoration(
                        color: palette.surfaceSubtle,
                        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                        border: Border.all(color: palette.borderSubtle),
                      ),
                      child: const SelectableText(
                        'flutter run \\\n'
                        '  --dart-define=SUPABASE_URL=https://PROJECT.supabase.co \\\n'
                        '  --dart-define=SUPABASE_ANON_KEY=YOUR_ANON_KEY',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTokens.space20),
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: palette.inkSecondary,
                        ),
                        const SizedBox(width: AppTokens.space8),
                        Expanded(
                          child: Text(
                            'Lihat docs/DEPLOYMENT.md untuk panduan migrasi database, Edge Functions, dan Google OAuth.',
                            style: textTheme.bodySmall?.copyWith(
                              color: palette.inkSecondary,
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
      ),
    );
  }
}
