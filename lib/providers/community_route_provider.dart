import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:latlong2/latlong.dart';
import '../services/notification_service.dart';

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
  final int downvotes;
  /// Current user's vote: 1=upvoted, -1=downvoted, 0=none
  final int userVote;
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
    this.downvotes = 0,
    this.userVote = 0,
    required this.createdAt,
  });

  int get score => likes - downvotes;

  CommunityRoute copyWith({int? likes, int? downvotes, int? userVote}) =>
      CommunityRoute(
        id: id,
        name: name,
        authorId: authorId,
        authorName: authorName,
        waypoints: waypoints,
        distanceKm: distanceKm,
        durationMinutes: durationMinutes,
        difficulty: difficulty,
        likes: likes ?? this.likes,
        downvotes: downvotes ?? this.downvotes,
        userVote: userVote ?? this.userVote,
        createdAt: createdAt,
      );

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
      downvotes: (j['downvotes'] as num? ?? 0).toInt(),
      userVote: (j['user_vote'] as num? ?? 0).toInt(),
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
        'downvotes': downvotes,
        'created_at': createdAt.toIso8601String(),
      };

  /// Payload for DB INSERT — omits auto-generated fields.
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
      final client = Supabase.instance.client;
      final rows = await client
          .from('community_routes')
          .select()
          .order('likes', ascending: false);

      // Fetch current user's votes in one query
      final userId = client.auth.currentUser?.id;
      final Map<String, int> myVotes = {};
      if (userId != null) {
        final votes = await client
            .from('route_votes')
            .select('route_id, vote')
            .eq('user_id', userId);
        for (final v in votes as List) {
          myVotes[v['route_id'] as String] = (v['vote'] as num).toInt();
        }
      }

      state = AsyncValue.data(
        (rows as List).map((r) {
          final m = Map<String, dynamic>.from(r);
          m['user_vote'] = myVotes[r['id'] as String] ?? 0;
          return CommunityRoute.fromJson(m);
        }).toList(),
      );
    } catch (_) {
      state = AsyncValue.data(_seedRoutes);
    }
  }

  Future<void> addRoute(CommunityRoute route) async {
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data([route, ...current]);
    // Notify other cyclists about the new route
    NotificationService().showNewRoute(route.name, route.authorName).ignore();
    try {
      final inserted = await Supabase.instance.client
          .from('community_routes')
          .insert(route.toInsertJson())
          .select()
          .single();
      final real = CommunityRoute.fromJson(inserted);
      final updated = state.valueOrNull ?? [];
      state = AsyncValue.data([
        for (final r in updated)
          if (r.id == route.id) real else r,
      ]);
    } catch (_) {
      await load();
    }
  }

  /// Cast a vote: 1 = upvote, -1 = downvote.
  /// Calling the same vote again acts as a toggle (removes the vote).
  Future<void> vote(String id, int v) async {
    final current = state.valueOrNull ?? [];
    final route = current.firstWhere((r) => r.id == id);
    final newVote = route.userVote == v ? 0 : v; // toggle off if same

    // Optimistic update
    state = AsyncValue.data([
      for (final r in current)
        if (r.id == id)
          r.copyWith(
            userVote: newVote,
            likes: r.likes +
                (newVote == 1 ? 1 : 0) -
                (r.userVote == 1 ? 1 : 0),
            downvotes: r.downvotes +
                (newVote == -1 ? 1 : 0) -
                (r.userVote == -1 ? 1 : 0),
          )
        else
          r,
    ]);

    try {
      if (newVote == 0) {
        // Remove vote
        await Supabase.instance.client
            .from('route_votes')
            .delete()
            .eq('route_id', id)
            .eq('user_id', Supabase.instance.client.auth.currentUser!.id);
        // Recalculate counts
        await Supabase.instance.client.rpc('cast_route_vote',
            params: {'rid': id, 'v': v}); // will revert in DB
      } else {
        await Supabase.instance.client
            .rpc('cast_route_vote', params: {'rid': id, 'v': newVote});
      }
    } catch (_) {
      await load(); // revert on error
    }
  }

  // Keep backwards compat alias
  Future<void> likeRoute(String id) => vote(id, 1);
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
