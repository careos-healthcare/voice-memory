import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_export/complete_archive_export.dart';
import 'package:voicememory_mobile/features/changes/change_thread.dart';
import 'package:voicememory_mobile/features/changes/change_thread_projection.dart';
import 'package:voicememory_mobile/features/explainable_conclusion/change_dimensions.dart';
import 'package:voicememory_mobile/features/explainable_conclusion/explainable_conclusion.dart';
import 'package:voicememory_mobile/features/monetization/domain/access_policy_engine.dart';
import 'package:voicememory_mobile/features/monetization/domain/contextual_paywall_policy.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/security/private_data_service.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';

Reflection _reflection() => const Reflection(
  mood: 'tired',
  emotionalIntensity: 4,
  recurringThemes: ['sleep', 'work'],
  exactLanguagePattern: 'I keep putting it off',
  concreteObservation: 'You described delaying the same task again.',
  repeatedSignal: 'Delay came up twice.',
);

/// A moment with corrections, evidence links, markers, and vault audio.
JournalEntry _richEntry() => JournalEntry(
  id: 'moment-a',
  createdAt: DateTime.utc(2026, 3, 1, 9),
  updatedAt: DateTime.utc(2026, 3, 4, 11),
  transcript: 'I keep putting it off until the evening.',
  durationSeconds: 42,
  reflection: _reflection(),
  source: SavedMomentSource.voice,
  syncStatus: SyncStatus.pendingUpload,
  localAudioVaultRef: 'av1:abc123.enc',
  textEdits: [
    SavedMomentTextEdit(
      editedAt: DateTime.utc(2026, 3, 2, 10),
      source: SavedMomentSource.typed,
      text: 'I keep putting it off until evening.',
    ),
    SavedMomentTextEdit(
      editedAt: DateTime.utc(2026, 3, 4, 11),
      source: SavedMomentSource.typed,
      text: 'I keep putting it off until the evening.',
    ),
  ],
  evidenceOffsets: const [
    SavedMomentEvidenceOffset(
      startUtf16: 2,
      endUtf16: 21,
      audioStartMs: 1200,
      audioEndMs: 4300,
    ),
    SavedMomentEvidenceOffset(startUtf16: 0, endUtf16: 6),
  ],
  isPinned: true,
  pinnedAt: DateTime.utc(2026, 3, 3),
  keepExactDetails: true,
  preserveOriginal: true,
  entryAboutness: 'about_me',
  memorySurfacing: 'normal',
  captureContextTag: 'evening_wind_down',
  archiveThreadId: 'thread-1',
);

/// A voice capture that was never transcribed — audio is all it has.
JournalEntry _audioOnlyEntry() => JournalEntry(
  id: 'moment-audio',
  createdAt: DateTime.utc(2026, 3, 2, 8),
  transcript: '',
  durationSeconds: 17,
  reflection: _reflection(),
  source: SavedMomentSource.voice,
  localAudioVaultRef: 'av1:audio-only.enc',
);

TranscriptEvidenceCitation _citation({
  required String entryId,
  required String quote,
  required int start,
  required int end,
  EvidenceTemporalRole temporalRole = EvidenceTemporalRole.single,
}) => TranscriptEvidenceCitation(
  entryId: entryId,
  quote: quote,
  startUtf16: start,
  endUtf16: end,
  role: TranscriptEvidenceRole.supporting,
  temporalRole: temporalRole,
  sourceCapturedAt: DateTime.utc(2026, 3, 1, 9),
  audioTimestampMs: 1200,
  audioEndTimestampMs: 4300,
  audioVaultReference: 'av1:abc123.enc',
);

