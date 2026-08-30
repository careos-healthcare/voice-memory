import 'dart:io';

import 'package:archiveme_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:archiveme_mobile/features/beta_activation/beta_activation_summary_copy.dart';
import 'package:archiveme_mobile/features/local_backup/local_backup_copy.dart';
import 'package:archiveme_mobile/features/privacy_trust/privacy_trust_copy.dart';
import 'package:archiveme_mobile/features/trust/privacy_screen_copy.dart';
import 'package:archiveme_mobile/l10n/generated/app_localizations.dart';
import 'package:archiveme_mobile/screens/account_screen.dart';
import 'package:archiveme_mobile/screens/settings_screen.dart';
import 'package:archiveme_mobile/security/account_privacy_controls_copy.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/widgets/account/privacy_trust_centre_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

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
    ArchiveBetaMissionGate.resetForTest();
    await AppServices.resetForTest(
      journalPath: sandbox.journalPath,
      prefsPath: sandbox.prefsPath,
      skipRevenueCat: true,
    );
  });

  tearDown(() => sandbox.dispose());
  tearDown(ArchiveBetaMissionGate.resetForTest);

  /// `PushedScreenShell` puts `SyncStatusAppBarAction` in the AppBar, which
  /// reads a Riverpod provider, and the body is a lazy list that never builds
  /// its lower children on the default 800x600 surface.
  Future<void> pumpCentre(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 4000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      withAppProviderScope(
        MaterialApp(
          theme: AppTheme.light(),
          home: const PrivacyTrustCentreScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  group('PrivacyTrustCentreScreen', () {
    testWidgets('shows all trust sections and controls', (tester) async {
      await pumpCentre(tester);

      expect(
        find.byKey(const Key('privacy_trust_centre_screen')),
        findsOneWidget,
      );
      expect(find.text(PrivacyTrustCopy.title), findsOneWidget);
      expect(
        find.text(PrivacyTrustCopy.whatNotIncludedHeading),
        findsOneWidget,
      );
      expect(find.text(PrivacyTrustCopy.whatNotIncludedBody), findsOneWidget);
      expect(
        find.text(PrivacyTrustCopy.betaMeasurementHeading),
        findsOneWidget,
      );
      expect(find.text(PrivacyTrustCopy.betaMeasurementBody), findsOneWidget);
      expect(find.text(PrivacyTrustCopy.yourControlsHeading), findsOneWidget);
      expect(
        find.text(PrivacyTrustCopy.correctTranscriptControl),
        findsOneWidget,
      );
      expect(find.text(PrivacyTrustCopy.deleteArchiveControl), findsOneWidget);
      expect(
        find.text(PrivacyTrustCopy.copyPrivateReportControl),
        findsOneWidget,
      );
      expect(find.text(LocalBackupCopy.exportControl), findsOneWidget);
      expect(find.text(LocalBackupCopy.restoreControl), findsOneWidget);
      expect(
        find.text(PrivacyTrustCopy.sendBetaFeedbackControl),
        findsOneWidget,
      );
      expect(
        find.text(PrivacyTrustCopy.betaMeasurementHeading),
        findsOneWidget,
      );
      expect(find.text(PrivacyTrustCopy.betaMeasurementBody), findsOneWidget);
    });

    testWidgets('beta progress summary link shows when beta flag enabled', (
      tester,
    ) async {
      ArchiveBetaMissionGate.enabledOverride = true;
      await pumpCentre(tester);

      expect(
        find.byKey(const Key('privacy_trust_control_beta_summary')),
        findsOneWidget,
      );
      expect(find.text(BetaActivationSummaryCopy.openLink), findsOneWidget);
    });

    testWidgets('beta progress summary link hidden when beta flag disabled', (
      tester,
    ) async {
      ArchiveBetaMissionGate.enabledOverride = false;
      await pumpCentre(tester);

      expect(
        find.byKey(const Key('privacy_trust_control_beta_summary')),
        findsNothing,
      );
    });

    testWidgets('renders the privacy disclosure migrated from /privacy', (
      tester,
    ) async {
      await pumpCentre(tester);

      expect(find.byKey(const Key('privacy_where_words_go')), findsOneWidget);
      expect(find.text(PrivacyScreenCopy.whereWordsGoTitle), findsOneWidget);
      expect(find.byKey(const Key('privacy_intro')), findsOneWidget);
      for (final section in PrivacyScreenCopy.sections) {
        expect(
          find.text(section.title),
          findsOneWidget,
          reason: 'missing section: ${section.title}',
        );
        expect(
          find.text(section.body),
          findsOneWidget,
          reason: 'missing body for: ${section.title}',
        );
      }
      expect(
        find.byKey(const Key('privacy_remote_processing_switch')),
        findsOneWidget,
      );
      expect(find.text(PrivacyScreenCopy.fullPolicyLink), findsOneWidget);
    });

    testWidgets('names its processing providers where a reader can reach it', (
      tester,
    ) async {
      // The one disclosure in this app that names OpenAI and Google against
      // the calls that reach them. `/privacy` used to be the only screen that
      // rendered it and `/privacy` is now a redirect, so if this case fails
      // the disclosure exists in the source and on no screen at all.
      await pumpCentre(tester);

      final tile = find.byKey(const Key('privacy_processing_providers'));
      expect(tile, findsOneWidget);
      expect(
        find.text(PrivacyScreenCopy.processingProvidersTitle),
        findsOneWidget,
      );
      expect(
        find.text(PrivacyScreenCopy.processingProvidersBody),
        findsNothing,
      );

      await tester.ensureVisible(tile);
      await tester.tap(tile);
      await tester.pumpAndSettle();

      final body = tester.widget<Text>(
        find.text(PrivacyScreenCopy.processingProvidersBody),
      );
      expect(body.data, contains('OpenAI'));
      expect(body.data, contains('Google'));
    });

    testWidgets('copy avoids unsupported encryption and cloud backup claims', (
      tester,
    ) async {
      await pumpCentre(tester);

      final text = tester
          .widgetList<Text>(find.byType(Text))
          .map((w) => w.data ?? '')
          .join('\n')
          .toLowerCase();

      expect(text, isNot(contains('end-to-end encrypted')));
      expect(text, isNot(contains('cloud backup')));
      expect(text, isNot(contains('icloud sync')));
      expect(text, isNot(contains('automatically backed up')));
    });
  });

  group('Account and Settings entry points', () {
    Future<void> pumpWithRouter(
      WidgetTester tester, {
      required String initialLocation,
      required Widget home,
    }) async {
      final router = GoRouter(
        initialLocation: initialLocation,
        routes: [
          GoRoute(path: '/', builder: (context, state) => home),
          GoRoute(
            path: '/privacy-trust-centre',
            builder: (context, state) => const PrivacyTrustCentreScreen(),
          ),
        ],
      );
      await tester.pumpWidget(
        withAppProviderScope(
          MaterialApp.router(
            theme: AppTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();
    }

    testWidgets('account screen links to privacy trust centre', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await pumpWithRouter(
        tester,
        initialLocation: '/',
        home: const AccountScreen(),
      );
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      final tile = find.byKey(const Key('account_privacy_trust_centre_tile'));
      await tester.ensureVisible(tile);
      expect(tile, findsOneWidget);
      await tester.tap(tile);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('privacy_trust_centre_screen')),
        findsOneWidget,
      );
    });

    testWidgets('settings screen links to privacy trust centre', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 2400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final router = GoRouter(
        initialLocation: '/settings',
        routes: [
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/privacy-trust-centre',
            builder: (context, state) => const PrivacyTrustCentreScreen(),
          ),
        ],
      );
      await tester.pumpWidget(
        withAppProviderScope(
          MaterialApp.router(
            theme: AppTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final tile = find.byKey(const Key('settings_privacy_trust_centre_tile'));
      await tester.scrollUntilVisible(tile, 500);
      expect(tile, findsOneWidget);
      expect(find.text(PrivacyTrustCopy.title), findsOneWidget);
      await tester.tap(tile);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('privacy_trust_centre_screen')),
        findsOneWidget,
      );
    });

    testWidgets('settings still links to full privacy policy separately', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(800, 4000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        withAppProviderScope(
          const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(AccountPrivacyControlsCopy.privacyPolicy),
        findsOneWidget,
      );
    });
  });

  group('Protected areas', () {
    test('feature files avoid billing signing and backend surfaces', () {
      const banned = [
        'RevenueCat',
        'Purchases.',
        'CFBundleVersion',
        'signing',
        'product_id',
        'api.archive',
      ];
      final files = [
        'lib/features/privacy_trust/privacy_trust_copy.dart',
        'lib/widgets/account/privacy_trust_centre_screen.dart',
        'lib/features/local_backup/local_backup_copy.dart',
        'lib/features/local_backup/local_backup_builder.dart',
      ];
      for (final path in files) {
        final text = File(path).readAsStringSync();
        for (final token in banned) {
          expect(
            text.contains(token),
            isFalse,
            reason: '$path must not reference $token',
          );
        }
      }
    });

    test('copy strings avoid unsupported security claims', () {
      for (final line in PrivacyTrustCopy.allVisibleStrings()) {
        final lower = line.toLowerCase();
        expect(lower, isNot(contains('end-to-end')));
        expect(lower, isNot(contains('cloud backup')));
        expect(lower, isNot(contains('automatically backed up')));
      }
      expect(
        PrivacyTrustCopy.whatNotIncludedBody.toLowerCase(),
        contains('private reports'),
      );
    });
  });
}
