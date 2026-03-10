import 'package:flutter/material.dart';

/// Perceived safety level for a community group ride.
enum SafetyLevel { low, medium, high }

extension SafetyLevelX on SafetyLevel {
  String get label {
    switch (this) {
      case SafetyLevel.low:
        return 'Low Safety';
      case SafetyLevel.medium:
        return 'Moderate';
      case SafetyLevel.high:
        return 'Very Safe';
    }
  }

  Color get color {
    switch (this) {
      case SafetyLevel.low:
        return const Color(0xFFFF9800);
      case SafetyLevel.medium:
        return const Color(0xFFFFEB3B);
      case SafetyLevel.high:
        return const Color(0xFF4CAF50);
    }
  }

  IconData get icon {
    switch (this) {
      case SafetyLevel.low:
        return Icons.warning_amber_rounded;
      case SafetyLevel.medium:
        return Icons.shield_outlined;
      case SafetyLevel.high:
        return Icons.shield_rounded;
    }
  }
}

/// A group cycling event organized within the Sector 2 community.
/// Designed to help cyclists overcome the fear of riding alone.
///
/// TODO: Connect to Supabase:
///   Table: community_groups
///     id                UUID PRIMARY KEY DEFAULT gen_random_uuid()
///     name              TEXT NOT NULL
///     description       TEXT
///     ride_date         TIMESTAMPTZ NOT NULL
///     meeting_point     TEXT
///     geom              GEOGRAPHY(POINT, 4326)  ← meeting point location
///     participant_count INT DEFAULT 0
///     max_participants  INT NOT NULL
///     safety_level      TEXT NOT NULL
///     organizer_id      UUID REFERENCES auth.users(id)
///     route_description TEXT
///
///   Realtime participant_count:
///     supabase.from('community_groups')
///       .stream(primaryKey: ['id'])
///       .listen((data) => updateGroupList(data))
///
///   Join/leave via an Edge Function to atomically update participant_count
///   and upsert into a group_members junction table.
class CommunityGroupModel {
  final String id;
  final String name;
  final String description;
  final DateTime rideDate;
  final String meetingPoint;
  final double meetingLat;
  final double meetingLon;
  final int participantCount;
  final int maxParticipants;
  final SafetyLevel safetyLevel;
  final String organizerId;
  final String? routeDescription;

  /// Whether the current user has joined this group ride.
  final bool isJoined;

  const CommunityGroupModel({
    required this.id,
    required this.name,
    required this.description,
    required this.rideDate,
    required this.meetingPoint,
    required this.meetingLat,
    required this.meetingLon,
    required this.participantCount,
    required this.maxParticipants,
    required this.safetyLevel,
    required this.organizerId,
    this.routeDescription,
    this.isJoined = false,
  });

  bool get isFull => participantCount >= maxParticipants;
  double get occupancy => participantCount / maxParticipants;

  CommunityGroupModel copyWith({bool? isJoined, int? participantCount}) {
    return CommunityGroupModel(
      id: id,
      name: name,
      description: description,
      rideDate: rideDate,
      meetingPoint: meetingPoint,
      meetingLat: meetingLat,
      meetingLon: meetingLon,
      participantCount: participantCount ?? this.participantCount,
      maxParticipants: maxParticipants,
      safetyLevel: safetyLevel,
      organizerId: organizerId,
      routeDescription: routeDescription,
      isJoined: isJoined ?? this.isJoined,
    );
  }

  factory CommunityGroupModel.fromJson(Map<String, dynamic> json) {
    return CommunityGroupModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      rideDate: DateTime.parse(json['ride_date'] as String),
      meetingPoint: json['meeting_point'] as String,
      meetingLat: (json['meeting_lat'] as num).toDouble(),
      meetingLon: (json['meeting_lon'] as num).toDouble(),
      participantCount: json['participant_count'] as int,
      maxParticipants: json['max_participants'] as int,
      safetyLevel: SafetyLevel.values.firstWhere(
        (e) => e.name == json['safety_level'],
        orElse: () => SafetyLevel.medium,
      ),
      organizerId: json['organizer_id'] as String,
      routeDescription: json['route_description'] as String?,
      isJoined: json['is_joined'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'ride_date': rideDate.toIso8601String(),
        'meeting_point': meetingPoint,
        'meeting_lat': meetingLat,
        'meeting_lon': meetingLon,
        'participant_count': participantCount,
        'max_participants': maxParticipants,
        'safety_level': safetyLevel.name,
        'organizer_id': organizerId,
        'route_description': routeDescription,
        'is_joined': isJoined,
      };
}
