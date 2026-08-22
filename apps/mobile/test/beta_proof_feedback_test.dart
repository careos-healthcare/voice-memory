import 'dart:io';

import 'package:archiveme_mobile/features/archive_proof/proof_surface_advice_guard.dart';
import 'package:archiveme_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:archiveme_mobile/features/beta_proof_feedback/beta_proof_feedback_analytics.dart';
import 'package:archiveme_mobile/features/beta_proof_feedback/beta_proof_feedback_copy.dart';
import 'package:archiveme_mobile/features/beta_proof_feedback/beta_proof_feedback_engine.dart';
import 'package:archiveme_mobile/features/beta_proof_feedback/beta_proof_feedback_model.dart';
import 'package:archiveme_mobile/features/beta_proof_feedback/beta_proof_feedback_store.dart';
import 'package:archiveme_mobile/features/proof_relevance_repair/proof_relevance_repair_copy.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:archiveme_mobile/widgets/beta/beta_proof_feedback_row.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryPrefs extends MobilePrefsStore {
  _MemoryPrefs()
    : super(file: File('test/tmp/beta_proof_feedback/unused.json'));

  final Map<String, Map<String, dynamic>> maps = {};

  @override
  Future<Map<String, dynamic>?> readMap(String key) async => maps[key];

  @override
  Future<void> writeMap(String key, Map<String, dynamic> value) async {
    maps[key] = value;
  }
}

