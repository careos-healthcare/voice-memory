import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_daily_change/archive_daily_change_copy.dart';
import 'package:voicememory_mobile/features/archive_daily_change/archive_daily_change_engine.dart';
import 'package:voicememory_mobile/features/archive_daily_change/archive_daily_change_models.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_activation_fit_models.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_boundary_response_models.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_cost_models.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_decision_outcome_models.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_pull_reason_models.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_return_trigger_copy.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_return_trigger_engine.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_return_trigger_models.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_three_moment_engine.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_three_moment_models.dart';
import 'package:voicememory_mobile/features/capacity_loop/quick_capture_friction_models.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/product/acquisition_start_copy.dart';
import 'package:voicememory_mobile/product/archive_positioning_copy.dart';
import 'package:voicememory_mobile/product/loop_acquisition_copy.dart';
import 'package:voicememory_mobile/product/loop_mode_copy.dart';

const _bannedWords = [
  'diagnosis',
  'symptom',
  'therapy',
  'mental health',
  'medical',
  'treatment',
  'subscribe now',
  'buy now',
  'pro is active',
  'wellbeing score',
  'mental health score',
  'life score',
  'clinical score',
  'guilt',
  'streak',
  'daily habit',
  'you must',
  'complete your streak',
  'fake stats',
  'testimonial',
];

const _forbiddenOnboardingTerms = [
  'capacity loop',
  'beta signal',
  'activation',
  'evidence archive',
];

const _privateSnippet = 'felt pressure at work before saying yes';

