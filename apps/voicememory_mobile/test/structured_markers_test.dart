import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/explainable_conclusion/change_dimensions.dart';
import 'package:voicememory_mobile/features/explainable_conclusion/explainable_conclusion.dart';
import 'package:voicememory_mobile/features/explainable_conclusion/explainable_conclusion_validator.dart';
import 'package:voicememory_mobile/features/structured_markers/structured_marker_comparison.dart';
import 'package:voicememory_mobile/features/structured_markers/structured_marker_store.dart';
import 'package:voicememory_mobile/features/structured_markers/structured_markers.dart';
import 'package:voicememory_mobile/services/product_analytics.dart';
import 'package:voicememory_mobile/storage/private_data_encryption_key_store.dart';

/// The ten-second check is optional, secondary and correctable. It may add a
/// comparison the reader's words could not make; it may never overrule them.
void main() {
  setUp(ProductAnalytics.resetForTest);

  group('optional by construction', () {
    test('a moment with no markers compares exactly as its words do', () {
      const before = 'I checked the report twice before the meeting.';
      const after = 'I checked the report once before the meeting.';

      final withoutMarkers = StructuredMarkerComparison.compare(
        before: before,
        after: after,
      );
      final wordsOnly = ChangeDimensionReader.compare(
        before: before,
        after: after,
      );

      expect(
        withoutMarkers.movements.map((movement) => movement.summary),
        wordsOnly.movements.map((movement) => movement.summary),
      );
    });

    test('an untouched check stores nothing at all', () async {
      final store = _store('archive-1');

      await store.save(const StructuredMarkers(entryId: 'entry-1'));

      expect(const StructuredMarkers(entryId: 'entry-1').isEmpty, isTrue);
      expect(await store.forArchive(), isEmpty);
    });

    test('"Other" records that an answer was given, not what it was', () {
      expect(
        StructuredMarkerComparison.observe(
          const StructuredMarkers(
            entryId: 'entry-1',
            action: MarkerAction.other,
          ),
        ),
        isEmpty,
      );
      expect(
        StructuredMarkerComparison.observe(
          const StructuredMarkers(
            entryId: 'entry-1',
            action: MarkerAction.avoided,
          ),
        ).keys,
        [ChangeDimension.behaviouralResponse],
      );
    });
  });

  group('markers as additional evidence', () {
    test('they add an ending the words never mention', () {
      const before = 'I checked the report twice before the meeting.';
      const after = 'I checked the report again before the meeting.';

      expect(
        ChangeDimensionReader.compare(
          before: before,
          after: after,
        ).movements.map((movement) => movement.dimension),
        isNot(contains(ChangeDimension.outcome)),
      );

      final withMarkers = StructuredMarkerComparison.compare(
        before: before,
        after: after,
        beforeMarkers: const StructuredMarkers(
          entryId: 'entry-then',
          resolution: MarkerResolution.unresolved,
        ),
        afterMarkers: const StructuredMarkers(
          entryId: 'entry-now',
          resolution: MarkerResolution.resolved,
        ),
      );
      final outcome = withMarkers.changed.singleWhere(
        (movement) => movement.dimension == ChangeDimension.outcome,
      );

      expect(outcome.direction, DimensionDirection.increased);
      expect(withMarkers.supportsChange, isTrue);
    });

    test('they can show a repeat the words leave unstated', () {
      final repeat = StructuredMarkerComparison.compare(
        before: 'I checked the report before the meeting.',
        after: 'I checked the report before the meeting again.',
        beforeMarkers: const StructuredMarkers(
          entryId: 'entry-then',
          action: MarkerAction.avoided,
        ),
        afterMarkers: const StructuredMarkers(
          entryId: 'entry-now',
          action: MarkerAction.avoided,
        ),
      );
      final response = repeat.movements.singleWhere(
        (movement) => movement.dimension == ChangeDimension.behaviouralResponse,
      );

      expect(response.direction, DimensionDirection.unchanged);
      expect(repeat.supportsRepeat, isTrue);
    });

    test(
      'one-sided markers add nothing, because one side is not a comparison',
      () {
        final oneSided = StructuredMarkerComparison.compare(
          before: 'I checked the report twice before the meeting.',
          after: 'I checked the report again before the meeting.',
          afterMarkers: const StructuredMarkers(
            entryId: 'entry-now',
            resolution: MarkerResolution.resolved,
          ),
        );

        expect(
          oneSided.movements.map((movement) => movement.dimension),
          isNot(contains(ChangeDimension.outcome)),
        );
      },
    );
  });

  group('the words stay authoritative', () {
    test('a marker pointing the other way does not win', () {
      const before = 'I felt slightly worried about the deadline.';
      const after = 'I felt very worried about the deadline.';

      final fromWords =
          ChangeDimensionReader.compare(
            before: before,
            after: after,
          ).movements.singleWhere(
            (movement) =>
                movement.dimension == ChangeDimension.emotionalIntensity,
          );
      expect(fromWords.direction, DimensionDirection.increased);

      final contradicted = StructuredMarkerComparison.compare(
        before: before,
        after: after,
        beforeMarkers: const StructuredMarkers(
          entryId: 'entry-then',
          strength: MarkerStrength.high,
        ),
        afterMarkers: const StructuredMarkers(
          entryId: 'entry-now',
          strength: MarkerStrength.low,
        ),
      );
      final intensity = contradicted.movements.singleWhere(
        (movement) => movement.dimension == ChangeDimension.emotionalIntensity,
      );

      expect(
        intensity.direction,
        DimensionDirection.increased,
        reason: 'the saved words decide where the saved words speak',
      );
      expect(intensity.before.markers, contains('slightly'));
      expect(intensity.after.markers, contains('very'));
    });

    test('a marker cannot overrule words on one side only', () {
      // "very" appears on one side, so the dimension belongs to the words even
      // though they cannot compare it. A marker pair must not fill the gap.
      final mixed = StructuredMarkerComparison.compare(
        before: 'I checked the report before the meeting.',
        after: 'I felt very tense before the meeting.',
        beforeMarkers: const StructuredMarkers(
          entryId: 'entry-then',
          strength: MarkerStrength.low,
        ),
        afterMarkers: const StructuredMarkers(
          entryId: 'entry-now',
          strength: MarkerStrength.low,
        ),
      );

      expect(
        mixed.movements.map((movement) => movement.dimension),
        isNot(contains(ChangeDimension.emotionalIntensity)),
      );
    });

    test('removed markers no longer reach a conclusion', () async {
      final store = _store('archive-1');
      await store.save(
        const StructuredMarkers(
          entryId: 'entry-then',
          resolution: MarkerResolution.unresolved,
        ),
      );
      await store.save(
        const StructuredMarkers(
          entryId: 'entry-now',
          resolution: MarkerResolution.resolved,
        ),
      );

      final conclusion = _checkingChange();
      final withMarkers = StructuredMarkerComparison.forConclusion(
        conclusion,
        markers: await store.forArchive(),
      );
      expect(
        withMarkers.changed.map((movement) => movement.dimension),
        contains(ChangeDimension.outcome),
      );

      await store.remove('entry-now');
      final afterRemoval = StructuredMarkerComparison.forConclusion(
        conclusion,
        markers: await store.forArchive(),
      );

      expect(
        afterRemoval.movements.map((movement) => movement.dimension),
        isNot(contains(ChangeDimension.outcome)),
      );
    });

    test('one moment plus markers is still not a comparison', () {
      expect(
        StructuredMarkerComparison.forConclusion(
          _singleMomentObservation(),
          markers: const {
            'entry-now': StructuredMarkers(
              entryId: 'entry-now',
              resolution: MarkerResolution.resolved,
            ),
          },
        ).movements,
        isEmpty,
      );
    });
  });

  group('archive-scoped storage', () {
    test(
      'forArchive returns this archive\'s markers keyed by entry id',
      () async {
        final store = _store('archive-1');
        final markers = StructuredMarkers(
          entryId: 'entry-1',
          strength: MarkerStrength.medium,
          action: MarkerAction.askedForHelp,
          resolution: MarkerResolution.partlyResolved,
          updatedAt: DateTime.utc(2026, 7, 31),
        );

        await store.save(markers);
        final byEntryId = await store.forArchive();

        expect(byEntryId.keys, ['entry-1']);
        expect(byEntryId['entry-1']!.strength, MarkerStrength.medium);
        expect(byEntryId['entry-1']!.action, MarkerAction.askedForHelp);
        expect(
          byEntryId['entry-1']!.resolution,
          MarkerResolution.partlyResolved,
        );
        expect(await store.read('entry-1'), isNotNull);
        expect(await store.read('entry-2'), isNull);
      },
    );

    test('another archive in the same file is never returned', () async {
      final file = _tempFile();
      final keyStore = InMemoryPrivateDataEncryptionKeyStore();
      final mine = StructuredMarkerStore(
        file: file,
        keyStore: keyStore,
        archiveId: 'archive-1',
      );
      final theirs = StructuredMarkerStore(
        file: file,
        keyStore: keyStore,
        archiveId: 'archive-2',
      );

      await mine.save(
        const StructuredMarkers(
          entryId: 'entry-mine',
          strength: MarkerStrength.low,
        ),
      );
      await theirs.save(
        const StructuredMarkers(
          entryId: 'entry-theirs',
          strength: MarkerStrength.high,
        ),
      );

      expect((await mine.forArchive()).keys, ['entry-mine']);
      expect((await theirs.forArchive()).keys, ['entry-theirs']);
    });

    test('markers are stored encrypted, not as readable labels', () async {
      final file = _tempFile();
      final store = StructuredMarkerStore(
        file: file,
        keyStore: InMemoryPrivateDataEncryptionKeyStore(),
        archiveId: 'archive-1',
      );

      await store.save(
        const StructuredMarkers(
          entryId: 'entry-1',
          resolution: MarkerResolution.unresolved,
        ),
      );

      final raw = await file.readAsString();
      expect(raw, isNot(contains('unresolved')));
      expect(raw, isNot(contains('entry-1')));
    });

    test('clearing an archive removes every marker', () async {
      final store = _store('archive-1');
      await store.save(
        const StructuredMarkers(
          entryId: 'entry-1',
          strength: MarkerStrength.high,
        ),
      );

      await store.clear();

      expect(await store.forArchive(), isEmpty);
    });

    test('markers survive a round trip through the wire format', () {
      final markers = StructuredMarkers(
        entryId: 'entry-1',
        strength: MarkerStrength.high,
        action: MarkerAction.stopped,
        resolution: MarkerResolution.resolved,
        updatedAt: DateTime.utc(2026, 7, 31, 9),
      );

      final restored = StructuredMarkers.fromJson(markers.toJson());

      expect(restored!.entryId, 'entry-1');
      expect(restored.strength, MarkerStrength.high);
      expect(restored.action, MarkerAction.stopped);
      expect(restored.resolution, MarkerResolution.resolved);
      expect(restored.updatedAt, DateTime.utc(2026, 7, 31, 9));
      expect(StructuredMarkers.fromJson(const {'entryId': ''}), isNull);
    });

    test('nothing about a marker is reported to analytics', () async {
      final store = _store('archive-1');

      await store.save(
        const StructuredMarkers(
          entryId: 'entry-1',
          strength: MarkerStrength.high,
          resolution: MarkerResolution.unresolved,
        ),
      );
      await store.remove('entry-1');

      expect(ProductAnalytics.eventsForTest, isEmpty);
      expect(ProductAnalytics.queuedEventCountForTest, 0);
    });
  });
}

