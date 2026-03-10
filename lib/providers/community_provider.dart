import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/community_group_model.dart';

/// Manages community group rides for Sector 2.
///
/// TODO: Replace with Supabase Realtime for live participant counts:
///   supabase.from('community_groups')
///     .stream(primaryKey: ['id'])
///     .listen((rows) => state = rows.map(CommunityGroupModel.fromJson).toList())
///
/// Join/leave should call an Edge Function to atomically:
///   1. INSERT/DELETE from group_members(group_id, user_id)
///   2. UPDATE community_groups SET participant_count = count(*)
class CommunityNotifier extends StateNotifier<List<CommunityGroupModel>> {
  CommunityNotifier() : super(_seedGroups);

  void toggleJoin(String groupId) {
    state = [
      for (final g in state)
        if (g.id == groupId)
          g.copyWith(
            isJoined: !g.isJoined,
            participantCount:
                g.isJoined ? g.participantCount - 1 : g.participantCount + 1,
          )
        else
          g
    ];
  }
}

final communityProvider =
    StateNotifierProvider<CommunityNotifier, List<CommunityGroupModel>>(
  (_) => CommunityNotifier(),
);

// ─── Seed data ────────────────────────────────────────────────────────────────
final List<CommunityGroupModel> _seedGroups = [
  CommunityGroupModel(
    id: 'grp-01',
    name: 'Sector 2 Morning Ride',
    description:
        'A calm morning loop through Parcul Circului — perfect for beginners!',
    rideDate: DateTime.now().add(const Duration(days: 1, hours: 6)),
    meetingPoint: 'Parcul Circului, Intrarea A',
    meetingLat: 44.4443,
    meetingLon: 26.1200,
    participantCount: 8,
    maxParticipants: 20,
    safetyLevel: SafetyLevel.high,
    organizerId: 'user-005',
    routeDescription: 'Parcul Circului → Bd. Ferdinand → Parcul IOR',
  ),
  CommunityGroupModel(
    id: 'grp-02',
    name: 'Evening City Tour',
    description:
        'Explore Sector 2\'s lit streets after sunset. Front & rear lights required!',
    rideDate: DateTime.now().add(const Duration(hours: 18)),
    meetingPoint: 'Stația Metro Piața Muncii',
    meetingLat: 44.4260,
    meetingLon: 26.1180,
    participantCount: 15,
    maxParticipants: 25,
    safetyLevel: SafetyLevel.medium,
    organizerId: 'user-006',
    routeDescription: 'Piața Muncii → Bd. Pache Protopopescu → Calea Moșilor',
  ),
  CommunityGroupModel(
    id: 'grp-03',
    name: 'Family Ride – Mogoșoaia',
    description:
        'Slow & family-friendly ride to Mogoșoaia Palace. Kids & e-bikes welcome!',
    rideDate: DateTime.now().add(const Duration(days: 3)),
    meetingPoint: 'Piața Iancului',
    meetingLat: 44.4380,
    meetingLon: 26.1380,
    participantCount: 6,
    maxParticipants: 30,
    safetyLevel: SafetyLevel.high,
    organizerId: 'user-007',
    routeDescription:
        'Piața Iancului → Șos. Colentina → Mogoșoaia Palace (35km round trip)',
  ),
  CommunityGroupModel(
    id: 'grp-04',
    name: 'Infrastructure Watch Ride',
    description:
        'Ride together to document cycling hazards for City Hall. Bring your phone!',
    rideDate: DateTime.now().add(const Duration(days: 5)),
    meetingPoint: 'Stația Metro Universitate',
    meetingLat: 44.4355,
    meetingLon: 26.1016,
    participantCount: 22,
    maxParticipants: 50,
    safetyLevel: SafetyLevel.low,
    organizerId: 'user-008',
    routeDescription: 'Universitate → Bd. Magheru → Calea Moșilor → Piața Muncii',
  ),
];
