import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:voicememory_mobile/features/beta_proof_feedback/beta_proof_feedback_copy.dart';
import 'package:voicememory_mobile/features/beta_proof_feedback/beta_proof_feedback_model.dart';
import 'package:voicememory_mobile/features/beta_repair_lab/beta_repair_lab_model.dart';
import 'package:voicememory_mobile/features/beta_repair_lab/beta_repair_lab_store.dart';
import 'package:voicememory_mobile/features/evidence_trail_clarity/evidence_trail_clarity_engine.dart';
import 'package:voicememory_mobile/features/pricing_validation/pricing_validation_engine.dart';
import 'package:voicememory_mobile/features/proof_confidence_calibration/proof_confidence_calibration_engine.dart';
import 'package:voicememory_mobile/features/proof_confidence_calibration/proof_confidence_calibration_model.dart';
import 'package:voicememory_mobile/features/proof_quality_response/proof_quality_response_copy.dart';
import 'package:voicememory_mobile/features/proof_relevance_repair/proof_relevance_repair_copy.dart';
import 'package:voicememory_mobile/features/proof_relevance_repair/proof_relevance_repair_engine.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_engine.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_model.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'support/test_storage_sandbox.dart';

class _MemoryPrefs extends MobilePrefsStore {
  _MemoryPrefs()
    : super(file: File('test/tmp/proof_relevance_repair/unused.json'));

  final Map<String, Map<String, dynamic>> maps = {};

  @override
  Future<Map<String, dynamic>?> readMap(String key) async => maps[key];

  @override
  Future<void> writeMap(String key, Map<String, dynamic> value) async {
    maps[key] = value;
  }
}

const _behaviorPhrase = 'said yes when I had no capacity for one more thing';
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

List<JournalEntry> _specificRepeatEntries() => [
  _entry('1', _strongRepeat, createdAt: _now.subtract(const Duration(days: 2))),
  _entry(
    '2',
    'Same thing — said yes when I had no capacity for one more thing.',
    createdAt: _now.subtract(const Duration(days: 1)),
  ),
  _entry(
    '3',
    'I said yes again even though I had no capacity for one more ask.',
    createdAt: _now,
  ),
];

BetaRepairLabVisibilityInput _repairInput() => BetaRepairLabVisibilityInput(
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
  confidenceLevel: ProofConfidenceLevel.watchOnly,
  hasUsefulProofFeedback: false,
  feedbackType: BetaProofFeedbackType.tooVague,
  isNegativeFeedback: true,
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

  group('ProofRelevanceRepairCopy', () {
    test('strong proof copy includes noticed this repeated lead', () {
      final copy = ProofRelevanceRepairEngine.composeDisplayCopy(
        level: ProofConfidenceLevel.strong,
        behaviorPhrase: _behaviorPhrase,
        hasSafeAnchor: true,
        leadCopy: null,
        primaryCopy: 'fallback',
      );
      expect(copy, contains(ProofRelevanceRepairCopy.strongLead));
    });

    test('strong proof copy includes the specific behaviour phrase', () {
      final copy = ProofRelevanceRepairEngine.composeDisplayCopy(
        level: ProofConfidenceLevel.useful,
        behaviorPhrase: _behaviorPhrase,
        hasSafeAnchor: true,
        leadCopy: null,
        primaryCopy: 'fallback',
      );
      expect(copy, contains(_behaviorPhrase));
    });

    test('strong proof copy includes why this appeared', () {
      final copy = ProofRelevanceRepairEngine.composeDisplayCopy(
        level: ProofConfidenceLevel.strong,
        behaviorPhrase: _behaviorPhrase,
        hasSafeAnchor: true,
        leadCopy: null,
        primaryCopy: 'fallback',
      );
      expect(copy, contains(ProofRelevanceRepairCopy.whyAppearedPrefix));
    });

    test('why line uses cautious similar-moments wording', () {
      expect(
        ProofRelevanceRepairCopy.whyAppearedLine,
        contains('similar moments mention this same behaviour'),
      );
      expect(
        ProofRelevanceRepairCopy.whyAppearedLine,
        isNot(contains('this is your pattern')),
      );
    });

    test('proof card asks does this feel accurate', () {
      expect(
        BetaProofFeedbackCopy.question,
        ProofRelevanceRepairCopy.relevanceQuestion,
      );
    });

    test('buttons include Yes Too vague Not relevant', () {
      expect(BetaProofFeedbackCopy.answerUseful, 'Yes');
      expect(BetaProofFeedbackCopy.answerTooVague, 'Too vague');
      expect(BetaProofFeedbackCopy.answerNotRelevant, 'Not relevant');
      expect(ProofRelevanceRepairCopy.relevanceFeedbackTypes, [
        BetaProofFeedbackType.useful,
        BetaProofFeedbackType.tooVague,
        BetaProofFeedbackType.notRelevant,
      ]);
    });

    test('too vague response waits for more specific evidence', () {
      expect(
        BetaProofFeedbackCopy.responseFor(BetaProofFeedbackType.tooVague),
        ProofRelevanceRepairCopy.tooVagueResponse,
      );
      expect(
        ProofQualityResponseCopy.stillTooVagueFollowUp,
        contains('more specific evidence'),
      );
    });

    test('not relevant response says not treat as useful proof', () {
      expect(
        BetaProofFeedbackCopy.responseFor(BetaProofFeedbackType.notRelevant),
        ProofRelevanceRepairCopy.notRelevantResponse,
      );
    });

    test('lower-confidence proof uses softer may be noticing copy', () {
      final copy = ProofRelevanceRepairEngine.composeDisplayCopy(
        level: ProofConfidenceLevel.emerging,
        behaviorPhrase: _behaviorPhrase,
        hasSafeAnchor: true,
        leadCopy: null,
        primaryCopy: 'fallback',
      );
      expect(copy, contains(ProofRelevanceRepairCopy.softerLead));
      expect(copy, isNot(contains(ProofRelevanceRepairCopy.strongLead)));
    });

    test('copy does not use diagnosis coaching or therapy language', () {
      for (final text in ProofRelevanceRepairCopy.allVisibleStrings()) {
        expect(ProofSurfaceAdviceGuard.passes(text), isTrue, reason: text);
        final lower = text.toLowerCase();
        for (final banned in ProofRelevanceRepairCopy.bannedRelevancePhrases) {
          expect(lower.contains(banned), isFalse, reason: text);
        }
      }
    });
  });

  group('Proof relevance repair integration', () {
    test('specific confirmed-repeat proof uses relevance copy', () {
      final calibration = ProofConfidenceCalibrationEngine.build(
        entries: _specificRepeatEntries(),
        beliefSurfaceVisible: true,
        source: 'test',
        now: _now,
      );
      expect(calibration.hasSafeAnchor, isTrue);
      expect(
        calibration.displayCopy,
        contains(ProofRelevanceRepairCopy.strongLead),
      );
      expect(calibration.displayCopy, contains('no capacity'));
      expect(
        calibration.displayCopy,
        contains(ProofRelevanceRepairCopy.whyAppearedPrefix),
      );
    });

    test(
      'pro pricing evidence trail behaviour unchanged for rejected anchor',
      () {
        expect(
          EvidenceTrailClarityEngine.shouldShow(
            input: _repairInput(),
            hasSafeAnchor: false,
          ),
          isFalse,
        );
        BetaRepairLabStore.repairModeOverrideForTest = 'pricingValidation';
        expect(
          PricingValidationEngine.shouldShow(
            input: _repairInput(),
            hasProEngagement: true,
          ),
          isFalse,
        );
      },
    );

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
