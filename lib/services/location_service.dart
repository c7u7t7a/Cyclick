import 'dart:async';
import 'package:geolocator/geolocator.dart';

/// Wraps `geolocator` for permission management and GPS streaming.
///
/// TODO: For group ride live-tracking, stream positions to a Supabase Realtime
/// Broadcast channel so other participants can see each other on the map:
///   supabase.channel('group_ride_$groupId').sendBroadcastMessage(
///     event: 'location',
///     payload: {'lat': pos.latitude, 'lon': pos.longitude},
///   )
class LocationService {
  StreamSubscription<Position>? _subscription;
  Position? _lastKnownPosition;

  Position? get lastKnownPosition => _lastKnownPosition;

  /// Request location permissions; returns true if granted.
  Future<bool> requestPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// One-shot current position. Returns null if unavailable or outside Romania.
  Future<Position?> getCurrentPosition() async {
    if (!await requestPermission()) return null;
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      return _isInRomania(pos) ? pos : null;
    } catch (_) {
      return null;
    }
  }

  /// Returns false for obviously wrong simulator/mock positions outside Romania.
  static bool _isInRomania(Position pos) {
    return pos.latitude >= 43.5 &&
        pos.latitude <= 48.5 &&
        pos.longitude >= 20.0 &&
        pos.longitude <= 30.0;
  }

  /// Start continuous GPS stream for active ride tracking.
  /// Updates fire every 5 m of movement.
  void startTracking({
    required void Function(Position) onPosition,
    void Function(Object)? onError,
  }) {
    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    _subscription =
        Geolocator.getPositionStream(locationSettings: settings).listen(
      (pos) {
        if (!_isInRomania(pos)) return;
        _lastKnownPosition = pos;
        onPosition(pos);
      },
      onError: onError,
    );
  }

  /// Stop the GPS stream.
  void stopTracking() {
    _subscription?.cancel();
    _subscription = null;
  }

  void dispose() => stopTracking();
}
