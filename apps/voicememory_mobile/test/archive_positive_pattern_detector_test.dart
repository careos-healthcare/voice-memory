import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_reactivity/archive_positive_pattern_detector.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';

JournalEntry _entry(
  String transcript, {
  String id = 'entry-1',
  DateTime? createdAt,
}) {
  return JournalEntry(
    id: id,
    createdAt: createdAt ?? DateTime.utc(2026, 6, 10, 12),
    transcript: transcript,
    durationSeconds: 42,
    reflection: const Reflection(
      mood: 'neutral',
      emotionalIntensity: 0,
      recurringThemes: [],
      exactLanguagePattern: '',
      concreteObservation: '',
      repeatedSignal: '',
    ),
    syncStatus: SyncStatus.localOnly,
  );
}

void main() {
  group('ArchivePositivePatternDetector', () {
    test('detects pause language', () {
      final signal = ArchivePositivePatternDetector.detectLatest(
        entryId: 'e1',
        transcript: 'I paused before reacting and waited a moment.',
      );
      expect(signal, isNotNull);
      expect(signal!.signalType, ArchivePositivePatternSignalType.pause);
      expect(signal.evidencePhrase.toLowerCase(), contains('paused'));
    });

    test('detects reduced urgency language', () {
      final signal = ArchivePositivePatternDetector.detectLatest(
        entryId: 'e1',
        transcript: 'Today it felt less urgent than yesterday.',
      );
      expect(signal, isNotNull);
      expect(
        signal!.signalType,
        ArchivePositivePatternSignalType.reducedUrgency,
      );
    });

    test('detects stopped sooner language', () {
      final signal = ArchivePositivePatternDetector.detectLatest(
        entryId: 'e1',
        transcript: 'I did not check again after one useful check.',
      );
      expect(signal, isNotNull);
      expect(
        signal!.signalType,
        ArchivePositivePatternSignalType.stoppedSooner,
      );
    });

    test('detects chose different action language', () {
      final signal = ArchivePositivePatternDetector.detectLatest(
        entryId: 'e1',
        transcript: 'I went for a walk instead of checking again.',
      );
      expect(signal, isNotNull);
      expect(
        signal!.signalType,
        ArchivePositivePatternSignalType.choseDifferentAction,
      );
    });

    test('detects completed action language', () {
      final signal = ArchivePositivePatternDetector.detectLatest(
        entryId: 'e1',
        transcript: 'I finished the task and moved on.',
      );
      expect(signal, isNotNull);
      expect(
        signal!.signalType,
        ArchivePositivePatternSignalType.completedAction,
      );
    });

    test('detects asked for support language', () {
      final signal = ArchivePositivePatternDetector.detectLatest(
        entryId: 'e1',
        transcript: 'I asked for help before spiralling into checking.',
      );
      expect(signal, isNotNull);
      expect(
        signal!.signalType,
        ArchivePositivePatternSignalType.askedForSupport,
      );
    });

    test('does not introduce therapy or diagnosis language', () {
      final signal = ArchivePositivePatternDetector.detectLatest(
        entryId: 'e1',
        transcript: 'I waited before checking again.',
      );
      expect(signal, isNotNull);
      final blob = [
        signal!.title,
        signal.nextPrompt,
        signal.evidencePhrase,
        signal.confidenceLabel,
      ].join(' ').toLowerCase();
      expect(blob, isNot(contains('therapy')));
      expect(blob, isNot(contains('diagnosis')));
      expect(blob, isNot(contains('cure')));
    });
  });
}
