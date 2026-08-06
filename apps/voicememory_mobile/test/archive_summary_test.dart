import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/early_archive/archive_proof_surface_copy.dart';
import 'package:voicememory_mobile/features/early_archive/archive_proof_surface_layout.dart';
import 'package:voicememory_mobile/features/early_archive/archive_summary_copy.dart';
import 'package:voicememory_mobile/features/early_archive/archive_summary_engine.dart';
import 'package:voicememory_mobile/features/early_archive/archive_summary_gates.dart';
import 'package:voicememory_mobile/features/early_archive/confirmed_repeat_thought_map_copy.dart';
import 'package:voicememory_mobile/features/early_archive/confirmed_repeat_thought_map_models.dart';
import 'package:voicememory_mobile/features/early_archive/confirmed_repeat_why_matters_copy.dart';
import 'package:voicememory_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:voicememory_mobile/features/early_archive/positive_pattern_copy.dart';
import 'package:voicememory_mobile/features/repeat_return_check/repeat_return_check_change_proof.dart';
import 'package:voicememory_mobile/features/repeat_return_check/repeat_return_check_copy.dart';
import 'package:voicememory_mobile/features/repeat_return_check/repeat_return_check_models.dart';
import 'package:voicememory_mobile/features/voice_capture/record_cta_policy.dart';
import 'package:voicememory_mobile/features/voice_capture/record_microphone_permission_ui.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/security/privacy_copy_policy.dart';
import 'package:voicememory_mobile/widgets/record/archive_summary_card.dart';

JournalEntry _entry({
  required String id,
  required String transcript,
  DateTime? createdAt,
}) => JournalEntry(
  id: id,
  createdAt: createdAt ?? DateTime(2026, 6, 12, 12),
  transcript: transcript,
  durationSeconds: 30,
  localAudioPath: '/tmp/$id.m4a',
  reflection: const Reflection(
    mood: 'neutral',
    emotionalIntensity: 2,
    recurringThemes: ['work'],
    exactLanguagePattern: '',
    concreteObservation: 'Work pressure showed up in this moment.',
    repeatedSignal: '',
  ),
);

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

List<JournalEntry> _mixedRepeatAndWalkEntries() => [
  ..._threeRelatedRepeatEntries(),
  _entry(
    id: 'w4',
    transcript: 'I walked outside before replying and it helped.',
    createdAt: DateTime(2026, 6, 13, 12),
  ),
  _entry(
    id: 'w5',
    transcript: 'Same week I walked outside again before the hard email.',
    createdAt: DateTime(2026, 6, 14, 12),
  ),
];

RepeatReturnCheckChangeProof _changeProof(RepeatReturnCheckChoice choice) =>
    RepeatReturnCheckChangeProof(
      title: RepeatReturnCheckCopy.changeProofTitle,
      body: switch (choice) {
        RepeatReturnCheckChoice.stronger =>
          RepeatReturnCheckCopy.trendGettingLouder,
        RepeatReturnCheckChoice.softer =>
          RepeatReturnCheckCopy.trendSofterThanBefore,
        RepeatReturnCheckChoice.same => RepeatReturnCheckCopy.trendSteady,
        RepeatReturnCheckChoice.changed => 'It changed from before.',
      },
      latestChoice: choice,
    );

void _expectNoDiagnosticLanguage(String copy) {
  final lower = copy.toLowerCase();
  expect(lower, isNot(contains('diagnosis')));
  expect(lower, isNot(contains('therapy')));
  expect(lower, isNot(contains('disorder')));
}

