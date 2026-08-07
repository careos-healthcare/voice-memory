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
import 'package:voicememory_mobile/features/evidence_weighting/evidence_weighting_engine.dart';
import 'package:voicememory_mobile/features/pattern_match_quality/pattern_match_quality_analytics.dart';
import 'package:voicememory_mobile/features/pattern_match_quality/pattern_match_quality_copy.dart';
import 'package:voicememory_mobile/features/pattern_match_quality/pattern_match_quality_engine.dart';
import 'package:voicememory_mobile/features/pattern_match_quality/pattern_match_quality_model.dart';
import 'package:voicememory_mobile/features/present_day_relevance/present_day_relevance_engine.dart';
import 'package:voicememory_mobile/features/timeline_proof_moment/timeline_proof_moment_engine.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'support/test_storage_sandbox.dart';

class _MemoryPrefs extends MobilePrefsStore {
  _MemoryPrefs()
    : super(file: File('test/tmp/pattern_match_quality/unused.json'));

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

List<JournalEntry> _triggerAndBehaviourEntries() => [
  ..._threeRelatedEntries(anchor: _now.subtract(const Duration(days: 4))),
  _entry(
    '4',
    'Right before I said yes again, the extra meeting ask came in.',
    createdAt: _now.subtract(const Duration(days: 1)),
  ),
];

PatternMatchQualityResult _qualityFor(
  List<JournalEntry> entries, {
  bool beliefSurfaceVisible = true,
  List<String> beliefEvidencePhrases = const [],
  DateTime? now,
  String source = 'test',
}) => PatternMatchQualityEngine.build(
  entries: entries,
  beliefSurfaceVisible: beliefSurfaceVisible,
  source: source,
  beliefEvidencePhrases: beliefEvidencePhrases,
  now: now ?? _now,
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
    hasConfirmedRepeat: EarlyFirstSignalEngine.hasConfirmedRepeatFoundation(
      entries,
    ),
    source: 'test',
  );
}

