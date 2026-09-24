import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/core/execution/cancel_token.dart';
import 'package:archiveme_mobile/features/attachments/attachment_ingestion.dart';
import 'package:archiveme_mobile/features/attachments/local_ocr_processor.dart';
import 'package:archiveme_mobile/features/audio/sherpa_dual_mode_backend.dart';
import 'package:archiveme_mobile/features/chat/archive_chat_service.dart';
import 'package:archiveme_mobile/features/habits/habit_tracker_service.dart';
import 'package:archiveme_mobile/features/metadata/ambient_metadata_service.dart';
import 'package:archiveme_mobile/features/metadata/ambient_metadata_sources.dart';
import 'package:archiveme_mobile/features/metadata/ambient_metadata_store.dart';
import 'package:archiveme_mobile/features/sample_vault/sample_vault_embedder.dart';
import 'package:archiveme_mobile/features/search/entity_extraction_worker.dart';
import 'package:archiveme_mobile/features/wearable/wearable_ingestion_worker.dart';
import 'package:archiveme_mobile/storage/sqlite/app_sqlite_database.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_020_entity_graph.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_023_attachment_text.dart';
import 'package:archiveme_mobile/storage/sqlite/migrations/migration_026_habits.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqflite/sqflite.dart';

import '../test/storage/sqlite/support/sqlite_test_database.dart';

/// Cross-feature pipeline: PCM voice, ambient JSON, the entity graph,
/// habit logs, attachment OCR embeddings, and cited chat retrieval.
///
/// ```sh
/// flutter test integration_test/app_pipeline_test.dart
/// ```
void main() {
  _ensureTestBinding();

  testWidgets(
    'a voice moment updates metadata, entities, habits, ocr, and chat',
    (tester) async {
      final spoken = await tester.runAsync(() async {
        return _runPipeline();
      });
      await tester.pumpWidget(
        MaterialApp(home: Scaffold(body: Text(spoken ?? ''))),
      );
      await tester.pump();
      expect(find.textContaining('wrist-'), findsOneWidget);
      expect(find.textContaining('Met Ada in Banstead'), findsOneWidget);
    },
  );
}

