import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:latlong2/latlong.dart';

class CommunityRoute {
  final String id;
  final String name;
  final String authorId;
  final String authorName;
  final List<LatLng> waypoints;
  final double distanceKm;
  final int durationMinutes;
  final String difficulty; // easy / medium / hard
  final int likes;
  final DateTime createdAt;

  const CommunityRoute({
    required this.id,
    required this.name,
    required this.authorId,
    required this.authorName,
    required this.waypoints,
    required this.distanceKm,
    required this.durationMinutes,
    required this.difficulty,
    this.likes = 0,
    required this.createdAt,
  });

  factory CommunityRoute.fromJson(Map<String, dynamic> j) {
    final pts = (j['waypoints'] as List<dynamic>? ?? [])
        .map((p) => LatLng((p['lat'] as num).toDouble(),
            (p['lng'] as num).toDouble()))
        .toList();
    return CommunityRoute(
      id: j['id'] as String,
      name: j['name'] as String,
      authorId: j['author_id'] as String? ?? '',
      authorName: j['author_name'] as String? ?? 'Anonymous',
      waypoints: pts,
      distanceKm: (j['distance_km'] as num? ?? 0).toDouble(),
      durationMinutes: (j['duration_minutes'] as num? ?? 0).toInt(),
      difficulty: j['difficulty'] as String? ?? 'medium',
      likes: (j['likes'] as num? ?? 0).toInt(),
      createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'author_id': authorId,
        'author_name': authorName,
        'waypoints':
            waypoints.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList(),
        'distance_km': distanceKm,
        'duration_minutes': durationMinutes,
        'difficulty': difficulty,
        'likes': likes,
        'created_at': createdAt.toIso8601String(),
      };

  /// Payload for DB INSERT — omits auto-generated fields (id, likes, created_at).
  Map<String, dynamic> toInsertJson() => {
        'name': name,
        'author_id': authorId.isEmpty ? null : authorId,
        'author_name': authorName,
        'waypoints':
            waypoints.map((p) => {'lat': p.latitude, 'lng': p.longitude}).toList(),
        'distance_km': distanceKm,
        'duration_minutes': durationMinutes,
        'difficulty': difficulty,
      };
}

class CommunityRouteNotifier
    extends StateNotifier<AsyncValue<List<CommunityRoute>>> {
  CommunityRouteNotifier() : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      final rows = await Supabase.instance.client
          .from('community_routes')
          .select()
          .order('likes', ascending: false);
      state = AsyncValue.data(
          (rows as List).map((r) => CommunityRoute.fromJson(r)).toList());
    } catch (_) {
      state = AsyncValue.data(_seedRoutes);
    }
  }

  Future<void> addRoute(CommunityRoute route) async {
    // Optimistic — add temp entry immediately
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data([route, ...current]);
    try {
      // Use toInsertJson to let Supabase generate the UUID + timestamps
      final inserted = await Supabase.instance.client
          .from('community_routes')
          .insert(route.toInsertJson())
          .select()
          .single();
      // Replace the optimistic entry with the real one from DB
      final real = CommunityRoute.fromJson(inserted);
      final updated = state.valueOrNull ?? [];
      state = AsyncValue.data([
        for (final r in updated)
          if (r.id == route.id) real else r,
      ]);
    } catch (_) {
      await load(); // revert on error
    }
  }

  Future<void> likeRoute(String id) async {
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data([
      for (final r in current)
        if (r.id == id)
          CommunityRoute(
            id: r.id,
            name: r.name,
            authorId: r.authorId,
            authorName: r.authorName,
            waypoints: r.waypoints,
            distanceKm: r.distanceKm,
            durationMinutes: r.durationMinutes,
            difficulty: r.difficulty,
            likes: r.likes + 1,
            createdAt: r.createdAt,
          )
        else
          r,
    ]);
    await Supabase.instance.client.rpc('increment_route_likes', params: {'rid': id});
  }
}

final communityRouteProvider = StateNotifierProvider<CommunityRouteNotifier,
    AsyncValue<List<CommunityRoute>>>((_) => CommunityRouteNotifier());

/// The route currently highlighted on the map (null = none).
final selectedRouteProvider = StateProvider<CommunityRoute?>((ref) => null);

// ─── Seed ─────────────────────────────────────────────────────────────────────
final _seedRoutes = [
  CommunityRoute(
    id: 'cr-001',
    name: 'Parcul Tei → Floreasca',
    authorId: 'user001',
    authorName: 'Andrei C.',
    waypoints: const [
      LatLng(44.4650, 26.1100),
      LatLng(44.4670, 26.1010),
      LatLng(44.4680, 26.0920),
    ],
    distanceKm: 3.2,
    durationMinutes: 14,
    difficulty: 'easy',
    likes: 24,
    createdAt: DateTime(2026, 3, 1),
  ),
  CommunityRoute(
    id: 'cr-002',
    name: 'Iancului → Obor Loop',
    authorId: 'user002',
    authorName: 'Maria T.',
    waypoints: const [
      LatLng(44.4390, 26.1200),
      LatLng(44.4480, 26.1180),
      LatLng(44.4530, 26.0980),
      LatLng(44.4390, 26.1200),
    ],
    distanceKm: 6.8,
    durationMinutes: 28,
    difficulty: 'medium',
    likes: 17,
    createdAt: DateTime(2026, 3, 5),
  ),
];
