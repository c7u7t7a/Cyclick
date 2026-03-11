import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

class WeatherData {
  final double temperatureC;
  final int weatherCode;
  final double windSpeedKmh;
  final double precipitationMm;

  const WeatherData({
    required this.temperatureC,
    required this.weatherCode,
    required this.windSpeedKmh,
    required this.precipitationMm,
  });

  /// Returns true when cycling is not recommended.
  bool get isAlert =>
      precipitationMm > 1.0 || windSpeedKmh > 40 || _isBadCode(weatherCode);

  String get alertMessage {
    if (_isBadCode(weatherCode)) return _describeCode(weatherCode);
    if (precipitationMm > 1.0) return 'Rain expected — slippery lanes';
    if (windSpeedKmh > 40) return 'Strong wind (${windSpeedKmh.toStringAsFixed(0)} km/h)';
    return '';
  }

  String get alertMessageRo {
    if (_isBadCode(weatherCode)) return _describeCodeRo(weatherCode);
    if (precipitationMm > 1.0) return 'Ploaie — piste alunecoase';
    if (windSpeedKmh > 40) return 'Vânt puternic (${windSpeedKmh.toStringAsFixed(0)} km/h)';
    return '';
  }

  IconData get icon {
    if (weatherCode <= 1) return Icons.wb_sunny_rounded;
    if (weatherCode <= 3) return Icons.cloud_rounded;
    if (weatherCode < 60) return Icons.foggy;
    if (weatherCode < 70) return Icons.grain_rounded;
    if (weatherCode < 80) return Icons.ac_unit_rounded;
    return Icons.thunderstorm_rounded;
  }

  Color get color {
    if (!isAlert) return const Color(0xFF4CAF50);
    if (precipitationMm > 5 || _isBadCode(weatherCode)) return const Color(0xFFE53935);
    return const Color(0xFFFF9800);
  }

  bool _isBadCode(int c) => c >= 95; // thunderstorm codes

  String _describeCode(int c) {
    if (c >= 95) return 'Thunderstorm warning';
    if (c >= 80) return 'Heavy showers';
    if (c >= 70) return 'Snow';
    if (c >= 60) return 'Rain';
    if (c >= 45) return 'Fog';
    return 'Clear';
  }

  String _describeCodeRo(int c) {
    if (c >= 95) return 'Alertă furtună';
    if (c >= 80) return 'Averse puternice';
    if (c >= 70) return 'Ninsoare';
    if (c >= 60) return 'Ploaie';
    if (c >= 45) return 'Ceață';
    return 'Senin';
  }
}

class WeatherService {
  // OpenMeteo — completely free, no API key required.
  static const _base = 'https://api.open-meteo.com/v1/forecast';

  Future<WeatherData> fetchCurrent({
    double lat = 44.4557,
    double lon = 26.1162,
  }) async {
    final uri = Uri.parse(_base).replace(queryParameters: {
      'latitude': lat.toString(),
      'longitude': lon.toString(),
      'current': 'temperature_2m,weathercode,windspeed_10m,precipitation',
      'timezone': 'Europe/Bucharest',
      'forecast_days': '1',
    });

    final res = await http.get(uri).timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) throw Exception('Weather fetch failed');

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    final cur = json['current'] as Map<String, dynamic>;

    return WeatherData(
      temperatureC: (cur['temperature_2m'] as num).toDouble(),
      weatherCode: (cur['weathercode'] as num).toInt(),
      windSpeedKmh: (cur['windspeed_10m'] as num).toDouble(),
      precipitationMm: (cur['precipitation'] as num).toDouble(),
    );
  }
}
