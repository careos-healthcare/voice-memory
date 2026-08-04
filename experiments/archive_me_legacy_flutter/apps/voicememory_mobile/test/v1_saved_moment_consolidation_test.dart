import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/explainable_conclusion/explainable_conclusion.dart';
import 'package:voicememory_mobile/features/explainable_conclusion/explainable_conclusion_validator.dart';
import 'package:voicememory_mobile/features/journal/migration/saved_moment_legacy_adapter.dart';
import 'package:voicememory_mobile/features/journal/sync/saved_moment_sync.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';

void main() {
  const reflection = Reflection(
    mood: 'calm',
    emotionalIntensity: 3,
    recurringThemes: [],
    exactLanguagePattern: 'I paused',
    concreteObservation: 'A pause was recorded.',
    repeatedSignal: '',
  );

  SavedMoment moment(String owner, {DateTime? deletedAt}) => SavedMoment(
    id: 'immutable-entry-id',
    ownerArchiveId: owner,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 2),
    source: SavedMomentSource.typed,
    transcript: 'I paused before answering.',
    textEdits: [
      SavedMomentTextEdit(
        editedAt: DateTime.utc(2026, 1, 2),
        source: SavedMomentSource.typed,
        text: 'I paused before answering.',
      ),
    ],
    evidenceOffsets: const [
      SavedMomentEvidenceOffset(startUtf16: 0, endUtf16: 8),
    ],
    durationSeconds: 0,
    reflection: reflection,
    deletedAt: deletedAt,
  );

  test('legacy adapter migrates one way into the canonical schema', () {
    final migrated = SavedMomentLegacyAdapter.migrate(
      {
        'id': 'legacy-id',
        'createdAt': '2025-01-01T00:00:00.000Z',
        'transcript': 'Legacy words',
        'durationSeconds': 0,
        'reflection': reflection.toJson(),
      },
      ownerArchiveId: 'archive-a',
      migratedAt: DateTime.utc(2026),
    );
    final canonical = SavedMoment.fromJson(migrated);

    expect(canonical.id, 'legacy-id');
    expect(canonical.ownerArchiveId, 'archive-a');
    expect(canonical.schemaVersion, SavedMoment.currentSchemaVersion);
    expect(
      canonical.migrationMetadata?.adapter,
      SavedMomentLegacyAdapter.adapterId,
    );
    expect(canonical.toJson(), isNot(contains('legacyJournalEntry')));
  });

  test('queue, envelopes, and conflicts are account isolated', () async {
    final record = SavedMomentSyncRecord.fromMoment(
      moment('archive-a'),
      revision: 2,
      sourceDeviceId: 'device-a',
    );
    final queue = SavedMomentSyncQueue(ownerArchiveId: 'archive-a')
      ..enqueue(record);
    expect(queue.pending, [record]);
    expect(
      () => queue.enqueue(
        SavedMomentSyncRecord.fromMoment(
          moment('archive-b'),
          revision: 1,
          sourceDeviceId: 'device-b',
        ),
      ),
      throwsStateError,
    );

    final key = List<int>.generate(32, (index) => index);
    final envelope = await const SavedMomentSyncCipher().encrypt(
      record,
      keyBytes: key,
    );
    expect(
      () => const SavedMomentSyncCipher().decrypt(
        envelope,
        expectedOwnerArchiveId: 'archive-b',
        keyBytes: key,
      ),
      throwsStateError,
    );

    final tombstone = SavedMomentSyncRecord.fromMoment(
      moment('archive-a', deletedAt: DateTime.utc(2026, 1, 3)),
      revision: 3,
      sourceDeviceId: 'device-b',
    );
    expect(
      SavedMomentConflictResolver.winner(record, tombstone).mutation,
      SavedMomentSyncMutation.tombstone,
    );
  });

  test('legacy conclusions cannot enter the validated UI type', () {
    expect(
      ExplainableConclusion.fromJson({
        'id': 'legacy',
        'statement': 'Raw legacy interpretation',
        'confidence': 90,
      }),
      isNull,
    );

    final raw = ExplainableConclusion(
      id: 'raw',
      statement: 'A raw legacy interpretation',
      confidence: 60,
      reasoning: const ['Legacy reasoning was not evidence validated.'],
      uncertaintyNote: 'Legacy uncertainty was not source validated.',
      evidence: const [],
      alternatives: const [
        ExplainableAlternative(
          statement: 'Another angle',
          rationale: 'Legacy data cannot prove either interpretation.',
        ),
      ],
      provenance: ExplainableConclusionProvenance(
        source: 'legacy',
        generatedAt: DateTime.utc(2026),
        schemaVersion: 1,
      ),
      isLegacy: true,
    );
    expect(
      ExplainableConclusionRenderGate.visible(
        raw,
        canonicalTranscripts: const {},
      ),
      isNull,
    );
  });
}