JournalEntry _capacityEntry(String id, {DateTime? createdAt}) => JournalEntry(
  id: id,
  createdAt: createdAt ?? DateTime(2026, 6, 15, 12),
  transcript:
      'I said yes again with no capacity left even though I was tired today.',
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

CapacityPullReasonRecord _pullReason(
  String entryId,
  List<String> reasonIds, {
  DateTime? updatedAt,
}) => CapacityPullReasonRecord(
  sourceEntryId: entryId,
  reasonIds: reasonIds,
  status: CapacityPullReasonStatus.answered,
  createdAt: updatedAt ?? DateTime(2026, 6, 15, 12),
  updatedAt: updatedAt ?? DateTime(2026, 6, 15, 12),
);

CapacityCostRecord _laterCostRecord(String entryId) => CapacityCostRecord(
  sourceEntryId: entryId,
  costTypeIds: const [CapacityCostTypeIds.energy],
  status: CapacityCostRecordStatus.answered,
  createdAt: DateTime(2026, 6, 15, 12),
  updatedAt: DateTime(2026, 6, 15, 12),
);

CapacityDecisionOutcomeRecord _outcomeRecord(
  String entryId,
  String outcomeId,
) => CapacityDecisionOutcomeRecord(
  sourceEntryId: entryId,
  outcomeId: outcomeId,
  status: CapacityDecisionOutcomeStatus.answered,
  createdAt: DateTime(2026, 6, 15, 12),
  updatedAt: DateTime(2026, 6, 15, 12),
);

void _expectNoBannedCopy(Iterable<String> visible) {
  for (final text in visible) {
    final lower = text.toLowerCase();
    for (final word in _bannedWords) {
      expect(
        lower,
        isNot(contains(word)),
        reason: 'must not contain "$word" in "$text"',
      );
    }
    expect(lower, isNot(contains('archiveme knows')));
    expect(lower, isNot(contains(_privateSnippet)));
  }
}

void main() {
  const dailyChangeEngine = ArchiveDailyChangeEngine();
  const returnEngine = CapacityReturnTriggerEngine();
  const threeMomentEngine = CapacityThreeMomentEngine();

  group('Beta recovery onboarding promise', () {
    test('headline uses simpler fallback copy', () {
      expect(
        AcquisitionStartCopy.capacityTitle,
        ArchivePositioningCopy.firstUseTitle,
      );
      expect(
        AcquisitionStartCopy.capacityTitle,
        contains('When it repeats, save it'),
      );
      expect(
        LoopAcquisitionCopy.capacityYes.headline,
        'Catch the yes before it costs you.',
      );
      expect(
        LoopModeCopy.capacityHandoffTitle,
        'Catch the yes before it costs you.',
      );
    });

    test('how it works explains save choose pull come back review', () {
      expect(AcquisitionStartCopy.capacityHowItWorksSteps, [
        'Save one real moment',
        'Choose what pulled you in',
        'Come back when it repeats',
        'See what appeared and returned',
      ]);
      expect(LoopAcquisitionCopy.capacityYes.bullets, [
        'Save a yes moment',
        'See what pulled you in',
        'Review what changed',
      ]);
    });

    test('avoids internal terms in normal-user onboarding copy', () {
      final visible = [
        AcquisitionStartCopy.capacityTitle,
        AcquisitionStartCopy.capacityBody,
        ...AcquisitionStartCopy.capacityHowItWorksSteps,
        AcquisitionStartCopy.capacityFirstPathLabel,
        AcquisitionStartCopy.capacityFirstPathHeadline,
        LoopAcquisitionCopy.capacityYes.headline,
        LoopAcquisitionCopy.capacityYes.subheadline,
        ...LoopAcquisitionCopy.capacityYes.bullets,
      ];
      final joined = visible.join('\n').toLowerCase();
      for (final term in _forbiddenOnboardingTerms) {
        expect(joined, isNot(contains(term)));
      }
    });

    test('includes first-use body and CTAs', () {
      expect(
        AcquisitionStartCopy.capacityBody,
        ArchivePositioningCopy.firstUseBody,
      );
      expect(AcquisitionStartCopy.capacityStartCta, 'Save first moment');
      expect(AcquisitionStartCopy.capacityHowItWorksCta, 'See how it works');
    });
  });

  group('Beta recovery return trigger copy', () {
    test('first-save completion says first moment saved', () {
      final result = returnEngine.build(
        const CapacityReturnTriggerInput(
          sampleMode: false,
          screenshotMode: false,
          capacityWedgeActive: true,
          capacityMomentCount: 1,
          surface: CapacityReturnTriggerSurface.completion,
        ),
      );
      expect(result.title, 'First moment saved.');
      expect(result.primaryCtaLabel, 'Done for now');
      expect(result.secondaryCtaLabel, 'Save another');
      expect(result.primaryDismisses, isTrue);
    });

    test('1-2 moment archive copy pulls user toward next real request', () {
      final one = returnEngine.build(
        const CapacityReturnTriggerInput(
          sampleMode: false,
          screenshotMode: false,
          capacityWedgeActive: true,
          capacityMomentCount: 1,
          surface: CapacityReturnTriggerSurface.archiveHome,
        ),
      );
      expect(one.title, 'First moment saved.');
      expect(one.body, CapacityReturnTriggerCopy.archiveHomeBody(1, target: 3));

      final integrated = threeMomentEngine.build(
        const CapacityThreeMomentInput(
          sampleMode: false,
          capacityWedgeActive: true,
          capacityEvidenceCount: 1,
          capacityMomentCount: 1,
        ),
      );
      expect(integrated.title, one.title);
      expect(integrated.subtitle, one.body);
    });

    test('record line uses when real yes moment happens again', () {
      final result = returnEngine.build(
        const CapacityReturnTriggerInput(
          sampleMode: false,
          screenshotMode: false,
          capacityWedgeActive: true,
          capacityMomentCount: 1,
          surface: CapacityReturnTriggerSurface.recordLine,
        ),
      );
      expect(
        CapacityReturnTriggerEngine.recordProgressLine(result),
        CapacityReturnTriggerCopy.recordProgressLine,
      );
    });

    test('return copy passes language guard', () {
      _expectNoBannedCopy(CapacityReturnTriggerCopy.allVisibleStrings());
    });
  });

  group('Beta recovery daily change sharpened responses', () {
    test('urgency + later cost uses sharper combined copy', () {
      final result = dailyChangeEngine.build(
        ArchiveDailyChangeInput(
          sampleMode: false,
          capacityWedgeActive: true,
          realSavedMomentCount: 2,
          capacityMomentCount: 2,
          capacityEvidenceCount: 2,
          mostCommonPullReasonId: CapacityPullReasonIds.soundedUrgent,
          pullReasonRecordCount: 2,
          state: ArchiveDailyChangeState.empty,
          entries: [
            _capacityEntry('real_0'),
            _capacityEntry('real_1', createdAt: DateTime(2026, 6, 16, 13)),
          ],
          pullReasonRecords: [
            _pullReason('real_0', [CapacityPullReasonIds.soundedUrgent]),
            _pullReason('real_1', [
              CapacityPullReasonIds.soundedUrgent,
            ], updatedAt: DateTime(2026, 6, 16, 13)),
          ],
          costRecords: [_laterCostRecord('real_0')],
          outcomeRecords: const [],
          boundarySelection: null,
          activationFitRecord: null,
          weeklyReviewAvailable: false,
        ),
      );

      expect(
        result.changeLine,
        ArchiveDailyChangeCopy.urgencyWithLaterCostLine,
      );
      expect(result.alternativeNextMove, ArchiveDailyChangeCopy.altUrgency);
    });

    test('responsibility + said yes uses sharper combined copy', () {
      final result = dailyChangeEngine.build(
        ArchiveDailyChangeInput(
          sampleMode: false,
          capacityWedgeActive: true,
          realSavedMomentCount: 3,
          capacityMomentCount: 3,
          capacityEvidenceCount: 3,
          mostCommonPullReasonId: CapacityPullReasonIds.feltResponsible,
          pullReasonRecordCount: 2,
          state: ArchiveDailyChangeState.empty,
          entries: [
            _capacityEntry('real_0'),
            _capacityEntry('real_1', createdAt: DateTime(2026, 6, 16, 13)),
            _capacityEntry('real_2', createdAt: DateTime(2026, 6, 16, 14)),
          ],
          pullReasonRecords: [
            _pullReason('real_0', [CapacityPullReasonIds.feltResponsible]),
            _pullReason('real_1', [CapacityPullReasonIds.feltResponsible]),
          ],
          costRecords: const [],
          outcomeRecords: [
            _outcomeRecord('real_0', CapacityDecisionOutcomeIds.saidYes),
          ],
          boundarySelection: null,
          activationFitRecord: null,
          weeklyReviewAvailable: false,
        ),
      );

      expect(
        result.changeLine,
        ArchiveDailyChangeCopy.responsibilityWithSaidYesLine,
      );
      expect(
        result.alternativeNextMove,
        ArchiveDailyChangeCopy.altResponsibility,
      );
    });

    test('fit partly + new moment references partly fitting', () {
      final result = dailyChangeEngine.build(
        ArchiveDailyChangeInput(
          sampleMode: false,
          capacityWedgeActive: true,
          realSavedMomentCount: 2,
          capacityMomentCount: 2,
          capacityEvidenceCount: 2,
          mostCommonPullReasonId: CapacityPullReasonIds.soundedUrgent,
          pullReasonRecordCount: 1,
          state: ArchiveDailyChangeState.empty,
          entries: [
            _capacityEntry('real_0'),
            _capacityEntry('real_1', createdAt: DateTime(2026, 6, 16, 13)),
          ],
          pullReasonRecords: [
            _pullReason('real_0', [CapacityPullReasonIds.soundedUrgent]),
          ],
          costRecords: const [],
          outcomeRecords: const [],
          boundarySelection: null,
          activationFitRecord: CapacityActivationFitRecord(
            responseId: CapacityActivationFitResponseIds.partly,
            source: CapacityActivationFitSource.capacityLoopActivation,
            activationEntryCount: 2,
            status: CapacityActivationFitStatus.answered,
            createdAt: DateTime(2026, 6, 15, 12),
            updatedAt: DateTime(2026, 6, 15, 12),
          ),
          weeklyReviewAvailable: false,
        ),
      );

      expect(
        result.responseType,
        ArchiveDailyChangeResponseType.fitPartlyNewMoment,
      );
      expect(result.changeLine, ArchiveDailyChangeCopy.fitPartlyNewMomentLine);
    });

    test('quick capture still_work maps to reduce workload copy', () {
      final result = dailyChangeEngine.build(
        ArchiveDailyChangeInput(
          sampleMode: false,
          capacityWedgeActive: true,
          realSavedMomentCount: 1,
          capacityMomentCount: 1,
          capacityEvidenceCount: 1,
          mostCommonPullReasonId: null,
          pullReasonRecordCount: 0,
          state: ArchiveDailyChangeState.empty,
          entries: [_capacityEntry('real_0')],
          pullReasonRecords: const [],
          costRecords: const [],
          outcomeRecords: const [],
          boundarySelection: null,
          activationFitRecord: null,
          weeklyReviewAvailable: false,
          quickCaptureFrictionRecord: QuickCaptureFrictionRecord(
            responseId: QuickCaptureFrictionResponseIds.stillWork,
            source: QuickCaptureFrictionSource.quickYesCapture,
            relatedEntryId: 'real_0',
            status: QuickCaptureFrictionStatus.answered,
            createdAt: DateTime(2026, 6, 16, 12),
            updatedAt: DateTime(2026, 6, 16, 12),
          ),
        ),
      );

      expect(
        result.responseType,
        ArchiveDailyChangeResponseType.quickCaptureStillWork,
      );
      expect(
        result.changeLine,
        ArchiveDailyChangeCopy.quickCaptureStillWorkLine,
      );
      expect(
        result.alternativeNextMove,
        ArchiveDailyChangeCopy.altQuickCaptureStillWork,
      );
    });
  });

  group('Beta recovery alternative mapping', () {
    test('pull-specific alternatives are fixed templates', () {
      expect(
        ArchiveDailyChangeCopy.alternativeBodyForPull(
          CapacityPullReasonIds.soundedUrgent,
        ),
        ArchiveDailyChangeCopy.altUrgency,
      );
      expect(
        ArchiveDailyChangeCopy.alternativeBodyForPull(
          CapacityPullReasonIds.feltResponsible,
        ),
        ArchiveDailyChangeCopy.altResponsibility,
      );
      expect(
        ArchiveDailyChangeCopy.alternativeBodyForPull(
          CapacityPullReasonIds.avoidDisappoint,
        ),
        ArchiveDailyChangeCopy.altDisappointment,
      );
      expect(
        ArchiveDailyChangeCopy.alternativeBodyForPull(
          CapacityPullReasonIds.squeezeItIn,
        ),
        ArchiveDailyChangeCopy.altSqueezeItIn,
      );
      expect(
        ArchiveDailyChangeCopy.alternativeBodyForPull(
          CapacityPullReasonIds.wantedOpportunity,
        ),
        ArchiveDailyChangeCopy.altOpportunity,
      );
      expect(
        ArchiveDailyChangeCopy.alternativeBodyForPull(
          CapacityPullReasonIds.answeredTooQuickly,
        ),
        ArchiveDailyChangeCopy.altAnsweredTooQuickly,
      );
    });

    test('selected boundary response is preferred over pull template', () {
      final result = dailyChangeEngine.build(
        ArchiveDailyChangeInput(
          sampleMode: false,
          capacityWedgeActive: true,
          realSavedMomentCount: 2,
          capacityMomentCount: 2,
          capacityEvidenceCount: 2,
          mostCommonPullReasonId: CapacityPullReasonIds.soundedUrgent,
          pullReasonRecordCount: 2,
          state: ArchiveDailyChangeState.empty,
          entries: [
            _capacityEntry('real_0'),
            _capacityEntry('real_1', createdAt: DateTime(2026, 6, 16, 13)),
          ],
          pullReasonRecords: [
            _pullReason('real_0', [CapacityPullReasonIds.soundedUrgent]),
            _pullReason('real_1', [CapacityPullReasonIds.soundedUrgent]),
          ],
          costRecords: [_laterCostRecord('real_0')],
          outcomeRecords: const [],
          boundarySelection: CapacityBoundaryResponseSelection(
            responseId: CapacityBoundaryResponseIds.cannotAnswerNow,
            selectedAt: DateTime(2026, 6, 15, 12),
          ),
          activationFitRecord: null,
          weeklyReviewAvailable: false,
        ),
      );

      expect(
        result.alternativeNextMove,
        'I cannot answer properly right now — I will come back to you.',
      );
      expect(
        result.alternativeLabel,
        ArchiveDailyChangeCopy.labelUseDefaultPause,
      );
    });

    test('daily change copy passes language guard', () {
      _expectNoBannedCopy(ArchiveDailyChangeCopy.allVisibleStrings());
    });
  });
}
