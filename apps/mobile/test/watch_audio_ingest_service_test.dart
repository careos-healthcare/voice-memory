import 'dart:io';

import 'package:archiveme_mobile/features/watch/watch_audio_capture.dart';
import 'package:archiveme_mobile/features/watch/watch_audio_ingest_service.dart';
import 'package:archiveme_mobile/features/watch/watch_audio_ingest_store.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/services/capture_pipeline_service.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter_test/flutter_test.dart';

JournalEntry _entry() => JournalEntry(
  id: 'watch-entry',
  createdAt: DateTime.utc(2026, 1, 15),
  transcript: 'From watch',
  durationSeconds: 8,
  reflection: const Reflection(
    mood: 'calm',
    emotionalIntensity: 3,
    recurringThemes: [],
    exactLanguagePattern: '',
    concreteObservation: '',
    repeatedSignal: '',
  ),
  captureSource: 'watch',
);

void main() {
  test('WatchAudioIngestService dedupes and emits success events', () async {
    final prefsPath =
        '${Directory.systemTemp.createTempSync('vm_watch_ingest_').path}/prefs.json';
    final prefs = await MobilePrefsStore.open(prefsPath);
    final store = WatchAudioIngestStore(prefs);
    final service = WatchAudioIngestService(store: store);

    var calls = 0;
    service.watchCaptureRunner =
        ({required audioFilePath, durationSeconds}) async {
          calls++;
          return CapturePipelineResult(
            entry: _entry(),
            localSaved: true,
            syncSucceeded: false,
          );
        };

    final capture = WatchAudioCapture(
      path: '/tmp/watch_capture.m4a',
      durationSeconds: 8,
      capturedAt: DateTime.utc(2026, 1, 15),
    );

    final events = <WatchIngestEvent>[];
    final sub = service.events.listen(events.add);

    await service.enqueue(capture);
    await service.enqueue(capture);

    expect(calls, 1);
    expect(events, hasLength(1));
    expect(events.single.kind, WatchIngestEventKind.success);
    expect(await store.isProcessed(capture.ingestKey), isTrue);

    await sub.cancel();
    service.dispose();
  });
}