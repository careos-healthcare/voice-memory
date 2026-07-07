import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/archive_timeline_spine/archive_timeline_spine_engine.dart';
import 'package:voicememory_mobile/features/archive_timeline_spine/archive_timeline_spine_model.dart';
import 'package:voicememory_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:voicememory_mobile/features/beta_proof_feedback/beta_proof_feedback_model.dart';
import 'package:voicememory_mobile/features/beta_proof_feedback/beta_proof_feedback_store.dart';
import 'package:voicememory_mobile/features/beta_proof_lift/beta_proof_lift_engine.dart';
import 'package:voicememory_mobile/features/beta_proof_lift/beta_proof_lift_model.dart';
import 'package:voicememory_mobile/features/correction_memory/correction_memory_copy.dart';
import 'package:voicememory_mobile/features/correction_memory/correction_memory_engine.dart';
import 'package:voicememory_mobile/features/correction_memory/correction_memory_store.dart';
import 'package:voicememory_mobile/features/current_relevance/current_relevance_model.dart';
import 'package:voicememory_mobile/features/current_relevance/current_relevance_store.dart';
import 'package:voicememory_mobile/features/early_archive/early_first_signal_copy.dart';
import 'package:voicememory_mobile/features/early_archive/early_first_signal_engine.dart';
import 'package:voicememory_mobile/features/evidence_anchors/evidence_anchor_analytics.dart';
import 'package:voicememory_mobile/features/evidence_anchors/evidence_anchor_copy.dart';
import 'package:voicememory_mobile/features/evidence_anchors/evidence_anchor_engine.dart';
import 'package:voicememory_mobile/features/evidence_anchors/evidence_anchor_model.dart';
import 'package:voicememory_mobile/features/proof_quality_response/proof_quality_response_engine.dart';
import 'package:voicememory_mobile/features/proof_quality_response/proof_quality_response_model.dart';
import 'package:voicememory_mobile/features/proof_specificity/proof_specificity_engine.dart';
import 'package:voicememory_mobile/features/timeline_proof_moment/timeline_proof_moment_engine.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/services/app_services.dart';

import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';

