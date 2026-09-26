import 'dart:io';

import 'package:archiveme_mobile/features/import/services/shared_media_receiver.dart';
import 'package:archiveme_mobile/features/import/views/import_receipt_view.dart';
import 'package:archiveme_mobile/features/import/views/voice_memo_import_progress.dart';
import 'package:archiveme_mobile/features/import/voice_memo_importer.dart';
import 'package:archiveme_mobile/features/import/voice_memo_queue.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('recording date prefers file metadata over the modification time', () {
    final modified = DateTime.utc(2026, 9, 26, 16);
    expect(
      SharedMediaReceiver.preferRecordingDate(
        metadataIso: '2025-03-12T09:00:00.000Z',
        fileModified: modified,
      ),
      DateTime.utc(2025, 3, 12, 9),
    );
    expect(
      SharedMediaReceiver.preferRecordingDate(
        metadataIso: null,
        fileModified: modified,
      ),
      modified,
    );
    expect(
      SharedMediaReceiver.preferRecordingDate(
        metadataIso: 'not-a-date',
        fileModified: modified,
      ),
      modified,
    );
    expect(
      ImportReceiptView.provenanceLine(DateTime.utc(2025, 3, 12)),
      'Imported from Voice Memos · recorded 12 Mar 2025',
    );
    expect(VoiceMemoTitles.from(name: 'Morning walk.m4a', path: '/tmp/x.m4a'), 'Morning walk');
    expect(
      VoiceMemoTitles.from(
        path: '/tmp/11111111-1111-1111-1111-111111111111.m4a',
      ),
      isNull,
    );
  });

  test('a duplicate file hash is skipped and progress counts every file', () async {
    final dir = await Directory.systemTemp.createTemp('voice_memo_queue_');
    final first = File('${dir.path}/a.m4a')..writeAsBytesSync([1, 2, 3]);
    final copy = File('${dir.path}/b.m4a')..writeAsBytesSync([1, 2, 3]);
    final other = File('${dir.path}/c.wav')..writeAsBytesSync([9]);
    final recorded = DateTime.utc(2025, 3, 12, 9);
    final seen = <String>{};
    final progress = <VoiceMemoImportProgress>[];
    final imported = await VoiceMemoImportQueue.run(
      items: [
        SharedAudioIntake(path: first.path, recordedAt: recorded, name: 'Morning'),
        SharedAudioIntake(path: copy.path, recordedAt: recorded, name: 'Morning'),
        SharedAudioIntake(path: other.path, recordedAt: recorded, name: 'Evening'),
      ],
      seenHashes: seen,
      onProgress: progress.add,
      importOne: (item) async => JournalEntry(
        id: item.path,
        createdAt: item.recordedAt,
        transcript: item.name ?? '',
        durationSeconds: 1,
        reflection: const Reflection(
          mood: '',
          emotionalIntensity: 0,
          recurringThemes: [],
          exactLanguagePattern: '',
          concreteObservation: '',
          repeatedSignal: '',
        ),
      ),
    );
    expect(imported, hasLength(2));
    expect(imported.map((entry) => entry.transcript), ['Morning', 'Evening']);
    expect(progress.map((step) => step.label), [
      'Importing 1 of 3',
      'Importing 2 of 3',
      'Importing 3 of 3',
    ]);
    expect(progress.last.skippedDuplicates, 1);
    expect(seen, hasLength(2));
    await dir.delete(recursive: true);
  });

  test('Android share intents accept audio files and ignore other types', () {
    expect(
      AndroidAudioShare.paths(
        action: AndroidAudioShare.send,
        mime: 'audio/mp4',
        stream: '/inbox/walk.m4a',
      ),
      ['/inbox/walk.m4a'],
    );
    expect(
      AndroidAudioShare.paths(
        action: AndroidAudioShare.sendMultiple,
        mime: 'audio/*',
        streams: ['/a.mp3', '/b.wav', '/c.ogg', '/d.m4a'],
      ),
      ['/a.mp3', '/b.wav', '/c.ogg', '/d.m4a'],
    );
    expect(
      AndroidAudioShare.paths(
        action: AndroidAudioShare.send,
        mime: 'text/plain',
        stream: '/notes.txt',
      ),
      isEmpty,
    );
    expect(
      AndroidAudioShare.paths(
        action: 'android.intent.action.VIEW',
        mime: 'audio/mpeg',
        stream: '/song.mp3',
      ),
      isEmpty,
    );
    expect(VoiceMemoImporter.accepts('clip.ogg'), isTrue);
  });

  testWidgets('queue progress shows how many memos are in the batch', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: VoiceMemoImportProgressView(
          progress: VoiceMemoImportProgress(
            done: 1,
            total: 3,
            skippedDuplicates: 0,
          ),
        ),
      ),
    );
    expect(find.text('Importing 1 of 3'), findsOneWidget);
  });
}