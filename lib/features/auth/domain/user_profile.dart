import 'package:flutter/foundation.dart';

@immutable
class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.fullName,
    this.avatarUrl,
    required this.hasPin,
    required this.savingsTarget,
    required this.savingsTargetTitle,
    this.savingsTargetDeadline,
    required this.onboardingCompleted,
    required this.notificationsEnabled,
    required this.reminderHour,
  });

  final String id;
  final String email;
  final String fullName;
  final String? avatarUrl;
  final bool hasPin;
  final double savingsTarget;
  final String savingsTargetTitle;
  final DateTime? savingsTargetDeadline;
  final bool onboardingCompleted;
  final bool notificationsEnabled;
  final int reminderHour;

  String get firstName {
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) {
      final beforeAt = email.split('@').first;
      return beforeAt.isEmpty ? 'Kamu' : beforeAt;
    }
    return trimmed.split(RegExp(r'\s+')).first;
  }

  String get initials {
    final parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return email.isNotEmpty ? email[0].toUpperCase() : 'U';
    }
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      email: (json['email'] as String?) ?? '',
      fullName: (json['full_name'] as String?) ?? '',
      avatarUrl: json['avatar_url'] as String?,
      hasPin: json['pin_set_at'] != null || json['has_pin'] == true,
      savingsTarget: _toDouble(json['savings_target']),
      savingsTargetTitle:
          (json['savings_target_title'] as String?) ?? 'Target Tabungan Utama',
      savingsTargetDeadline: json['savings_target_deadline'] != null
          ? DateTime.tryParse(json['savings_target_deadline'].toString())
          : null,
      onboardingCompleted: json['onboarding_completed'] == true,
      notificationsEnabled: json['notifications_enabled'] != false,
      reminderHour: (json['reminder_hour'] as num?)?.toInt() ?? 20,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'has_pin': hasPin,
      'savings_target': savingsTarget,
      'savings_target_title': savingsTargetTitle,
      'savings_target_deadline':
          savingsTargetDeadline?.toIso8601String().split('T').first,
      'onboarding_completed': onboardingCompleted,
      'notifications_enabled': notificationsEnabled,
      'reminder_hour': reminderHour,
    };
  }

  UserProfile copyWith({
    String? fullName,
    String? avatarUrl,
    bool? hasPin,
    double? savingsTarget,
    String? savingsTargetTitle,
    DateTime? savingsTargetDeadline,
    bool clearDeadline = false,
    bool? onboardingCompleted,
    bool? notificationsEnabled,
    int? reminderHour,
  }) {
    return UserProfile(
      id: id,
      email: email,
      fullName: fullName ?? this.fullName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      hasPin: hasPin ?? this.hasPin,
      savingsTarget: savingsTarget ?? this.savingsTarget,
      savingsTargetTitle: savingsTargetTitle ?? this.savingsTargetTitle,
      savingsTargetDeadline: clearDeadline
          ? null
          : (savingsTargetDeadline ?? this.savingsTargetDeadline),
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      reminderHour: reminderHour ?? this.reminderHour,
    );
  }

  static double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }
}