Future<String> _runPipeline() async {
  final directory = await Directory.systemTemp.createTemp('app-pipeline');
  final app = await AppSqliteDatabase.open(
    filePath: '${directory.path}/archive.db',
    password: testSqliteEncryptionPassword,
    runDeferredBackfill: false,
    scheduleVectorExtensions: false,
  );
  addTearDown(() async {
    await app.close();
    await AppSqliteDatabase.resetForTest();
    if (directory.existsSync()) {
      directory.deleteSync(recursive: true);
    }
  });

  final db = app.database;
  final capturedAt = DateTime.utc(2026, 9, 23, 12);
  final pcm = Int16List.fromList(const [16384, -8192, 0, 4096]);
  final wavPath = '${directory.path}/moment.wav';
  await File(wavPath).writeAsBytes(_wavPcm16(pcm));

  final metadata = AmbientMetadataService(
    geo: const _PipelineGeo(),
    forecast: const _PipelineForecast(),
    activity: const _PipelineActivity(),
    clock: () => capturedAt,
    persist: (entryId, captured) {
      return AmbientMetadataStore.write(
        db,
        entryId: entryId,
        metadata: captured,
      );
    },
  );
  final worker = WearableIngestionWorker(
    database: db,
    metadata: metadata,
    clock: () => capturedAt,
    notificationsEnabled: false,
    quantize: (_) async => null,
    transcribe: (path) {
      return WearableSherpaTranscriber(
        recognize: _sherpaTranscript,
      ).transcribePath(path);
    },
  );

  expect(
    await worker.ingest(
      WearableAudioClip(
        path: wavPath,
        platform: 'test',
        capturedAt: capturedAt,
      ),
    ),
    isTrue,
  );

  final moments = await db.query(
    'journal_entries',
    columns: ['id', 'transcript', 'ambient_metadata'],
  );
  expect(moments, hasLength(1));
  final entryId = '${moments.single['id']}';
  expect(moments.single['transcript'], _voiceTranscript);

  final ambient =
      jsonDecode('${moments.single['ambient_metadata']}')
          as Map<String, dynamic>;
  expect(ambient['location'], {
    'city': 'Banstead',
    'locality': 'Banstead',
    'latitude': 51.32,
    'longitude': -0.2,
  });
  expect(ambient['weather'], {
    'temperature': 18.0,
    'conditionCode': 2,
  });
  final stored = await AmbientMetadataStore.read(db, entryId);
  expect(stored?.placeLabel, 'Banstead');
  expect(stored?.temperatureC, 18);

  const graph = EntityExtractionWorker();
  final first = await graph.processEntry(
    db: db,
    entryId: entryId,
    transcript: _voiceTranscript,
    seenAt: capturedAt,
  );
  expect(first.entityIds, contains('people:ada'));
  expect(first.entityIds, contains('locations:banstead'));
  expect(first.entityIds, contains('goals:run-daily'));
  const seenAt = 'seen_at:people:ada:locations:banstead';
  expect(await _weight(db, seenAt), 1);

  await graph.processEntry(
    db: db,
    entryId: '$entryId-again',
    transcript: _voiceTranscript,
    seenAt: capturedAt,
  );
  expect(await _weight(db, seenAt), 2);
  final people = await db.query(
    Migration020EntityGraph.entitiesTable,
    where: 'category = ?',
    whereArgs: [EntityCategories.people],
  );
  expect(people.single['name'], 'Ada');

  final habits = HabitTrackerService(
    database: db,
    clock: () => capturedAt,
  );
  final run = await habits.create(title: '5km run');
  final logs = await habits.detectFromMoment(
    entryId: entryId,
    transcript: _voiceTranscript,
    loggedAt: capturedAt,
  );
  expect(logs, hasLength(1));
  expect(logs.single.habitId, run.id);
  expect(logs.single.entryId, entryId);
  final storedLogs = await db.query(
    Migration026Habits.logsTable,
    where: 'entry_id = ?',
    whereArgs: [entryId],
  );
  expect(storedLogs, hasLength(1));
  expect(storedLogs.single['habit_id'], run.id);

  const pageText = 'Met Ada at Banstead.';
  final image = Uint8List.fromList(const [0x89, 0x50, 0x4E, 0x47, 1]);
  expect(V1CapabilityRegistry.cameraAndPhotos, isFalse);
  final ocr =
      await AttachmentOcrIngestion(
        processor: LocalOcrProcessor(
          photosEnabled: true,
          recognize: (bytes) async {
            expect(bytes, image);
            return ocrDocumentFromMlKit(
              text: pageText,
              blocks: const [
                MlKitTextBlock(
                  text: pageText,
                  left: 2,
                  top: 4,
                  right: 48,
                  bottom: 16,
                  lines: [pageText],
                  confidence: 0.9,
                ),
              ],
            );
          },
        ),
      ).ingest(
        db: db,
        entryId: entryId,
        imageBytes: image,
        filePath: '${directory.path}/note.png',
      );
  expect(ocr.document.text, pageText);
  expect(ocr.vectorHit?.id, entryId);
  final attachment = await db.query(
    Migration023AttachmentText.attachmentsTable,
    where: 'entry_id = ?',
    whereArgs: [entryId],
  );
  expect(attachment.single['attachment_text'], pageText);
  expect(
    attachment.single['embedding'],
    SampleVaultEmbedder.toBlob(SampleVaultEmbedder.embed(pageText)),
  );
  final entryText = await db.query(
    'journal_entries',
    columns: [Migration023AttachmentText.column],
    where: 'id = ?',
    whereArgs: [entryId],
  );
  expect(entryText.single[Migration023AttachmentText.column], pageText);

  final chat = ArchiveChatService(
    database: db,
    clock: () => capturedAt,
  );
  final retrieval = await chat.retrieve('Where did I meet Ada?');
  expect(retrieval.moments, hasLength(1));
  final cited = retrieval.moments.single;
  expect(cited.entryId, entryId);
  expect(cited.location, 'Banstead');
  expect(cited.transcript, _voiceTranscript);
  expect(cited.entities, containsAll(['Ada', 'Banstead', 'run daily']));
  expect(retrieval.synthesized, contains('Moment $entryId'));
  expect(retrieval.synthesized, contains('Entities: '));
  final mapped = cited.toJson();
  expect(mapped['entryId'], entryId);
  expect(mapped['entities'], cited.entities);

  final reply = StringBuffer();
  await for (final chunk in chat.streamReply(
    synthesized: retrieval.synthesized,
    cancel: ExecutionCancelToken(),
  )) {
    reply
      ..clear()
      ..write(chunk);
  }
  expect(reply.toString(), contains(entryId));
  expect(reply.toString(), contains('Ada'));
  expect(reply.toString(), contains('Banstead'));
  return reply.toString();
}

