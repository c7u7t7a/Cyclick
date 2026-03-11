import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/achievement_model.dart';
import '../models/ride_history_model.dart';
import 'history_provider.dart';
import 'friends_provider.dart';

// ─── State ────────────────────────────────────────────────────────────────────

class AchievementState {
  /// IDs of achievements that are already unlocked in the DB.
  final Set<String> unlockedIds;

  /// Unlocked achievements sorted newest-first.
  final List<UnlockedAchievement> unlocked;

  /// IDs newly unlocked in this session (for showing a congrats UI).
  final List<String> newlyUnlocked;

  final bool loading;

  const AchievementState({
    this.unlockedIds = const {},
    this.unlocked = const [],
    this.newlyUnlocked = const [],
    this.loading = true,
  });

  bool isUnlocked(String id) => unlockedIds.contains(id);

  AchievementState copyWith({
    Set<String>? unlockedIds,
    List<UnlockedAchievement>? unlocked,
    List<String>? newlyUnlocked,
    bool? loading,
  }) =>
      AchievementState(
        unlockedIds: unlockedIds ?? this.unlockedIds,
        unlocked: unlocked ?? this.unlocked,
        newlyUnlocked: newlyUnlocked ?? this.newlyUnlocked,
        loading: loading ?? this.loading,
      );
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class AchievementNotifier extends StateNotifier<AchievementState> {
  AchievementNotifier(this._ref) : super(const AchievementState()) {
    _load();
    // Re-check whenever ride history changes.
    _ref.listen<List<RideHistoryModel>>(historyProvider, (_, rides) {
      _checkFromHistory(rides);
    });
    // Re-check when friends change (for first_friend achievement).
    _ref.listen<FriendsState>(friendsProvider, (_, fs) {
      final rides = _ref.read(historyProvider);
      _checkFromHistory(rides, friendCount: fs.totalFriends);
    });
  }

  final Ref _ref;
  SupabaseClient get _db => Supabase.instance.client;
  String? get _uid => _db.auth.currentUser?.id;

  // ── Load from Supabase ─────────────────────────────────────────────────────

  Future<void> _load() async {
    if (_uid == null) {
      state = state.copyWith(loading: false);
      return;
    }
    try {
      final rows = await _db
          .from('user_achievements')
          .select('achievement_id, unlocked_at')
          .eq('user_id', _uid!);

      final ids = <String>{};
      final list = <UnlockedAchievement>[];
      for (final r in rows as List) {
        final id = r['achievement_id'] as String;
        ids.add(id);
        list.add(UnlockedAchievement(
          achievementId: id,
          unlockedAt: DateTime.parse(r['unlocked_at'] as String),
        ));
      }
      list.sort((a, b) => b.unlockedAt.compareTo(a.unlockedAt));
      state = state.copyWith(
          unlockedIds: ids, unlocked: list, newlyUnlocked: [], loading: false);
    } catch (_) {
      state = state.copyWith(loading: false);
    }
  }

  // ── Check conditions ────────────────────────────────────────────────────────

  Future<void> _checkFromHistory(
    List<RideHistoryModel> rides, {
    int? friendCount,
  }) async {
    if (_uid == null) return;

    final stats = RideStats(
      rides: rides.length,
      totalKm: rides.fold(0.0, (s, r) => s + r.distanceKm),
      totalCo2Grams: rides.fold(0.0, (s, r) => s + r.co2SavedGrams),
      highRatedRides:
          rides.where((r) => (r.safetyRating ?? 0) >= 4).length,
      cityHallReports: rides
          .where((r) =>
              r.cityHallMessage != null &&
              r.cityHallMessage!.trim().isNotEmpty)
          .length,
      friendCount:
          friendCount ?? _ref.read(friendsProvider).totalFriends,
    );

    await checkAndUnlock(stats);
  }

  /// Unlocks any achievements that [stats] now satisfy but were not yet in DB.
  /// Call this externally too (e.g. after community group join).
  Future<void> checkAndUnlock(RideStats stats) async {
    if (_uid == null || state.loading) return;

    final current = state.unlockedIds;
    final toUnlock =
        kAllAchievements.where((d) => !current.contains(d.id) && d.check(stats)).map((d) => d.id).toList();

    if (toUnlock.isEmpty) return;

    final nowIso = DateTime.now().toUtc().toIso8601String();
    try {
      await _db.from('user_achievements').upsert(
            toUnlock
                .map((id) => {
                      'user_id': _uid,
                      'achievement_id': id,
                      'unlocked_at': nowIso,
                    })
                .toList(),
            onConflict: 'user_id,achievement_id',
          );
    } catch (_) {
      // Persist failed; still update local state so UI reflects it.
    }

    final newIds = {...current, ...toUnlock};
    final now = DateTime.now();
    final newEntries = toUnlock
        .map((id) => UnlockedAchievement(achievementId: id, unlockedAt: now))
        .toList();
    state = state.copyWith(
      unlockedIds: newIds,
      unlocked: [...newEntries, ...state.unlocked],
      newlyUnlocked: toUnlock,
    );
  }

  /// Clear the newly-unlocked list after the UI has shown the congrats.
  void clearNewlyUnlocked() {
    if (state.newlyUnlocked.isNotEmpty) {
      state = state.copyWith(newlyUnlocked: []);
    }
  }

  Future<void> reload() => _load();
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final achievementProvider =
    StateNotifierProvider<AchievementNotifier, AchievementState>(
  (ref) => AchievementNotifier(ref),
);
