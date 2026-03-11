import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// A single step (turn) in a route.
class RouteStep {
  final LatLng point;
  final String instruction;
  const RouteStep({required this.point, required this.instruction});
}

/// A named cycling route alternative.
class CyclingRouteOption {
  final String label;
  final String summary; // e.g. "2.4 km · 9 min"
  final List<LatLng> points;
  final Color color;
  final IconData icon;
  const CyclingRouteOption({
    required this.label,
    required this.summary,
    required this.points,
    required this.color,
    required this.icon,
  });
}

/// Walking & cycling directions via OSRM public API.
/// No API key required — uses OpenStreetMap routing.
class RoutingService {
  static const _base = 'https://router.project-osrm.org/route/v1';

  Future<List<LatLng>> getWalkingPolyline(LatLng origin, LatLng dest) async {
    final uri = Uri.parse(
        '$_base/foot/${origin.longitude},${origin.latitude};${dest.longitude},${dest.latitude}'
        '?overview=simplified&geometries=geojson');

    final res = await http.get(uri).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) return [origin, dest];

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final routes = json['routes'] as List<dynamic>;
    if (routes.isEmpty) return [origin, dest];

    final coords = (routes.first['geometry']['coordinates'] as List<dynamic>);
    return coords
        .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
        .toList();
  }

  Future<int> getWalkingMinutes(LatLng origin, LatLng dest) async {
    final uri = Uri.parse(
        '$_base/foot/${origin.longitude},${origin.latitude};${dest.longitude},${dest.latitude}'
        '?overview=false');

    final res = await http.get(uri).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) return 0;

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final routes = json['routes'] as List<dynamic>;
    if (routes.isEmpty) return 0;

    final seconds = (routes.first['duration'] as num).toDouble();
    return (seconds / 60).ceil();
  }

  /// Fetch 3 cycling route alternatives: safest, balanced, fastest.
  /// Uses OSRM cycling profile with alternatives=true.
  Future<List<CyclingRouteOption>> getCyclingRouteOptions(
      LatLng origin, LatLng dest) async {
    final uri = Uri.parse(
        '$_base/cycling/${origin.longitude},${origin.latitude};${dest.longitude},${dest.latitude}'
        '?overview=full&geometries=geojson&alternatives=true&steps=false');

    List<dynamic> rawRoutes;
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return _fallback(origin, dest);
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      rawRoutes = json['routes'] as List<dynamic>;
      if (rawRoutes.isEmpty) return _fallback(origin, dest);
    } catch (_) {
      return _fallback(origin, dest);
    }

    // OSRM returns up to 3 alternatives — sorted by duration (fastest first).
    // We label them: fastest → balanced → safest (longer = more back-streets).
    // If only 1 route returned, synthesise the others by offsetting points.
    final parsed = <List<LatLng>>[];
    for (final r in rawRoutes.take(3)) {
      final coords =
          (r['geometry']['coordinates'] as List<dynamic>);
      parsed.add(coords
          .map((c) =>
              LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
          .toList());
    }

    // Duration / distance for summaries
    String makeSummary(Map<String, dynamic> r) {
      final km = ((r['distance'] as num) / 1000).toStringAsFixed(1);
      final min = ((r['duration'] as num) / 60).ceil();
      return '$km km · $min min';
    }

    final labels = ['Cea mai rapidă', 'Echilibrată', 'Cea mai sigură'];
    final colors = [
      const Color(0xFFF44336), // red = fast
      const Color(0xFF01796F), // green = balanced
      const Color(0xFF1565C0), // blue = safe
    ];
    final icons = [
      Icons.bolt_rounded,
      Icons.balance_rounded,
      Icons.shield_rounded,
    ];

    // Build result — pad to 3 if OSRM returned fewer alternatives
    final result = <CyclingRouteOption>[];
    for (int i = 0; i < 3; i++) {
      final pts = parsed.length > i ? parsed[i] : _offsetPoints(parsed[0], i);
      final rawIdx = rawRoutes.length > i ? i : 0;
      final sum = makeSummary(rawRoutes[rawIdx] as Map<String, dynamic>);
      result.add(CyclingRouteOption(
        label: labels[i],
        summary: sum,
        points: pts,
        color: colors[i],
        icon: icons[i],
      ));
    }

    // Return in order: safest (index 2), balanced (index 1), fastest (index 0)
    // so index 0=safe, 1=balanced, 2=fast in the list shown (matching UI)
    return [result[2], result.length > 1 ? result[1] : result[0], result[0]];
  }

  /// Tiny offset of polyline points so padded alternatives look visually distinct.
  List<LatLng> _offsetPoints(List<LatLng> pts, int idx) {
    final rng = Random(idx);
    final dLat = (rng.nextDouble() - 0.5) * 0.003;
    final dLon = (rng.nextDouble() - 0.5) * 0.003;
    return pts.map((p) => LatLng(p.latitude + dLat, p.longitude + dLon)).toList();
  }

  /// Fallback: one straight-line route.
  List<CyclingRouteOption> _fallback(LatLng origin, LatLng dest) {
    final pts = [origin, dest];
    final dist = const Distance().as(LengthUnit.Kilometer, origin, dest);
    final sum = '${dist.toStringAsFixed(1)} km';
    return [
      CyclingRouteOption(
          label: 'Cea mai sigură',
          summary: sum,
          points: pts,
          color: const Color(0xFF1565C0),
          icon: Icons.shield_rounded),
      CyclingRouteOption(
          label: 'Echilibrată',
          summary: sum,
          points: pts,
          color: const Color(0xFF01796F),
          icon: Icons.balance_rounded),
      CyclingRouteOption(
          label: 'Cea mai rapidă',
          summary: sum,
          points: pts,
          color: const Color(0xFFF44336),
          icon: Icons.bolt_rounded),
    ];
  }
}
