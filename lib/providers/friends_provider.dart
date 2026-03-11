import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/friend_model.dart';

// ─── State ────────────────────────────────────────────────────────────────────

class FriendsState {
  final List<FriendModel> friends;          // accepted
  final List<FriendModel> pendingSent;      // I sent, waiting
  final List<FriendModel> pendingReceived;  // they sent, I decide
  final bool loading;

  const FriendsState({
    this.friends = const [],
    this.pendingSent = const [],
    this.pendingReceived = const [],
    this.loading = true,
  });

  int get totalFriends => friends.length;

  FriendsState copyWith({
    List<FriendModel>? friends,
    List<FriendModel>? pendingSent,
    List<FriendModel>? pendingReceived,
    bool? loading,
  }) =>
      FriendsState(
        friends: friends ?? this.friends,
        pendingSent: pendingSent ?? this.pendingSent,
        pendingReceived: pendingReceived ?? this.pendingReceived,
        loading: loading ?? this.loading,
      );
}

// ─── Notifier ─────────────────────────────────────────────────────────────────

class FriendsNotifier extends StateNotifier<FriendsState> {
  FriendsNotifier() : super(const FriendsState()) {
    load();
  }

  SupabaseClient get _db => Supabase.instance.client;
  String? get _uid => _db.auth.currentUser?.id;

  // ── Load ───────────────────────────────────────────────────────────────────

  Future<void> load() async {
    if (_uid == null) {
      state = state.copyWith(loading: false);
      return;
    }
    try {
      final rows = await _db
          .from('friendships')
          .select('requester_id, addressee_id, status')
          .or('requester_id.eq.$_uid,addressee_id.eq.$_uid');

      final friends = <FriendModel>[];
      final sent = <FriendModel>[];
      final received = <FriendModel>[];

      for (final r in rows as List) {
        final isRequester = r['requester_id'] == _uid;
        final otherId = isRequester
            ? r['addressee_id'] as String
            : r['requester_id'] as String;
        final status = r['status'] as String;

        // Fetch the other user's profile
        final profile = await _db
            .from('profiles')
            .select('id, name, email, bicycle_type, total_km, total_rides, total_co2_saved_grams')
            .eq('id', otherId)
            .maybeSingle();
        if (profile == null) continue;

        // Fetch their unlocked achievement IDs
        final achRows = await _db
            .from('user_achievements')
            .select('achievement_id')
            .eq('user_id', otherId);
        final achIds = (achRows as List)
            .map((a) => a['achievement_id'] as String)
            .toList();

        FriendshipStatus friendStatus;
        if (status == 'accepted') {
          friendStatus = FriendshipStatus.accepted;
        } else if (isRequester) {
          friendStatus = FriendshipStatus.pendingSent;
        } else {
          friendStatus = FriendshipStatus.pendingReceived;
        }

        final friend = FriendModel(
          userId: otherId,
          name: profile['name'] as String? ?? 'Cyclist',
          email: profile['email'] as String? ?? '',
          bicycleType: profile['bicycle_type'] as String?,
          status: friendStatus,
          totalKm: (profile['total_km'] as num?)?.toDouble() ?? 0,
          totalRides: (profile['total_rides'] as int?) ?? 0,
          totalCo2Grams:
              (profile['total_co2_saved_grams'] as num?)?.toDouble() ?? 0,
          unlockedAchievementIds: achIds,
        );

        if (status == 'accepted') {
          friends.add(friend);
        } else if (isRequester) {
          sent.add(friend);
        } else {
          received.add(friend);
        }
      }

      state = FriendsState(
        friends: friends,
        pendingSent: sent,
        pendingReceived: received,
        loading: false,
      );
    } catch (_) {
      state = state.copyWith(loading: false);
    }
  }

  // ── Search ─────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    if (query.trim().length < 2) return [];
    try {
      final rows = await _db
          .from('profiles')
          .select('id, name, email, bicycle_type')
          .ilike('name', '%${query.trim()}%')
          .neq('id', _uid ?? '')
          .limit(10);
      return (rows as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> sendRequest(String targetId) async {
    if (_uid == null) return;
    try {
      await _db.from('friendships').upsert(
        {
          'requester_id': _uid,
          'addressee_id': targetId,
          'status': 'pending',
        },
        onConflict: 'requester_id,addressee_id',
      );
      await load();
    } catch (_) {}
  }

  Future<void> acceptRequest(String requesterId) async {
    if (_uid == null) return;
    try {
      await _db
          .from('friendships')
          .update({'status': 'accepted'})
          .eq('requester_id', requesterId)
          .eq('addressee_id', _uid!);
      await load();
    } catch (_) {}
  }

  Future<void> declineRequest(String requesterId) async {
    if (_uid == null) return;
    try {
      await _db
          .from('friendships')
          .delete()
          .eq('requester_id', requesterId)
          .eq('addressee_id', _uid!);
      await load();
    } catch (_) {}
  }

  Future<void> removeFriend(String friendId) async {
    if (_uid == null) return;
    try {
      // Delete both directions (either could be requester)
      await _db.from('friendships').delete().or(
            'and(requester_id.eq.$_uid,addressee_id.eq.$friendId),'
            'and(requester_id.eq.$friendId,addressee_id.eq.$_uid)',
          );
      await load();
    } catch (_) {}
  }
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final friendsProvider =
    StateNotifierProvider<FriendsNotifier, FriendsState>(
  (_) => FriendsNotifier(),
);
