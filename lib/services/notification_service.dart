import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'weather_service.dart';

/// Thin wrapper around flutter_local_notifications for in-app push alerts.
/// Sends local notifications for new community routes, blocked lanes, and weather alerts.
class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  // Avoid spamming: track last weather-alert notification time
  DateTime? _lastWeatherAlert;

  Future<void> init() async {
    if (_initialized) return;
    const ios = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: false,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(iOS: ios);
    await _plugin.initialize(settings);
    _initialized = true;
  }

  Future<void> showNewRoute(String routeName, String author) async {
    await _show(
      id: 1001,
      title: '🚴 New Community Route',
      body: '$author added "$routeName" — check it out!',
      channel: 'routes',
    );
  }

  Future<void> showBlockedLane(String location) async {
    await _show(
      id: 1002,
      title: '⚠️ Lane Blocked',
      body: 'New hazard reported on $location. Choose an alternate route.',
      channel: 'hazards',
    );
  }

  /// Shows a weather alert notification. Throttled to once per 30 minutes.
  Future<void> showWeatherAlert(WeatherData weather, {bool isRo = false}) async {
    if (!weather.isAlert) return;
    final now = DateTime.now();
    if (_lastWeatherAlert != null &&
        now.difference(_lastWeatherAlert!).inMinutes < 30) {
      return;
    }
    _lastWeatherAlert = now;

    final msg = isRo ? weather.alertMessageRo : weather.alertMessage;
    final icon = _weatherEmoji(weather);
    await _show(
      id: 1003,
      title: '$icon Condiții nefavorabile pentru ciclism',
      body: msg.isNotEmpty ? msg : 'Atenție la condițiile meteo!',
      channel: 'weather',
    );
  }

  String _weatherEmoji(WeatherData w) {
    if (w.weatherCode >= 95) return '⛈️';
    if (w.weatherCode >= 80) return '🌧️';
    if (w.weatherCode >= 70) return '❄️';
    if (w.weatherCode >= 60) return '🌧️';
    if (w.weatherCode >= 45) return '🌫️';
    if (w.windSpeedKmh > 40) return '💨';
    return '⚠️';
  }

  Future<void> _show({
    required int id,
    required String title,
    required String body,
    required String channel,
  }) async {
    if (!_initialized) await init();
    const ios = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      subtitle: 'Cyclick · Sector 2',
    );
    await _plugin.show(
      id,
      title,
      body,
      const NotificationDetails(iOS: ios),
    );
  }
}