void main() {
  group('ArchiveSummaryGates', () {
    test('hidden before three entries and while recording', () {
      expect(
        ArchiveSummaryGates.shouldShow(
          loaded: true,
          entryCount: 2,
          isReady: true,
          isRecording: false,
          viewingConfirmedRepeatOrTimeline: true,
          hasSummary: true,
        ),
        isFalse,
      );
      expect(
        ArchiveSummaryGates.shouldShow(
          loaded: true,
          entryCount: 3,
          isReady: true,
          isRecording: true,
          viewingConfirmedRepeatOrTimeline: true,
          hasSummary: true,
        ),
        isFalse,
      );
      expect(
        ArchiveSummaryGates.shouldShow(
          loaded: true,
          entryCount: 3,
          isReady: true,
          isRecording: false,
          viewingConfirmedRepeatOrTimeline: false,
          hasSummary: true,
        ),
        isFalse,
      );
      expect(
        ArchiveSummaryGates.shouldShow(
          loaded: true,
          entryCount: 3,
          isReady: true,
          isRecording: false,
          viewingConfirmedRepeatOrTimeline: true,
          hasSummary: true,
        ),
        isTrue,
      );
    });

    test('record next CTA hides when capture primary is visible', () {
      expect(
        ArchiveSummaryGates.showRecordNextCta(
          policy: const RecordCtaPolicyResolution(
            state: RecordCtaPolicyState.returning,
            primaryLabel: ConsumerUiCopy.recordMomentCta,
            showMainBottomCta: true,
            action: RecordCtaAction.startRecording,
          ),
          hideCardRecordButtons: true,
          promoteMicCaptureActions: false,
        ),
        isFalse,
      );
    });
  });

  group('ArchiveSummaryEngine', () {
    test('visible after confirmed repeat with evidence phrases', () {
      final entries = _threeRelatedRepeatEntries();
      final confirmed = EarlyFirstSignalEngine.build(entries: entries);
      expect(confirmed?.showsConfirmedRepeat, isTrue);

      final summary = ArchiveSummaryEngine.build(
        entries: entries,
        confirmedRepeat: confirmed,
        viewingConfirmedRepeatOrTimeline: true,
      );
      expect(summary, isNotNull);
      expect(summary!.title, ArchiveSummaryCopy.title);
      expect(
        summary.keepsRepeating.bodyLines.any(
          (line) =>
              line.contains('evidence') || line.contains('ArchiveMe found'),
        ),
        isTrue,
      );
      expect(
        summary.keepsRepeating.bodyLines.join('\n').toLowerCase(),
        contains('said yes'),
      );
      expect(summary.keepsRepeating.evidencePhrases, isNotEmpty);
      expect(summary.keepsRepeating.isFallback, isFalse);
    });

    test('keeps repeating copy avoids personality and motive claims', () {
      final summary = ArchiveSummaryEngine.build(
        entries: _threeRelatedRepeatEntries(),
        confirmedRepeat: EarlyFirstSignalEngine.build(
          entries: _threeRelatedRepeatEntries(),
        ),
        viewingConfirmedRepeatOrTimeline: true,
      );
      expect(summary, isNotNull);
      final blob = summary!.keepsRepeating.bodyLines.join(' ').toLowerCase();
      expect(blob, isNot(contains('you always')));
      expect(blob, isNot(contains('you are')));
      expect(blob, isNot(contains('because you')));
      _expectNoDiagnosticLanguage(blob);
    });

    test('returns null without confirmed repeat context', () {
      expect(
        ArchiveSummaryEngine.build(
          entries: _threeRelatedRepeatEntries(),
          viewingConfirmedRepeatOrTimeline: false,
        ),
        isNull,
      );
    });

    test('includes thought map sections without inventing unknowns', () {
      final summary = ArchiveSummaryEngine.build(
        entries: _threeRelatedRepeatEntries(),
        confirmedRepeat: EarlyFirstSignalEngine.build(
          entries: _threeRelatedRepeatEntries(),
        ),
        viewingConfirmedRepeatOrTimeline: true,
      );
      expect(summary, isNotNull);
      expect(summary!.loopRows, hasLength(4));
      expect(
        summary.loopRows.map((row) => row.label),
        containsAll([
          ConfirmedRepeatThoughtMapCopy.triggerLabel,
          ConfirmedRepeatThoughtMapCopy.thoughtLabel,
          ConfirmedRepeatThoughtMapCopy.actionLabel,
          ConfirmedRepeatThoughtMapCopy.resultLabel,
        ]),
      );
      final trigger = summary.loopRows.firstWhere(
        (row) => row.sectionId == ThoughtMapSectionId.trigger,
      );
      expect(trigger.isKnown, isFalse);
      expect(trigger.displayText, ConfirmedRepeatThoughtMapCopy.triggerUnknown);
    });

    test('includes change-over-time copy when available', () {
      final summary = ArchiveSummaryEngine.build(
        entries: _threeRelatedRepeatEntries(),
        confirmedRepeat: EarlyFirstSignalEngine.build(
          entries: _threeRelatedRepeatEntries(),
        ),
        changeProof: _changeProof(RepeatReturnCheckChoice.softer),
        viewingConfirmedRepeatOrTimeline: true,
      );
      expect(summary, isNotNull);
      expect(
        summary!.changingLine,
        RepeatReturnCheckCopy.trendSofterThanBefore,
      );
      expect(summary.changingIsFallback, isFalse);
    });

    test('uses changing fallback without change proof', () {
      final summary = ArchiveSummaryEngine.build(
        entries: _threeRelatedRepeatEntries(),
        confirmedRepeat: EarlyFirstSignalEngine.build(
          entries: _threeRelatedRepeatEntries(),
        ),
        viewingConfirmedRepeatOrTimeline: true,
      );
      expect(summary!.changingLine, ArchiveSummaryCopy.changingFallback);
      expect(summary.changingIsFallback, isTrue);
    });

    test('includes positive pattern when available', () {
      final summary = ArchiveSummaryEngine.build(
        entries: _mixedRepeatAndWalkEntries(),
        confirmedRepeat: EarlyFirstSignalEngine.build(
          entries: _threeRelatedRepeatEntries(),
        ),
        viewingConfirmedRepeatOrTimeline: true,
      );
      expect(summary, isNotNull);
      expect(summary!.whatHelpsLine, contains('A helpful action appeared'));
      expect(summary.whatHelpsLine.toLowerCase(), contains('walked outside'));
      expect(summary.whatHelpsLine.toLowerCase(), contains('watching'));
      expect(summary.whatHelpsIsFallback, isFalse);
    });

    test('chooses trigger prompt when trigger is unknown', () {
      final summary = ArchiveSummaryEngine.build(
        entries: _threeRelatedRepeatEntries(),
        confirmedRepeat: EarlyFirstSignalEngine.build(
          entries: _threeRelatedRepeatEntries(),
        ),
        viewingConfirmedRepeatOrTimeline: true,
      );
      expect(
        summary!.recordNext.prompt,
        ArchiveSummaryCopy.recordNextTriggerUnknown,
      );
      expect(summary.recordNext.targetSection, ThoughtMapSectionId.trigger);
    });

    test('chooses change prompt when loop is complete but change unknown', () {
      final entries = _mixedRepeatAndWalkEntries();
      final summary = ArchiveSummaryEngine.build(
        entries: entries,
        confirmedRepeat: EarlyFirstSignalEngine.build(
          entries: _threeRelatedRepeatEntries(),
        ),
        viewingConfirmedRepeatOrTimeline: true,
      );
      expect(summary, isNotNull);
      if (summary!.loopRows.every((row) => row.isKnown)) {
        expect(
          summary.recordNext.prompt,
          ArchiveSummaryCopy.recordNextChangeUnknown,
        );
      }
    });

    test('prioritizes missing loop sections before change and help', () {
      final summary = ArchiveSummaryEngine.build(
        entries: _threeRelatedRepeatEntries(),
        confirmedRepeat: EarlyFirstSignalEngine.build(
          entries: _threeRelatedRepeatEntries(),
        ),
        changeProof: _changeProof(RepeatReturnCheckChoice.same),
        viewingConfirmedRepeatOrTimeline: true,
      );
      expect(
        summary!.recordNext.prompt,
        ArchiveSummaryCopy.recordNextTriggerUnknown,
      );
      expect(summary.recordNext.targetSection, ThoughtMapSectionId.trigger);
    });

    test('uses keeps repeating fallback without confirmed repeat body', () {
      final summary = ArchiveSummaryEngine.build(
        entries: _threeRelatedRepeatEntries(),
        viewingConfirmedRepeatOrTimeline: true,
      );
      expect(summary, isNotNull);
      expect(
        summary!.keepsRepeating.bodyLines,
        contains(ArchiveSummaryCopy.keepsRepeatingFallback),
      );
    });
  });

  group('ArchiveSummaryCopy', () {
    test('avoids therapy and diagnosis language', () {
      final lines = [
        ArchiveSummaryCopy.title,
        ArchiveSummaryCopy.promise,
        ArchiveSummaryCopy.keepsRepeatingLabel,
        ArchiveSummaryCopy.keepsRepeatingFallback,
        ArchiveSummaryCopy.loopFormingLabel,
        ArchiveSummaryCopy.changingLabel,
        ArchiveSummaryCopy.changingFallback,
        ArchiveSummaryCopy.whatHelpsLabel,
        ArchiveSummaryCopy.whatHelpsFallback,
        ArchiveSummaryCopy.recordNextLabel,
        ArchiveSummaryCopy.recordNextCta,
        ArchiveSummaryCopy.recordNextTriggerUnknown,
        ArchiveSummaryCopy.recordNextThoughtUnknown,
        ArchiveSummaryCopy.recordNextActionUnknown,
        ArchiveSummaryCopy.recordNextResultUnknown,
        ArchiveSummaryCopy.recordNextChangeUnknown,
        ArchiveSummaryCopy.recordNextPositiveMissing,
      ];
      final copy = lines.join(' ');
      _expectNoDiagnosticLanguage(copy);
      for (final line in lines) {
        for (final reason in PrivacyCopyPolicy.violationsInLiteral(line)) {
          fail('"$line": $reason');
        }
      }
    });

    test('uses evidence and repeat language, not chat-memory framing', () {
      final joined = [
        ArchiveSummaryCopy.title,
        ArchiveSummaryCopy.promise,
        ArchiveSummaryCopy.keepsRepeatingLabel,
        ArchiveSummaryCopy.changingLabel,
        ArchiveSummaryCopy.recordNextLabel,
        ArchiveSummaryCopy.recordNextChangeGuided,
      ].join(' ');

      expect(joined, contains('evidence'));
      expect(joined, contains('repeat'));
      expect(ArchiveSummaryCopy.promise, contains('not conversation history'));
      expect(joined.toLowerCase(), isNot(contains('chat memory')));
      expect(joined.toLowerCase(), isNot(contains('ai remembers you')));
    });

    test('references tracking change over time since first proof', () {
      final joined = [
        ArchiveSummaryCopy.changingLabel,
        ArchiveSummaryCopy.changingFallback,
        ArchiveSummaryCopy.recordNextChangeUnknown,
        ArchiveSummaryCopy.recordNextChangeGuided,
      ].join(' ').toLowerCase();

      expect(joined, contains('first proof'));
      expect(joined, contains('what changed'));
      expect(joined, contains('stronger'));
      expect(joined, contains('softer'));
      expect(joined, contains('about the same'));
    });

    test('uses evidence language and avoids coaching advice', () {
      for (final line in ProofSurfaceAdviceGuard.mainProofSurfaceCopyBlocks()) {
        for (final violation in ProofSurfaceAdviceGuard.violationsIn(line)) {
          fail('"$line" contains banned advice phrase "$violation"');
        }
      }

      final joined = [
        ArchiveSummaryCopy.whatHelpsLabel,
        ArchiveSummaryCopy.whatHelpsWithPhrase('walked outside'),
        ArchiveSummaryCopy.changingFallback,
      ].join(' ').toLowerCase();
      expect(joined, contains('helpful action appeared'));
      expect(joined, contains('watching'));
      expect(joined, isNot(contains('you should')));
    });
  });

  group('ArchiveSummaryCard', () {
    testWidgets('renders unified sections on Record-style surface', (
      tester,
    ) async {
      final summary = ArchiveSummaryEngine.build(
        entries: _threeRelatedRepeatEntries(),
        confirmedRepeat: EarlyFirstSignalEngine.build(
          entries: _threeRelatedRepeatEntries(),
        ),
        changeProof: _changeProof(RepeatReturnCheckChoice.stronger),
        viewingConfirmedRepeatOrTimeline: true,
      );
      expect(summary, isNotNull);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ArchiveSummaryCard(
                summary: summary!,
                showRecordNextCta: true,
                onRecordNext: () {},
              ),
            ),
          ),
        ),
      );

      expect(find.text(ArchiveSummaryCopy.title), findsOneWidget);
      expect(find.text(ArchiveSummaryCopy.keepsRepeatingLabel), findsOneWidget);
      expect(find.text(ArchiveSummaryCopy.loopFormingLabel), findsOneWidget);
      expect(find.text(ArchiveSummaryCopy.changingLabel), findsOneWidget);
      expect(find.text(ArchiveSummaryCopy.whatHelpsLabel), findsOneWidget);
      expect(find.text(ArchiveSummaryCopy.recordNextLabel), findsOneWidget);
      expect(
        find.text(RepeatReturnCheckCopy.trendGettingLouder),
        findsOneWidget,
      );
      expect(find.text(ArchiveSummaryCopy.recordNextCta), findsOneWidget);
    });

    testWidgets('does not expose full transcript blobs', (tester) async {
      final entries = _threeRelatedRepeatEntries();
      final summary = ArchiveSummaryEngine.build(
        entries: entries,
        confirmedRepeat: EarlyFirstSignalEngine.build(entries: entries),
        viewingConfirmedRepeatOrTimeline: true,
      );
      expect(summary, isNotNull);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ArchiveSummaryCard(
                summary: summary!,
                showRecordNextCta: false,
              ),
            ),
          ),
        ),
      );

      expect(find.textContaining(entries.first.transcript), findsNothing);
    });
  });

  group('ArchiveSummary proof dedup', () {
    test('summary replaces supporting card headings on the same surface', () {
      final confirmed = EarlyFirstSignalEngine.build(
        entries: _threeRelatedRepeatEntries(),
      );
      final layout = ArchiveProofSurfaceLayout(
        confirmedRepeatCardVisible: true,
        timelineVisible: false,
        changeProofVisible: true,
        proBridgeVisible: false,
        whyMattersVisible: true,
        thoughtMapVisible: true,
        positivePatternVisible: true,
        archiveSummaryVisible: true,
      );
      final blocks = ArchiveProofSurfaceCopy.patternsStack(
        layout: layout,
        confirmedRepeat: confirmed,
        changeProof: _changeProof(RepeatReturnCheckChoice.same),
      );

      expect(blocks, contains(ArchiveSummaryCopy.title));
      expect(blocks, isNot(contains(ConfirmedRepeatWhyMattersCopy.title)));
      expect(blocks, isNot(contains(ConfirmedRepeatThoughtMapCopy.title)));
      expect(blocks, isNot(contains(PositivePatternCopy.title)));
      expect(
        blocks.where((block) => block == ArchiveSummaryCopy.title),
        hasLength(1),
      );
      expect(
        blocks.where((block) => block == ArchiveSummaryCopy.loopFormingLabel),
        hasLength(1),
      );
    });

    test('layout suppresses supporting cards when summary is visible', () {
      const layout = ArchiveProofSurfaceLayout(
        confirmedRepeatCardVisible: true,
        timelineVisible: false,
        changeProofVisible: true,
        proBridgeVisible: false,
        whyMattersVisible: true,
        thoughtMapVisible: true,
        positivePatternVisible: true,
        archiveSummaryVisible: true,
      );
      expect(layout.effectiveWhyMattersVisible, isFalse);
      expect(layout.effectiveThoughtMapVisible, isFalse);
      expect(layout.effectivePositivePatternVisible, isFalse);
      expect(layout.effectiveChangeProofVisible, isFalse);
      expect(layout.effectiveConfirmedRepeatCardVisible, isFalse);
    });

    test(
      'current belief surface replaces archive summary as main overview',
      () {
        const layout = ArchiveProofSurfaceLayout(
          confirmedRepeatCardVisible: true,
          timelineVisible: true,
          changeProofVisible: true,
          proBridgeVisible: true,
          archiveSummaryVisible: true,
          archiveCurrentBeliefVisible: true,
        );
        expect(layout.effectiveArchiveSummaryVisible, isFalse);
        expect(layout.effectiveConfirmedRepeatCardVisible, isFalse);
        expect(layout.recordTimelineVisible(surfaceIsRecord: true), isFalse);
      },
    );
  });
}
