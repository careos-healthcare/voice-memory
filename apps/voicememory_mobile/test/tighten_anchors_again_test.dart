import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:voicememory_mobile/features/beta_proof_feedback/beta_proof_feedback_model.dart';
import 'package:voicememory_mobile/features/beta_proof_feedback/beta_proof_feedback_store.dart';
import 'package:voicememory_mobile/features/beta_repair_lab/beta_repair_lab_engine.dart';
import 'package:voicememory_mobile/features/beta_repair_lab/beta_repair_lab_model.dart';
import 'package:voicememory_mobile/features/beta_repair_lab/beta_repair_lab_store.dart';
import 'package:voicememory_mobile/features/evidence_anchors/evidence_anchor_engine.dart';
import 'package:voicememory_mobile/features/evidence_trail_clarity/evidence_trail_clarity_engine.dart';
import 'package:voicememory_mobile/features/evidence_weighting/evidence_weighting_copy.dart';
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

class _MemoryPrefs extends MobilePrefsStore {
  _MemoryPrefs()
    : super(file: File('test/tmp/tighten_anchors_again/unused.json'));

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

List<JournalEntry> _genericStressEntries() {
  final base = _now;
  return [
    _entry(
      '1',
      'Stress at work again today.',
      createdAt: base.subtract(const Duration(days: 2)),
      concreteObservation: 'stress',
    ),
    _entry(
      '2',
      'Work stress again this afternoon.',
      createdAt: base.subtract(const Duration(days: 1)),
      concreteObservation: 'stress',
    ),
    _entry(
      '3',
      'Stress again after work today.',
      createdAt: base,
      concreteObservation: 'stress',
    ),
  ];
}

List<JournalEntry> _genericEmotionalEntries() {
  final base = _now;
  return [
    _entry(
      '1',
      'I felt bad after work today.',
      createdAt: base.subtract(const Duration(days: 2)),
      concreteObservation: 'felt bad',
    ),
    _entry(
      '2',
      'Felt bad again at work.',
      createdAt: base.subtract(const Duration(days: 1)),
      concreteObservation: 'felt bad',
    ),
    _entry(
      '3',
      'Feeling bad again today.',
      createdAt: base,
      concreteObservation: 'felt bad',
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
          'test/tmp/tighten_anchors_again/${DateTime.now().microsecondsSinceEpoch}_journal.json',
      prefsPath:
          'test/tmp/tighten_anchors_again/${DateTime.now().microsecondsSinceEpoch}_prefs.json',
      skipRevenueCat: true,
    );
    ArchiveBetaMissionGate.enabledOverride = true;
    await BetaProofFeedbackStore.resetForTest(prefs);
  });

  tearDown(() async {
    ArchiveBetaMissionGate.resetForTest();
    await BetaRepairLabStore.resetForTest(prefs);
    await BetaProofFeedbackStore.resetForTest(prefs);
  });

  group('AnchorSpecificityGuard', () {
    test('rejects generic one-word anchors', () {
      expect(AnchorSpecificityGuard.isProofLevelEligible('stress'), isFalse);
      expect(AnchorSpecificityGuard.isProofLevelEligible('work'), isFalse);
      expect(AnchorSpecificityGuard.isProofLevelEligible('pressure'), isFalse);
    });

    test('rejects UI/system-like anchors', () {
      expect(
        AnchorSpecificityGuard.isProofLevelEligible(
          EvidenceWeightingCopy.explanationRepeated,
        ),
        isFalse,
      );
      expect(
        AnchorSpecificityGuard.isProofLevelEligible(
          'saved privately on device',
        ),
        isFalse,
      );
      expect(
        AnchorSpecificityGuard.isProofLevelEligible('open the paywall screen'),
        isFalse,
      );
    });

    test('accepts specific repeated anchors', () {
      expect(
        AnchorSpecificityGuard.isProofLevelEligible(
          'checking the same message before sending',
        ),
        isTrue,
      );
      expect(
        AnchorSpecificityGuard.isProofLevelEligible(
          'avoiding replying after feeling pressure',
        ),
        isTrue,
      );
      expect(
        AnchorSpecificityGuard.isProofLevelEligible(
          'said yes when I had no capacity for one more thing',
        ),
        isTrue,
      );
    });
  });

