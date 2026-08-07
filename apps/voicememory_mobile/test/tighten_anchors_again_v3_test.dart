import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:voicememory_mobile/features/beta_proof_feedback/beta_proof_feedback_model.dart';
import 'package:voicememory_mobile/features/beta_proof_lift/beta_proof_lift_engine.dart';
import 'package:voicememory_mobile/features/beta_proof_lift/beta_proof_lift_model.dart';
import 'package:voicememory_mobile/features/beta_repair_lab/beta_repair_lab_model.dart';
import 'package:voicememory_mobile/features/beta_repair_lab/beta_repair_lab_store.dart';
import 'package:voicememory_mobile/features/evidence_anchors/evidence_anchor_engine.dart';
import 'package:voicememory_mobile/features/evidence_trail_clarity/evidence_trail_clarity_engine.dart';
import 'package:voicememory_mobile/features/pattern_match_quality/pattern_match_quality_engine.dart';
import 'package:voicememory_mobile/features/pattern_match_quality/pattern_match_quality_model.dart';
import 'package:voicememory_mobile/features/pricing_validation/pricing_validation_engine.dart';
import 'package:voicememory_mobile/features/proof_confidence_calibration/proof_confidence_calibration_engine.dart';
import 'package:voicememory_mobile/features/proof_confidence_calibration/proof_confidence_calibration_model.dart';
import 'package:voicememory_mobile/features/proof_floor_rescue/proof_floor_rescue_engine.dart';
import 'package:voicememory_mobile/features/proof_floor_rescue/proof_floor_rescue_model.dart';
import 'package:voicememory_mobile/features/proof_protection/anchor_specificity_guard.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_engine.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_model.dart';
import 'package:voicememory_mobile/features/timeline_proof_moment/timeline_proof_moment_engine.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'support/test_storage_sandbox.dart';

class _MemoryPrefs extends MobilePrefsStore {
  _MemoryPrefs()
    : super(file: File('test/tmp/tighten_anchors_again_v3/unused.json'));

  final Map<String, Map<String, dynamic>> maps = {};

  @override
  Future<Map<String, dynamic>?> readMap(String key) async => maps[key];

  @override
  Future<void> writeMap(String key, Map<String, dynamic> value) async {
    maps[key] = value;
  }
}

const _strongRepeat =
    'I had no capacity but I said yes again to the extra meeting today.';
final _now = DateTime(2026, 6, 12, 12);

JournalEntry _entry(
  String id,
  String transcript, {
  DateTime? createdAt,
  String concreteObservation = 'Work pressure showed up again today.',
}) => JournalEntry(
  id: id,
  createdAt: createdAt ?? _now,
  transcript: transcript,
  durationSeconds: 24,
  localAudioPath: '/tmp/$id.m4a',
  reflection: Reflection(
    mood: 'thoughtful',
    emotionalIntensity: 2,
    recurringThemes: const ['work'],
    exactLanguagePattern: '',
    concreteObservation: concreteObservation,
    repeatedSignal: '',
  ),
  syncStatus: SyncStatus.localOnly,
);

List<JournalEntry> _specificRepeatEntries({DateTime? anchor}) {
  final base = anchor ?? _now;
  return [
    _entry(
      '1',
      _strongRepeat,
      createdAt: base.subtract(const Duration(days: 2)),
    ),
    _entry(
      '2',
      'Same thing — said yes when I had no capacity for one more thing.',
      createdAt: base.subtract(const Duration(days: 1)),
    ),
    _entry(
      '3',
      'I said yes again even though I had no capacity for one more ask.',
      createdAt: base,
    ),
  ];
}

List<JournalEntry> _keptCheckingEntries() {
  final base = _now;
  return [
    _entry(
      '1',
      'I kept checking again before bed but never opened the message.',
      createdAt: base.subtract(const Duration(days: 2)),
      concreteObservation: 'kept checking',
    ),
    _entry(
      '2',
      'Kept checking again tonight without replying to the message.',
      createdAt: base.subtract(const Duration(days: 1)),
      concreteObservation: 'kept checking',
    ),
    _entry(
      '3',
      'I kept checking again and still avoided sending the reply.',
      createdAt: base,
      concreteObservation: 'kept checking',
    ),
  ];
}

