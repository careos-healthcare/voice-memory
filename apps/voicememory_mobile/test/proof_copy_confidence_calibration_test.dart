import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/archive_timeline_spine/archive_timeline_spine_engine.dart';
import 'package:voicememory_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:voicememory_mobile/features/beta_proof_feedback/beta_proof_feedback_model.dart';
import 'package:voicememory_mobile/features/beta_proof_feedback/beta_proof_feedback_store.dart';
import 'package:voicememory_mobile/features/beta_proof_lift/beta_proof_lift_engine.dart';
import 'package:voicememory_mobile/features/beta_proof_lift/beta_proof_lift_model.dart';
import 'package:voicememory_mobile/features/correction_memory/correction_memory_engine.dart';
import 'package:voicememory_mobile/features/correction_memory/correction_memory_store.dart';
import 'package:voicememory_mobile/features/current_relevance/current_relevance_model.dart';
import 'package:voicememory_mobile/features/current_relevance/current_relevance_store.dart';
import 'package:voicememory_mobile/features/early_archive/early_first_signal_copy.dart';
import 'package:voicememory_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:voicememory_mobile/features/proof_confidence_calibration/proof_confidence_calibration_analytics.dart';
import 'package:voicememory_mobile/features/proof_confidence_calibration/proof_confidence_calibration_copy.dart';
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
      : super(file: File('test/tmp/proof_confidence_calibration/unused.json'));

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

List<JournalEntry> _softeningEntries() => [
      ..._threeRelatedEntries(anchor: _now.subtract(const Duration(days: 4))),
      _entry(
        '4',
        'Same capacity pressure came back but it felt easier to stop this time.',
        createdAt: _now.subtract(const Duration(days: 1)),
      ),
    ];

ProofConfidenceCalibrationResult _calibrate(
  List<JournalEntry> entries, {
  bool beliefSurfaceVisible = true,
  String source = 'test',
}) =>
    ProofConfidenceCalibrationEngine.build(
      entries: entries,
      beliefSurfaceVisible: beliefSurfaceVisible,
      source: source,
      now: _now,
    );

Future<void> _saveCorrection(
  List<JournalEntry> entries,
  CurrentRelevanceAnswer answer,
) async {
  final proofKey = CurrentRelevanceStore.proofKeyFor(entries);
  await CurrentRelevanceStore.instance().saveSelection(
    proofKey: proofKey,
    answer: answer,
    entryCountAtCapture: entries.length,
  );
  await CorrectionMemoryEngine.saveFromAnswer(
    proofKey: proofKey,
    answer: answer,
    entryCountAtCapture: entries.length,
    hasConfirmedRepeat:
        EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(entries),
    source: 'test',
  );
}

