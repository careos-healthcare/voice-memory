import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/activation/activation_events_store.dart';
import 'package:voicememory_mobile/features/retention/retention_state_model.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/widgets/retention/retention_state_card.dart';

Future<void> _reset(String stamp) async {
  await AppServices.resetForTest(
    journalPath: '/tmp/vm_retention_card_journal_$stamp.json',
    prefsPath: '/tmp/vm_retention_card_prefs_$stamp.json',
  );
}

void main() {
  test('tracks retention metrics', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await _reset(stamp);
    final store = ActivationEventsStore(AppServices.instance.prefs);

    await store.increment('retentionStateShown');
    await store.increment('retentionDueShown');
    await store.increment('retentionPrimaryCtaTapped');

    final events = await store.read();
    expect(events.retentionStateShown, 1);
    expect(events.retentionDueShown, 1);
    expect(events.retentionPrimaryCtaTapped, 1);
  });

  testWidgets('primary CTA callback fires', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RetentionStateCard(
            state: const RetentionState(
              type: RetentionStateType.noCheckSet,
              title: 'No check set',
              body: 'Record one moment to choose what to check tomorrow.',
              primaryCtaLabel: 'Record one moment',
            ),
            onPrimaryTap: () => tapped = true,
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('No check set'), findsOneWidget);
    await tester.tap(find.text('Record one moment'));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('shows urgency label and check question when present', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RetentionStateCard(
            state: const RetentionState(
              type: RetentionStateType.checkDueToday,
              title: 'Today\u2019s check is waiting',
              body: 'Answer the check you chose yesterday.',
              checkQuestion: 'Did this pattern show up again?',
              primaryCtaLabel: 'Answer check',
              urgencyLabel: 'Due today',
            ),
            onPrimaryTap: () {},
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Due today'), findsOneWidget);
    expect(find.text('Did this pattern show up again?'), findsOneWidget);
  });
}
