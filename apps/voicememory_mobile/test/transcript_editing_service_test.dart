import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/explainable_conclusion/explainable_conclusion.dart';
import 'package:voicememory_mobile/features/recording/domain/application/post_save_experience_coordinator.dart';
import 'package:voicememory_mobile/features/recording/domain/application/save_moment_coordinator.dart';
import 'package:voicememory_mobile/features/recording/domain/application/transcript_editing_service.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';

void main() {
  test(
    'editing transcript persists history and invalidates evidence offsets',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'archiveme_transcript_edit_',
      );
      addTearDown(() => directory.delete(recursive: true));
      final store = await JournalStore.open(
        '${directory.path}/journal.json',
        ownerArchiveId: 'local',
        encryptAtRest: false,
      );
      final entry = JournalEntry(
        id: 'moment',
        createdAt: DateTime.utc(2026, 8, 1),
        transcript: 'The original exact words.',
        durationSeconds: 0,
        source: SavedMomentSource.typed,
        localAudioVaultRef: 'vault://moment',
        evidenceOffsets: const [
          SavedMomentEvidenceOffset(startUtf16: 4, endUtf16: 12),
        ],
        reflection: Reflection(
          mood: 'neutral',
          emotionalIntensity: 0,
          recurringThemes: [],
          exactLanguagePattern: '',
          concreteObservation: '',
          repeatedSignal: '',
          explainableConclusion: _observation(
            transcript: 'The original exact words.',
          ),
        ),
      );
      await store.save(entry);

      final updated = await TranscriptEditingService(
        store,
      ).replace(entry: entry, transcript: 'The corrected exact words.');

      expect(updated.transcript, 'The corrected exact words.');
      expect(updated.textEdits, hasLength(1));
      expect(updated.textEdits.single.text, updated.transcript);
      expect(updated.evidenceOffsets, isEmpty);
      expect(updated.localAudioVaultRef, entry.localAudioVaultRef);
      expect((await store.getById(entry.id))?.transcript, updated.transcript);
      final experience = const PostSaveExperienceCoordinator().build(
        SavedMomentResult(
          entry: updated,
          entries: [updated],
          analysisSucceeded: true,
          syncSucceeded: true,
        ),
      );
      expect(experience.conclusion, isNull);
    },
  );
}

ExplainableConclusion _observation({required String transcript}) =>
    ExplainableConclusion(
      id: 'observation',
      statement: 'You described the original exact words.',
      confidence: 60,
      reasoning: const ['The exact saved wording supports this cautious read.'],
      uncertaintyNote: 'This may be specific to this one moment.',
      evidence: [
        TranscriptEvidenceCitation(
          entryId: 'moment',
          quote: transcript,
          startUtf16: 0,
          endUtf16: transcript.length,
          role: TranscriptEvidenceRole.supporting,
          sourceCapturedAt: DateTime.utc(2026, 8, 1),
          sourceType: EvidenceSourceType.voice,
          audioTimestampMs: 0,
          audioVaultReference: 'vault://moment',
        ),
      ],
      alternatives: const [
        ExplainableAlternative(
          statement: 'This may be specific to this moment.',
          rationale: 'One moment cannot establish a repeated response.',
        ),
      ],
      provenance: ExplainableConclusionProvenance(
        source: 'test',
        generatedAt: DateTime.utc(2026, 8, 1, 1),
        schemaVersion: ExplainableConclusion.schemaVersion,
      ),
      kind: ExplainableInsightKind.observation,
    );
