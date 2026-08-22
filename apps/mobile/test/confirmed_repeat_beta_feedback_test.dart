import 'dart:io';

import 'package:archiveme_mobile/features/beta/confirmed_repeat_beta_feedback_analytics.dart';
import 'package:archiveme_mobile/features/beta/confirmed_repeat_beta_feedback_copy.dart';
import 'package:archiveme_mobile/features/beta/confirmed_repeat_beta_feedback_gates.dart';
import 'package:archiveme_mobile/features/beta/confirmed_repeat_beta_feedback_models.dart';
import 'package:archiveme_mobile/features/beta/confirmed_repeat_beta_feedback_store.dart';
import 'package:archiveme_mobile/security/privacy_copy_policy.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:archiveme_mobile/widgets/beta/confirmed_repeat_beta_feedback_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryPrefs extends MobilePrefsStore {
  _MemoryPrefs()
    : super(file: File('test/tmp/confirmed_repeat_beta/unused.json'));

  final Map<String, Map<String, dynamic>> maps = {};

  @override
  Future<Map<String, dynamic>?> readMap(String key) async => maps[key];

  @override
  Future<void> writeMap(String key, Map<String, dynamic> value) async {
    maps[key] = value;
  }
}

void _expectNoDiagnosticLanguage(String copy) {
  final lower = copy.toLowerCase();
  expect(lower, isNot(contains('diagnosis')));
  expect(lower, isNot(contains('therapy')));
  expect(lower, isNot(contains('disorder')));
}

