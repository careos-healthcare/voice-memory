import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/features/first_session/two_day_activation_engine.dart';
import 'package:voicememory_mobile/features/memory/memory_scope.dart';
import 'package:voicememory_mobile/features/memory/memory_scope_policy.dart';
import 'package:voicememory_mobile/features/onboarding/first_save_loop_state.dart';
import 'package:voicememory_mobile/features/retention/repeat_recording_nudge_state.dart';
import 'package:voicememory_mobile/features/retention/repeat_recording_nudge_store.dart';
import 'package:voicememory_mobile/services/activation_funnel_analytics.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/onboarding/day2_change_bridge_card.dart';
import 'package:voicememory_mobile/widgets/retention/day2_return_reason_card.dart';
import 'package:voicememory_mobile/widgets/retention/second_entry_nudge_card.dart';
import 'package:voicememory_mobile/widgets/retention/tiny_record_again_cta.dart';

class _Event {
  const _Event(this.name, this.properties);
  final String name;
  final Map<String, Object> properties;
}

final List<_Event> _events = [];

const _bannedWords = [
  'always',
  'never',
  'proves',
  'definitely',
  'diagnosis',
  'diagnose',
  'therapy',
  'treatment',
  'fixed',
  'broken',
  'problem',
  'failure',
  'lazy',
  'weak',
  'must',
  'should',
  'surveillance',
  'spying',
  'tracking',
  'VoiceMemory',
];

