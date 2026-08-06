import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:voicememory_mobile/features/archive_timeline_spine/archive_timeline_spine_engine.dart';
import 'package:voicememory_mobile/features/beta_proof_lift/beta_proof_lift_engine.dart';
import 'package:voicememory_mobile/features/beta_proof_lift/beta_proof_lift_model.dart';
import 'package:voicememory_mobile/features/correction_memory/correction_memory_model.dart';
import 'package:voicememory_mobile/features/evidence_anchors/evidence_anchor_model.dart';
import 'package:voicememory_mobile/features/evidence_weighting/evidence_weighting_model.dart';
import 'package:voicememory_mobile/features/pattern_match_quality/pattern_match_quality_copy.dart';
import 'package:voicememory_mobile/features/pattern_match_quality/pattern_match_quality_model.dart';
import 'package:voicememory_mobile/features/proof_caution_guard/proof_caution_guard_analytics.dart';
import 'package:voicememory_mobile/features/proof_caution_guard/proof_caution_guard_copy.dart';
import 'package:voicememory_mobile/features/proof_caution_guard/proof_caution_guard_engine.dart';
import 'package:voicememory_mobile/features/proof_caution_guard/proof_caution_guard_model.dart';
import 'package:voicememory_mobile/features/proof_confidence_calibration/proof_confidence_calibration_copy.dart';
import 'package:voicememory_mobile/features/proof_confidence_calibration/proof_confidence_calibration_engine.dart';
import 'package:voicememory_mobile/features/proof_confidence_calibration/proof_confidence_calibration_model.dart';
import 'package:voicememory_mobile/features/timeline_proof_moment/timeline_proof_moment_engine.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';

const _strongRepeat =
    'I had no capacity but I said yes again to the extra meeting today.';
final _now = DateTime(2026, 6, 12, 12);

