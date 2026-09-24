import 'dart:convert';
import 'dart:io';

import 'package:archiveme_mobile/features/metadata/ambient_metadata.dart';
import 'package:archiveme_mobile/features/metadata/ambient_metadata_service.dart';
import 'package:archiveme_mobile/features/metadata/ambient_metadata_sources.dart';
import 'package:archiveme_mobile/features/metadata/ambient_metadata_store.dart';
import 'package:archiveme_mobile/features/metadata/entry_metadata_views.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_021_ambient_metadata.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('capture stores place, weather, and steps', () async {
    AmbientMetadata? written;
    final forecast = _Forecast();
    final service = AmbientMetadataService(
      geo: const _Geo(),
      forecast: forecast,
      activity: const _Activity(),
      persist: (entryId, metadata) async {
        written = metadata;
      },
    );

    service.begin();
    await pumpEventQueue();
    await service.attachToEntry('moment-1');

    expect(service.metadataFor('moment-1')?.badgeText, _badge);
    expect(written?.movementState, 'walking');
    expect(written?.conditionCode, 2);
    expect(forecast.calls, 1);
  });

  test('Open-Meteo forecast is reused from the local cache', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls += 1;
      return http.Response(
        jsonEncode({
          'current': {'temperature_2m': 18.2, 'weather_code': 2},
        }),
        200,
      );
    });
    final reader = OpenMeteoForecastReader(client: client);
    final first = await reader.read(latitude: 51.322, longitude: -0.204);
    final second = await reader.read(latitude: 51.324, longitude: -0.201);
    expect(first?.temperatureC, 18.2);
    expect(second?.conditionCode, 2);
    expect(calls, 1);
  });

  test('ambient_metadata column round-trips JSON', () async {
    final db = await databaseFactory.openDatabase(
      '${Directory.systemTemp.path}/ambient-metadata-${DateTime.now().microsecondsSinceEpoch}.db',
    );
    await db.execute('''
      CREATE TABLE journal_entries (
        id TEXT PRIMARY KEY,
        transcript TEXT
      )
    ''');
    await Migration021AmbientMetadata().up(db);
    await db.insert('journal_entries', {
      'id': 'moment-1',
      'transcript': 'A quieter evening.',
    });
    const metadata = AmbientMetadata(
      locality: 'Banstead',
      latitude: 51.32,
      longitude: -0.2,
      temperatureC: 18,
      conditionCode: 2,
      stepCount: 2400,
      movementState: 'walking',
    );
    await AmbientMetadataStore.write(
      db,
      entryId: 'moment-1',
      metadata: metadata,
    );
    final loaded = await AmbientMetadataStore.read(db, 'moment-1');
    expect(loaded?.badgeText, _badge);
    expect(loaded?.latitude, 51.32);
    await db.close();
  });

  testWidgets('detail and card show the surroundings badge', (tester) async {
    const metadata = AmbientMetadata(
      locality: 'Banstead',
      temperatureC: 18,
      conditionCode: 2,
      stepCount: 2400,
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              EntryDetailView(
                transcript: 'A quieter evening.',
                metadata: metadata,
              ),
              EntryCardTile(
                transcript: 'A quieter evening.',
                metadata: metadata,
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.text(_badge), findsNWidgets(2));
    expect(find.text('A quieter evening.'), findsNWidgets(2));
  });
}

const _badge = '📍 Banstead • 🌤️ 18°C • 🚶 2,400 steps';

class _Geo extends AmbientGeoReader {
  const _Geo();

  @override
  Future<AmbientGeoFix?> read() async {
    return const AmbientGeoFix(
      latitude: 51.32,
      longitude: -0.2,
      locality: 'Banstead',
      city: 'Banstead',
    );
  }
}

class _Forecast extends AmbientForecastReader {
  int calls = 0;
  AmbientWeather? cached;

  @override
  Future<AmbientWeather?> read({
    required double latitude,
    required double longitude,
  }) async {
    final existing = cached;
    if (existing != null) return existing;
    calls += 1;
    return cached = const AmbientWeather(temperatureC: 18, conditionCode: 2);
  }
}

class _Activity extends AmbientActivityReader {
  const _Activity();

  @override
  Future<AmbientActivity?> read() async {
    return const AmbientActivity(stepCount: 2400);
  }
}
