import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/community_group_model.dart';

class CommunityNotifier extends AsyncNotifier<List<CommunityGroupModel>> {
  SupabaseClient get _db => Supabase.instance.client;

  @override
  Future<List<CommunityGroupModel>> build() => _fetch();

  Future<List<CommunityGroupModel>> _fetch() async {
    final rows = await _db
        .from('community_groups')
        .select()
        .order('ride_date', ascending: true);

    final userId = _db.auth.currentUser?.id;
    final joinedIds = <String>{};
    if (userId != null) {
      final members = await _db
          .from('group_members')
          .select('group_id')
          .eq('user_id', userId);
      for (final m in members) {
        joinedIds.add(m['group_id'] as String);
      }
    }

    return rows.map((r) {
      final m = Map<String, dynamic>.from(r);
      m['is_joined'] = joinedIds.contains(r['id'] as String);
      return CommunityGroupModel.fromJson(m);
    }).toList();
  }

  Future<void> toggleJoin(String groupId) async {
    final current = state.valueOrNull ?? [];
    final group = current.firstWhere((g) => g.id == groupId);
    if (group.isJoined) {
      await _db.rpc('leave_group', params: {'gid': groupId});
    } else {
      await _db.rpc('join_group', params: {'gid': groupId});
    }
    state = AsyncData(await _fetch());
  }

  Future<void> createGroup({
    required String name,
    required String description,
    required DateTime rideDate,
    required String meetingPoint,
    required double meetingLat,
    required double meetingLon,
    required int maxParticipants,
    required SafetyLevel safetyLevel,
    String? routeDescription,
  }) async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) return;
    await _db.from('community_groups').insert({
      'name': name,
      'description': description,
      'ride_date': rideDate.toIso8601String(),
      'meeting_point': meetingPoint,
      'meeting_lat': meetingLat,
      'meeting_lon': meetingLon,
      'max_participants': maxParticipants,
      'safety_level': safetyLevel.name,
      'organizer_id': userId,
      if (routeDescription != null && routeDescription.isNotEmpty)
        'route_description': routeDescription,
    });
    state = AsyncData(await _fetch());
  }
}

final communityProvider =
    AsyncNotifierProvider<CommunityNotifier, List<CommunityGroupModel>>(
  CommunityNotifier.new,
);