  group('Tighten anchors again proof gating', () {
    test('generic one-word anchor does not produce useful or strong proof', () {
      final calibration = ProofConfidenceCalibrationEngine.build(
        entries: _genericStressEntries(),
        beliefSurfaceVisible: true,
        source: 'test',
        now: _now,
      );
      expect(calibration.isProofLevel, isFalse);
      expect(
        ProofConfidenceCalibrationEngine.shouldShowUsefulProofSurface(
          calibration: calibration,
          hasSafeAnchor: calibration.hasSafeAnchor,
        ),
        isFalse,
      );
    });

    test('generic emotional anchor is downgraded to watchOnly', () {
      final calibration = ProofConfidenceCalibrationEngine.build(
        entries: _genericEmotionalEntries(),
        beliefSurfaceVisible: true,
        source: 'test',
        now: _now,
      );
      expect(calibration.level, ProofConfidenceLevel.watchOnly);
      expect(calibration.isWatchOnly, isTrue);
    });

    test('generic repeated entries still do not become useful proof', () {
      final match = PatternMatchQualityEngine.build(
        entries: _genericStressEntries(),
        beliefSurfaceVisible: true,
        source: 'test',
        now: _now,
      );
      expect(match.shouldShowAsProof, isFalse);
      expect(
        EvidenceAnchorEngine.build(
          entries: _genericStressEntries(),
          beliefSurfaceVisible: true,
          source: 'test',
          now: _now,
        ).hasSafeAnchor,
        isFalse,
      );
    });

    test('specific repeated anchor can still become strong proof', () {
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

    test('too vague feedback keeps similar weak anchor blocked', () async {
      final entries = _specificRepeatEntries();
      await BetaProofFeedbackStore.forPrefs(prefs).saveAnswer(
        surface: BetaProofFeedbackSurface.timelineProofMoment,
        feedbackType: BetaProofFeedbackType.tooVague,
        entryCount: entries.length,
      );
      final calibration = ProofConfidenceCalibrationEngine.build(
        entries: entries,
        beliefSurfaceVisible: true,
        source: 'test',
        calibrationFeedback: BetaProofFeedbackType.tooVague,
        now: _now,
      );
      expect(
        ProofConfidenceCalibrationEngine.shouldShowUsefulProofSurface(
          calibration: calibration,
          hasSafeAnchor: calibration.hasSafeAnchor,
        ),
        isFalse,
      );
    });

    test('not relevant feedback keeps similar weak anchor blocked', () async {
      final entries = _specificRepeatEntries();
      await BetaProofFeedbackStore.forPrefs(prefs).saveAnswer(
        surface: BetaProofFeedbackSurface.timelineProofMoment,
        feedbackType: BetaProofFeedbackType.notRelevant,
        entryCount: entries.length,
      );
      final calibration = ProofConfidenceCalibrationEngine.build(
        entries: entries,
        beliefSurfaceVisible: true,
        source: 'test',
        calibrationFeedback: BetaProofFeedbackType.notRelevant,
        now: _now,
      );
      expect(calibration.level, ProofConfidenceLevel.corrected);
      expect(
        ProofConfidenceCalibrationEngine.shouldShowUsefulProofSurface(
          calibration: calibration,
          hasSafeAnchor: calibration.hasSafeAnchor,
        ),
        isFalse,
      );
    });

    test('softening specific entries retain proof-level anchors', () {
      final entries = [
        ..._specificRepeatEntries(),
        _entry(
          '4',
          'Same capacity pressure came back but it felt easier to stop this time.',
          createdAt: _now.subtract(const Duration(hours: 4)),
        ),
      ];
      final extraction = EvidenceAnchorEngine.build(
        entries: entries,
        beliefSurfaceVisible: true,
        source: 'test',
        now: _now,
      );
      expect(extraction.hasSafeAnchor, isTrue);
      final calibration = ProofConfidenceCalibrationEngine.build(
        entries: entries,
        beliefSurfaceVisible: true,
        source: 'test',
        now: _now,
      );
      expect(calibration.isWatchOnly, isFalse);
      expect(calibration.leadCopy, isNotNull);
    });

    test('evidence trail pricing modes cannot override rejected anchor', () {
      expect(
        EvidenceTrailClarityEngine.shouldShow(
          input: _repairInput(confidenceLevel: ProofConfidenceLevel.watchOnly),
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
    });

    test('record surface priority keeps one proof guidance card', () {
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
    });
  });
}
