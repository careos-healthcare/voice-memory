import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/beta/confirmed_repeat_beta_feedback_analytics.dart';
import 'package:voicememory_mobile/features/beta/confirmed_repeat_beta_feedback_copy.dart';
import 'package:voicememory_mobile/features/beta/confirmed_repeat_beta_feedback_gates.dart';
import 'package:voicememory_mobile/features/beta/confirmed_repeat_beta_feedback_models.dart';
import 'package:voicememory_mobile/features/beta/confirmed_repeat_beta_feedback_store.dart';
import 'package:voicememory_mobile/services/activation_funnel_analytics.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';
import 'package:voicememory_mobile/widgets/beta/confirmed_repeat_beta_feedback_card.dart';

class _MemoryPrefs extends MobilePrefsStore {
  _MemoryPrefs() : super(file: File('test/tmp/confirmed_repeat_beta/unused.json'));

  final Map<String, Map<String, dynamic>> maps = {};

  @override
  Future<Map<String, dynamic>?> readMap(String key) async => maps[key];

  @override
  Future<void> writeMap(String key, Map<String, dynamic> value) async {
    maps[key] = value;
  }
}

void main() {
  late List<({String event, Map<String, Object> properties})> captured;

  setUp(() async {
    captured = [];
    ActivationFunnelAnalytics.resetForTest();
    ActivationFunnelAnalytics.captureForTest(
      (event, properties) =>
          captured.add((event: event, properties: properties)),
    );
    await AppServices.resetForTest(
      journalPath:
          '${DateTime.now().microsecondsSinceEpoch}_confirmed_repeat_beta.json',
      prefsPath: '${DateTime.now().microsecondsSinceEpoch}_prefs.json',
      skipRevenueCat: true,
    );
    await ConfirmedRepeatBetaFeedbackStore.resetForTest();
  });

  tearDown(ActivationFunnelAnalytics.resetForTest);

  group('ConfirmedRepeatBetaFeedbackGates', () {
    test('shows only while viewing confirmed repeat and not recording', () {
      expect(
        ConfirmedRepeatBetaFeedbackGates.shouldShow(
          viewingConfirmedRepeat: true,
          isRecording: false,
          state: ConfirmedRepeatBetaFeedbackState.empty,
        ),
        isTrue,
      );
      expect(
        ConfirmedRepeatBetaFeedbackGates.shouldShow(
          viewingConfirmedRepeat: false,
          isRecording: false,
          state: ConfirmedRepeatBetaFeedbackState.empty,
        ),
        isFalse,
      );
      expect(
        ConfirmedRepeatBetaFeedbackGates.shouldShow(
          viewingConfirmedRepeat: true,
          isRecording: true,
          state: ConfirmedRepeatBetaFeedbackState.empty,
        ),
        isFalse,
      );
    });

    test('never shows again after response or dismiss', () {
      expect(
        ConfirmedRepeatBetaFeedbackGates.shouldShow(
          viewingConfirmedRepeat: true,
          isRecording: false,
          state: const ConfirmedRepeatBetaFeedbackState(
            choice: ConfirmedRepeatBetaFeedbackChoice.yes,
          ),
        ),
        isFalse,
      );
      expect(
        ConfirmedRepeatBetaFeedbackGates.shouldShow(
          viewingConfirmedRepeat: true,
          isRecording: false,
          state: const ConfirmedRepeatBetaFeedbackState(dismissed: true),
        ),
        isFalse,
      );
    });
  });

  group('ConfirmedRepeatBetaFeedbackStore', () {
    test('persists choice and optional note locally', () async {
      final prefs = _MemoryPrefs();
      final store = ConfirmedRepeatBetaFeedbackStore(prefs);

      await store.saveResponse(
        choice: ConfirmedRepeatBetaFeedbackChoice.notReally,
        note: 'The overlap felt too broad.',
      );

      final loaded = await store.load();
      expect(loaded.choice, ConfirmedRepeatBetaFeedbackChoice.notReally);
      expect(loaded.note, 'The overlap felt too broad.');
      expect(loaded.completed, isTrue);
    });

    test('dismiss marks completed without a choice', () async {
      final prefs = _MemoryPrefs();
      final store = ConfirmedRepeatBetaFeedbackStore(prefs);

      await store.dismiss();
      final loaded = await store.load();
      expect(loaded.dismissed, isTrue);
      expect(loaded.choice, isNull);
      expect(loaded.completed, isTrue);
    });
  });

  group('ConfirmedRepeatBetaFeedbackCard', () {
    testWidgets('renders prompt and choice buttons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConfirmedRepeatBetaFeedbackCard.test(
              entryCount: 3,
              surface: 'record',
              viewingConfirmedRepeat: true,
              isRecording: false,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Did this feel true?'), findsOneWidget);
      expect(find.text('Yes'), findsOneWidget);
      expect(find.text('Not really'), findsOneWidget);
      expect(find.text('I need to add more'), findsOneWidget);
    });

    testWidgets('shows optional note step after choice', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConfirmedRepeatBetaFeedbackCard.test(
              entryCount: 3,
              surface: 'record',
              viewingConfirmedRepeat: true,
              isRecording: false,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('confirmed_repeat_beta_feedback_yes')));
      await tester.pump();

      expect(
        find.text('What made it useful or wrong?'),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('confirmed_repeat_beta_feedback_note_field')),
        findsOneWidget,
      );
    });

    testWidgets('saves response locally and thanks user', (tester) async {
      final prefs = _MemoryPrefs();
      final store = ConfirmedRepeatBetaFeedbackStore(prefs);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConfirmedRepeatBetaFeedbackCard.test(
              entryCount: 3,
              surface: 'patterns',
              viewingConfirmedRepeat: true,
              isRecording: false,
              store: store,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('confirmed_repeat_beta_feedback_need_more')));
      await tester.pump();
      await tester.enterText(
        find.byKey(const Key('confirmed_repeat_beta_feedback_note_field')),
        'Need one more honest moment before I trust it.',
      );
      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('confirmed_repeat_beta_feedback_save_note')));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();

      expect(
        find.text(ConfirmedRepeatBetaFeedbackCopy.thanks),
        findsOneWidget,
      );
      final loaded = await store.load();
      expect(loaded.choice, ConfirmedRepeatBetaFeedbackChoice.needMore);
      expect(loaded.note, 'Need one more honest moment before I trust it.');
    });

    testWidgets('dismiss hides card without saving a choice', (tester) async {
      final prefs = _MemoryPrefs();
      final store = ConfirmedRepeatBetaFeedbackStore(prefs);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConfirmedRepeatBetaFeedbackCard.test(
              entryCount: 3,
              surface: 'record',
              viewingConfirmedRepeat: true,
              isRecording: false,
              store: store,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.runAsync(() async {
        await tester.tap(find.byKey(const Key('confirmed_repeat_beta_feedback_dismiss')));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();

      expect(
        find.byKey(const Key('confirmed_repeat_beta_feedback_card')),
        findsNothing,
      );
      final loaded = await store.load();
      expect(loaded.dismissed, isTrue);
      expect(loaded.choice, isNull);
    });

    testWidgets('hidden while recording', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConfirmedRepeatBetaFeedbackCard.test(
              entryCount: 3,
              surface: 'record',
              viewingConfirmedRepeat: true,
              isRecording: true,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Did this feel true?'), findsNothing);
    });
  });

  group('Inline accuracy suppression', () {
    test('hides legacy row while one-time beta prompt is pending', () {
      expect(
        ConfirmedRepeatBetaFeedbackGates.suppressInlineAccuracyFeedback(
          state: ConfirmedRepeatBetaFeedbackState.empty,
        ),
        isTrue,
      );
      expect(
        ConfirmedRepeatBetaFeedbackGates.suppressInlineAccuracyFeedback(
          state: const ConfirmedRepeatBetaFeedbackState(
            choice: ConfirmedRepeatBetaFeedbackChoice.yes,
          ),
        ),
        isFalse,
      );
    });
  });

  group('Analytics privacy', () {
    test('records metadata only — never note or transcript text', () {
      ConfirmedRepeatBetaFeedbackAnalytics.recordChoice(
        choice: ConfirmedRepeatBetaFeedbackChoice.yes,
        entryCount: 3,
        surface: 'record',
      );
      ConfirmedRepeatBetaFeedbackAnalytics.recordNoteSaved(
        choice: ConfirmedRepeatBetaFeedbackChoice.yes,
        entryCount: 3,
        surface: 'record',
        hasNote: true,
      );

      expect(captured, hasLength(2));
      for (final event in captured) {
        final payload = '${event.event} ${event.properties}'.toLowerCase();
        expect(payload, isNot(contains('transcript')));
        expect(payload, isNot(contains('said yes')));
        expect(payload, isNot(contains('useful or wrong')));
      }
      expect(captured.first.properties['reason'], 'yes');
      expect(captured.last.properties['method'], 'has_note');
    });
  });
}