ChangeThreadProjection _changes() {
  final events = [
    ChangeEvent(
      eventId: 'event-2',
      threadId: 'thread-1',
      conclusionKind: ExplainableInsightKind.change,
      status: ChangeThreadStatus.weakened,
      changedDimensions: const [
        ChangeDimension.frequency,
        ChangeDimension.emotionalIntensity,
      ],
      exactEvidence: [
        _citation(
          entryId: 'moment-a',
          quote: 'putting it off',
          start: 7,
          end: 21,
          temporalRole: EvidenceTemporalRole.now,
        ),
      ],
      occurredAt: DateTime.utc(2026, 3, 5, 12),
      confidenceBand: EvidenceConfidenceBand.someSupportingEvidence,
      uncertainty: 'Two moments is a short run.',
      alternativeExplanation: 'The week may simply have been quieter.',
      statement: 'The delay showed up less often than before.',
    ),
    ChangeEvent(
      eventId: 'event-1',
      threadId: 'thread-1',
      conclusionKind: ExplainableInsightKind.observation,
      status: ChangeThreadStatus.firstObserved,
      changedDimensions: const [ChangeDimension.frequency],
      exactEvidence: [
        _citation(
          entryId: 'moment-a',
          quote: 'I keep',
          start: 0,
          end: 6,
          temporalRole: EvidenceTemporalRole.then,
        ),
      ],
      occurredAt: DateTime.utc(2026, 3, 1, 12),
      confidenceBand: EvidenceConfidenceBand.earlyObservation,
      uncertainty: 'One moment cannot establish a pattern.',
      alternativeExplanation: 'This may describe only that evening.',
      statement: 'You described delaying the same task.',
    ),
  ];
  return ChangeThreadProjection(
    threads: [
      ChangeThreadView(
        thread: ChangeThread(
          threadId: 'thread-1',
          archiveId: 'local',
          userEditableLabel: 'Putting the evening task off',
          subjectRepresentation: const {'task', 'evening'},
          firstObservedAt: DateTime.utc(2026, 3, 1, 12),
          latestObservedAt: DateTime.utc(2026, 3, 5, 12),
          currentStatus: ChangeThreadStatus.weakened,
          evidenceEventIds: const ['event-1', 'event-2'],
          policyVersion: ChangeThreadProjector.policyVersion,
          correctionState: ChangeThreadCorrectionState.renamed,
          labelIsUserConfirmed: true,
        ),
        events: events,
      ),
    ],
    ungroupedEvents: [
      ChangeEvent(
        eventId: 'event-loose',
        threadId: '',
        conclusionKind: ExplainableInsightKind.observation,
        status: ChangeThreadStatus.unresolved,
        changedDimensions: const [],
        exactEvidence: [
          _citation(
            entryId: 'moment-a',
            quote: 'the evening',
            start: 28,
            end: 39,
          ),
        ],
        occurredAt: DateTime.utc(2026, 3, 6, 12),
        confidenceBand: EvidenceConfidenceBand.earlyObservation,
        uncertainty: 'Not confidently placed on any thread.',
        alternativeExplanation: 'It may belong to something not yet recorded.',
        statement: 'A finding ArchiveMe could not place.',
      ),
    ],
    policyVersion: ChangeThreadProjector.policyVersion,
  );
}

Map<String, Object?> _momentById(Map<String, Object?> parsed, String id) =>
    (parsed['savedMoments'] as List).cast<Map<String, Object?>>().firstWhere(
      (moment) => moment['id'] == id,
    );

