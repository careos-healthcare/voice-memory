import 'package:archiveme_mobile/core/di/app_provider_container.dart';
import 'package:archiveme_mobile/features/auth/application/auth_session_notifier.dart';
import 'package:archiveme_mobile/features/auth/application/auth_session_state.dart';
import 'package:archiveme_mobile/l10n/generated/app_localizations.dart';
import 'package:archiveme_mobile/l10n/localized_consumer_ui.dart';
import 'package:archiveme_mobile/screens/account_screen.dart';
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

  testWidgets('mounts under an app-wide ProviderScope and refreshes the '
      'session without a mid-build provider write', (tester) async {
    // The default 800x600 surface leaves the lower half of the account
    // `ListView` unbuilt, so the sign-in labels would never be found.
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final observedPhases = <AuthPhase>[];
    final subscription = appProviderContainer.listen(
      authSessionProvider,
      (previous, next) => observedPhases.add(next.phase),
    );
    addTearDown(subscription.close);

    await tester.pumpWidget(
      withAppProviderScope(
        MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const AccountScreen(),
        ),
      ),
    );
    // The refresh awaits the session API and then reads the last-sync
    // timestamp off disk. Real I/O does not advance under the fake async zone
    // that drives `pump`, so hand time back to the real event loop in between.
    final loadingLabel = find.text('Loading…');
    for (var i = 0; i < 50 && loadingLabel.evaluate().isNotEmpty; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }

    expect(tester.takeException(), isNull);

    // The refresh must still run — deferring it into a no-op would trade the
    // build-phase error for a screen that never leaves its loading label.
    expect(
      observedPhases,
      contains(AuthPhase.loading),
      reason: 'AccountScreen must still refresh the auth session on mount',
    );
    expect(
      observedPhases.last,
      anyOf(AuthPhase.signedIn, AuthPhase.signedOut),
      reason: 'the session refresh must resolve, not stall in loading',
    );
    expect(loadingLabel, findsNothing);
    expect(
      find.text(englishLocalizations.accountNotSignedIn),
      findsOneWidget,
    );
  });
}
