import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:voicememory_mobile/features/beta_feedback_capture/beta_feedback_capture_analytics.dart';
import 'package:voicememory_mobile/features/beta_feedback_capture/beta_feedback_capture_copy.dart';
import 'package:voicememory_mobile/features/beta_feedback_capture/beta_feedback_capture_engine.dart';
import 'package:voicememory_mobile/features/beta_feedback_capture/beta_feedback_capture_model.dart';
import 'package:voicememory_mobile/features/beta_feedback_capture/beta_feedback_capture_store.dart';
import 'package:voicememory_mobile/features/beta_proof_feedback/beta_proof_feedback_model.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_engine.dart';
import 'package:voicememory_mobile/features/surface_priority/surface_priority_model.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'package:voicememory_mobile/widgets/beta/beta_feedback_capture_card.dart';

class _MemoryPrefs extends MobilePrefsStore {
  _MemoryPrefs()
    : super(file: File('test/tmp/beta_feedback_capture/unused.json'));

  final Map<String, Map<String, dynamic>> maps = {};

  @override
  Future<Map<String, dynamic>?> readMap(String key) async => maps[key];

  @override
  Future<void> writeMap(String key, Map<String, dynamic> value) async {
    maps[key] = value;
  }
}

BetaFeedbackCaptureContext _context({
  BetaFeedbackCaptureSurface surface =
      BetaFeedbackCaptureSurface.recordPostSave,
  String source = 'test',
  int entryCount = 1,
  bool betaMissionEnabled = true,
  bool isReady = true,
  bool isRecording = false,
  bool isPostSave = true,
  bool isDegradedTranscriptState = false,
  bool isPostSaveDegradedState = false,
  bool whatChangedQuestionActive = false,
  bool patternReviewInboxHasActiveItems = false,
  bool hasUsefulProof = false,
  bool hasPaywallSeen = false,
  bool hasPurchaseCtaTapped = false,
  bool isPro = false,
  bool timelineProofVisible = false,
  bool proPreviewVisible = false,
  bool existingProofFeedbackVisible = false,
  bool coreCaptureCtaVisible = false,
  bool paywallNoCtaRequested = false,
  bool paywallPurchaseAttempted = false,
}) => BetaFeedbackCaptureContext(
  surface: surface,
  source: source,
  entryCount: entryCount,
  betaMissionEnabled: betaMissionEnabled,
  isReady: isReady,
  isRecording: isRecording,
  isPostSave: isPostSave,
  isDegradedTranscriptState: isDegradedTranscriptState,
  isPostSaveDegradedState: isPostSaveDegradedState,
  whatChangedQuestionActive: whatChangedQuestionActive,
  patternReviewInboxHasActiveItems: patternReviewInboxHasActiveItems,
  hasUsefulProof: hasUsefulProof,
  hasPaywallSeen: hasPaywallSeen,
  hasPurchaseCtaTapped: hasPurchaseCtaTapped,
  isPro: isPro,
  timelineProofVisible: timelineProofVisible,
  proPreviewVisible: proPreviewVisible,
  existingProofFeedbackVisible: existingProofFeedbackVisible,
  coreCaptureCtaVisible: coreCaptureCtaVisible,
  paywallNoCtaRequested: paywallNoCtaRequested,
  paywallPurchaseAttempted: paywallPurchaseAttempted,
);

