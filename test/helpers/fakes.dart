import 'dart:async';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:tabungan_pribadi/core/security/error_mapper.dart';
import 'package:tabungan_pribadi/core/security/secure_storage_service.dart';
import 'package:tabungan_pribadi/features/auth/data/auth_repository.dart';
import 'package:tabungan_pribadi/features/auth/domain/user_profile.dart';
import 'package:tabungan_pribadi/features/gamification/data/gamification_repository.dart';
import 'package:tabungan_pribadi/features/gamification/domain/gamification_models.dart';
import 'package:tabungan_pribadi/features/insights/domain/financial_summary.dart';
import 'package:tabungan_pribadi/features/transactions/data/transaction_repository.dart';
import 'package:tabungan_pribadi/features/transactions/domain/transaction_category.dart';
import 'package:tabungan_pribadi/features/transactions/domain/transaction_item.dart';

class InMemorySecureStorage implements SecureStorageService {
  final Map<String, String> store = {};

  @override
  Future<void> delete(String key) async => store.remove(key);

  @override
  Future<void> deleteAll() async => store.clear();

  @override
  Future<String?> read(String key) async => store[key];

  @override
  Future<void> write(String key, String value) async => store[key] = value;
}

class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository({
    UserProfile? initialProfile,
    bool signedIn = false,
    String? configuredPin,
  })  : _profile = initialProfile ??
            const UserProfile(
              id: 'user-test-1',
              email: 'nadia@example.com',
              fullName: 'Nadia Pratama',
              hasPin: false,
              savingsTarget: 0,
              savingsTargetTitle: 'Target Tabungan Utama',
              onboardingCompleted: false,
              notificationsEnabled: true,
              reminderHour: 20,
            ),
        _signedIn = signedIn,
        _pin = configuredPin;

  UserProfile _profile;
  bool _signedIn;
  String? _pin;
  int failedAttempts = 0;
  final StreamController<sb.AuthState> _controller =
      StreamController<sb.AuthState>.broadcast();

  UserProfile get currentProfile => _profile;

  @override
  bool get hasActiveSession => _signedIn;

  @override
  String? get currentUserId => _signedIn ? _profile.id : null;

  @override
  String? get currentUserEmail => _signedIn ? _profile.email : null;

  @override
  Stream<sb.AuthState> get onAuthStateChange => _controller.stream;

  @override
  Future<void> signInWithGoogle() async {
    _signedIn = true;
  }

  @override
  Future<UserProfile> fetchProfile() async {
    if (!_signedIn) {
      throw const AppException('UNAUTHENTICATED', 'Sesi tidak ditemukan.');
    }
    return _profile;
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
    _profile = _profile.copyWith(
      fullName: fullName,
      savingsTarget: savingsTarget,
      savingsTargetTitle: savingsTargetTitle,
      savingsTargetDeadline: savingsTargetDeadline,
      clearDeadline: clearDeadline,
      onboardingCompleted: onboardingCompleted,
      notificationsEnabled: notificationsEnabled,
      reminderHour: reminderHour,
    );
    return _profile;
  }

  @override
  Future<void> updateFcmToken(String? token) async {}

  @override
  Future<void> setOrChangePin({
    required String newPin,
    String? currentPin,
    bool isReset = false,
  }) async {
    if (!isReset && _pin != null && currentPin != _pin) {
      throw const AppException('INVALID_CURRENT_PIN', 'PIN saat ini tidak sesuai.');
    }
    _pin = newPin;
    _profile = _profile.copyWith(hasPin: true);
    failedAttempts = 0;
  }

  @override
  Future<void> verifyPin(String pin) async {
    if (_pin == null) {
      throw const AppException('PIN_NOT_CONFIGURED', 'PIN belum diatur.');
    }
    if (failedAttempts >= 5) {
      throw const AppException(
        'PIN_LOCKED',
        'Akses PIN terkunci sementara karena terlalu banyak percobaan salah.',
      );
    }
    if (pin != _pin) {
      failedAttempts++;
      throw const AppException('INVALID_PIN', 'PIN tidak sesuai.');
    }
    failedAttempts = 0;
  }

  String? lastSentOtp;

  @override
  Future<void> sendPasswordResetOtp(String email) async {
    lastSentOtp = '123456';
  }

  @override
  Future<void> verifyPasswordResetOtp({
    required String email,
    required String token,
  }) async {
    if (token != (lastSentOtp ?? '123456')) {
      throw const AppException('INVALID_OTP', 'Kode OTP salah atau telah kedaluwarsa.');
    }
  }

  @override
  Future<void> signOut() async {
    _signedIn = false;
  }

  void dispose() {
    unawaited(_controller.close());
  }
}

