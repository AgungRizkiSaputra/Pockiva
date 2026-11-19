import 'package:flutter/material.dart';

@immutable
class UserStreak {
  const UserStreak({
    required this.currentStreak,
    required this.longestStreak,
    required this.totalActiveDays,
    this.lastActive,
  });

  final int currentStreak;
  final int longestStreak;
  final int totalActiveDays;
  final DateTime? lastActive;

  static const UserStreak empty = UserStreak(
    currentStreak: 0,
    longestStreak: 0,
    totalActiveDays: 0,
  );

  bool isActiveToday({DateTime? now}) {
    if (lastActive == null) return false;
    final ref = now ?? DateTime.now();
    return lastActive!.year == ref.year &&
        lastActive!.month == ref.month &&
        lastActive!.day == ref.day;
  }

  /// Effective streak accounts for missed days so the UI never displays a stale streak.
  int effectiveStreak({DateTime? now}) {
    if (lastActive == null || currentStreak == 0) return 0;
    final ref = now ?? DateTime.now();
    final today = DateTime(ref.year, ref.month, ref.day);
    final last = DateTime(lastActive!.year, lastActive!.month, lastActive!.day);
    final gap = today.difference(last).inDays;
    return gap <= 1 ? currentStreak : 0;
  }

  factory UserStreak.fromJson(Map<String, dynamic> json) {
    return UserStreak(
      currentStreak: (json['current_streak'] as num?)?.toInt() ?? 0,
      longestStreak: (json['longest_streak'] as num?)?.toInt() ?? 0,
      totalActiveDays: (json['total_active_days'] as num?)?.toInt() ?? 0,
      lastActive: json['last_active'] != null
          ? DateTime.tryParse(json['last_active'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'current_streak': currentStreak,
      'longest_streak': longestStreak,
      'total_active_days': totalActiveDays,
      'last_active': lastActive?.toIso8601String().split('T').first,
    };
  }
}

@immutable
class UnlockedBadge {
  const UnlockedBadge({
    required this.badgeCode,
    required this.unlockedAt,
  });

  final String badgeCode;
  final DateTime unlockedAt;

  factory UnlockedBadge.fromJson(Map<String, dynamic> json) {
    return UnlockedBadge(
      badgeCode: json['badge_code'] as String,
      unlockedAt: DateTime.parse(json['unlocked_at'].toString()).toLocal(),
    );
  }

  Map<String, dynamic> toJson() => {
        'badge_code': badgeCode,
        'unlocked_at': unlockedAt.toUtc().toIso8601String(),
      };
}

@immutable
class BadgeDefinition {
  const BadgeDefinition({
    required this.code,
    required this.title,
    required this.description,
    required this.icon,
  });

  final String code;
  final String title;
  final String description;
  final IconData icon;

  static const List<BadgeDefinition> catalog = [
    BadgeDefinition(
      code: 'first_save',
      title: 'Langkah Pertama',
      description: 'Mencatat setoran tabungan pertamamu.',
      icon: Icons.savings_outlined,
    ),
    BadgeDefinition(
      code: 'streak_3',
      title: 'Konsisten 3 Hari',
      description: 'Aktif mencatat keuangan 3 hari berturut-turut.',
      icon: Icons.local_fire_department_outlined,
    ),
    BadgeDefinition(
      code: 'streak_7',
      title: 'Pekan Disiplin',
      description: 'Menjaga streak harian selama 7 hari penuh.',
      icon: Icons.event_available_outlined,
    ),
    BadgeDefinition(
      code: 'consistent_10',
      title: 'Pencatat Andal',
      description: 'Mencatat minimal 10 transaksi keuangan.',
      icon: Icons.fact_check_outlined,
    ),
    BadgeDefinition(
      code: 'saver_1m',
      title: 'Sejuta Pertama',
      description: 'Mengumpulkan total tabungan minimal Rp 1.000.000.',
      icon: Icons.account_balance_wallet_outlined,
    ),
    BadgeDefinition(
      code: 'target_50',
      title: 'Setengah Jalan',
      description: 'Mencapai 50% dari target tabungan utamamu.',
      icon: Icons.flag_outlined,
    ),
    BadgeDefinition(
      code: 'target_100',
      title: 'Target Tercapai',
      description: 'Berhasil memenuhi 100% target tabungan utamamu.',
      icon: Icons.emoji_events_outlined,
    ),
    BadgeDefinition(
      code: 'streak_30',
      title: 'Master 30 Hari',
      description: 'Menjaga kebiasaan finansial selama 30 hari berturut-turut.',
      icon: Icons.workspace_premium_outlined,
    ),
  ];
}
