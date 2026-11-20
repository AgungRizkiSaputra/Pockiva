import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/app_theme.dart';
import '../theme/app_tokens.dart';

/// Accessible, tactile, luxury 6-digit PIN indicator and keypad reused across
/// PIN setup, PIN verification, and PIN change flows.
class PinPadWidget extends StatelessWidget {
  const PinPadWidget({
    super.key,
    required this.pinLength,
    required this.onDigitPressed,
    required this.onBackspacePressed,
    this.isBusy = false,
    this.errorText,
    this.leftBottomAction,
  });

  final int pinLength;
  final ValueChanged<String> onDigitPressed;
  final VoidCallback onBackspacePressed;
  final bool isBusy;
  final String? errorText;
  final Widget? leftBottomAction;

  static const _subLabels = {
    '1': '',
    '2': 'ABC',
    '3': 'DEF',
    '4': 'GHI',
    '5': 'JKL',
    '6': 'MNO',
    '7': 'PQRS',
    '8': 'TUV',
    '9': 'WXYZ',
    '0': '+',
  };

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 6-Digit PIN Indicators with luminous glowing jewel effects
        Semantics(
          label: '$pinLength dari 6 digit PIN terisi',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: palette.surfaceSubtle.withValues(alpha: isDark ? 0.4 : 0.6),
              borderRadius: BorderRadius.circular(AppTokens.radiusCapsule),
              border: Border.all(
                color: palette.borderSubtle,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(6, (index) {
                final filled = index < pinLength;
                final isCurrent = index == pinLength;
                final isError = errorText != null;

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.symmetric(horizontal: 7),
                  width: filled ? 16 : 13,
                  height: filled ? 16 : 13,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled
                        ? (isError ? palette.danger : palette.sageFill)
                        : Colors.transparent,
                    border: Border.all(
                      color: isError
                          ? palette.danger
                          : (filled
                              ? palette.sageFill
                              : (isCurrent
                                  ? palette.fabAccent
                                  : palette.inkSecondary.withValues(alpha: 0.3))),
                      width: isCurrent ? 2.0 : 1.5,
                    ),
                    boxShadow: filled
                        ? [
                            BoxShadow(
                              color: (isError ? palette.danger : palette.sageFill)
                                  .withValues(alpha: isDark ? 0.6 : 0.35),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ]
                        : (isCurrent
                            ? [
                                BoxShadow(
                                  color: palette.fabAccent.withValues(alpha: 0.25),
                                  blurRadius: 6,
                                ),
                              ]
                            : null),
                  ),
                );
              }),
            ),
          ),
        ),
        const SizedBox(height: AppTokens.space12),

        // Error message or loader area
        SizedBox(
          height: 38,
          child: Center(
            child: isBusy
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: palette.sageText,
                    ),
                  )
                : errorText != null
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                        decoration: BoxDecoration(
                          color: palette.danger.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppTokens.radiusFull),
                          border: Border.all(
                            color: palette.danger.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          errorText!,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: palette.danger,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                        ),
                      )
                    : const SizedBox.shrink(),
          ),
        ),
        const SizedBox(height: AppTokens.space16),

        // Modern Minimalist Keypad
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 300),
          child: Column(
            children: [
              _buildRow(context, isDark, const ['1', '2', '3']),
              const SizedBox(height: AppTokens.space12),
              _buildRow(context, isDark, const ['4', '5', '6']),
              const SizedBox(height: AppTokens.space12),
              _buildRow(context, isDark, const ['7', '8', '9']),
              const SizedBox(height: AppTokens.space12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  leftBottomAction != null
                      ? SizedBox(
                          width: 80,
                          height: 60,
                          child: Center(child: leftBottomAction),
                        )
                      : const SizedBox(width: 80, height: 60),
                  _KeypadButton(
                    label: '0',
                    subLabel: _subLabels['0'] ?? '',
                    isDark: isDark,
                    enabled: !isBusy && pinLength < 6,
                    onTap: () => _handleDigit('0'),
                  ),
                  _KeypadIconButton(
                    tooltip: 'Hapus satu digit',
                    icon: Icons.backspace_outlined,
                    isDark: isDark,
                    enabled: !isBusy && pinLength > 0,
                    onTap: () {
                      HapticFeedback.lightImpact();
                      onBackspacePressed();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRow(BuildContext context, bool isDark, List<String> digits) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: digits
          .map(
            (d) => _KeypadButton(
              label: d,
              subLabel: _subLabels[d] ?? '',
              isDark: isDark,
              enabled: !isBusy && pinLength < 6,
              onTap: () => _handleDigit(d),
            ),
          )
          .toList(),
    );
  }

  void _handleDigit(String digit) {
    HapticFeedback.selectionClick();
    onDigitPressed(digit);
  }
}

class _KeypadButton extends StatelessWidget {
  const _KeypadButton({
    required this.label,
    required this.subLabel,
    required this.isDark,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final String subLabel;
  final bool isDark;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: Key('pin_key_$label'),
        borderRadius: BorderRadius.circular(18),
        onTap: enabled ? onTap : null,
        child: Container(
          width: 80,
          height: 60,
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : palette.border,
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.25)
                    : const Color(0x06000000),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 22,
                      height: 1.1,
                      color: enabled
                          ? palette.inkPrimary
                          : palette.inkSecondary.withValues(alpha: 0.35),
                    ),
              ),
              if (subLabel.isNotEmpty) ...[
                const SizedBox(height: 1),
                Text(
                  subLabel,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.5,
                    color: palette.inkSecondary.withValues(alpha: enabled ? 0.7 : 0.3),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _KeypadIconButton extends StatelessWidget {
  const _KeypadIconButton({
    required this.tooltip,
    required this.icon,
    required this.isDark,
    required this.enabled,
    required this.onTap,
  });

  final String tooltip;
  final IconData icon;
  final bool isDark;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          key: const Key('pin_key_backspace'),
          borderRadius: BorderRadius.circular(18),
          onTap: enabled ? onTap : null,
          child: SizedBox(
            width: 80,
            height: 60,
            child: Center(
              child: Icon(
                icon,
                size: 24,
                color: enabled
                    ? palette.inkPrimary
                    : palette.inkSecondary.withValues(alpha: 0.3),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
