import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:voicememory_mobile/features/beta_proof_feedback/beta_proof_feedback_model.dart';
import 'package:voicememory_mobile/features/beta_proof_feedback/beta_proof_feedback_store.dart';
import 'package:voicememory_mobile/features/beta_proof_lift/beta_proof_lift_engine.dart';
import 'package:voicememory_mobile/features/beta_proof_lift/beta_proof_lift_copy.dart';
import 'package:voicememory_mobile/features/beta_proof_lift/beta_proof_lift_model.dart';
import 'package:voicememory_mobile/features/pattern_match_quality/pattern_match_quality_model.dart';
import 'package:voicememory_mobile/features/beta_repair_lab/beta_repair_lab_engine.dart';
import 'package:voicememory_mobile/features/beta_repair_lab/beta_repair_lab_model.dart';
import 'package:voicememory_mobile/features/beta_repair_lab/beta_repair_lab_store.dart';
import 'package:voicememory_mobile/features/evidence_trail_clarity/evidence_trail_clarity_engine.dart';
import 'package:voicememory_mobile/features/pricing_validation/pricing_validation_engine.dart';
import 'package:voicememory_mobile/features/proof_confidence_calibration/proof_confidence_calibration_engine.dart';
import 'package:voicememory_mobile/features/proof_confidence_calibration/proof_confidence_calibration_model.dart';
import 'package:voicememory_mobile/features/proof_floor_rescue/proof_floor_rescue_engine.dart';
import 'package:voicememory_mobile/features/proof_floor_rescue/proof_floor_rescue_model.dart';
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
    : super(file: File('test/tmp/proof_protection_repair_v2/unused.json'));

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

JournalEntry _entry(String id, String transcript, {DateTime? createdAt}) =>
    JournalEntry(
      id: id,
      createdAt: createdAt ?? _now,
      transcript: transcript,
      durationSeconds: 24,
      localAudioPath: '/tmp/$id.m4a',
      reflection: const Reflection(
        mood: 'thoughtful',
        emotionalIntensity: 2,
        recurringThemes: ['work'],
        exactLanguagePattern: '',
        concreteObservation: 'Work pressure showed up again today.',
        repeatedSignal: '',
      ),
      syncStatus: SyncStatus.localOnly,
    );

