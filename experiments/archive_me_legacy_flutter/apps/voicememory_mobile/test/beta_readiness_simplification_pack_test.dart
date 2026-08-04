import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_daily_change/archive_daily_change_copy.dart';
import 'package:voicememory_mobile/features/archive_daily_change/archive_daily_change_engine.dart';
import 'package:voicememory_mobile/features/archive_daily_change/archive_daily_change_models.dart';
import 'package:voicememory_mobile/features/archive_home/archive_home_card_priority.dart';
import 'package:voicememory_mobile/features/archive_home/archive_home_priority_engine.dart';
import 'package:voicememory_mobile/features/archive_home/archive_home_priority_models.dart';
import 'package:voicememory_mobile/features/archive_depth/archive_depth_models.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_boundary_response_copy.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_boundary_response_models.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_decision_outcome_models.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_pull_reason_models.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_return_trigger_copy.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_return_trigger_engine.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_return_trigger_models.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_three_moment_engine.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_three_moment_models.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/product/acquisition_start_copy.dart';
import 'package:voicememory_mobile/product/archive_positioning_copy.dart';
import 'package:voicememory_mobile/security/privacy_copy_policy.dart';

const _bannedPhrases = [
  'therapy',
  'diagnosis',
  'medical',
  'treatment',
  'mental health score',
  'wellbeing score',
  'clinical score',
  'life score',
  'archiveme knows',
  'fake stats',
  'testimonial',
  'everything stays on device',
  'fully encrypted archive',
  '100% secure',
  'unhackable',
  'anonymous',
];

const _forbiddenOnboardingTerms = [
  'activation',
  'beta signal',
  'loop-map',
  'capacity loop',
  'archive intelligence',
  'evidence engine',
];

const _privateSnippet = 'felt pressure at work before saying yes';

