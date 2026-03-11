/// Model for a user that is a (potential) friend.
class FriendModel {
  final String userId;
  final String name;
  final String email;
  final String? bicycleType;
  final FriendshipStatus status;
  final double totalKm;
  final int totalRides;
  final double totalCo2Grams;
  final List<String> unlockedAchievementIds;

  const FriendModel({
    required this.userId,
    required this.name,
    required this.email,
    this.bicycleType,
    required this.status,
    this.totalKm = 0,
    this.totalRides = 0,
    this.totalCo2Grams = 0,
    this.unlockedAchievementIds = const [],
  });

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

enum FriendshipStatus {
  accepted,
  pendingSent,      // I sent the request, waiting
  pendingReceived,  // They sent to me, I decide
}