List<JournalEntry> _threeRelatedEntries({DateTime? anchor}) {
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

BetaRepairLabVisibilityInput _repairInput({
  ProofConfidenceLevel confidenceLevel = ProofConfidenceLevel.watchOnly,
  BetaProofFeedbackType? feedbackType,
  bool hasTimelineProofVisible = true,
}) => BetaRepairLabVisibilityInput(
  mode: BetaRepairLabMode.evidenceTrailTimelineClarity,
  entryCount: 4,
  source: 'test',
  isPro: false,
  isRecording: false,
  isDegradedTranscriptState: false,
  whatChangedQuestionActive: false,
  patternReviewInboxHasActiveItems: false,
  hasTimelineProofVisible: hasTimelineProofVisible,
  hasConfirmedRepeat: true,
  confidenceLevel: confidenceLevel,
  hasUsefulProofFeedback: feedbackType == BetaProofFeedbackType.useful,
  feedbackType: feedbackType,
  isNegativeFeedback:
      feedbackType == BetaProofFeedbackType.tooVague ||
      feedbackType == BetaProofFeedbackType.notRelevant,
  betaMissionEnabled: true,
);

ProofFloorRescueInput _floorInput({
  ProofConfidenceLevel confidenceLevel = ProofConfidenceLevel.watchOnly,
  bool hasSafeAnchor = false,
  BetaProofFeedbackType? latestFeedbackType,
}) => ProofFloorRescueInput(
  entryCount: 4,
  source: 'test',
  isPro: false,
  hasTimelineProofVisible: true,
  hasConfirmedRepeat: true,
  confidenceLevel: confidenceLevel,
  hasSafeAnchor: hasSafeAnchor,
  hasLowMatchQuality: true,
  usefulFeedbackCount: 0,
  latestFeedbackType: latestFeedbackType,
  feedbackAnsweredToday: false,
  isRecording: false,
  isDegradedTranscriptState: false,
  whatChangedQuestionActive: false,
  patternReviewInboxHasActiveItems: false,
);

void main() {
  late TestStorageSandbox sandbox;
  late _MemoryPrefs prefs;

  setUp(() async {
    sandbox = TestStorageSandbox.create();
    prefs = _MemoryPrefs();
    await BetaRepairLabStore.resetForTest(prefs);
    await AppServices.resetForTest(
      journalPath: sandbox.journalPath,
      prefsPath: sandbox.prefsPath,
      skipRevenueCat: true,
    );
    ArchiveBetaMissionGate.enabledOverride = true;
    await BetaProofFeedbackStore.resetForTest(prefs);
  });

  tearDown(() => sandbox.dispose());
  tearDown(() async {
    ArchiveBetaMissionGate.resetForTest();
    await BetaRepairLabStore.resetForTest(prefs);
    await BetaProofFeedbackStore.resetForTest(prefs);
  });

  group('Proof protection repair v2 gates', () {
    test('watch_only never shows useful proof surface', () {
      final calibration = ProofConfidenceCalibrationResult(
        shouldCalibrate: true,
        entryCount: 4,
        source: 'test',
        level: ProofConfidenceLevel.watchOnly,
        primaryCopy: 'watch',
        displayCopy: 'watch',
        hasSafeAnchor: true,
        hasMatchQuality: true,
        hasCorrection: false,
        hasFreshReturn: false,
      );
      expect(
        ProofConfidenceCalibrationEngine.shouldShowUsefulProofSurface(
          calibration: calibration,
          hasSafeAnchor: true,
        ),
        isFalse,
      );
      expect(calibration.isProofLevel, isFalse);
    });

    test('watch_only blocks Pro monetization', () {
      expect(
        ProofFloorRescueEngine.blocksProMonetization(
          _floorInput(confidenceLevel: ProofConfidenceLevel.watchOnly),
        ),
        isTrue,
      );
    });

    test('no_safe_anchor blocks useful proof surface', () {
      final calibration = ProofConfidenceCalibrationEngine.build(
        entries: [
          _entry('1', 'Had a normal day.'),
          _entry('2', 'Walk after lunch.'),
        ],
        beliefSurfaceVisible: false,
        source: 'test',
        now: _now,
      );
      expect(calibration.hasSafeAnchor, isFalse);
      expect(
        ProofConfidenceCalibrationEngine.shouldShowUsefulProofSurface(
          calibration: calibration,
          hasSafeAnchor: false,
        ),
        isFalse,
      );
    });

    test('too vague feedback blocks useful proof resurfacing', () async {
      final entries = _threeRelatedEntries();
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
      expect(
        BetaRepairLabEngine.blocksProWhenProofProtectionActive(
          input: _repairInput(
            confidenceLevel: calibration.level,
            feedbackType: BetaProofFeedbackType.tooVague,
          ),
        ),
        isTrue,
      );
    });

    test('not relevant feedback blocks useful proof resurfacing', () async {
      final entries = _threeRelatedEntries();
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

    test('strong proof appears with confirmed repeat and safe anchor', () {
      final entries = _threeRelatedEntries();
      final calibration = ProofConfidenceCalibrationEngine.build(
        entries: entries,
        beliefSurfaceVisible: true,
        source: 'test',
        now: _now,
      );
      final timeline = TimelineProofMomentEngine.build(
        entries: entries,
        beliefSurfaceVisible: true,
        source: 'record',
        now: _now,
      );
      expect(calibration.hasSafeAnchor, isTrue);
      expect(
        calibration.level,
        anyOf(ProofConfidenceLevel.useful, ProofConfidenceLevel.strong),
      );
      if (calibration.isProofLevel) {
        expect(timeline?.shouldShow, isTrue);
        expect(timeline?.hasSafeAnchor, isTrue);
      }
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

    test('repair modes do not override proof protection', () async {
      BetaRepairLabStore.repairModeOverrideForTest =
          'evidenceTrailTimelineClarity';
      expect(
        EvidenceTrailClarityEngine.shouldShow(
          input: _repairInput(
            confidenceLevel: ProofConfidenceLevel.watchOnly,
            feedbackType: BetaProofFeedbackType.tooVague,
          ),
          hasSafeAnchor: false,
        ),
        isFalse,
      );
      BetaRepairLabStore.repairModeOverrideForTest = 'pricingValidation';
      expect(
        PricingValidationEngine.shouldShow(
          input: _repairInput(
            confidenceLevel: ProofConfidenceLevel.emerging,
            feedbackType: BetaProofFeedbackType.tooVague,
          ),
          hasProEngagement: true,
        ),
        isFalse,
      );
      BetaRepairLabStore.repairModeOverrideForTest =
          'proof_specificity_caution';
      expect(
        BetaRepairLabEngine.blocksProWhenProofProtectionActive(
          input: _repairInput(
            confidenceLevel: ProofConfidenceLevel.watchOnly,
            feedbackType: BetaProofFeedbackType.tooVague,
          ),
        ),
        isTrue,
      );
    });

    test('beta proof lift hidden without useful proof level', () {
      final result = BetaProofLiftResult(
        shouldShow: true,
        entryCount: 4,
        source: 'test',
        surface: BetaProofLiftSurface.timelineProofMoment,
        title: BetaProofLiftCopy.title,
        body: BetaProofLiftCopy.body,
        sections: const [],
        deltaRows: const [],
        hasSafeAnchor: false,
        hasDelta: false,
        hasCurrentRelevance: false,
        hasCorrection: false,
        patternMatchQuality: PatternMatchQualityResult.hidden(
          source: 'test',
          entryCount: 4,
        ),
        proofConfidenceCalibration: ProofConfidenceCalibrationResult(
          shouldCalibrate: true,
          entryCount: 4,
          source: 'test',
          level: ProofConfidenceLevel.watchOnly,
          primaryCopy: 'watch',
          displayCopy: 'watch',
          hasSafeAnchor: false,
          hasMatchQuality: true,
          hasCorrection: false,
          hasFreshReturn: false,
        ),
      );
      expect(
        BetaProofLiftEngine.shouldShow(
          result: result,
          parentVisible: true,
          timelineProofVisible: true,
          firstProofPayoffVisible: false,
          isRecording: false,
          isDegradedTranscriptState: false,
          isPostSaveDegradedState: false,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: false,
        ),
        isFalse,
      );
    });
  });
}