JournalEntry _capacityEntry(String id) => JournalEntry(
  id: id,
  createdAt: DateTime(2026, 6, 15, 12),
  transcript: 'I said yes again with no capacity left.',
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

CapacityPullReasonRecord _pullReason(String entryId, List<String> ids) =>
    CapacityPullReasonRecord(
      sourceEntryId: entryId,
      reasonIds: ids,
      status: CapacityPullReasonStatus.answered,
      createdAt: DateTime(2026, 6, 15, 12),
      updatedAt: DateTime(2026, 6, 16, 12),
    );

void _expectNoBannedCopy(Iterable<String> visible) {
  for (final text in visible) {
    final lower = text.toLowerCase();
    for (final phrase in _bannedPhrases) {
      if (phrase == 'therapy' && lower.contains('not therapy')) continue;
      expect(
        lower,
        isNot(contains(phrase)),
        reason: '"$text" contains "$phrase"',
      );
    }
    expect(lower, isNot(contains(_privateSnippet)));
    for (final reason in PrivacyCopyPolicy.violationsInLiteral(text)) {
      fail('privacy violation in "$text": $reason');
    }
  }
}

ArchiveHomePriorityInput _calmHomeInput({
  bool activationVisible = true,
  bool dailyChangeVisible = true,
  bool loopVisible = true,
  bool pullReasonVisible = true,
}) => ArchiveHomePriorityInput(
  savedEntryCount: 1,
  usableEvidenceCount: 1,
  depthLevel: ArchiveDepthLevel.notStarted,
  returnChangesAvailable: false,
  weeklyReviewAvailable: false,
  sampleMode: false,
  proPreviewPromoVisible: false,
  showEmptySample: false,
  archiveDailyChangeVisible: dailyChangeVisible,
  firstWeekPathVisible: false,
  dailyArchiveExerciseVisible: false,
  archiveClarityProgressVisible: false,
  capacityThreeMomentActivationVisible: activationVisible,
  capacityLoopVisible: loopVisible,
  capacityPullReasonVisible: pullReasonVisible,
  capacityDecisionOutcomeVisible: false,
  capacityCostLaterCheckinVisible: false,
  capacityActivationFitVisible: false,
  beforeYouSayYesPauseVisible: false,
  capacityWeeklyReviewVisible: false,
  capacityBoundaryResponseVisible: false,
  thenVsNowVisible: false,
  archiveCalendarVisible: false,
  reviewRitualVisible: false,
  milestoneShareVisible: false,
  calmCapacityActivationMode: true,
);

void main() {
  group('Onboarding clarity', () {
    test('headline uses simpler fallback copy', () {
      expect(
        AcquisitionStartCopy.capacityTitle,
        ArchivePositioningCopy.firstUseTitle,
      );
      expect(
        AcquisitionStartCopy.capacityTitle,
        contains('Your voice becomes your life story'),
      );
    });

    test('body explains save one real moment', () {
      expect(
        AcquisitionStartCopy.capacityBody,
        ArchivePositioningCopy.firstUseBody,
      );
    });

    test('how it works explains save choose pull come back review', () {
      expect(AcquisitionStartCopy.capacityHowItWorksSteps, [
        'Speak your thoughts',
        'Choose what pulled you in',
        'Build one life story',
        'Discover personal intelligence',
      ]);
    });

    test('onboarding does not expose internal terms', () {
      final joined = AcquisitionStartCopy.capacityVisibleStrings()
          .join('\n')
          .toLowerCase();
      for (final term in _forbiddenOnboardingTerms) {
        expect(joined, isNot(contains(term)), reason: 'contains $term');
      }
    });

    test('first path card copy is present', () {
      expect(
        AcquisitionStartCopy.capacityFirstPathHeadline,
        ArchivePositioningCopy.firstUseFirstPath,
      );
    });

    test('CTA says Save first moment', () {
      expect(AcquisitionStartCopy.capacityStartCta, 'Save first moment');
    });
  });

  group('Activation simplification', () {
    test('1 moment state says wait and do not force it', () {
      expect(
        CapacityReturnTriggerCopy.archiveHomeBody(1, target: 3).toLowerCase(),
        allOf(contains('wait for the next real one'), contains('do not force')),
      );
    });

    test('2 moment state says one more real moment', () {
      expect(
        CapacityReturnTriggerCopy.archiveHomeBody(2, target: 3),
        'One more real moment will make the pattern clearer.',
      );
    });

    test('return trigger primary CTA says Done for now', () {
      expect(CapacityReturnTriggerCopy.archiveHomePrimaryCta, 'Done for now');
    });

    test('under 3 moments only one primary capacity card is selected', () {
      const engine = ArchiveHomePriorityEngine();
      final plan = engine.build(
        _calmHomeInput(
          activationVisible: true,
          dailyChangeVisible: true,
          loopVisible: true,
          pullReasonVisible: true,
        ),
      );
      expect(ArchiveHomeCardPriority.onlyOneCapacityPrimaryCard(plan), isTrue);
      expect(
        plan.primarySections,
        contains(ArchiveHomeSectionId.capacityThreeMomentActivation),
      );
      expect(
        plan.primarySections,
        isNot(contains(ArchiveHomeSectionId.archiveDailyChange)),
      );
      expect(
        plan.primarySections,
        isNot(contains(ArchiveHomeSectionId.capacityLoop)),
      );
    });

    test('three moment engine hides quick save secondary at 1-2 moments', () {
      const engine = CapacityThreeMomentEngine();
      final result = engine.build(
        const CapacityThreeMomentInput(
          sampleMode: false,
          capacityWedgeActive: true,
          capacityEvidenceCount: 1,
          capacityMomentCount: 1,
        ),
      );
      expect(result.showQuickSaveSecondary, isFalse);
      expect(result.showReviewSecondary, isTrue);
    });
  });

  group('Daily change sharpening', () {
    const dailyEngine = ArchiveDailyChangeEngine();

    test('responsibility repeated with delayed answer', () {
      final result = dailyEngine.build(
        ArchiveDailyChangeInput(
          sampleMode: false,
          capacityWedgeActive: true,
          realSavedMomentCount: 2,
          capacityMomentCount: 2,
          capacityEvidenceCount: 2,
          mostCommonPullReasonId: CapacityPullReasonIds.feltResponsible,
          pullReasonRecordCount: 2,
          state: const ArchiveDailyChangeState(lastSeenAt: null),
          entries: [_capacityEntry('e0'), _capacityEntry('e1')],
          pullReasonRecords: [
            _pullReason('e0', [CapacityPullReasonIds.feltResponsible]),
            _pullReason('e1', [CapacityPullReasonIds.feltResponsible]),
          ],
          costRecords: const [],
          outcomeRecords: [
            CapacityDecisionOutcomeRecord(
              sourceEntryId: 'e1',
              outcomeId: CapacityDecisionOutcomeIds.delayed,
              status: CapacityDecisionOutcomeStatus.answered,
              createdAt: DateTime(2026, 6, 16, 12),
              updatedAt: DateTime(2026, 6, 16, 12),
            ),
          ],
          boundarySelection: null,
          activationFitRecord: null,
          weeklyReviewAvailable: false,
          quickCaptureFrictionRecord: null,
        ),
      );
      expect(result.hasFeature, isTrue);
      expect(
        result.changeLine,
        ArchiveDailyChangeCopy.repeatedPullNewOutcomeLine,
      );
    });

    test('urgency with later cost uses sharper line', () {
      expect(
        ArchiveDailyChangeCopy.samePullLaterCostLine,
        contains('later cost repeated'),
      );
    });

    test('fit partly handles not settled copy', () {
      expect(
        ArchiveDailyChangeCopy.fitPartlyNewMomentLine,
        contains('not settled'),
      );
    });

    test('quick capture still work says fewer moments not more', () {
      expect(
        ArchiveDailyChangeCopy.quickCaptureStillWorkLine,
        contains('fewer moments, not more'),
      );
    });
  });

  group('Alternative mapping', () {
    test('each pull reason maps to a specific fixed next move', () {
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

    test('selected boundary response wins over generic alternative', () {
      final selection = CapacityBoundaryResponseSelection(
        responseId: CapacityBoundaryResponseIds.cannotAnswerNow,
        selectedAt: DateTime(2026, 6, 16),
      );
      final boundaryText = CapacityBoundaryResponseCopy.textForId(
        selection.responseId,
      );
      expect(boundaryText, isNotNull);
      expect(
        boundaryText,
        isNot(
          ArchiveDailyChangeCopy.alternativeBodyForPull(
            CapacityPullReasonIds.soundedUrgent,
          ),
        ),
      );
    });
  });

  group('Privacy copy honesty', () {
    test('journal encrypted claim is in allowed promises', () {
      expect(
        PrivacyCopyPolicy.journalEncryptedAtRest.toLowerCase(),
        contains('archive file on this device is encrypted'),
      );
    });

    test('allowed promises pass policy scan', () {
      _expectNoBannedCopy([
        PrivacyCopyPolicy.privateByDefault,
        PrivacyCopyPolicy.journalEncryptedAtRest,
        PrivacyCopyPolicy.transcriptionAnalysisWhenUsed,
        PrivacyCopyPolicy.exportDeleteAnytime,
        PrivacyCopyPolicy.lockArchiveMe,
      ]);
    });
  });

  group('Commercial readiness docs', () {
    test('paid checklist requires 2-3 paid-intent users', () {
      final doc = File(
        'docs/PAID_LAUNCH_DECISION_CHECKLIST.md',
      ).readAsStringSync();
      expect(doc, contains('2–3 clear paid-intent users'));
      expect(doc, contains('RevenueCat readiness comes after return'));
      expect(
        doc,
        contains('Do not enable paid launch from one maybe-paid user'),
      );
    });
  });

  group('Dependency maintenance doc', () {
    test('dependency maintenance plan exists', () {
      expect(File('docs/DEPENDENCY_MAINTENANCE_PLAN.md').existsSync(), isTrue);
      final doc = File(
        'docs/DEPENDENCY_MAINTENANCE_PLAN.md',
      ).readAsStringSync();
      expect(doc.toLowerCase(), contains('deferred during testflight'));
    });
  });

  group('Guardrails', () {
    test('beta readiness copy passes banned phrase scan', () {
      _expectNoBannedCopy([
        ...AcquisitionStartCopy.capacityVisibleStrings(),
        ...CapacityReturnTriggerCopy.allVisibleStrings(),
        ...ArchiveDailyChangeCopy.allVisibleStrings(),
        ArchivePositioningCopy.wedgeHeadline,
      ]);
    });

    test('return trigger engine 1/3 copy passes guardrails', () {
      const engine = CapacityReturnTriggerEngine();
      final result = engine.build(
        const CapacityReturnTriggerInput(
          sampleMode: false,
          screenshotMode: false,
          capacityWedgeActive: true,
          capacityMomentCount: 1,
          surface: CapacityReturnTriggerSurface.archiveHome,
        ),
      );
      _expectNoBannedCopy([result.title, result.body, result.primaryCtaLabel]);
    });
  });
}
