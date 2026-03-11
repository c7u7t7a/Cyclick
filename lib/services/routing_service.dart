import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

/// A single step (turn) in a route.
class RouteStep {
  final LatLng point;
  final String instruction;
  const RouteStep({required this.point, required this.instruction});
}

/// Walking directions from [origin] to [destination] via OSRM public API.
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
}
