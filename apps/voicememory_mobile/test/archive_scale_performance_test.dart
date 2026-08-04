import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_export/complete_archive_export.dart';
import 'package:voicememory_mobile/features/archive_export/full_archive_export.dart';
import 'package:voicememory_mobile/features/changes/change_thread.dart';
import 'package:voicememory_mobile/features/changes/change_thread_projection.dart';
import 'package:voicememory_mobile/features/explainable_conclusion/explainable_conclusion.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/services/privacy/audio_vault_service.dart';

const _projectionBudget = Duration(seconds: 15);
const _readableExportBudget = Duration(seconds: 15);
const _fullExportBudget = Duration(seconds: 30);

void main() {
  test(
    '1000 entries, 100 Changes threads, and 50 audio references stay bounded',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'archiveme_scale_performance_',
      );
      addTearDown(() async {
        if (await root.exists()) await root.delete(recursive: true);
      });
      final vaultTemp = Directory('${root.path}/vault-temp');
      final vault = AudioVaultService(
        keyStore: InMemoryAudioVaultKeyStore(),
        vaultDirectory: () async => Directory('${root.path}/vault'),
        temporaryDirectory: () async => vaultTemp,
      );

      final entries = <JournalEntry>[];
      final conclusions = <ExplainableConclusion>[];
      for (var thread = 0; thread < 100; thread++) {
        final then = _entry(
          id: 'thread-$thread-then',
          index: thread * 2,
          transcript: 'I answered the topic$thread message immediately.',
        );
        final now = _entry(
          id: 'thread-$thread-now',
          index: thread * 2 + 1,
          transcript: 'I paused before answering the topic$thread message.',
        );
        entries.addAll([then, now]);
        conclusions.add(_change(thread, then, now));
      }
      for (var index = entries.length; index < 1000; index++) {
        entries.add(
          _entry(
            id: 'filler-$index',
            index: index,
            transcript: 'Synthetic saved moment $index for scale coverage.',
          ),
        );
      }

      final projectionWatch = Stopwatch()..start();
      final projected = ChangeThreadProjector.project(
        archiveId: 'scale-archive',
        entries: entries,
        conclusions: conclusions,
      );
      projectionWatch.stop();
      expect(projected.allEvents, hasLength(100));
      expect(projectionWatch.elapsed, lessThan(_projectionBudget));
      final projection = _hundredThreadProjection(conclusions);
      expect(projection.threads, hasLength(100));

      final readableWatch = Stopwatch()..start();
      final readable = CompleteArchiveExportBuilder.build(
        archiveId: 'scale-archive',
        entries: entries,
        changes: projection,
      );
      readableWatch.stop();
      expect(readable.manifest.entryCount, 1000);
      expect(readable.manifest.changeThreadCount, 100);
      expect(readable.machineReadableJson, isNotEmpty);
      expect(readable.readableDocument, isNotEmpty);
      expect(readableWatch.elapsed, lessThan(_readableExportBudget));

      final audioEntries = <JournalEntry>[];
      for (var index = 0; index < 50; index++) {
        final source = File('${root.path}/source-$index.m4a');
        await source.writeAsBytes(
          List<int>.generate(2048, (offset) => (index + offset) % 251),
        );
        final reference = (await vault.sealCapture(
          'audio-$index',
          source,
        )).reference;
        audioEntries.add(
          _entry(
            id: 'audio-$index',
            index: index,
            transcript: 'Synthetic audio moment $index.',
            vaultRef: reference,
          ),
        );
      }

      var maximumLivePlaintextFiles = 0;
      final fullWatch = Stopwatch()..start();
      final result =
          await FullArchiveExportBuilder(
            audioVault: vault,
            temporaryRoot: Directory('${root.path}/export'),
            appVersion: 'scale-test',
            clock: () => DateTime.utc(2026, 8, 4),
            exportIdFactory: () => 'scale-test',
            onItemAdded: (_) {
              final live = vaultTemp.existsSync()
                  ? vaultTemp.listSync().whereType<File>().length
                  : 0;
              if (live > maximumLivePlaintextFiles) {
                maximumLivePlaintextFiles = live;
              }
            },
          ).build(
            readable: readable,
            entries: audioEntries,
            audioExportConfirmed: true,
          );
      fullWatch.stop();
      addTearDown(result.cleanup);

      final items = (result.manifest['items']! as List).cast<Map>();
      expect(
        items.where((item) => item['path'].toString().startsWith('audio/')),
        hasLength(50),
      );
      expect(maximumLivePlaintextFiles, lessThanOrEqualTo(1));
      expect(vaultTemp.listSync(), isEmpty);
      expect(fullWatch.elapsed, lessThan(_fullExportBudget));

      // Keep the locally reproducible measurements visible in test logs.
      // These are host-VM numbers, never physical-device evidence.
      // ignore: avoid_print
      print(
        'SCALE_MEASURED entries=1000 threads=100 audio=50 '
        'projection_ms=${projectionWatch.elapsedMilliseconds} '
        'readable_export_ms=${readableWatch.elapsedMilliseconds} '
        'full_export_ms=${fullWatch.elapsedMilliseconds} '
        'max_live_plaintext=$maximumLivePlaintextFiles',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

JournalEntry _entry({
  required String id,
  required int index,
  required String transcript,
  String? vaultRef,
}) => JournalEntry(
  id: id,
  ownerArchiveId: 'scale-archive',
  createdAt: DateTime.utc(2026, 1, 1).add(Duration(hours: index)),
  source: vaultRef == null ? SavedMomentSource.typed : SavedMomentSource.voice,
  transcript: transcript,
  durationSeconds: vaultRef == null ? 0 : 4,
  localAudioVaultRef: vaultRef,
  reflection: const Reflection(
    mood: 'neutral',
    emotionalIntensity: 1,
    recurringThemes: [],
    exactLanguagePattern: '',
    concreteObservation: '',
    repeatedSignal: '',
  ),
);

ExplainableConclusion _change(
  int index,
  JournalEntry then,
  JournalEntry now,
) => ExplainableConclusion(
  id: 'change-$index',
  kind: ExplainableInsightKind.change,
  statement: 'Your topic$index message response may have changed.',
  confidence: 75,
  reasoning: const ['The exact saved wording supports this narrow claim.'],
  uncertaintyNote: 'Later saved moments may support or challenge this read.',
  evidence: [
    _citation(then, EvidenceTemporalRole.then),
    _citation(now, EvidenceTemporalRole.now),
  ],
  alternatives: const [
    ExplainableAlternative(
      statement: 'The circumstances may explain this wording.',
      rationale: 'More saved moments could support a different explanation.',
    ),
  ],
  provenance: ExplainableConclusionProvenance(
    source: 'synthetic_scale_fixture',
    generatedAt: now.createdAt.add(const Duration(days: 1)),
    schemaVersion: ExplainableConclusion.schemaVersion,
  ),
  theoryId: 'topic_$index',
);

TranscriptEvidenceCitation _citation(
  JournalEntry entry,
  EvidenceTemporalRole temporalRole,
) => TranscriptEvidenceCitation(
  entryId: entry.id,
  quote: entry.transcript,
  startUtf16: 0,
  endUtf16: entry.transcript.length,
  role: TranscriptEvidenceRole.supporting,
  sourceCapturedAt: entry.createdAt,
  sourceType: EvidenceSourceType.text,
  temporalRole: temporalRole,
);

ChangeThreadProjection _hundredThreadProjection(
  List<ExplainableConclusion> conclusions,
) => ChangeThreadProjection(
  policyVersion: ChangeThreadProjector.policyVersion,
  ungroupedEvents: const [],
  threads: [
    for (var index = 0; index < conclusions.length; index++)
      ChangeThreadView(
        thread: ChangeThread(
          threadId: 'scale-thread-$index',
          archiveId: 'scale-archive',
          userEditableLabel: 'Synthetic thread $index',
          subjectRepresentation: {'synthetic-$index'},
          firstObservedAt: conclusions[index].evidence.first.sourceCapturedAt!,
          latestObservedAt: conclusions[index].evidence.last.sourceCapturedAt!,
          currentStatus: ChangeThreadStatus.changed,
          evidenceEventIds: ['scale-event-$index'],
          policyVersion: ChangeThreadProjector.policyVersion,
        ),
        events: [
          ChangeEvent(
            eventId: 'scale-event-$index',
            threadId: 'scale-thread-$index',
            conclusionKind: ExplainableInsightKind.change,
            status: ChangeThreadStatus.changed,
            changedDimensions: const [],
            exactEvidence: conclusions[index].evidence,
            occurredAt: conclusions[index].evidence.last.sourceCapturedAt!,
            confidenceBand: EvidenceConfidenceBand.earlyObservation,
            uncertainty: conclusions[index].uncertaintyNote,
            alternativeExplanation:
                conclusions[index].alternatives.first.statement,
            statement: conclusions[index].statement,
          ),
        ],
      ),
  ],
);