void main() {
  final analyticsEvents = <({String event, Map<String, Object> props})>[];

  setUp(() async {
    ArchiveBetaMissionGate.resetForTest();
    BetaProofFeedbackAnalytics.resetForTest();
    BetaProofFeedbackAnalytics.captureForTest = (event, props) {
      analyticsEvents.add((event: event, props: props));
    };
    analyticsEvents.clear();
    await BetaProofFeedbackStore.resetForTest(_MemoryPrefs());
  });

  tearDown(() {
    ArchiveBetaMissionGate.resetForTest();
    BetaProofFeedbackAnalytics.resetForTest();
  });

  group('BetaProofFeedbackEngine', () {
    test('hidden when beta flag false', () {
      ArchiveBetaMissionGate.enabledOverride = false;
      expect(
        BetaProofFeedbackEngine.shouldShow(
          surface: BetaProofFeedbackSurface.timelineProofMoment,
          parentVisible: true,
          entryCount: 3,
          hasConfirmedRepeat: true,
          isRecording: false,
          isPostSaveDegraded: false,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: false,
        ),
        isFalse,
      );
    });

    test('visible when beta flag true', () {
      ArchiveBetaMissionGate.enabledOverride = true;
      expect(
        BetaProofFeedbackEngine.shouldShow(
          surface: BetaProofFeedbackSurface.timelineProofMoment,
          parentVisible: true,
          entryCount: 3,
          hasConfirmedRepeat: true,
          isRecording: false,
          isPostSaveDegraded: false,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: false,
        ),
        isTrue,
      );
    });

    test('hidden during recording', () {
      ArchiveBetaMissionGate.enabledOverride = true;
      expect(
        BetaProofFeedbackEngine.shouldShow(
          surface: BetaProofFeedbackSurface.archiveTimelineSpine,
          parentVisible: true,
          entryCount: 3,
          hasConfirmedRepeat: true,
          isRecording: true,
          isPostSaveDegraded: false,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: false,
        ),
        isFalse,
      );
    });

    test('hidden during post-save degraded', () {
      ArchiveBetaMissionGate.enabledOverride = true;
      expect(
        BetaProofFeedbackEngine.shouldShow(
          surface: BetaProofFeedbackSurface.firstProofPayoff,
          parentVisible: true,
          entryCount: 3,
          hasConfirmedRepeat: true,
          isRecording: false,
          isPostSaveDegraded: true,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: false,
        ),
        isFalse,
      );
    });

    test('hidden during What Changed', () {
      ArchiveBetaMissionGate.enabledOverride = true;
      expect(
        BetaProofFeedbackEngine.shouldShow(
          surface: BetaProofFeedbackSurface.firstProofPayoff,
          parentVisible: true,
          entryCount: 3,
          hasConfirmedRepeat: true,
          isRecording: false,
          isPostSaveDegraded: false,
          whatChangedQuestionActive: true,
          patternReviewInboxHasActiveItems: false,
        ),
        isFalse,
      );
    });

    test('hidden during Pattern Review Inbox active item', () {
      ArchiveBetaMissionGate.enabledOverride = true;
      expect(
        BetaProofFeedbackEngine.shouldShow(
          surface: BetaProofFeedbackSurface.firstProofPayoff,
          parentVisible: true,
          entryCount: 3,
          hasConfirmedRepeat: true,
          isRecording: false,
          isPostSaveDegraded: false,
          whatChangedQuestionActive: false,
          patternReviewInboxHasActiveItems: true,
        ),
        isFalse,
      );
    });

    test('does not change proof thresholds or evidence gates', () {
      for (final path in [
        'lib/features/beta_proof_feedback/beta_proof_feedback_engine.dart',
        'lib/features/beta_proof_feedback/beta_proof_feedback_store.dart',
        'lib/widgets/beta/beta_proof_feedback_row.dart',
      ]) {
        final source = File(path).readAsStringSync();
        expect(source, isNot(contains('ArchiveEvidenceQualityGate')));
        expect(source, isNot(contains('ProofThreshold')));
        expect(source, isNot(contains('ArchiveEvidenceQuality')));
      }
    });
  });

  group('BetaProofFeedbackStore', () {
    test('stores answer locally per surface', () async {
      final prefs = _MemoryPrefs();
      await BetaProofFeedbackStore.resetForTest(prefs);
      final store = BetaProofFeedbackStore.forPrefs(prefs);

      await store.saveAnswer(
        surface: BetaProofFeedbackSurface.timelineProofMoment,
        feedbackType: BetaProofFeedbackType.useful,
        entryCount: 3,
      );

      await BetaProofFeedbackStore.ensureLoaded();
      expect(
        BetaProofFeedbackStore.recordFor(
          BetaProofFeedbackSurface.timelineProofMoment,
        ).feedbackType,
        BetaProofFeedbackType.useful,
      );
      expect(
        BetaProofFeedbackStore.isAnsweredToday(
          BetaProofFeedbackSurface.timelineProofMoment,
        ),
        isTrue,
      );
    });
  });

  group('BetaProofFeedbackRow', () {
    Future<void> pumpRow(
      WidgetTester tester, {
      BetaProofFeedbackSurface surface =
          BetaProofFeedbackSurface.timelineProofMoment,
      BetaProofFeedbackStore? store,
      bool betaEnabled = true,
    }) async {
      ArchiveBetaMissionGate.enabledOverride = betaEnabled;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: BetaProofFeedbackRow.test(
                surface: surface,
                source: 'test',
                entryCount: 3,
                hasConfirmedRepeat: true,
                parentVisible: true,
                store: store,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('renders Was this useful?', (tester) async {
      await pumpRow(tester);
      expect(find.text(BetaProofFeedbackCopy.question), findsOneWidget);
    });

    testWidgets('renders all four options', (tester) async {
      await pumpRow(tester);
      for (final type in BetaProofFeedbackType.values) {
        expect(find.text(BetaProofFeedbackCopy.labelFor(type)), findsOneWidget);
      }
    });

    testWidgets('hidden when beta flag false', (tester) async {
      await pumpRow(tester, betaEnabled: false);
      expect(find.text(BetaProofFeedbackCopy.question), findsNothing);
    });

    testWidgets('visible when beta flag true', (tester) async {
      await pumpRow(tester);
      expect(find.text(BetaProofFeedbackCopy.question), findsOneWidget);
    });

    for (final type in ProofRelevanceRepairCopy.relevanceFeedbackTypes) {
      testWidgets('tapping ${type.storageValue} stores local feedback', (
        tester,
      ) async {
        final prefs = _MemoryPrefs();
        await BetaProofFeedbackStore.resetForTest(prefs);
        final store = BetaProofFeedbackStore.forPrefs(prefs);

        await pumpRow(
          tester,
          surface: BetaProofFeedbackSurface.archiveTimelineSpine,
          store: store,
        );
        await tester.tap(
          find.byKey(Key('beta_proof_feedback_${type.storageValue}')),
        );
        await tester.pumpAndSettle();

        expect(
          BetaProofFeedbackStore.recordFor(
            BetaProofFeedbackSurface.archiveTimelineSpine,
          ).feedbackType,
          type,
        );
      });
    }

    testWidgets('after answer shows thanks copy', (tester) async {
      final prefs = _MemoryPrefs();
      await BetaProofFeedbackStore.resetForTest(prefs);
      final store = BetaProofFeedbackStore.forPrefs(prefs);

      await pumpRow(tester, store: store);
      await tester.tap(find.byKey(const Key('beta_proof_feedback_useful')));
      await tester.pumpAndSettle();

      expect(find.text(BetaProofFeedbackCopy.thanksMessage), findsOneWidget);
      expect(find.text(BetaProofFeedbackCopy.question), findsNothing);
    });

    testWidgets('metadata-only analytics', (tester) async {
      final prefs = _MemoryPrefs();
      await BetaProofFeedbackStore.resetForTest(prefs);
      final store = BetaProofFeedbackStore.forPrefs(prefs);

      await pumpRow(tester, store: store);
      await tester.tap(find.byKey(const Key('beta_proof_feedback_too_vague')));
      await tester.pumpAndSettle();

      expect(analyticsEvents.length, greaterThanOrEqualTo(2));
      final seen = analyticsEvents.firstWhere(
        (event) => event.event == BetaProofFeedbackAnalytics.seenEvent,
      );
      expect(
        seen.props.keys,
        containsAll([
          'source',
          'surface',
          'entry_count',
          'has_confirmed_repeat',
        ]),
      );
      expect(seen.props.keys, isNot(contains('transcript')));
      expect(seen.props.keys, isNot(contains('entry_id')));
      expect(seen.props.keys, isNot(contains('body')));

      final answered = analyticsEvents.firstWhere(
        (event) => event.event == BetaProofFeedbackAnalytics.answeredEvent,
      );
      expect(answered.props['feedback_type'], 'too_vague');
    });
  });

  group('Beta proof feedback copy guard', () {
    test('no therapy/diagnosis/treatment claims', () {
      for (final line in BetaProofFeedbackCopy.allVisibleStrings()) {
        expect(
          ProofSurfaceAdviceGuard.passes(line),
          isTrue,
          reason: 'failed on: $line',
        );
      }
    });

    test('no transcript/body/private text in feature files', () {
      for (final path in [
        'lib/features/beta_proof_feedback/beta_proof_feedback_analytics.dart',
        'lib/features/beta_proof_feedback/beta_proof_feedback_store.dart',
        'lib/widgets/beta/beta_proof_feedback_row.dart',
      ]) {
        final source = File(path).readAsStringSync().toLowerCase();
        expect(source, isNot(contains('transcript')));
        expect(source, isNot(contains('entry_id')));
      }
    });

    test('feature files avoid billing surfaces', () {
      for (final path in [
        'lib/features/beta_proof_feedback/beta_proof_feedback_copy.dart',
        'lib/features/beta_proof_feedback/beta_proof_feedback_engine.dart',
        'lib/widgets/beta/beta_proof_feedback_row.dart',
      ]) {
        final source = File(path).readAsStringSync().toLowerCase();
        expect(source, isNot(contains('revenuecat')));
        expect(source, isNot(contains('restore purchases')));
      }
    });
  });

  group('Beta proof feedback placement', () {
    test('appears under TimelineProofMomentCard on patterns', () {
      final source = File(
        'lib/screens/archive_belief_screen.dart',
      ).readAsStringSync();
      final cardIndex = source.indexOf('TimelineProofMomentCard(');
      final rowIndex = source.indexOf(
        'surface: BetaProofFeedbackSurface.timelineProofMoment',
      );
      expect(cardIndex, greaterThan(0));
      expect(rowIndex, greaterThan(cardIndex));
    });

    test('appears under ArchiveTimelineSpineCard on patterns', () {
      final source = File(
        'lib/screens/archive_belief_screen.dart',
      ).readAsStringSync();
      final cardIndex = source.indexOf('ArchiveTimelineSpineCard(');
      final rowIndex = source.indexOf(
        'surface: BetaProofFeedbackSurface.archiveTimelineSpine',
      );
      expect(cardIndex, greaterThan(0));
      expect(rowIndex, greaterThan(cardIndex));
    });
  });
}