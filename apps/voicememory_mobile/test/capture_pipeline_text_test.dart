import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_evidence/archive_evidence_guard.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
void main() {
  test('text capture entry without audio counts as archive evidence', () {
    const transcript =
        'I keep saying I want more balance but I still take on extra work every week.';
    final entry = JournalEntry(
      id: 'text-1',
      createdAt: DateTime(2025, 5, 10),
      transcript: transcript,
      durationSeconds: 12,
      reflection: const Reflection(
        mood: 'thoughtful',
        emotionalIntensity: 2,
        recurringThemes: ['work'],
        exactLanguagePattern: 'balance',
        concreteObservation: 'Tension between intent and behavior.',
        repeatedSignal: 'overcommitment',
      ),
      syncStatus: SyncStatus.pendingUpload,
    );

    expect(entry.localAudioPath, isNull);
    expect(
      ArchiveEvidenceGuard.eligibleReflectionCount([entry]),
      1,
    );
  });

  test('short typed capture is stored but not archive evidence', () {
    final entry = JournalEntry(
      id: 'text-short',
      createdAt: DateTime(2025, 5, 11),
      transcript: 'too short',
      durationSeconds: 1,
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
    expect(entry.localAudioPath, isNull);
    expect(ArchiveEvidenceGuard.eligibleReflectionCount([entry]), 0);
  });
}
