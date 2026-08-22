import 'package:archiveme_mobile/billing/pro_value_preview_model.dart';
import 'package:archiveme_mobile/features/activation/activation_events_store.dart';
import 'package:archiveme_mobile/features/activation/activation_tracker.dart';
import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/widgets/billing/pro_value_preview_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _preview = ProValuePreview(
  type: ProValuePreviewType.memoryLimit,
  title: 'Your pattern memory is growing',
  body:
      'Free keeps your first 7 key moments. Pro keeps the longer proof trail across weeks and months.',
  previewBullets: [
    'Keep older moments',
    'Search all your moments',
    'See patterns across months',
  ],
  ctaLabel: ConsumerUiCopy.unlockFullMemoryCta,
);

void main() {
  testWidgets('unlock and dismiss callbacks fire', (tester) async {
    var unlocked = false;
    var dismissed = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProValuePreviewCard(
            preview: _preview,
            trackShown: false,
            onUnlock: () => unlocked = true,
            onDismiss: () => dismissed = true,
          ),
        ),
      ),
    );

    expect(find.text(_preview.title), findsOneWidget);
    expect(find.text('Keep older moments'), findsOneWidget);

    await tester.tap(find.text(ConsumerUiCopy.unlockFullMemoryCta));
    await tester.pump();
    expect(unlocked, isTrue);

    await tester.tap(find.text(ConsumerUiCopy.paywallSecondaryCta));
    await tester.pump();
    expect(dismissed, isTrue);
  });

  testWidgets('hide actions when showActions is false', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProValuePreviewCard(
            preview: _preview,
            showActions: false,
            trackShown: false,
            onUnlock: () {},
          ),
        ),
      ),
    );

    expect(find.text(_preview.title), findsOneWidget);
    expect(find.text(ConsumerUiCopy.unlockFullMemoryCta), findsNothing);
    expect(find.text(ConsumerUiCopy.paywallSecondaryCta), findsNothing);
  });

  test('preview tracks shown, unlock, and dismiss', () async {
    final stamp = DateTime.now().microsecondsSinceEpoch.toString();
    await AppServices.resetForTest(
      journalPath: '/tmp/vm_pro_preview_card_journal_$stamp.json',
      prefsPath: '/tmp/vm_pro_preview_card_prefs_$stamp.json',
    );
    final store = ActivationEventsStore(AppServices.instance.prefs);

    ActivationTracker.trackProValuePreviewShown('memoryLimit');
    ActivationTracker.trackProValuePreviewUnlockTapped();
    ActivationTracker.trackProValuePreviewDismissed();
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final counts = await store.read();
    expect(counts.proValuePreviewShown, 1);
    expect(counts.latestProValuePreviewType, 'memoryLimit');
    expect(counts.proValuePreviewUnlockTapped, 1);
    expect(counts.proValuePreviewDismissed, 1);
  });
}