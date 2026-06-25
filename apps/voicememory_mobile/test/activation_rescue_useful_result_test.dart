import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/activation/activation_events_store.dart';
import 'package:voicememory_mobile/features/activation/activation_tracker.dart';
import 'package:voicememory_mobile/features/tomorrow_return/tomorrow_check_in_model.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/widgets/record/check_in_completed_card.dart';
import 'package:voicememory_mobile/widgets/record/result_next_check_card.dart';
import 'package:voicememory_mobile/widgets/trial/check_in_result_rating_prompt.dart';

Future<void> _reset(String stamp) async {
  await AppServices.resetForTest(
    journalPath: '/tmp/vm_rescue_useful_journal_$stamp.json',
    prefsPath: '/tmp/vm_rescue_useful_prefs_$stamp.json',
    skipRevenueCat: true,
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
  selectedOptionId: 'showed_up_again',
  completedAt: DateTime(2026, 5, 26),
);

void main() {
  testWidgets('rating appears after useful takeaway and next-check CTA', (
    tester,
  ) async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await tester.runAsync(() => _reset(stamp));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CheckInCompletedCard(
              checkIn: _completed(),
              nextCheckSlot: ResultNextCheckCard(
                checkIn: _completed(),
                showFeedback: false,
                onCreateCheckIn: (_) async {},
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('What changed'), findsOneWidget);
    expect(find.text('Why this is useful'), findsOneWidget);
    expect(find.text(ConsumerUiCopy.resultNextCheckTitle), findsOneWidget);
    expect(
      find.text(ConsumerUiCopy.resultNextCheckUseTomorrowCta),
      findsOneWidget,
    );
    expect(find.text(ConsumerUiCopy.makeResultMoreUsefulCta), findsOneWidget);
    expect(find.text(ConsumerUiCopy.checkInResultUsefulPrompt), findsOneWidget);
  });

  testWidgets('weak input shows Early read nudge', (tester) async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await tester.runAsync(() => _reset(stamp));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: CheckInCompletedCard(checkIn: _completed(), weakInput: true),
          ),
        ),
      ),
    );

    expect(
      find.text(ConsumerUiCopy.inputQualityEarlyReadLabel),
      findsOneWidget,
    );
    expect(
      find.textContaining('Add one clearer moment to make this more useful.'),
      findsOneWidget,
    );
  });

  test('useful result activation events increment', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    final store = ActivationEventsStore(AppServices.instance.prefs);

    await ActivationTracker.trackActivationUsefulTakeawayShown();
    await ActivationTracker.trackActivationMakeUsefulTapped();
    await ActivationTracker.trackActivationMakeUsefulReasonSelected();
    await ActivationTracker.trackActivationResultRatedUseful();
    await ActivationTracker.trackActivationResultRatedSortOf();
    await ActivationTracker.trackActivationResultRatedNotUseful();
    final events = await store.read();
    expect(events.activationUsefulTakeawayShown, 1);
    expect(events.activationMakeUsefulTapped, 1);
    expect(events.activationMakeUsefulReasonSelected, 1);
    expect(events.activationResultRatedUseful, 1);
    expect(events.activationResultRatedSortOf, 1);
    expect(events.activationResultRatedNotUseful, 1);
  });
}