JournalEntry _entry(
  String id,
  String transcript, {
  DateTime? createdAt,
  String mood = 'thoughtful',
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

List<JournalEntry> _fourSofteningEntries() => [
  ..._threeRelatedEntries(anchor: _now.subtract(const Duration(days: 5))),
  _entry(
    '4',
    'Same capacity pressure came back but it felt easier to stop this time.',
    createdAt: _now.subtract(const Duration(days: 1)),
  ),
];

ProofConfidenceCalibrationResult _watchOnlyCalibration({int entryCount = 3}) =>
    ProofConfidenceCalibrationResult(
      shouldCalibrate: true,
      entryCount: entryCount,
      source: 'test',
      level: ProofConfidenceLevel.watchOnly,
      primaryCopy: ProofConfidenceCalibrationCopy.watchOnly,
      displayCopy: ProofConfidenceCalibrationCopy.watchOnly,
      hasSafeAnchor: true,
      hasMatchQuality: true,
      hasCorrection: false,
      hasFreshReturn: false,
    );

PatternMatchQualityResult _groundedMatchQuality({
  int entryCount = 3,
  List<PatternMatchWeakReason> weakReasons = const [],
}) => PatternMatchQualityResult(
  shouldResolve: true,
  entryCount: entryCount,
  source: 'test',
  score: 40,
  confidenceBand: PatternMatchConfidenceBand.weak,
  matchedDimensions: const [
    PatternMatchDimension.sameBehaviour,
    PatternMatchDimension.sameFeeling,
  ],
  weakReasons: weakReasons,
  safeExplanation: PatternMatchQualityCopy.weak,
  shouldShowAsProof: false,
  shouldShowAsWatchOnly: true,
);

EvidenceAnchorExtractionResult _safeAnchors({
  List<EvidenceAnchor>? anchors,
  bool hasChangeAnchor = false,
}) => EvidenceAnchorExtractionResult(
  shouldExtract: true,
  entryCount: 3,
  source: 'test',
  anchors:
      anchors ??
      const [
        EvidenceAnchor(
          id: 'a1',
          type: EvidenceAnchorType.repeat,
          label: 'Returned',
          safeSummary: 'Said yes when capacity was already full.',
          strength: 0.8,
          recencyWeight: 0.9,
          sourceCount: 2,
          isUserCorrected: false,
          isFreshReturn: false,
          isSafeForDisplay: true,
        ),
      ],
  safeSummaries: const ['Said yes when capacity was already full.'],
  usesFallback: false,
  hasSafeAnchor: true,
  hasRecentAnchor: true,
  hasCorrectionAnchor: false,
  hasChangeAnchor: hasChangeAnchor,
);

EvidenceWeightingResult _recentWeighting({int entryCount = 4}) =>
    EvidenceWeightingResult(
      entryCount: entryCount,
      hasConfirmedRepeat: true,
      hasRecentEntry: true,
      hasOlderEntry: true,
      hasSofteningSignal: true,
      hasQuietSignal: false,
      primaryState: EvidenceWeightState.repeated,
      secondaryStates: const [EvidenceWeightState.softened],
      shouldShow: true,
    );

void main() {
  final analyticsEvents = <({String event, Map<String, Object> props})>[];

  setUp(() {
    ProofCautionGuardAnalytics.resetForTest();
    ProofCautionGuardAnalytics.captureForTest = (event, props) {
      analyticsEvents.add((event: event, props: props));
    };
    analyticsEvents.clear();
  });

  tearDown(() {
    ProofCautionGuardAnalytics.resetForTest();
  });

  group('ProofCautionGuardEngine upgrades', () {
    test('watchOnly with 3 entries + safe anchor + 2 dimensions upgrades', () {
      final result = ProofCautionGuardEngine.apply(
        calibration: _watchOnlyCalibration(),
        matchQuality: _groundedMatchQuality(),
        hasSafeAnchor: true,
        hasConfirmedRepeat: true,
        isDegraded: false,
        userMarkedNotRelevant: false,
        anchorExtraction: _safeAnchors(),
      );

      expect(result.applied, isTrue);
      expect(result.originalLevel, ProofConfidenceLevel.watchOnly);
      expect(
        result.adjustedLevel,
        anyOf(ProofConfidenceLevel.emerging, ProofConfidenceLevel.useful),
      );
      expect(result.adjustedLevel, isNot(ProofConfidenceLevel.strong));
    });

    test(
      'emerging with 4 entries + change anchor + recent return upgrades',
      () {
        final calibration = ProofConfidenceCalibrationResult(
          shouldCalibrate: true,
          entryCount: 4,
          source: 'test',
          level: ProofConfidenceLevel.emerging,
          primaryCopy: ProofConfidenceCalibrationCopy.emerging,
          displayCopy: ProofConfidenceCalibrationCopy.emerging,
          hasSafeAnchor: true,
          hasMatchQuality: true,
          hasCorrection: false,
          hasFreshReturn: false,
        );
        final matchQuality = PatternMatchQualityResult(
          shouldResolve: true,
          entryCount: 4,
          source: 'test',
          score: 50,
          confidenceBand: PatternMatchConfidenceBand.emerging,
          matchedDimensions: const [
            PatternMatchDimension.sameBehaviour,
            PatternMatchDimension.sameFeeling,
          ],
          weakReasons: const [],
          safeExplanation: PatternMatchQualityCopy.emerging,
          shouldShowAsProof: false,
          shouldShowAsWatchOnly: false,
        );

        final result = ProofCautionGuardEngine.apply(
          calibration: calibration,
          matchQuality: matchQuality,
          hasSafeAnchor: true,
          hasConfirmedRepeat: true,
          isDegraded: false,
          userMarkedNotRelevant: false,
          anchorExtraction: _safeAnchors(
            hasChangeAnchor: true,
            anchors: const [
              EvidenceAnchor(
                id: 'change',
                type: EvidenceAnchorType.softening,
                label: 'Softening',
                safeSummary: 'Change: felt easier to stop this time.',
                strength: 0.82,
                recencyWeight: 0.9,
                sourceCount: 2,
                isUserCorrected: false,
                isFreshReturn: false,
                isSafeForDisplay: true,
              ),
            ],
          ),
          evidenceWeighting: _recentWeighting(),
        );

        expect(result.applied, isTrue);
        expect(result.adjustedLevel, ProofConfidenceLevel.useful);
        expect(
          result.calibration.primaryCopy,
          ProofCautionGuardCopy.upgradeBody,
        );
        expect(result.adjustedLevel, isNot(ProofConfidenceLevel.strong));
      },
    );

    test('never upgrades to strong', () {
      final result = ProofCautionGuardEngine.apply(
        calibration: _watchOnlyCalibration(),
        matchQuality: _groundedMatchQuality(),
        hasSafeAnchor: true,
        hasConfirmedRepeat: true,
        isDegraded: false,
        userMarkedNotRelevant: false,
        anchorExtraction: _safeAnchors(),
      );

      expect(result.adjustedLevel, isNot(ProofConfidenceLevel.strong));
    });
  });

  group('ProofCautionGuardEngine blocks', () {
    test('not relevant blocks upgrade', () {
      final result = ProofCautionGuardEngine.apply(
        calibration: _watchOnlyCalibration(),
        matchQuality: _groundedMatchQuality(
          weakReasons: const [PatternMatchWeakReason.userMarkedNotRelevant],
        ),
        hasSafeAnchor: true,
        hasConfirmedRepeat: true,
        isDegraded: false,
        userMarkedNotRelevant: true,
        anchorExtraction: _safeAnchors(),
        trackAnalytics: true,
      );

      expect(result.applied, isFalse);
      expect(
        result.blockedReason,
        ProofCautionGuardBlockedReason.userMarkedNotRelevant,
      );
    });

    test('no safe anchor blocks upgrade', () {
      final result = ProofCautionGuardEngine.apply(
        calibration: _watchOnlyCalibration(),
        matchQuality: _groundedMatchQuality(
          weakReasons: const [PatternMatchWeakReason.noSafeAnchorAvailable],
        ),
        hasSafeAnchor: false,
        hasConfirmedRepeat: true,
        isDegraded: false,
        userMarkedNotRelevant: false,
        anchorExtraction: _safeAnchors(),
        trackAnalytics: true,
      );

      expect(result.applied, isFalse);
      expect(result.blockedReason, ProofCautionGuardBlockedReason.noSafeAnchor);
    });

    test('generic wording only blocks upgrade', () {
      final result = ProofCautionGuardEngine.apply(
        calibration: _watchOnlyCalibration(),
        matchQuality: _groundedMatchQuality(
          weakReasons: const [
            PatternMatchWeakReason.onlyGenericWordingOverlaps,
          ],
        ),
        hasSafeAnchor: true,
        hasConfirmedRepeat: true,
        isDegraded: false,
        userMarkedNotRelevant: false,
        anchorExtraction: _safeAnchors(),
        trackAnalytics: true,
      );

      expect(result.applied, isFalse);
      expect(
        result.blockedReason,
        ProofCautionGuardBlockedReason.genericWordingOnly,
      );
    });

    test('degraded blocks upgrade', () {
      final result = ProofCautionGuardEngine.apply(
        calibration: _watchOnlyCalibration(),
        matchQuality: _groundedMatchQuality(),
        hasSafeAnchor: true,
        hasConfirmedRepeat: true,
        isDegraded: true,
        userMarkedNotRelevant: false,
        anchorExtraction: _safeAnchors(),
        trackAnalytics: true,
      );

      expect(result.applied, isFalse);
      expect(
        result.blockedReason,
        ProofCautionGuardBlockedReason.degradedTranscript,
      );
    });

    test('unrelated entries block upgrade', () {
      final result = ProofCautionGuardEngine.apply(
        calibration: _watchOnlyCalibration(),
        matchQuality: _groundedMatchQuality(
          weakReasons: const [PatternMatchWeakReason.entriesTooUnrelated],
        ),
        hasSafeAnchor: true,
        hasConfirmedRepeat: false,
        isDegraded: false,
        userMarkedNotRelevant: false,
        anchorExtraction: _safeAnchors(),
        trackAnalytics: true,
      );

      expect(result.applied, isFalse);
      expect(
        result.blockedReason,
        ProofCautionGuardBlockedReason.entriesUnrelated,
      );
    });

    test('correction background blocks upgrade', () {
      final result = ProofCautionGuardEngine.apply(
        calibration: _watchOnlyCalibration(),
        matchQuality: _groundedMatchQuality(),
        hasSafeAnchor: true,
        hasConfirmedRepeat: true,
        isDegraded: false,
        userMarkedNotRelevant: false,
        correction: const CorrectionMemorySnapshot(
          state: CorrectionMemoryState.faded,
          returnedAfterFaded: false,
          entryCountAtCapture: 3,
        ),
        anchorExtraction: _safeAnchors(),
        trackAnalytics: true,
      );

      expect(result.applied, isFalse);
      expect(
        result.blockedReason,
        ProofCautionGuardBlockedReason.correctionBackground,
      );
    });
  });

  group('ProofCautionGuardAnalytics', () {
    test('metadata-only analytics', () {
      ProofCautionGuardEngine.apply(
        calibration: _watchOnlyCalibration(),
        matchQuality: _groundedMatchQuality(),
        hasSafeAnchor: true,
        hasConfirmedRepeat: true,
        isDegraded: false,
        userMarkedNotRelevant: false,
        anchorExtraction: _safeAnchors(),
        trackAnalytics: true,
      );

      ProofCautionGuardEngine.apply(
        calibration: _watchOnlyCalibration(),
        matchQuality: _groundedMatchQuality(
          weakReasons: const [PatternMatchWeakReason.noSafeAnchorAvailable],
        ),
        hasSafeAnchor: false,
        hasConfirmedRepeat: true,
        isDegraded: false,
        userMarkedNotRelevant: false,
        anchorExtraction: _safeAnchors(),
        trackAnalytics: true,
      );

      expect(
        analyticsEvents.map((e) => e.event),
        containsAll([
          ProofCautionGuardAnalytics.appliedEvent,
          ProofCautionGuardAnalytics.blockedEvent,
        ]),
      );

      final applied = analyticsEvents
          .firstWhere((e) => e.event == ProofCautionGuardAnalytics.appliedEvent)
          .props;
      expect(
        applied.keys,
        containsAll(['source', 'original_level', 'adjusted_level', 'reason']),
      );
      expect(applied.keys, isNot(contains('transcript')));

      final blocked = analyticsEvents
          .firstWhere((e) => e.event == ProofCautionGuardAnalytics.blockedEvent)
          .props;
      expect(blocked.keys, contains('blocked_reason'));
    });
  });

  group('Downstream integration', () {
    setUp(() {
      ArchiveBetaMissionGate.enabledOverride = false;
    });

    tearDown(() {
      ArchiveBetaMissionGate.resetForTest();
    });

    test('TimelineProofMoment uses guarded level', () {
      final entries = _threeRelatedEntries();
      final spine = ArchiveTimelineSpineEngine.build(
        entries: entries,
        beliefSurfaceVisible: true,
        source: 'test',
        now: _now,
      );
      expect(spine, isNotNull);

      final moment = TimelineProofMomentEngine.buildFromSpine(
        spine: spine,
        entries: entries,
        source: 'test',
        now: _now,
      );
      expect(moment, isNotNull);
      expect(moment!.body, moment.proofConfidenceCalibration.displayCopy);
    });

    test('BetaProofLift uses guarded level', () {
      final lift = BetaProofLiftEngine.build(
        entries: _fourSofteningEntries(),
        surface: BetaProofLiftSurface.timelineProofMoment,
        source: 'test',
        beliefSurfaceVisible: true,
        now: _now,
      );
      expect(lift.body, lift.proofConfidenceCalibration.displayCopy);
      expect(lift.proofConfidenceCalibration.isWatchOnly, isFalse);
    });

    test('ArchiveTimelineSpine uses guarded level', () {
      final spine = ArchiveTimelineSpineEngine.build(
        entries: _threeRelatedEntries(),
        beliefSurfaceVisible: true,
        source: 'test',
        now: _now,
      );
      expect(spine, isNotNull);
      expect(spine!.explanation, spine.proofConfidenceCalibration.displayCopy);
      expect(spine.proofConfidenceCalibration.isWatchOnly, isFalse);
    });
  });

  group('Protected areas', () {
    test('no threshold constant changes in pattern match quality engine', () {
      final source = File(
        'lib/features/pattern_match_quality/pattern_match_quality_engine.dart',
      ).readAsStringSync();
      expect(source, contains('static const minEntryCount = 2'));
      expect(
        source,
        contains('if (score >= 75) return PatternMatchConfidenceBand.strong'),
      );
      expect(
        source,
        contains('if (score >= 55) return PatternMatchConfidenceBand.solid'),
      );
    });

    test('no medical claims in guard copy', () {
      expect(
        ProofSurfaceAdviceGuard.passes(ProofCautionGuardCopy.upgradeBody),
        isTrue,
      );
      expect(
        ProofCautionGuardCopy.passesMedicalGuard(
          ProofCautionGuardCopy.upgradeBody,
        ),
        isTrue,
      );
    });

    test(
      'calibration engine wires guard without changing resolve thresholds',
      () {
        final source = File(
          'lib/features/proof_confidence_calibration/proof_confidence_calibration_engine.dart',
        ).readAsStringSync();
        expect(source, contains('ProofCautionGuardEngine.guard'));
        expect(source.contains('if (score >= 75)'), isFalse);
      },
    );
  });
}
