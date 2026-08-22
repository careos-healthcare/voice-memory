import 'dart:io';
import 'support/record_screen_library_source.dart';

import 'package:archiveme_mobile/billing/archive_loop_entitlement_ids.dart';
import 'package:archiveme_mobile/billing/paywall_source.dart';
import 'package:archiveme_mobile/billing/restore_purchases_copy.dart';
import 'package:archiveme_mobile/billing/revenuecat_service.dart';
import 'package:archiveme_mobile/features/pro_evidence_value/pro_evidence_value_dismiss_store.dart';
import 'package:archiveme_mobile/features/pro_preview/pro_preview_analytics.dart';
import 'package:archiveme_mobile/features/pro_preview/pro_preview_copy.dart';
import 'package:archiveme_mobile/features/pro_preview/pro_preview_engine.dart';
import 'package:archiveme_mobile/features/pro_preview/pro_preview_model.dart';
import 'package:archiveme_mobile/features/surface_priority/surface_priority_copy.dart';
import 'package:archiveme_mobile/features/surface_priority/surface_priority_engine.dart';
import 'package:archiveme_mobile/features/surface_priority/surface_priority_model.dart';
import 'package:archiveme_mobile/widgets/pro/pro_preview_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ProPreviewContext _context({
  ProPreviewSurface surface = ProPreviewSurface.recordPostSave,
  int entryCount = 3,
  bool isPro = false,
  bool dismissed = false,
  bool hasFirstProof = true,
  bool hasTimelineProofVisible = false,
  bool firstProofPayoffSeen = false,
  bool isZeroEntryState = false,
  bool isFirstRecordingState = false,
  bool isDegradedTranscriptState = false,
  bool isPostSaveDegradedState = false,
  bool firstProofTruthQuestionActive = false,
  bool whatChangedQuestionActive = false,
  bool patternReviewInboxHasActiveItems = false,
}) => ProPreviewContext(
  surface: surface,
  source: 'test',
  entryCount: entryCount,
  isPro: isPro,
  dismissed: dismissed,
  hasFirstProof: hasFirstProof,
  hasTimelineProofVisible: hasTimelineProofVisible,
  firstProofPayoffSeen: firstProofPayoffSeen,
  isZeroEntryState: isZeroEntryState,
  isFirstRecordingState: isFirstRecordingState,
  isDegradedTranscriptState: isDegradedTranscriptState,
  isPostSaveDegradedState: isPostSaveDegradedState,
  firstProofTruthQuestionActive: firstProofTruthQuestionActive,
  whatChangedQuestionActive: whatChangedQuestionActive,
  patternReviewInboxHasActiveItems: patternReviewInboxHasActiveItems,
);

ProPreviewResult _visibleResult({ProPreviewContext? context}) =>
    ProPreviewEngine.build(context: context ?? _context());

