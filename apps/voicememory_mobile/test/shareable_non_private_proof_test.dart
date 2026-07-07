import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/beta_proof_feedback/beta_proof_feedback_model.dart';
import 'package:voicememory_mobile/features/beta_proof_feedback/beta_proof_feedback_store.dart';
import 'package:voicememory_mobile/features/shareable_proof/shareable_proof_analytics.dart';
import 'package:voicememory_mobile/features/shareable_proof/shareable_proof_copy.dart';
import 'package:voicememory_mobile/features/shareable_proof/shareable_proof_engine.dart';
import 'package:voicememory_mobile/features/shareable_proof/shareable_proof_model.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'package:voicememory_mobile/widgets/share/shareable_proof_card.dart';

class _MemoryPrefs extends MobilePrefsStore {
  _MemoryPrefs()
      : super(file: File('test/tmp/shareable_non_private_proof/unused.json'));

  final Map<String, Map<String, dynamic>> maps = {};

  @override
  Future<Map<String, dynamic>?> readMap(String key) async => maps[key];

  @override
  Future<void> writeMap(String key, Map<String, dynamic> value) async {
    maps[key] = value;
  }
}

ShareableProofVisibilityInput _input({
  bool timelineProofMomentSeen = false,
  bool betaTesterReportSeen = false,
  bool isRecording = false,
  bool isDegradedTranscript = false,
  bool whatChangedQuestionActive = false,
  bool patternReviewInboxHasActiveItems = false,
  int entryCount = 3,
}) =>
    ShareableProofVisibilityInput(
      entryCount: entryCount,
      timelineProofMomentSeen: timelineProofMomentSeen,
      betaTesterReportSeen: betaTesterReportSeen,
      isRecording: isRecording,
      isDegradedTranscript: isDegradedTranscript,
      whatChangedQuestionActive: whatChangedQuestionActive,
      patternReviewInboxHasActiveItems: patternReviewInboxHasActiveItems,
    );

ShareableProofResult _visibleResult({int entryCount = 3}) =>
    ShareableProofEngine.build(
      input: _input(
        timelineProofMomentSeen: true,
        entryCount: entryCount,
      ),
    );

