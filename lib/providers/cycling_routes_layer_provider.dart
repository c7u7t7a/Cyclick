import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

// ─── Model ────────────────────────────────────────────────────────────────────

class CyclingRouteFeature {
  final List<List<LatLng>> segments; // MultiLineString → list of LineStrings
  final int? riskClass;              // clasa_risc: 1 (safest) – 6 (most dangerous)
  final double lengthKm;             // computed from coordinates (lungime is null in data)
  final Color color;

  const CyclingRouteFeature({
    required this.segments,
    required this.riskClass,
    required this.lengthKm,
    required this.color,
  });
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

double _haversineKm(LatLng a, LatLng b) {
  const r = 6371.0;
  final lat1 = a.latitude * math.pi / 180;
  final lat2 = b.latitude * math.pi / 180;
  final dlat = (b.latitude - a.latitude) * math.pi / 180;
  final dlon = (b.longitude - a.longitude) * math.pi / 180;
  final h = math.sin(dlat / 2) * math.sin(dlat / 2) +
      math.cos(lat1) * math.cos(lat2) * math.sin(dlon / 2) * math.sin(dlon / 2);
  return 2 * r * math.asin(math.sqrt(h.clamp(0.0, 1.0)));
}

double _segmentLength(List<LatLng> pts) {
  double km = 0;
  for (int i = 1; i < pts.length; i++) {
    km += _haversineKm(pts[i - 1], pts[i]);
  }
  return km;
}

/// Minimum distance (km) from [p] to any vertex in any segment of [f].
double _minDist(CyclingRouteFeature f, LatLng p) {
  double minD = double.infinity;
  for (final seg in f.segments) {
    for (final pt in seg) {
      final d = _haversineKm(p, pt);
      if (d < minD) minD = d;
    }
  }
  return minD;
}

Color _riskColor(int? risk) => switch (risk) {
      1 => const Color(0xFF4CAF50), // green — safest
      2 => const Color(0xFF8BC34A), // light green
      3 => const Color(0xFFFFC107), // amber
      4 => const Color(0xFFFF9800), // orange
      5 => const Color(0xFFFF5722), // deep orange
      6 => const Color(0xFFF44336), // red — most dangerous
      _ => const Color(0xFF9E9E9E), // grey — unknown
    };

/// Human-readable risk class label.
String riskLabel(int? risk, {bool isRo = false}) => switch (risk) {
      1 => isRo ? 'Risc Minim' : 'Minimal Risk',
      2 => isRo ? 'Risc Scăzut' : 'Low Risk',
      3 => isRo ? 'Risc Mediu' : 'Medium Risk',
      4 => isRo ? 'Risc Ridicat' : 'High Risk',
      5 => isRo ? 'Risc Înalt' : 'Very High Risk',
      6 => isRo ? 'Risc Maxim' : 'Maximum Risk',
      _ => isRo ? 'Necunoscut' : 'Unknown',
    };

// ─── Provider ─────────────────────────────────────────────────────────────────

/// Parses `arcgis/rute_buccccc.geojson` (MultiLineString cycling infrastructure
/// for Bucharest) into a list of [CyclingRouteFeature] objects.
final cyclingRoutesProvider =
    FutureProvider<List<CyclingRouteFeature>>((ref) async {
  final raw =
      await rootBundle.loadString('arcgis/rute_buccccc.geojson');
  final json = jsonDecode(raw) as Map<String, dynamic>;
  final features = json['features'] as List<dynamic>;

  return features.map((f) {
    final props = f['properties'] as Map<String, dynamic>;
    final riskClass = props['clasa_risc'] as int?;
    final geom = f['geometry'] as Map<String, dynamic>;

    // GeoJSON coordinates are [longitude, latitude]
    final rawLines = geom['coordinates'] as List<dynamic>;
    final segments = rawLines.map((line) {
      return (line as List<dynamic>).map((coord) {
        final c = coord as List<dynamic>;
        return LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble());
      }).toList();
    }).toList();

    double totalKm = 0;
    for (final seg in segments) {
      totalKm += _segmentLength(seg);
    }

    return CyclingRouteFeature(
      segments: segments,
      riskClass: riskClass,
      lengthKm: totalKm,
      color: _riskColor(riskClass),
    );
  }).toList();
});

/// Whether the cycling infrastructure risk layer is visible on the map.
final showCyclingRoutesProvider = StateProvider<bool>((ref) => true);

/// Returns the nearest [CyclingRouteFeature] to [tap] within [thresholdKm],
/// or null if nothing is close enough.
CyclingRouteFeature? nearestRoute(
  List<CyclingRouteFeature> features,
  LatLng tap, {
  double thresholdKm = 0.08,
}) {
  CyclingRouteFeature? best;
  double bestDist = thresholdKm;
  for (final f in features) {
    final d = _minDist(f, tap);
    if (d < bestDist) {
      bestDist = d;
      best = f;
    }
  }
  return best;
}
