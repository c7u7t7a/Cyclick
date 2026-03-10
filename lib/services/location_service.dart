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

  /// One-shot current position. Returns null if unavailable.
  Future<Position?> getCurrentPosition() async {
    if (!await requestPermission()) return null;
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (_) {
      return null;
    }
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
