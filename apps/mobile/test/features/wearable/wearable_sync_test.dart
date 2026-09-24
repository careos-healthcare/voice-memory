import 'dart:io';
import 'dart:typed_data';

import 'package:archiveme_mobile/features/metadata/ambient_metadata_service.dart';
import 'package:archiveme_mobile/features/metadata/ambient_metadata_sources.dart';
import 'package:archiveme_mobile/features/wearable/wearable_ingestion_worker.dart';
import 'package:archiveme_mobile/features/wearable/wearable_sync_service.dart';
import 'package:archiveme_mobile/features/wearable/widgets/wearable_settings_tile.dart';
import 'package:archiveme_mobile/storage/sqlite/app_sqlite_database.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_021_ambient_metadata.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';

import '../../storage/sqlite/support/sqlite_test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const watch = MethodChannel(WearableSyncService.watchOsChannelName);
  const wear = MethodChannel(WearableSyncService.wearOsChannelName);

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(watch, null);
    messenger.setMockMethodCallHandler(wear, null);
  });

  test('wav samples reach sherpa and other files stay silent', () async {
    final wav = _wavSample(16384);
    Float32List? seen;
    final text = await WearableSherpaTranscriber(
      recognize: (samples) async {
        seen = samples;
        return 'Ada';
      },
    ).transcribeBytes(wav);
    expect(text, 'Ada');
    expect(seen, isNotNull);
    expect(seen!.first, closeTo(0.5, 0.001));
    expect(
      await WearableSherpaTranscriber(
        recognize: (samples) async => 'nope',
      ).transcribeBytes(Uint8List.fromList([1, 2, 3, 4])),
      isEmpty,
    );
  });

  test('a connected watch is transcribed, tagged, and quantized', () async {
    final harness = await _Harness.open();
    addTearDown(harness.close);
    var quantizeCalls = 0;
    var notices = 0;
    final worker = WearableIngestionWorker(
      database: harness.db,
      transcribe: (path) async => 'Met Ada at Banstead.',
      metadata: AmbientMetadataService(
        geo: const _BansteadGeo(),
        forecast: const _MildForecast(),
        activity: const DisabledActivityReader(),
        persist: (entryId, metadata) {
          return harness.db.update(
            'journal_entries',
            {Migration021AmbientMetadata.column: metadata.encode()},
            where: 'id = ?',
            whereArgs: [entryId],
          );
        },
      ),
      quantize: (db) async {
        quantizeCalls += 1;
        return null;
      },
      notificationsEnabled: false,
      notifier: (body) async {
        expect(body, wearableIndexedNotice);
        notices += 1;
      },
      clock: () => DateTime.utc(2026, 9, 23, 12),
    );
    final indexed = await worker.ingest(
      const WearableAudioClip(path: '/clips/wrist.wav', platform: 'watchos'),
    );
    expect(indexed, isTrue);
    expect(quantizeCalls, 1);
    expect(notices, 0);
    expect(worker.confirmations, [wearableIndexedNotice]);
    final rows = await harness.db.query('journal_entries');
    expect(rows.single['transcript'], 'Met Ada at Banstead.');
    expect(rows.single['ambient_metadata'], contains('Banstead'));
    final vectors = await harness.db.query('memory_transcript_embeddings');
    expect(vectors, hasLength(1));
  });

  test('recordings wait until the watch connects and sync is on', () async {
    final harness = await _Harness.open();
    addTearDown(harness.close);
    final worker = WearableIngestionWorker(
      database: harness.db,
      transcribe: (path) async => 'Saved from the wrist.',
      metadata: AmbientMetadataService(
        geo: const DisabledGeoReader(),
        forecast: const DisabledForecastReader(),
        activity: const DisabledActivityReader(),
      ),
      quantize: (db) async => null,
      notificationsEnabled: true,
      notifier: (body) async {
        expect(body, wearableIndexedNotice);
        harness.note();
      },
    );
    final service = WearableSyncService(
      worker: worker,
      backgroundSync: false,
    );
    _mockPlatforms(
      connected: true,
      watchPending: const [
        {'path': '/clips/wrist.m4a', 'platform': 'watchos'},
        {'path': '/clips/notes.txt'},
      ],
    );
    await service.bind();
    expect(service.connected, isTrue);
    expect(service.pending, hasLength(1));
    expect(await harness.db.query('journal_entries'), isEmpty);

    await service.setBackgroundSync(enabled: true);
    expect(service.pending, isEmpty);
    final rows = await harness.db.query('journal_entries');
    expect(rows.single['transcript'], 'Saved from the wrist.');
    expect(harness.notices, 1);
    expect(worker.confirmations.single, wearableIndexedNotice);
    service.dispose();
  });

  test('a disconnected watch holds audio until the link returns', () async {
    final harness = await _Harness.open();
    addTearDown(harness.close);
    final worker = WearableIngestionWorker(
      database: harness.db,
      transcribe: (path) async => 'Later.',
      quantize: (db) async => null,
      metadata: AmbientMetadataService(
        geo: const DisabledGeoReader(),
        forecast: const DisabledForecastReader(),
        activity: const DisabledActivityReader(),
      ),
    );
    final service = WearableSyncService(worker: worker);
    _mockPlatforms(connected: false);
    await service.bind();
    await _emit(watch, WearableSyncService.readyMethod, {
      'path': '/clips/later.wav',
    });
    expect(service.pending, hasLength(1));
    expect(await harness.db.query('journal_entries'), isEmpty);

    await _emit(watch, WearableSyncService.statusChangedMethod, {
      'connected': true,
    });
    expect(service.connected, isTrue);
    expect(service.pending, isEmpty);
    expect(
      (await harness.db.query('journal_entries')).single['transcript'],
      'Later.',
    );
    service.dispose();
  });

  testWidgets('settings show connection, sync, and the waiting count', (
    tester,
  ) async {
    var enabled = true;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WearableSettingsTile(
            connected: false,
            backgroundSync: enabled,
            pendingCount: 2,
            confirmation: wearableIndexedNotice,
            onBackgroundSyncChanged: (value) => enabled = value,
          ),
        ),
      ),
    );
    expect(find.text('Not connected'), findsOneWidget);
    expect(find.text('Battery-friendly background sync'), findsOneWidget);
    expect(find.text('2 recordings waiting'), findsOneWidget);
    expect(find.text(wearableIndexedNotice), findsOneWidget);
    await tester.tap(find.byKey(const Key('wearable_background_sync')));
    await tester.pump();
    expect(enabled, isFalse);
  });
}

