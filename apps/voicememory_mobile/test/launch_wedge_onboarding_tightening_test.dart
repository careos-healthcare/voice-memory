import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/capacity_loop/before_yes_copy.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_activation_fit_copy.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_beta_mission_copy.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_boundary_response_copy.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_cost_copy.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_launch_wedge_gates.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_loop_copy.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_pull_reason_copy.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_pull_reason_engine.dart';
import 'package:voicememory_mobile/features/capacity_loop/capacity_three_moment_copy.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/product/acquisition_start_copy.dart';
import 'package:voicememory_mobile/product/archive_positioning_copy.dart';
import 'package:voicememory_mobile/product/loop_acquisition_copy.dart';
import 'package:voicememory_mobile/product/loop_mode_copy.dart';
import 'package:voicememory_mobile/product/testflight_invite_copy.dart';

const _requiredPhrases = [
  'Catch the yes before it costs you',
  'See what keeps returning',
  'Save a yes moment',
  'See what pulled you in',
  'Review what changed',
  'Save 3 yes moments',
  'Review your yes loop',
  'Does this feel accurate',
  'see what returned',
  'before checking your capacity',
  'later cost',
  'default yes pause',
];

const _forbiddenPhrases = [
  'yes-before-capacity loop',
  'capacity loop activation',
  'beta signal dashboard',
  'productivity',
  'therapy',
  'diagnosis',
  'medical',
  'treatment',
  'mental health score',
  'wellbeing score',
  'clinical score',
  'buy now',
  'subscribe now',
  'pro is active',
  'archiveme knows',
  'testimonial',
  'streak',
  'overcommitted professionals',
  'busy professionals',
];

JournalEntry _capacityEntry(String id) => JournalEntry(
      id: id,
      createdAt: DateTime(2026, 6, 12, 12),
      transcript: 'I felt pulled to agree again even when I was tired today.',
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

Iterable<String> _launchWedgeUserFacingCopy() sync* {
  yield* AcquisitionStartCopy.capacityVisibleStrings();
  yield ArchivePositioningCopy.umbrellaHeadline;
  yield* CapacityThreeMomentCopy.allVisibleStrings();
  yield CapacityLoopCopy.title;
  yield CapacityLoopCopy.subtitle;
  yield CapacityLoopCopy.saveYesMomentCta;
  yield CapacityLoopCopy.reviewLoopCta;
  yield* CapacityActivationFitCopy.allVisibleStrings();
  yield* CapacityBetaMissionCopy.allVisibleStrings();
  yield LoopAcquisitionCopy.capacityYes.headline;
  yield LoopAcquisitionCopy.capacityYes.subheadline;
  yield LoopAcquisitionCopy.capacityYes.cta;
  yield* LoopAcquisitionCopy.capacityYes.bullets;
  yield LoopModeCopy.capacityHandoffTitle;
  yield LoopModeCopy.capacityHandoffBody;
  yield LoopModeCopy.capacityHandoffCta;
  yield LoopModeCopy.capacityHandoffPrompt;
  yield LoopModeCopy.capacityJourneyTitle;
  yield LoopModeCopy.capacityReviewTitle;
  yield LoopModeCopy.capacityReviewSubtitle;
  yield BeforeYesCopy.recordPrompt;
  yield CapacityBoundaryResponseCopy.title;
  yield CapacityBoundaryResponseCopy.cardEyebrow;
  yield CapacityBoundaryResponseCopy.loopSectionTitle;
  yield CapacityPullReasonCopy.cardTitle;
  yield CapacityPullReasonCopy.cardBody;
  yield CapacityCostCopy.cardTitle;
  yield TestFlightInviteCopy.shortText(TestFlightInviteVariant.capacityYes);
}

void _expectContainsRequired(Iterable<String> visible) {
  final joined = visible.join('\n').toLowerCase();
  for (final phrase in _requiredPhrases) {
    expect(
      joined,
      contains(phrase.toLowerCase()),
      reason: 'launch wedge copy should include "$phrase"',
    );
  }
}

void _expectNoForbidden(Iterable<String> visible) {
  for (final text in visible) {
    final lower = text.toLowerCase();
    for (final phrase in _forbiddenPhrases) {
      if (phrase == 'therapy' && RegExp('not therapy').hasMatch(lower)) {
        continue;
      }
      expect(
        lower,
        isNot(contains(phrase)),
        reason: 'must not contain "$phrase" in "$text"',
      );
    }
  }
}

void main() {
  group('Launch wedge onboarding copy guard', () {
    test('includes required launch wedge phrases', () {
      _expectContainsRequired(_launchWedgeUserFacingCopy());
    });

    test('excludes internal and banned phrases', () {
      _expectNoForbidden(_launchWedgeUserFacingCopy());
    });

    test('acquisition start uses first-use headline and save CTA', () {
      expect(
        AcquisitionStartCopy.capacityTitle,
        ArchivePositioningCopy.firstUseTitle,
      );
      expect(
        AcquisitionStartCopy.capacityStartCta,
        ArchivePositioningCopy.firstUseCta,
      );
      expect(
        AcquisitionStartCopy.capacityBody.toLowerCase(),
        contains('real moment'),
      );
      expect(
        AcquisitionStartCopy.capacityHowItWorksSteps,
        contains('Save one small moment'),
      );
    });

    test('three moment card uses simplified progress copy', () {
      expect(CapacityThreeMomentCopy.cardTitle, 'Save 3 yes moments');
      expect(
        CapacityThreeMomentCopy.progressLabel(1, target: 3),
        '1 of 3 yes moments saved',
      );
    });

    test('activation fit uses accurate framing', () {
      expect(CapacityActivationFitCopy.cardTitle, 'Does this feel accurate?');
      expect(
        CapacityActivationFitCopy.cardBody.toLowerCase(),
        contains('does this loop fit'),
      );
    });

    test('beta mission uses tightened title and body', () {
      expect(CapacityBetaMissionCopy.title, '7-day capacity test');
      expect(
        CapacityBetaMissionCopy.subtitle.toLowerCase(),
        contains('save 3 yes moments'),
      );
    });
  });

  group('Launch wedge first-session gating', () {
    test('early activation phase for wedge users under 3 moments', () {
      expect(
        CapacityLaunchWedgeGates.inEarlyActivationPhase(
          capacityWedgeActive: true,
          capacityMomentCount: 0,
        ),
        isTrue,
      );
      expect(
        CapacityLaunchWedgeGates.inEarlyActivationPhase(
          capacityWedgeActive: true,
          capacityMomentCount: 2,
        ),
        isTrue,
      );
      expect(
        CapacityLaunchWedgeGates.inEarlyActivationPhase(
          capacityWedgeActive: true,
          capacityMomentCount: 3,
        ),
        isFalse,
      );
    });

    test('pull reason hidden on archive home during early wedge session', () {
      const engine = CapacityPullReasonEngine();
      final result = engine.buildFromJournal(
        entries: [_capacityEntry('e0')],
        capacityLoopActive: true,
        capacityCohortActive: false,
        records: const [],
      );
      expect(result.hasCard, isTrue);
      expect(result.showOnArchiveHome, isFalse);
    });

    test('pull reason can show on archive home after 3 moments', () {
      const engine = CapacityPullReasonEngine();
      final result = engine.buildFromJournal(
        entries: [
          _capacityEntry('e0'),
          _capacityEntry('e1'),
          _capacityEntry('e2'),
        ],
        capacityLoopActive: true,
        capacityCohortActive: false,
        records: const [],
      );
      expect(result.hasCard, isTrue);
      expect(result.showOnArchiveHome, isTrue);
    });
  });
}
