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
import 'package:voicememory_mobile/features/capacity_loop/quick_capture_friction_models.dart';
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
      expect(lower, isNot(contains(phrase)), reason: '"$text" contains "$phrase"');
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
}) =>
    ArchiveHomePriorityInput(
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
      capacityLoopVisible: true,
      capacityPullReasonVisible: true,
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
  group('Onboarding fallback', () {
    test('fallback title maps the moments that keep repeating', () {
      expect(
        AcquisitionStartCopy.capacityTitle,
        contains('Map the moments that keep repeating'),
      );
    });

    test('fallback body explains save one real moment', () {
      expect(
        AcquisitionStartCopy.capacityBody.toLowerCase(),
        allOf(
          contains('save one real moment'),
          contains('connects to over time'),
        ),
      );
    });

    test('fallback CTA says Save first moment', () {
      expect(AcquisitionStartCopy.capacityStartCta, 'Save first moment');
    });

    test('fallback how it works uses See how it works', () {
      expect(AcquisitionStartCopy.capacityHowItWorksCta, 'See how it works');
      expect(
        AcquisitionStartCopy.capacityHowItWorksSteps,
        ArchivePositioningCopy.howItWorksSteps,
      );
    });

    test('fallback onboarding avoids internal terms', () {
      final joined = AcquisitionStartCopy.capacityVisibleStrings()
          .join('\n')
          .toLowerCase();
      for (final term in _forbiddenOnboardingTerms) {
        expect(joined, isNot(contains(term)), reason: 'contains $term');
      }
    });
  });

  group('Activation fallback', () {
    test('1/3 copy says wait and do not force it', () {
      expect(
        CapacityReturnTriggerCopy.archiveHomeBody(1, target: 3).toLowerCase(),
        allOf(
          contains('wait for the next real one'),
          contains('do not force'),
        ),
      );
    });

    test('1/3 primary action can be Done for now', () {
      expect(
        CapacityReturnTriggerCopy.archiveHomePrimaryCta,
        'Done for now',
      );
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
      expect(result.primaryCtaLabel, 'Done for now');
      expect(result.primaryDismisses, isTrue);
    });

    test('2/3 copy says one more real moment', () {
      expect(
        CapacityReturnTriggerCopy.archiveHomeBody(2, target: 3).toLowerCase(),
        contains('one more real moment'),
      );
      expect(CapacityReturnTriggerCopy.archiveHomeTitle(2), 'Two moments saved.');
    });

    test('under 3 moments only one primary capacity card', () {
      const engine = ArchiveHomePriorityEngine();
      final plan = engine.build(_calmHomeInput());
      expect(ArchiveHomeCardPriority.onlyOneCapacityPrimaryCard(plan), isTrue);
      expect(
        plan.primarySections,
        contains(ArchiveHomeSectionId.capacityThreeMomentActivation),
      );
    });

    test('three moment engine uses Done for now at 1/3', () {
      const engine = CapacityThreeMomentEngine();
      final result = engine.build(
        const CapacityThreeMomentInput(
          sampleMode: false,
          capacityWedgeActive: true,
          capacityEvidenceCount: 1,
          capacityMomentCount: 1,
        ),
      );
      expect(result.primaryCtaLabel, 'Done for now');
      expect(result.primaryDismisses, isTrue);
      expect(result.showReviewSecondary, isTrue);
    });
  });

  group('Daily change fallback', () {
    const dailyEngine = ArchiveDailyChangeEngine();

    test('distinguishes repeated pull with new outcome', () {
      expect(
        ArchiveDailyChangeCopy.repeatedPullNewOutcomeLine.toLowerCase(),
        allOf(contains('outcome changed'), contains('showed up again')),
      );
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
      expect(result.changeLine, ArchiveDailyChangeCopy.repeatedPullNewOutcomeLine);
    });

    test('distinguishes same pull with same outcome', () {
      expect(
        ArchiveDailyChangeCopy.samePullSameOutcomeLine.toLowerCase(),
        allOf(contains('same pull'), contains('same answer')),
      );
    });

    test('distinguishes pull with later cost', () {
      expect(
        ArchiveDailyChangeCopy.samePullLaterCostLine.toLowerCase(),
        allOf(contains('pull repeated'), contains('later cost repeated')),
      );
    });

    test('partly fit uses not settled copy', () {
      expect(
        ArchiveDailyChangeCopy.fitPartlyNewMomentLine.toLowerCase(),
        allOf(contains('partly fits'), contains('not settled')),
      );
    });

    test('quick capture still work maps to less reflection not more', () {
      expect(
        ArchiveDailyChangeCopy.quickCaptureStillWorkLine.toLowerCase(),
        allOf(
          contains('less reflection'),
          contains('not more'),
          contains('save only the pull'),
        ),
      );
    });
  });

  group('Alternative mapping fallback', () {
    test('selected boundary response wins over generic alternative', () {
      final selection = CapacityBoundaryResponseSelection(
        responseId: CapacityBoundaryResponseIds.cannotAnswerNow,
        selectedAt: DateTime(2026, 6, 16),
      );
      final boundaryText =
          CapacityBoundaryResponseCopy.textForId(selection.responseId);
      expect(boundaryText, isNotNull);
      expect(
        boundaryText,
        isNot(ArchiveDailyChangeCopy.alternativeBodyForPull(
          CapacityPullReasonIds.soundedUrgent,
        )),
      );
    });

    test('urgency maps to delay before replying', () {
      expect(
        ArchiveDailyChangeCopy.alternativeLabelForPull(
          CapacityPullReasonIds.soundedUrgent,
        ),
        'Delay before replying',
      );
      expect(
        ArchiveDailyChangeCopy.alternativeBodyForPull(
          CapacityPullReasonIds.soundedUrgent,
        ),
        contains('Do not answer immediately'),
      );
    });

    test('responsibility maps to check capacity first', () {
      expect(
        ArchiveDailyChangeCopy.alternativeLabelForPull(
          CapacityPullReasonIds.feltResponsible,
        ),
        'Check capacity first',
      );
      expect(
        ArchiveDailyChangeCopy.alternativeBodyForPull(
          CapacityPullReasonIds.feltResponsible,
        ),
        contains('actual capacity'),
      );
    });

    test('disappointment maps to name the limit', () {
      expect(
        ArchiveDailyChangeCopy.alternativeLabelForPull(
          CapacityPullReasonIds.avoidDisappoint,
        ),
        'Name the limit',
      );
    });

    test('squeeze-it-in maps to move something first', () {
      expect(
        ArchiveDailyChangeCopy.alternativeLabelForPull(
          CapacityPullReasonIds.squeezeItIn,
        ),
        'Move something first',
      );
    });

    test('opportunity maps to check trade-off', () {
      expect(
        ArchiveDailyChangeCopy.alternativeLabelForPull(
          CapacityPullReasonIds.wantedOpportunity,
        ),
        'Check the trade-off',
      );
    });

    test('answered-too-quickly maps to pause first answer', () {
      expect(
        ArchiveDailyChangeCopy.alternativeLabelForPull(
          CapacityPullReasonIds.answeredTooQuickly,
        ),
        'Pause the first answer',
      );
    });

    test('something_else maps to mark the pull first', () {
      expect(
        ArchiveDailyChangeCopy.alternativeLabelForPull(
          CapacityPullReasonIds.somethingElse,
        ),
        'Mark the pull first',
      );
      expect(
        ArchiveDailyChangeCopy.alternativeBodyForPull(
          CapacityPullReasonIds.somethingElse,
        ),
        contains('Name the pull later'),
      );
    });

    test('still_work quick capture maps to save only the pull label', () {
      expect(ArchiveDailyChangeCopy.labelSaveOnlyPull, 'Save only the pull');
      expect(
        ArchiveDailyChangeCopy.altQuickCaptureStillWork,
        contains('Skip the full story'),
      );
    });
  });

  group('Beta decision doc', () {
    test('beta four failure response rules doc exists', () {
      final doc = File('../../docs/BETA_FOUR_FAILURE_RESPONSE_RULES.md');
      expect(doc.existsSync(), isTrue);
      final text = doc.readAsStringSync();
      expect(text, contains('Users do not understand'));
      expect(text, contains('Do not enable RevenueCat'));
      expect(text, contains('Do not add new dashboards'));
    });
  });

  group('Guardrails', () {
    test('pack copy passes banned phrase scan', () {
      _expectNoBannedCopy([
        ...AcquisitionStartCopy.capacityVisibleStrings(),
        ...CapacityReturnTriggerCopy.allVisibleStrings(),
        ...ArchiveDailyChangeCopy.allVisibleStrings(),
      ]);
    });
  });
}
