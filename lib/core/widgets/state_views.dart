import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';

/// Consistent, informative loading indicator that states what is being loaded.
class AppLoadingView extends StatelessWidget {
  const AppLoadingView({
    super.key,
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.space24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: palette.surfaceSubtle,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: palette.borderSubtle),
              ),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: palette.sageText,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppTokens.space16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: palette.inkSecondary,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Actionable empty state stating the reason and single primary next action.
class AppEmptyStateView extends StatelessWidget {
  const AppEmptyStateView({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.space24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: palette.sageSurface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: palette.sageBorder),
                ),
                child: Icon(icon, size: 28, color: palette.sageText),
              ),
              const SizedBox(height: AppTokens.space20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: AppTokens.space8),
              Text(
                description,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: palette.inkSecondary,
                  height: 1.4,
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: AppTokens.space24),
                FilledButton(
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Informative error state naming what failed and offering a retry action.
class AppErrorStateView extends StatelessWidget {
  const AppErrorStateView({
    super.key,
    required this.title,
    required this.message,
    this.onRetry,
    this.retryLabel = 'Coba Lagi',
  });

  final String title;
  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.space24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: palette.dangerBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: palette.danger.withValues(alpha: 0.25),
                  ),
                ),
                child: Icon(
                  Icons.error_outline_rounded,
                  size: 28,
                  color: palette.danger,
                ),
              ),
              const SizedBox(height: AppTokens.space20),
              Text(
                title,
                textAlign: TextAlign.center,
                style: textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: AppTokens.space8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: textTheme.bodyMedium?.copyWith(
                  color: palette.inkSecondary,
                  height: 1.4,
                ),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: AppTokens.space24),
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(retryLabel),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
