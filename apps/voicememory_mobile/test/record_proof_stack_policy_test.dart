import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/early_archive/archive_proof_surface_copy.dart';
import 'package:voicememory_mobile/features/early_archive/archive_proof_surface_layout.dart';
import 'package:voicememory_mobile/features/early_archive/archive_summary_copy.dart';
import 'package:voicememory_mobile/features/early_archive/confirmed_repeat_thought_map_copy.dart';
import 'package:voicememory_mobile/features/early_archive/daily_return_reason_copy.dart';
import 'package:voicememory_mobile/features/early_archive/early_first_signal_copy.dart';
import 'package:voicememory_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:voicememory_mobile/features/early_archive/positive_pattern_copy.dart';
import 'package:voicememory_mobile/features/early_archive/private_archive_report_copy.dart';
import 'package:voicememory_mobile/features/early_archive/record_proof_stack_policy.dart';
import 'package:voicememory_mobile/features/early_archive/weekly_archive_review_copy.dart';
import 'package:voicememory_mobile/features/repeat_return_check/pattern_changed_copy.dart';
import 'package:voicememory_mobile/features/repeat_return_check/pattern_changed_engine.dart';
import 'package:voicememory_mobile/features/repeat_return_check/repeat_return_check_change_proof.dart';
import 'package:voicememory_mobile/features/repeat_return_check/repeat_return_check_copy.dart';
import 'package:voicememory_mobile/features/repeat_return_check/repeat_return_check_models.dart';
import 'package:voicememory_mobile/features/repeat_return_check/repeat_return_check_trend.dart';
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

RepeatReturnCheckRecord _strongerRecord() => RepeatReturnCheckRecord(
  entryId: 'e4',
  choice: RepeatReturnCheckChoice.stronger,
  entryCountAtCapture: 4,
  createdAt: DateTime(2026, 6, 13),
);

