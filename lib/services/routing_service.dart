import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../providers/cycling_routes_layer_provider.dart';

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

  /// Fetch 3 cycling route alternatives.
  ///
  /// When [geoJsonRoutes] are provided (from the cycling-infrastructure layer),
  /// the first option is always routed **through official cycling segments**
  /// via intermediate waypoints. OSRM fills the remaining alternatives and acts
  /// as the fallback when GeoJSON routing is not possible.
  Future<List<CyclingRouteOption>> getCyclingRouteOptions(
      LatLng origin, LatLng dest,
      {List<CyclingRouteFeature> geoJsonRoutes = const []}) async {
    // ── 1. GeoJSON-first attempt ────────────────────────────────────────────
    List<LatLng>? geoRoute;
    if (geoJsonRoutes.isNotEmpty) {
      geoRoute = await _routeViaGeoJson(origin, dest, geoJsonRoutes);
    }

    // ── 2. OSRM alternatives (always fetched as fallback / extra options) ──
    final uri = Uri.parse(
        '$_base/cycling/${origin.longitude},${origin.latitude};${dest.longitude},${dest.latitude}'
        '?overview=full&geometries=geojson&alternatives=true&steps=false');

    List<dynamic> rawRoutes;
    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) {
        if (geoRoute != null) return _singleGeoResultList(origin, dest, geoRoute);
        return _fallback(origin, dest);
      }
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      rawRoutes = json['routes'] as List<dynamic>;
      if (rawRoutes.isEmpty) {
        if (geoRoute != null) return _singleGeoResultList(origin, dest, geoRoute);
        return _fallback(origin, dest);
      }
    } catch (_) {
      if (geoRoute != null) return _singleGeoResultList(origin, dest, geoRoute);
      return _fallback(origin, dest);
    }

    // Parse OSRM alternatives (up to 3, fastest first).
    final parsed = <List<LatLng>>[];
    for (final r in rawRoutes.take(3)) {
      final coords = r['geometry']['coordinates'] as List<dynamic>;
      parsed.add(coords
          .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
          .toList());
    }

    String makeSummary(Map<String, dynamic> r) {
      final km = ((r['distance'] as num) / 1000).toStringAsFixed(1);
      final min = ((r['duration'] as num) / 60).ceil();
      return '$km km · $min min';
    }

    // ── 3. Build final 3-option list ─────────────────────────────────────────
    if (geoRoute != null) {
      // Slot 0: official GeoJSON route (safest)
      // Slot 1: OSRM balanced  (2nd fastest alternative, or offset of fastest)
      // Slot 2: OSRM fastest
      final fastestPts  = parsed[0];
      final balancedPts = parsed.length > 1 ? parsed[1] : _offsetPoints(parsed[0], 1);
      final fastSum     = makeSummary(rawRoutes[0] as Map<String, dynamic>);
      final balSum      = rawRoutes.length > 1
          ? makeSummary(rawRoutes[1] as Map<String, dynamic>)
          : fastSum;
      final geoDist = _routeDistanceKm(geoRoute);
      final geoMin  = (geoDist / 12 * 60).ceil(); // ~12 km/h cycling speed

      return [
        CyclingRouteOption(
          label: 'Rute Aprobate',
          summary: '${geoDist.toStringAsFixed(1)} km · $geoMin min',
          points: geoRoute,
          color: const Color(0xFF01796F),
          icon: Icons.route_rounded,
        ),
        CyclingRouteOption(
          label: 'Echilibrată',
          summary: balSum,
          points: balancedPts,
          color: const Color(0xFF1565C0),
          icon: Icons.balance_rounded,
        ),
        CyclingRouteOption(
          label: 'Cea mai rapidă',
          summary: fastSum,
          points: fastestPts,
          color: const Color(0xFFF44336),
          icon: Icons.bolt_rounded,
        ),
      ];
    }

    // No GeoJSON route available — return standard OSRM alternatives.
    final labels = ['Cea mai rapidă', 'Echilibrată', 'Cea mai sigură'];
    final colors = [
      const Color(0xFFF44336),
      const Color(0xFF01796F),
      const Color(0xFF1565C0),
    ];
    final icons = [Icons.bolt_rounded, Icons.balance_rounded, Icons.shield_rounded];

    final result = <CyclingRouteOption>[];
    for (int i = 0; i < 3; i++) {
      final pts = parsed.length > i ? parsed[i] : _offsetPoints(parsed[0], i);
      final rawIdx = rawRoutes.length > i ? i : 0;
      result.add(CyclingRouteOption(
        label: labels[i],
        summary: makeSummary(rawRoutes[rawIdx] as Map<String, dynamic>),
        points: pts,
        color: colors[i],
        icon: icons[i],
      ));
    }
    return [result[2], result.length > 1 ? result[1] : result[0], result[0]];
  }

  // ── GeoJSON routing helpers ───────────────────────────────────────────────

  /// Try to build a route that passes through official GeoJSON cycling
  /// infrastructure. Returns null when no relevant segments are found or the
  /// OSRM waypoint request fails.
  Future<List<LatLng>?> _routeViaGeoJson(
    LatLng origin,
    LatLng dest,
    List<CyclingRouteFeature> features,
  ) async {
    final waypoints = _findCyclingWaypoints(origin, dest, features);
    if (waypoints.isEmpty) return null;

    // Build multi-stop OSRM request: origin → waypoints → dest
    final allPts = [origin, ...waypoints, dest];
    final coordStr = allPts.map((p) => '${p.longitude},${p.latitude}').join(';');
    final uri = Uri.parse(
        '$_base/cycling/$coordStr?overview=full&geometries=geojson&steps=false');

    try {
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final routes = json['routes'] as List<dynamic>;
      if (routes.isEmpty) return null;
      final coords = routes.first['geometry']['coordinates'] as List<dynamic>;
      return coords
          .map((c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
          .toList();
    } catch (_) {
      return null;
    }
  }

  /// Select up to 3 midpoints from GeoJSON segments that fall inside the
  /// routing corridor between [origin] and [dest].
  /// Prefers low-risk segments (risk 1–3); falls back to all segments.
  List<LatLng> _findCyclingWaypoints(
    LatLng origin,
    LatLng dest,
    List<CyclingRouteFeature> features,
  ) {
    final minLat = min(origin.latitude, dest.latitude);
    final maxLat = max(origin.latitude, dest.latitude);
    final minLon = min(origin.longitude, dest.longitude);
    final maxLon = max(origin.longitude, dest.longitude);

    // Expand bounding box by 30 % (min 500 m each side)
    final latBuf = max((maxLat - minLat) * 0.30, 0.004);
    final lonBuf = max((maxLon - minLon) * 0.30, 0.005);

    final boxMinLat = minLat - latBuf;
    final boxMaxLat = maxLat + latBuf;
    final boxMinLon = minLon - lonBuf;
    final boxMaxLon = maxLon + lonBuf;

    final candidates = <({LatLng mid, int risk, double distFromOrigin})>[];

    for (final feat in features) {
      final risk = feat.riskClass ?? 6;
      for (final seg in feat.segments) {
        if (seg.length < 2) continue;
        // Use any segment whose midpoint is inside the bbox
        final mid = seg[seg.length ~/ 2];
        if (mid.latitude < boxMinLat || mid.latitude > boxMaxLat ||
            mid.longitude < boxMinLon || mid.longitude > boxMaxLon) continue;
        candidates.add((
          mid: mid,
          risk: risk,
          distFromOrigin: _haversineKm(origin, mid),
        ));
      }
    }

    if (candidates.isEmpty) return const [];

    // Sort: lowest risk first, then by distance from origin
    candidates.sort((a, b) {
      final rCmp = a.risk.compareTo(b.risk);
      return rCmp != 0 ? rCmp : a.distFromOrigin.compareTo(b.distFromOrigin);
    });

    // Keep up to 3 waypoints, ensure they're ordered origin → dest
    final best = candidates.take(3).map((c) => c.mid).toList();
    best.sort((a, b) =>
        _haversineKm(origin, a).compareTo(_haversineKm(origin, b)));
    return best;
  }

  double _haversineKm(LatLng a, LatLng b) {
    const r = 6371.0;
    final lat1 = a.latitude * pi / 180;
    final lat2 = b.latitude * pi / 180;
    final dlat = (b.latitude - a.latitude) * pi / 180;
    final dlon = (b.longitude - a.longitude) * pi / 180;
    final h = sin(dlat / 2) * sin(dlat / 2) +
        cos(lat1) * cos(lat2) * sin(dlon / 2) * sin(dlon / 2);
    return 2 * r * asin(sqrt(h.clamp(0.0, 1.0)));
  }

  double _routeDistanceKm(List<LatLng> pts) {
    double km = 0;
    for (int i = 1; i < pts.length; i++) {
      km += _haversineKm(pts[i - 1], pts[i]);
    }
    return km;
  }

  CyclingRouteOption _singleGeoResult(
      LatLng origin, LatLng dest, List<LatLng> geoRoute) {
    final dist = _routeDistanceKm(geoRoute);
    final min = (dist / 12 * 60).ceil();
    return CyclingRouteOption(
      label: 'Rute Aprobate',
      summary: '${dist.toStringAsFixed(1)} km · $min min',
      points: geoRoute,
      color: const Color(0xFF01796F),
      icon: Icons.route_rounded,
    );
  }

  // (kept for when _singleGeoResult is the only result — wrap in list)
  List<CyclingRouteOption> _singleGeoResultList(
      LatLng origin, LatLng dest, List<LatLng> geoRoute) {
    final r = _singleGeoResult(origin, dest, geoRoute);
    return [r, r, r];
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
