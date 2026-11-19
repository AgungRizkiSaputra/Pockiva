import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/security/error_mapper.dart';
import '../../auth/application/auth_controller.dart';
import '../data/gamification_repository.dart';
import '../domain/gamification_models.dart';

@immutable
class GamificationState {
  const GamificationState({
    this.streak = UserStreak.empty,
    this.unlockedBadges = const [],
    this.isLoading = false,
    this.errorMessage,
  });

  final UserStreak streak;
  final List<UnlockedBadge> unlockedBadges;
  final bool isLoading;
  final String? errorMessage;

  bool isBadgeUnlocked(String code) =>
      unlockedBadges.any((b) => b.badgeCode == code);

  DateTime? badgeUnlockedAt(String code) {
    for (final b in unlockedBadges) {
      if (b.badgeCode == code) return b.unlockedAt;
    }
    return null;
  }

  GamificationState copyWith({
    UserStreak? streak,
    List<UnlockedBadge>? unlockedBadges,
    bool? isLoading,
    String? errorMessage,
    bool clearError = false,
  }) {
    return GamificationState(
      streak: streak ?? this.streak,
      unlockedBadges: unlockedBadges ?? this.unlockedBadges,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class GamificationController extends StateNotifier<GamificationState> {
  GamificationController({
    required GamificationRepository? repository,
    required String? userId,
  })  : _repository = repository,
        _userId = userId,
        super(const GamificationState());

  final GamificationRepository? _repository;
  final String? _userId;

  Future<void> refresh() async {
    final repo = _repository;
    if (repo == null || _userId == null) return;

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final results = await Future.wait([
        repo.fetchStreak(),
        repo.fetchUnlockedBadges(),
      ]);

      state = GamificationState(
        streak: results[0] as UserStreak,
        unlockedBadges: results[1] as List<UnlockedBadge>,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: ErrorMapper.toUserMessage(e),
      );
    }
  }
}

final gamificationControllerProvider =
    StateNotifierProvider<GamificationController, GamificationState>((ref) {
  final authState = ref.watch(authControllerProvider);
  final userId = authState.status == AuthStatus.authenticated
      ? authState.profile?.id
      : null;

  final controller = GamificationController(
    repository: ref.watch(gamificationRepositoryProvider),
    userId: userId,
  );

  if (userId != null) {
    unawaited(controller.refresh());
  }

  return controller;
});
