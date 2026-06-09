import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/activation/activation_events_store.dart';
import 'package:voicememory_mobile/features/activation/activation_tracker.dart';
import 'package:voicememory_mobile/features/routine/routine_anchor_model.dart';
import 'package:voicememory_mobile/features/tomorrow_return/tomorrow_check_in_model.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/widgets/record/result_next_check_card.dart';
import 'package:voicememory_mobile/widgets/routine/routine_anchor_chooser.dart';

Future<void> _reset(String stamp) async {
  await AppServices.resetForTest(
    journalPath: '/tmp/vm_rescue_next_check_journal_$stamp.json',
    prefsPath: '/tmp/vm_rescue_next_check_prefs_$stamp.json',
  );
}

TomorrowCheckIn _completed() => TomorrowCheckIn(
      id: 't1',
      createdAt: DateTime(2026, 5, 25),
      targetDate: '2026-05-26',
      patternTitle: 'Pattern',
      prompt: 'Tomorrow, check whether this pattern shows up again.',
      question: 'Did this pattern show up again?',
      options: kDefaultTomorrowCheckInOptions,
      selectedOptionId: 'lighter',
      completedAt: DateTime(2026, 5, 26),
    );

void main() {
  testWidgets('Use this tomorrow confirms tomorrow check', (tester) async {
    String? created;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ResultNextCheckCard(
              checkIn: _completed(),
              onCreateCheckIn: (q) async => created = q,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text(ConsumerUiCopy.resultNextCheckUseTomorrowCta));
    await tester.pump();

    expect(created, isNotNull);
    expect(find.text(ConsumerUiCopy.resultNextCheckConfirmation), findsOneWidget);
  });

  testWidgets('routine anchor is optional after next-check use', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ResultNextCheckCard(
              checkIn: _completed(),
              onCreateCheckIn: (_) async {},
              routineAnchorPicker: () async => null,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text(ConsumerUiCopy.resultNextCheckUseTomorrowCta));
    await tester.pump();

    expect(find.text(ConsumerUiCopy.resultNextCheckConfirmation), findsOneWidget);
    expect(find.text(RoutineAnchorChooser.title), findsNothing);
  });

  testWidgets('routine anchor can be set after next-check use', (tester) async {
    RoutineAnchor? saved;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ResultNextCheckCard(
              checkIn: _completed(),
              onCreateCheckIn: (_) async {},
              routineAnchorPicker: () async =>
                  const RoutineAnchor(type: RoutineAnchorType.morning),
              onRoutineAnchorChosen: (a) async => saved = a,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text(ConsumerUiCopy.resultNextCheckUseTomorrowCta));
    await tester.pump();

    expect(saved!.type, RoutineAnchorType.morning);
  });

  test('next check activation events increment', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    final store = ActivationEventsStore(AppServices.instance.prefs);

    await ActivationTracker.trackActivationNextCheckShown();
    await ActivationTracker.trackActivationNextCheckUsed();
    await ActivationTracker.trackActivationNextCheckChanged();
    await ActivationTracker.trackActivationRoutineAnchorOffered();
    await ActivationTracker.trackActivationRoutineAnchorSet();
    final events = await store.read();
    expect(events.activationNextCheckShown, 1);
    expect(events.activationNextCheckUsed, 1);
    expect(events.activationNextCheckChanged, 1);
    expect(events.activationRoutineAnchorOffered, 1);
    expect(events.activationRoutineAnchorSet, 1);
  });
}
