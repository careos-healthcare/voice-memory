import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:voicememory_mobile/features/beta_proof_feedback/beta_proof_feedback_model.dart';
import 'package:voicememory_mobile/features/beta_repair_lab/beta_repair_lab_model.dart';
import 'package:voicememory_mobile/features/beta_repair_lab/beta_repair_lab_store.dart';
import 'package:voicememory_mobile/features/evidence_anchors/evidence_anchor_engine.dart';
import 'package:voicememory_mobile/features/evidence_trail_clarity/evidence_trail_clarity_engine.dart';
import 'package:voicememory_mobile/features/pattern_match_quality/pattern_match_quality_engine.dart';
import 'package:voicememory_mobile/features/pricing_validation/pricing_validation_engine.dart';
import 'package:voicememory_mobile/features/proof_confidence_calibration/proof_confidence_calibration_engine.dart';
import 'package:voicememory_mobile/features/proof_confidence_calibration/proof_confidence_calibration_model.dart';
import 'package:voicememory_mobile/features/proof_floor_rescue/proof_floor_rescue_engine.dart';
import 'package:voicememory_mobile/features/proof_floor_rescue/proof_floor_rescue_model.dart';
import 'package:voicememory_mobile/features/proof_protection/anchor_specificity_guard.dart';
import 'package:voicememory_mobile/features/timeline_proof_moment/timeline_proof_moment_engine.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';

class _MemoryPrefs extends MobilePrefsStore {
  _MemoryPrefs()
    : super(file: File('test/tmp/tighten_anchors_again_v2/unused.json'));

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
  String mood = 'thoughtful',
  String concreteObservation = 'Work pressure showed up again today.',
}) => JournalEntry(
  id: id,
  createdAt: createdAt ?? _now,
  transcript: transcript,
  durationSeconds: 24,
  localAudioPath: '/tmp/$id.m4a',
  reflection: Reflection(
    mood: mood,
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

List<JournalEntry> _genericWorkPressureEntries() {
  final base = _now;
  return [
    _entry(
      '1',
      'Work pressure again after the meeting.',
      createdAt: base.subtract(const Duration(days: 2)),
      concreteObservation: 'work pressure',
    ),
    _entry(
      '2',
      'Felt pressure again at work today.',
      createdAt: base.subtract(const Duration(days: 1)),
      concreteObservation: 'felt pressure again',
    ),
    _entry(
      '3',
      'Work pressure showed up again this afternoon.',
      createdAt: base,
      concreteObservation: 'work pressure',
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
  late _MemoryPrefs prefs;

  setUp(() async {
    prefs = _MemoryPrefs();
    ArchiveBetaMissionGate.enabledOverride = true;
    await BetaRepairLabStore.resetForTest(prefs);
    await AppServices.resetForTest(
      journalPath:
          'test/tmp/tighten_anchors_again_v2/${DateTime.now().microsecondsSinceEpoch}_journal.json',
      prefsPath:
          'test/tmp/tighten_anchors_again_v2/${DateTime.now().microsecondsSinceEpoch}_prefs.json',
      skipRevenueCat: true,
    );
    ArchiveBetaMissionGate.enabledOverride = true;
  });

  tearDown(() async {
    ArchiveBetaMissionGate.resetForTest();
    await BetaRepairLabStore.resetForTest(prefs);
  });

  group('AnchorSpecificityGuard v2 weak phrases', () {
    test('work pressure fails proof-level eligibility', () {
      expect(
        AnchorSpecificityGuard.isProofLevelEligible('work pressure'),
        isFalse,
      );
    });

    test('felt pressure again fails', () {
      expect(
        AnchorSpecificityGuard.isProofLevelEligible('felt pressure again'),
        isFalse,
      );
    });

    test('stress at work fails', () {
      expect(
        AnchorSpecificityGuard.isProofLevelEligible('stress at work'),
        isFalse,
      );
    });

    test('checking again fails', () {
      expect(
        AnchorSpecificityGuard.isProofLevelEligible('checking again'),
        isFalse,
      );
    });

    test('same thing again fails', () {
      expect(
        AnchorSpecificityGuard.isProofLevelEligible('same thing again'),
        isFalse,
      );
    });

    test('long generic phrase fails despite length', () {
      expect(
        AnchorSpecificityGuard.isProofLevelEligible(
          'felt pressure again at work today',
        ),
        isFalse,
      );
      expect(
        AnchorSpecificityGuard.isProofLevelEligible(
          'not sure what changed after another busy day at work',
        ),
        isFalse,
      );
    });

    test('generic-density rule rejects mostly generic phrases', () {
      expect(
        AnchorSpecificityGuard.hasGenericDensityTooHigh(
          'felt pressure again at work',
        ),
        isTrue,
      );
      expect(
        AnchorSpecificityGuard.isProofLevelEligible(
          'felt pressure again at work',
        ),
        isFalse,
      );
    });

    test('weak-context-only phrase fails', () {
      expect(
        AnchorSpecificityGuard.isWeakContextOnly('office pressure again'),
        isTrue,
      );
      expect(
        AnchorSpecificityGuard.isProofLevelEligible('office pressure again'),
        isFalse,
      );
      expect(
        AnchorSpecificityGuard.isProofLevelEligible('busy day at work'),
        isFalse,
      );
    });
  });

  group('AnchorSpecificityGuard v2 specific phrases', () {
    test('specific action object phrase passes', () {
      expect(
        AnchorSpecificityGuard.isProofLevelEligible(
          'checking the same message before sending',
        ),
        isTrue,
      );
    });

    test('specific action context phrase passes', () {
      expect(
        AnchorSpecificityGuard.isProofLevelEligible(
          'avoiding replying after feeling pressure',
        ),
        isTrue,
      );
      expect(
        AnchorSpecificityGuard.isProofLevelEligible(
          're-reading the email before feeling done',
        ),
        isTrue,
      );
    });

    test('specific boundary capacity phrase passes', () {
      expect(
        AnchorSpecificityGuard.isProofLevelEligible(
          'said yes when I had no capacity for one more thing',
        ),
        isTrue,
      );
      expect(
        AnchorSpecificityGuard.isProofLevelEligible(
          'putting off the same task after work pressure',
        ),
        isTrue,
      );
    });
  });

  group('Tighten anchors again v2 proof gating', () {
    test('confirmed repeat does not rescue generic anchor', () {
      final entries = _genericWorkPressureEntries();
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
    });

    test('rejected anchor produces watchOnly or no useful proof', () {
      final calibration = ProofConfidenceCalibrationEngine.build(
        entries: _genericWorkPressureEntries(),
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

    test('existing confirmed-repeat specific proof still passes', () {
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
  });
}
