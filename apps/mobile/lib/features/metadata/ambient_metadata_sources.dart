import 'dart:convert';

import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/core/services/location_service.dart';
import 'package:http/http.dart' as http;

/// A device fix with an optional reverse-geocoded place.
class AmbientGeoFix {
  const AmbientGeoFix({
    required this.latitude,
    required this.longitude,
    this.city,
    this.locality,
  });

  final double latitude;
  final double longitude;
  final String? city;
  final String? locality;
}

/// Temperature and an Open-Meteo weather code.
class AmbientWeather {
  const AmbientWeather({required this.temperatureC, this.conditionCode});

  final double temperatureC;
  final int? conditionCode;
}

/// Pedometer total and a coarse movement label.
class AmbientActivity {
  const AmbientActivity({this.stepCount, this.movementState});

  final int? stepCount;
  final String? movementState;
}

/// Position plus reverse geocode. Implementations may use geolocator.
abstract class AmbientGeoReader {
  const AmbientGeoReader();

  Future<AmbientGeoFix?> read();
}

/// Open-Meteo or a local cache of the last forecast.
abstract class AmbientForecastReader {
  const AmbientForecastReader();

  Future<AmbientWeather?> read({
    required double latitude,
    required double longitude,
  });
}

/// Step count and movement. Implementations may use a pedometer.
abstract class AmbientActivityReader {
  const AmbientActivityReader();

  Future<AmbientActivity?> read();
}

class DisabledGeoReader extends AmbientGeoReader {
  const DisabledGeoReader();

  @override
  Future<AmbientGeoFix?> read() async => null;
}

class DisabledForecastReader extends AmbientForecastReader {
  const DisabledForecastReader();

  @override
  Future<AmbientWeather?> read({
    required double latitude,
    required double longitude,
  }) async => null;
}

class DisabledActivityReader extends AmbientActivityReader {
  const DisabledActivityReader();

  @override
  Future<AmbientActivity?> read() async => null;
}

/// Uses [LocationService] only while the V1 location capability is on.
class LocationServiceGeoReader extends AmbientGeoReader {
  LocationServiceGeoReader({LocationService? locations})
    : _locations = locations ?? LocationService();

  final LocationService _locations;

  @override
  Future<AmbientGeoFix?> read() async {
    if (!V1CapabilityRegistry.location) return null;
    final place = await _locations.reverseGeocodeCurrent();
    if (place == null) return null;
    final latitude = place.latitude;
    final longitude = place.longitude;
    if (latitude == null || longitude == null) return null;
    return AmbientGeoFix(
      latitude: latitude,
      longitude: longitude,
      locality: place.neighborhood,
    );
  }
}

/// Open-Meteo forecast with an in-memory cache keyed by rounded coordinates.
class OpenMeteoForecastReader extends AmbientForecastReader {
  OpenMeteoForecastReader({http.Client? client, Map<String, AmbientWeather>? cache})
    : _client = client,
      cache = cache ?? <String, AmbientWeather>{};

  final http.Client? _client;
  final Map<String, AmbientWeather> cache;

  static String cacheKey(double latitude, double longitude) {
    return '${latitude.toStringAsFixed(2)},${longitude.toStringAsFixed(2)}';
  }

  @override
  Future<AmbientWeather?> read({
    required double latitude,
    required double longitude,
  }) async {
    final key = cacheKey(latitude, longitude);
    final cached = cache[key];
    if (cached != null) return cached;
    final client = _client ?? http.Client();
    final closeClient = _client == null;
    try {
      final uri = Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': '$latitude',
        'longitude': '$longitude',
        'current': 'temperature_2m,weather_code',
      });
      final response = await client
          .get(uri)
          .timeout(const Duration(seconds: 4));
      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) return null;
      final current = body['current'];
      if (current is! Map<String, dynamic>) return null;
      final temperature = current['temperature_2m'];
      if (temperature is! num) return null;
      final code = current['weather_code'];
      final weather = AmbientWeather(
        temperatureC: temperature.toDouble(),
        conditionCode: code is num ? code.round() : null,
      );
      cache[key] = weather;
      return weather;
    } on Object {
      return null;
    } finally {
      if (closeClient) client.close();
    }
  }
}

/// Step probe that stays quiet while the health capability is off.
class CapabilityActivityReader extends AmbientActivityReader {
  const CapabilityActivityReader({this.steps});

  final AmbientActivityReader? steps;

  @override
  Future<AmbientActivity?> read() async {
    if (!V1CapabilityRegistry.health && steps == null) return null;
    return steps?.read();
  }
}
