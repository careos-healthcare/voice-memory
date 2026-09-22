import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A coordinate captured on the device.
class GeoPoint {
  const GeoPoint({required this.latitude, required this.longitude});

  final double latitude;
  final double longitude;
}

/// A neighborhood label, or a local coordinate label when geocoding is offline.
class NeighborhoodPlace {
  const NeighborhoodPlace({
    required this.neighborhood,
    required this.resolvedOffline,
    this.latitude,
    this.longitude,
  });

  final String neighborhood;
  final bool resolvedOffline;
  final double? latitude;
  final double? longitude;
}

/// Supplies the current device position. A missing platform plugin returns null.
abstract class DevicePositionSource {
  const DevicePositionSource();

  Future<GeoPoint?> currentPosition();
}

/// Turns coordinates into a neighborhood name. May fail while offline.
abstract class NeighborhoodGeocoder {
  const NeighborhoodGeocoder();

  Future<String?> neighborhoodName(GeoPoint point);
}

/// No platform location plugin is linked while V1 location is disabled.
class UnavailablePositionSource extends DevicePositionSource {
  const UnavailablePositionSource();

  @override
  Future<GeoPoint?> currentPosition() async => null;
}

/// Geocoder used when no network lookup is configured.
class UnavailableNeighborhoodGeocoder extends NeighborhoodGeocoder {
  const UnavailableNeighborhoodGeocoder();

  @override
  Future<String?> neighborhoodName(GeoPoint point) async => null;
}

/// Formats a readable place name from coordinates alone.
abstract final class OfflineNeighborhoodLabel {
  static String format(GeoPoint point) {
    final latitude = point.latitude.toStringAsFixed(2);
    final longitude = point.longitude.toStringAsFixed(2);
    return '$latitude, $longitude';
  }
}

/// Reverse-geocodes the current position into a neighborhood name.
///
/// When the geocoder is unreachable, the service still returns a local
/// coordinate label so a draft can be saved without a network.
class LocationService {
  LocationService({
    DevicePositionSource? positions,
    NeighborhoodGeocoder? geocoder,
  }) : _positions = positions ?? const UnavailablePositionSource(),
       _geocoder = geocoder ?? const UnavailableNeighborhoodGeocoder();

  final DevicePositionSource _positions;
  final NeighborhoodGeocoder _geocoder;

  Future<NeighborhoodPlace?> reverseGeocodeCurrent() async {
    final point = await _positions.currentPosition();
    if (point == null) return null;

    try {
      final name = (await _geocoder.neighborhoodName(point))?.trim();
      if (name != null && name.isNotEmpty) {
        return NeighborhoodPlace(
          neighborhood: name,
          resolvedOffline: false,
          latitude: point.latitude,
          longitude: point.longitude,
        );
      }
    } on Object catch (error, stackTrace) {
      AppLogger.debug(
        'neighborhood_geocode_offline_fallback',
        name: 'LocationService',
        error: error,
        stackTrace: stackTrace,
      );
    }

    return NeighborhoodPlace(
      neighborhood: OfflineNeighborhoodLabel.format(point),
      resolvedOffline: true,
      latitude: point.latitude,
      longitude: point.longitude,
    );
  }
}

final locationServiceProvider = Provider<LocationService>(
  (ref) => LocationService(),
);