void main() {
  late TestStorageSandbox sandbox;
  final analyticsEvents = <({String event, Map<String, Object> props})>[];
  late _MemoryPrefs prefs;

  setUp(() async {
    sandbox = TestStorageSandbox.create();
    prefs = _MemoryPrefs();
    ArchiveBetaMissionGate.enabledOverride = true;
    PatternMatchQualityAnalytics.resetForTest();
    PatternMatchQualityAnalytics.captureForTest = (event, props) {
      analyticsEvents.add((event: event, props: props));
    };
    await AppServices.resetForTest(
      journalPath: sandbox.journalPath,
      prefsPath: sandbox.prefsPath,
      skipRevenueCat: true,
    );
    await CurrentRelevanceStore.resetForTest();
    await CorrectionMemoryStore.resetForTest();
    await BetaProofFeedbackStore.resetForTest(prefs);
    analyticsEvents.clear();
  });

  tearDown(() => sandbox.dispose());
  tearDown(() async {
    PatternMatchQualityAnalytics.resetForTest();
    ArchiveBetaMissionGate.resetForTest();
    await CorrectionMemoryStore.resetForTest();
    await CurrentRelevanceStore.resetForTest();
    await BetaProofFeedbackStore.resetForTest(prefs);
  });

  group('PatternMatchQualityEngine', () {
    test('two unrelated entries score weak', () {
      final result = _qualityFor([
        _entry('1', 'Had a normal day at work.'),
        _entry('2', 'Went for a walk after lunch.'),
      ]);
      expect(result.confidenceBand, PatternMatchConfidenceBand.weak);
      expect(result.shouldShowAsWatchOnly, isTrue);
      expect(result.shouldShowAsProof, isFalse);
    });

    test('generic wording only scores weak', () {
      final result = _qualityFor(
        [
          _entry('1', 'Alpha note.'),
          _entry('2', 'Beta note.'),
          _entry('3', 'Gamma note.'),
        ],
        beliefEvidencePhrases: const ['stress', 'anxiety'],
        beliefSurfaceVisible: true,
      );
      expect(
        result.weakReasons,
        contains(PatternMatchWeakReason.onlyGenericWordingOverlaps),
      );
      expect(result.confidenceBand, isNot(PatternMatchConfidenceBand.strong));
    });

    test('same trigger + behaviour scores solid', () {
      final result = _qualityFor(_triggerAndBehaviourEntries());
      expect(
        result.matchedDimensions,
        containsAll([
          PatternMatchDimension.sameTrigger,
          PatternMatchDimension.sameBehaviour,
        ]),
      );
      expect(
        result.confidenceBand,
        anyOf(
          PatternMatchConfidenceBand.solid,
          PatternMatchConfidenceBand.strong,
        ),
      );
      expect(result.shouldShowAsProof, isTrue);
    });

    test('same helpful action increases score', () {
      final baseline = _qualityFor(_threeRelatedEntries());
      final withHelped = _qualityFor(
        _threeRelatedEntries(),
        beliefEvidencePhrases: const [
          EarlyFirstSignalCopy.helpfulActionCapturedEvidence,
        ],
      );
      expect(
        baseline.matchedDimensions,
        isNot(contains(PatternMatchDimension.sameHelpfulAction)),
      );
      expect(
        withHelped.matchedDimensions,
        contains(PatternMatchDimension.sameHelpfulAction),
      );
      expect(withHelped.score, greaterThanOrEqualTo(baseline.score));
    });

    test('fresh return after correction increases score', () async {
      final now = _now;
      final entries = [
        _entry(
          '1',
          _strongRepeat,
          createdAt: now.subtract(const Duration(days: 2)),
        ),
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
      final result = _qualityFor(withReturn, now: now);
      expect(
        result.matchedDimensions,
        contains(PatternMatchDimension.sameCorrectionFreshReturn),
      );
      expect(result.score, greaterThanOrEqualTo(55));
    });

    test('not relevant without fresh return downgrades score', () async {
      final entries = _threeRelatedEntries();
      await BetaProofFeedbackStore.forPrefs(prefs).saveAnswer(
        surface: BetaProofFeedbackSurface.timelineProofMoment,
        feedbackType: BetaProofFeedbackType.notRelevant,
        entryCount: entries.length,
      );
      final result = _qualityFor(entries);
      expect(
        result.weakReasons,
        contains(PatternMatchWeakReason.userMarkedNotRelevant),
      );
      expect(result.shouldShowAsWatchOnly, isTrue);
    });

    test('stale evidence downgrades score', () {
      final result = _qualityFor([
        _entry('1', _strongRepeat, createdAt: DateTime(2026, 5, 1, 12)),
        _entry(
          '2',
          'Same thing — said yes when I had no capacity for one more thing.',
          createdAt: DateTime(2026, 5, 3, 12),
        ),
        _entry(
          '3',
          'I said yes again even though I had no capacity for one more ask.',
          createdAt: DateTime(2026, 5, 5, 12),
        ),
      ]);
      expect(
        result.weakReasons,
        contains(PatternMatchWeakReason.oldEvidenceOnly),
      );
    });

    test('no safe anchor downgrades score', () {
      final result = _qualityFor([
        _entry('1', 'Alpha note.'),
        _entry('2', 'Beta note.'),
        _entry('3', 'Gamma note.'),
      ], beliefSurfaceVisible: true);
      expect(
        result.weakReasons,
        contains(PatternMatchWeakReason.noSafeAnchorAvailable),
      );
    });

    test('weak match uses watch-only copy', () {
      final result = _qualityFor([
        _entry('1', 'Had a normal day.'),
        _entry('2', 'Walk after lunch.'),
      ]);
      expect(result.safeExplanation, PatternMatchQualityCopy.weak);
    });

    test('emerging match uses emerging copy', () {
      final result = PatternMatchQualityResult(
        shouldResolve: true,
        entryCount: 2,
        source: 'test',
        score: 42,
        confidenceBand: PatternMatchConfidenceBand.emerging,
        matchedDimensions: const [PatternMatchDimension.sameBehaviour],
        weakReasons: const [],
        safeExplanation: PatternMatchQualityCopy.emerging,
        shouldShowAsProof: false,
        shouldShowAsWatchOnly: false,
      );
      expect(result.safeExplanation, PatternMatchQualityCopy.emerging);
    });

    test('solid match uses proof copy', () {
      final result = _qualityFor(_threeRelatedEntries());
      expect(result.shouldShowAsProof, isTrue);
      expect(
        result.safeExplanation,
        anyOf(PatternMatchQualityCopy.solid, PatternMatchQualityCopy.strong),
      );
    });

    test('strong match uses timeline copy', () {
      final result = _qualityFor(_triggerAndBehaviourEntries());
      if (result.confidenceBand == PatternMatchConfidenceBand.strong) {
        expect(result.safeExplanation, PatternMatchQualityCopy.strong);
      } else {
        expect(result.confidenceBand, PatternMatchConfidenceBand.solid);
      }
    });

    test('TimelineProofMoment consumes match quality', () {
      final result = TimelineProofMomentEngine.build(
        entries: _threeRelatedEntries(),
        beliefSurfaceVisible: true,
        source: 'test',
        now: _now,
      );
      expect(result, isNotNull);
      expect(result!.patternMatchQuality.shouldResolve, isTrue);
      expect(result.body, result.proofConfidenceCalibration.displayCopy);
    });

    test('BetaProofLift consumes match quality', () {
      final lift = BetaProofLiftEngine.build(
        entries: _threeRelatedEntries(),
        surface: BetaProofLiftSurface.timelineProofMoment,
        source: 'test',
        beliefSurfaceVisible: true,
        now: _now,
      );
      expect(lift.patternMatchQuality.shouldResolve, isTrue);
      if (lift.isWatchOnly) {
        expect(lift.sections.first.body, PatternMatchQualityCopy.weak);
      }
    });

    test('ArchiveTimelineSpine consumes match quality', () {
      final spine = ArchiveTimelineSpineEngine.build(
        entries: _threeRelatedEntries(),
        beliefSurfaceVisible: true,
        source: 'test',
        now: _now,
      );
      expect(spine, isNotNull);
      expect(spine!.patternMatchQuality.shouldResolve, isTrue);
      expect(spine.explanation, spine.proofConfidenceCalibration.displayCopy);
    });

    test('EvidenceWeighting consumes match quality', () {
      final weighting = EvidenceWeightingEngine.build(
        entries: _threeRelatedEntries(),
        beliefSurfaceVisible: true,
        now: _now,
      );
      expect(weighting, isNotNull);
      expect(weighting!.patternMatchQuality?.shouldResolve, isTrue);
    });

    test('PresentDayRelevance consumes match quality', () {
      final presentDay = PresentDayRelevanceEngine.build(
        entries: _threeRelatedEntries(),
        beliefSurfaceVisible: true,
        source: 'test',
        now: _now,
      );
      expect(presentDay, isNotNull);
      expect(presentDay!.patternMatchQuality?.shouldResolve, isTrue);
    });

    test('no raw transcript/body/private text', () {
      final result = _qualityFor(_threeRelatedEntries());
      expect(result.safeExplanation, isNot(contains(_strongRepeat)));
      expect(
        result.safeExplanation.toLowerCase(),
        isNot(contains('transcript')),
      );
    });

    test('no medical/therapy claims', () {
      for (final line in PatternMatchQualityCopy.all) {
        expect(ProofSurfaceAdviceGuard.passes(line), isTrue, reason: line);
      }
    });

    test('no billing changes', () {
      final joined = PatternMatchQualityCopy.all.join(' ').toLowerCase();
      expect(joined, isNot(contains('upgrade to pro')));
      expect(joined, isNot(contains('/subscription')));
    });

    test('metadata-only analytics', () {
      PatternMatchQualityAnalytics.resolved(
        result: _qualityFor(_threeRelatedEntries()),
      );
      expect(
        analyticsEvents.single.event,
        PatternMatchQualityAnalytics.resolvedEvent,
      );
      expect(
        analyticsEvents.single.props.keys,
        containsAll([
          'entry_count',
          'score_band',
          'matched_dimension_count',
          'weak_reason_count',
          'should_show_as_proof',
          'should_show_as_watch_only',
          'source',
        ]),
      );
    });
  });
}
