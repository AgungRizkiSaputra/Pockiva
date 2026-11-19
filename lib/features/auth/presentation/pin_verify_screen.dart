import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/widgets/pin_pad_widget.dart';
import '../application/auth_controller.dart';

class PinVerifyScreen extends ConsumerStatefulWidget {
  const PinVerifyScreen({super.key});

  @override
  ConsumerState<PinVerifyScreen> createState() => _PinVerifyScreenState();
}

class _PinVerifyScreenState extends ConsumerState<PinVerifyScreen> {
  String _pin = '';

  Future<void> _onDigit(String digit) async {
    if (_pin.length >= 6) return;
    setState(() => _pin += digit);

    if (_pin.length == 6) {
      final entered = _pin;
      final ok =
          await ref.read(authControllerProvider.notifier).verifyPin(entered);
      if (!ok && mounted) {
        setState(() => _pin = '');
      }
    }
  }

  void _onBackspace() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    final firstName = authState.profile?.firstName ?? 'Kamu';

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppTokens.space8),
            child: TextButton(
              onPressed: authState.isBusy
                  ? null
                  : () => ref.read(authControllerProvider.notifier).signOut(),
              style: TextButton.styleFrom(
                foregroundColor: palette.inkSecondary,
                textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              child: const Text('Ganti Akun'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.space24,
              vertical: AppTokens.space12,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Profile Avatar Squircle
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: palette.sageSurface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: palette.sageBorder, width: 1.5),
                    ),
                    child: Center(
                      child: Text(
                        authState.profile?.initials ?? 'U',
                        style: textTheme.titleLarge?.copyWith(
                          color: palette.sageText,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTokens.space20),
                  Text(
                    'Halo, $firstName',
                    textAlign: TextAlign.center,
                    style: textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: AppTokens.space8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppTokens.space16),
                    child: Text(
                      'Masukkan 6 digit PIN untuk membuka kembali data tabunganmu.',
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(
                        color: palette.inkSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTokens.space28),
                  PinPadWidget(
                    pinLength: _pin.length,
                    isBusy: authState.isBusy,
                    errorText: authState.errorMessage,
                    onDigitPressed: _onDigit,
                    onBackspacePressed: _onBackspace,
                  ),
                  const SizedBox(height: AppTokens.space12),
                  TextButton.icon(
                    key: const Key('forgot_pin_button'),
                    onPressed: authState.isBusy
                        ? null
                        : () => _showForgotPinDialog(context, ref, authState),
                    icon: const Icon(Icons.help_outline_rounded, size: 16),
                    label: const Text('Lupa PIN?'),
                    style: TextButton.styleFrom(
                      foregroundColor: palette.sageText,
                      textStyle: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _maskEmail(String? email) {
    if (email == null || email.isEmpty) return 'email terdaftar Anda';
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final name = parts[0];
    final domain = parts[1];
    if (name.length <= 3) {
      return '${name[0]}***@$domain';
    }
    return '${name.substring(0, 2)}***${name.substring(name.length - 2)}@$domain';
  }

  void _showForgotPinDialog(
    BuildContext context,
    WidgetRef ref,
    AuthControllerState authState,
  ) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    final email = authState.profile?.email;
    final maskedEmail = _maskEmail(email);

    showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: palette.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: palette.fabAccent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: palette.fabAccent.withValues(alpha: 0.25),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.mark_email_unread_rounded,
                  color: palette.fabAccent,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Kirim Kode OTP?',
              textAlign: TextAlign.center,
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Kami akan mengirimkan 6 digit kode verifikasi ke email:',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: palette.inkSecondary,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: palette.surfaceSubtle,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: palette.borderSubtle),
              ),
              child: Text(
                maskedEmail,
                style: textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: palette.inkPrimary,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Setelah kode dimasukkan, kamu bisa langsung membuat PIN baru.',
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(
                color: palette.inkSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    foregroundColor: palette.inkSecondary,
                  ),
                  child: const Text('Batal'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  key: const Key('confirm_forgot_pin_button'),
                  style: FilledButton.styleFrom(
                    backgroundColor: palette.fabAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.send_rounded, size: 16),
                  label: const Text(
                    'Kirim OTP',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  onPressed: () {
                    Navigator.of(dialogCtx).pop();
                    ref.read(authControllerProvider.notifier).startForgotPinOtpFlow();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
