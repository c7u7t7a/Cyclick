import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/weather_service.dart';

final weatherServiceProvider = Provider<WeatherService>((_) => WeatherService());

/// Auto-refreshing weather provider — polls every 10 minutes.
final weatherProvider = FutureProvider.autoDispose<WeatherData>((ref) async {
  ref.keepAlive();
  return ref.watch(weatherServiceProvider).fetchCurrent();
});