void main() {
  group('complete export round trip', () {
    late ArchiveExportBundle bundle;
    late Map<String, Object?> parsed;

    setUp(() {
      bundle = CompleteArchiveExportBuilder.build(
        archiveId: 'local',
        entries: [_richEntry(), _audioOnlyEntry()],
        changes: _changes(),
      );
      parsed = jsonDecode(bundle.machineReadableJson) as Map<String, Object?>;
    });

    test('parses back to every original moment field', () {
      final moment = _momentById(parsed, 'moment-a');
      final original = _richEntry();

      expect(moment['id'], 'moment-a');
      expect(moment['ownerArchiveId'], 'local');
      expect(moment['source'], 'voice');
      expect(moment['state'], 'active');
      expect(moment['syncStatus'], 'pendingUpload');

      final timestamps = moment['timestamps'] as Map<String, Object?>;
      expect(
        DateTime.parse(timestamps['createdAt'] as String),
        original.createdAt,
      );
      expect(
        DateTime.parse(timestamps['updatedAt'] as String),
        original.updatedAt,
      );
      expect(
        DateTime.parse(timestamps['pinnedAt'] as String),
        original.pinnedAt,
      );
      expect(timestamps['deletedAt'], isNull);

      final text = moment['text'] as Map<String, Object?>;
      expect(text['transcript'], original.transcript);
      expect(text['durationSeconds'], original.durationSeconds);
      expect(text['earliestRetainedText'], original.textEdits.first.text);
    });

    test('recovers every correction in stable order', () {
      final corrections =
          (_momentById(parsed, 'moment-a')['corrections'] as List)
              .cast<Map<String, Object?>>();

      expect(corrections, hasLength(2));
      expect(corrections.first['text'], 'I keep putting it off until evening.');
      expect(corrections.first['source'], 'typed');
      expect(
        DateTime.parse(corrections.first['editedAt'] as String),
        DateTime.utc(2026, 3, 2, 10),
      );
      expect(
        corrections.last['text'],
        'I keep putting it off until the evening.',
      );
    });

    test('recovers evidence links with the text they point at', () {
      final links = (_momentById(parsed, 'moment-a')['evidenceLinks'] as List)
          .cast<Map<String, Object?>>();

      expect(links, hasLength(2));
      expect(links.first['startUtf16'], 0);
      expect(links.first['endUtf16'], 6);
      expect(links.first['quotedText'], 'I keep');
      expect(links.last['startUtf16'], 2);
      expect(links.last['audioStartMs'], 1200);
      expect(links.last['audioEndMs'], 4300);
      expect(links.last['quotedText'], 'keep putting it off');
    });

    test('recovers structured markers', () {
      final markers =
          _momentById(parsed, 'moment-a')['markers'] as Map<String, Object?>;

      expect(markers['isPinned'], isTrue);
      expect(markers['keepExactDetails'], isTrue);
      expect(markers['preserveOriginal'], isTrue);
      expect(markers['isDeleted'], isFalse);
      expect(markers['entryAboutness'], 'about_me');
      expect(markers['memorySurfacing'], 'normal');
      expect(markers['captureContextTag'], 'evening_wind_down');
      expect(markers['archiveThreadId'], 'thread-1');
      expect(markers['recurringThemes'], ['sleep', 'work']);
    });

    test('recovers the interpretation that can be corrected or hidden', () {
      final interpretation =
          _momentById(parsed, 'moment-a')['interpretation']
              as Map<String, Object?>;

      expect(interpretation['mood'], 'tired');
      expect(interpretation['emotionalIntensity'], 4);
      expect(
        interpretation['concreteObservation'],
        'You described delaying the same task again.',
      );
      expect(interpretation['exactLanguagePattern'], 'I keep putting it off');
    });

    test('recovers the Changes history from the thread projection', () {
      final changes = parsed['changes'] as Map<String, Object?>;
      expect(changes['policyVersion'], ChangeThreadProjector.policyVersion);

      final threads = (changes['threads'] as List).cast<Map<String, Object?>>();
      expect(threads, hasLength(1));
      final thread = threads.single;
      expect(thread['threadId'], 'thread-1');
      expect(thread['label'], 'Putting the evening task off');
      expect(thread['correctionState'], 'renamed');
      expect(thread['subjectRepresentation'], ['evening', 'task']);
      expect(
        DateTime.parse(thread['firstObservedAt'] as String),
        DateTime.utc(2026, 3, 1, 12),
      );

      final events = (thread['events'] as List).cast<Map<String, Object?>>();
      expect(events.map((event) => event['eventId']), ['event-1', 'event-2']);
      expect(
        events.last['statement'],
        'The delay showed up less often than before.',
      );
      expect(events.last['changedDimensions'], [
        'emotionalIntensity',
        'frequency',
      ]);
      expect(events.last['confidenceBand'], 'someSupportingEvidence');
      expect(
        events.last['alternativeExplanation'],
        'The week may simply have been quieter.',
      );

      final evidence = (events.first['evidence'] as List)
          .cast<Map<String, Object?>>();
      expect(evidence.single['entryId'], 'moment-a');
      expect(evidence.single['quote'], 'I keep');
      expect(evidence.single['audioReference'], 'av1:abc123.enc');

      final unplaced = (changes['unplacedEvents'] as List)
          .cast<Map<String, Object?>>();
      expect(unplaced.single['eventId'], 'event-loose');
    });

    test('readable document carries the same recoverable content', () {
      final document = bundle.readableDocument;

      expect(document, startsWith('# ArchiveMe archive export'));
      expect(document, contains('Your recordings stay yours.'));
      expect(document, contains('2026-03-01T09:00:00.000Z'));
      expect(document, contains('I keep putting it off until the evening.'));
      expect(document, contains('I keep putting it off until evening.'));
      expect(document, contains('av1:abc123.enc'));
      expect(document, contains('Putting the evening task off'));
      expect(document, contains('The delay showed up less often than before.'));
      expect(document, contains('Evidence from moment-a'));
      expect(document, contains('Moment fields:'));
    });

    test('manifest counts what the export actually contains', () {
      final manifest = bundle.manifest;
      expect(manifest.entryCount, 2);
      expect(manifest.activeEntryCount, 2);
      expect(manifest.deletedEntryCount, 0);
      expect(manifest.correctionCount, 2);
      expect(manifest.evidenceLinkCount, 2);
      expect(manifest.audioReferenceCount, 2);
      expect(manifest.changeThreadCount, 1);
      expect(manifest.changeEventCount, 2);
      expect(manifest.unplacedChangeEventCount, 1);
      expect(
        ArchiveExportManifest.entryFields,
        contains('corrections[].editedAt'),
      );
      expect(
        ArchiveExportManifest.changeFields,
        contains('threads[].events[].evidence[].quote'),
      );
    });
  });

  group('determinism', () {
    test('two runs on identical state are byte-identical', () {
      final first = CompleteArchiveExportBuilder.build(
        archiveId: 'local',
        entries: [_richEntry(), _audioOnlyEntry()],
        changes: _changes(),
      );
      final second = CompleteArchiveExportBuilder.build(
        archiveId: 'local',
        entries: [_richEntry(), _audioOnlyEntry()],
        changes: _changes(),
      );

      expect(second.machineReadableJson, first.machineReadableJson);
      expect(second.readableDocument, first.readableDocument);
      expect(
        utf8.encode(second.machineReadableJson),
        utf8.encode(first.machineReadableJson),
      );
    });

    test('input order does not change the output bytes', () {
      final forwards = CompleteArchiveExportBuilder.build(
        archiveId: 'local',
        entries: [_richEntry(), _audioOnlyEntry()],
        changes: _changes(),
      );
      final backwards = CompleteArchiveExportBuilder.build(
        archiveId: 'local',
        entries: [_audioOnlyEntry(), _richEntry()],
        changes: _changes(),
      );

      expect(backwards.machineReadableJson, forwards.machineReadableJson);
      expect(backwards.readableDocument, forwards.readableDocument);
    });

    test('no generation timestamp is embedded in either document', () {
      final bundle = CompleteArchiveExportBuilder.build(
        archiveId: 'local',
        entries: [_richEntry()],
      );
      final thisYear = DateTime.now().toUtc().year.toString();

      // Only archive-derived 2026 timestamps may appear; a clock reading of
      // "now" would betray itself as a different year in later test runs.
      expect(bundle.machineReadableJson, isNot(contains('exportedAt')));
      expect(bundle.machineReadableJson, isNot(contains('generatedAt')));
      if (thisYear != '2026') {
        expect(bundle.machineReadableJson, isNot(contains(thisYear)));
        expect(bundle.readableDocument, isNot(contains(thisYear)));
      }
    });
  });

  group('audio references', () {
    test('an audio-only moment still exports an audio reference', () {
      final bundle = CompleteArchiveExportBuilder.build(
        archiveId: 'local',
        entries: [_audioOnlyEntry()],
      );
      final parsed =
          jsonDecode(bundle.machineReadableJson) as Map<String, Object?>;
      final audio =
          _momentById(parsed, 'moment-audio')['audio'] as Map<String, Object?>;

      expect(audio['referenceKind'], 'vault');
      expect(audio['reference'], 'av1:audio-only.enc');
      expect(audio['bytesIncluded'], isFalse);
      expect(
        (_momentById(parsed, 'moment-audio')['text']
            as Map<String, Object?>)['transcript'],
        '',
      );
      expect(bundle.readableDocument, contains('av1:audio-only.enc'));
      expect(bundle.readableDocument, contains('(no text)'));
      expect(bundle.manifest.audioReferenceCount, 1);
    });

    test('a legacy plaintext capture exports its file name only', () {
      final bundle = CompleteArchiveExportBuilder.build(
        archiveId: 'local',
        entries: [
          JournalEntry(
            id: 'moment-legacy',
            createdAt: DateTime.utc(2026, 1, 1),
            transcript: 'Legacy capture',
            durationSeconds: 3,
            reflection: _reflection(),
            localAudioPath: '/var/mobile/tmp/vm_rec_9182.m4a',
          ),
        ],
      );
      final parsed =
          jsonDecode(bundle.machineReadableJson) as Map<String, Object?>;
      final audio =
          _momentById(parsed, 'moment-legacy')['audio'] as Map<String, Object?>;

      expect(audio['referenceKind'], 'localFile');
      expect(audio['reference'], 'vm_rec_9182.m4a');
      expect(bundle.machineReadableJson, isNot(contains('/var/mobile/tmp')));
    });

    test('a typed moment reports no recording rather than a null path', () {
      final bundle = CompleteArchiveExportBuilder.build(
        archiveId: 'local',
        entries: [
          JournalEntry(
            id: 'moment-typed',
            createdAt: DateTime.utc(2026, 1, 2),
            transcript: 'Typed only',
            durationSeconds: 0,
            reflection: _reflection(),
            source: SavedMomentSource.typed,
          ),
        ],
      );
      final parsed =
          jsonDecode(bundle.machineReadableJson) as Map<String, Object?>;
      final audio =
          _momentById(parsed, 'moment-typed')['audio'] as Map<String, Object?>;

      expect(audio['referenceKind'], 'none');
      expect(audio['reference'], isNull);
      expect(bundle.readableDocument, contains('no recording retained'));
    });
  });

  group('deleted moments', () {
    test('a tombstone is exported explicitly, not silently dropped', () {
      final deleted = JournalEntry(
        id: 'moment-deleted',
        createdAt: DateTime.utc(2026, 2, 1),
        transcript: 'This one was deleted',
        durationSeconds: 5,
        reflection: _reflection(),
        deletedAt: DateTime.utc(2026, 2, 9, 15),
      );
      final bundle = CompleteArchiveExportBuilder.build(
        archiveId: 'local',
        entries: [deleted, _richEntry()],
      );
      final parsed =
          jsonDecode(bundle.machineReadableJson) as Map<String, Object?>;
      final moment = _momentById(parsed, 'moment-deleted');

      expect(moment['state'], 'deleted');
      expect(
        DateTime.parse(
          (moment['timestamps'] as Map<String, Object?>)['deletedAt'] as String,
        ),
        DateTime.utc(2026, 2, 9, 15),
      );
      expect((moment['markers'] as Map<String, Object?>)['isDeleted'], isTrue);
      expect(bundle.manifest.deletedEntryCount, 1);
      expect(bundle.manifest.activeEntryCount, 1);
      expect(bundle.readableDocument, contains('— deleted'));
      expect(bundle.readableDocument, contains('Deleted at: '));
      expect(
        bundle.machineReadableJson,
        contains(ArchiveExportManifest.tombstoneNote),
        reason: 'the manifest must explain what a tombstone means',
      );
    });

    test(
      'journal tombstones reach the export through the canonical store',
      () async {
        final tempDir = Directory.systemTemp.createTempSync('vm_export_rt_');
        addTearDown(() => tempDir.deleteSync(recursive: true));
        final store = await JournalStore.open(
          '${tempDir.path}/entries.json',
          ownerArchiveId: 'local',
        );
        await store.save(_richEntry());
        await store.save(_audioOnlyEntry());
        await store.delete('moment-audio');

        final bundle = await CompleteArchiveExportBuilder.fromJournalStore(
          store,
        );
        final parsed =
            jsonDecode(bundle.machineReadableJson) as Map<String, Object?>;
        final ids = (parsed['savedMoments'] as List)
            .cast<Map<String, Object?>>()
            .map((moment) => moment['id'])
            .toList();

        expect(ids, ['moment-a', 'moment-audio']);
        expect(_momentById(parsed, 'moment-audio')['state'], 'deleted');
        expect(_momentById(parsed, 'moment-a')['state'], 'active');
        expect(bundle.manifest.deletedEntryCount, 1);
      },
    );

    test('PrivateDataService exposes the same complete export', () async {
      final tempDir = Directory.systemTemp.createTempSync('vm_export_svc_');
      addTearDown(() => tempDir.deleteSync(recursive: true));
      final store = await JournalStore.open(
        '${tempDir.path}/entries.json',
        ownerArchiveId: 'local',
      );
      await store.save(_richEntry());

      final bundle = await PrivateDataService(
        journalStore: store,
      ).buildCompleteExport(changes: _changes());

      expect(bundle.manifest.entryCount, 1);
      expect(bundle.manifest.changeEventCount, 2);
      expect(bundle.machineReadableJson, contains('av1:abc123.enc'));
      expect(bundle.readableDocument, contains('Putting the evening task off'));
    });
  });

  group('no hidden Pro requirement', () {
    test('export stays user-owned for a free account', () {
      const free = EntitlementSnapshot.free();
      expect(free.hasProAccess, isFalse);

      final decision = AccessPolicyEngine.decide(
        capability: CapabilityId.exportOriginalContent,
        entitlement: free,
      );

      expect(decision.allowed, isTrue);
      expect(decision.reason, AccessDecisionReason.userOwned);
      expect(
        MonetizationPolicy.capability(
          CapabilityId.exportOriginalContent,
        ).accessClass,
        AccessClass.userOwned,
      );
      expect(
        ContextualPaywallPolicy.mayPaywall(CapabilityId.exportOriginalContent),
        isFalse,
      );
      expect(
        ContextualPaywallPolicy.neverPaywalled,
        contains(CapabilityId.exportOriginalContent),
      );
    });

    test('a free account exports the complete archive, not a preview', () {
      final bundle = CompleteArchiveExportBuilder.build(
        archiveId: 'local',
        entries: [_richEntry(), _audioOnlyEntry()],
        changes: _changes(),
      );

      // Nothing in the builder can consult an entitlement: there is no
      // parameter for one, and every moment and thread is serialised.
      expect(bundle.manifest.entryCount, 2);
      expect(bundle.manifest.changeEventCount, 2);
      expect(bundle.manifest.correctionCount, 2);
      expect(
        bundle.machineReadableJson,
        contains(ArchiveExportManifest.accessNote),
      );
      expect(
        bundle.readableDocument,
        contains('No subscription is required for any part of this export.'),
      );
      expect(
        bundle.machineReadableJson.toLowerCase(),
        isNot(contains('locked')),
      );
      expect(
        bundle.machineReadableJson.toLowerCase(),
        isNot(contains('upgrade')),
      );
    });
  });
}