StructuredMarkerStore _store(String archiveId) => StructuredMarkerStore(
  file: _tempFile(),
  keyStore: InMemoryPrivateDataEncryptionKeyStore(),
  archiveId: archiveId,
);

File _tempFile() {
  final directory = Directory.systemTemp.createTempSync('structured_markers');
  addTearDown(() {
    if (directory.existsSync()) directory.deleteSync(recursive: true);
  });
  return File('${directory.path}/${StructuredMarkerStore.fileName}');
}

const _thenTranscript = 'I checked the report twice before the meeting.';
const _nowTranscript = 'I checked the report again before the meeting.';

ValidatedExplainableConclusion _checkingChange() => _gate(
  ExplainableConclusion(
    id: 'change-checking',
    statement:
        'You checked the report again before the meeting, where the same '
        'report once took two checks.',
    confidence: 80,
    reasoning: const [
      'The earlier saved words describe two checks of the report.',
      'The later saved words describe checking the report again.',
    ],
    uncertaintyNote: 'Two moments cannot show whether this holds over time.',
    evidence: [
      TranscriptEvidenceCitation(
        entryId: 'entry-then',
        quote: _thenTranscript,
        startUtf16: 0,
        endUtf16: _thenTranscript.length,
        role: TranscriptEvidenceRole.supporting,
        sourceCapturedAt: DateTime(2026, 6, 1, 9),
        sourceType: EvidenceSourceType.voice,
        temporalRole: EvidenceTemporalRole.then,
        confidenceScore: 0.9,
      ),
      TranscriptEvidenceCitation(
        entryId: 'entry-now',
        quote: _nowTranscript,
        startUtf16: 0,
        endUtf16: _nowTranscript.length,
        role: TranscriptEvidenceRole.supporting,
        sourceCapturedAt: DateTime(2026, 7, 31, 10),
        sourceType: EvidenceSourceType.text,
        temporalRole: EvidenceTemporalRole.now,
        confidenceScore: 0.9,
      ),
    ],
    alternatives: const [
      ExplainableAlternative(
        statement: 'The later report may simply have been a smaller one.',
        rationale: 'Neither saved moment says how large the report was.',
      ),
    ],
    provenance: ExplainableConclusionProvenance(
      source: 'test',
      generatedAt: DateTime(2026, 7, 31, 11),
      schemaVersion: ExplainableConclusion.schemaVersion,
    ),
    kind: ExplainableInsightKind.change,
  ),
  const {'entry-then': _thenTranscript, 'entry-now': _nowTranscript},
);

