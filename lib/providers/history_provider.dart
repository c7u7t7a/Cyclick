import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ride_history_model.dart';

/// Manages the user's ride history — loads from Supabase and persists new rides.
class HistoryNotifier extends StateNotifier<List<RideHistoryModel>> {
  HistoryNotifier() : super(_seedHistory) {
    _loadFromSupabase();
  }

  SupabaseClient get _db => Supabase.instance.client;

  Future<void> _loadFromSupabase() async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) return; // not signed in yet; seed data stays

    try {
      final rows = await _db
          .from('ride_history')
          .select()
          .eq('user_id', userId)
          .order('started_at', ascending: false);

      if (rows.isNotEmpty) {
        state = rows.map((r) => RideHistoryModel.fromJson(r)).toList();
      }
    } catch (_) {
      // Network error — keep showing seed / previously loaded data.
    }
  }

  /// Adds a completed ride to Supabase and to the local list.
  Future<void> addRide(RideHistoryModel ride) async {
    // Optimistically prepend to the UI.
    state = [ride, ...state];

    try {
      await _db.from('ride_history').insert(ride.toJson());
    } catch (_) {
      // Row failed to save — UI already shows it, we silently swallow.
      // In production you'd queue this for retry.
    }
  }

  void updateRide(RideHistoryModel updated) {
    state = [
      for (final r in state)
        if (r.id == updated.id) updated else r,
    ];
  }
}

final historyProvider =
    StateNotifierProvider<HistoryNotifier, List<RideHistoryModel>>(
  (_) => HistoryNotifier(),
);

// ─── Seed data ────────────────────────────────────────────────────────────────
final List<RideHistoryModel> _seedHistory = [
  RideHistoryModel(
    id: 'ride-001',
    userId: 'mock-uid-001',
    startedAt: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
    finishedAt:
        DateTime.now().subtract(const Duration(days: 1, hours: 1, minutes: 15)),
    distanceKm: 8.3,
    duration: const Duration(minutes: 45),
    co2SavedGrams: 996.0,
    safetyRating: 4.0,
    feedbackTags: [FeedbackTag.smoothSurface, FeedbackTag.wellLit],
  ),
  RideHistoryModel(
    id: 'ride-002',
    userId: 'mock-uid-001',
    startedAt: DateTime.now().subtract(const Duration(days: 3, hours: 7)),
    finishedAt:
        DateTime.now().subtract(const Duration(days: 3, hours: 6, minutes: 30)),
    distanceKm: 5.7,
    duration: const Duration(minutes: 30),
    co2SavedGrams: 684.0,
    safetyRating: 3.0,
    feedbackTags: [FeedbackTag.heavyTraffic, FeedbackTag.dangerousIntersection],
    cityHallMessage:
        'The intersection at Bd. Colentina needs better cycling signals.',
  ),
  RideHistoryModel(
    id: 'ride-003',
    userId: 'mock-uid-001',
    startedAt: DateTime.now().subtract(const Duration(days: 5, hours: 17)),
    finishedAt:
        DateTime.now().subtract(const Duration(days: 5, hours: 15, minutes: 55)),
    distanceKm: 12.1,
    duration: const Duration(hours: 1, minutes: 5),
    co2SavedGrams: 1452.0,
    safetyRating: 5.0,
    feedbackTags: [FeedbackTag.smoothSurface, FeedbackTag.wellLit],
  ),
];