Future<void> _pumpCard(
  WidgetTester tester, {
  required ProPreviewResult result,
  VoidCallback? onSeePro,
  VoidCallback? onDismiss,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ProPreviewCard.test(
          result: result,
          onSeePro: onSeePro,
          onDismiss: onDismiss,
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  setUp(() {
    ProPreviewAnalytics.resetForTest();
    ProEvidenceValueDismissStore.invalidateSessionForTest();
  });

  tearDown(ProPreviewAnalytics.resetForTest);

  group('ProPreviewCopy', () {
    test('uses generic preview copy', () {
      expect(ProPreviewCopy.title, 'What Pro keeps');
      expect(
        ProPreviewCopy.body,
        'Your first proof is free. Pro keeps the longer proof trail over time.',
      );
      expect(ProPreviewCopy.cta, 'See Pro');
      expect(ProPreviewCopy.secondary, 'Not now');
      expect(ProPreviewCopy.previewRows(), hasLength(7));
    });
  });

  group('ProPreviewEngine visibility', () {
    test('hidden before proof', () {
      expect(
        ProPreviewEngine.shouldShowCard(
          _context(
            hasFirstProof: false,
          ),
        ),
        isFalse,
      );
    });

    test('visible after first proof', () {
      expect(
        ProPreviewEngine.shouldShowCard(
          _context(
            firstProofPayoffSeen: true,
          ),
        ),
        isTrue,
      );
    });

    test('visible after timeline proof', () {
      expect(
        ProPreviewEngine.shouldShowCard(
          _context(
            hasFirstProof: false,
            hasTimelineProofVisible: true,
          ),
        ),
        isTrue,
      );
    });

    test('hidden for Pro subscriber', () {
      expect(ProPreviewEngine.shouldShowCard(_context(isPro: true)), isFalse);
    });

    test('hidden when dismissed for session', () async {
      await ProPreviewEngine.dismissForSession();
      expect(
        ProPreviewEngine.shouldShowCard(
          _context(dismissed: ProPreviewEngine.isDismissed()),
        ),
        isFalse,
      );
    });
  });

  group('ProPreviewCard', () {
    testWidgets('hidden before proof renders shrink', (tester) async {
      await _pumpCard(
        tester,
        result: ProPreviewEngine.build(
          context: _context(
            hasFirstProof: false,
          ),
        ),
      );

      expect(find.byKey(const Key('pro_preview_card_hidden')), findsOneWidget);
      expect(find.byKey(const Key('pro_preview_card')), findsNothing);
    });

    testWidgets('CTA opens paywall handler', (tester) async {
      var openedPaywall = false;
      await _pumpCard(
        tester,
        result: _visibleResult(),
        onSeePro: () => openedPaywall = true,
        onDismiss: () {},
      );

      await tester.tap(find.byKey(const Key('pro_preview_cta')));
      await tester.pump();

      expect(openedPaywall, isTrue);
    });

    testWidgets('Not now dismisses through handler', (tester) async {
      var dismissed = false;
      await _pumpCard(
        tester,
        result: _visibleResult(),
        onSeePro: () {},
        onDismiss: () => dismissed = true,
      );

      await tester.tap(find.byKey(const Key('pro_preview_dismiss')));
      await tester.pump();

      expect(dismissed, isTrue);
    });

    test('no fake evidence or private text', () {
      final displayed = ProPreviewCopy.allDisplayedStrings()
          .join(' ')
          .toLowerCase();
      for (final banned in ProPreviewCopy.bannedFakeClaims) {
        expect(displayed, isNot(contains(banned)));
      }
      for (final banned in ProPreviewCopy.bannedMedicalTerms) {
        expect(displayed, isNot(contains(banned)));
      }
      expect(displayed, isNot(contains('transcript')));
      expect(displayed, isNot(contains('journal entry')));
    });
  });

  group('ProPreviewAnalytics', () {
    test('metadata-only analytics', () {
      final events = <String>[];
      final properties = <Map<String, Object>>[];
      ProPreviewAnalytics.captureForTest = (event, props) {
        events.add(event);
        properties.add(props);
      };

      ProPreviewAnalytics.seen(
        source: 'record_post_save',
        surface: 'record_post_save',
        entryCount: 3,
        hasTimelineProof: true,
        hasFirstProof: true,
      );
      ProPreviewAnalytics.ctaTapped(
        source: 'record_post_save',
        surface: 'record_post_save',
        entryCount: 3,
        hasTimelineProof: true,
        hasFirstProof: true,
      );
      ProPreviewAnalytics.dismissed(
        source: 'record_post_save',
        surface: 'record_post_save',
        entryCount: 3,
        hasTimelineProof: true,
        hasFirstProof: true,
      );

      expect(events, [
        ProPreviewAnalytics.seenEvent,
        ProPreviewAnalytics.ctaTappedEvent,
        ProPreviewAnalytics.dismissedEvent,
      ]);
      for (final props in properties) {
        expect(
          props.keys,
          containsAll([
            'entry_count',
            'source',
            'surface',
            'has_timeline_proof',
            'has_first_proof',
          ]),
        );
        expect(props.containsKey('product_id'), isFalse);
        expect(props.containsKey('price'), isFalse);
        expect(props.containsKey('transcript'), isFalse);
      }
    });
  });

  group('SurfacePriorityEngine Pro slot cap', () {
    test('pro preview wins single Pro slot on record post save', () {
      final result = SurfacePriorityEngine.auditRecordPostSave(
        entryCount: 3,
        source: 'test',
        candidates: SurfacePriorityCandidates.recordPostSave(
          lowFrictionReturn: false,
          whatToNoticeNext: false,
          betaTodaySummary: false,
          openCapturePromptChips: false,
          captureFreedomLine: false,
          whatChanged: false,
          firstProofPayoff: true,
          returnPayoff: false,
          timelineProofMomentPostSave: true,
          proofSpecificityPostSave: false,
          betaProofFeedback: false,
          proPreview: true,
          proBridgeVisibility: true,
          proEvidenceValue: true,
          proLockMoment: true,
          privateReportProBridge: true,
        ),
      );

      expect(result.proSlot, SurfacePriorityCardKey.proPreview);
      expect(
        result.isVisible(
          SurfacePriorityCardKey.proBridgeVisibility,
          candidate: true,
        ),
        isFalse,
      );
      expect(
        result.hiddenReasons,
        contains(SurfacePriorityCopy.hiddenReasonProCap),
      );
    });

    test('pro preview wins single Pro slot on patterns', () {
      final result = SurfacePriorityEngine.auditPatterns(
        entryCount: 5,
        source: 'test',
        candidates: SurfacePriorityCandidates.patterns(
          archiveBeliefSurface: true,
          timelineProofMoment: true,
          archiveTimelineSpine: true,
          betaTesterReport: true,
          correctionMemory: false,
          notRelevantRecovery: false,
          proofQualityResponse: false,
          patternConfidence: false,
          evidenceWeighting: false,
          currentRelevance: false,
          proofSpecificity: false,
          presentDayRelevance: false,
          timelinePositioning: false,
          proPreview: true,
          proBridgeVisibility: true,
          proEvidenceValue: true,
          archiveIntelligenceProBridge: true,
          privateReportProBridge: true,
          archiveBackupBridge: true,
          suppressLegacyEducation: false,
        ),
      );

      expect(result.proSlot, SurfacePriorityCardKey.proPreview);
      expect(
        result.isVisible(
          SurfacePriorityCardKey.proEvidenceValue,
          candidate: true,
        ),
        isFalse,
      );
    });
  });

  group('Protected billing areas', () {
    test('entitlement IDs unchanged', () {
      expect(ArchiveLoopEntitlementIds.archiveLoopPro, 'archive_loop_pro');
      expect(ArchiveLoopEntitlementIds.revenueCatLegacyPro, 'pro');
      expect(RevenueCatService.proEntitlementId, 'pro');
    });

    test('restore purchases unchanged', () {
      expect(RestorePurchasesCopy.restorePurchases, 'Restore purchases');
    });

    test('record screen routes preview CTA through valueMoment paywall', () {
      final recordSource = readRecordScreenLibrarySource();
      expect(recordSource, contains('ProPreviewCard'));
      expect(recordSource, contains('_openProEvidenceValueSubscription'));
      expect(recordSource, contains('PaywallSource.valueMoment'));
    });

    test(
      'patterns screen routes preview CTA through existing paywall handler',
      () {
        final patternsSource = File(
          'lib/screens/archive_belief_screen.dart',
        ).readAsStringSync();
        expect(patternsSource, contains('ProPreviewCard'));
        expect(patternsSource, contains('_openProEvidenceValueSubscription'));
        expect(
          patternsSource,
          contains("analyticsSource: 'patterns_post_proof_pro_preview'"),
        );
      },
    );

    test('paywall source valueMoment unchanged', () {
      expect(PaywallSource.valueMoment.id, 'value_moment');
    });
  });
}