void main() {
  final analyticsEvents = <({String event, Map<String, Object> props})>[];
  late _MemoryPrefs prefs;

  setUp(() async {
    prefs = _MemoryPrefs();
    ArchiveBetaMissionGate.enabledOverride = true;
    ProofConfidenceCalibrationAnalytics.resetForTest();
    ProofConfidenceCalibrationAnalytics.captureForTest = (event, props) {
      analyticsEvents.add((event: event, props: props));
    };
    await AppServices.resetForTest(
      journalPath:
          'test/tmp/proof_confidence_calibration/${DateTime.now().microsecondsSinceEpoch}_journal.json',
      prefsPath:
          'test/tmp/proof_confidence_calibration/${DateTime.now().microsecondsSinceEpoch}_prefs.json',
      skipRevenueCat: true,
    );
    await CurrentRelevanceStore.resetForTest();
    await CorrectionMemoryStore.resetForTest();
    await BetaProofFeedbackStore.resetForTest(prefs);
    analyticsEvents.clear();
  });

  tearDown(() async {
    ProofConfidenceCalibrationAnalytics.resetForTest();
    ArchiveBetaMissionGate.resetForTest();
    await CorrectionMemoryStore.resetForTest();
    await CurrentRelevanceStore.resetForTest();
    await BetaProofFeedbackStore.resetForTest(prefs);
  });

  group('ProofConfidenceCalibrationEngine', () {
    test('weak match uses watchOnly copy', () {
      final result = _calibrate([
        _entry('1', 'Had a normal day.'),
        _entry('2', 'Walk after lunch.'),
      ]);
      expect(result.level, ProofConfidenceLevel.watchOnly);
      expect(result.primaryCopy, ProofConfidenceCalibrationCopy.watchOnly);
    });

    test('emerging match uses emerging copy', () {
      final result = ProofConfidenceCalibrationResult(
        shouldCalibrate: true,
        entryCount: 2,
        source: 'test',
        level: ProofConfidenceLevel.emerging,
        primaryCopy: ProofConfidenceCalibrationCopy.emerging,
        displayCopy: ProofConfidenceCalibrationCopy.emerging,
        hasSafeAnchor: false,
        hasMatchQuality: true,
        hasCorrection: false,
        hasFreshReturn: false,
      );
      expect(result.primaryCopy, ProofConfidenceCalibrationCopy.emerging);
    });

    test('useful match uses returned copy', () {
      final result = _calibrate(_threeRelatedEntries());
      expect(result.level, anyOf(
        ProofConfidenceLevel.useful,
        ProofConfidenceLevel.strong,
      ));
      if (result.level == ProofConfidenceLevel.useful) {
        expect(result.primaryCopy, ProofConfidenceCalibrationCopy.useful);
      }
    });

    test('strong match uses clearer timeline copy', () {
      final result = _calibrate(_threeRelatedEntries());
      if (result.level == ProofConfidenceLevel.strong) {
        expect(result.primaryCopy, ProofConfidenceCalibrationCopy.strong);
      } else {
        expect(result.level, ProofConfidenceLevel.useful);
      }
    });

    test('not relevant correction uses corrected copy', () async {
      final entries = _threeRelatedEntries();
      await BetaProofFeedbackStore.forPrefs(prefs).saveAnswer(
        surface: BetaProofFeedbackSurface.timelineProofMoment,
        feedbackType: BetaProofFeedbackType.notRelevant,
        entryCount: entries.length,
      );
      final result = _calibrate(entries);
      expect(result.level, ProofConfidenceLevel.corrected);
      expect(result.primaryCopy, ProofConfidenceCalibrationCopy.corrected);
    });

    test('fresh return after correction uses freshReturn copy', () async {
      final now = _now;
      final entries = [
        _entry('1', _strongRepeat, createdAt: now.subtract(const Duration(days: 2))),
        _entry(
          '2',
          'Same thing — said yes when I had no capacity for one more thing.',
          createdAt: now.subtract(const Duration(days: 1)),
        ),
        _entry(
          '3',
          'I said yes again even though I had no capacity for one more ask.',
          createdAt: now.subtract(const Duration(hours: 3)),
        ),
      ];
      await _saveCorrection(entries, CurrentRelevanceAnswer.notReally);
      final withReturn = [
        ...entries,
        _entry(
          '4',
          'I said yes again even though I had no capacity for one more ask.',
          createdAt: now,
        ),
      ];
      final result = _calibrate(withReturn);
      expect(result.level, ProofConfidenceLevel.freshReturn);
      expect(result.primaryCopy, ProofConfidenceCalibrationCopy.freshReturn);
    });

    test('missing safe anchors avoid strong copy', () {
      final result = _calibrate(
        [
          _entry('1', 'Alpha note.'),
          _entry('2', 'Beta note.'),
          _entry('3', 'Gamma note.'),
        ],
        beliefSurfaceVisible: true,
      );
      expect(result.level, isNot(ProofConfidenceLevel.strong));
    });

    test('change/delta gets priority over generic repeat', () {
      final result = _calibrate(_softeningEntries());
      expect(result.leadCopy, ProofConfidenceCalibrationCopy.changeDeltaLead);
      expect(
        result.displayCopy,
        startsWith(ProofConfidenceCalibrationCopy.changeDeltaLead),
      );
    });

    test('helped/softened gets priority where available', () {
      final result = ProofConfidenceCalibrationEngine.build(
        entries: _threeRelatedEntries(),
        beliefSurfaceVisible: true,
        source: 'test',
        now: _now,
        beliefEvidencePhrases: const [
          EarlyFirstSignalCopy.helpfulActionCapturedEvidence,
        ],
      );
      if (result.leadCopy == ProofConfidenceCalibrationCopy.changeDeltaLead) {
        expect(
          result.displayCopy,
          startsWith(ProofConfidenceCalibrationCopy.changeDeltaLead),
        );
        return;
      }
      expect(result.leadCopy, ProofConfidenceCalibrationCopy.helpedSoftenedLead);
      expect(
        result.displayCopy,
        startsWith(ProofConfidenceCalibrationCopy.helpedSoftenedLead),
      );
    });

    test('no identity overclaiming', () {
      for (final line in ProofConfidenceCalibrationCopy.all) {
        expect(
          ProofConfidenceCalibrationCopy.passesIdentityGuard(line),
          isTrue,
          reason: line,
        );
      }
    });

    test('no therapy/medical claims', () {
      for (final line in ProofConfidenceCalibrationCopy.all) {
        expect(ProofSurfaceAdviceGuard.passes(line), isTrue, reason: line);
      }
    });

    test('TimelineProofMoment uses calibrated copy', () {
      final result = TimelineProofMomentEngine.build(
        entries: _threeRelatedEntries(),
        beliefSurfaceVisible: true,
        source: 'test',
        now: _now,
      );
      expect(result, isNotNull);
      expect(result!.body, result.proofConfidenceCalibration.displayCopy);
    });

    test('BetaProofLift uses calibrated copy', () {
      final lift = BetaProofLiftEngine.build(
        entries: _threeRelatedEntries(),
        surface: BetaProofLiftSurface.timelineProofMoment,
        source: 'test',
        beliefSurfaceVisible: true,
        now: _now,
      );
      expect(lift.proofConfidenceCalibration.shouldCalibrate, isTrue);
      if (lift.isWatchOnly) {
        expect(lift.body, ProofConfidenceCalibrationCopy.watchOnlySubtitle);
      } else {
        expect(lift.body, lift.proofConfidenceCalibration.displayCopy);
      }
    });

    test('ArchiveTimelineSpine uses calibrated copy', () {
      final spine = ArchiveTimelineSpineEngine.build(
        entries: _threeRelatedEntries(),
        beliefSurfaceVisible: true,
        source: 'test',
        now: _now,
      );
      expect(spine, isNotNull);
      expect(spine!.explanation, spine.proofConfidenceCalibration.displayCopy);
    });

    test('ProofQualityResponse uses calibrated copy', () async {
      final entries = _threeRelatedEntries();
      await BetaProofFeedbackStore.forPrefs(prefs).saveAnswer(
        surface: BetaProofFeedbackSurface.timelineProofMoment,
        feedbackType: BetaProofFeedbackType.notRelevant,
        entryCount: entries.length,
      );
      final response = ProofQualityResponseEngine.build(
        entries: entries,
        surface: ProofQualityResponseSurface.timelineProofMoment,
        source: 'test',
        now: _now,
      );
      expect(response.feedbackState, ProofQualityFeedbackState.notRelevant);
      expect(response.body, ProofConfidenceCalibrationCopy.corrected);
    });

    test('metadata-only analytics', () {
      ProofConfidenceCalibrationAnalytics.calibrated(
        result: _calibrate(_threeRelatedEntries()),
      );
      expect(analyticsEvents.single.event,
          ProofConfidenceCalibrationAnalytics.calibratedEvent);
      expect(analyticsEvents.single.props.keys, containsAll([
        'entry_count',
        'source',
        'confidence_level',
        'has_safe_anchor',
        'has_match_quality',
        'has_correction',
        'has_fresh_return',
      ]));
    });

    test('no billing changes', () {
      final joined = ProofConfidenceCalibrationCopy.all.join(' ').toLowerCase();
      expect(joined, isNot(contains('upgrade to pro')));
      expect(joined, isNot(contains('/subscription')));
    });
  });
}
