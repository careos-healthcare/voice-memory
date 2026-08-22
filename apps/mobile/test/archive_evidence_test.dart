import 'package:archiveme_mobile/features/archive_evidence/archive_evidence_guard.dart';
import 'package:archiveme_mobile/features/evidence_contract/evidence_eligibility_policy.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_evidence.dart';
import 'package:archiveme_mobile/features/archive_state_object/archive_state_object.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:flutter_test/flutter_test.dart';

JournalEntry _entry({
  required String id,
  required String transcript,
  String observation = '',
}) {
  return JournalEntry(
    id: id,
    createdAt: DateTime(2025, 5, id.hashCode % 28 + 1),
    transcript: transcript,
    durationSeconds: 20,
    reflection: Reflection(
      mood: 'neutral',
      emotionalIntensity: 2,
      recurringThemes: const [],
      exactLanguagePattern: 'pattern',
      concreteObservation: observation,
      repeatedSignal: 'signal',
    ),
  );
}

void main() {
  test('minimum evidence uses focused-beta policy in V1 mode', () {
    expect(
      archiveMinEvidenceReflections,
      ArchiveEvidenceGuard.minimumEvidenceCount,
    );
    expect(
      ArchiveEvidenceGuard.minimumEvidenceCount,
      EvidenceEligibilityPolicy.possiblePatternMinimum,
    );
  });

  test('short transcripts do not count as evidence', () {
    final entries = List.generate(
      6,
      (i) => _entry(id: '$i', transcript: 'too short'),
    );
    expect(archiveEvidenceReflectionCount(entries), 0);
    expect(archiveHasMinimumEvidence(entries), isFalse);
  });

  test('degraded voice drafts do not count as evidence', () {
    final entries = [
      JournalEntry(
        id: 'v1',
        createdAt: DateTime(2025, 5),
        transcript:
            '[draft] Recording saved locally — transcribe when connected',
        durationSeconds: 20,
        localAudioPath: '/tmp/audio.m4a',
        reflection: const Reflection(
          mood: 'neutral',
          emotionalIntensity: 2,
          recurringThemes: [],
          exactLanguagePattern: 'pattern',
          concreteObservation: '',
          repeatedSignal: 'signal',
        ),
      ),
    ];
    expect(archiveEvidenceReflectionCount(entries), 0);
    expect(archiveHasMinimumEvidence(entries), isFalse);
  });

  test('belief and summary come from reflections when threshold met', () {
    final entries = List.generate(
      5,
      (i) => _entry(
        id: '$i',
        transcript: 'This is a long enough transcript about work stress $i.',
        observation: i == 4
            ? 'I keep avoiding hard conversations at work.'
            : '',
      ),
    );
    final state = buildArchiveStateObjectV3(entries: entries);
    expect(state!.hasMinimumEvidence, isTrue);
    expect(state.belief, contains('hard conversations'));
    expect(state.evidenceSummary, contains('5 reflections'));
    expect(state.strongestEvidenceQuote, isNotNull);
  });

  test('state omits fake belief below threshold', () {
    final entries = [
      _entry(
        id: '1',
        transcript: 'This is a long enough transcript for one reflection only.',
      ),
    ];
    final state = buildArchiveStateObjectV3(entries: entries);
    expect(state!.hasMinimumEvidence, isFalse);
    expect(state.belief, isNull);
    expect(state.evidenceSummary, isNull);
  });
}