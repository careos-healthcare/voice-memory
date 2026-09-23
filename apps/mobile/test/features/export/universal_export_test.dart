import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:archiveme_mobile/core/execution/cancel_token.dart';
import 'package:archiveme_mobile/features/export/universal_export_dialog.dart';
import 'package:archiveme_mobile/features/export/universal_export_models.dart';
import 'package:archiveme_mobile/features/export/universal_export_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late File database;
  late File wav;
  late File mp3;
  late UniversalExportRequest request;
  const service = UniversalExportService();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    root = await Directory.systemTemp.createTemp('archive-export-');
    database = File('${root.path}/source.db');
    await database.writeAsBytes(const [1, 2, 3, 4]);
    wav = File('${root.path}/note.wav');
    await wav.writeAsBytes(List<int>.filled(32, 7));
    mp3 = File('${root.path}/skip.mp3');
    await mp3.writeAsBytes(List<int>.filled(80, 9));
    final output = Directory('${root.path}/out')..createSync();
    request = UniversalExportRequest(
      outputDirectory: output,
      databaseFile: database,
      entries: [
        UniversalExportEntry(
          id: 'moment-1',
          createdAt: DateTime.utc(2026, 9, 23, 10),
          updatedAt: DateTime.utc(2026, 9, 23, 11),
          transcript: 'Anxious about the Monday review.',
          tags: const ['career', 'work'],
          location: 'Banstead',
          audioPath: wav.path,
          metadata: const {'durationSeconds': 12},
        ),
        UniversalExportEntry(
          id: 'moment-2',
          createdAt: DateTime.utc(2026, 9, 22),
          transcript: 'A project milestone.',
          audioPath: mp3.path,
        ),
      ],
    );
  });

  tearDown(() async {
    if (root.existsSync()) await root.delete(recursive: true);
  });

  test('estimate counts markdown, database, and raw recordings only', () async {
    final estimate = await service.estimate(request);
    expect(estimate.entryCount, 2);
    expect(estimate.recordingCount, 1);
    expect(estimate.databaseBytes, 4);
    expect(estimate.audioBytes, 32);
    expect(estimate.totalBytes, greaterThan(4 + 32));
  });

  test('zip contains markdown, archive_me.db, and audio sidecars', () async {
    final zip = await service.export(request);
    final decoded = ZipDecoder().decodeBytes(await zip.readAsBytes());
    final markdown = utf8.decode(decoded.findFile('entries/moment-1.md')!.content);
    expect(markdown, contains('createdAt: "2026-09-23T10:00:00.000Z"'));
    expect(markdown, contains('- "career"'));
    expect(markdown, contains('location: "Banstead"'));
    expect(markdown, contains('durationSeconds: 12'));
    expect(markdown, contains('Anxious about the Monday review.'));
    expect(decoded.findFile('archive_me.db')!.content, [1, 2, 3, 4]);
    expect(decoded.findFile('audio/moment-1.wav')!.content.length, 32);
    final sidecar = jsonDecode(
      utf8.decode(decoded.findFile('audio/moment-1.json')!.content),
    ) as Map<String, dynamic>;
    expect(sidecar['format'], 'wav');
    expect(sidecar['location'], 'Banstead');
    expect(decoded.findFile('audio/moment-2.mp3'), isNull);
  });

  test('cancellation stops before the zip is written', () async {
    final token = ExecutionCancelToken()..cancel();
    await expectLater(
      service.export(request, cancel: token),
      throwsA(isA<ExecutionCancelledException>()),
    );
    expect(File('${request.outputDirectory.path}/archive_me_export.zip').existsSync(), isFalse);
  });

  test('reads tags and location from journal rows', () async {
    final dbPath = '${root.path}/journal.db';
    final db = await databaseFactoryFfi.openDatabase(dbPath);
    await db.execute('''
      CREATE TABLE journal_entries (
        id TEXT PRIMARY KEY,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        deleted_at INTEGER,
        transcript TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        ambient_metadata TEXT
      )
    ''');
    await db.insert('journal_entries', {
      'id': 'row-1',
      'created_at': DateTime.utc(2026, 9).millisecondsSinceEpoch,
      'updated_at': DateTime.utc(2026, 9, 2).millisecondsSinceEpoch,
      'transcript': 'Walked home.',
      'payload_json': jsonEncode({
        'localAudioPath': wav.path,
        'captureContextTag': 'health',
        'tags': ['sleep'],
        'durationSeconds': 8,
      }),
      'ambient_metadata': jsonEncode({
        'location': {'city': 'Banstead', 'locality': 'Surrey'},
      }),
    });
    await db.insert('journal_entries', {
      'id': 'gone',
      'created_at': DateTime.utc(2026, 8).millisecondsSinceEpoch,
      'updated_at': DateTime.utc(2026, 8).millisecondsSinceEpoch,
      'deleted_at': 1,
      'transcript': 'Removed.',
      'payload_json': '{}',
    });

    final entries = await UniversalExportService.readEntries(db);
    await db.close();
    expect(entries, hasLength(1));
    expect(entries.single.tags, ['health', 'sleep']);
    expect(entries.single.location, 'Banstead, Surrey');
    expect(entries.single.audioPath, wav.path);
    expect(entries.single.metadata['durationSeconds'], 8);
  });

  testWidgets('dialog shows the size, then writes the zip', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showUniversalExportDialog(
              context: context,
              entries: request.entries,
              databaseFile: database,
              outputDirectory: request.outputDirectory,
              service: service,
              delivery: UniversalExportDelivery.save,
            ),
            child: const Text('Open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump();

    expect(find.byKey(const Key('universal_export_estimate')), findsOneWidget);
    expect(find.textContaining('before compression'), findsOneWidget);

    await tester.tap(find.byKey(const Key('universal_export_create')));
    await tester.pump();
    await tester.pump();

    expect(
      File('${request.outputDirectory.path}/archive_me_export.zip').existsSync(),
      isTrue,
    );
  });
}
