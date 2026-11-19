import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/pin_pad_widget.dart';
import '../application/auth_controller.dart';

class PinSetupScreen extends ConsumerStatefulWidget {
  const PinSetupScreen({super.key});

  @override
  ConsumerState<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends ConsumerState<PinSetupScreen> {
  String _firstPin = '';
  String _confirmPin = '';
  bool _isConfirmStep = false;
  String? _localError;

  String get _activePin => _isConfirmStep ? _confirmPin : _firstPin;

  Future<void> _onDigit(String digit) async {
    setState(() {
      _localError = null;
      if (_isConfirmStep) {
        if (_confirmPin.length < 6) _confirmPin += digit;
      } else {
        if (_firstPin.length < 6) _firstPin += digit;
      }
    });

    if (!_isConfirmStep && _firstPin.length == 6) {
      final validationError = InputValidators.validateNewPin(_firstPin);
      if (validationError != null) {
        setState(() {
          _localError = validationError;
          _firstPin = '';
        });
        return;
      }
      setState(() => _isConfirmStep = true);
      return;
    }

    if (_isConfirmStep && _confirmPin.length == 6) {
      if (_confirmPin != _firstPin) {
        setState(() {
          _localError = 'Konfirmasi PIN tidak cocok. Silakan ulangi.';
          _confirmPin = '';
        });
        return;
      }

      final ok = await ref
          .read(authControllerProvider.notifier)
          .setupInitialPin(_confirmPin);
      if (!ok && mounted) {
        setState(() {
          _firstPin = '';
          _confirmPin = '';
          _isConfirmStep = false;
        });
      }
    }
  }

  void _onBackspace() {
    setState(() {
      _localError = null;
      if (_isConfirmStep && _confirmPin.isNotEmpty) {
        _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
      } else if (!_isConfirmStep && _firstPin.isNotEmpty) {
        _firstPin = _firstPin.substring(0, _firstPin.length - 1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: _isConfirmStep
            ? IconButton(
                tooltip: 'Kembali',
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: authState.isBusy
                    ? null
                    : () => setState(() {
                          _isConfirmStep = false;
                          _confirmPin = '';
                          _localError = null;
                        }),
              )
            : null,
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
              child: const Text('Keluar'),
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
                  // Step Indicator Pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppTokens.space10,
                      vertical: AppTokens.space4,
                    ),
                    decoration: BoxDecoration(
                      color: palette.sageSurface,
                      borderRadius: BorderRadius.circular(AppTokens.radiusFull),
                      border: Border.all(color: palette.sageBorder),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: palette.sageText,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: AppTokens.space6),
                        Flexible(
                          child: Text(
                            _isConfirmStep
                                ? 'Langkah 2/2: Konfirmasi PIN'
                                : 'Langkah 1/2: Buat PIN',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.labelSmall?.copyWith(
                              color: palette.sageText,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppTokens.space20),
                  // Icon Squircle
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: palette.surfaceSubtle,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: palette.borderSubtle),
                    ),
                    child: Center(
                      child: Icon(
                        _isConfirmStep
                            ? Icons.verified_user_outlined
                            : Icons.lock_outline_rounded,
                        color: palette.sageText,
                        size: 26,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTokens.space16),
                  Text(
                    _isConfirmStep
                        ? 'Konfirmasi PIN 6 Digit'
                        : (authState.isResetPinMode
                            ? 'Buat PIN Baru'
                            : 'Buat PIN Keamanan'),
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
                      _isConfirmStep
                          ? 'Masukkan kembali 6 digit PIN yang sama untuk memastikan.'
                          : (authState.isResetPinMode
                              ? 'Masukkan 6 digit PIN baru untuk membuka dan mengamankan kembali data tabunganmu.'
                              : 'PIN digunakan untuk membuka aplikasi dan disimpan dengan hash Argon2id di server.'),
                      textAlign: TextAlign.center,
                      style: textTheme.bodyMedium?.copyWith(
                        color: palette.inkSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTokens.space28),
                  PinPadWidget(
                    pinLength: _activePin.length,
                    isBusy: authState.isBusy,
                    errorText: _localError ?? authState.errorMessage,
                    onDigitPressed: _onDigit,
                    onBackspacePressed: _onBackspace,
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
