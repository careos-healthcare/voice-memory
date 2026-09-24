import 'dart:async';
import 'dart:convert';

import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/core/services/location_service.dart';
import 'package:archiveme_mobile/models/ambient_context.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/services/mcp/platform/calendar_data_gateway.dart';
import 'package:archiveme_mobile/services/mcp/platform/health_data_gateway.dart';
import 'package:http/http.dart' as http;

/// Reads place, weather, steps, and the calendar event covering [DateTime.now].
///
/// Each probe is optional. A denied permission, a disabled V1 capability, or a
/// slow platform call becomes an empty field. [capture] itself finishes within
/// [budget].
class AmbientContextService {
  AmbientContextService({
    AmbientPlaceReader? places,
    AmbientWeatherReader? weather,
    AmbientStepReader? steps,
    AmbientCalendarReader? calendar,
    this.budget = const Duration(milliseconds: 500),
    DateTime Function()? clock,
  }) : _places = places ?? const DisabledPlaceReader(),
       _weather = weather ?? const DisabledWeatherReader(),
       _steps = steps ?? const DisabledStepReader(),
       _calendar = calendar ?? const DisabledCalendarReader(),
       _clock = clock ?? DateTime.now;

  /// Shared instance used while an entry is saved.
  ///
  /// Capabilities that are off in the V1 build stay disabled, so a save does
  /// not prompt for location, health, or calendar.
  static final AmbientContextService shared = AmbientContextService.automatic();

  final AmbientPlaceReader _places;
  final AmbientWeatherReader _weather;
  final AmbientStepReader _steps;
  final AmbientCalendarReader _calendar;
  final Duration budget;
  final DateTime Function() _clock;

  factory AmbientContextService.automatic() {
    return AmbientContextService(
      places: V1CapabilityRegistry.location
          ? LocationServicePlaceReader()
          : const DisabledPlaceReader(),
      weather: V1CapabilityRegistry.internet
          ? OpenMeteoWeatherReader()
          : const DisabledWeatherReader(),
      steps: V1CapabilityRegistry.health
          ? HealthStepReader()
          : const DisabledStepReader(),
      calendar: V1CapabilityRegistry.calendar
          ? DeviceCalendarTitleReader()
          : const DisabledCalendarReader(),
    );
  }

  Future<AmbientContext> capture() async {
    final capturedAt = _clock().toUtc();
    final started = DateTime.now();
    try {
      final pending = await Future.wait<Object?>([
        _within(_quiet(_places.read)),
        _within(_quiet(_steps.read)),
        _within(_quiet(_calendar.read)),
      ]);
      final place = pending[0] as AmbientPlace?;
      final steps = pending[1] as int?;
      final calendarTitle = pending[2] as String?;
      final weather = await _weatherFor(place, started);
      return AmbientContext(
        locality: place?.locality,
        weatherLabel: weather?.label,
        weatherGlyph: weather?.glyph ?? '⛅',
        stepCount: steps,
        calendarTitle: calendarTitle,
        capturedAt: capturedAt,
      );
    } on Object {
      return AmbientContext(capturedAt: capturedAt);
    }
  }

  /// Writes [capture] onto [entry] when any field came back.
  Future<JournalEntry> attach(JournalEntry entry) async {
    if (entry.display.ambientContext != null) return entry;
    final context = await capture();
    if (context.isEmpty) return entry;
    return entry.copyWith(
      display: entry.display.copyWith(ambientContext: context),
    );
  }

  Future<WeatherSnapshot?> _weatherFor(
    AmbientPlace? place,
    DateTime started,
  ) async {
    final latitude = place?.latitude;
    final longitude = place?.longitude;
    if (latitude == null || longitude == null) return null;
    final remaining = budget - DateTime.now().difference(started);
    if (remaining <= Duration.zero) return null;
    try {
      return await _quiet(
        () => _weather.read(latitude: latitude, longitude: longitude),
      ).timeout(remaining);
    } on Object {
      return null;
    }
  }

  Future<T?> _within<T>(Future<T?> future) {
    return future.timeout(budget, onTimeout: () => null);
  }
}

class AmbientPlace {
  const AmbientPlace({
    required this.locality,
    this.latitude,
    this.longitude,
  });

  final String locality;
  final double? latitude;
  final double? longitude;
}

class WeatherSnapshot {
  const WeatherSnapshot({required this.label, required this.glyph});

  final String label;
  final String glyph;
}

abstract class AmbientPlaceReader {
  const AmbientPlaceReader();

  Future<AmbientPlace?> read();
}

