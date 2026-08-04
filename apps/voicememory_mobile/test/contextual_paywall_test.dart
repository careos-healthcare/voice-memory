import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/features/monetization/domain/access_policy_engine.dart';
import 'package:voicememory_mobile/features/monetization/domain/contextual_paywall_policy.dart';
import 'package:voicememory_mobile/screens/paywall_screen.dart';
import 'package:voicememory_mobile/subscriptions/domain/subscription_models.dart';

import 'subscriptions/fake_subscription_repository.dart';
import 'support/widget_test_pump.dart';

const _freeProofDelivered = ProductValueState(
  generatedCapabilities: {CapabilityId.firstEvidenceObservation},
);

const _proEntitlement = EntitlementSnapshot(
  plan: PlanKind.pro,
  status: EntitlementStatus.active,
);

const _expiredEntitlement = EntitlementSnapshot(
  plan: PlanKind.free,
  status: EntitlementStatus.expired,
);

const _offers = [
  SubscriptionOffer(
    id: 'monthly-offer',
    productIdentifier: 'com.voicememory.app.pro.monthly',
    price: r'$4.99 monthly',
    period: SubscriptionPeriod.monthly,
  ),
  SubscriptionOffer(
    id: 'yearly-offer',
    productIdentifier: 'com.voicememory.app.pro.annual',
    price: r'$39.99 yearly',
    period: SubscriptionPeriod.annual,
  ),
  SubscriptionOffer(
    id: 'legacy-lifetime',
    productIdentifier: 'legacy.lifetime',
    price: r'$99.99',
    period: SubscriptionPeriod.lifetime,
  ),
];

/// A raw journal quote. It must never reach the paywall.
const _rawQuote =
    'I stayed at my desk for another hour after the task was already done.';

Future<void> _pumpPaywall(
  WidgetTester tester, {
  required bool freeProofDelivered,
  ContextualPaywallContext context = const ContextualPaywallContext(),
  Set<CapabilityId> unavailableCapabilities = const {},
  SubscriptionState? entitlement,
}) async {
  await tester.binding.setSurfaceSize(const Size(390, 3000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => PaywallScreen(
              subscriptionRepository: FakeSubscriptionRepository(
                offers: _offers,
              ),
              entitlementLoader: () async =>
                  entitlement ?? SubscriptionState.free(),
              delayedPaywallProofGateOverride: () => freeProofDelivered,
              contextLoader: () async => context,
              unavailableCapabilities: unavailableCapabilities,
            ),
          ),
        ],
      ),
    ),
  );
  await pumpUntilAbsent(tester, find.byType(CircularProgressIndicator));
}

