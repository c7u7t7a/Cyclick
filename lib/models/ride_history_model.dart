/// Quick-select feedback chips shown on the post-ride screen.
class FeedbackTag {
  static const String smoothSurface = 'Smooth Surface';
  static const String heavyTraffic = 'Heavy Traffic';
  static const String wellLit = 'Well Lit';
  static const String dangerousIntersection = 'Dangerous Intersection';

  static const List<String> all = [
    smoothSurface,
    heavyTraffic,
    wellLit,
    dangerousIntersection,
  ];
}

/// A completed cycling ride, including distance, duration, CO₂ savings,
/// and optional post-ride feedback submitted by the user.
///
/// TODO: Connect to Supabase:
///   Table: ride_history
///     id                UUID PRIMARY KEY DEFAULT gen_random_uuid()
///     user_id           UUID REFERENCES auth.users(id)
///     started_at        TIMESTAMPTZ NOT NULL
///     finished_at       TIMESTAMPTZ NOT NULL
///     distance_km       FLOAT NOT NULL
///     duration_seconds  INT NOT NULL
///     co2_saved_grams   FLOAT NOT NULL
///     safety_rating     FLOAT CHECK (safety_rating BETWEEN 1 AND 5)
///     feedback_tags     TEXT[]
///     city_hall_message TEXT          ← Trigger a Supabase Edge Function to
///                                        log actionable suggestions for City Hall
///     route             GEOGRAPHY(LINESTRING, 4326)  ← PostGIS for spatial analysis
///
///   Insert: supabase.from('ride_history').insert(ride.toJson())
///   Fetch:  supabase.from('ride_history')
///             .select().eq('user_id', userId)
///             .order('started_at', ascending: false)
class RideHistoryModel {
  final String id;
  final String userId;
  final DateTime startedAt;
  final DateTime finishedAt;
  final double distanceKm;
  final Duration duration;

  /// Grams of CO₂ saved vs. driving the same distance.
  final double co2SavedGrams;

  /// Post-ride safety rating 1–5 stars (null if not yet rated).
  final double? safetyRating;

  final List<String> feedbackTags;

  /// Optional message forwarded to City Hall infrastructure team.
  final String? cityHallMessage;

  /// Encoded route geometry (GeoJSON LineString or encoded polyline).
  final String? routePolyline;

  const RideHistoryModel({
    required this.id,
    required this.userId,
    required this.startedAt,
    required this.finishedAt,
    required this.distanceKm,
    required this.duration,
    required this.co2SavedGrams,
    this.safetyRating,
    this.feedbackTags = const [],
    this.cityHallMessage,
    this.routePolyline,
  });

  String get formattedDuration {
    final h = duration.inHours;
    final m = duration.inMinutes.remainder(60);
    if (h == 0) return '${m}m';
    return '${h}h ${m}m';
  }

  String get formattedCo2 {
    if (co2SavedGrams >= 1000) {
      return '${(co2SavedGrams / 1000).toStringAsFixed(2)} kg';
    }
    return '${co2SavedGrams.toStringAsFixed(0)} g';
  }

  RideHistoryModel copyWith({
    double? safetyRating,
    List<String>? feedbackTags,
    String? cityHallMessage,
  }) {
    return RideHistoryModel(
      id: id,
      userId: userId,
      startedAt: startedAt,
      finishedAt: finishedAt,
      distanceKm: distanceKm,
      duration: duration,
      co2SavedGrams: co2SavedGrams,
      safetyRating: safetyRating ?? this.safetyRating,
      feedbackTags: feedbackTags ?? this.feedbackTags,
      cityHallMessage: cityHallMessage ?? this.cityHallMessage,
      routePolyline: routePolyline,
    );
  }

  factory RideHistoryModel.fromJson(Map<String, dynamic> json) {
    return RideHistoryModel(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      startedAt: DateTime.parse(json['started_at'] as String),
      finishedAt: DateTime.parse(json['finished_at'] as String),
      distanceKm: (json['distance_km'] as num).toDouble(),
      duration: Duration(seconds: json['duration_seconds'] as int),
      co2SavedGrams: (json['co2_saved_grams'] as num).toDouble(),
      safetyRating: (json['safety_rating'] as num?)?.toDouble(),
      feedbackTags: List<String>.from(json['feedback_tags'] ?? []),
      cityHallMessage: json['city_hall_message'] as String?,
      routePolyline: json['route_polyline'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'started_at': startedAt.toIso8601String(),
        'finished_at': finishedAt.toIso8601String(),
        'distance_km': distanceKm,
        'duration_seconds': duration.inSeconds,
        'co2_saved_grams': co2SavedGrams,
        'safety_rating': safetyRating,
        'feedback_tags': feedbackTags,
        'city_hall_message': cityHallMessage,
        'route_polyline': routePolyline,
      };
}