List<JournalEntry> _emotionalContextEntries() {
  final base = _now;
  return [
    _entry(
      '1',
      'Work stress kept coming back after another busy day at the office.',
      createdAt: base.subtract(const Duration(days: 2)),
      concreteObservation: 'work stress kept coming back',
    ),
    _entry(
      '2',
      'The same pressure at work showed up again today.',
      createdAt: base.subtract(const Duration(days: 1)),
      concreteObservation: 'the same pressure at work',
    ),
    _entry(
      '3',
      'Feeling pressure before work again this morning.',
      createdAt: base,
      concreteObservation: 'feeling pressure before work',
    ),
  ];
}

BetaRepairLabVisibilityInput _repairInput({
  ProofConfidenceLevel confidenceLevel = ProofConfidenceLevel.watchOnly,
  BetaProofFeedbackType? feedbackType,
}) => BetaRepairLabVisibilityInput(
  mode: BetaRepairLabMode.evidenceTrailTimelineClarity,
  entryCount: 4,
  source: 'test',
  isPro: false,
  isRecording: false,
  isDegradedTranscriptState: false,
  whatChangedQuestionActive: false,
  patternReviewInboxHasActiveItems: false,
  hasTimelineProofVisible: true,
  hasConfirmedRepeat: true,
  confidenceLevel: confidenceLevel,
  hasUsefulProofFeedback: feedbackType == BetaProofFeedbackType.useful,
  feedbackType: feedbackType,
  isNegativeFeedback:
      feedbackType == BetaProofFeedbackType.tooVague ||
      feedbackType == BetaProofFeedbackType.notRelevant,
  betaMissionEnabled: true,
);

