import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import '../../../core/notifications/notification_service.dart';
import '../../../core/security/error_mapper.dart';
import '../../../core/security/inactivity_guard.dart';
import '../../../core/security/secure_storage_service.dart';
import '../data/auth_repository.dart';
import '../domain/user_profile.dart';

enum AuthStatus {
  loading,
  unconfigured,
  unauthenticated,
  needsPinSetup,
  pinLocked,
  otpVerification,
  needsOnboarding,
  authenticated,
}

@immutable
class AuthControllerState {
  const AuthControllerState({
    required this.status,
    this.profile,
    this.errorMessage,
    this.inactivityNotice,
    this.isBusy = false,
    this.isResetPinMode = false,
    this.resetEmail,
  });

  final AuthStatus status;
  final UserProfile? profile;
  final String? errorMessage;
  final String? inactivityNotice;
  final bool isBusy;
  final bool isResetPinMode;
  final String? resetEmail;

  AuthControllerState copyWith({
    AuthStatus? status,
    UserProfile? profile,
    bool clearProfile = false,
    String? errorMessage,
    bool clearError = false,
    String? inactivityNotice,
    bool clearInactivityNotice = false,
    bool? isBusy,
    bool? isResetPinMode,
    String? resetEmail,
    bool clearResetEmail = false,
  }) {
    return AuthControllerState(
      status: status ?? this.status,
      profile: clearProfile ? null : (profile ?? this.profile),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      inactivityNotice: clearInactivityNotice
          ? null
          : (inactivityNotice ?? this.inactivityNotice),
      isBusy: isBusy ?? this.isBusy,
      isResetPinMode: isResetPinMode ?? this.isResetPinMode,
      resetEmail: clearResetEmail ? null : (resetEmail ?? this.resetEmail),
    );
  }
}

class AuthController extends StateNotifier<AuthControllerState> {
  AuthController({
    required AuthRepository? repository,
    required SecureStorageService storage,
    required NotificationService notifications,
  })  : _repository = repository,
        _notifications = notifications,
        super(const AuthControllerState(status: AuthStatus.loading)) {
    _inactivityGuard = InactivitySessionGuard(
      storage: storage,
      onTimeout: _handleInactivityTimeout,
    );
    unawaited(_bootstrap());
  }

  final AuthRepository? _repository;
  final NotificationService _notifications;
  late final InactivitySessionGuard _inactivityGuard;
  StreamSubscription<sb.AuthState>? _authSub;
  bool _pinVerifiedInSession = false;

  Future<void> _bootstrap() async {
    final repo = _repository;
    if (repo == null) {
      state = const AuthControllerState(status: AuthStatus.unconfigured);
      return;
    }

    _authSub = repo.onAuthStateChange.listen((authEvent) {
      if (authEvent.event == sb.AuthChangeEvent.signedIn ||
          (authEvent.event == sb.AuthChangeEvent.initialSession &&
              authEvent.session != null)) {
        if (state.isResetPinMode) {
          unawaited(() async {
            final profile = await repo.fetchProfile();
            state = AuthControllerState(
              status: AuthStatus.needsPinSetup,
              profile: profile,
              isResetPinMode: true,
            );
          }());
        } else if (state.status == AuthStatus.unauthenticated ||
            state.status == AuthStatus.loading) {
          unawaited(
            _loadSignedInUser(requirePinIfConfigured: !_pinVerifiedInSession),
          );
        }
      } else if (authEvent.event == sb.AuthChangeEvent.signedOut) {
        _pinVerifiedInSession = false;
        unawaited(_inactivityGuard.stop());
        if (state.status != AuthStatus.unauthenticated) {
          state = state.copyWith(
            status: AuthStatus.unauthenticated,
            clearProfile: true,
            isBusy: false,
          );
        }
      }
    });

    if (!repo.hasActiveSession) {
      state = const AuthControllerState(status: AuthStatus.unauthenticated);
      return;
    }

    await _loadSignedInUser(requirePinIfConfigured: true);
  }

