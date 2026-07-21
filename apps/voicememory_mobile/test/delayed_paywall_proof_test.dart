import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/billing/paywall_access.dart';
import 'package:voicememory_mobile/features/pro_bridge_visibility/delayed_paywall_proof_store.dart';
import 'package:voicememory_mobile/features/pro_bridge_visibility/pro_bridge_visibility_engine.dart';
import 'package:voicememory_mobile/features/pro_bridge_visibility/pro_bridge_visibility_model.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
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

JournalEntry _entry(String id) => JournalEntry(
      id: id,
      createdAt: DateTime(2026, 6, 12, 10),
      transcript: 'Saved moment $id with enough words to count.',
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

Future<void> _seedTwoMoments() async {
  await AppServices.instance.journalStore.save(_entry('e1'));
  await AppServices.instance.journalStore.save(_entry('e2'));
}

ProBridgeVisibilityInput _allowedInput({
  bool hasSeenFirstRepeat = true,
  bool hasOpenedEvidenceTrail = true,
  int entryCount = 2,
}) =>
    ProBridgeVisibilityInput(
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
    test('starts false until all proof milestones are recorded', () async {
      expect(DelayedPaywallProofStore.hasSeenFirstRepeat, isFalse);
      expect(DelayedPaywallProofStore.hasOpenedEvidenceTrail, isFalse);
      expect(DelayedPaywallProofStore.passesGate, isFalse);

      await DelayedPaywallProofStore.markFirstRepeatSeen();
      expect(DelayedPaywallProofStore.passesGate, isFalse);

      await DelayedPaywallProofStore.markEvidenceTrailOpened();
      expect(DelayedPaywallProofStore.passesGate, isFalse);

      await _seedTwoMoments();
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

    test('requires at least two saved moments', () async {
      await DelayedPaywallProofStore.markFirstRepeatSeen();
      await DelayedPaywallProofStore.markEvidenceTrailOpened();
      await AppServices.instance.journalStore.save(_entry('only-one'));

      expect(DelayedPaywallProofStore.passesGate, isFalse);
    });
  });

  group('ProBridgeVisibilityEngine delayed paywall gate', () {
    test('passesDelayedPaywallProofGate requires all three milestones', () {
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
      expect(
        ProBridgeVisibilityEngine.passesDelayedPaywallProofGate(
          _allowedInput(entryCount: 1),
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

      await _seedTwoMoments();
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

      expect(find.text('You saw the first useful repeat.'), findsNothing);
      expect(find.byKey(const Key('paywall_unavailable_body')), findsNothing);
      expect(DelayedPaywallProofStore.passesGate, isFalse);
    });
  });
}
