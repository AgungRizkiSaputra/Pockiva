import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/validators.dart';
import '../application/transactions_controller.dart';
import '../domain/transaction_category.dart';
import '../domain/transaction_item.dart';

/// Optimized for sub-5-second transaction entry (PRD FR-02 & Section 13):
/// 1. Tap type (Expense/Saving)
/// 2. Tap digits on custom fintech numpad (with '000' shortcut for IDR)
/// 3. Tap category icon
/// 4. Tap Simpan
class QuickAddSheet extends ConsumerStatefulWidget {
  const QuickAddSheet({
    super.key,
    this.initialType = TransactionType.saving,
    this.editingItem,
  });

  final TransactionType initialType;
  final TransactionItem? editingItem;

  static Future<bool?> show(
    BuildContext context, {
    TransactionType initialType = TransactionType.saving,
    TransactionItem? editingItem,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => QuickAddSheet(
        initialType: editingItem?.type ?? initialType,
        editingItem: editingItem,
      ),
    );
  }

  @override
  ConsumerState<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends ConsumerState<QuickAddSheet> {
  late TransactionType _type;
  late String _selectedCategoryCode;
  late String _digits;
  late final String _draftClientId;
  late final TextEditingController _noteController;

  bool _showNoteField = false;
  bool _submittedSuccessfully = false;
  bool _submittingLocal = false;
  String? _validationError;

  bool get _isEditing => widget.editingItem != null;

  @override
  void initState() {
    super.initState();
    _draftClientId = widget.editingItem?.clientId ?? const Uuid().v4();
    _type = widget.editingItem?.type ?? widget.initialType;
    _selectedCategoryCode = widget.editingItem?.category ??
        TransactionCategory.forType(_type).first.code;
    _digits = widget.editingItem != null
        ? widget.editingItem!.amount.round().toString()
        : '';
    _noteController = TextEditingController(text: widget.editingItem?.note ?? '');
    _showNoteField = (widget.editingItem?.note?.isNotEmpty ?? false);
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  double get _amount => InputValidators.parseKeypadAmount(_digits);

  void _switchType(TransactionType next) {
    if (_type == next || _submittingLocal) return;
    HapticFeedback.selectionClick();
    setState(() {
      _type = next;
      _selectedCategoryCode = TransactionCategory.forType(next).first.code;
      _validationError = null;
    });
  }

  void _appendDigits(String token) {
    if (_submittingLocal || _submittedSuccessfully) return;
    if (_digits.isEmpty && (token == '0' || token == '000')) return;
    final next = _digits + token;
    if (next.length > 12) return; // Cap at 999 billion IDR
    HapticFeedback.selectionClick();
    setState(() {
      _digits = next;
      _validationError = null;
    });
  }

  void _backspace() {
    if (_submittingLocal || _digits.isEmpty) return;
    HapticFeedback.lightImpact();
    setState(() {
      _digits = _digits.substring(0, _digits.length - 1);
      _validationError = null;
    });
  }

  void _clearDigits() {
    if (_submittingLocal || _digits.isEmpty) return;
    setState(() {
      _digits = '';
      _validationError = null;
    });
  }

  Future<void> _submit() async {
    if (_submittingLocal || _submittedSuccessfully) return;

    final amountError = InputValidators.validateAmount(_amount);
    if (amountError != null) {
      setState(() => _validationError = amountError);
      return;
    }

    setState(() {
      _submittingLocal = true;
      _validationError = null;
    });

    final note = InputValidators.sanitizeNote(_noteController.text);
    final controller = ref.read(transactionsControllerProvider.notifier);
    final txState = ref.read(transactionsControllerProvider);
    final availableBalance = txState.effectiveSummary.totalBalance;
    final effectiveAvailable = _isEditing && widget.editingItem != null
        ? (widget.editingItem!.type == TransactionType.expense
            ? availableBalance + widget.editingItem!.amount
            : availableBalance - widget.editingItem!.amount)
        : availableBalance;

    if (_type == TransactionType.expense && _amount > effectiveAvailable) {
      setState(() {
        _submittingLocal = false;
        _validationError = effectiveAvailable <= 0
            ? 'Saldo tabungan masih Rp 0. Catat setoran tabungan terlebih dahulu.'
            : 'Pengeluaran melebihi saldo tabungan yang tersedia (${CurrencyFormatter.formatIdr(effectiveAvailable)}).';
      });
      return;
    }

    if (_isEditing) {
      final err = await controller.updateTransaction(
        original: widget.editingItem!,
        type: _type,
        amount: _amount,
        category: _selectedCategoryCode,
        note: note,
        occurredAt: widget.editingItem!.occurredAt,
      );

      if (!mounted) return;
      if (err != null) {
        setState(() {
          _submittingLocal = false;
          _validationError = err;
        });
        return;
      }

      unawaited(HapticFeedback.mediumImpact());
      setState(() {
        _submittingLocal = false;
        _submittedSuccessfully = true;
      });
      await Future<void>.delayed(const Duration(milliseconds: 350));
      if (mounted) {
        final messenger = ScaffoldMessenger.maybeOf(context);
        Navigator.of(context).pop(true);
        messenger?.showSnackBar(
          const SnackBar(content: Text('Transaksi berhasil diperbarui.')),
        );
      }
      return;
    }

    final result = await controller.createTransaction(
      type: _type,
      amount: _amount,
      category: _selectedCategoryCode,
      note: note,
      explicitClientId: _draftClientId,
      validateBalance: true,
    );

    if (!mounted) return;
    if (!result.success) {
      setState(() {
        _submittingLocal = false;
        _validationError = result.errorMessage ?? 'Gagal menyimpan transaksi.';
      });
      return;
    }

    unawaited(HapticFeedback.mediumImpact());
    setState(() {
      _submittingLocal = false;
      _submittedSuccessfully = true;
    });

    final feedbackMsg = result.syncStatus == SyncStatus.synced
        ? '${_type.label} ${CurrencyFormatter.formatIdr(_amount)} tercatat.'
        : 'Tersimpan lokal (${CurrencyFormatter.formatIdr(_amount)}). Akan disinkronkan saat online.';

    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (mounted) {
      final messenger = ScaffoldMessenger.maybeOf(context);
      Navigator.of(context).pop(true);
      messenger?.showSnackBar(
        SnackBar(content: Text(feedbackMsg)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    final categories = TransactionCategory.forType(_type);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final txState = ref.watch(transactionsControllerProvider);
    final availableBalance = txState.effectiveSummary.totalBalance;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isExpenseOver = _type == TransactionType.expense && _amount > availableBalance && availableBalance > 0;

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppTokens.space20,
              AppTokens.space12,
              AppTokens.space20,
              AppTokens.space24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: palette.border,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
                const SizedBox(height: AppTokens.space16),

                // Header + Type Toggle
                Row(
                  children: [
                    Expanded(
                      child: _TypeSegment(
                        selected: _type,
                        onChanged: _switchType,
                      ),
                    ),
                    const SizedBox(width: AppTokens.space12),
                    IconButton(
                      tooltip: 'Tutup',
                      onPressed: _submittingLocal
                          ? null
                          : () => Navigator.of(context).pop(false),
                      icon: Icon(Icons.close_rounded, color: palette.inkSecondary),
                      style: IconButton.styleFrom(
                        backgroundColor: palette.surfaceSubtle,
                        shape: const CircleBorder(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppTokens.space16),

                // Amount Readout Container - Fintech Hero Card
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTokens.space16,
                    vertical: AppTokens.space16,
                  ),
                  decoration: BoxDecoration(
                    color: palette.surfaceSubtle,
                    borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                    border: Border.all(
                      color: _amount > 0
                          ? (_type == TransactionType.saving
                              ? palette.sageBorder
                              : palette.border)
                          : palette.border,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              _type == TransactionType.saving
                                  ? 'Nominal Setoran Tabungan'
                                  : 'Nominal Pengeluaran',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: textTheme.labelMedium?.copyWith(
                                color: palette.inkSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              minimumSize: const Size(44, 28),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: () =>
                                setState(() => _showNoteField = !_showNoteField),
                            icon: Icon(
                              _showNoteField
                                  ? Icons.notes_rounded
                                  : Icons.add_comment_outlined,
                              size: 15,
                              color: palette.fabAccent,
                            ),
                            label: Text(
                              _showNoteField ? 'Tutup Catatan' : '+ Catatan',
                              style: TextStyle(
                                fontSize: 12,
                                color: palette.fabAccent,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          CurrencyFormatter.formatIdr(_amount),
                          key: const Key('quick_add_amount_display'),
                          style: textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            color: _amount > 0
                                ? (_type == TransactionType.saving
                                    ? palette.sageText
                                    : palette.inkPrimary)
                                : palette.inkSecondary.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                      if (_type == TransactionType.expense) ...[
                        const SizedBox(height: 6),
                        if (availableBalance <= 0) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: palette.warning.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: palette.warning.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline_rounded, size: 16, color: palette.warning),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Saldo tabungan masih Rp 0. Perlu setoran awal.',
                                    style: textTheme.labelSmall?.copyWith(
                                      color: palette.warning,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                InkWell(
                                  onTap: () => _switchType(TransactionType.saving),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    child: Text(
                                      'Ubah ke Setoran',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: palette.fabAccent,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          Text(
                            'Saldo tabungan tersedia: ${CurrencyFormatter.formatIdr(availableBalance)}',
                            style: textTheme.labelSmall?.copyWith(
                              color: palette.inkSecondary,
                              fontSize: 11,
                            ),
                          ),
                          if (isExpenseOver) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: palette.danger.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: palette.danger.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.error_outline_rounded, size: 16, color: palette.danger),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Nominal melebihi saldo tabungan (${CurrencyFormatter.formatIdr(availableBalance)}).',
                                      style: textTheme.labelSmall?.copyWith(
                                        color: palette.danger,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ],
                      if (_validationError != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _validationError!,
                          key: const Key('quick_add_error_text'),
                          style: textTheme.bodySmall?.copyWith(
                            color: palette.danger,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                if (_showNoteField) ...[
                  const SizedBox(height: AppTokens.space12),
                  TextField(
                    key: const Key('quick_add_note_field'),
                    controller: _noteController,
                    maxLength: InputValidators.maxNoteLength,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: 'Catatan singkat (opsional)',
                      hintText: 'Contoh: Kopi pagi, Bonus proyek, Hadiah',
                      counterText: '',
                      filled: true,
                      fillColor: palette.surfaceSubtle,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                        borderSide: BorderSide(color: palette.border),
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: AppTokens.space16),

                // Category Icons Strip - Modern Horizontal Selector
                SizedBox(
                  height: 78,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: categories.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(width: AppTokens.space8),
                    itemBuilder: (context, index) {
                      final cat = categories[index];
                      final isSelected = cat.code == _selectedCategoryCode;
                      return InkWell(
                        key: Key('quick_add_cat_${cat.code}'),
                        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                        onTap: _submittingLocal
                            ? null
                            : () {
                                HapticFeedback.selectionClick();
                                setState(() => _selectedCategoryCode = cat.code);
                              },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 140),
                          width: 80,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (_type == TransactionType.saving
                                    ? palette.sageSurface
                                    : palette.surfaceSubtle)
                                : palette.surface,
                            borderRadius:
                                BorderRadius.circular(AppTokens.radiusMd),
                            border: Border.all(
                              color: isSelected
                                  ? (_type == TransactionType.saving
                                      ? palette.sageBorder
                                      : palette.fabAccent)
                                  : palette.border,
                              width: isSelected ? 1.8 : 1,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                cat.icon,
                                size: 22,
                                color: isSelected
                                    ? (_type == TransactionType.saving
                                        ? palette.sageText
                                        : palette.fabAccent)
                                    : palette.inkSecondary,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                cat.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: textTheme.labelSmall?.copyWith(
                                  fontSize: 11,
                                  color: isSelected
                                      ? palette.inkPrimary
                                      : palette.inkSecondary,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: AppTokens.space16),

                // Custom High-Speed Numpad
                _QuickNumpad(
                  enabled: !_submittingLocal && !_submittedSuccessfully,
                  onToken: _appendDigits,
                  onBackspace: _backspace,
                  onLongBackspace: _clearDigits,
                ),

                const SizedBox(height: AppTokens.space16),

                // Submit CTA with instant visual feedback
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    key: const Key('quick_add_submit_button'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _submittedSuccessfully
                          ? palette.success
                          : palette.fabAccent,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                      ),
                      elevation: 0,
                    ),
                    onPressed:
                        (_submittingLocal || _submittedSuccessfully) ? null : _submit,
                    child: _submittedSuccessfully
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_outline_rounded, size: 20),
                              SizedBox(width: AppTokens.space8),
                              Text(
                                'Tersimpan',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          )
                        : _submittingLocal
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _isEditing
                                    ? 'Simpan Perubahan'
                                    : 'Simpan ${_type.label}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TypeSegment extends StatelessWidget {
  const _TypeSegment({
    required this.selected,
    required this.onChanged,
  });

  final TransactionType selected;
  final ValueChanged<TransactionType> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: palette.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
        border: Border.all(color: palette.border),
      ),
      child: Row(
        children: TransactionType.values.map((type) {
          final active = type == selected;
          return Expanded(
            child: GestureDetector(
              key: Key('quick_add_type_${type.value}'),
              onTap: () => onChanged(type),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 140),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: active ? palette.surface : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: active
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    type.label,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          fontSize: 13,
                          color: active ? palette.inkPrimary : palette.inkSecondary,
                          fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                        ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _QuickNumpad extends StatelessWidget {
  const _QuickNumpad({
    required this.enabled,
    required this.onToken,
    required this.onBackspace,
    required this.onLongBackspace,
  });

  final bool enabled;
  final ValueChanged<String> onToken;
  final VoidCallback onBackspace;
  final VoidCallback onLongBackspace;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _row(context, const ['1', '2', '3']),
        const SizedBox(height: AppTokens.space8),
        _row(context, const ['4', '5', '6']),
        const SizedBox(height: AppTokens.space8),
        _row(context, const ['7', '8', '9']),
        const SizedBox(height: AppTokens.space8),
        Row(
          children: [
            Expanded(
              child: _NumKey(
                key: const Key('numpad_000'),
                label: '000',
                enabled: enabled,
                onTap: () => onToken('000'),
              ),
            ),
            const SizedBox(width: AppTokens.space8),
            Expanded(
              child: _NumKey(
                key: const Key('numpad_0'),
                label: '0',
                enabled: enabled,
                onTap: () => onToken('0'),
              ),
            ),
            const SizedBox(width: AppTokens.space8),
            Expanded(
              child: _BackspaceKey(
                enabled: enabled,
                onTap: onBackspace,
                onLongPress: onLongBackspace,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _row(BuildContext context, List<String> labels) {
    return Row(
      children: [
        for (int i = 0; i < labels.length; i++) ...[
          if (i > 0) const SizedBox(width: AppTokens.space8),
          Expanded(
            child: _NumKey(
              key: Key('numpad_${labels[i]}'),
              label: labels[i],
              enabled: enabled,
              onTap: () => onToken(labels[i]),
            ),
          ),
        ],
      ],
    );
  }
}

class _NumKey extends StatelessWidget {
  const _NumKey({
    super.key,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: palette.surfaceSubtle,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: enabled ? onTap : null,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : palette.borderSubtle,
              width: 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 20,
                    color: palette.inkPrimary,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BackspaceKey extends StatelessWidget {
  const _BackspaceKey({
    required this.enabled,
    required this.onTap,
    required this.onLongPress,
  });

  final bool enabled;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Tooltip(
      message: 'Hapus digit (tahan untuk bersihkan)',
      child: Material(
        color: palette.surfaceSubtle,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          key: const Key('numpad_backspace'),
          borderRadius: BorderRadius.circular(16),
          onTap: enabled ? onTap : null,
          onLongPress: enabled ? onLongPress : null,
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.08) : palette.borderSubtle,
                width: 1,
              ),
            ),
            child: Center(
              child: Icon(
                Icons.backspace_outlined,
                size: 22,
                color: palette.inkPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