void _ensureTestBinding() {
  try {
    if (WidgetsBinding.instance is TestWidgetsFlutterBinding) return;
  } on Object {
    // The integration runner has not created a binding yet.
  }
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
}

const _voiceTranscript =
    'Met Ada in Banstead. I want to run daily when rested. '
    'Finished my 5km run.';

/// Decodes 16-bit PCM, then returns the sherpa transcript for those samples.
///
/// `bindSherpaDualMode()` has no model files in this suite, so the recognizer
/// callback is the same port [WearableSherpaTranscriber] uses for sherpa-onnx.
Future<String> _sherpaTranscript(Float32List samples) async {
  expect(bindSherpaDualMode().transcribe, isNull);
  expect(samples, hasLength(4));
  expect(samples[0], closeTo(16384 / 32768.0, 1e-6));
  expect(samples[1], closeTo(-8192 / 32768.0, 1e-6));
  expect(samples[2], 0);
  return _voiceTranscript;
}

Future<double> _weight(DatabaseExecutor db, String id) async {
  final rows = await db.query(
    Migration020EntityGraph.relationshipsTable,
    columns: ['weight'],
    where: 'id = ?',
    whereArgs: [id],
  );
  final weight = rows.single['weight'];
  if (weight is! num) {
    throw StateError('Missing relationship weight for $id');
  }
  return weight.toDouble();
}

Uint8List _wavPcm16(Int16List samples, {int sampleRate = 16000}) {
  final pcm = ByteData(samples.length * 2);
  for (var index = 0; index < samples.length; index++) {
    pcm.setInt16(index * 2, samples[index], Endian.little);
  }
  final data = pcm.buffer.asUint8List();
  final header = ByteData(44);
  void writeAscii(int offset, String text) {
    for (var index = 0; index < text.length; index++) {
      header.setUint8(offset + index, text.codeUnitAt(index));
    }
  }

  writeAscii(0, 'RIFF');
  header.setUint32(4, 36 + data.length, Endian.little);
  writeAscii(8, 'WAVE');
  writeAscii(12, 'fmt ');
  header.setUint32(16, 16, Endian.little);
  header.setUint16(20, 1, Endian.little);
  header.setUint16(22, 1, Endian.little);
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, sampleRate * 2, Endian.little);
  header.setUint16(32, 2, Endian.little);
  header.setUint16(34, 16, Endian.little);
  writeAscii(36, 'data');
  header.setUint32(40, data.length, Endian.little);
  return Uint8List.fromList([...header.buffer.asUint8List(), ...data]);
}

class _PipelineGeo extends AmbientGeoReader {
  const _PipelineGeo();

  @override
  Future<AmbientGeoFix?> read() async {
    return const AmbientGeoFix(
      latitude: 51.32,
      longitude: -0.2,
      city: 'Banstead',
      locality: 'Banstead',
    );
  }
}

class _PipelineForecast extends AmbientForecastReader {
  const _PipelineForecast();

  @override
  Future<AmbientWeather?> read({
    required double latitude,
    required double longitude,
  }) async {
    return const AmbientWeather(temperatureC: 18, conditionCode: 2);
  }
}

class _PipelineActivity extends AmbientActivityReader {
  const _PipelineActivity();

  @override
  Future<AmbientActivity?> read() async {
    return const AmbientActivity(stepCount: 2400, movementState: 'walking');
  }
}
