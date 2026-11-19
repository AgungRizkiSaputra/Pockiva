import 'dart:async';
import '../config/app_config.dart';
import 'secure_storage_service.dart';

/// Enforces automatic logout after 15 minutes of user inactivity (PRD Section 10).
/// Persists last activity timestamp in secure storage so backgrounding the app
/// cannot bypass the timeout.
class InactivitySessionGuard {
  InactivitySessionGuard({
    required SecureStorageService storage,
    required Future<void> Function() onTimeout,
    Duration timeout = AppConfig.inactivityTimeout,
    DateTime Function()? clock,
  })  : _storage = storage,
        _onTimeout = onTimeout,
        _timeout = timeout,
        _clock = clock ?? DateTime.now;

  final SecureStorageService _storage;
  final Future<void> Function() _onTimeout;
  final Duration _timeout;
  final DateTime Function() _clock;

  Timer? _timer;
  bool _active = false;
  DateTime? _lastWrite;

  bool get isActive => _active;

  Future<void> start() async {
    _active = true;
    await recordActivity(forcePersist: true);
  }

  Future<void> stop() async {
    _active = false;
    _timer?.cancel();
    _timer = null;
    try {
      await _storage.delete(SecureStorageKeys.lastActivityEpochMs);
    } catch (_) {
      // Ignore storage cleanup errors on restricted web contexts
    }
  }

  Future<void> recordActivity({bool forcePersist = false}) async {
    if (!_active) return;

    final now = _clock();
    _timer?.cancel();
    _timer = Timer(_timeout, () async {
      if (!_active) return;
      await _triggerTimeout();
    });

    // Throttle secure storage writes to at most once every 10 seconds during rapid taps
    if (forcePersist ||
        _lastWrite == null ||
        now.difference(_lastWrite!) >= const Duration(seconds: 10)) {
      _lastWrite = now;
      try {
        await _storage.write(
          SecureStorageKeys.lastActivityEpochMs,
          now.millisecondsSinceEpoch.toString(),
        );
      } catch (_) {
        // In-memory timer still enforces the 15-minute inactivity timeout
      }
    }
  }

  /// Checks elapsed time when app resumes from background.
  Future<bool> checkExpiredOnResume() async {
    if (!_active) return false;
    final stored = await _storage.read(SecureStorageKeys.lastActivityEpochMs);
    if (stored == null) return false;

    final lastMs = int.tryParse(stored);
    if (lastMs == null) return false;

    final elapsed = _clock().millisecondsSinceEpoch - lastMs;
    if (elapsed >= _timeout.inMilliseconds) {
      await _triggerTimeout();
      return true;
    }

    final remaining = Duration(milliseconds: _timeout.inMilliseconds - elapsed);
    _timer?.cancel();
    _timer = Timer(remaining, () async {
      if (!_active) return;
      await _triggerTimeout();
    });
    return false;
  }

  Future<void> _triggerTimeout() async {
    _active = false;
    _timer?.cancel();
    _timer = null;
    await _storage.delete(SecureStorageKeys.lastActivityEpochMs);
    await _onTimeout();
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _active = false;
  }
}
