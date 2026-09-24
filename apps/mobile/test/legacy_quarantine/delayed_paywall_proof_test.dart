import 'package:archiveme_mobile/billing/paywall_access.dart';
import 'package:archiveme_mobile/features/pro_bridge_visibility/delayed_paywall_proof_store.dart';
import 'package:archiveme_mobile/features/pro_bridge_visibility/pro_bridge_visibility_engine.dart';
import 'package:archiveme_mobile/features/pro_bridge_visibility/pro_bridge_visibility_model.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/screens/paywall_screen.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/test_storage_sandbox.dart';

JournalEntry _entry(
  String id, {
  String? transcript,
}) => JournalEntry(
  id: id,
  createdAt: DateTime(2026, 6, 12, 10),
  transcript:
      transcript ??
      'Saved moment $id with enough words to count as a real recording.',
  durationSeconds: 20,
  reflection: const Reflection(
    mood: 'neutral',
    emotionalIntensity: 2,
    recurringThemes: ['work'],
    exactLanguagePattern: '',
    concreteObservation: 'Work pressure showed up.',
    repeatedSignal: '',
  ),
);

Future<void> _seedMagicMoments() async {
  final entries = [
    _entry(
      'e1',
      transcript:
          'I had no capacity but I said yes again to the extra meeting today.',
    ),
    _entry(
      'e2',
      transcript:
          'Same thing — said yes when I had no capacity for one more thing.',
    ),
    _entry(
      'e3',
      transcript:
          'I said yes again even though I had no capacity for one more ask.',
    ),
  ];
  for (final entry in entries) {
    await AppServices.instance.journalStore.save(entry);
  }
}

ProBridgeVisibilityInput _allowedInput({
  bool hasSeenFirstRepeat = true,
  bool hasOpenedEvidenceTrail = true,
  int entryCount = 3,
}) => ProBridgeVisibilityInput(
  surface: ProBridgeVisibilitySurface.recordReady,
  source: 'test',
  entryCount: entryCount,
  isPro: false,
  postProofProBridgeEnabled: true,
  hasFirstProof: true,
  hasTimelineProofVisible: true,
  hasSeenFirstRepeat: hasSeenFirstRepeat,
  hasOpenedEvidenceTrail: hasOpenedEvidenceTrail,
);

void main() {
  late TestStorageSandbox sandbox;
  setUp(() async {
    sandbox = TestStorageSandbox.create();
    await AppServices.resetForTest(
      journalPath: sandbox.journalPath,
      prefsPath: sandbox.prefsPath,
      skipRevenueCat: true,
    );
    DelayedPaywallProofStore.bypassGateForTest = false;
    await DelayedPaywallProofStore.resetForTest();
  });

  tearDown(() => sandbox.dispose());
  group('DelayedPaywallProofStore', () {
    test('starts false until all proof milestones are recorded', () async {
      expect(DelayedPaywallProofStore.hasSeenFirstRepeat, isFalse);
      expect(DelayedPaywallProofStore.hasOpenedEvidenceTrail, isFalse);
      expect(DelayedPaywallProofStore.passesGate, isFalse);

      await DelayedPaywallProofStore.markFirstRepeatSeen();
      expect(DelayedPaywallProofStore.passesGate, isFalse);

      await DelayedPaywallProofStore.markEvidenceTrailOpened();
      expect(DelayedPaywallProofStore.passesGate, isFalse);

      await _seedMagicMoments();
      expect(DelayedPaywallProofStore.passesGate, isTrue);
    });

    test('persists to prefs', () async {
      await DelayedPaywallProofStore.markFirstRepeatSeen();
      await DelayedPaywallProofStore.markEvidenceTrailOpened();

      final raw = await AppServices.instance.prefs.readMap(
        DelayedPaywallProofStore.prefsKey,
      );
      expect(raw?['hasSeenFirstRepeat'], isTrue);
      expect(raw?['hasOpenedEvidenceTrail'], isTrue);
    });

    test('requires at least three evidence milestones', () async {
      await DelayedPaywallProofStore.markFirstRepeatSeen();
      await DelayedPaywallProofStore.markEvidenceTrailOpened();
      await AppServices.instance.journalStore.save(_entry('only-one'));

      expect(DelayedPaywallProofStore.passesGate, isFalse);
      expect(
        DelayedPaywallProofStore.passesGateFor(evidenceMilestoneCount: 2),
        isFalse,
      );
      expect(
        DelayedPaywallProofStore.passesGateFor(evidenceMilestoneCount: 3),
        isTrue,
      );
    });
  });

  group('ProBridgeVisibilityEngine delayed paywall gate', () {
    test('passesDelayedPaywallProofGate when all milestones met', () async {
      await DelayedPaywallProofStore.markFirstRepeatSeen();
      await DelayedPaywallProofStore.markEvidenceTrailOpened();
      await _seedMagicMoments();

      expect(
        ProBridgeVisibilityEngine.passesDelayedPaywallProofGate(
          _allowedInput(),
        ),
        isTrue,
      );
    });

    test('passesDelayedPaywallProofGate false without first repeat', () async {
      await DelayedPaywallProofStore.markEvidenceTrailOpened();
      await _seedMagicMoments();

      expect(
        ProBridgeVisibilityEngine.passesDelayedPaywallProofGate(
          _allowedInput(hasSeenFirstRepeat: false),
        ),
        isFalse,
      );
    });

    test('passesDelayedPaywallProofGate false without evidence trail', () async {
      await DelayedPaywallProofStore.markFirstRepeatSeen();
      await _seedMagicMoments();

      expect(
        ProBridgeVisibilityEngine.passesDelayedPaywallProofGate(
          _allowedInput(hasOpenedEvidenceTrail: false),
        ),
        isFalse,
      );
    });
  });

  group('PaywallAccess delayed paywall gate', () {
    test('canOpenPaywall is false until all proof milestones', () async {
      expect(await PaywallAccess.canOpenPaywall(), isFalse);

      await DelayedPaywallProofStore.markFirstRepeatSeen();
      expect(await PaywallAccess.canOpenPaywall(), isFalse);

      await DelayedPaywallProofStore.markEvidenceTrailOpened();
      expect(await PaywallAccess.canOpenPaywall(), isFalse);

      await _seedMagicMoments();
      expect(await PaywallAccess.canOpenPaywall(), isTrue);
    });
  });

  group('PaywallScreen delayed paywall gate', () {
    testWidgets('blocks paywall content when proof milestones are missing', (
      tester,
    ) async {
      expect(DelayedPaywallProofStore.bypassGateForTest, isFalse);
      expect(DelayedPaywallProofStore.passesGate, isFalse);
      late final GoRouter router;
      router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: Center(
                child: TextButton(
                  key: const Key('open_paywall'),
                  onPressed: () => context.push('/subscription'),
                  child: const Text('Open paywall'),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/subscription',
            builder: (context, state) =>
                PaywallScreen(billingReadyOverride: () => false),
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.tap(find.byKey(const Key('open_paywall')));
      await tester.pump();
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('You saw the first useful repeat.'), findsNothing);
      expect(find.byKey(const Key('paywall_unavailable_body')), findsNothing);
      expect(DelayedPaywallProofStore.passesGate, isFalse);
    });
  });
}