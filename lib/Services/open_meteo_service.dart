import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:dryvmobapp/Models/open_meteo_weather.dart';
import 'package:dryvmobapp/Models/lat_lng.dart';

class OpenMeteoServiceException implements Exception {
  final String message;
  const OpenMeteoServiceException(this.message);
  @override
  String toString() => message;
}

class OpenMeteoService {
  final http.Client _client;

  OpenMeteoService({http.Client? client}) : _client = client ?? http.Client();

  Future<OpenMeteoWeather> fetchCurrent({required LatLng location}) async {
    final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
      'latitude': location.lat.toString(),
      'longitude': location.lng.toString(),
      'current': 'temperature_2m,weather_code,wind_speed_10m',
      'hourly': 'precipitation_probability',
      'timezone': 'auto',
    });

    final resp = await _client.get(uri);
    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw OpenMeteoServiceException(
        'Open-Meteo request failed (HTTP ${resp.statusCode}).',
      );
    }

    final decoded = jsonDecode(resp.body);
    if (decoded is! Map) {
      throw const OpenMeteoServiceException(
        'Invalid Open-Meteo JSON response.',
      );
    }

    final json = decoded.cast<String, dynamic>();
    final current = json['current'];
    if (current is! Map) {
      throw const OpenMeteoServiceException('Missing current weather payload.');
    }

    DateTime? currentTime;
    final timeStr = (current['time'] as String?);
    if (timeStr != null) {
      currentTime = DateTime.tryParse(timeStr);
    }

    final temperature = (current['temperature_2m'] as num?)?.toDouble();
    final code = (current['weather_code'] as num?)?.toInt();
    final wind = (current['wind_speed_10m'] as num?)?.toDouble();

    double? precipProb;
    final hourly = json['hourly'];
    if (hourly is Map) {
      final times = hourly['time'];
      final probs = hourly['precipitation_probability'];
      if (times is List && probs is List && times.length == probs.length) {
        int idx = 0;
        if (currentTime != null) {
          final currentIso = currentTime.toIso8601String();
          final found = times.indexWhere(
            (t) => t is String && (t == timeStr || t == currentIso),
          );
          if (found >= 0) idx = found;
        }

        final p = probs.isNotEmpty ? probs[idx] : null;
        precipProb = (p is num) ? p.toDouble() : null;
      }
    }

    return OpenMeteoWeather(
      time: currentTime,
      temperatureC: temperature,
      weatherCode: code,
      windSpeedKmh: wind,
      precipitationProbability: precipProb,
    );
  }
}
