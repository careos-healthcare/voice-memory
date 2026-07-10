import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:voicememory_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:voicememory_mobile/features/beta_repair_lab/beta_repair_lab_engine.dart';
import 'package:voicememory_mobile/features/beta_repair_lab/beta_repair_lab_model.dart';
import 'package:voicememory_mobile/features/beta_repair_lab/beta_repair_lab_store.dart';
import 'package:voicememory_mobile/features/evidence_trail_clarity/evidence_trail_clarity_engine.dart';
import 'package:voicememory_mobile/features/pattern_match_quality/pattern_match_quality_model.dart';
import 'package:voicememory_mobile/features/pricing_validation/pricing_validation_engine.dart';
import 'package:voicememory_mobile/features/proof_caution_guard/proof_caution_guard_model.dart';
import 'package:voicememory_mobile/features/proof_confidence_calibration/proof_confidence_calibration_engine.dart';
import 'package:voicememory_mobile/features/proof_confidence_calibration/proof_confidence_calibration_model.dart';
import 'package:voicememory_mobile/features/proof_detail_repair/proof_detail_repair_copy.dart';
import 'package:voicememory_mobile/features/proof_detail_repair/proof_detail_repair_engine.dart';
import 'package:voicememory_mobile/features/proof_relevance_repair/proof_relevance_repair_copy.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_engine.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_model.dart';
import 'package:voicememory_mobile/features/timeline_proof_moment/timeline_proof_moment_engine.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/models/sync_status.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'package:voicememory_mobile/widgets/patterns/timeline_proof_moment_card.dart';

class _MemoryPrefs extends MobilePrefsStore {
  _MemoryPrefs()
      : super(file: File('test/tmp/proof_selection_explanation/unused.json'));

  final Map<String, Map<String, dynamic>> maps = {};

  @override
  Future<Map<String, dynamic>?> readMap(String key) async => maps[key];

  @override
  Future<void> writeMap(String key, Map<String, dynamic> value) async {
    maps[key] = value;
  }
}

const _behaviorPhrase =
    'said yes when I had no capacity for one more thing';
const _strongRepeat =
    'I had no capacity but I said yes again to the extra meeting today.';
final _now = DateTime(2026, 6, 12, 12);

JournalEntry _entry(
  String id,
  String transcript, {
  DateTime? createdAt,
  String concreteObservation = 'Work pressure showed up again today.',
}) =>
    JournalEntry(
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

List<JournalEntry> _specificRepeatEntries() => [
      _entry(
        '1',
        _strongRepeat,
        createdAt: _now.subtract(const Duration(days: 2)),
      ),
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
      'Kept checking again before sleep.',
      createdAt: base.subtract(const Duration(days: 1)),
      concreteObservation: 'kept checking',
    ),
    _entry(
      '3',
      'I kept checking again tonight.',
      createdAt: base,
      concreteObservation: 'kept checking',
    ),
  ];
}

BetaRepairLabVisibilityInput _repairInput() =>
    BetaRepairLabVisibilityInput(
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
      feedbackType: null,
      isNegativeFeedback: false,
      betaMissionEnabled: true,
    );

ProofDetailRepairResult _strongDetail() => ProofDetailRepairEngine.build(
      level: ProofConfidenceLevel.strong,
      hasSafeAnchor: true,
      behaviorPhrase: _behaviorPhrase,
    );

