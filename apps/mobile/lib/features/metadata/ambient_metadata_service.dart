import 'dart:async';

import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/features/metadata/ambient_metadata.dart';
import 'package:archiveme_mobile/features/metadata/ambient_metadata_sources.dart';
import 'package:archiveme_mobile/features/metadata/ambient_metadata_store.dart';
import 'package:archiveme_mobile/services/app_services.dart';

/// Fetches place, weather, and movement when a recording starts.
class AmbientMetadataService {
  AmbientMetadataService({
    AmbientGeoReader? geo,
    AmbientForecastReader? forecast,
    AmbientActivityReader? activity,
    this.persist,
    DateTime Function()? clock,
  }) : _geo =
           geo ??
           (V1CapabilityRegistry.location
               ? LocationServiceGeoReader()
               : const DisabledGeoReader()),
       _forecast =
           forecast ??
           (V1CapabilityRegistry.internet
               ? OpenMeteoForecastReader()
               : const DisabledForecastReader()),
       _activity = activity ?? const CapabilityActivityReader(),
       _clock = clock ?? DateTime.now;

  static final AmbientMetadataService shared = AmbientMetadataService();

  final AmbientGeoReader _geo;
  final AmbientForecastReader _forecast;
  final AmbientActivityReader _activity;
  final Future<void> Function(String entryId, AmbientMetadata metadata)?
  persist;
  final DateTime Function() _clock;

  AmbientMetadata? pending;
  final Map<String, AmbientMetadata> stored = {};

  /// Starts a background fetch. Recording does not wait for it.
  void begin() {
    unawaited(_capturePending());
  }

  Future<void> _capturePending() async {
    pending = await capture();
  }

  Future<AmbientMetadata> capture() async {
    final capturedAt = _clock().toUtc();
    final geo = await _quiet(_geo.read);
    final activity = await _quiet(_activity.read);
    AmbientWeather? weather;
    if (geo != null) {
      weather = await _quiet(
        () => _forecast.read(
          latitude: geo.latitude,
          longitude: geo.longitude,
        ),
      );
    }
    final steps = activity?.stepCount;
    return AmbientMetadata(
      city: geo?.city,
      locality: geo?.locality,
      latitude: geo?.latitude,
      longitude: geo?.longitude,
      temperatureC: weather?.temperatureC,
      conditionCode: weather?.conditionCode,
      stepCount: steps,
      movementState: activity?.movementState ?? _movementFor(steps),
      capturedAt: capturedAt,
    );
  }

  /// Keeps [pending] on [entryId] and writes `ambient_metadata` when possible.
  Future<void> attachToEntry(String entryId) async {
    final metadata = pending ?? await capture();
    pending = metadata;
    if (metadata.isEmpty) return;
    stored[entryId] = metadata;
    final writer = persist;
    if (writer != null) {
      await writer(entryId, metadata);
      return;
    }
    if (!AppServices.isInitialized) return;
    try {
      await AmbientMetadataStore.write(
        AppServices.instance.sqliteDatabase.database,
        entryId: entryId,
        metadata: metadata,
      );
    } on Object {
      return;
    }
  }

  AmbientMetadata? metadataFor(String entryId) => stored[entryId];

  static String? _movementFor(int? steps) {
    if (steps == null) return null;
    if (steps < 200) return 'stationary';
    return 'walking';
  }
}

Future<T?> _quiet<T>(Future<T?> Function() read) async {
  try {
    return await read();
  } on Object {
    return null;
  }
}