class _Harness {
  _Harness(this.app, this.db);

  final AppSqliteDatabase app;
  final Database db;
  int notices = 0;

  void note() => notices += 1;

  static Future<_Harness> open() async {
    final directory = await Directory.systemTemp.createTemp('wearable-sync');
    final app = await openTestAppSqliteDatabase(
      filePath: '${directory.path}/archive.db',
    );
    return _Harness(app, app.database);
  }

  Future<void> close() async {
    await app.close();
    AppSqliteDatabase.resetForTest();
  }
}

class _BansteadGeo extends AmbientGeoReader {
  const _BansteadGeo();

  @override
  Future<AmbientGeoFix?> read() async {
    return const AmbientGeoFix(
      latitude: 51.3,
      longitude: -0.2,
      city: 'Banstead',
    );
  }
}

class _MildForecast extends AmbientForecastReader {
  const _MildForecast();

  @override
  Future<AmbientWeather?> read({
    required double latitude,
    required double longitude,
  }) async {
    return const AmbientWeather(temperatureC: 18, conditionCode: 1);
  }
}

void _mockPlatforms({
  required bool connected,
  List<Map<String, Object?>> watchPending = const [],
}) {
  const watch = MethodChannel(WearableSyncService.watchOsChannelName);
  const wear = MethodChannel(WearableSyncService.wearOsChannelName);
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(watch, (call) async {
    if (call.method == WearableSyncService.statusMethod) {
      return {'connected': connected};
    }
    if (call.method == WearableSyncService.consumePendingMethod) {
      return watchPending;
    }
    return null;
  });
  messenger.setMockMethodCallHandler(wear, (call) async {
    if (call.method == WearableSyncService.statusMethod) {
      return {'connected': false};
    }
    if (call.method == WearableSyncService.consumePendingMethod) {
      return <Map<String, Object?>>[];
    }
    return null;
  });
}

Future<void> _emit(MethodChannel channel, String method, Object? arguments) {
  const codec = StandardMethodCodec();
  return TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
        channel.name,
        codec.encodeMethodCall(MethodCall(method, arguments)),
        (_) {},
      );
}

Uint8List _wavSample(int sample) {
  final data = ByteData(46);
  void chars(int offset, String text) {
    for (var index = 0; index < text.length; index++) {
      data.setUint8(offset + index, text.codeUnitAt(index));
    }
  }

  chars(0, 'RIFF');
  data.setUint32(4, 38, Endian.little);
  chars(8, 'WAVE');
  chars(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, 16000, Endian.little);
  data.setUint32(28, 32000, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  chars(36, 'data');
  data.setUint32(40, 2, Endian.little);
  data.setInt16(44, sample, Endian.little);
  return data.buffer.asUint8List();
}