void main() {
  late _MemoryPrefs prefs;

  setUp(() async {
    prefs = _MemoryPrefs();
    ArchiveBetaMissionGate.enabledOverride = true;
    await BetaRepairLabStore.resetForTest(prefs);
    await AppServices.resetForTest(
      journalPath:
          'test/tmp/proof_selection_explanation/${DateTime.now().microsecondsSinceEpoch}_journal.json',
      prefsPath:
          'test/tmp/proof_selection_explanation/${DateTime.now().microsecondsSinceEpoch}_prefs.json',
      skipRevenueCat: true,
    );
    ArchiveBetaMissionGate.enabledOverride = true;
  });

  tearDown(() async {
    ArchiveBetaMissionGate.resetForTest();
    await BetaRepairLabStore.resetForTest(prefs);
  });

  group('Proof selection explanation copy', () {
    test('CTA remains More detail', () {
      expect(_strongDetail().ctaLabel, ProofDetailRepairCopy.ctaMoreDetail);
    });

    test('title remains Why this may matter', () {
      expect(ProofDetailRepairCopy.title, 'Why this may matter');
      expect(_strongDetail().title, ProofDetailRepairCopy.title);
    });

    test('detail includes safe behaviour phrase', () {
      expect(_strongDetail().body, contains(_behaviorPhrase));
    });

    test('detail includes Why this one', () {
      expect(_strongDetail().body, contains('Why this one'));
      expect(_strongDetail().body, contains(ProofDetailRepairCopy.whyThisOneLine));
    });

    test('detail says clearest specific repeat', () {
      expect(_strongDetail().body, contains('clearest specific repeat'));
    });

    test('detail says compare safely right now', () {
      expect(_strongDetail().body, contains('compare safely right now'));
    });

    test('detail says it is not ranking every past mention yet', () {
      expect(_strongDetail().body, contains('not ranking every past mention yet'));
    });

    test('detail says it is not the most important thing', () {
      expect(
        _strongDetail().body,
        contains('not saying this is the most important thing'),
      );
    });

    test('detail includes showed up more than once', () {
      expect(_strongDetail().body, contains('showed up more than once'));
    });

    test('detail keeps Too vague Not relevant correction reassurance', () {
      expect(_strongDetail().body, contains(ProofDetailRepairCopy.correctionLine));
      expect(_strongDetail().body, contains('Too vague'));
      expect(_strongDetail().body, contains('Not relevant'));
    });

    test('detail does not show ranked list copy', () {
      final lower = _strongDetail().body.toLowerCase();
      expect(lower.contains('ranked list'), isFalse);
      expect(lower.contains('rank #'), isFalse);
      expect(lower.contains('top pattern'), isFalse);
    });

    test('detail avoids key issue should need therapy diagnosis coach language',
        () {
      for (final text in ProofDetailRepairCopy.allVisibleStrings()) {
        expect(ProofSurfaceAdviceGuard.passes(text), isTrue, reason: text);
        final lower = text.toLowerCase();
        for (final banned in ProofDetailRepairCopy.bannedDetailPhrases) {
          expect(lower.contains(banned), isFalse, reason: text);
        }
      }
    });

    test('detail does not expose raw private journal text beyond safe anchor',
        () {
      final detail = _strongDetail();
      expect(detail.body, isNot(contains(_strongRepeat)));
      expect(detail.body, isNot(contains('extra meeting today')));
    });
  });

  group('Proof selection explanation visibility', () {
    test('watchOnly proof does not expose detail', () {
      expect(
        ProofDetailRepairEngine.build(
          level: ProofConfidenceLevel.watchOnly,
          hasSafeAnchor: true,
          behaviorPhrase: _behaviorPhrase,
        ).shouldShow,
        isFalse,
      );
    });

    test('no-safe-anchor proof does not expose detail', () {
      expect(
        ProofDetailRepairEngine.build(
          level: ProofConfidenceLevel.strong,
          hasSafeAnchor: false,
          behaviorPhrase: _behaviorPhrase,
        ).shouldShow,
        isFalse,
      );
    });

    test('generic rejected proof does not expose detail', () {
      expect(
        ProofDetailRepairEngine.build(
          level: ProofConfidenceLevel.strong,
          hasSafeAnchor: true,
          behaviorPhrase: 'kept checking',
          weakReasons: const [
            PatternMatchWeakReason.onlyGenericWordingOverlaps,
          ],
        ).shouldShow,
        isFalse,
      );
    });

    test('correction-blocked proof does not expose detail', () {
      expect(
        ProofDetailRepairEngine.build(
          level: ProofConfidenceLevel.useful,
          hasSafeAnchor: true,
          behaviorPhrase: _behaviorPhrase,
          cautionBlockedReason:
              ProofCautionGuardBlockedReason.userMarkedNotRelevant,
        ).shouldShow,
        isFalse,
      );
    });
  });

  group('Proof selection explanation integration', () {
    test('existing specific confirmed-repeat proof still passes', () {
      final moment = TimelineProofMomentEngine.build(
        entries: _specificRepeatEntries(),
        beliefSurfaceVisible: true,
        source: 'test',
        now: _now,
      );
      expect(moment, isNotNull);
      expect(moment!.hasSafeAnchor, isTrue);
      expect(
        moment.proofConfidenceCalibration.displayCopy,
        contains(ProofRelevanceRepairCopy.strongLead),
      );

      final detail = ProofDetailRepairEngine.buildFromTimelineMoment(moment);
      expect(detail.shouldShow, isTrue);
      expect(detail.body, contains('Why this one'));
      expect(detail.body, contains('no capacity'));
    });

    test('record screen remains capture-first without stacking extra cards', () {
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

  group('Proof selection explanation protected areas', () {
    test('does not change anchors thresholds or protected systems', () {
      for (final path in [
        'lib/features/proof_detail_repair/proof_detail_repair_copy.dart',
        'lib/features/proof_detail_repair/proof_detail_repair_engine.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source.contains('anchor_specificity_guard'), isFalse);
        expect(source.contains('PaywallSource'), isFalse);
        expect(source.contains('RevenueCat'), isFalse);
        expect(source.contains('billing/'), isFalse);
        expect(source.contains('evidence_trail_clarity'), isFalse);
        expect(source.contains('pricing_validation'), isFalse);
      }
    });

    test('pro pricing evidence trail behaviour unchanged', () {
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
    });
  });

  group('Proof selection explanation widget', () {
    testWidgets('timeline proof card expands selection explanation copy',
        (tester) async {
      final moment = TimelineProofMomentEngine.build(
        entries: _specificRepeatEntries(),
        beliefSurfaceVisible: true,
        source: 'test',
        now: _now,
      );
      expect(moment, isNotNull);

      await tester.binding.setSurfaceSize(const Size(800, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: TimelineProofMomentCard.test(
                result: moment!,
                source: 'test',
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('proof_detail_repair_cta')));
      await tester.pump();

      expect(find.textContaining('Why this one'), findsOneWidget);
      expect(
        find.textContaining('clearest specific repeat'),
        findsOneWidget,
      );
    });
  });
}