  Future<void> _loadSignedInUser({required bool requirePinIfConfigured}) async {
    final repo = _repository;
    if (repo == null) return;

    state = state.copyWith(isBusy: true, clearError: true);
    try {
      final profile = await repo.fetchProfile();

      if (!profile.hasPin) {
        state = AuthControllerState(
          status: AuthStatus.needsPinSetup,
          profile: profile,
        );
        return;
      }

      if (requirePinIfConfigured && !_pinVerifiedInSession) {
        state = AuthControllerState(
          status: AuthStatus.pinLocked,
          profile: profile,
        );
        return;
      }

      if (!profile.onboardingCompleted) {
        state = AuthControllerState(
          status: AuthStatus.needsOnboarding,
          profile: profile,
        );
        return;
      }

      await _inactivityGuard.start();
      state = AuthControllerState(
        status: AuthStatus.authenticated,
        profile: profile,
      );
      unawaited(_syncFcmTokenIfEnabled(profile));
    } catch (e) {
      state = AuthControllerState(
        status: AuthStatus.unauthenticated,
        errorMessage: ErrorMapper.toUserMessage(e),
      );
    }
  }

  Future<void> signInWithGoogle() async {
    final repo = _repository;
    if (repo == null) return;

    state = state.copyWith(
      isBusy: true,
      clearError: true,
      clearInactivityNotice: true,
    );

    try {
      await repo.signInWithGoogle();
      if (repo.hasActiveSession) {
        await _loadSignedInUser(requirePinIfConfigured: true);
      } else {
        // OAuth redirect opened externally; auth state listener will resume
        state = state.copyWith(isBusy: false);
      }
    } catch (e) {
      state = state.copyWith(
        isBusy: false,
        errorMessage: ErrorMapper.toUserMessage(e),
      );
    }
  }

  Future<bool> setupInitialPin(String pin) async {
    final repo = _repository;
    if (repo == null) return false;

    final isReset = state.isResetPinMode;
    state = state.copyWith(isBusy: true, clearError: true);
    try {
      await repo.setOrChangePin(newPin: pin, isReset: isReset);
      _pinVerifiedInSession = true;
      final updatedProfile = (state.profile)?.copyWith(hasPin: true) ??
          await repo.fetchProfile();

      if (!updatedProfile.onboardingCompleted) {
        state = AuthControllerState(
          status: AuthStatus.needsOnboarding,
          profile: updatedProfile,
        );
      } else {
        await _inactivityGuard.start();
        state = AuthControllerState(
          status: AuthStatus.authenticated,
          profile: updatedProfile,
        );
      }
      return true;
    } catch (e) {
      state = state.copyWith(
        isBusy: false,
        errorMessage: ErrorMapper.toUserMessage(e),
      );
      return false;
    }
  }

  /// Initiates the secure Forgot PIN OTP flow by sending a 6-digit OTP to the user's email.
  Future<bool> startForgotPinOtpFlow() async {
    final repo = _repository;
    if (repo == null) return false;

    final targetEmail = state.profile?.email ?? repo.currentUserEmail;
    if (targetEmail == null || targetEmail.isEmpty) {
      state = state.copyWith(
        errorMessage: 'Email akun tidak ditemukan. Silakan masuk kembali.',
      );
      return false;
    }

    state = state.copyWith(isBusy: true, clearError: true);
    try {
      await repo.sendPasswordResetOtp(targetEmail);
      state = state.copyWith(
        status: AuthStatus.otpVerification,
        resetEmail: targetEmail,
        isResetPinMode: true,
        isBusy: false,
        clearError: true,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isBusy: false,
        errorMessage: ErrorMapper.toUserMessage(e),
      );
      return false;
    }
  }

