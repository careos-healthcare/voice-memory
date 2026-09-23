import 'package:archiveme_mobile/features/monetization/paywall_milestone.dart';
import 'package:archiveme_mobile/features/monetization/paywall_milestone_coordinator.dart';
import 'package:archiveme_mobile/features/monetization/revenuecat_service.dart';
import 'package:archiveme_mobile/features/monetization/ui/ai_feature_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final coordinator = PaywallMilestoneCoordinator.instance;

  setUp(() {
    coordinator.resetForTest();
    PremiumAccess.apply(PremiumEntitlement.free);
  });

  tearDown(() {
    coordinator.resetForTest();
    PremiumAccess.apply(PremiumEntitlement.free);
  });

  test('five completed archives open one paywall win', () {
    coordinator.recordNewArchive(
      activeCountAfter: 4,
      savedAt: DateTime.utc(2026, 9, 20),
      activeDayKeys: const {'2026-09-20'},
      isFirstEntryOnSavedDay: true,
    );
    expect(coordinator.pending, isNull);

    coordinator.recordNewArchive(
      activeCountAfter: 5,
      savedAt: DateTime.utc(2026, 9, 21),
      activeDayKeys: const {'2026-09-20', '2026-09-21'},
      isFirstEntryOnSavedDay: true,
    );

    expect(coordinator.pending, PaywallMicroWin.fiveCompletedArchives);
    expect(
      coordinator.claimPending(),
      PaywallMicroWin.fiveCompletedArchives,
    );
    expect(coordinator.pending, isNull);
  });

  test('a third consecutive day opens the streak win', () {
    coordinator.recordNewArchive(
      activeCountAfter: 2,
      savedAt: DateTime.utc(2026, 9, 21),
      activeDayKeys: const {'2026-09-20', '2026-09-21'},
      isFirstEntryOnSavedDay: true,
    );
    expect(coordinator.pending, isNull);

    coordinator.recordNewArchive(
      activeCountAfter: 3,
      savedAt: DateTime.utc(2026, 9, 22),
      activeDayKeys: const {'2026-09-20', '2026-09-21', '2026-09-22'},
      isFirstEntryOnSavedDay: true,
    );

    expect(coordinator.pending, PaywallMicroWin.threeDayStreak);
  });

  test('an already long archive does not reopen the sheet', () {
    coordinator.recordNewArchive(
      activeCountAfter: 11,
      savedAt: DateTime.utc(2026, 9, 22),
      activeDayKeys: const {'2026-09-22'},
      isFirstEntryOnSavedDay: true,
    );

    expect(coordinator.pending, isNull);
  });

  testWidgets('a locked tool waits for the milestone before the sheet', (
    tester,
  ) async {
    var drafted = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          monetizationRevenueCatServiceProvider.overrideWithValue(
            MonetizationRevenueCatService(),
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: AIFeatureGate(
              transcript: 'The rent is due tomorrow.',
              onEmailDraft: () => drafted = true,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('ai_gate_email')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(drafted, isFalse);
    expect(find.text('Start Premium'), findsNothing);

    coordinator.recordNewArchive(
      activeCountAfter: 5,
      savedAt: DateTime.utc(2026, 9, 23),
      activeDayKeys: const {'2026-09-23'},
      isFirstEntryOnSavedDay: true,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 450));

    expect(find.text('Start Premium'), findsOneWidget);
    expect(find.byKey(const Key('upgrade_tier_local')), findsOneWidget);
    expect(find.byKey(const Key('upgrade_tier_p2p')), findsOneWidget);
    expect(find.byKey(const Key('upgrade_tier_gpt5')), findsOneWidget);
    expect(find.text('Included'), findsOneWidget);
    expect(find.text('P2P mesh'), findsOneWidget);
    expect(find.text('GPT-5'), findsOneWidget);
  });
}
