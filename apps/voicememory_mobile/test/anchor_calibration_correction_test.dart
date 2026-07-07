import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/archive_timeline_spine/archive_timeline_spine_engine.dart';
import 'package:voicememory_mobile/features/beta_proof_feedback/beta_proof_feedback_model.dart';
import 'package:voicememory_mobile/features/beta_proof_feedback/beta_proof_feedback_store.dart';
import 'package:voicememory_mobile/features/beta_proof_lift/beta_proof_lift_engine.dart';
import 'package:voicememory_mobile/features/beta_proof_lift/beta_proof_lift_model.dart';
import 'package:voicememory_mobile/features/anchor_calibration/anchor_calibration_analytics.dart';
import 'package:voicememory_mobile/features/anchor_calibration/anchor_calibration_copy.dart';
import 'package:voicememory_mobile/features/anchor_calibration/anchor_calibration_engine.dart';
import 'package:voicememory_mobile/features/anchor_calibration/anchor_calibration_model.dart';
import 'package:voicememory_mobile/features/correction_memory/correction_memory_model.dart';
import 'package:voicememory_mobile/features/evidence_anchors/evidence_anchor_copy.dart';
import 'package:voicememory_mobile/features/evidence_anchors/evidence_anchor_engine.dart';
import 'package:voicememory_mobile/features/evidence_anchors/evidence_anchor_model.dart';
import 'package:voicememory_mobile/features/present_day_relevance/present_day_relevance_engine.dart';
import 'package:voicememory_mobile/features/present_day_relevance/present_day_relevance_model.dart';
import 'package:voicememory_mobile/features/proof_confidence_calibration/proof_confidence_calibration_engine.dart';
import 'package:voicememory_mobile/features/proof_confidence_calibration/proof_confidence_calibration_model.dart';
import 'package:voicememory_mobile/features/proof_quality_response/proof_quality_response_engine.dart';
import 'package:voicememory_mobile/features/proof_quality_response/proof_quality_response_model.dart';
import 'package:voicememory_mobile/features/timeline_proof_moment/timeline_proof_moment_engine.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';

class _MemoryPrefs extends MobilePrefsStore {
  _MemoryPrefs()
      : super(file: File('test/tmp/anchor_calibration/unused.json'));

  final Map<String, Map<String, dynamic>> maps = {};

  @override
  Future<Map<String, dynamic>?> readMap(String key) async => maps;

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
}) =>
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

EvidenceAnchor _anchor(
  EvidenceAnchorType type, {
  String id = 'a1',
  String summary = 'Said yes when capacity was already full.',
  bool isSafeForDisplay = true,
}) =>
    EvidenceAnchor(
      id: id,
      type: type,
      label: type.label,
      safeSummary: summary,
      strength: 0.8,
      recencyWeight: 0.9,
      sourceCount: 2,
      isUserCorrected: false,
      isFreshReturn: type == EvidenceAnchorType.freshReturn,
      isSafeForDisplay: isSafeForDisplay,
    );

EvidenceAnchorExtractionResult _extraction(List<EvidenceAnchor> anchors) =>
    EvidenceAnchorExtractionResult(
      shouldExtract: true,
      entryCount: 3,
      source: 'test',
      anchors: anchors,
      safeSummaries: anchors
          .where((anchor) => anchor.isSafeForDisplay)
          .map((anchor) => anchor.safeSummary)
          .toList(),
      usesFallback: anchors.every((anchor) => !anchor.isSafeForDisplay),
      hasSafeAnchor: anchors.any((anchor) => anchor.isSafeForDisplay),
      hasRecentAnchor: true,
      hasCorrectionAnchor: anchors.any(
        (anchor) =>
            anchor.type == EvidenceAnchorType.corrected ||
            anchor.type == EvidenceAnchorType.freshReturn,
      ),
      hasChangeAnchor: anchors.any(
        (anchor) =>
            anchor.type == EvidenceAnchorType.change ||
            anchor.type == EvidenceAnchorType.softening ||
            anchor.type == EvidenceAnchorType.strengthening ||
            anchor.type == EvidenceAnchorType.helped,
      ),
    );

Future<void> _saveFeedback(BetaProofFeedbackType type) async {
  await BetaProofFeedbackStore.forPrefs(_MemoryPrefs()).saveAnswer(
    surface: BetaProofFeedbackSurface.timelineProofMoment,
    feedbackType: type,
    entryCount: 3,
  );
}