void main() {
  final analyticsEvents = <({String event, Map<String, Object> props})>[];

  setUp(() async {
    ShareableProofSeenLatch.resetForTest();
    ShareableProofAnalytics.resetForTest();
    ShareableProofAnalytics.captureForTest = (event, props) {
      analyticsEvents.add((event: event, props: props));
    };
    analyticsEvents.clear();
    await BetaProofFeedbackStore.resetForTest(_MemoryPrefs());
  });

  tearDown(() {
    ShareableProofAnalytics.resetForTest();
  });

  group('ShareableProofCopy', () {
    test('fixed strings stay generic and safe', () {
      for (final text in ShareableProofCopy.allVisibleStrings) {
        expect(ShareableProofCopy.isSafeShareText(text), isTrue);
      }
    });

    test('rejects private markers and entry ids', () {
      expect(
        ShareableProofCopy.isSafeShareText(
          'entry_id: abc123 transcript body Maria said divorce',
        ),
        isFalse,
      );
    });

    test('no therapy or medical claims', () {
      const banned = [
        'therapy',
        'diagnosis',
        'medical treatment',
        'mental health score',
      ];
      for (final text in ShareableProofCopy.allVisibleStrings) {
        final lower = text.toLowerCase();
        for (final marker in banned) {
          expect(lower, isNot(contains(marker)));
        }
      }
    });

    test('no fake testimonials', () {
      for (final text in ShareableProofCopy.allVisibleStrings) {
        expect(text, isNot(contains('Maria said')));
        expect(text, isNot(contains('changed my life')));
        expect(text, isNot(startsWith('"')));
      }
    });
  });

  group('ShareableProofEngine', () {
    test('hidden before timeline proof or other positive triggers', () {
      expect(
        ShareableProofEngine.shouldShow(_input()),
        isFalse,
      );
      expect(ShareableProofEngine.build(input: _input()).shouldShow, isFalse);
    });

    test('visible after timeline proof seen', () {
      expect(
        ShareableProofEngine.shouldShow(
          _input(timelineProofMomentSeen: true),
        ),
        isTrue,
      );
    });

    test('visible after beta tester report seen', () {
      expect(
        ShareableProofEngine.shouldShow(
          _input(betaTesterReportSeen: true),
        ),
        isTrue,
      );
    });

    test('visible after useful proof feedback', () async {
      final store = BetaProofFeedbackStore.forPrefs(_MemoryPrefs());
      await store.saveAnswer(
        surface: BetaProofFeedbackSurface.timelineProofMoment,
        feedbackType: BetaProofFeedbackType.useful,
        entryCount: 3,
      );
      expect(ShareableProofEngine.shouldShow(_input()), isTrue);
    });

    test('hidden after Too vague feedback', () async {
      final store = BetaProofFeedbackStore.forPrefs(_MemoryPrefs());
      await store.saveAnswer(
        surface: BetaProofFeedbackSurface.timelineProofMoment,
        feedbackType: BetaProofFeedbackType.tooVague,
        entryCount: 3,
      );
      expect(
        ShareableProofEngine.shouldShow(
          _input(timelineProofMomentSeen: true),
        ),
        isFalse,
      );
    });

    test('hidden after Not relevant feedback', () async {
      final store = BetaProofFeedbackStore.forPrefs(_MemoryPrefs());
      await store.saveAnswer(
        surface: BetaProofFeedbackSurface.firstProofPayoff,
        feedbackType: BetaProofFeedbackType.notRelevant,
        entryCount: 3,
      );
      expect(
        ShareableProofEngine.shouldShow(
          _input(betaTesterReportSeen: true),
        ),
        isFalse,
      );
    });

    test('hidden while recording, degraded, What Changed, or inbox active', () {
      final base = _input(timelineProofMomentSeen: true);
      expect(
        ShareableProofEngine.shouldShow(
          _input(timelineProofMomentSeen: true, isRecording: true),
        ),
        isFalse,
      );
      expect(
        ShareableProofEngine.shouldShow(
          _input(timelineProofMomentSeen: true, isDegradedTranscript: true),
        ),
        isFalse,
      );
      expect(
        ShareableProofEngine.shouldShow(
          _input(
            timelineProofMomentSeen: true,
            whatChangedQuestionActive: true,
          ),
        ),
        isFalse,
      );
      expect(
        ShareableProofEngine.shouldShow(
          _input(
            timelineProofMomentSeen: true,
            patternReviewInboxHasActiveItems: true,
          ),
        ),
        isFalse,
      );
      expect(base.entryCount, 3);
    });
  });

  group('ShareableProofResult', () {
    test('share text does not include transcript, body, or entry ids', () {
      const privateLeak =
          'Maria said divorce entry_id e1 transcript concreteObservation';
      final result = _visibleResult();
      for (final template in ShareableProofTemplate.values) {
        final text = result.shareTextFor(template);
        expect(text.toLowerCase(), isNot(contains('transcript')));
        expect(text.toLowerCase(), isNot(contains('entry_id')));
        expect(text.toLowerCase(), isNot(contains('e1')));
        expect(text, isNot(contains(privateLeak)));
        expect(text, contains(ShareableProofCopy.privacyWarning));
      }
    });
  });

  group('ShareableProofAnalytics', () {
    test('metadata-only analytics payloads', () {
      final result = _visibleResult(entryCount: 5);
      ShareableProofAnalytics.seen(
        source: 'record',
        surface: 'record_ready',
        result: result,
      );
      ShareableProofAnalytics.copied(
        source: 'record',
        surface: 'record_ready',
        result: result,
        template: ShareableProofTemplate.keepsReturning,
      );
      ShareableProofAnalytics.shared(
        source: 'record',
        surface: 'record_ready',
        result: result,
        template: ShareableProofTemplate.chatGptDifferentiation,
      );

      expect(analyticsEvents.length, 3);
      for (final captured in analyticsEvents) {
        expect(captured.props.keys.toSet(), {
          'source',
          'surface',
          'entry_count',
          'share_template',
          'has_timeline_proof',
        });
        expect(captured.props['source'], 'record');
        expect(captured.props['surface'], 'record_ready');
        expect(captured.props['entry_count'], 5);
        expect(captured.props['has_timeline_proof'], 1);
      }
      expect(analyticsEvents[0].event, ShareableProofAnalytics.seenEvent);
      expect(analyticsEvents[1].event, ShareableProofAnalytics.copiedEvent);
      expect(analyticsEvents[2].event, ShareableProofAnalytics.sharedEvent);
    });
  });

  group('ShareableProofCard', () {
    Future<void> _pumpCard(
      WidgetTester tester, {
      required ShareableProofResult result,
      Future<void> Function(String text)? onCopy,
      Future<void> Function(String text)? onShare,
    }) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShareableProofCard.test(
              result: result,
              source: 'record',
              surface: 'record_ready',
              onCopy: onCopy,
              onShare: onShare,
            ),
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('renders title and privacy warning', (tester) async {
      await _pumpCard(tester, result: _visibleResult());
      expect(
        find.text('Share the idea, not your archive'),
        findsOneWidget,
      );
      expect(
        find.text('Your saved moments are never included.'),
        findsOneWidget,
      );
    });

    testWidgets('hidden when engine says not to show', (tester) async {
      await _pumpCard(
        tester,
        result: ShareableProofEngine.build(input: _input()),
      );
      expect(find.byKey(const Key('shareable_non_private_proof_card')), findsNothing);
    });

    testWidgets('copy and share require explicit tap', (tester) async {
      String? copied;
      String? shared;
      await _pumpCard(
        tester,
        result: _visibleResult(),
        onCopy: (text) async {
          copied = text;
        },
        onShare: (text) async {
          shared = text;
        },
      );

      expect(copied, isNull);
      expect(shared, isNull);
      expect(analyticsEvents.where((e) => e.event.contains('copied')), isEmpty);
      expect(analyticsEvents.where((e) => e.event.contains('shared')), isEmpty);

      await tester.tap(find.byKey(const Key('shareable_non_private_proof_copy')));
      await tester.pump();
      expect(copied, isNotNull);
      expect(
        analyticsEvents.any(
          (e) => e.event == ShareableProofAnalytics.copiedEvent,
        ),
        isTrue,
      );

      await tester.tap(find.byKey(const Key('shareable_non_private_proof_share')));
      await tester.pump();
      expect(shared, isNotNull);
      expect(
        analyticsEvents.any(
          (e) => e.event == ShareableProofAnalytics.sharedEvent,
        ),
        isTrue,
      );
    });

    testWidgets('selected template stays generic in share text', (tester) async {
      String? shared;
      await _pumpCard(
        tester,
        result: _visibleResult(),
        onShare: (text) async {
          shared = text;
        },
      );

      await tester.tap(
        find.byKey(
          const Key('shareable_non_private_proof_template_chatgpt_differentiation'),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('shareable_non_private_proof_share')));
      await tester.pump();

      expect(shared, contains(ShareableProofCopy.templateChatGptDifferentiation));
      expect(shared, contains(ShareableProofCopy.privacyWarning));
      expect(shared!.toLowerCase(), isNot(contains('transcript')));
      expect(shared!.toLowerCase(), isNot(contains('entry_id')));
    });
  });
}