  /// Verifies the 6-digit OTP entered by the user.
  /// If valid, transitions directly to [AuthStatus.needsPinSetup] with [isResetPinMode] enabled.
  Future<bool> verifyForgotPinOtp(String token) async {
    final repo = _repository;
    if (repo == null) return false;

    final email = state.resetEmail ?? state.profile?.email ?? repo.currentUserEmail;
    if (email == null || email.isEmpty) {
      state = state.copyWith(
        errorMessage: 'Email sesi verifikasi tidak valid.',
      );
      return false;
    }

    state = state.copyWith(isBusy: true, clearError: true);
    try {
      await repo.verifyPasswordResetOtp(email: email, token: token.trim());
      final profile = state.profile ?? await repo.fetchProfile();
      state = AuthControllerState(
        status: AuthStatus.needsPinSetup,
        profile: profile,
        isResetPinMode: true,
        isBusy: false,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isBusy: false,
        errorMessage: ErrorMapper.toUserMessage(e),
      );
      return false;
    }
  }

  /// Resends the 6-digit OTP to the user's reset email.
  Future<bool> resendForgotPinOtp() async {
    final repo = _repository;
    if (repo == null) return false;

    final email = state.resetEmail ?? state.profile?.email ?? repo.currentUserEmail;
    if (email == null) return false;

    state = state.copyWith(isBusy: true, clearError: true);
    try {
      await repo.sendPasswordResetOtp(email);
      state = state.copyWith(isBusy: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isBusy: false,
        errorMessage: ErrorMapper.toUserMessage(e),
      );
      return false;
    }
  }

  /// Cancels OTP verification and returns back to PIN verification.
  void cancelOtpVerification() {
    state = state.copyWith(
      status: AuthStatus.pinLocked,
      isResetPinMode: false,
      clearResetEmail: true,
      clearError: true,
      isBusy: false,
    );
  }

  /// Initiates the secure Forgot PIN re-authentication flow via Google (fallback).
  /// Once identity is verified, transitions directly to [AuthStatus.needsPinSetup]
  /// with [isResetPinMode] enabled.
  Future<bool> startForgotPinFlow() async {
    final repo = _repository;
    if (repo == null) return false;

    state = state.copyWith(isBusy: true, isResetPinMode: true, clearError: true);
    try {
      await repo.signInWithGoogle();
      if (repo.hasActiveSession) {
        final profile = await repo.fetchProfile();
        state = AuthControllerState(
          status: AuthStatus.needsPinSetup,
          profile: profile,
          isResetPinMode: true,
        );
        return true;
      } else {
        state = state.copyWith(isBusy: false);
        return false;
      }
    } catch (e) {
      state = state.copyWith(
        isBusy: false,
        isResetPinMode: false,
        errorMessage: ErrorMapper.toUserMessage(e),
      );
      return false;
    }
  }

  Future<bool> verifyPin(String pin) async {
    final repo = _repository;
    if (repo == null) return false;

    state = state.copyWith(isBusy: true, clearError: true);
    try {
      await repo.verifyPin(pin);
      _pinVerifiedInSession = true;

      final profile = state.profile ?? await repo.fetchProfile();
      if (!profile.onboardingCompleted) {
        state = AuthControllerState(
          status: AuthStatus.needsOnboarding,
          profile: profile,
        );
      } else {
        await _inactivityGuard.start();
        state = AuthControllerState(
          status: AuthStatus.authenticated,
          profile: profile,
        );
        unawaited(_syncFcmTokenIfEnabled(profile));
      }
      return true;
    } catch (e) {
      state = state.copyWith(
        isBusy: false,
        errorMessage: ErrorMapper.toUserMessage(e),
      );
      return false;
    }
  }

  Future<String?> changePin({
    required String currentPin,
    required String newPin,
  }) async {
    final repo = _repository;
    if (repo == null) return 'Layanan tidak tersedia.';

    try {
      await repo.setOrChangePin(currentPin: currentPin, newPin: newPin);
      return null;
    } catch (e) {
      return ErrorMapper.toUserMessage(e);
    }
  }

