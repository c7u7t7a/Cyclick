/// Represents an authenticated user of Cyclick.
///
/// TODO: Map this to Supabase:
///   - Authentication: supabase.auth.currentUser (id, email)
///   - Extended profile: SELECT * FROM profiles WHERE id = auth.uid()
///   - Update profile: supabase.from('profiles').upsert({...})
class UserModel {
  final String id;
  final String name;
  final String email;
  final String? avatarUrl;

  /// e.g. 'Mountain', 'Road', 'City', 'E-Bike', 'Gravel'
  final String? bicycleType;

  final double totalKm;
  final int totalRides;

  /// Total CO₂ saved in grams compared to driving.
  final double totalCo2SavedGrams;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.avatarUrl,
    this.bicycleType,
    this.totalKm = 0.0,
    this.totalRides = 0,
    this.totalCo2SavedGrams = 0.0,
  });

  bool get isLoggedIn => id.isNotEmpty;

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      avatarUrl: json['avatar_url'] as String?,
      bicycleType: json['bicycle_type'] as String?,
      totalKm: (json['total_km'] as num?)?.toDouble() ?? 0.0,
      totalRides: (json['total_rides'] as int?) ?? 0,
      totalCo2SavedGrams:
          (json['total_co2_saved_grams'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'avatar_url': avatarUrl,
        'bicycle_type': bicycleType,
        'total_km': totalKm,
        'total_rides': totalRides,
        'total_co2_saved_grams': totalCo2SavedGrams,
      };

  UserModel copyWith({
    String? name,
    String? avatarUrl,
    String? bicycleType,
    double? totalKm,
    int? totalRides,
    double? totalCo2SavedGrams,
  }) {
    return UserModel(
      id: id,
      name: name ?? this.name,
      email: email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bicycleType: bicycleType ?? this.bicycleType,
      totalKm: totalKm ?? this.totalKm,
      totalRides: totalRides ?? this.totalRides,
      totalCo2SavedGrams: totalCo2SavedGrams ?? this.totalCo2SavedGrams,
    );
  }
}
