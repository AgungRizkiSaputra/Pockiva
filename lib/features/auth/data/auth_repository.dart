import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/config/app_config.dart';
import '../../../core/security/error_mapper.dart';
import '../../../core/security/secure_storage_service.dart';
import '../domain/user_profile.dart';

abstract class AuthRepository {
  bool get hasActiveSession;
  String? get currentUserId;
  String? get currentUserEmail;
  Stream<AuthState> get onAuthStateChange;

  Future<void> signInWithGoogle();
  Future<UserProfile> fetchProfile();
  Future<UserProfile> updateProfile({
    String? fullName,
    double? savingsTarget,
    String? savingsTargetTitle,
    DateTime? savingsTargetDeadline,
    bool clearDeadline = false,
    bool? onboardingCompleted,
    bool? notificationsEnabled,
    int? reminderHour,
  });
  Future<void> updateFcmToken(String? token);
  Future<void> setOrChangePin({
    required String newPin,
    String? currentPin,
    bool isReset = false,
  });
  Future<void> verifyPin(String pin);
  Future<void> sendPasswordResetOtp(String email);
  Future<void> verifyPasswordResetOtp({
    required String email,
    required String token,
  });
  Future<void> signOut();
}

class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client, this._storage);

  final SupabaseClient _client;
  final SecureStorageService _storage;

  @override
  bool get hasActiveSession => _client.auth.currentSession != null;

  @override
  String? get currentUserId => _client.auth.currentUser?.id;

  @override
  String? get currentUserEmail => _client.auth.currentUser?.email;

  @override
  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  @override
  Future<void> signInWithGoogle() async {
    try {
      // Native Google Sign-In on Android/iOS when Web Client ID is provided
      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS) &&
          AppConfig.googleWebClientId.isNotEmpty) {
        final googleSignIn = GoogleSignIn(
          serverClientId: AppConfig.googleWebClientId,
          clientId: defaultTargetPlatform == TargetPlatform.iOS &&
                  AppConfig.googleIosClientId.isNotEmpty
              ? AppConfig.googleIosClientId
              : null,
          scopes: const ['email', 'profile'],
        );

        final googleUser = await googleSignIn.signIn();
        if (googleUser == null) {
          throw const AppException('AUTH_CANCELLED', 'Proses masuk Google dibatalkan.');
        }

        final googleAuth = await googleUser.authentication;
        final idToken = googleAuth.idToken;
        final accessToken = googleAuth.accessToken;
        if (idToken == null) {
          throw const AppException(
            'MISSING_ID_TOKEN',
            'Token autentikasi Google tidak ditemukan. Periksa konfigurasi OAuth.',
          );
        }

        await _client.auth.signInWithIdToken(
          provider: OAuthProvider.google,
          idToken: idToken,
          accessToken: accessToken,
        );
        return;
      }

      // PKCE OAuth browser flow for Web / Desktop or fallback
      await _client.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: kIsWeb ? Uri.base.origin : AppConfig.supabaseRedirectUrl,
        authScreenLaunchMode: kIsWeb
            ? LaunchMode.platformDefault
            : LaunchMode.externalApplication,
      );
    } on AppException {
      rethrow;
    } catch (e) {
      throw AppException('GOOGLE_SIGN_IN_FAILED', ErrorMapper.toUserMessage(e));
    }
  }

  @override
  Future<UserProfile> fetchProfile() async {
    final uid = currentUserId;
    if (uid == null) {
      throw const AppException('UNAUTHENTICATED', 'Sesi tidak ditemukan.');
    }

    try {
      // Explicit column projection excludes server-only pin_hash & lockout columns
      Map<String, dynamic>? data = await _client
          .from('profiles')
          .select(
            'id, email, full_name, avatar_url, pin_set_at, savings_target, '
            'savings_target_title, savings_target_deadline, onboarding_completed, '
            'notifications_enabled, reminder_hour',
          )
          .eq('id', uid)
          .maybeSingle();

      // Retry briefly once in case the auth trigger just finished provisioning
      if (data == null) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        data = await _client
            .from('profiles')
            .select(
              'id, email, full_name, avatar_url, pin_set_at, savings_target, '
              'savings_target_title, savings_target_deadline, onboarding_completed, '
              'notifications_enabled, reminder_hour',
            )
            .eq('id', uid)
            .maybeSingle();
      }

      if (data == null) {
        throw const AppException(
          'PROFILE_NOT_FOUND',
          'Profil belum terbentuk di database. Pastikan migrasi 002 (trigger on_auth_user_created) sudah dijalankan.',
        );
      }

      final profile = UserProfile.fromJson(data);
      try {
        await _storage.write(
          SecureStorageKeys.cachedProfileJson,
          jsonEncode(profile.toJson()),
        );
      } catch (_) {
        // Non-blocking local cache write
      }
      return profile;
    } catch (e) {
      if (ErrorMapper.isNetworkError(e)) {
        final cached = await _storage.read(SecureStorageKeys.cachedProfileJson);
        if (cached != null) {
          return UserProfile.fromJson(jsonDecode(cached) as Map<String, dynamic>);
        }
      }
      throw AppException('PROFILE_FETCH_FAILED', ErrorMapper.toUserMessage(e));
    }
  }

  @override
  Future<UserProfile> updateProfile({
    String? fullName,
    double? savingsTarget,
    String? savingsTargetTitle,
    DateTime? savingsTargetDeadline,
    bool clearDeadline = false,
    bool? onboardingCompleted,
    bool? notificationsEnabled,
    int? reminderHour,
  }) async {
    final uid = currentUserId;
    if (uid == null) {
      throw const AppException('UNAUTHENTICATED', 'Sesi tidak ditemukan.');
    }

    final payload = <String, dynamic>{};
    if (fullName != null) payload['full_name'] = fullName;
    if (savingsTarget != null) payload['savings_target'] = savingsTarget;
    if (savingsTargetTitle != null) {
      payload['savings_target_title'] = savingsTargetTitle;
    }
    if (clearDeadline) {
      payload['savings_target_deadline'] = null;
    } else if (savingsTargetDeadline != null) {
      payload['savings_target_deadline'] =
          savingsTargetDeadline.toIso8601String().split('T').first;
    }
    if (onboardingCompleted != null) {
      payload['onboarding_completed'] = onboardingCompleted;
    }
    if (notificationsEnabled != null) {
      payload['notifications_enabled'] = notificationsEnabled;
    }
    if (reminderHour != null) payload['reminder_hour'] = reminderHour;

    try {
      final data = await _client
          .from('profiles')
          .update(payload)
          .eq('id', uid)
          .select(
            'id, email, full_name, avatar_url, pin_set_at, savings_target, '
            'savings_target_title, savings_target_deadline, onboarding_completed, '
            'notifications_enabled, reminder_hour',
          )
          .single();

      final profile = UserProfile.fromJson(data);
      await _storage.write(
        SecureStorageKeys.cachedProfileJson,
        jsonEncode(profile.toJson()),
      );
      return profile;
    } catch (e) {
      throw AppException('PROFILE_UPDATE_FAILED', ErrorMapper.toUserMessage(e));
    }
  }

  @override
  Future<void> updateFcmToken(String? token) async {
    final uid = currentUserId;
    if (uid == null) return;
    try {
      await _client.from('profiles').update({'fcm_token': token}).eq('id', uid);
    } catch (_) {
      // Non-blocking best-effort token sync
    }
  }

  @override
  Future<void> setOrChangePin({
    required String newPin,
    String? currentPin,
    bool isReset = false,
  }) async {
    try {
      final body = <String, dynamic>{'new_pin': newPin};
      if (currentPin != null) {
        body['current_pin'] = currentPin;
      }
      if (isReset) {
        body['reset'] = true;
      }

      final response = await _client.functions.invoke('pin-manage', body: body);
      if (response.status >= 400) {
        final data = response.data;
        final message = (data is Map && data['message'] is String)
            ? data['message'] as String
            : 'Gagal menyimpan PIN.';
        final code = (data is Map && data['error'] is String)
            ? data['error'] as String
            : 'PIN_MANAGE_FAILED';
        throw AppException(code, message);
      }
    } on AppException {
      rethrow;
    } catch (e) {
      throw AppException('PIN_MANAGE_FAILED', ErrorMapper.toUserMessage(e));
    }
  }

  @override
  Future<void> verifyPin(String pin) async {
    try {
      final response = await _client.functions.invoke(
        'pin-verify',
        body: {'pin': pin},
      );
      if (response.status >= 400) {
        final data = response.data;
        final message = (data is Map && data['message'] is String)
            ? data['message'] as String
            : 'PIN tidak sesuai.';
        final code = (data is Map && data['error'] is String)
            ? data['error'] as String
            : 'INVALID_PIN';
        throw AppException(code, message);
      }
    } on AppException {
      rethrow;
    } catch (e) {
      throw AppException('PIN_VERIFY_FAILED', ErrorMapper.toUserMessage(e));
    }
  }

  @override
  Future<void> sendPasswordResetOtp(String email) async {
    try {
      await _client.auth.signInWithOtp(
        email: email.trim(),
        shouldCreateUser: false,
      );
    } catch (e) {
      final msg = e.toString().toLowerCase();
      if (msg.contains('rate limit') || msg.contains('over_email_send_rate_limit')) {
        throw const AppException(
          'RATE_LIMIT',
          'Terlalu sering meminta OTP. Silakan tunggu beberapa saat lagi sebelum mencoba kembali.',
        );
      }
      throw AppException(
        'OTP_SEND_FAILED',
        ErrorMapper.toUserMessage(e),
      );
    }
  }

  @override
  Future<void> verifyPasswordResetOtp({
    required String email,
    required String token,
  }) async {
    try {
      final res = await _client.auth.verifyOTP(
        email: email.trim(),
        token: token.trim(),
        type: OtpType.email,
      );
      if (res.session == null && _client.auth.currentSession == null) {
        throw const AppException(
          'INVALID_OTP',
          'Kode OTP tidak valid atau sudah kedaluwarsa.',
        );
      }
    } catch (e) {
      if (e is AppException) rethrow;
      final msg = e.toString().toLowerCase();
      if (msg.contains('expired') || msg.contains('invalid') || msg.contains('otp_expired')) {
        throw const AppException(
          'INVALID_OTP',
          'Kode OTP salah atau telah kedaluwarsa. Silakan periksa email Anda kembali.',
        );
      }
      throw AppException(
        'OTP_VERIFY_FAILED',
        ErrorMapper.toUserMessage(e),
      );
    }
  }

  @override
  Future<void> signOut() async {
    try {
      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.android ||
              defaultTargetPlatform == TargetPlatform.iOS)) {
        final googleSignIn = GoogleSignIn();
        if (await googleSignIn.isSignedIn()) {
          await googleSignIn.signOut();
        }
      }
    } catch (_) {
      // Proceed with Supabase session sign-out regardless
    }
    await _client.auth.signOut();
    await _storage.deleteAll();
  }
}

final supabaseClientProvider = Provider<SupabaseClient?>((ref) {
  if (!AppConfig.isSupabaseConfigured) return null;
  try {
    return Supabase.instance.client;
  } catch (_) {
    return null;
  }
});

final authRepositoryProvider = Provider<AuthRepository?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return null;
  return SupabaseAuthRepository(client, ref.watch(secureStorageProvider));
});
