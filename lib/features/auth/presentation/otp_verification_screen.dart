import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../application/auth_controller.dart';

class OtpVerificationScreen extends ConsumerStatefulWidget {
  const OtpVerificationScreen({super.key});

  @override
  ConsumerState<OtpVerificationScreen> createState() =>
      _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  String _otp = '';
  int _secondsRemaining = 60;
  Timer? _timer;
  bool _isResending = false;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _timer?.cancel();
    setState(() => _secondsRemaining = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 0) {
        setState(() => _secondsRemaining--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _onDigit(String digit) async {
    if (_otp.length >= 6) return;
    final nextOtp = _otp + digit;
    setState(() => _otp = nextOtp);

    if (nextOtp.length == 6) {
      await _submitOtp(nextOtp);
    }
  }

  void _onBackspace() {
    if (_otp.isEmpty) return;
    setState(() => _otp = _otp.substring(0, _otp.length - 1));
  }

  Future<void> _submitOtp(String code) async {
    final success = await ref
        .read(authControllerProvider.notifier)
        .verifyForgotPinOtp(code);
    if (!success && mounted) {
      setState(() => _otp = '');
    }
  }

  Future<void> _resendCode() async {
    if (_secondsRemaining > 0 || _isResending) return;
    setState(() => _isResending = true);
    final ok =
        await ref.read(authControllerProvider.notifier).resendForgotPinOtp();
    if (mounted) {
      setState(() => _isResending = false);
      if (ok) {
        _startCountdown();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kode OTP baru telah dikirimkan ke email Anda.'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    }
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    // Extract first 6 digits from clipboard
    final digits = text.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 6) {
      final code = digits.substring(0, 6);
      setState(() => _otp = code);
      await _submitOtp(code);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tidak ditemukan 6 digit kode pada clipboard.'),
          ),
        );
      }
    }
  }

  String _maskEmail(String? email) {
    if (email == null || email.isEmpty) return 'email Anda';
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final name = parts[0];
    final domain = parts[1];
    if (name.length <= 3) {
      return '${name[0]}***@$domain';
    }
    return '${name.substring(0, 2)}***${name.substring(name.length - 2)}@$domain';
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maskedEmail = _maskEmail(authState.resetEmail);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Kembali',
          onPressed: authState.isBusy
              ? null
              : () => ref
                  .read(authControllerProvider.notifier)
                  .cancelOtpVerification(),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppTokens.space8),
            child: TextButton(
              onPressed: authState.isBusy
                  ? null
                  : () => ref
                      .read(authControllerProvider.notifier)
                      .cancelOtpVerification(),
              style: TextButton.styleFrom(
                foregroundColor: palette.inkSecondary,
                textStyle:
                    const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              child: const Text('Batal'),
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
                  // Icon Halo
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: palette.fabAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: palette.fabAccent.withValues(alpha: 0.28),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.mark_email_read_outlined,
                        color: palette.fabAccent,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTokens.space20),
                  Text(
                    'Verifikasi Kode OTP',
                    textAlign: TextAlign.center,
                    style: textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: AppTokens.space8),
                  Text(
                    'Masukkan 6 digit kode verifikasi yang telah kami kirimkan ke email:',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyMedium?.copyWith(
                      color: palette.inkSecondary,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: AppTokens.space8),
                  // Masked Email Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: palette.surfaceSubtle,
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                        color: palette.borderSubtle,
                      ),
                    ),
                    child: Text(
                      maskedEmail,
                      style: textTheme.bodySmall?.copyWith(
                        color: palette.inkPrimary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTokens.space24),

                  // 6 Digit OTP Cells Display
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(6, (index) {
                      final hasDigit = index < _otp.length;
                      final isCurrent = index == _otp.length;
                      final char = hasDigit ? _otp[index] : '';

                      return Container(
                        key: Key('otp_cell_$index'),
                        width: 48,
                        height: 56,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: hasDigit
                              ? palette.surface
                              : palette.surfaceSubtle
                                  .withValues(alpha: isDark ? 0.3 : 0.6),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isCurrent
                                ? palette.fabAccent
                                : hasDigit
                                    ? palette.fabAccent.withValues(alpha: 0.5)
                                    : palette.borderSubtle,
                            width: isCurrent ? 2.0 : 1.2,
                          ),
                          boxShadow: isCurrent
                              ? [
                                  BoxShadow(
                                    color: palette.fabAccent
                                        .withValues(alpha: 0.18),
                                    blurRadius: 8,
                                    spreadRadius: 1,
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            char,
                            style: textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: palette.inkPrimary,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),

                  // Paste Button
                  const SizedBox(height: AppTokens.space12),
                  TextButton.icon(
                    key: const Key('paste_otp_button'),
                    onPressed: authState.isBusy ? null : _pasteFromClipboard,
                    icon: const Icon(Icons.paste_rounded, size: 16),
                    label: const Text(
                      'Tempel dari Clipboard',
                      style:
                          TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: palette.fabAccent,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                    ),
                  ),

                  // Error Text if any
                  if (authState.errorMessage != null) ...[
                    const SizedBox(height: AppTokens.space8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color:
                              const Color(0xFFEF4444).withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: Color(0xFFEF4444),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              authState.errorMessage!,
                              style: const TextStyle(
                                color: Color(0xFFEF4444),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Resend Timer / Action
                  const SizedBox(height: AppTokens.space12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Tidak menerima kode? ',
                        style: textTheme.bodySmall?.copyWith(
                          color: palette.inkSecondary,
                          fontSize: 12,
                        ),
                      ),
                      if (_secondsRemaining > 0)
                        Text(
                          'Kirim ulang dalam ${_secondsRemaining}s',
                          style: textTheme.bodySmall?.copyWith(
                            color: palette.inkPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        )
                      else
                        InkWell(
                          onTap: (authState.isBusy || _isResending)
                              ? null
                              : _resendCode,
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            child: Text(
                              _isResending ? 'Mengirim...' : 'Kirim Ulang Kode',
                              style: textTheme.bodySmall?.copyWith(
                                color: palette.fabAccent,
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: AppTokens.space24),

                  // Tactile Numeric Keypad
                  _NumericKeypad(
                    onDigit: _onDigit,
                    onBackspace: _onBackspace,
                    isBusy: authState.isBusy,
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

class _NumericKeypad extends StatelessWidget {
  const _NumericKeypad({
    required this.onDigit,
    required this.onBackspace,
    required this.isBusy,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final bool isBusy;

  static const _rows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['', '0', 'backspace'],
  ];

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: _rows.map((row) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: row.map((key) {
              if (key.isEmpty) {
                return const SizedBox(width: 88, height: 58);
              }
              if (key == 'backspace') {
                return SizedBox(
                  width: 88,
                  height: 58,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: isBusy ? null : onBackspace,
                      borderRadius: BorderRadius.circular(16),
                      child: Center(
                        child: Icon(
                          Icons.backspace_outlined,
                          color: palette.inkSecondary,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                );
              }
              return Container(
                width: 88,
                height: 58,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                child: Material(
                  color: palette.surfaceSubtle.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                    side: BorderSide(
                      color: palette.borderSubtle.withValues(alpha: 0.8),
                    ),
                  ),
                  child: InkWell(
                    key: Key('otp_keypad_$key'),
                    onTap: isBusy ? null : () => onDigit(key),
                    borderRadius: BorderRadius.circular(18),
                    child: Center(
                      child: Text(
                        key,
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: palette.inkPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    ),
  );
  }
}
