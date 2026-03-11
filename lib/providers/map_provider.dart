import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/report_model.dart';
import '../models/ride_history_model.dart';
import '../services/location_service.dart';
import '../services/ride_service.dart';

// ─── Services ─────────────────────────────────────────────────────────────────
final locationServiceProvider = Provider<LocationService>((ref) {
  final svc = LocationService();
  ref.onDispose(svc.dispose);
  return svc;
});

final rideServiceProvider = Provider<RideService>((ref) {
  final svc = RideService();
  ref.onDispose(svc.dispose);
  return svc;
});

// ─── Current user position on map ─────────────────────────────────────────────
final currentPositionProvider = StateProvider<LatLng?>((ref) => null);

// ─── Current GPS heading (degrees, 0=North, 90=East, -1=unavailable) ──────────
final currentHeadingProvider = StateProvider<double>((ref) => -1.0);

// ─── Navigation destination ───────────────────────────────────────────────────
final navigationDestinationProvider = StateProvider<LatLng?>((ref) => null);

// ─── Ride origin (start point) ────────────────────────────────────────────────
final rideOriginProvider = StateProvider<LatLng?>((ref) => null);

// ─── Map reports (Living Map) — Supabase Realtime stream ─────────────────────
// Streams all active reports in real time; reconnects automatically on resume.
final reportsProvider = StreamProvider<List<ReportModel>>((ref) {
  final stream = Supabase.instance.client
      .from('reports')
      .stream(primaryKey: ['id'])
      .eq('is_active', true)
      .order('reported_at', ascending: false);

  return stream.map(
    (rows) => rows.map((row) => ReportModel.fromJson(row)).toList(),
  );
});

// ─── Active Ride State ────────────────────────────────────────────────────────
class RideState {
  final bool isActive;
  final double distanceKm;
  final Duration elapsed;
  final RideHistoryModel? completedRide;

  const RideState({
    this.isActive = false,
    this.distanceKm = 0.0,
    this.elapsed = Duration.zero,
    this.completedRide,
  });

  RideState copyWith({
    bool? isActive,
    double? distanceKm,
    Duration? elapsed,
    RideHistoryModel? completedRide,
  }) =>
      RideState(
        isActive: isActive ?? this.isActive,
        distanceKm: distanceKm ?? this.distanceKm,
        elapsed: elapsed ?? this.elapsed,
        completedRide: completedRide ?? this.completedRide,
      );
}

class RideNotifier extends StateNotifier<RideState> {
  final RideService _ride;
  final LocationService _location;
  final Ref _ref;

  RideNotifier(this._ride, this._location, this._ref)
      : super(const RideState());

  Future<void> startRide() async {
    await _location.requestPermission();
    _ride.start();
    // Mark as active immediately so the HUD shows even without a GPS fix
    state = state.copyWith(isActive: true);

    _location.startTracking(
      onPosition: (Position pos) {
        _ride.addPosition(pos);

        // Compute heading from position delta when GPS compass returns -1
        // (common on iOS when speed is low or compass is uncalibrated).
        double heading = pos.heading;
        if (heading < 0) {
          final prev = _ref.read(currentPositionProvider);
          if (prev != null) {
            heading = _bearingBetween(
              prev.latitude, prev.longitude,
              pos.latitude, pos.longitude,
            );
          }
        }

        _ref.read(currentPositionProvider.notifier).state =
            LatLng(pos.latitude, pos.longitude);
        if (heading >= 0) {
          _ref.read(currentHeadingProvider.notifier).state = heading;
        }
        state = state.copyWith(
          isActive: true,
          distanceKm: _ride.distanceKm,
          elapsed: _ride.elapsed,
        );
      },
    );
  }

  /// Returns the compass bearing (0–360°) from point A to point B.
  static double _bearingBetween(
      double lat1, double lon1, double lat2, double lon2) {
    final dLon = (lon2 - lon1) * math.pi / 180;
    final lat1R = lat1 * math.pi / 180;
    final lat2R = lat2 * math.pi / 180;
    final y = math.sin(dLon) * math.cos(lat2R);
    final x = math.cos(lat1R) * math.sin(lat2R) -
        math.sin(lat1R) * math.cos(lat2R) * math.cos(dLon);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  /// Finish the ride and return the completed [RideHistoryModel].
  RideHistoryModel finishRide(String userId) {
    _location.stopTracking();
    final completed = _ride.finish(userId);
    _ref.read(rideOriginProvider.notifier).state = null;
    state = RideState(completedRide: completed);
    return completed;
  }

  void clearCompletedRide() => state = const RideState();
}

final rideProvider =
    StateNotifierProvider<RideNotifier, RideState>((ref) => RideNotifier(
          ref.watch(rideServiceProvider),
          ref.watch(locationServiceProvider),
          ref,
        ));

