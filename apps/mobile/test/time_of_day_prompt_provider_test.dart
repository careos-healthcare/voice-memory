import 'package:archiveme_mobile/core/services/location_service.dart';
import 'package:archiveme_mobile/features/guided_entry/presentation/models/time_of_day_prompt.dart';
import 'package:archiveme_mobile/features/guided_entry/presentation/providers/time_of_day_prompt_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('local hour maps onto the three blank-entry prompts', () {
    const expected = <int, String>{
      0: 'Evening Debrief',
      4: 'Evening Debrief',
      5: 'Morning Reflection',
      11: 'Morning Reflection',
      12: 'Midday Check-In',
      16: 'Midday Check-In',
      17: 'Evening Debrief',
      23: 'Evening Debrief',
    };

    for (final entry in expected.entries) {
      final prompt = TimeOfDayPrompt.resolve(DateTime(2026, 6, 1, entry.key));
      expect(prompt.title, entry.value, reason: 'hour ${entry.key}');
    }
  });

  test('TimeOfDayPromptProvider uses the injected local clock', () {
    final container = ProviderContainer(
      overrides: [
        timeOfDayPromptProvider.overrideWith(
          () => TimeOfDayPromptProvider(clock: () => DateTime(2026, 6, 1, 13)),
        ),
      ],
    );
    addTearDown(container.dispose);

    final prompt = container.read(timeOfDayPromptProvider);
    expect(prompt.kind, TimeOfDayPromptKind.middayCheckIn);
    expect(prompt.title, 'Midday Check-In');
    expect(prompt.body, contains('middle of the day'));
  });

  test('reverse geocode keeps a local coordinate label when offline', () async {
    final service = LocationService(
      positions: _FixedPosition(
        const GeoPoint(latitude: 37.76, longitude: -122.42),
      ),
      geocoder: _OfflineGeocoder(),
    );

    final place = await service.reverseGeocodeCurrent();

    expect(place, isNotNull);
    expect(place!.neighborhood, '37.76, -122.42');
    expect(place.resolvedOffline, isTrue);
  });

  test(
    'reverse geocode prefers a neighborhood name when one is available',
    () async {
      final service = LocationService(
        positions: _FixedPosition(
          const GeoPoint(latitude: 37.76, longitude: -122.42),
        ),
        geocoder: _NamedGeocoder('Mission District'),
      );

      final place = await service.reverseGeocodeCurrent();

      expect(place!.neighborhood, 'Mission District');
      expect(place.resolvedOffline, isFalse);
    },
  );

  test('reverse geocode returns null without a position', () async {
    final place = await LocationService().reverseGeocodeCurrent();
    expect(place, isNull);
  });
}

class _FixedPosition extends DevicePositionSource {
  _FixedPosition(this.point);

  final GeoPoint point;

  @override
  Future<GeoPoint?> currentPosition() async => point;
}

class _NamedGeocoder extends NeighborhoodGeocoder {
  _NamedGeocoder(this.name);

  final String name;

  @override
  Future<String?> neighborhoodName(GeoPoint point) async => name;
}

class _OfflineGeocoder extends NeighborhoodGeocoder {
  @override
  Future<String?> neighborhoodName(GeoPoint point) async {
    throw StateError('offline');
  }
}