class _MemoryPrefs extends MobilePrefsStore {
  _MemoryPrefs()
      : super(file: File('test/tmp/evidence_anchor/unused.json'));

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

EvidenceAnchorExtractionResult _extract(
  List<JournalEntry> entries, {
  bool beliefSurfaceVisible = true,
  List<String> beliefEvidencePhrases = const [],
  DateTime? now,
}) =>
    EvidenceAnchorEngine.build(
      entries: entries,
      beliefSurfaceVisible: beliefSurfaceVisible,
      source: 'test',
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
    EvidenceAnchorAnalytics.resetForTest();
    EvidenceAnchorAnalytics.captureForTest = (event, props) {
      analyticsEvents.add((event: event, props: props));
    };
    await AppServices.resetForTest(
      journalPath:
          'test/tmp/evidence_anchor/${DateTime.now().microsecondsSinceEpoch}_journal.json',
      prefsPath:
          'test/tmp/evidence_anchor/${DateTime.now().microsecondsSinceEpoch}_prefs.json',
      skipRevenueCat: true,
    );
    await CurrentRelevanceStore.resetForTest();
    await CorrectionMemoryStore.resetForTest();
    await BetaProofFeedbackStore.resetForTest(prefs);
    analyticsEvents.clear();
  });

  tearDown(() async {
    EvidenceAnchorAnalytics.resetForTest();
    ArchiveBetaMissionGate.resetForTest();
    await CorrectionMemoryStore.resetForTest();
    await CurrentRelevanceStore.resetForTest();
    await BetaProofFeedbackStore.resetForTest(prefs);
  });

  group('EvidenceAnchorEngine', () {
    test('extracts repeat anchor from safe repeat signal', () {
      final result = _extract(_threeRelatedEntries());
      expect(result.hasSafeAnchor, isTrue);
      expect(
        result.anchors.any((anchor) => anchor.type == EvidenceAnchorType.repeat),
        isTrue,
      );
      for (final summary in result.safeSummaries) {
        expect(summary, isNot(contains(_strongRepeat)));
      }
    });

    test('extracts change anchor from change signal', () {
      final result = _extract(_softeningEntries());
      expect(
        result.anchors.any((anchor) => anchor.type == EvidenceAnchorType.change),
        isTrue,
      );
    });

    test('extracts softening anchor from softer signal', () {
      final result = _extract(_softeningEntries());
      expect(
        result.anchors.any((anchor) => anchor.type == EvidenceAnchorType.softening),
        isTrue,
      );
    });

    test('extracts strengthening anchor from stronger signal', () {
      final result = _extract(_threeRelatedEntries());
      expect(
        result.anchors.any(
          (anchor) => anchor.type == EvidenceAnchorType.strengthening,
        ),
        isTrue,
      );
    });

    test('extracts helped anchor from helped signal', () {
      final result = _extract(
        _threeRelatedEntries(),
        beliefEvidencePhrases: const [
          EarlyFirstSignalCopy.helpfulActionCapturedEvidence,
        ],
      );
      expect(
        result.anchors.any((anchor) => anchor.type == EvidenceAnchorType.helped),
        isTrue,
      );
    });

    test('extracts current anchor from present-day relevance', () {
      final result = _extract(_threeRelatedEntries());
      expect(
        result.anchors.any((anchor) => anchor.type == EvidenceAnchorType.current),
        isTrue,
      );
      expect(
        result.safeSummaries.any((summary) => summary.contains('This looks current')),
        isTrue,
      );
    });

    test('extracts corrected anchor from correction memory', () async {
      final entries = _threeRelatedEntries();
      await _saveCorrection(entries, CurrentRelevanceAnswer.yes);
      final result = _extract(entries);
      expect(
        result.anchors.any((anchor) => anchor.type == EvidenceAnchorType.corrected),
        isTrue,
      );
    });

    test('extracts fresh return after correction', () async {
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
      final result = _extract(withReturn, now: now);
      expect(
        result.anchors.any((anchor) => anchor.type == EvidenceAnchorType.freshReturn),
        isTrue,
      );
    });

    test('prefers recent anchors over older anchors', () {
      final recent = _extract(_threeRelatedEntries());
      final stale = _extract(
        [
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
        ],
      );
      expect(recent.hasRecentAnchor, isTrue);
      expect(stale.hasRecentAnchor, isFalse);
      expect(
        recent.anchors.first.recencyWeight,
        greaterThan(stale.anchors.first.recencyWeight),
      );
    });

    test('prefers change anchors over generic repeat anchors', () {
      final result = _extract(_softeningEntries());
      expect(result.anchors.first.type, isNot(EvidenceAnchorType.repeat));
      expect(
        result.anchors.first.type == EvidenceAnchorType.change ||
            result.anchors.first.type == EvidenceAnchorType.softening,
        isTrue,
      );
    });

    test('never includes transcript/body/private text', () {
      final result = _extract(_threeRelatedEntries());
      for (final summary in result.safeSummaries) {
        expect(summary.toLowerCase(), isNot(contains('transcript')));
        expect(summary, isNot(contains(_strongRepeat)));
      }
      for (final anchor in result.anchors) {
        expect(anchor.safeSummary, isNot(contains(_strongRepeat)));
      }
    });

    test('never includes entry IDs', () {
      final result = _extract(
        _threeRelatedEntries(),
        beliefEvidencePhrases: const ['entry_id 4 should not appear'],
      );
      for (final summary in result.safeSummaries) {
        expect(summary.toLowerCase(), isNot(contains('entry_id')));
      }
    });

    test('returns fallback when no safe anchors exist', () {
      final result = EvidenceAnchorEngine.fallbackResult(
        source: 'test',
        entryCount: 3,
      );
      expect(result.usesFallback, isTrue);
      expect(result.hasSafeAnchor, isFalse);
      expect(result.anchors.single.safeSummary, EvidenceAnchorCopy.fallbackSummary);
    });

    test('TimelineProofMoment uses anchors', () {
      final result = TimelineProofMomentEngine.build(
        entries: _threeRelatedEntries(),
        beliefSurfaceVisible: true,
        source: 'test',
        now: _now,
      );
      expect(result, isNotNull);
      expect(result!.hasSafeAnchor, isTrue);
      expect(result.evidenceAnchors, isNotEmpty);
    });

    test('BetaProofLift uses anchors', () {
      final timeline = TimelineProofMomentEngine.build(
        entries: _threeRelatedEntries(),
        beliefSurfaceVisible: true,
        source: 'test',
        now: _now,
      );
      final lift = BetaProofLiftEngine.build(
        entries: _threeRelatedEntries(),
        surface: BetaProofLiftSurface.timelineProofMoment,
        source: 'test',
        beliefSurfaceVisible: true,
        timelineProof: timeline,
        now: _now,
      );
      expect(lift.hasSafeAnchor, isTrue);
      expect(lift.sections.first.body, isNot(contains(_strongRepeat)));
      expect(lift.deltaRows, isNotEmpty);
    });

    test('ProofQualityResponse uses anchors', () async {
      final entries = _threeRelatedEntries();
      await BetaProofFeedbackStore.forPrefs(prefs).saveAnswer(
        surface: BetaProofFeedbackSurface.timelineProofMoment,
        feedbackType: BetaProofFeedbackType.tooVague,
        entryCount: entries.length,
      );
      final response = ProofQualityResponseEngine.build(
        entries: entries,
        surface: ProofQualityResponseSurface.timelineProofMoment,
        source: 'test',
        now: _now,
      );
      expect(response.hasSafeAnchor, isTrue);
      expect(response.evidenceAnchors, isNotEmpty);
    });

    test('ArchiveTimelineSpine can receive anchors', () {
      final spine = ArchiveTimelineSpineEngine.build(
        entries: _threeRelatedEntries(),
        beliefSurfaceVisible: true,
        source: 'test',
        now: _now,
      );
      expect(spine, isNotNull);
      expect(spine!.hasSafeAnchor, isTrue);
      expect(spine.evidenceAnchors, isNotEmpty);
      expect(
        spine.rows.any((row) => row.anchorType != null),
        isTrue,
      );
    });

    test('ProofSpecificity delegates to evidence anchors', () {
      final result = ProofSpecificityEngine.build(
        entries: _threeRelatedEntries(),
        beliefSurfaceVisible: true,
        source: 'test',
      );
      expect(result.evidenceAnchors, isNotEmpty);
      expect(result.usesFallbackEvidenceLine, isFalse);
    });

    test('metadata-only analytics', () {
      EvidenceAnchorAnalytics.trackExtraction(
        result: _extract(_threeRelatedEntries()),
      );
      expect(analyticsEvents, isNotEmpty);
      final event = analyticsEvents.last;
      expect(event.props.keys, containsAll([
        'entry_count',
        'source',
        'anchor_count',
        'anchor_types',
        'has_recent_anchor',
        'has_correction_anchor',
        'has_change_anchor',
      ]));
      expect(event.props.keys, isNot(contains('transcript')));
      expect(event.props.keys, isNot(contains('proof_key')));
    });

    test('empty analytics when only fallback exists', () {
      EvidenceAnchorAnalytics.empty(source: 'test', entryCount: 3);
      expect(analyticsEvents.single.event, EvidenceAnchorAnalytics.emptyEvent);
      expect(analyticsEvents.single.props['anchor_count'], 0);
    });

    test('no therapy/medical claims', () {
      for (final line in EvidenceAnchorCopy.all) {
        expect(ProofSurfaceAdviceGuard.passes(line), isTrue, reason: line);
      }
      final result = _extract(_threeRelatedEntries());
      for (final summary in result.safeSummaries) {
        expect(ProofSurfaceAdviceGuard.passes(summary), isTrue, reason: summary);
      }
    });

    test('no Pro CTA', () {
      final joined = [
        ...EvidenceAnchorCopy.all,
        ..._extract(_threeRelatedEntries()).safeSummaries,
      ].join(' ').toLowerCase();
      expect(joined, isNot(contains('upgrade to pro')));
      expect(joined, isNot(contains('/subscription')));
    });

    test('extracts avoided anchor from avoided signal', () {
      final result = _extract(
        _threeRelatedEntries(),
        beliefEvidencePhrases: const ['avoided the message again'],
      );
      expect(
        result.anchors.any((anchor) => anchor.type == EvidenceAnchorType.avoided),
        isTrue,
      );
    });
  });
}
