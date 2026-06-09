import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/activation/activation_events_store.dart';
import 'package:voicememory_mobile/features/activation/activation_tracker.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/widgets/record/consumer_record_prompts_section.dart';
import 'package:voicememory_mobile/widgets/record/first_loop_start_card.dart';

Future<void> _reset(String stamp) async {
  await AppServices.resetForTest(
    journalPath: '/tmp/vm_rescue_first_record_journal_$stamp.json',
    prefsPath: '/tmp/vm_rescue_first_record_prefs_$stamp.json',
  );
}

void main() {
  testWidgets('first-record card has one dominant Record one moment CTA',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FirstLoopStartCard(onRecord: () {}),
        ),
      ),
    );

    expect(find.text(FirstLoopStartCard.title), findsOneWidget);
    expect(find.text(FirstLoopStartCard.body), findsOneWidget);
    expect(find.text(FirstLoopStartCard.cta), findsOneWidget);
    expect(find.text('Record one moment'), findsOneWidget);
    for (final example in FirstLoopStartCard.examples) {
      expect(find.text(example), findsOneWidget);
    }
  });

  testWidgets('starter prompt selection still works', (tester) async {
    String? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ConsumerRecordPromptsSection(
            onSelectPrompt: (p) => selected = p,
          ),
        ),
      ),
    );

    await tester.tap(find.text(ConsumerUiCopy.recordStarterPrompts.first));
    await tester.pump();
    expect(selected, ConsumerUiCopy.recordStarterPrompts.first);
  });

  test('activation first-record events increment', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    final store = ActivationEventsStore(AppServices.instance.prefs);

    await ActivationTracker.trackActivationFirstRecordCardShown();
    await ActivationTracker.trackActivationFirstRecordCtaTapped();
    await ActivationTracker.trackActivationStarterPromptSelected();
    await ActivationTracker.trackActivationFirstSaveCompleted();
    final events = await store.read();
    expect(events.activationFirstRecordCardShown, 1);
    expect(events.activationFirstRecordCtaTapped, 1);
    expect(events.activationStarterPromptSelected, 1);
    expect(events.activationFirstSaveCompleted, 1);
  });
}
