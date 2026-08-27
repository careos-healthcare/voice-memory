import 'package:archiveme_mobile/providers/subscription_provider.dart';
import 'package:archiveme_mobile/screens/comparison_engine_screen.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/billing/paywall_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_storage_sandbox.dart';

void main() {
  late TestStorageSandbox sandbox;

  setUpAll(() {
    // `AppServices.resetForTest` starts `ConnectivityAwareNetworkSource`,
    // which throws `MissingPluginException` without this stub.
    const channel = MethodChannel('dev.fluttercommunity.plus/connectivity');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'check') return ['wifi'];
          return null;
        });
  });

  setUp(() async {
    sandbox = TestStorageSandbox.create();
    await AppServices.resetForTest(
      journalPath: sandbox.journalPath,
      prefsPath: sandbox.prefsPath,
      skipRevenueCat: true,
    );
  });

  tearDown(() => sandbox.dispose());

  testWidgets('mounts under a ProviderScope and bootstraps billing '
      'without a mid-build provider write', (tester) async {
    // Give the comparison body plenty of room on the default test surface.
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // The real `SubscriptionNotifier`, not a stand-in. Its `build()` used to
    // kick off `_initRevenueCat` inline, which reads `state` before the
    // provider has finished building, so mounting it here always threw. The
    // loading phases are read off the provider rather than recorded by a
    // subclass, which keeps the notifier under test completely unmodified.
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final phases = <bool>[];
    container.listen<SubscriptionState>(
      subscriptionProvider,
      (previous, next) {
        if (phases.isEmpty || phases.last != next.isLoading) {
          phases.add(next.isLoading);
        }
      },
      fireImmediately: true,
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const ComparisonEngineScreen(),
        ),
      ),
    );

    // The bootstrap awaits billing and then reads the journal off disk. Real
    // I/O does not advance under the fake async zone that drives `pump`, so
    // hand time back to the real event loop in between.
    final body = find.text(
      'Evidence-linked then vs now across your saved moments.',
    );
    for (var i = 0; i < 50 && body.evaluate().isEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }

    expect(tester.takeException(), isNull);

    // The bootstrap must still run — deferring it into a no-op would trade the
    // build-phase error for a screen that never leaves its loading spinner.
    expect(
      phases.take(2).toList(),
      [true, false],
      reason: 'ComparisonEngineScreen must enter the billing bootstrap on '
          'mount and see it resolve, not stall in loading',
    );
    // Comparison is no longer Pro-gated: the screen renders its body directly
    // (Pro affects only history depth, inline), matching the routed
    // comparison_explorer_screen. There is no hard PaywallGate.
    expect(find.byType(PaywallGate), findsNothing);
    expect(
      body,
      findsOneWidget,
      reason: '_bootstrap clears its loading flag after ensureInitialized() '
          'and the journal load both complete, then renders the comparison body',
    );
  });
}
