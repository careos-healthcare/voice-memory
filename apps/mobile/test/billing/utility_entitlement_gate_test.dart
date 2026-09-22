import 'dart:io';

import 'package:archiveme_mobile/billing/utility/entitlement_required_exception.dart';
import 'package:archiveme_mobile/billing/utility/freemium_quota.dart';
import 'package:archiveme_mobile/billing/utility/paywall_modal.dart';
import 'package:archiveme_mobile/billing/utility/usage_progress_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('journaling and local search stay outside the utility paywall', () {
    final journal = File(
      'lib/services/capture_pipeline/text_capture_handler.dart',
    ).readAsStringSync();
    final search = File(
      'lib/features/search/vector_search_service.dart',
    ).readAsStringSync();
    expect(journal, isNot(contains('EntitlementRequiredException')));
    expect(journal, isNot(contains('requireExport')));
    expect(search, isNot(contains('PaywallModal')));
    expect(search, isNot(contains('canUseCloudLLM')));
  });

  test('free users can journal and search, and utility limits throw', () async {
    final container = _gatedContainer();
    addTearDown(container.dispose);
    final gate = container.read(utilityEntitlementGateProvider);

    expect(gate.canCreateEntry(), isTrue);
    expect(gate.canSearchLocally(), isTrue);
    expect(gate.canExportArchive(), isFalse);
    expect(
      gate.requireExport,
      throwsA(
        isA<EntitlementRequiredException>().having(
          (error) => error.limit,
          'limit',
          UtilityLimit.exportArchive,
        ),
      ),
    );

    await expandWithCloudLlm(gate: gate, expand: () async => 'answer');
    expect(container.read(freemiumQuotaProvider).cloudTokensRemaining, 19);

    container.read(freemiumQuotaProvider.notifier).snapshot =
        const FreemiumQuota(billingReachable: true, cloudTokensUsed: 20);
    expect(gate.requireCloudLlm, throwsA(isA<EntitlementRequiredException>()));

    expect(gate.canUploadMedia(1024), isTrue);
    gate.requireMediaUpload(1024);
    expect(container.read(freemiumQuotaProvider).mediaBytesUsed, 1024);
    expect(
      () => gate.requireMediaUpload(FreemiumQuota.freeMediaBytes),
      throwsA(
        isA<EntitlementRequiredException>().having(
          (error) => error.limit,
          'limit',
          UtilityLimit.mediaStorage,
        ),
      ),
    );
    expect(container.read(freemiumQuotaProvider).mediaBytesUsed, 1024);
  });

  test('billing that is not on sale does not block export', () {
    final gate = UtilityEntitlementGate(FreemiumQuota.new);
    expect(gate.canExportArchive(), isTrue);
    expect(gate.canUseCloudLLM(), isTrue);
    expect(gate.canUploadMedia(FreemiumQuota.freeMediaBytes + 1), isTrue);
    gate.requireExport();
  });

  testWidgets('progress bar shows remaining tokens and storage', (tester) async {
    final container = _gatedContainer(
      quota: const FreemiumQuota(
        billingReachable: true,
        cloudTokensUsed: 5,
        mediaBytesUsed: 250 * 1024 * 1024,
      ),
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: Scaffold(body: UsageProgressBarSlot())),
      ),
    );
    expect(find.text('15 cloud answers left'), findsOneWidget);
    expect(find.text('250 MB of 500 MB left'), findsOneWidget);
  });

  testWidgets('export and storage caps open the paywall and purchase sheet', (
    tester,
  ) async {
    final presenter = _CountingPresenter();
    final container = _gatedContainer(presenter: presenter);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () {
                  guardUtilityAction(context, (gate) => gate.requireExport());
                },
                child: const Text('Export'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Export'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('utility_paywall_modal')), findsOneWidget);
    expect(find.textContaining('Journaling and on-device search stay free'), findsOneWidget);
    expect(presenter.calls, 1);
  });
}

ProviderContainer _gatedContainer({
  FreemiumQuota quota = const FreemiumQuota(billingReachable: true),
  PurchaseSheetPresenter? presenter,
}) {
  final container = ProviderContainer(
    overrides: [
      if (presenter != null)
        purchaseSheetPresenterProvider.overrideWithValue(presenter),
    ],
  );
  container.read(freemiumQuotaProvider.notifier).snapshot = quota;
  return container;
}

class _CountingPresenter implements PurchaseSheetPresenter {
  int calls = 0;

  @override
  Future<void> present() async {
    calls++;
  }
}
