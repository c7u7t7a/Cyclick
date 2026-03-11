import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Thin wrapper around flutter_local_notifications for in-app push alerts.
/// Sends local notifications for new community routes and blocked lanes.
class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

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

  Future<void> _show({
    required int id,
    required String title,
    required String body,
    required String channel,
  }) async {
    if (!_initialized) await init();
    final ios = DarwinNotificationDetails(
      presentAlert: true,
      presentSound: true,
      subtitle: 'Cyclick · Sector 2',
    );
    await _plugin.show(
      id,
      title,
      body,
      NotificationDetails(iOS: ios),
    );
  }
}
