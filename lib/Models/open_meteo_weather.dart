class OpenMeteoWeather {
  final DateTime? time;
  final double? temperatureC;
  final int? weatherCode;
  final double? windSpeedKmh;
  final double? precipitationProbability;

  const OpenMeteoWeather({
    required this.time,
    required this.temperatureC,
    required this.weatherCode,
    required this.windSpeedKmh,
    required this.precipitationProbability,
  });

  String get conditionLabel {
    final code = weatherCode;
    if (code == null) return 'Weather';

    if (code == 0) return 'Clear sky';
    if (code >= 1 && code <= 3) {
      return switch (code) {
        1 => 'Mainly clear',
        2 => 'Partly cloudy',
        _ => 'Overcast',
      };
    }
    if (code == 45 || code == 48) return 'Fog';
    if (code >= 51 && code <= 57) return 'Drizzle';
    if (code >= 61 && code <= 67) return 'Rain';
    if (code >= 71 && code <= 77) return 'Snow';
    if (code >= 80 && code <= 82) return 'Rain showers';
    if (code >= 95 && code <= 99) return 'Thunderstorm';
    return 'Weather';
  }
}
