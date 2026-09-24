import 'dart:io';

import 'package:archiveme_mobile/features/capture_flow/recording_feedback.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/models/transcript_provenance.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pause and resume freeze the recording timer', () {
    var now = DateTime(2026, 9, 24, 12);
    final clock = RecordingElapsedClock(now: () => now);
    clock.start();
    now = now.add(const Duration(seconds: 4));
    clock.pause();
    now = now.add(const Duration(seconds: 9));
    expect(clock.elapsed, const Duration(seconds: 4));
    clock.resume();
    now = now.add(const Duration(seconds: 3));
    expect(clock.elapsed, const Duration(seconds: 7));
    clock.pause();
    expect(clock.elapsed, const Duration(seconds: 7));
  });

  test('downsampled amplitude series is stored with the recording', () async {
    final series = RecordingAmplitudeSeries();
    final start = DateTime(2026, 9, 24, 12);
    series.addDb(-10, at: start);
    series.addDb(-8, at: start.add(const Duration(milliseconds: 60)));
    series.addDb(-6, at: start.add(const Duration(milliseconds: 100)));
    series.addDb(-4, at: start.add(const Duration(milliseconds: 160)));
    series.addDb(-2, at: start.add(const Duration(milliseconds: 200)));
    expect(series.persisted, hasLength(3));
    expect(series.displayBars, hasLength(40));

    final dir = Directory.systemTemp.createTempSync('waveform');
    final audio = File('${dir.path}/take.m4a')..writeAsBytesSync([1, 2, 3]);
    await series.writeBeside(audio);
    final stored = await RecordingAmplitudeSeries.readBeside(audio);
    expect(stored, series.persisted);
    dir.deleteSync(recursive: true);
  });

  test('draft text is never written to JournalEntry.transcript', () {
    const draft = 'partial hello from the live recogniser';
    final entry = JournalEntry(
      id: 'e1',
      createdAt: DateTime(2026, 9, 24),
      transcript: 'the final sentence',
      durationSeconds: 3,
      reflection: Reflection(
        mood: 'neutral',
        emotionalIntensity: 0,
        recurringThemes: const [],
        exactLanguagePattern: '',
        concreteObservation: '',
        repeatedSignal: '',
      ),
      transcriptProvenance: TranscriptProvenance.unknownLegacy,
    );
    final saved = RecordingDraftPolicy.entryKeepingPipelineTranscript(
      entry: entry,
      draft: draft,
    );
    expect(saved.transcript, 'the final sentence');
    expect(saved.transcript, isNot(draft));
    expect(saved.transcriptProvenance, TranscriptProvenance.unknownLegacy);
    expect(
      saved.transcriptProvenance,
      isNot(TranscriptProvenance.speechToText),
    );
  });
}