void main() {
  setUp(() async {
    ConfirmedRepeatBetaFeedbackAnalytics.resetForTest();
    await AppServices.resetForTest(
      journalPath:
          '${DateTime.now().microsecondsSinceEpoch}_confirmed_repeat_beta.json',
      prefsPath: '${DateTime.now().microsecondsSinceEpoch}_prefs.json',
      skipRevenueCat: true,
    );
    await ConfirmedRepeatBetaFeedbackStore.resetForTest();
  });

  group('ConfirmedRepeatBetaFeedbackGates', () {
    test('hidden before confirmed repeat', () {
      expect(
        ConfirmedRepeatBetaFeedbackGates.shouldShow(
          viewingConfirmedRepeat: false,
          isRecording: false,
          entryCount: 3,
          state: ConfirmedRepeatBetaFeedbackState.empty,
        ),
        isFalse,
      );
    });

    test('hidden before entry count 3', () {
      expect(
        ConfirmedRepeatBetaFeedbackGates.shouldShow(
          viewingConfirmedRepeat: true,
          isRecording: false,
          entryCount: 2,
          state: ConfirmedRepeatBetaFeedbackState.empty,
        ),
        isFalse,
      );
    });

    test('visible after confirmed repeat with enough entries', () {
      expect(
        ConfirmedRepeatBetaFeedbackGates.shouldShow(
          viewingConfirmedRepeat: true,
          isRecording: false,
          entryCount: 3,
          state: ConfirmedRepeatBetaFeedbackState.empty,
        ),
        isTrue,
      );
    });

    test('hidden while recording', () {
      expect(
        ConfirmedRepeatBetaFeedbackGates.shouldShow(
          viewingConfirmedRepeat: true,
          isRecording: true,
          entryCount: 3,
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
          entryCount: 3,
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
          entryCount: 3,
          state: const ConfirmedRepeatBetaFeedbackState(dismissed: true),
        ),
        isFalse,
      );
    });
  });

  group('ConfirmedRepeatBetaFeedbackStore', () {
    test('persists choice and follow-up reason locally', () async {
      final prefs = _MemoryPrefs();
      final store = ConfirmedRepeatBetaFeedbackStore(prefs);

      await store.saveResponse(
        choice: ConfirmedRepeatBetaFeedbackChoice.notReally,
        reason: ConfirmedRepeatBetaFeedbackReason.wrongPattern,
      );

      final loaded = await store.load();
      expect(loaded.choice, ConfirmedRepeatBetaFeedbackChoice.notReally);
      expect(loaded.reason, ConfirmedRepeatBetaFeedbackReason.wrongPattern);
      expect(loaded.completed, isTrue);
    });

    test('dismiss persists without a choice', () async {
      final prefs = _MemoryPrefs();
      final store = ConfirmedRepeatBetaFeedbackStore(prefs);

      await store.dismiss();
      final loaded = await store.load();
      expect(loaded.dismissed, isTrue);
      expect(loaded.choice, isNull);
      expect(loaded.completed, isTrue);
    });

    test('migrates legacy needMore choice to somewhat', () {
      final migrated = ConfirmedRepeatBetaFeedbackState.fromJson({
        'choice': 'needMore',
        'dismissed': false,
      });
      expect(migrated.choice, ConfirmedRepeatBetaFeedbackChoice.somewhat);
    });
  });

  group('ConfirmedRepeatBetaFeedbackCopy', () {
    test('no hard or therapy language', () {
      _expectNoDiagnosticLanguage(
        ConfirmedRepeatBetaFeedbackCopy.all.join(' '),
      );
      for (final line in ConfirmedRepeatBetaFeedbackCopy.all) {
        for (final reason in PrivacyCopyPolicy.violationsInLiteral(line)) {
          fail('"$line": $reason');
        }
      }
    });
  });

  group('ConfirmedRepeatBetaFeedbackCard', () {
    testWidgets('renders prompt and answer buttons', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
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

      expect(find.text(ConfirmedRepeatBetaFeedbackCopy.prompt), findsOneWidget);
      expect(find.text(ConfirmedRepeatBetaFeedbackCopy.yes), findsOneWidget);
      expect(
        find.text(ConfirmedRepeatBetaFeedbackCopy.somewhat),
        findsOneWidget,
      );
      expect(
        find.text(ConfirmedRepeatBetaFeedbackCopy.notReally),
        findsOneWidget,
      );
    });

    testWidgets('yes answer stores safe metadata', (tester) async {
      final prefs = _MemoryPrefs();
      final store = ConfirmedRepeatBetaFeedbackStore(prefs);
      Map<String, Object>? captured;

      ConfirmedRepeatBetaFeedbackAnalytics.captureForTest = (event, props) {
        captured = props;
      };

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
        await tester.tap(
          find.byKey(const Key('confirmed_repeat_beta_feedback_yes')),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();

      expect(captured, isNotNull);
      expect(captured!['surface'], 'record');
      expect(captured!['entry_count'], 3);
      expect(captured!['answer'], 'yes');
      expect(captured!.containsKey('reason'), isFalse);
      expect(captured!.containsKey('transcript'), isFalse);

      final loaded = await store.load();
      expect(loaded.choice, ConfirmedRepeatBetaFeedbackChoice.yes);
      expect(loaded.reason, isNull);
    });

    testWidgets('somewhat answer shows follow-up', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
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

      await tester.tap(
        find.byKey(const Key('confirmed_repeat_beta_feedback_somewhat')),
      );
      await tester.pump();

      expect(
        find.text(ConfirmedRepeatBetaFeedbackCopy.followUpPrompt),
        findsOneWidget,
      );
      expect(
        find.text(ConfirmedRepeatBetaFeedbackCopy.tooGeneric),
        findsOneWidget,
      );
      expect(
        find.text(ConfirmedRepeatBetaFeedbackCopy.wrongPattern),
        findsOneWidget,
      );
    });

    testWidgets('not really answer shows follow-up', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ConfirmedRepeatBetaFeedbackCard.test(
              entryCount: 3,
              surface: 'patterns',
              viewingConfirmedRepeat: true,
              isRecording: false,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(
        find.byKey(const Key('confirmed_repeat_beta_feedback_not_really')),
      );
      await tester.pump();

      expect(
        find.text(ConfirmedRepeatBetaFeedbackCopy.followUpPrompt),
        findsOneWidget,
      );
      expect(
        find.text(ConfirmedRepeatBetaFeedbackCopy.repeatedTooMuch),
        findsOneWidget,
      );
    });

    testWidgets('follow-up reasons stored without transcript text', (
      tester,
    ) async {
      final prefs = _MemoryPrefs();
      final store = ConfirmedRepeatBetaFeedbackStore(prefs);
      Map<String, Object>? captured;

      ConfirmedRepeatBetaFeedbackAnalytics.captureForTest = (event, props) {
        captured = props;
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConfirmedRepeatBetaFeedbackCard.test(
              entryCount: 4,
              surface: 'patterns',
              viewingConfirmedRepeat: true,
              isRecording: false,
              store: store,
            ),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(
        find.byKey(const Key('confirmed_repeat_beta_feedback_somewhat')),
      );
      await tester.pump();
      await tester.runAsync(() async {
        await tester.tap(
          find.byKey(
            const Key('confirmed_repeat_beta_feedback_reason_tooGeneric'),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();

      expect(captured, isNotNull);
      expect(captured!['answer'], 'somewhat');
      expect(captured!['reason'], 'too_generic');
      expect(captured!.containsKey('transcript'), isFalse);

      final loaded = await store.load();
      expect(loaded.choice, ConfirmedRepeatBetaFeedbackChoice.somewhat);
      expect(loaded.reason, ConfirmedRepeatBetaFeedbackReason.tooGeneric);
    });

    testWidgets('dismiss persists and hides card', (tester) async {
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
        await tester.tap(
          find.byKey(const Key('confirmed_repeat_beta_feedback_dismiss')),
        );
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

    testWidgets('does not block recording', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const ConfirmedRepeatBetaFeedbackCard.test(
                  entryCount: 3,
                  surface: 'record',
                  viewingConfirmedRepeat: true,
                  isRecording: false,
                ),
                FilledButton(
                  key: const Key('record_primary_cta'),
                  onPressed: () {},
                  child: const Text('Record moment'),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('confirmed_repeat_beta_feedback_card')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('record_primary_cta')), findsOneWidget);
      await tester.tap(find.byKey(const Key('record_primary_cta')));
      await tester.pump();
    });

    testWidgets('hidden while recording', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
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

      expect(find.text(ConfirmedRepeatBetaFeedbackCopy.prompt), findsNothing);
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
}