ValidatedExplainableConclusion _singleMomentObservation() => _gate(
  ExplainableConclusion(
    id: 'observation-checking',
    statement: 'You described checking the report twice before the meeting.',
    confidence: 60,
    reasoning: const [
      'The saved words describe two checks before the meeting.',
    ],
    uncertaintyNote: 'One moment cannot show whether this repeats.',
    evidence: [
      TranscriptEvidenceCitation(
        entryId: 'entry-now',
        quote: _thenTranscript,
        startUtf16: 0,
        endUtf16: _thenTranscript.length,
        role: TranscriptEvidenceRole.supporting,
        sourceCapturedAt: DateTime(2026, 7, 31, 10),
        sourceType: EvidenceSourceType.text,
      ),
    ],
    alternatives: const [
      ExplainableAlternative(
        statement: 'This may belong to this moment rather than a habit.',
        rationale: 'Only one saved moment supports it so far.',
      ),
    ],
    provenance: ExplainableConclusionProvenance(
      source: 'test',
      generatedAt: DateTime(2026, 7, 31, 11),
      schemaVersion: ExplainableConclusion.schemaVersion,
    ),
  ),
  const {'entry-now': _thenTranscript},
);

ValidatedExplainableConclusion _gate(
  ExplainableConclusion conclusion,
  Map<String, String> transcripts,
) {
  final gated = ExplainableConclusionRenderGate.visible(
    conclusion,
    canonicalTranscripts: transcripts,
  );
  expect(
    gated,
    isNotNull,
    reason: 'fixture "${conclusion.id}" must survive the render gate',
  );
  return gated!;
}
