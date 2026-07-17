import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/billing/paywall_access.dart';
import 'package:voicememory_mobile/billing/paywall_route_args.dart';
import 'package:voicememory_mobile/billing/paywall_source.dart';
import 'package:voicememory_mobile/features/pro_bridge_visibility/delayed_paywall_proof_store.dart';
import 'package:voicememory_mobile/features/pro_bridge_visibility/pro_bridge_visibility_engine.dart';
import 'package:voicememory_mobile/features/pro_bridge_visibility/pro_bridge_visibility_model.dart';
import 'package:voicememory_mobile/screens/paywall_screen.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';

class _MemoryPrefs extends MobilePrefsStore {
  _MemoryPrefs()
      : super(file: File('test/tmp/delayed_paywall_proof/unused.json'));

  final Map<String, Map<String, dynamic>> maps = {};

  @override
  Future<Map<String, dynamic>?> readMap(String key) async => maps[key];

  @override
  Future<void> writeMap(String key, Map<String, dynamic> value) async {
    maps[key] = value;
  }
}

ProBridgeVisibilityInput _allowedInput({
  bool hasSeenFirstRepeat = true,
  bool hasOpenedEvidenceTrail = true,
}) =>
    ProBridgeVisibilityInput(
      surface: ProBridgeVisibilitySurface.recordReady,
      source: 'test',
      entryCount: 3,
      isPro: false,
      postProofProBridgeEnabled: true,
      hasFirstProof: true,
      hasTimelineProofVisible: true,
      hasSeenFirstRepeat: hasSeenFirstRepeat,
      hasOpenedEvidenceTrail: hasOpenedEvidenceTrail,
    );

void main() {
  setUp(() async {
    await AppServices.resetForTest(
      journalPath: '${DateTime.now().microsecondsSinceEpoch}_journal.json',
      prefsPath: '${DateTime.now().microsecondsSinceEpoch}_prefs.json',
      skipRevenueCat: true,
    );
    DelayedPaywallProofStore.bypassGateForTest = false;
    await DelayedPaywallProofStore.resetForTest();
  });

  group('DelayedPaywallProofStore', () {
    test('starts false until milestones are recorded', () async {
      expect(DelayedPaywallProofStore.hasSeenFirstRepeat, isFalse);
      expect(DelayedPaywallProofStore.hasOpenedEvidenceTrail, isFalse);

      await DelayedPaywallProofStore.markFirstRepeatSeen();
      expect(DelayedPaywallProofStore.hasSeenFirstRepeat, isTrue);
      expect(DelayedPaywallProofStore.hasOpenedEvidenceTrail, isFalse);

      await DelayedPaywallProofStore.markEvidenceTrailOpened();
      expect(DelayedPaywallProofStore.hasOpenedEvidenceTrail, isTrue);
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
  });

  group('ProBridgeVisibilityEngine delayed paywall gate', () {
    test('passesDelayedPaywallProofGate requires both milestones', () {
      expect(
        ProBridgeVisibilityEngine.passesDelayedPaywallProofGate(
          _allowedInput(),
        ),
        isTrue,
      );
      expect(
        ProBridgeVisibilityEngine.passesDelayedPaywallProofGate(
          _allowedInput(hasSeenFirstRepeat: false),
        ),
        isFalse,
      );
      expect(
        ProBridgeVisibilityEngine.passesDelayedPaywallProofGate(
          _allowedInput(hasOpenedEvidenceTrail: false),
        ),
        isFalse,
      );
    });
  });

  group('PaywallAccess delayed paywall gate', () {
    test('canOpenPaywall is false until both milestones', () async {
      expect(await PaywallAccess.canOpenPaywall(), isFalse);

      await DelayedPaywallProofStore.markFirstRepeatSeen();
      expect(await PaywallAccess.canOpenPaywall(), isFalse);

      await DelayedPaywallProofStore.markEvidenceTrailOpened();
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
            builder: (context, state) => PaywallScreen(
              billingReadyOverride: () => false,
            ),
          ),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.tap(find.byKey(const Key('open_paywall')));
      await tester.pump();
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text('Free shows the first useful proof. Pro keeps the longer trail.'),
        findsNothing,
      );
      expect(find.byKey(const Key('paywall_unavailable_body')), findsNothing);
      expect(DelayedPaywallProofStore.passesGate, isFalse);
    });
  });
}