void main() {
  late TestStorageSandbox sandbox;
  late _MemoryPrefs prefs;

  setUp(() async {
    sandbox = TestStorageSandbox.create();
    prefs = _MemoryPrefs();
    ArchiveBetaMissionGate.enabledOverride = true;
    await BetaRepairLabStore.resetForTest(prefs);
    await AppServices.resetForTest(
      journalPath: sandbox.journalPath,
      prefsPath: sandbox.prefsPath,
      skipRevenueCat: true,
    );
    ArchiveBetaMissionGate.enabledOverride = true;
  });

  tearDown(() => sandbox.dispose());
  tearDown(() async {
    ArchiveBetaMissionGate.resetForTest();
    await BetaRepairLabStore.resetForTest(prefs);
  });

  group('AnchorSpecificityGuard v3 emotional and vague behavior', () {
    test('emotional context-only long phrase fails', () {
      expect(
        AnchorSpecificityGuard.isProofLevelEligible(
          'feeling pressure before work again this morning',
        ),
        isFalse,
      );
      expect(
        AnchorSpecificityGuard.isProofLevelEligible(
          'felt unsettled today at the office after another busy day',
        ),
        isFalse,
      );
    });

    test('work stress kept coming back fails', () {
      expect(
        AnchorSpecificityGuard.isProofLevelEligible(
          'work stress kept coming back',
        ),
        isFalse,
      );
    });

    test('the same pressure at work fails', () {
      expect(
        AnchorSpecificityGuard.isProofLevelEligible(
          'the same pressure at work',
        ),
        isFalse,
      );
    });

    test('checking again fails', () {
      expect(
        AnchorSpecificityGuard.isProofLevelEligible('checking again'),
        isFalse,
      );
    });

    test('kept checking fails', () {
      expect(
        AnchorSpecificityGuard.isProofLevelEligible('kept checking'),
        isFalse,
      );
    });

    test('putting it off again fails', () {
      expect(
        AnchorSpecificityGuard.isProofLevelEligible('putting it off again'),
        isFalse,
      );
    });

    test('said yes again fails', () {
      expect(
        AnchorSpecificityGuard.isProofLevelEligible('said yes again'),
        isFalse,
      );
    });
  });

  group('AnchorSpecificityGuard v3 behavior-specific passes', () {
    test('specific message-before-sending anchor passes', () {
      expect(
        AnchorSpecificityGuard.isProofLevelEligible(
          'checking the same message before sending',
        ),
        isTrue,
      );
    });

    test('specific reply-after-pressure anchor passes', () {
      expect(
        AnchorSpecificityGuard.isProofLevelEligible(
          'avoiding replying after feeling pressure',
        ),
        isTrue,
      );
    });

    test('specific email-before-done anchor passes', () {
      expect(
        AnchorSpecificityGuard.isProofLevelEligible(
          're-reading the email before feeling done',
        ),
        isTrue,
      );
    });

    test('specific capacity boundary anchor passes', () {
      expect(
        AnchorSpecificityGuard.isProofLevelEligible(
          'said yes when I had no capacity for one more thing',
        ),
        isTrue,
      );
    });

    test('specific physical-check anchor passes', () {
      expect(
        AnchorSpecificityGuard.isProofLevelEligible(
          'checking the door twice before leaving',
        ),
        isTrue,
      );
      expect(
        AnchorSpecificityGuard.isProofLevelEligible(
          'delaying the same invoice after opening it',
        ),
        isTrue,
      );
      expect(
        AnchorSpecificityGuard.isProofLevelEligible(
          'rewriting the same reply before sending',
        ),
        isTrue,
      );
    });
  });

  group('Tighten anchors again v3 proof gating', () {
    test('strong match quality cannot rescue vague anchor', () {
      final entries = _emotionalContextEntries();
      final match = PatternMatchQualityEngine.build(
        entries: entries,
        beliefSurfaceVisible: true,
        source: 'test',
        now: _now,
      );
      expect(
        match.confidenceBand,
        anyOf(
          PatternMatchConfidenceBand.solid,
          PatternMatchConfidenceBand.strong,
          PatternMatchConfidenceBand.weak,
        ),
      );
      expect(match.shouldShowAsProof, isFalse);
      expect(
        EvidenceAnchorEngine.build(
          entries: entries,
          beliefSurfaceVisible: true,
          source: 'test',
          now: _now,
        ).hasSafeAnchor,
        isFalse,
      );
    });

    test('confirmed repeat cannot rescue vague anchor', () {
      final entries = _keptCheckingEntries();
      final match = PatternMatchQualityEngine.build(
        entries: entries,
        beliefSurfaceVisible: true,
        source: 'test',
        now: _now,
      );
      expect(match.shouldShowAsProof, isFalse);
      expect(
        EvidenceAnchorEngine.build(
          entries: entries,
          beliefSurfaceVisible: true,
          source: 'test',
          now: _now,
        ).hasSafeAnchor,
        isFalse,
      );
      expect(
        AnchorSpecificityGuard.isProofLevelEligible('kept checking'),
        isFalse,
      );
    });

    test('rejected anchor produces watchOnly or no useful proof', () {
      final calibration = ProofConfidenceCalibrationEngine.build(
        entries: _emotionalContextEntries(),
        beliefSurfaceVisible: true,
        source: 'test',
        now: _now,
      );
      expect(calibration.hasSafeAnchor, isFalse);
      expect(calibration.isProofLevel, isFalse);
      expect(
        ProofConfidenceCalibrationEngine.shouldShowUsefulProofSurface(
          calibration: calibration,
          hasSafeAnchor: calibration.hasSafeAnchor,
        ),
        isFalse,
      );
      expect(
        calibration.level,
        anyOf(ProofConfidenceLevel.watchOnly, ProofConfidenceLevel.corrected),
      );
    });

    test(
      'rejected anchor does not show What Changed or first proof payoff',
      () {
        final entries = _keptCheckingEntries();
        final lift = BetaProofLiftEngine.build(
          entries: entries,
          surface: BetaProofLiftSurface.timelineProofMoment,
          source: 'test',
          beliefSurfaceVisible: true,
          now: _now,
        );
        expect(lift.hasSafeAnchor, isFalse);
        expect(lift.shouldShow, isFalse);
        expect(
          BetaProofLiftEngine.shouldShow(
            result: lift,
            parentVisible: true,
            timelineProofVisible: true,
            firstProofPayoffVisible: true,
            isRecording: false,
            isDegradedTranscriptState: false,
            isPostSaveDegradedState: false,
            whatChangedQuestionActive: false,
            patternReviewInboxHasActiveItems: false,
          ),
          isFalse,
        );

        final payoff = BetaProofLiftEngine.build(
          entries: entries,
          surface: BetaProofLiftSurface.firstProofPayoff,
          source: 'test',
          beliefSurfaceVisible: true,
          now: _now,
        );
        expect(payoff.hasSafeAnchor, isFalse);
        expect(payoff.shouldShow, isFalse);
      },
    );

    test(
      'pro evidence-trail pricing modes cannot override rejected anchor',
      () {
        expect(
          EvidenceTrailClarityEngine.shouldShow(
            input: _repairInput(
              confidenceLevel: ProofConfidenceLevel.watchOnly,
            ),
            hasSafeAnchor: false,
          ),
          isFalse,
        );
        BetaRepairLabStore.repairModeOverrideForTest = 'pricingValidation';
        expect(
          PricingValidationEngine.shouldShow(
            input: _repairInput(
              confidenceLevel: ProofConfidenceLevel.watchOnly,
              feedbackType: BetaProofFeedbackType.tooVague,
            ),
            hasProEngagement: true,
          ),
          isFalse,
        );
        expect(
          ProofFloorRescueEngine.blocksProMonetization(
            ProofFloorRescueInput(
              entryCount: 4,
              source: 'test',
              isPro: false,
              hasTimelineProofVisible: true,
              hasConfirmedRepeat: true,
              confidenceLevel: ProofConfidenceLevel.watchOnly,
              hasSafeAnchor: false,
              hasLowMatchQuality: true,
              usefulFeedbackCount: 0,
              latestFeedbackType: BetaProofFeedbackType.tooVague,
              feedbackAnsweredToday: true,
              isRecording: false,
              isDegradedTranscriptState: false,
              whatChangedQuestionActive: false,
              patternReviewInboxHasActiveItems: false,
            ),
          ),
          isTrue,
        );
      },
    );

    test('existing specific confirmed-repeat proof path still passes', () {
      final calibration = ProofConfidenceCalibrationEngine.build(
        entries: _specificRepeatEntries(),
        beliefSurfaceVisible: true,
        source: 'test',
        now: _now,
      );
      expect(calibration.hasSafeAnchor, isTrue);
      expect(
        calibration.level,
        anyOf(ProofConfidenceLevel.useful, ProofConfidenceLevel.strong),
      );
      final timeline = TimelineProofMomentEngine.build(
        entries: _specificRepeatEntries(),
        beliefSurfaceVisible: true,
        source: 'record',
        now: _now,
      );
      expect(timeline?.hasSafeAnchor, isTrue);
      if (calibration.isProofLevel) {
        expect(timeline?.shouldShow, isTrue);
      }
    });

    test(
      'record screen remains capture-first without stacking extra cards',
      () {
        final audit = SurfacePriorityEngine.auditRecordReady(
          entryCount: 4,
          source: 'record',
          candidates: SurfacePriorityCandidates.recordReady(
            firstMomentCapture: false,
            secondMomentReturn: false,
            lowFrictionReturn: false,
            whatToNoticeNext: false,
            betaTodaySummary: false,
            openCapturePromptChips: false,
            captureFreedomLine: false,
            timelineProofMoment: true,
            archiveTimelineSpine: false,
            timelinePositioning: false,
            currentRelevance: false,
            correctionMemory: false,
            notRelevantRecovery: false,
            proofQualityResponse: false,
            evidenceWeighting: false,
            proofSpecificity: false,
            presentDayRelevance: false,
            patternConfidence: false,
            betaTesterReport: false,
            proEvidenceValue: false,
            privateReportProBridge: false,
            suppressLegacyEducation: false,
            betaProofLift: true,
          ),
        );
        expect(audit.proofCardKey, 'timelineProofMoment');
        expect(audit.guidanceCardKey, isNull);
      },
    );
  });
}
