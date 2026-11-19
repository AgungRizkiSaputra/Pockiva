import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../../auth/application/auth_controller.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController(text: 'Dana Darurat');
  final _amountController = TextEditingController(text: '5000000');

  int _step = 0;
  DateTime? _deadline;

  static const _presetAmounts = <double>[
    2000000,
    5000000,
    10000000,
    25000000,
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? now.add(const Duration(days: 180)),
      firstDate: now.add(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 3650)),
    );
    if (picked != null) {
      setState(() => _deadline = picked);
    }
  }

  Future<void> _submitTarget() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final amount = InputValidators.parseKeypadAmount(_amountController.text);
    final title = InputValidators.sanitizeTargetTitle(_titleController.text);

    await ref.read(authControllerProvider.notifier).completeOnboarding(
          savingsTarget: amount,
          targetTitle: title,
          deadline: _deadline,
        );
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
        leading: _step == 1
            ? IconButton(
                tooltip: 'Kembali',
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: authState.isBusy ? null : () => setState(() => _step = 0),
              )
            : null,
        title: Text(
          _step == 0 ? 'Mulai' : 'Target Tabungan',
          style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.space24,
              vertical: AppTokens.space12,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: _step == 0
                  ? _buildIntroStep(context, palette, textTheme)
                  : _buildTargetStep(context, palette, textTheme, authState),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIntroStep(
    BuildContext context,
    AppColorPalette palette,
    TextTheme textTheme,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Step Pill
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
                  'Langkah 1/2: Panduan',
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
        const SizedBox(height: AppTokens.space16),
        Text(
          'Dua langkah sederhana untuk kebiasaan menabung.',
          style: textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: AppTokens.space12),
        Text(
          'Tetapkan satu target tabungan utama dulu. Setiap kali kamu menabung atau berbelanja, cukup tekan tombol biru di beranda untuk mencatat dalam hitungan detik.',
          style: textTheme.bodyMedium?.copyWith(
            color: palette.inkSecondary,
            height: 1.5,
          ),
        ),
        const SizedBox(height: AppTokens.space24),
        Container(
          padding: const EdgeInsets.all(AppTokens.space20),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(AppTokens.radiusLg),
            border: Border.all(color: palette.borderSubtle),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Column(
            children: [
              _StepSummaryRow(
                number: '1',
                title: 'Tentukan target jelas',
                detail: 'Misalnya Dana Darurat, Laptop Baru, atau Liburan.',
              ),
              Divider(height: AppTokens.space24),
              _StepSummaryRow(
                number: '2',
                title: 'Catat harian di bawah 5 detik',
                detail:
                    'Setiap aktivitas harian menjaga streak dan memperbarui insight bulananmu otomatis.',
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTokens.space32),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            key: const Key('onboarding_next_button'),
            onPressed: () => setState(() => _step = 1),
            child: const Text('Lanjut Atur Target'),
          ),
        ),
      ],
    );
  }

  Widget _buildTargetStep(
    BuildContext context,
    AppColorPalette palette,
    TextTheme textTheme,
    AuthControllerState authState,
  ) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Step Pill
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
                    'Langkah 2/2: Target Tabungan',
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
          const SizedBox(height: AppTokens.space16),
          Text(
            'Apa target tabungan utamamu?',
            style: textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: AppTokens.space8),
          Text(
            'Kamu bisa mengubah nominal atau tenggat kapan saja dari halaman Progres.',
            style: textTheme.bodyMedium?.copyWith(
              color: palette.inkSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppTokens.space24),
          TextFormField(
            key: const Key('target_title_field'),
            controller: _titleController,
            textInputAction: TextInputAction.next,
            maxLength: InputValidators.maxTargetTitleLength,
            decoration: const InputDecoration(
              labelText: 'Nama Target',
              hintText: 'Contoh: Dana Darurat, DP Motor, Liburan',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Nama target tidak boleh kosong.';
              }
              return null;
            },
          ),
          const SizedBox(height: AppTokens.space16),
          TextFormField(
            key: const Key('target_amount_field'),
            controller: _amountController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Nominal Target (Rp)',
              prefixText: 'Rp ',
              hintText: '5000000',
            ),
            validator: (value) {
              final parsed = InputValidators.parseKeypadAmount(value ?? '');
              return InputValidators.validateSavingsTarget(parsed);
            },
          ),
          const SizedBox(height: AppTokens.space12),
          Wrap(
            spacing: AppTokens.space8,
            runSpacing: AppTokens.space8,
            children: _presetAmounts.map((preset) {
              final isSelected =
                  _amountController.text == preset.toInt().toString();
              return ActionChip(
                backgroundColor: isSelected ? palette.sageSurface : palette.surfaceSubtle,
                side: BorderSide(
                  color: isSelected ? palette.sageText : palette.borderSubtle,
                ),
                label: Text(
                  CurrencyFormatter.formatCompactIdr(preset),
                  style: TextStyle(
                    color: isSelected ? palette.sageText : palette.inkPrimary,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                onPressed: () {
                  setState(() {
                    _amountController.text = preset.toInt().toString();
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: AppTokens.space24),
          InkWell(
            onTap: _pickDeadline,
            borderRadius: BorderRadius.circular(AppTokens.radiusMd),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Tenggat Waktu (Opsional)',
                suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
              ),
              child: Text(
                _deadline != null
                    ? DateFormatter.formatDayMonthYear(_deadline!)
                    : 'Pilih tanggal target',
                style: textTheme.bodyMedium?.copyWith(
                  color: _deadline != null
                      ? palette.inkPrimary
                      : palette.inkSecondary,
                ),
              ),
            ),
          ),
          if (authState.errorMessage != null) ...[
            const SizedBox(height: AppTokens.space16),
            Text(
              authState.errorMessage!,
              style: textTheme.bodySmall?.copyWith(
                color: palette.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: AppTokens.space32),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const Key('save_target_button'),
              onPressed: authState.isBusy ? null : _submitTarget,
              child: authState.isBusy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Simpan Target & Masuk Beranda'),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepSummaryRow extends StatelessWidget {
  const _StepSummaryRow({
    required this.number,
    required this.title,
    required this.detail,
  });

  final String number;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: palette.sageSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: palette.sageBorder),
          ),
          child: Center(
            child: Text(
              number,
              style: textTheme.labelLarge?.copyWith(
                color: palette.sageText,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(width: AppTokens.space16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                detail,
                style: textTheme.bodySmall?.copyWith(
                  color: palette.inkSecondary,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
