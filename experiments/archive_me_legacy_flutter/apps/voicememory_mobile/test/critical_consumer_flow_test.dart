import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/activation/first_loop_activation_model.dart';
import 'package:voicememory_mobile/features/activation/first_loop_activation_store.dart';
import 'package:voicememory_mobile/features/activation/return_day_friction_model.dart';
import 'package:voicememory_mobile/features/activation/return_day_friction_store.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/widgets/record/first_loop_start_card.dart';
import 'package:voicememory_mobile/widgets/record/return_day_closed_card.dart';

// Smoke coverage for the critical consumer loop. These tests stay at the
// card + state-machine level so they are fast and deterministic (full-screen
// pump-and-settle is intentionally avoided — it hangs headless).

Future<void> _reset(String stamp) async {
  await AppServices.resetForTest(
    journalPath: '/tmp/vm_flow_journal_$stamp.json',
    prefsPath: '/tmp/vm_flow_prefs_$stamp.json',
  );
}

Widget _wrap(Widget child) => MaterialApp(
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  group('first run framing', () {
    testWidgets('first open shows "Start with one moment"', (tester) async {
      await tester.pumpWidget(_wrap(FirstLoopStartCard(onRecord: () {})));
      expect(find.text(FirstLoopStartCard.title), findsOneWidget);
      expect(find.text('Start with one moment'), findsOneWidget);
      expect(find.text(FirstLoopStartCard.cta), findsOneWidget);
    });

    testWidgets('record CTA fires its callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        _wrap(FirstLoopStartCard(onRecord: () => tapped = true)),
      );
      await tester.tap(find.text(FirstLoopStartCard.cta));
      expect(tapped, isTrue);
    });
  });

  group('first-loop progression to loop ready', () {
    test('save then choosing tomorrow check reaches loopReady', () async {
      final stamp = DateTime.now().microsecondsSinceEpoch.toString();
      await _reset(stamp);
      final store = FirstLoopActivationStore(AppServices.instance.prefs);

      expect((await store.load()).stage, FirstLoopActivationStage.notStarted);

      await store.markFirstMomentSaved();
      expect(
        (await store.load()).stage,
        FirstLoopActivationStage.firstMomentSaved,
      );

      await store.markFirstPatternShown('Saying yes too fast');
      await store.markTomorrowCheckChosen('Did this show up again?');
      final ready = await store.markLoopReady(
        'Saying yes too fast',
        'Did this show up again?',
      );

      expect(ready.stage, FirstLoopActivationStage.loopReady);
      expect(ready.isComplete, isTrue);
      expect(ready.tomorrowQuestion, 'Did this show up again?');
    });
  });

  group('return-day loop', () {
    test('due -> answer -> loop closed progresses and completes', () async {
      final stamp = DateTime.now().microsecondsSinceEpoch.toString();
      await _reset(stamp);
      final store = ReturnDayFrictionStore(AppServices.instance.prefs);

      expect((await store.load()).stage, ReturnDayFrictionStage.notDue);

      await store.markDueShown('cid-1');
      expect((await store.load()).stage, ReturnDayFrictionStage.dueShown);

      await store.markAnswerSelected('cid-1', 'showed_up_again');
      expect((await store.load()).stage, ReturnDayFrictionStage.answerSelected);

      final closed = await store.markLoopClosed('cid-1');
      expect(closed.stage, ReturnDayFrictionStage.loopClosed);
      expect(closed.isComplete, isTrue);
    });

    test('a new check-in resets the funnel', () async {
      final stamp = DateTime.now().microsecondsSinceEpoch.toString();
      await _reset(stamp);
      final store = ReturnDayFrictionStore(AppServices.instance.prefs);

      await store.markLoopClosed('cid-1');
      final fresh = await store.markDueShown('cid-2');
      expect(fresh.checkInId, 'cid-2');
      expect(fresh.stage, ReturnDayFrictionStage.dueShown);
    });

    testWidgets('answer step exposes a record-one-moment CTA copy', (
      tester,
    ) async {
      // The one-tap return-day flow asks for one short moment after an answer.
      expect(ConsumerUiCopy.tomorrowCheckInOneTapRecordCta, isNotEmpty);
    });

    testWidgets('post-save shows "Loop closed"', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ReturnDayClosedCard(
            resultHeadline: 'This pattern showed up again.',
            usefulLine: 'It often starts before saying yes.',
            nextCheck: 'What happens right before it starts?',
            onDone: () {},
          ),
        ),
      );
      expect(find.text(ReturnDayClosedCard.title), findsOneWidget);
      expect(find.text('Loop closed'), findsOneWidget);
      expect(find.text('What happens right before it starts?'), findsOneWidget);
    });
  });
}
