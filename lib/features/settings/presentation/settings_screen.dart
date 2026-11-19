import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/theme_provider.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/pin_pad_widget.dart';
import '../../auth/application/auth_controller.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final profile = authState.profile;
    final themeMode = ref.watch(themeModeProvider);
    final palette = context.palette;
    final textTheme = Theme.of(context).textTheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pengaturan'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppTokens.space16,
          AppTokens.space12,
          AppTokens.space16,
          120, // Clean clearance above floating capsule nav
        ),
        children: [
          // Profile Card - Modern Fintech
          Container(
            padding: const EdgeInsets.all(AppTokens.space20),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(AppTokens.radiusLg),
              border: Border.all(color: palette.border),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.25)
                      : Colors.black.withValues(alpha: 0.03),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: palette.sageSurface,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: palette.sageBorder),
                  ),
                  child: Center(
                    child: Text(
                      profile?.initials ?? 'U',
                      style: textTheme.titleLarge?.copyWith(
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
                        profile?.fullName.isNotEmpty == true
                            ? profile!.fullName
                            : 'Pengguna Tabungan',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: palette.inkPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        profile?.email ?? '',
                        style: textTheme.bodySmall?.copyWith(
                          color: palette.inkSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.space24),

          // Appearance (Light / Dark / System)
          Text(
            'TAMPILAN',
            style: textTheme.labelSmall?.copyWith(
              color: palette.inkSecondary,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppTokens.space8),
          Container(
            padding: const EdgeInsets.all(AppTokens.space16),
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
              border: Border.all(color: palette.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Mode Tema',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: palette.inkPrimary,
                  ),
                ),
                const SizedBox(height: AppTokens.space12),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<ThemeMode>(
                    key: const Key('theme_mode_selector'),
                    style: SegmentedButton.styleFrom(
                      selectedBackgroundColor: palette.sageSurface,
                      selectedForegroundColor: palette.sageText,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                      ),
                    ),
                    segments: const [
                      ButtonSegment(
                        value: ThemeMode.system,
                        icon: Icon(Icons.brightness_auto_outlined, size: 18),
                        label: Text('Sistem'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.light,
                        icon: Icon(Icons.light_mode_outlined, size: 18),
                        label: Text('Terang'),
                      ),
                      ButtonSegment(
                        value: ThemeMode.dark,
                        icon: Icon(Icons.dark_mode_outlined, size: 18),
                        label: Text('Gelap'),
                      ),
                    ],
                    selected: {themeMode},
                    onSelectionChanged: (selected) {
                      if (selected.isNotEmpty) {
                        ref
                            .read(themeModeProvider.notifier)
                            .setThemeMode(selected.first);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.space24),

          // Notifications
          Text(
            'NOTIFIKASI',
            style: textTheme.labelSmall?.copyWith(
              color: palette.inkSecondary,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppTokens.space8),
          Container(
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
              border: Border.all(color: palette.border),
            ),
            child: Column(
              children: [
                SwitchListTile(
                  key: const Key('notifications_toggle'),
                  title: Text(
                    'Pengingat Harian Adaptif',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: palette.inkPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Kirim pengingat hanya jika kamu belum mencatat transaksi hari ini.',
                    style: textTheme.bodySmall?.copyWith(
                      color: palette.inkSecondary,
                    ),
                  ),
                  value: profile?.notificationsEnabled ?? true,
                  activeThumbColor: palette.sageText,
                  onChanged: profile == null
                      ? null
                      : (enabled) async {
                          final err = await ref
                              .read(authControllerProvider.notifier)
                              .updateNotificationPreferences(
                                enabled: enabled,
                                reminderHour: profile.reminderHour,
                              );
                          if (err != null && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(err)),
                            );
                          }
                        },
                ),
                if (profile?.notificationsEnabled == true) ...[
                  Divider(color: palette.border, height: 1, indent: AppTokens.space16),
                  ListTile(
                    leading: Icon(Icons.schedule_rounded, color: palette.inkSecondary),
                    title: Text(
                      'Jam Pengingat (WIB)',
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: palette.sageSurface,
                        borderRadius: BorderRadius.circular(AppTokens.radiusPill),
                      ),
                      child: Text(
                        '${profile!.reminderHour.toString().padLeft(2, '0')}:00 WIB',
                        style: textTheme.titleSmall?.copyWith(
                          color: palette.sageText,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    onTap: () => _pickReminderHour(context, ref, profile.reminderHour),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: AppTokens.space24),

          // Security & PIN
          Text(
            'KEAMANAN & SESI',
            style: textTheme.labelSmall?.copyWith(
              color: palette.inkSecondary,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppTokens.space8),
          Container(
            decoration: BoxDecoration(
              color: palette.surface,
              borderRadius: BorderRadius.circular(AppTokens.radiusMd),
              border: Border.all(color: palette.border),
            ),
            child: Column(
              children: [
                ListTile(
                  key: const Key('change_pin_tile'),
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: palette.surfaceSubtle,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.pin_outlined, size: 20, color: palette.inkPrimary),
                  ),
                  title: Text(
                    'Ubah PIN 6 Digit',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: palette.inkPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Disimpan terenkripsi dengan Argon2id di server.',
                    style: textTheme.bodySmall?.copyWith(
                      color: palette.inkSecondary,
                    ),
                  ),
                  trailing: Icon(Icons.chevron_right_rounded, color: palette.inkSecondary),
                  onTap: () => _ChangePinSheet.show(context),
                ),
                Divider(color: palette.border, height: 1, indent: AppTokens.space16),
                ListTile(
                  key: const Key('lock_now_tile'),
                  leading: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: palette.surfaceSubtle,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.lock_outline_rounded, size: 20, color: palette.inkPrimary),
                  ),
                  title: Text(
                    'Kunci Aplikasi Sekarang',
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: palette.inkPrimary,
                    ),
                  ),
                  subtitle: Text(
                    'Sesi otomatis berakhir setelah 15 menit tidak aktif.',
                    style: textTheme.bodySmall?.copyWith(
                      color: palette.inkSecondary,
                    ),
                  ),
                  trailing: Icon(Icons.chevron_right_rounded, color: palette.inkSecondary),
                  onTap: () {
                    Navigator.of(context).pop();
                    ref.read(authControllerProvider.notifier).lockAppManually();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: AppTokens.space32),

          // Logout Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              key: const Key('logout_button'),
              style: OutlinedButton.styleFrom(
                foregroundColor: palette.danger,
                side: BorderSide(color: palette.danger.withValues(alpha: 0.3)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTokens.radiusMd),
                ),
              ),
              onPressed: () => _confirmSignOut(context, ref),
              icon: const Icon(Icons.logout_rounded, size: 20),
              label: const Text(
                'Keluar dari Akun',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickReminderHour(
    BuildContext context,
    WidgetRef ref,
    int currentHour,
  ) async {
    final hours = List<int>.generate(17, (i) => i + 6); // 06:00 - 22:00 WIB
    final chosen = await showModalBottomSheet<int>(
      context: context,
      useSafeArea: true,
      builder: (ctx) => ListView.builder(
        shrinkWrap: true,
        itemCount: hours.length,
        itemBuilder: (_, idx) {
          final hour = hours[idx];
          return ListTile(
            title: Text('${hour.toString().padLeft(2, '0')}:00 WIB'),
            trailing: hour == currentHour
                ? Icon(Icons.check_rounded, color: ctx.palette.sageText)
                : null,
            onTap: () => Navigator.of(ctx).pop(hour),
          );
        },
      ),
    );

    if (chosen == null || chosen == currentHour) return;
    final err = await ref
        .read(authControllerProvider.notifier)
        .updateNotificationPreferences(enabled: true, reminderHour: chosen);
    if (err != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
  }

  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusLg),
        ),
        title: const Text('Keluar dari Akun?'),
        content: const Text(
          'Cache lokal terenkripsi di perangkat ini akan dibersihkan saat kamu keluar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ctx.palette.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Keluar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(authControllerProvider.notifier).signOut();
    }
  }
}

class _ChangePinSheet extends ConsumerStatefulWidget {
  const _ChangePinSheet();

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _ChangePinSheet(),
    );
  }

  @override
  ConsumerState<_ChangePinSheet> createState() => _ChangePinSheetState();
}

class _ChangePinSheetState extends ConsumerState<_ChangePinSheet> {
  int _step = 0; // 0: current, 1: new, 2: confirm
  String _currentPin = '';
  String _newPin = '';
  String _confirmPin = '';
  bool _isBusy = false;
  String? _errorText;

  String get _activePin => switch (_step) {
        0 => _currentPin,
        1 => _newPin,
        _ => _confirmPin,
      };

  String get _title => switch (_step) {
        0 => 'Masukkan PIN Saat Ini',
        1 => 'Masukkan PIN Baru',
        _ => 'Konfirmasi PIN Baru',
      };

  Future<void> _onDigit(String digit) async {
    setState(() {
      _errorText = null;
      if (_step == 0 && _currentPin.length < 6) _currentPin += digit;
      if (_step == 1 && _newPin.length < 6) _newPin += digit;
      if (_step == 2 && _confirmPin.length < 6) _confirmPin += digit;
    });

    if (_step == 0 && _currentPin.length == 6) {
      setState(() => _step = 1);
      return;
    }

    if (_step == 1 && _newPin.length == 6) {
      final err = InputValidators.validateNewPin(_newPin);
      if (err != null) {
        setState(() {
          _errorText = err;
          _newPin = '';
        });
        return;
      }
      if (_newPin == _currentPin) {
        setState(() {
          _errorText = 'PIN baru harus berbeda dari PIN saat ini.';
          _newPin = '';
        });
        return;
      }
      setState(() => _step = 2);
      return;
    }

    if (_step == 2 && _confirmPin.length == 6) {
      if (_confirmPin != _newPin) {
        setState(() {
          _errorText = 'Konfirmasi PIN baru tidak cocok.';
          _confirmPin = '';
        });
        return;
      }

      setState(() => _isBusy = true);
      final err = await ref.read(authControllerProvider.notifier).changePin(
            currentPin: _currentPin,
            newPin: _newPin,
          );
      if (!mounted) return;
      if (err != null) {
        setState(() {
          _isBusy = false;
          _errorText = err;
          _step = 0;
          _currentPin = '';
          _newPin = '';
          _confirmPin = '';
        });
        return;
      }

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN keamanan berhasil diperbarui.')),
      );
    }
  }

  void _onBackspace() {
    setState(() {
      _errorText = null;
      if (_step == 0 && _currentPin.isNotEmpty) {
        _currentPin = _currentPin.substring(0, _currentPin.length - 1);
      } else if (_step == 1 && _newPin.isNotEmpty) {
        _newPin = _newPin.substring(0, _newPin.length - 1);
      } else if (_step == 2 && _confirmPin.isNotEmpty) {
        _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
      padding: const EdgeInsets.fromLTRB(
        AppTokens.space24,
        AppTokens.space16,
        AppTokens.space24,
        AppTokens.space32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
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
          const SizedBox(height: AppTokens.space20),
          Text(
            _title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: palette.inkPrimary,
                ),
          ),
          const SizedBox(height: AppTokens.space24),
          PinPadWidget(
            pinLength: _activePin.length,
            isBusy: _isBusy,
            errorText: _errorText,
            onDigitPressed: _onDigit,
            onBackspacePressed: _onBackspace,
          ),
        ],
      ),
    );
  }
}