void main() {
  setUp(() {
    _events.clear();
    RepeatRecordingNudgeSession.resetForTest();
    MemoryScopePolicy.resetForTest();
    ActivationFunnelAnalytics.resetForTest();
    ActivationFunnelAnalytics.captureForTest(
      (event, properties) => _events.add(_Event(event, properties)),
    );
  });

  tearDown(ActivationFunnelAnalytics.resetForTest);

  group('Second-entry nudge gates', () {
    test('appears for exactly one entry after first save', () {
      expect(
        RepeatRecordingNudgeGates.showSecondEntryNudge(
          entryCount: 1,
          justSaved: false,
          hiddenThisSession: false,
        ),
        isTrue,
      );
    });

    test('does not appear for zero entries', () {
      expect(
        RepeatRecordingNudgeGates.showSecondEntryNudge(
          entryCount: 0,
          justSaved: false,
          hiddenThisSession: false,
        ),
        isFalse,
      );
    });

    test('does not appear after two or more entries', () {
      expect(
        RepeatRecordingNudgeGates.showSecondEntryNudge(
          entryCount: 2,
          justSaved: false,
          hiddenThisSession: false,
        ),
        isFalse,
      );
    });

    test('does not appear during the first-save receipt', () {
      expect(
        RepeatRecordingNudgeGates.showSecondEntryNudge(
          entryCount: 1,
          justSaved: true,
          hiddenThisSession: false,
        ),
        isFalse,
      );
    });

    test('does not claim pattern/change as detected', () {
      final copy = RepeatRecordingNudgeCopy.all.join(' ').toLowerCase();
      expect(copy, isNot(contains('pattern detected')));
      expect(copy, isNot(contains('we found')));
      expect(copy, isNot(contains('change detected')));
      expect(copy, isNot(contains('your pattern is')));
    });
  });

  group('Day 2 return reason', () {
    final day2Path = const TwoDayActivationEngine().build(
      entryCount: 1,
      entryDates: [DateTime(2026, 6, 11, 12)],
      now: DateTime(2026, 6, 12, 12),
    );

    test('appears for returning one-entry user', () {
      expect(day2Path.stage, TwoDayActivationStage.dayTwoReturn);
      expect(
        RepeatRecordingNudgeGates.showDay2ReturnReason(
          entryCount: 1,
          twoDayPath: day2Path,
          hasRealChangeInsight: false,
          hiddenThisSession: false,
        ),
        isTrue,
      );
    });

    test('is suppressed when real insight exists', () {
      expect(
        RepeatRecordingNudgeGates.showDay2ReturnReason(
          entryCount: 1,
          twoDayPath: day2Path,
          hasRealChangeInsight: true,
          hiddenThisSession: false,
        ),
        isFalse,
      );
    });

    test('memory off copy is safe', () {
      expect(
        RepeatRecordingNudgeGates.day2BodyForScope(MemoryScope.off),
        RepeatRecordingNudgeCopy.day2BodyMemoryOff,
      );
    });

    testWidgets('renders memory-off body', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Day2ReturnReasonCard(onRecord: () {}, memoryOff: true),
        ),
      );
      await tester.pump();

      expect(
        find.text(RepeatRecordingNudgeCopy.day2BodyMemoryOff),
        findsOneWidget,
      );
    });
  });

  group('Record again CTA', () {
    testWidgets('routes to recorder', (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: TinyRecordAgainCta(
                entryCount: 2,
                source: 'archive',
                onRecord: () => context.go('/record'),
              ),
            ),
          ),
          GoRoute(
            path: '/record',
            builder: (context, state) =>
                const Scaffold(body: Text('Recorder screen')),
          ),
        ],
      );

      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump();

      await tester.tap(find.byKey(const Key('record_again_cta_archive')));
      await tester.pumpAndSettle();

      expect(find.text('Recorder screen'), findsOneWidget);
    });
  });

  group('Session spam guard', () {
    testWidgets('second-entry nudge fires seen once per session', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: SecondEntryNudgeCard(onRecord: () {}, onDismiss: () {}),
        ),
      );
      await tester.pump();

      expect(
        _events.where((e) => e.name == 'second_entry_nudge_seen').length,
        1,
      );

      expect(
        RepeatRecordingNudgeGates.showSecondEntryNudge(
          entryCount: 1,
          justSaved: false,
          hiddenThisSession: RepeatRecordingNudgeSession.secondEntryHidden,
        ),
        isFalse,
      );
    });
  });

  group('Analytics privacy', () {
    test('payload contains no private content', () {
      ActivationFunnelAnalytics.track(
        ActivationFunnelAnalytics.secondEntryNudgeTapped,
        entryCount: 1,
        source: 'archive',
        stage: RepeatRecordingNudgeStage.secondEntry,
        memoryScope: MemoryScope.automatic.id,
      );
      ActivationFunnelAnalytics.track(
        ActivationFunnelAnalytics.day2ReturnReasonSeen,
        entryCount: 1,
        source: 'record',
        stage: RepeatRecordingNudgeStage.day2Return,
        memoryScope: MemoryScope.off.id,
      );

      final payloads = _events
          .map((e) => '${e.name} ${e.properties}')
          .join('\n');
      expect(payloads.contains('transcript'), isFalse);
      for (final event in _events) {
        expect(
          event.properties.keys.toSet().difference(
            ActivationFunnelAnalytics.allowedPropertyKeys,
          ),
          isEmpty,
        );
      }
    });
  });

  group('Copy guardrails', () {
    test('no VoiceMemory in consumer copy', () {
      for (final line in RepeatRecordingNudgeCopy.all) {
        expect(line.contains('VoiceMemory'), isFalse);
      }
    });

    test('banned-word sweep', () {
      final corpus = RepeatRecordingNudgeCopy.all.join('\n').toLowerCase();
      for (final word in _bannedWords) {
        expect(
          RegExp('\\b${word.toLowerCase()}\\b').hasMatch(corpus),
          isFalse,
          reason: 'banned word: $word',
        );
      }
    });

    test('legacy Day 2 bridge delegates to new copy', () {
      expect(
        FirstSaveLoopGates.showDay2Bridge(
          entryCount: 1,
          stage: TwoDayActivationStage.dayTwoReturn,
          hasRealChangeInsight: false,
        ),
        isTrue,
      );
    });
  });

  group('Legacy wrapper', () {
    testWidgets('Day2ChangeBridgeCard shows new title', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Day2ChangeBridgeCard(onRecord: () {}),
        ),
      );
      await tester.pump();

      expect(find.text(RepeatRecordingNudgeCopy.day2Title), findsOneWidget);
    });
  });
}