abstract class AmbientWeatherReader {
  const AmbientWeatherReader();

  Future<WeatherSnapshot?> read({
    required double latitude,
    required double longitude,
  });
}

abstract class AmbientStepReader {
  const AmbientStepReader();

  Future<int?> read();
}

abstract class AmbientCalendarReader {
  const AmbientCalendarReader();

  Future<String?> read();
}

class DisabledPlaceReader extends AmbientPlaceReader {
  const DisabledPlaceReader();

  @override
  Future<AmbientPlace?> read() async => null;
}

class DisabledWeatherReader extends AmbientWeatherReader {
  const DisabledWeatherReader();

  @override
  Future<WeatherSnapshot?> read({
    required double latitude,
    required double longitude,
  }) async => null;
}

class DisabledStepReader extends AmbientStepReader {
  const DisabledStepReader();

  @override
  Future<int?> read() async => null;
}

class DisabledCalendarReader extends AmbientCalendarReader {
  const DisabledCalendarReader();

  @override
  Future<String?> read() async => null;
}

class LocationServicePlaceReader extends AmbientPlaceReader {
  LocationServicePlaceReader({LocationService? locations})
    : _locations = locations ?? LocationService();

  final LocationService _locations;

  @override
  Future<AmbientPlace?> read() async {
    if (!V1CapabilityRegistry.location) return null;
    final place = await _locations.reverseGeocodeCurrent();
    if (place == null || place.neighborhood.trim().isEmpty) return null;
    return AmbientPlace(
      locality: place.neighborhood.trim(),
      latitude: place.latitude,
      longitude: place.longitude,
    );
  }
}

class OpenMeteoWeatherReader extends AmbientWeatherReader {
  OpenMeteoWeatherReader({http.Client? client}) : _client = client;

  final http.Client? _client;

  @override
  Future<WeatherSnapshot?> read({
    required double latitude,
    required double longitude,
  }) async {
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
          .timeout(const Duration(milliseconds: 400));
      if (response.statusCode != 200) return null;
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) return null;
      final current = body['current'];
      if (current is! Map<String, dynamic>) return null;
      final temperature = current['temperature_2m'];
      final code = current['weather_code'];
      if (temperature is! num) return null;
      final rounded = temperature.round();
      return WeatherSnapshot(
        label: '$rounded°C',
        glyph: _glyph(code is num ? code.round() : null),
      );
    } on Object {
      return null;
    } finally {
      if (closeClient) client.close();
    }
  }
}

class HealthStepReader extends AmbientStepReader {
  HealthStepReader({HealthDataGateway? health}) : _health = health;

  final HealthDataGateway? _health;

  @override
  Future<int?> read() async {
    if (!V1CapabilityRegistry.health && _health == null) return null;
    final now = DateTime.now();
    final gateway = _health ?? HealthKitGateway();
    final samples = await gateway.fetchMetrics(
      McpHealthQuery(
        start: DateTime(now.year, now.month, now.day),
        end: now,
        metricTypes: const ['steps'],
      ),
    );
    if (samples.isEmpty) return null;
    final total = samples.fold<double>(0, (sum, sample) => sum + sample.value);
    return total.round();
  }
}

class DeviceCalendarTitleReader extends AmbientCalendarReader {
  DeviceCalendarTitleReader({CalendarDataGateway? calendars})
    : _calendars = calendars;

  final CalendarDataGateway? _calendars;

  @override
  Future<String?> read() async {
    if (!V1CapabilityRegistry.calendar && _calendars == null) return null;
    final now = DateTime.now();
    final gateway = _calendars ?? DeviceCalendarGateway();
    final events = await gateway.fetchEvents(
      McpCalendarQuery(
        start: now.subtract(const Duration(hours: 12)),
        end: now.add(const Duration(hours: 12)),
      ),
    );
    for (final event in events) {
      final active = !now.isBefore(event.start) && now.isBefore(event.end);
      final title = event.title.trim();
      if (active && title.isNotEmpty) return title;
    }
    return null;
  }
}

String _glyph(int? code) {
  if (code == null) return '⛅';
  if (code == 0) return '☀️';
  if (code <= 3) return '⛅';
  if (code <= 48) return '🌫️';
  if (code <= 67 || (code >= 80 && code <= 82)) return '🌧️';
  if (code <= 77 || (code >= 85 && code <= 86)) return '🌨️';
  return '⛈️';
}

Future<T?> _quiet<T>(Future<T?> Function() read) async {
  try {
    return await read();
  } on Object {
    return null;
  }
}