Future<void> _pumpCard(
  WidgetTester tester, {
  required BetaFeedbackCaptureResult result,
  BetaFeedbackCaptureStore? store,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: BetaFeedbackCaptureCard.test(result: result, store: store),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  final analyticsEvents = <({String event, Map<String, Object> props})>[];
  late _MemoryPrefs prefs;

  setUp(() async {
    prefs = _MemoryPrefs();
    ArchiveBetaMissionGate.resetForTest();
    ArchiveBetaMissionGate.enabledOverride = true;
    BetaFeedbackCaptureAnalytics.resetForTest();
    BetaFeedbackCaptureAnalytics.captureForTest = (event, props) {
      analyticsEvents.add((event: event, props: props));
    };
    analyticsEvents.clear();
    await BetaFeedbackCaptureStore.resetForTest(prefs);
  });

  tearDown(() {
    ArchiveBetaMissionGate.resetForTest();
    BetaFeedbackCaptureAnalytics.resetForTest();
  });

  group('BetaFeedbackCaptureEngine', () {
    test('hidden when beta flag off', () {
      ArchiveBetaMissionGate.enabledOverride = false;
      final result = BetaFeedbackCaptureEngine.build(
        context: _context(entryCount: 1, betaMissionEnabled: false),
      );
      expect(result.shouldShow, isFalse);
    });

    test('after first save shows clarity question', () {
      final result = BetaFeedbackCaptureEngine.build(
        context: _context(entryCount: 1, isPostSave: true),
      );
      expect(result.shouldShow, isTrue);
      expect(result.moment, BetaFeedbackCaptureMoment.afterFirstSave);
      expect(
        result.title,
        BetaFeedbackCaptureCopy.titleFor(
          BetaFeedbackCaptureMoment.afterFirstSave,
        ),
      );
    });

    test('after third save shows expectation question', () {
      final result = BetaFeedbackCaptureEngine.build(
        context: _context(entryCount: 3, isPostSave: true),
      );
      expect(result.shouldShow, isTrue);
      expect(result.moment, BetaFeedbackCaptureMoment.afterThirdSave);
    });

    test('timeline proof uses existing proof feedback if visible', () {
      final result = BetaFeedbackCaptureEngine.build(
        context: _context(
          surface: BetaFeedbackCaptureSurface.recordReady,
          entryCount: 5,
          isPostSave: false,
          timelineProofVisible: true,
          existingProofFeedbackVisible: true,
        ),
      );
      expect(result.shouldShow, isFalse);
    });

    test('after Pro preview shows worth question', () {
      final result = BetaFeedbackCaptureEngine.build(
        context: _context(
          entryCount: 3,
          isPostSave: true,
          proPreviewVisible: true,
        ),
      );
      expect(result.shouldShow, isTrue);
      expect(result.moment, BetaFeedbackCaptureMoment.afterProPreview);
    });

    test('after paywall seen without CTA shows blocker question', () {
      final result = BetaFeedbackCaptureEngine.build(
        context: _context(
          surface: BetaFeedbackCaptureSurface.paywall,
          isPostSave: false,
          paywallNoCtaRequested: true,
          hasPaywallSeen: true,
        ),
      );
      expect(result.shouldShow, isTrue);
      expect(result.moment, BetaFeedbackCaptureMoment.afterPaywallSeenNoCta);
    });

    test(
      'after paywall CTA without purchase shows purchase blocker question',
      () {
        final result = BetaFeedbackCaptureEngine.build(
          context: _context(
            surface: BetaFeedbackCaptureSurface.paywall,
            isPostSave: false,
            paywallPurchaseAttempted: true,
            hasPurchaseCtaTapped: true,
          ),
        );
        expect(result.shouldShow, isTrue);
        expect(
          result.moment,
          BetaFeedbackCaptureMoment.afterPaywallCtaNoPurchase,
        );
      },
    );

    test('one card per surface resolves highest priority moment', () {
      final result = BetaFeedbackCaptureEngine.build(
        context: _context(
          entryCount: 3,
          isPostSave: true,
          proPreviewVisible: true,
          timelineProofVisible: true,
        ),
      );
      expect(result.moment, BetaFeedbackCaptureMoment.afterProPreview);
    });

    test('respects surface priority via core capture CTA guard', () {
      final result = BetaFeedbackCaptureEngine.build(
        context: _context(entryCount: 1, coreCaptureCtaVisible: true),
      );
      expect(result.shouldShow, isFalse);
    });

    test('hidden during recording', () {
      final result = BetaFeedbackCaptureEngine.build(
        context: _context(entryCount: 1, isRecording: true),
      );
      expect(result.shouldShow, isFalse);
    });

    test('hidden during degraded transcript', () {
      final result = BetaFeedbackCaptureEngine.build(
        context: _context(entryCount: 1, isDegradedTranscriptState: true),
      );
      expect(result.shouldShow, isFalse);
    });

    test('hidden during WhatChanged', () {
      final result = BetaFeedbackCaptureEngine.build(
        context: _context(entryCount: 1, whatChangedQuestionActive: true),
      );
      expect(result.shouldShow, isFalse);
    });

    test('hidden during pattern review inbox', () {
      final result = BetaFeedbackCaptureEngine.build(
        context: _context(
          entryCount: 1,
          patternReviewInboxHasActiveItems: true,
        ),
      );
      expect(result.shouldShow, isFalse);
    });
  });

  testWidgets('dismiss works', (tester) async {
    final result = BetaFeedbackCaptureEngine.build(
      context: _context(entryCount: 1),
    );
    final store = BetaFeedbackCaptureStore.forPrefs(prefs);
    await _pumpCard(tester, result: result, store: store);
    expect(find.byKey(const Key('beta_feedback_capture_card')), findsOneWidget);
    await tester.tap(find.byKey(const Key('beta_feedback_capture_dismiss')));
    await tester.pump();
    expect(
      find.byKey(const Key('beta_feedback_capture_card_hidden')),
      findsOneWidget,
    );
    expect(
      BetaFeedbackCaptureStore.isDismissedToday(
        BetaFeedbackCaptureMoment.afterFirstSave,
      ),
      isTrue,
    );
    final dismissed = analyticsEvents.firstWhere(
      (event) => event.event == BetaFeedbackCaptureAnalytics.dismissedEvent,
    );
    expect(dismissed.props['moment'], 'after_first_save');
  });

  testWidgets('card answers store metadata only', (tester) async {
    final result = BetaFeedbackCaptureEngine.build(
      context: _context(entryCount: 1),
    );
    final store = BetaFeedbackCaptureStore.forPrefs(prefs);
    await _pumpCard(tester, result: result, store: store);
    await tester.tap(find.byKey(const Key('beta_feedback_capture_option_yes')));
    await tester.pump();
    final record = BetaFeedbackCaptureStore.recordFor(
      BetaFeedbackCaptureMoment.afterFirstSave,
    );
    expect(record.answerId, 'yes');
    expect(record.entryCount, 1);
    expect(record.source, 'test');
  });

  testWidgets('free text never sent to analytics', (tester) async {
    final result = BetaFeedbackCaptureEngine.build(
      context: _context(entryCount: 1),
    );
    final store = BetaFeedbackCaptureStore.forPrefs(prefs);
    await _pumpCard(tester, result: result, store: store);
    await tester.enterText(
      find.byKey(const Key('beta_feedback_capture_follow_up')),
      'journal text should stay local',
    );
    await tester.tap(find.byKey(const Key('beta_feedback_capture_option_no')));
    await tester.pump();
    final answered = analyticsEvents.firstWhere(
      (event) => event.event == BetaFeedbackCaptureAnalytics.answeredEvent,
    );
    expect(answered.props.containsKey('free_text'), isFalse);
    expect(answered.props.containsKey('freeText'), isFalse);
    expect(answered.props['answer_id'], 'no');
    final record = BetaFeedbackCaptureStore.recordFor(
      BetaFeedbackCaptureMoment.afterFirstSave,
    );
    expect(record.freeTextLocal, contains('journal text'));
  });

  testWidgets('analytics metadata only', (tester) async {
    final result = BetaFeedbackCaptureEngine.build(
      context: _context(
        entryCount: 3,
        hasPaywallSeen: true,
        hasPurchaseCtaTapped: true,
        proPreviewVisible: true,
      ),
    );
    await _pumpCard(tester, result: result);
    final seen = analyticsEvents.firstWhere(
      (event) => event.event == BetaFeedbackCaptureAnalytics.seenEvent,
    );
    expect(seen.props.keys.toSet(), {
      'source',
      'moment',
      'entry_count',
      'has_useful_proof',
      'has_paywall_seen',
      'has_purchase_cta',
    });
  });

  testWidgets('no private journal text in card copy', (tester) async {
    final result = BetaFeedbackCaptureEngine.build(
      context: _context(entryCount: 1),
    );
    await _pumpCard(tester, result: result);
    for (final option in result.options) {
      expect(option.label.toLowerCase(), isNot(contains('journal')));
    }
    expect(find.textContaining('transcript'), findsNothing);
  });

  test('surface priority respected on record ready', () {
    final audit = SurfacePriorityEngine.auditRecordReady(
      entryCount: 1,
      source: 'test',
      candidates: SurfacePriorityCandidates.recordReady(
        firstMomentCapture: true,
        secondMomentReturn: false,
        lowFrictionReturn: false,
        whatToNoticeNext: false,
        betaTodaySummary: false,
        openCapturePromptChips: false,
        captureFreedomLine: false,
        timelineProofMoment: false,
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
        betaFeedbackCapture: true,
      ),
    );
    expect(
      audit.isVisible(
        SurfacePriorityCardKey.betaFeedbackCapture,
        candidate: true,
      ),
      isFalse,
    );
  });

  test('surface priority allows beta feedback when capture CTA absent', () {
    final audit = SurfacePriorityEngine.auditRecordPostSave(
      entryCount: 1,
      source: 'test',
      candidates: SurfacePriorityCandidates.recordPostSave(
        lowFrictionReturn: false,
        whatToNoticeNext: false,
        betaTodaySummary: false,
        openCapturePromptChips: false,
        captureFreedomLine: false,
        firstProofPayoff: false,
        whatChanged: false,
        returnPayoff: false,
        timelineProofMomentPostSave: false,
        proofSpecificityPostSave: false,
        betaProofFeedback: false,
        proEvidenceValue: false,
        proLockMoment: false,
        privateReportProBridge: false,
        betaFeedbackCapture: true,
      ),
    );
    expect(
      audit.isVisible(
        SurfacePriorityCardKey.betaFeedbackCapture,
        candidate: true,
      ),
      isTrue,
    );
  });

  test('proof feedback mapping for timeline answers', () {
    expect(
      BetaFeedbackCaptureEngine.proofFeedbackTypeForAnswer('useful'),
      BetaProofFeedbackType.useful,
    );
    expect(
      BetaFeedbackCaptureEngine.proofFeedbackTypeForAnswer('too_vague'),
      BetaProofFeedbackType.tooVague,
    );
  });
}