  Future<bool> completeOnboarding({
    required double savingsTarget,
    required String targetTitle,
    DateTime? deadline,
  }) async {
    final repo = _repository;
    if (repo == null) return false;

    state = state.copyWith(isBusy: true, clearError: true);
    try {
      final updated = await repo.updateProfile(
        savingsTarget: savingsTarget,
        savingsTargetTitle: targetTitle,
        savingsTargetDeadline: deadline,
        onboardingCompleted: true,
      );
      await _inactivityGuard.start();
      state = AuthControllerState(
        status: AuthStatus.authenticated,
        profile: updated,
      );
      unawaited(_syncFcmTokenIfEnabled(updated));
      return true;
    } catch (e) {
      state = state.copyWith(
        isBusy: false,
        errorMessage: ErrorMapper.toUserMessage(e),
      );
      return false;
    }
  }

  Future<String?> updateSavingsTarget({
    required double savingsTarget,
    required String targetTitle,
    DateTime? deadline,
    bool clearDeadline = false,
  }) async {
    final repo = _repository;
    if (repo == null) return 'Backend belum terkonfigurasi.';

    try {
      final updated = await repo.updateProfile(
        savingsTarget: savingsTarget,
        savingsTargetTitle: targetTitle,
        savingsTargetDeadline: deadline,
        clearDeadline: clearDeadline,
      );
      state = state.copyWith(profile: updated);
      return null;
    } catch (e) {
      return ErrorMapper.toUserMessage(e);
    }
  }

  Future<String?> updateNotificationPreferences({
    required bool enabled,
    required int reminderHour,
  }) async {
    final repo = _repository;
    if (repo == null) return 'Backend belum terkonfigurasi.';

    try {
      final updated = await repo.updateProfile(
        notificationsEnabled: enabled,
        reminderHour: reminderHour,
      );
      state = state.copyWith(profile: updated);
      if (enabled) {
        unawaited(_syncFcmTokenIfEnabled(updated));
      } else {
        unawaited(repo.updateFcmToken(null));
      }
      return null;
    } catch (e) {
      return ErrorMapper.toUserMessage(e);
    }
  }

  Future<void> _syncFcmTokenIfEnabled(UserProfile profile) async {
    if (!profile.notificationsEnabled || _repository == null) return;
    final token = await _notifications.requestPermissionAndGetToken();
    if (token != null) {
      await _repository.updateFcmToken(token);
    }
  }

  void recordUserActivity() {
    if (state.status == AuthStatus.authenticated) {
      unawaited(_inactivityGuard.recordActivity());
    }
  }

  Future<void> checkInactivityOnResume() async {
    if (state.status == AuthStatus.authenticated) {
      await _inactivityGuard.checkExpiredOnResume();
    }
  }

  void lockAppManually() {
    if (state.status == AuthStatus.authenticated && state.profile?.hasPin == true) {
      _pinVerifiedInSession = false;
      unawaited(_inactivityGuard.stop());
      state = state.copyWith(status: AuthStatus.pinLocked, clearError: true);
    }
  }

  Future<void> signOut({String? notice}) async {
    _pinVerifiedInSession = false;
    await _inactivityGuard.stop();
    try {
      await _repository?.signOut();
    } catch (_) {
      // Ensure local state always resets to unauthenticated
    }
    state = AuthControllerState(
      status: AuthStatus.unauthenticated,
      inactivityNotice: notice,
    );
  }

  Future<void> _handleInactivityTimeout() async {
    await signOut(
      notice:
          'Sesi berakhir otomatis demi keamanan karena tidak aktif selama 15 menit.',
    );
  }

  @override
  void dispose() {
    unawaited(_authSub?.cancel());
    _inactivityGuard.dispose();
    super.dispose();
  }
}

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthControllerState>((ref) {
  return AuthController(
    repository: ref.watch(authRepositoryProvider),
    storage: ref.watch(secureStorageProvider),
    notifications: ref.watch(notificationServiceProvider),
  );
});