void main() {
  group('contextual paywall policy', () {
    test('shows a safe count instead of journal content', () {
      final content = ContextualPaywallPolicy.resolve(
        entitlement: const EntitlementSnapshot.free(),
        productValue: _freeProofDelivered,
        context: const ContextualPaywallContext(comparableMomentCount: 3),
      );

      expect(content.visible, isTrue);
      expect(content.contextLine, '3 saved moments are ready for comparison.');
      expect(content.contextLine, isNot(contains(_rawQuote)));
    });

    test('names a thread only when the user approved it', () {
      const approved = ContextualPaywallContext.withApprovedThread(
        label: 'Stopping after the task is complete',
        approvedByUser: true,
        comparableMomentCount: 4,
      );
      const inferred = ContextualPaywallContext.withApprovedThread(
        label: 'Avoiding a difficult conversation at home',
        approvedByUser: false,
        comparableMomentCount: 4,
      );

      expect(
        ContextualPaywallPolicy.resolve(
          entitlement: const EntitlementSnapshot.free(),
          productValue: _freeProofDelivered,
          context: approved,
        ).contextLine,
        "Continue following 'Stopping after the task is complete'.",
      );
      expect(
        ContextualPaywallPolicy.resolve(
          entitlement: const EntitlementSnapshot.free(),
          productValue: _freeProofDelivered,
          context: inferred,
        ).contextLine,
        '4 saved moments are ready for comparison.',
      );
    });

    test('stays hidden until the first free proof was delivered', () {
      final beforeProof = ContextualPaywallPolicy.resolve(
        entitlement: const EntitlementSnapshot.free(),
        context: const ContextualPaywallContext(comparableMomentCount: 3),
      );
      final afterProof = ContextualPaywallPolicy.resolve(
        entitlement: const EntitlementSnapshot.free(),
        productValue: _freeProofDelivered,
        context: const ContextualPaywallContext(comparableMomentCount: 3),
      );

      expect(beforeProof.visible, isFalse);
      expect(beforeProof.contextLine, isNull);
      expect(beforeProof.capabilityLines, isEmpty);
      expect(afterProof.visible, isTrue);
    });

    test('is never offered to a Pro holder', () {
      final content = ContextualPaywallPolicy.resolve(
        entitlement: _proEntitlement,
        productValue: _freeProofDelivered,
        context: const ContextualPaywallContext(comparableMomentCount: 5),
      );

      expect(content.visible, isFalse);
    });

    test('never gates originals, prior evidence or a correction', () {
      const gated = [
        CapabilityId.openOriginalEntry,
        CapabilityId.playOriginalAudio,
        CapabilityId.readSavedTranscript,
        CapabilityId.exportOriginalContent,
        CapabilityId.deleteOriginalContent,
        CapabilityId.readExistingGeneratedOutput,
        CapabilityId.correctInterpretation,
        CapabilityId.hideInterpretation,
        CapabilityId.openEvidenceSource,
      ];

      for (final capability in gated) {
        expect(
          ContextualPaywallPolicy.mayPaywall(capability),
          isFalse,
          reason: '$capability must never be paywalled',
        );
        expect(
          ContextualPaywallPolicy.resolve(
            capability: capability,
            entitlement: _expiredEntitlement,
            productValue: _freeProofDelivered,
          ).visible,
          isFalse,
        );
      }
    });

    test('existing content stays accessible after Pro expires', () {
      const stillAllowed = [
        CapabilityId.openOriginalEntry,
        CapabilityId.playOriginalAudio,
        CapabilityId.readSavedTranscript,
        CapabilityId.exportOriginalContent,
        CapabilityId.readExistingGeneratedOutput,
        CapabilityId.correctInterpretation,
      ];

      for (final capability in stillAllowed) {
        expect(
          AccessPolicyEngine.decide(
            capability: capability,
            entitlement: _expiredEntitlement,
            productValue: _freeProofDelivered,
          ).allowed,
          isTrue,
          reason: '$capability must survive expiry',
        );
      }
    });

    test('hides unavailable capabilities instead of qualifying them', () {
      final lines = ContextualPaywallPolicy.capabilityLines(
        unavailableCapabilities: {
          CapabilityId.deepArchiveSynthesis,
          CapabilityId.fullHistoryQuestion,
        },
      );

      expect(lines, contains('Ongoing comparisons'));
      expect(lines, isNot(contains('Deeper archive analysis')));
      expect(lines, isNot(contains('Full-history questions')));
      for (final line in lines) {
        expect(line.toLowerCase(), isNot(contains('where configured')));
        expect(line.toLowerCase(), isNot(contains('where available')));
        expect(line.toLowerCase(), isNot(contains('unlimited ai')));
      }
    });

    test('uses the exact approved copy', () {
      expect(
        ContextualPaywallCopy.primary,
        'See the exact moments where the pattern repeated—and the evidence '
        'that it is changing.',
      );
      expect(
        ContextualPaywallCopy.supporting,
        'Your recordings stay yours. Pro unlocks ongoing comparisons and '
        'deeper change history.',
      );
    });
  });

  group('contextual paywall screen', () {
    testWidgets('renders the safe count and the approved copy only', (
      tester,
    ) async {
      await _pumpPaywall(
        tester,
        freeProofDelivered: true,
        context: const ContextualPaywallContext(comparableMomentCount: 3),
      );

      expect(
        find.text('3 saved moments are ready for comparison.'),
        findsOneWidget,
      );
      expect(find.text(ContextualPaywallCopy.primary), findsOneWidget);
      expect(find.text(ContextualPaywallCopy.supporting), findsOneWidget);
      expect(find.textContaining(_rawQuote), findsNothing);
      expect(find.textContaining('“'), findsNothing);
      expect(find.textContaining('where configured'), findsNothing);
      expect(find.textContaining('where available'), findsNothing);
      expect(
        find.textContaining('unlimited', findRichText: true),
        findsNothing,
      );
      expect(find.textContaining('Lifetime'), findsNothing);
      expect(find.text(r'$99.99'), findsNothing);
      expect(find.text(r'$4.99 monthly'), findsOneWidget);
      expect(find.text(r'$39.99 yearly'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('shows an approved thread label verbatim', (tester) async {
      await _pumpPaywall(
        tester,
        freeProofDelivered: true,
        context: const ContextualPaywallContext.withApprovedThread(
          label: 'Stopping after the task is complete',
          approvedByUser: true,
          comparableMomentCount: 3,
        ),
      );

      expect(
        find.text("Continue following 'Stopping after the task is complete'."),
        findsOneWidget,
      );
    });

    testWidgets('never names an inferred topic the user did not approve', (
      tester,
    ) async {
      await _pumpPaywall(
        tester,
        freeProofDelivered: true,
        context: const ContextualPaywallContext.withApprovedThread(
          label: 'Avoiding a difficult conversation at home',
          approvedByUser: false,
          comparableMomentCount: 3,
        ),
      );

      expect(
        find.textContaining('Avoiding a difficult conversation'),
        findsNothing,
      );
      expect(
        find.text('3 saved moments are ready for comparison.'),
        findsOneWidget,
      );
    });

    testWidgets('waits for the first free proof before offering Pro', (
      tester,
    ) async {
      await _pumpPaywall(
        tester,
        freeProofDelivered: false,
        context: const ContextualPaywallContext(comparableMomentCount: 3),
      );

      expect(
        find.byKey(const Key('paywall_awaiting_free_proof')),
        findsOneWidget,
      );
      expect(find.text(ContextualPaywallCopy.primary), findsNothing);
      expect(find.text('Continue'), findsNothing);
      expect(find.text(r'$4.99 monthly'), findsNothing);
      // The user keeps every action over their own moments.
      expect(find.byKey(const Key('paywall_originals_note')), findsOneWidget);
      expect(find.byKey(const Key('paywall_restore_button')), findsOneWidget);
    });

    testWidgets('omits the count when no genuine comparison is ready', (
      tester,
    ) async {
      await _pumpPaywall(
        tester,
        freeProofDelivered: true,
        context: const ContextualPaywallContext(comparableMomentCount: 1),
      );

      expect(find.byKey(const Key('paywall_context_line')), findsNothing);
      expect(find.text(ContextualPaywallCopy.primary), findsOneWidget);
    });
  });
}
