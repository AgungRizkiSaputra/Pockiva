import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Handles Firebase Cloud Messaging + local foreground notifications (PRD Section 22 & 28).
/// Degrades gracefully if Firebase native config is not yet attached in local dev builds.
class NotificationService {
  NotificationService();

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _firebaseAvailable = false;

  bool get isFirebaseAvailable => _firebaseAvailable;

  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      _firebaseAvailable = true;

      const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosInit = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      await _localNotifications.initialize(
        const InitializationSettings(android: androidInit, iOS: iosInit),
      );

      FirebaseMessaging.onMessage.listen(_showForegroundNotification);
    } catch (_) {
      // Firebase config files (google-services.json / GoogleService-Info.plist)
      // may be absent in CI or fresh local checkouts. App remains fully functional.
      _firebaseAvailable = false;
    }
  }

  Future<String?> requestPermissionAndGetToken() async {
    if (!_firebaseAvailable || kIsWeb) return null;

    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        return await messaging.getToken();
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    const androidDetails = AndroidNotificationDetails(
      'tabungan_reminders',
      'Pengingat Tabungan',
      channelDescription: 'Pengingat harian untuk menjaga streak tabungan',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _localNotifications.show(
      notification.hashCode,
      notification.title ?? 'Tabungan Pribadi',
      notification.body ?? '',
      details,
    );
  }
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});
