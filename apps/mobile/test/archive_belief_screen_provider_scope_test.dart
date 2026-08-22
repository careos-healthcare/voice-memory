import 'package:archiveme_mobile/core/di/app_provider_container.dart';
import 'package:archiveme_mobile/features/archive/v1/archive_belief_load_state.dart';
import 'package:archiveme_mobile/features/archive/v1/archive_feed_pagination_provider.dart';
import 'package:archiveme_mobile/screens/archive_belief_screen.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/app_provider_scope.dart';
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

  testWidgets('mounts under an app-wide ProviderScope and loads the feed '
      'without a mid-build provider write', (tester) async {
    final observedPhases = <ArchiveBeliefLoadState>[];
    final subscription = appProviderContainer.listen(
      archiveFeedPaginationProvider,
      (previous, next) => observedPhases.add(next.loadState),
    );
    addTearDown(subscription.close);

    await tester.pumpWidget(
      withAppProviderScope(
        MaterialApp(
          theme: AppTheme.light(),
          home: ArchiveBeliefScreen(key: UniqueKey()),
        ),
      ),
    );

    // The feed refresh mirrors the journal into SQLite and then paginates off
    // disk. Real I/O does not advance under the fake async zone that drives
    // `pump`, so hand time back to the real event loop in between.
    final loadingIndicator = find.byKey(const Key('archive_loading_indicator'));
    for (var i = 0; i < 50 && loadingIndicator.evaluate().isNotEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }

    expect(tester.takeException(), isNull);

    // The refresh must still run — deferring it into a no-op would trade the
    // build-phase error for a feed that never leaves its loading state.
    expect(
      observedPhases,
      contains(ArchiveBeliefLoadState.loading),
      reason: 'ArchiveBeliefScreen must still refresh the feed on mount',
    );
    expect(
      observedPhases.last,
      ArchiveBeliefLoadState.loaded,
      reason: 'the feed refresh must resolve, not stall in loading',
    );
    expect(loadingIndicator, findsNothing);
    expect(
      find.byKey(const Key('archive_tab_entry_state_empty')),
      findsOneWidget,
    );
  });
}
