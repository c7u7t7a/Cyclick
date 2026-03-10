import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../models/ride_history_model.dart';
import '../core/constants.dart';

/// Accumulates metrics (distance, elapsed time, GPS track) for an active ride.
///
/// TODO: Persist completed rides to Supabase:
///   supabase.from('ride_history').insert(ride.toJson())
///
/// The route LINESTRING can be built from [trackPoints] using PostGIS:
///   ST_MakeLine(ARRAY[ST_MakePoint(lon1,lat1), ...])
class RideService {
  DateTime? _startTime;
  double _distanceKm = 0.0;
  Duration _elapsed = Duration.zero;
  Position? _lastPosition;
  final List<Position> _track = [];
  Timer? _ticker;

  bool _active = false;

  bool get isActive => _active;
  double get distanceKm => _distanceKm;
  Duration get elapsed => _elapsed;
  List<Position> get trackPoints => List.unmodifiable(_track);

  void start() {
    _active = true;
    _startTime = DateTime.now();
    _distanceKm = 0.0;
    _elapsed = Duration.zero;
    _lastPosition = null;
    _track.clear();

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsed = DateTime.now().difference(_startTime!);
    });
  }

  /// Feed each GPS position from [LocationService] into this method.
  void addPosition(Position pos) {
    if (!_active) return;

    if (_lastPosition != null) {
      final segKm =
          Geolocator.distanceBetween(
                _lastPosition!.latitude,
                _lastPosition!.longitude,
                pos.latitude,
                pos.longitude,
              ) /
              1000;

      // Filter GPS jitter — only accumulate if moved more than 2 m.
      if (segKm > 0.002) {
        _distanceKm += segKm;
        _track.add(pos);
      }
    } else {
      _track.add(pos);
    }

    _lastPosition = pos;
  }

  /// Stop tracking and produce a [RideHistoryModel] ready for persistence.
  RideHistoryModel finish(String userId) {
    _active = false;
    _ticker?.cancel();

    final co2 = _distanceKm * kCo2GramsPerKm;

    return RideHistoryModel(
      id: 'ride-${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      startedAt: _startTime ?? DateTime.now(),
      finishedAt: DateTime.now(),
      distanceKm: _distanceKm,
      duration: _elapsed,
      co2SavedGrams: co2,
    );
  }

  void dispose() {
    _ticker?.cancel();
  }
}
