import 'package:flutter/material.dart';

/// The type of infrastructure report submitted by a cyclist.
enum ReportType {
  pothole,
  dangerousIntersection,
  blockedLane,
  safeZone,
}

extension ReportTypeX on ReportType {
  String get label {
    switch (this) {
      case ReportType.pothole:
        return 'Pothole';
      case ReportType.dangerousIntersection:
        return 'Dangerous\nIntersection';
      case ReportType.blockedLane:
        return 'Blocked Lane';
      case ReportType.safeZone:
        return 'Safe Zone';
    }
  }

  IconData get icon {
    switch (this) {
      case ReportType.pothole:
        return Icons.warning_amber_rounded;
      case ReportType.dangerousIntersection:
        return Icons.dangerous_rounded;
      case ReportType.blockedLane:
        return Icons.block_rounded;
      case ReportType.safeZone:
        return Icons.shield_rounded;
    }
  }

  Color get color {
    switch (this) {
      case ReportType.pothole:
        return const Color(0xFFFF9800);
      case ReportType.dangerousIntersection:
        return const Color(0xFFE53935);
      case ReportType.blockedLane:
        return const Color(0xFFE53935);
      case ReportType.safeZone:
        return const Color(0xFF4CAF50);
    }
  }
}

/// A citizen-submitted cycling infrastructure report pinned to the Living Map.
///
/// TODO: Connect to Supabase PostGIS:
///   Table: reports
///     id          UUID PRIMARY KEY DEFAULT gen_random_uuid()
///     type        TEXT NOT NULL
///     geom        GEOGRAPHY(POINT, 4326) NOT NULL   ← PostGIS spatial column
///     reported_by UUID REFERENCES auth.users(id)
///     reported_at TIMESTAMPTZ DEFAULT now()
///     description TEXT
///     upvote_count INT DEFAULT 0
///     is_active   BOOL DEFAULT true
///
///   Spatial query — fetch nearby reports within 500 m of user:
///     SELECT * FROM reports
///     WHERE ST_DWithin(geom, ST_MakePoint($lon, $lat)::geography, 500)
///       AND is_active = true;
///
///   Realtime: supabase.from('reports').stream(primaryKey: ['id']).listen(...)
class ReportModel {
  final String id;
  final ReportType type;
  final double latitude;
  final double longitude;
  final String reportedBy;
  final DateTime reportedAt;
  final String? description;
  final int upvoteCount;
  final bool isActive;

  const ReportModel({
    required this.id,
    required this.type,
    required this.latitude,
    required this.longitude,
    required this.reportedBy,
    required this.reportedAt,
    this.description,
    this.upvoteCount = 0,
    this.isActive = true,
  });

  factory ReportModel.fromJson(Map<String, dynamic> json) {
    return ReportModel(
      id: json['id'] as String,
      type: ReportType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ReportType.pothole,
      ),
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      reportedBy: json['reported_by'] as String,
      reportedAt: DateTime.parse(json['reported_at'] as String),
      description: json['description'] as String?,
      upvoteCount: (json['upvote_count'] as int?) ?? 0,
      isActive: (json['is_active'] as bool?) ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.name,
        'latitude': latitude,
        'longitude': longitude,
        'reported_by': reportedBy,
        'reported_at': reportedAt.toIso8601String(),
        'description': description,
        'upvote_count': upvoteCount,
        'is_active': isActive,
      };
}
