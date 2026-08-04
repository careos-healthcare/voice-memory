import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../core/config/v1_capability_registry.dart';
import '../models/local_capture_context.dart';

abstract interface class LocalLocationMetadataHook {
  Future<String?> resolveCoarseLabel({required bool requestPermission});
}

abstract interface class LocalCalendarMetadataHook {
  Future<String?> resolveCurrentEventName({required bool requestPermission});
}

/// Resolves optional ambient labels locally without sending them to an app backend.
///
/// Callers may collect silently with [requestPermissions] set to false. This
/// allows capture screens to attach context automatically only when the user
/// has already granted the relevant OS permissions.
class AmbientContextService {
  AmbientContextService({
    LocalLocationMetadataHook? locationHook,
    LocalCalendarMetadataHook? calendarHook,
  }) : _locationHook =
           locationHook ??
           (V1CapabilityRegistry.location
               ? DeviceLocationMetadataHook()
               : const DisabledLocationMetadataHook()),
       _calendarHook =
           calendarHook ??
           (V1CapabilityRegistry.calendar
               ? DeviceCalendarMetadataHook()
               : const DisabledCalendarMetadataHook());

  final LocalLocationMetadataHook _locationHook;
  final LocalCalendarMetadataHook _calendarHook;

  Future<LocalCaptureContext?> collect({
    required bool includeLocation,
    required bool includeCalendarEvent,
    bool requestPermissions = false,
    DateTime? now,
  }) async {
    if (!includeLocation && !includeCalendarEvent) return null;

    String? locationLabel;
    String? eventName;
    if (includeLocation) {
      try {
        locationLabel = await _locationHook.resolveCoarseLabel(
          requestPermission: requestPermissions,
        );
      } catch (_) {
        locationLabel = null;
      }
    }
    if (includeCalendarEvent) {
      try {
        eventName = await _calendarHook.resolveCurrentEventName(
          requestPermission: requestPermissions,
        );
      } catch (_) {
        eventName = null;
      }
    }

    final context = LocalCaptureContext(
      capturedAt: (now ?? DateTime.now()).toUtc(),
      locationLabel: _bounded(locationLabel),
      calendarEventName: _bounded(eventName),
    );
    return context.isEmpty ? null : context;
  }

  static String? _bounded(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed.length <= 100 ? trimmed : trimmed.substring(0, 100);
  }
}

final class DisabledLocationMetadataHook implements LocalLocationMetadataHook {
  const DisabledLocationMetadataHook();

  @override
  Future<String?> resolveCoarseLabel({required bool requestPermission}) async =>
      null;
}

final class DisabledCalendarMetadataHook implements LocalCalendarMetadataHook {
  const DisabledCalendarMetadataHook();

  @override
  Future<String?> resolveCurrentEventName({
    required bool requestPermission,
  }) async => null;
}

class DeviceLocationMetadataHook implements LocalLocationMetadataHook {
  @override
  Future<String?> resolveCoarseLabel({required bool requestPermission}) async {
    if (!await Geolocator.isLocationServiceEnabled()) return null;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied && requestPermission) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return null;
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.low,
        timeLimit: Duration(seconds: 6),
      ),
    );
    final placemarks = await Geocoding().placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );
    if (placemarks.isEmpty) return null;

    final place = placemarks.first;
    final parts = <String>[
      if (place.locality?.trim().isNotEmpty == true) place.locality!.trim(),
      if (place.administrativeArea?.trim().isNotEmpty == true)
        place.administrativeArea!.trim(),
    ];
    return parts.toSet().take(2).join(', ');
  }
}

class DeviceCalendarMetadataHook implements LocalCalendarMetadataHook {
  DeviceCalendarMetadataHook({MethodChannel? channel})
    : _channel =
          channel ?? const MethodChannel('archive_me/local_calendar_context');

  final MethodChannel _channel;

  @override
  Future<String?> resolveCurrentEventName({
    required bool requestPermission,
  }) async {
    var granted =
        await _channel.invokeMethod<bool>('hasCalendarPermission') == true;
    if (!granted && requestPermission) {
      granted =
          await _channel.invokeMethod<bool>('requestCalendarPermission') ==
          true;
    }
    if (!granted) return null;
    return (await _channel.invokeMethod<String>('currentEventTitle'))?.trim();
  }
}