void main() {
  group('RecordProofStackPolicy', () {
    test('entry 1–2 allows at most one early proof card', () {
      final decision = RecordProofStackPolicy.decide(
        loaded: true,
        entryCount: 2,
        isReady: true,
        isPostSave: false,
        isRecording: false,
        archiveSummaryVisible: false,
        hasEarlyFirstSignal: true,
        hasEarlyEvidenceTimeline: false,
        patternChangedVisible: true,
        dailyReturnReasonEligible: true,
        weeklyReviewEligible: true,
        privateReportEligible: true,
        whyMattersEligible: true,
        thoughtMapEligible: true,
        positiveReinforcementEligible: true,
        changeProofEligible: true,
        firstWeekLoopEligible: false,
        proBridgeEligible: true,
      );

      expect(decision.showEarlyRepeatProgress, isTrue);
      expect(decision.showEarlyFirstSignalCard, isFalse);
      expect(decision.showArchiveSummary, isFalse);
      expect(decision.showPatternChanged, isFalse);
      expect(decision.proofCardCount, lessThanOrEqualTo(1));
    });

    test('entry 5 with summary folds supporting cards on Record', () {
      final decision = RecordProofStackPolicy.decide(
        loaded: true,
        entryCount: 5,
        isReady: true,
        isPostSave: false,
        isRecording: false,
        archiveSummaryVisible: true,
        hasEarlyFirstSignal: false,
        hasEarlyEvidenceTimeline: true,
        patternChangedVisible: true,
        dailyReturnReasonEligible: true,
        weeklyReviewEligible: true,
        privateReportEligible: true,
        whyMattersEligible: true,
        thoughtMapEligible: true,
        positiveReinforcementEligible: true,
        changeProofEligible: true,
        firstWeekLoopEligible: false,
        proBridgeEligible: true,
      );

      expect(decision.showArchiveSummary, isTrue);
      expect(decision.showEarlyEvidenceTimeline, isFalse);
      expect(decision.showConfirmedRepeatThoughtMap, isFalse);
      expect(decision.showPositiveReinforcement, isFalse);
      expect(decision.showWeeklyArchiveWeekReview, isFalse);
      expect(decision.showPrivateArchiveReport, isFalse);
      expect(decision.showChangeProof, isFalse);
      expect(decision.showDailyReturnReason, isFalse);
      expect(decision.proofCardCount, lessThanOrEqualTo(3));
    });

    test('pattern changed may appear above archive summary on Record', () {
      final decision = RecordProofStackPolicy.decide(
        loaded: true,
        entryCount: 5,
        isReady: true,
        isPostSave: false,
        isRecording: false,
        archiveSummaryVisible: true,
        hasEarlyFirstSignal: false,
        hasEarlyEvidenceTimeline: true,
        patternChangedVisible: true,
        dailyReturnReasonEligible: false,
        weeklyReviewEligible: false,
        privateReportEligible: false,
        whyMattersEligible: false,
        thoughtMapEligible: false,
        positiveReinforcementEligible: false,
        changeProofEligible: true,
        firstWeekLoopEligible: false,
        proBridgeEligible: false,
      );

      expect(decision.showPatternChanged, isTrue);
      expect(decision.showArchiveSummary, isTrue);
      expect(decision.showChangeProof, isFalse);
    });

    test('caps proof cards at three on Record ready state', () {
      final decision = RecordProofStackPolicy.decide(
        loaded: true,
        entryCount: 5,
        isReady: true,
        isPostSave: false,
        isRecording: false,
        archiveSummaryVisible: true,
        hasEarlyFirstSignal: false,
        hasEarlyEvidenceTimeline: false,
        patternChangedVisible: true,
        dailyReturnReasonEligible: true,
        weeklyReviewEligible: false,
        privateReportEligible: false,
        whyMattersEligible: false,
        thoughtMapEligible: false,
        positiveReinforcementEligible: false,
        changeProofEligible: false,
        firstWeekLoopEligible: false,
        proBridgeEligible: true,
      );

      expect(decision.proofCardCount, 3);
      expect(decision.showPatternChanged, isTrue);
      expect(decision.showArchiveSummary, isTrue);
      expect(decision.showProBridge, isTrue);
      expect(decision.showDailyReturnReason, isFalse);
    });

    test('drops pro bridge before first week loop when cap exceeded', () {
      final decision = RecordProofStackPolicy.decide(
        loaded: true,
        entryCount: 5,
        isReady: true,
        isPostSave: false,
        isRecording: false,
        archiveSummaryVisible: true,
        hasEarlyFirstSignal: false,
        hasEarlyEvidenceTimeline: false,
        patternChangedVisible: true,
        dailyReturnReasonEligible: false,
        weeklyReviewEligible: false,
        privateReportEligible: false,
        whyMattersEligible: false,
        thoughtMapEligible: false,
        positiveReinforcementEligible: false,
        changeProofEligible: false,
        firstWeekLoopEligible: true,
        proBridgeEligible: true,
      );

      expect(decision.showFirstWeekLoop, isTrue);
      expect(decision.showProBridge, isFalse);
      expect(decision.proofCardCount, 3);
    });

    test(
      'drops archive summary before first week loop when pattern changed keeps cap',
      () {
        final decision = RecordProofStackPolicy.decide(
          loaded: true,
          entryCount: 5,
          isReady: true,
          isPostSave: false,
          isRecording: false,
          archiveSummaryVisible: true,
          hasEarlyFirstSignal: false,
          hasEarlyEvidenceTimeline: false,
          patternChangedVisible: true,
          dailyReturnReasonEligible: true,
          weeklyReviewEligible: false,
          privateReportEligible: false,
          whyMattersEligible: false,
          thoughtMapEligible: false,
          positiveReinforcementEligible: false,
          changeProofEligible: false,
          firstWeekLoopEligible: true,
          proBridgeEligible: true,
        );

        expect(decision.showPatternChanged, isTrue);
        expect(decision.showArchiveSummary, isFalse);
        expect(decision.showFirstWeekLoop, isTrue);
        expect(decision.showProBridge, isFalse);
        expect(decision.proofCardCount, lessThanOrEqualTo(3));
      },
    );
  });

  group('ArchiveProofSurfaceLayout record folding', () {
    test('record pattern changed stays visible when summary is visible', () {
      const layout = ArchiveProofSurfaceLayout(
        confirmedRepeatCardVisible: false,
        timelineVisible: true,
        changeProofVisible: true,
        proBridgeVisible: false,
        patternChangedVisible: true,
        archiveSummaryVisible: true,
      );

      expect(layout.recordPatternChangedVisible, isTrue);
      expect(layout.effectivePatternChangedVisible, isFalse);
      expect(layout.recordTimelineVisible(surfaceIsRecord: true), isFalse);
      expect(layout.recordTimelineVisible(surfaceIsRecord: false), isTrue);
      expect(layout.effectiveConfirmedRepeatCardVisible, isFalse);
    });
  });

  group('Record proof stack copy', () {
    test('record stack hides folded card titles at entry 5', () {
      final confirmed = EarlyFirstSignalEngine.build(
        entries: _threeRelatedRepeatEntries(),
      );
      final proof = RepeatReturnCheckChangeProof(
        title: RepeatReturnCheckCopy.changeProofTitle,
        body: RepeatReturnCheckTrendEngine.bodyForChoice(
          RepeatReturnCheckChoice.changed,
        ),
        latestChoice: RepeatReturnCheckChoice.changed,
      );
      final patternChanged = PatternChangedEngine.build(
        changeProof: proof,
        records: [
          RepeatReturnCheckRecord(
            entryId: 'e5',
            choice: RepeatReturnCheckChoice.changed,
            entryCountAtCapture: 5,
            createdAt: DateTime(2026, 6, 14),
          ),
        ],
        entries: [
          ..._threeRelatedRepeatEntries(),
          _entry(
            id: 'e4',
            transcript:
                'I said yes again even though I had no capacity for one more ask today.',
            createdAt: DateTime(2026, 6, 13, 12),
          ),
          _entry(
            id: 'e5',
            transcript:
                'Something felt different — I checked again before sending it.',
            createdAt: DateTime(2026, 6, 14, 12),
          ),
        ],
      );
      const layout = ArchiveProofSurfaceLayout(
        confirmedRepeatCardVisible: true,
        timelineVisible: true,
        changeProofVisible: true,
        proBridgeVisible: true,
        thoughtMapVisible: true,
        positivePatternVisible: true,
        patternChangedVisible: true,
        archiveSummaryVisible: true,
      );
      final decision = RecordProofStackPolicy.decide(
        loaded: true,
        entryCount: 5,
        isReady: true,
        isPostSave: false,
        isRecording: false,
        archiveSummaryVisible: true,
        hasEarlyFirstSignal: confirmed != null,
        hasEarlyEvidenceTimeline: true,
        patternChangedVisible: true,
        dailyReturnReasonEligible: true,
        weeklyReviewEligible: true,
        privateReportEligible: true,
        whyMattersEligible: true,
        thoughtMapEligible: true,
        positiveReinforcementEligible: true,
        changeProofEligible: true,
        firstWeekLoopEligible: false,
        proBridgeEligible: true,
      );

      final blocks = ArchiveProofSurfaceCopy.recordReadyStack(
        layout: layout,
        confirmedRepeat: confirmed,
        changeProof: proof,
        patternChanged: patternChanged,
        showArchiveSummary: decision.showArchiveSummary,
        showPatternChanged: decision.showPatternChanged,
        showDailyReturnReason: decision.showDailyReturnReason,
        showWeeklyReview: decision.showWeeklyArchiveWeekReview,
        showPrivateReport: decision.showPrivateArchiveReport,
      );

      expect(blocks, contains(ArchiveSummaryCopy.title));
      expect(blocks, contains(PatternChangedCopy.title));
      expect(blocks, isNot(contains(ConfirmedRepeatThoughtMapCopy.title)));
      expect(blocks, isNot(contains(PositivePatternCopy.title)));
      expect(blocks, isNot(contains(WeeklyArchiveWeekReviewCopy.title)));
      expect(blocks, isNot(contains(PrivateArchiveReportCopy.title)));
      expect(blocks, isNot(contains(RepeatReturnCheckCopy.changeProofTitle)));
      expect(
        ArchiveProofCopyDedup.countPhrase(
          blocks.join('\n'),
          EarlyFirstSignalCopy.threeEntrySeenThreeTimes,
        ),
        lessThanOrEqualTo(1),
      );
    });

    test('patterns stack keeps daily return and deeper review surfaces', () {
      const layout = ArchiveProofSurfaceLayout(
        confirmedRepeatCardVisible: false,
        timelineVisible: false,
        changeProofVisible: false,
        proBridgeVisible: false,
        archiveSummaryVisible: true,
      );
      final blocks = ArchiveProofSurfaceCopy.patternsStack(layout: layout);

      expect(blocks, contains(ArchiveSummaryCopy.title));
      expect(blocks, isNot(contains(DailyReturnReasonCopy.title)));
    });
  });
}