class FakeTransactionRepository implements TransactionRepository {
  FakeTransactionRepository({
    List<TransactionItem>? seed,
    this.simulateOffline = false,
  }) : items = List<TransactionItem>.from(seed ?? const []);

  final List<TransactionItem> items;
  bool simulateOffline;
  int createCallCount = 0;

  @override
  Future<List<TransactionItem>> fetchPage({
    required int page,
    required int pageSize,
    TransactionType? typeFilter,
  }) async {
    if (simulateOffline) {
      throw const SocketException('No internet connection');
    }
    final filtered = typeFilter == null
        ? items
        : items.where((e) => e.type == typeFilter).toList();
    final sorted = List<TransactionItem>.from(filtered)
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

    final start = page * pageSize;
    if (start >= sorted.length) return const [];
    final end = (start + pageSize).clamp(0, sorted.length);
    return sorted.sublist(start, end);
  }

  @override
  Future<TransactionItem> createTransaction({
    required String clientId,
    required TransactionType type,
    required double amount,
    required String category,
    String? note,
    required DateTime occurredAt,
  }) async {
    createCallCount++;
    if (simulateOffline) {
      throw const SocketException('No internet connection');
    }

    // Enforce server-like idempotency by clientId
    for (final existing in items) {
      if (existing.clientId == clientId) return existing;
    }

    final created = TransactionItem(
      id: 'srv-${items.length + 1}',
      userId: 'user-test-1',
      clientId: clientId,
      type: type,
      amount: amount,
      category: category,
      note: note,
      occurredAt: occurredAt,
      createdAt: occurredAt,
      syncStatus: SyncStatus.synced,
    );
    items.insert(0, created);
    return created;
  }

  @override
  Future<TransactionItem> updateTransaction({
    required String id,
    required TransactionType type,
    required double amount,
    required String category,
    String? note,
    required DateTime occurredAt,
  }) async {
    final idx = items.indexWhere((e) => e.id == id);
    if (idx < 0) {
      throw const AppException('NOT_FOUND', 'Transaksi tidak ditemukan.');
    }
    final updated = items[idx].copyWith(
      type: type,
      amount: amount,
      category: category,
      note: note,
      clearNote: note == null,
      occurredAt: occurredAt,
    );
    items[idx] = updated;
    return updated;
  }

  @override
  Future<void> deleteTransaction(String id) async {
    items.removeWhere((e) => e.id == id);
  }

  @override
  Future<FinancialSummary> fetchFinancialSummary({int months = 6}) async {
    if (simulateOffline) {
      throw const SocketException('No internet connection');
    }
    return FinancialSummary.fromTransactions(items, months: months);
  }
}

class FakeGamificationRepository implements GamificationRepository {
  FakeGamificationRepository({
    this.streak = UserStreak.empty,
    this.badges = const [],
  });

  UserStreak streak;
  List<UnlockedBadge> badges;

  @override
  Future<UserStreak> fetchStreak() async => streak;

  @override
  Future<List<UnlockedBadge>> fetchUnlockedBadges() async => badges;
}
