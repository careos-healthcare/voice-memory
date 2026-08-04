import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/l10n/generated/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:voicememory_mobile/features/beta_activation/beta_activation_summary_copy.dart';
import 'package:voicememory_mobile/features/local_backup/local_backup_copy.dart';
import 'package:voicememory_mobile/features/privacy_trust/privacy_trust_copy.dart';
import 'package:voicememory_mobile/screens/account_screen.dart';
import 'package:voicememory_mobile/screens/settings_screen.dart';
import 'package:voicememory_mobile/security/behavioral_log_export_service.dart';
import 'package:voicememory_mobile/security/local_privacy_data_controls.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/account/privacy_trust_centre_screen.dart';

import 'support/provider_test_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const nativeRecorderChannel = MethodChannel(
    'archive_me/native_audio_recorder',
  );

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(nativeRecorderChannel, (_) async => null);
  });

  setUp(() async {
    ArchiveBetaMissionGate.resetForTest();
    await AppServices.resetForTest(
      journalPath:
          'test/tmp/privacy_trust_centre/${DateTime.now().microsecondsSinceEpoch}_journal.json',
      prefsPath:
          'test/tmp/privacy_trust_centre/${DateTime.now().microsecondsSinceEpoch}_prefs.json',
      skipRevenueCat: true,
    );
  });

  tearDown(() {
    ArchiveBetaMissionGate.resetForTest();
  });

  Future<void> pumpCentre(
    WidgetTester tester, {
    Widget centre = const PrivacyTrustCentreScreen(),
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: AppTheme.light(),
        home: centre,
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
      expect(find.text(PrivacyTrustCopy.whatStoresHeading), findsOneWidget);
      expect(find.text(PrivacyTrustCopy.whatStoresBody), findsOneWidget);
      expect(
        find.text(PrivacyTrustCopy.whatNotIncludedHeading),
        findsOneWidget,
      );
      expect(find.text(PrivacyTrustCopy.whatNotIncludedBody), findsOneWidget);
      expect(
        find.text(PrivacyTrustCopy.whatStaysPrivateHeading),
        findsOneWidget,
      );
      expect(find.text(PrivacyTrustCopy.whatStaysPrivateBody), findsOneWidget);
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
      expect(
        find.byKey(const Key('privacy_trust_control_data_portability')),
        findsOneWidget,
      );
      expect(find.text(LocalBackupCopy.exportControl), findsOneWidget);
      expect(find.text(LocalBackupCopy.restoreControl), findsOneWidget);
      expect(
        find.text(PrivacyTrustCopy.exportBehavioralLogsControl),
        findsOneWidget,
      );
      expect(
        find.text(PrivacyTrustCopy.clearBehavioralLogsControl),
        findsOneWidget,
      );
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

    testWidgets('exports only after tap and passes a safe artifact', (
      tester,
    ) async {
      final now = DateTime.utc(2026, 7, 20);
      final controls = _FakePrivacyControls(
        artifact: BehavioralLogExportArtifact(
          contents: '{"schemaVersion":1,"events":[{"type":"paywall_seen"}]}',
          exportedAt: now,
          eventCount: 1,
        ),
      );
      BehavioralLogExportArtifact? shared;

      await pumpCentre(
        tester,
        centre: PrivacyTrustCentreScreen(
          controls: controls,
          shareBehavioralLogExport: (artifact) async {
            shared = artifact;
          },
        ),
      );
      expect(shared, isNull);

      final export = find.byKey(
        const Key('privacy_trust_control_export_behavioral_logs'),
      );
      await tester.ensureVisible(export);
      await tester.tap(export);
      await tester.pumpAndSettle();

      expect(shared, isNotNull);
      expect(shared!.contents, contains('paywall_seen'));
      expect(controls.exportCalls, 1);
    });

    testWidgets('clear requires confirmation and leaves archive untouched', (
      tester,
    ) async {
      final controls = _FakePrivacyControls();
      await pumpCentre(
        tester,
        centre: PrivacyTrustCentreScreen(controls: controls),
      );

      final clear = find.byKey(
        const Key('privacy_trust_control_clear_behavioral_logs'),
      );
      await tester.ensureVisible(clear);
      await tester.tap(clear);
      await tester.pump();
      expect(
        find.text(PrivacyTrustCopy.clearBehavioralLogsBody),
        findsOneWidget,
      );
      expect(controls.clearCalls, 0);

      await tester.tap(find.byKey(const Key('clear_behavioral_logs_confirm')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(controls.clearCalls, 1);
      expect(controls.clearArchiveCalls, 0);
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
        providerTestHarness(
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.light(),
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
      await pumpWithRouter(
        tester,
        initialLocation: '/',
        home: const SettingsScreen(),
      );
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        find.byKey(const Key('settings_privacy_trust_centre_tile')),
        findsOneWidget,
      );
      expect(find.text(PrivacyTrustCopy.title), findsOneWidget);
      await tester.tap(
        find.byKey(const Key('settings_privacy_trust_centre_tile')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('privacy_trust_centre_screen')),
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
        expect(lower, isNot(contains('encrypted at rest')));
      }
    });
  });
}

class _FakePrivacyControls extends LocalPrivacyDataControls {
  _FakePrivacyControls({BehavioralLogExportArtifact? artifact})
    : artifact =
          artifact ??
          BehavioralLogExportArtifact(
            contents: '{"schemaVersion":1,"categories":[]}',
            exportedAt: DateTime.utc(2026, 7, 20),
            eventCount: 0,
          );

  final BehavioralLogExportArtifact artifact;
  int exportCalls = 0;
  int clearCalls = 0;
  int clearArchiveCalls = 0;

  @override
  Future<BehavioralLogExportArtifact> exportBehavioralLogs() async {
    exportCalls++;
    return artifact;
  }

  @override
  Future<void> clearBehavioralLogs() async {
    clearCalls++;
  }

  @override
  Future<void> clearLocalArchive() async {
    clearArchiveCalls++;
  }
}
