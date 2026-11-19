import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/security/error_mapper.dart';
import '../../../core/security/secure_storage_service.dart';
import '../../auth/data/auth_repository.dart';
import '../domain/gamification_models.dart';

abstract class GamificationRepository {
  Future<UserStreak> fetchStreak();
  Future<List<UnlockedBadge>> fetchUnlockedBadges();
}

class SupabaseGamificationRepository implements GamificationRepository {
  SupabaseGamificationRepository(this._client, this._storage);

  final SupabaseClient _client;
  final SecureStorageService _storage;

  @override
  Future<UserStreak> fetchStreak() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return UserStreak.empty;

    try {
      final row = await _client
          .from('streaks')
          .select('current_streak, longest_streak, total_active_days, last_active')
          .eq('user_id', uid)
          .maybeSingle();

      final streak = row != null ? UserStreak.fromJson(row) : UserStreak.empty;
      await _storage.write(
        SecureStorageKeys.cachedStreakJson,
        jsonEncode(streak.toJson()),
      );
      return streak;
    } catch (e) {
      if (ErrorMapper.isNetworkError(e)) {
        final raw = await _storage.read(SecureStorageKeys.cachedStreakJson);
        if (raw != null) {
          return UserStreak.fromJson(jsonDecode(raw) as Map<String, dynamic>);
        }
      }
      throw AppException('STREAK_FETCH_FAILED', ErrorMapper.toUserMessage(e));
    }
  }

  @override
  Future<List<UnlockedBadge>> fetchUnlockedBadges() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return const [];

    try {
      final rows = await _client
          .from('user_badges')
          .select('badge_code, unlocked_at')
          .eq('user_id', uid)
          .order('unlocked_at', ascending: false);

      final badges = (rows as List<dynamic>)
          .whereType<Map<String, dynamic>>()
          .map(UnlockedBadge.fromJson)
          .toList();

      await _storage.write(
        SecureStorageKeys.cachedBadgesJson,
        jsonEncode(badges.map((b) => b.toJson()).toList()),
      );
      return badges;
    } catch (e) {
      if (ErrorMapper.isNetworkError(e)) {
        final raw = await _storage.read(SecureStorageKeys.cachedBadgesJson);
        if (raw != null) {
          final list = jsonDecode(raw) as List<dynamic>;
          return list
              .whereType<Map<String, dynamic>>()
              .map(UnlockedBadge.fromJson)
              .toList();
        }
      }
      throw AppException('BADGES_FETCH_FAILED', ErrorMapper.toUserMessage(e));
    }
  }
}

final gamificationRepositoryProvider = Provider<GamificationRepository?>((ref) {
  final client = ref.watch(supabaseClientProvider);
  if (client == null) return null;
  return SupabaseGamificationRepository(client, ref.watch(secureStorageProvider));
});