void main() {
  final analyticsEvents = <({String event, Map<String, Object> props})>[];
  late _MemoryPrefs prefs;

  setUp(() async {
    prefs = _MemoryPrefs();
    ArchiveBetaMissionGate.enabledOverride = true;
    AnchorCalibrationAnalytics.resetForTest();
    AnchorCalibrationAnalytics.captureForTest = (event, props) {
      analyticsEvents.add((event: event, props: props));
    };
    analyticsEvents.clear();
    await AppServices.resetForTest(
      journalPath:
          'test/tmp/anchor_calibration/${DateTime.now().microsecondsSinceEpoch}_journal.json',
      prefsPath:
          'test/tmp/anchor_calibration/${DateTime.now().microsecondsSinceEpoch}_prefs.json',
      skipRevenueCat: true,
    );
    await BetaProofFeedbackStore.resetForTest(prefs);
  });

  tearDown(() async {
    ArchiveBetaMissionGate.resetForTest();
    AnchorCalibrationAnalytics.resetForTest();
    await BetaProofFeedbackStore.resetForTest(prefs);
  });

  group('Anchor ranking', () {
    test('freshReturn ranks highest', () {
      final ranked = AnchorCalibrationEngine.rankAnchors([
        _anchor(EvidenceAnchorType.repeat, id: 'repeat'),
        _anchor(EvidenceAnchorType.freshReturn, id: 'fresh'),
      ]);
      expect(ranked.first.type, EvidenceAnchorType.freshReturn);
    });

    test('helped ranks above repeat', () {
      expect(
        AnchorCalibrationEngine.typeRank(EvidenceAnchorType.helped),
        greaterThan(AnchorCalibrationEngine.typeRank(EvidenceAnchorType.repeat)),
      );
      final ranked = AnchorCalibrationEngine.rankAnchors([
        _anchor(EvidenceAnchorType.repeat, id: 'repeat'),
        _anchor(EvidenceAnchorType.helped, id: 'helped', summary: 'Helped: paused before saying yes.'),
      ]);
      expect(ranked.first.type, EvidenceAnchorType.helped);
    });

    test('change ranks above repeat', () {
      final ranked = AnchorCalibrationEngine.rankAnchors([
        _anchor(EvidenceAnchorType.repeat, id: 'repeat'),
        _anchor(
          EvidenceAnchorType.change,
          id: 'change',
          summary: 'Change: stopped before saying yes.',
        ),
      ]);
      expect(ranked.first.type, EvidenceAnchorType.change);
    });

    test('fallback ranks lowest', () {
      expect(
        AnchorCalibrationEngine.typeRank(EvidenceAnchorType.unknown),
        lessThan(AnchorCalibrationEngine.typeRank(EvidenceAnchorType.repeat)),
      );
    });
  });

  group('Too vague calibration', () {
    test('downgrades fallback-only proof', () {
      final result = AnchorCalibrationEngine.apply(
        extraction: EvidenceAnchorEngine.fallbackResult(
          source: 'test',
          entryCount: 3,
        ),
        feedbackType: BetaProofFeedbackType.tooVague,
        source: 'test',
      );
      expect(result.forceWatchOnly, isTrue);
      expect(result.extraction.usesFallback, isTrue);
      expect(result.extraction.hasSafeAnchor, isFalse);
    });

    test('prefers specific anchor over repeat', () {
      final result = AnchorCalibrationEngine.apply(
        extraction: _extraction([
          _anchor(EvidenceAnchorType.repeat, id: 'repeat'),
          _anchor(
            EvidenceAnchorType.helped,
            id: 'helped',
            summary: 'Helped: paused before saying yes.',
          ),
        ]),
        feedbackType: BetaProofFeedbackType.tooVague,
        source: 'test',
      );
      expect(result.extraction.anchors.first.type, EvidenceAnchorType.helped);
      expect(result.forceWatchOnly, isFalse);
    });
  });

  group('Already knew calibration', () {
    test('requires change delta before useful proof', () {
      final calibration = ProofConfidenceCalibrationEngine.build(
        entries: _threeRelatedEntries(),
        beliefSurfaceVisible: true,
        source: 'test',
        anchorExtraction: _extraction([
          _anchor(EvidenceAnchorType.repeat),
        ]),
        calibrationFeedback: BetaProofFeedbackType.alreadyKnew,
        now: _now,
      );
      expect(
        calibration.primaryCopy,
        AnchorCalibrationCopy.changeTrackingBody,
      );
      expect(calibration.level, isNot(ProofConfidenceLevel.strong));
    });

    test('without delta uses watch/change-tracking copy', () {
      final result = AnchorCalibrationEngine.apply(
        extraction: _extraction([_anchor(EvidenceAnchorType.repeat)]),
        feedbackType: BetaProofFeedbackType.alreadyKnew,
        hasChangeDelta: false,
        source: 'test',
      );
      expect(result.useChangeTrackingCopy, isTrue);
    });
  });

  group('Not relevant calibration', () {
    test('downgrades current relevance', () {
      final presentDay = PresentDayRelevanceEngine.build(
        entries: _threeRelatedEntries(),
        beliefSurfaceVisible: true,
        source: 'test',
        now: _now,
        calibrationFeedback: BetaProofFeedbackType.notRelevant,
      );
      expect(presentDay?.relevanceState, PresentDayRelevanceState.fading);
    });

    test('requires fresh return before strong surfacing', () {
      final calibration = ProofConfidenceCalibrationEngine.build(
        entries: _threeRelatedEntries(),
        beliefSurfaceVisible: true,
        source: 'test',
        anchorExtraction: _extraction([
          _anchor(EvidenceAnchorType.repeat),
        ]),
        calibrationFeedback: BetaProofFeedbackType.notRelevant,
        now: _now,
      );
      expect(calibration.level, isNot(ProofConfidenceLevel.strong));
    });
  });

  group('Useful calibration', () {
    test('strengthens similar future anchors', () {
      final baseline = AnchorCalibrationEngine.rankAnchors([
        _anchor(EvidenceAnchorType.repeat, id: 'repeat'),
        _anchor(EvidenceAnchorType.current, id: 'current'),
      ]);
      final strengthened = AnchorCalibrationEngine.rankAnchors(
        [
          _anchor(EvidenceAnchorType.repeat, id: 'repeat'),
          _anchor(EvidenceAnchorType.current, id: 'current'),
        ],
        feedbackType: BetaProofFeedbackType.useful,
        strengthenSimilar: true,
      );
      expect(strengthened.first.type, EvidenceAnchorType.current);
      expect(baseline.first.type, EvidenceAnchorType.current);
      expect(
        AnchorCalibrationEngine.apply(
          extraction: _extraction([
            _anchor(EvidenceAnchorType.repeat),
            _anchor(EvidenceAnchorType.current),
          ]),
          feedbackType: BetaProofFeedbackType.useful,
          source: 'test',
        ).strengthenSimilarAnchors,
        isTrue,
      );
    });
  });

  group('Safety and analytics', () {
    test('no private text or entry IDs in calibrated summaries', () {
      final entries = _threeRelatedEntries();
      final extraction = EvidenceAnchorEngine.build(
        entries: entries,
        beliefSurfaceVisible: true,
        source: 'test',
        now: _now,
      );
      final calibrated = AnchorCalibrationEngine.apply(
        extraction: extraction,
        feedbackType: BetaProofFeedbackType.tooVague,
        source: 'test',
      ).extraction;
      for (final summary in calibrated.safeSummaries) {
        expect(summary.toLowerCase(), isNot(contains('entry_')));
        expect(summary.toLowerCase(), isNot(contains('transcript')));
      }
      expect(
        calibrated.safeSummaries,
        isNot(contains(entries.first.transcript)),
      );
    });

    test('no medical claims', () {
      expect(
        ProofSurfaceAdviceGuard.passes(AnchorCalibrationCopy.changeTrackingBody),
        isTrue,
      );
      expect(
        AnchorCalibrationCopy.passesMedicalGuard(
          AnchorCalibrationCopy.changeTrackingBody,
        ),
        isTrue,
      );
    });

    test('metadata-only analytics', () {
      AnchorCalibrationEngine.apply(
        extraction: _extraction([
          _anchor(EvidenceAnchorType.helped, summary: 'Helped: paused.'),
        ]),
        feedbackType: BetaProofFeedbackType.tooVague,
        source: 'test',
        trackAnalytics: true,
      );
      expect(analyticsEvents.single.event, AnchorCalibrationAnalytics.appliedEvent);
      expect(
        analyticsEvents.single.props.keys,
        containsAll([
          'entry_count',
          'source',
          'feedback_type',
          'calibration_action',
        ]),
      );
      expect(analyticsEvents.single.props.keys, isNot(contains('transcript')));
    });
  });

  group('Downstream integration', () {
    test('TimelineProofMoment uses calibrated anchors', () async {
      await _saveFeedback(BetaProofFeedbackType.tooVague);
      final entries = _threeRelatedEntries();
      final moment = TimelineProofMomentEngine.build(
        entries: entries,
        beliefSurfaceVisible: true,
        source: 'test',
        now: _now,
      );
      expect(moment, isNotNull);
      expect(moment!.proofConfidenceCalibration.shouldCalibrate, isTrue);
    });

    test('BetaProofLift uses calibrated anchors', () async {
      await _saveFeedback(BetaProofFeedbackType.alreadyKnew);
      final lift = BetaProofLiftEngine.build(
        entries: _threeRelatedEntries(),
        surface: BetaProofLiftSurface.timelineProofMoment,
        source: 'test',
        beliefSurfaceVisible: true,
        now: _now,
      );
      expect(lift.proofConfidenceCalibration.shouldCalibrate, isTrue);
    });

    test('ProofQualityResponse uses calibrated anchors', () async {
      await _saveFeedback(BetaProofFeedbackType.tooVague);
      final response = ProofQualityResponseEngine.build(
        entries: _threeRelatedEntries(),
        surface: ProofQualityResponseSurface.timelineProofMoment,
        source: 'test',
        now: _now,
      );
      expect(response.shouldShow, isTrue);
      expect(response.feedbackState, ProofQualityFeedbackState.tooVague);
      for (final anchor in response.evidenceAnchors) {
        expect(anchor, isNot(EvidenceAnchorCopy.fallbackSummary));
      }
    });
  });
}
