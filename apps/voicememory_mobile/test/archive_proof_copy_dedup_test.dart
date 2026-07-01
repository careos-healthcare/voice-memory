import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_evidence/archive_belief_thread_copy.dart';
import 'package:voicememory_mobile/features/early_archive/confirmed_repeat_why_matters_copy.dart';
import 'package:voicememory_mobile/features/early_archive/confirmed_repeat_thought_map_copy.dart';
import 'package:voicememory_mobile/features/early_archive/positive_pattern_copy.dart';
import 'package:voicememory_mobile/features/early_archive/archive_proof_surface_copy.dart';
import 'package:voicememory_mobile/features/early_archive/archive_proof_surface_layout.dart';
import 'package:voicememory_mobile/features/early_archive/archive_proof_surface_layout.dart';
import 'package:voicememory_mobile/features/early_archive/early_evidence_timeline_engine.dart';
import 'package:voicememory_mobile/features/early_archive/early_first_signal_copy.dart';
import 'package:voicememory_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:voicememory_mobile/features/early_archive/early_repeat_progress_copy.dart';
import 'package:voicememory_mobile/features/early_archive/early_repeat_progress_engine.dart';
import 'package:voicememory_mobile/features/repeat_return_check/repeat_return_check_copy.dart';
import 'package:voicememory_mobile/features/repeat_return_check/repeat_return_check_engine.dart';
import 'package:voicememory_mobile/features/repeat_return_check/repeat_return_check_models.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';

JournalEntry _entry({
  required String id,
  required String transcript,
  DateTime? createdAt,
}) {
  return JournalEntry(
    id: id,
    createdAt: createdAt ?? DateTime(2026, 6, 12, 10),
    transcript: transcript,
    durationSeconds: 24,
    reflection: const Reflection(
      mood: 'thoughtful',
      emotionalIntensity: 2,
      recurringThemes: ['work'],
      exactLanguagePattern: '',
      concreteObservation: 'Work pressure showed up again today.',
      repeatedSignal: '',
    ),
  );
}

List<JournalEntry> _threeRelatedRepeatEntries() => [
      _entry(
        id: 'e1',
        transcript:
            'I had no capacity but I said yes again to the extra meeting today.',
        createdAt: DateTime(2026, 6, 10, 12),
      ),
      _entry(
        id: 'e2',
        transcript:
            'Same thing — said yes when I had no capacity for one more thing.',
        createdAt: DateTime(2026, 6, 11, 12),
      ),
      _entry(
        id: 'e3',
        transcript:
            'I said yes again even though I had no capacity for one more ask.',
        createdAt: DateTime(2026, 6, 12, 12),
      ),
    ];

List<JournalEntry> _fourRelatedEntries() => [
      ..._threeRelatedRepeatEntries(),
      _entry(
        id: 'e4',
        transcript:
            'I said yes again even though I had no capacity for one more ask today.',
        createdAt: DateTime(2026, 6, 13, 12),
      ),
    ];

RepeatReturnCheckRecord _strongerRecord() => RepeatReturnCheckRecord(
      entryId: 'e4',
      choice: RepeatReturnCheckChoice.stronger,
      entryCountAtCapture: 4,
      createdAt: DateTime(2026, 6, 13),
    );

