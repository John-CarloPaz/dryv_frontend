import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dryvmobapp/Models/flood_nearby.dart';
import 'package:dryvmobapp/Models/lat_lng.dart';
import 'package:dryvmobapp/Models/open_meteo_weather.dart';
import 'package:dryvmobapp/Services/flood_nearby_service.dart';
import 'package:dryvmobapp/Services/location_service.dart';
import 'package:dryvmobapp/Services/open_meteo_service.dart';

class ForecastLocationException implements Exception {
  final String message;
  const ForecastLocationException(this.message);

  @override
  String toString() => message;
}

class ForecastData {
  final LatLng location;
  final String? locationLabel;
  final FloodNearbyResponse flood;
  final OpenMeteoWeather weather;

  const ForecastData({
    required this.location,
    required this.locationLabel,
    required this.flood,
    required this.weather,
  });
}

class ForecastController extends AsyncNotifier<ForecastData> {
  LatLng? _selectedLocation;
  String? _selectedLabel;

  @override
  FutureOr<ForecastData> build() async {
    final location = await _resolveLocation();
    return _load(location);
  }

  Future<LatLng> _resolveLocation() async {
    final selected = _selectedLocation;
    if (selected != null) return selected;

    final loc = await LocationService.getLastKnownLocation();
    if (loc == null) {
      throw const ForecastLocationException(
        'Unable to read your location. Please enable GPS and location permission.',
      );
    }
    final lat = loc['lat'];
    final lng = loc['lng'];
    if (lat == null || lng == null) {
      throw const ForecastLocationException(
        'Unable to read your location. Please enable GPS and location permission.',
      );
    }
    return LatLng(lat: lat, lng: lng);
  }

  Future<ForecastData> _load(LatLng location) async {
    final floodSvc = FloodNearbyService();
    final meteoSvc = OpenMeteoService();

    final results = await Future.wait([
      floodSvc.fetchNearby(location: location),
      meteoSvc.fetchCurrent(location: location),
    ]);

    final flood = results[0] as FloodNearbyResponse;
    final weather = results[1] as OpenMeteoWeather;

    return ForecastData(
      location: location,
      locationLabel: _selectedLabel,
      flood: flood,
      weather: weather,
    );
  }

  Future<void> reload() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final location = await _resolveLocation();
      return _load(location);
    });
  }

  Future<void> setLocation(LatLng location, {String? label}) async {
    _selectedLocation = location;
    _selectedLabel = label;
    await reload();
  }

  Future<void> clearLocationOverride() async {
    _selectedLocation = null;
    _selectedLabel = null;
    await reload();
  }
}

final forecastProvider =
    AsyncNotifierProvider<ForecastController, ForecastData>(
      ForecastController.new,
    );