void main() {
  group('ArchiveProofSurfaceCopy dedup', () {
    test('confirmed repeat card alone keeps key phrases once', () {
      final confirmed = EarlyFirstSignalEngine.build(
        entries: _threeRelatedRepeatEntries(),
      );
      final layout = ArchiveProofSurfaceLayout(
        confirmedRepeatCardVisible: true,
        timelineVisible: false,
        changeProofVisible: false,
        proBridgeVisible: false,
      );
      final blocks = ArchiveProofSurfaceCopy.patternsStack(
        layout: layout,
        confirmedRepeat: confirmed,
      );

      expect(
        ArchiveProofCopyDedup.phrasesWithinLimit(
          copyBlocks: blocks,
          onceOnlyPhrases: [
            EarlyFirstSignalCopy.threeEntrySeenThreeTimes,
            EarlyFirstSignalCopy.evidenceHeading,
          ],
        ),
        isTrue,
      );
    });

    test('record stack with timeline and change proof dedupes repeat phrasing', () {
      final timeline = EarlyEvidenceTimelineEngine.build(
        entries: _fourRelatedEntries(),
      );
      final changeProof = RepeatReturnCheckEngine.changeProofForReady(
        entryCount: 4,
        viewingConfirmedRepeat: true,
        isRecording: false,
        isPostSave: false,
        records: [_strongerRecord()],
      );
      final layout = ArchiveProofSurfaceLayout(
        confirmedRepeatCardVisible: false,
        timelineVisible: true,
        changeProofVisible: true,
        proBridgeVisible: true,
      );
      final blocks = ArchiveProofSurfaceCopy.recordReadyStack(
        layout: layout,
        timeline: timeline,
        changeProof: changeProof,
      );

      expect(
        ArchiveProofCopyDedup.countPhrase(
          blocks.join('\n'),
          EarlyFirstSignalCopy.threeEntrySeenThreeTimes,
        ),
        0,
      );
      expect(
        ArchiveProofCopyDedup.countPhrase(
          blocks.join('\n'),
          EarlyFirstSignalCopy.evidenceHeading,
        ),
        1,
      );
      expect(blocks, contains(RepeatReturnCheckCopy.changeProofTitle));
      expect(blocks, contains(RepeatReturnCheckCopy.trendGettingLouder));
      expect(blocks, isNot(contains(RepeatReturnCheckCopy.changeProofSupportLine)));
      expect(blocks, contains(ArchiveBeliefThreadCopy.fullArchiveHistoryTitle));
      expect(blocks, contains(ArchiveBeliefThreadCopy.fullArchiveHistoryBody));
    });

    test('patterns stack with confirmed repeat hides timeline evidence heading', () {
      final confirmed = EarlyFirstSignalEngine.build(
        entries: _threeRelatedRepeatEntries(),
      );
      final layout = ArchiveProofSurfaceLayout(
        confirmedRepeatCardVisible: true,
        timelineVisible: false,
        changeProofVisible: false,
        proBridgeVisible: false,
      );

      expect(
        ArchiveProofCopyDedup.phrasesWithinLimit(
          copyBlocks: ArchiveProofSurfaceCopy.patternsStack(
            layout: layout,
            confirmedRepeat: confirmed,
          ),
          onceOnlyPhrases: [EarlyFirstSignalCopy.evidenceHeading],
        ),
        isTrue,
      );
    });
    test('why matters copy stays distinct from proof phrases', () {
      final confirmed = EarlyFirstSignalEngine.build(
        entries: _threeRelatedRepeatEntries(),
      );
      final layout = ArchiveProofSurfaceLayout(
        confirmedRepeatCardVisible: true,
        timelineVisible: false,
        changeProofVisible: false,
        proBridgeVisible: false,
        whyMattersVisible: true,
      );
      final blocks = ArchiveProofSurfaceCopy.patternsStack(
        layout: layout,
        confirmedRepeat: confirmed,
      );

      expect(blocks, contains(ConfirmedRepeatWhyMattersCopy.title));
      expect(
        ArchiveProofCopyDedup.countPhrase(
          blocks.join('\n'),
          EarlyFirstSignalCopy.threeEntrySeenThreeTimes,
        ),
        1,
      );
      expect(
        blocks.where((block) => block == ConfirmedRepeatWhyMattersCopy.title),
        hasLength(1),
      );
    });

    test('thought map copy stays distinct from proof phrases', () {
      final confirmed = EarlyFirstSignalEngine.build(
        entries: _threeRelatedRepeatEntries(),
      );
      final layout = ArchiveProofSurfaceLayout(
        confirmedRepeatCardVisible: true,
        timelineVisible: false,
        changeProofVisible: false,
        proBridgeVisible: false,
        whyMattersVisible: false,
        thoughtMapVisible: true,
      );
      final blocks = ArchiveProofSurfaceCopy.patternsStack(
        layout: layout,
        confirmedRepeat: confirmed,
      );

      expect(blocks, contains(ConfirmedRepeatThoughtMapCopy.title));
      expect(
        ArchiveProofCopyDedup.countPhrase(
          blocks.join('\n'),
          EarlyFirstSignalCopy.threeEntrySeenThreeTimes,
        ),
        1,
      );
      expect(
        blocks.where((block) => block == ConfirmedRepeatThoughtMapCopy.title),
        hasLength(1),
      );
    });

    test('positive pattern copy stays distinct from confirmed repeat proof', () {
      final confirmed = EarlyFirstSignalEngine.build(
        entries: _threeRelatedRepeatEntries(),
      );
      final layout = ArchiveProofSurfaceLayout(
        confirmedRepeatCardVisible: true,
        timelineVisible: false,
        changeProofVisible: false,
        proBridgeVisible: false,
        positivePatternVisible: true,
      );
      final blocks = ArchiveProofSurfaceCopy.patternsStack(
        layout: layout,
        confirmedRepeat: confirmed,
      );

      expect(blocks, contains(PositivePatternCopy.title));
      expect(blocks, contains(PositivePatternCopy.body));
      expect(
        blocks.where((block) => block == PositivePatternCopy.title),
        hasLength(1),
      );
    });

    test('early repeat progress cue does not duplicate progress card copy', () {
      final progress = EarlyRepeatProgressEngine.build(
        entries: [
          _entry(
            id: 'e1',
            transcript:
                'I had no capacity but I said yes again to the extra meeting today.',
          ),
          _entry(
            id: 'e2',
            transcript:
                'Same thing — said yes when I had no capacity for one more thing.',
          ),
        ],
      );
      expect(progress, isNotNull);

      expect(progress!.nextMomentCue.body, isNot(equals(progress.title)));
      expect(progress.nextMomentCue.body, isNot(equals(progress.progressLabel)));
      expect(
        ArchiveProofCopyDedup.countPhrase(
          [
            progress.title,
            progress.body,
            progress.progressLabel,
            progress.nextMomentCue.label,
            progress.nextMomentCue.body,
            progress.nextMomentCue.footer,
          ].join('\n'),
          EarlyRepeatProgressCopy.twoRelatedTitle,
        ),
        1,
      );
      expect(
        ArchiveProofCopyDedup.countPhrase(
          [
            progress.title,
            progress.body,
            progress.progressLabel,
            progress.nextMomentCue.label,
            progress.nextMomentCue.body,
            progress.nextMomentCue.footer,
          ].join('\n'),
          EarlyRepeatProgressCopy.twoRelatedProgress,
        ),
        1,
      );
    });
  });
}
