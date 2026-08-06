import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:voicememory_mobile/features/beta_activation/beta_activation_summary_copy.dart';
import 'package:voicememory_mobile/features/local_backup/local_backup_copy.dart';
import 'package:voicememory_mobile/features/privacy_trust/privacy_trust_copy.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/screens/account_screen.dart';
import 'package:voicememory_mobile/screens/settings_screen.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/account/privacy_trust_centre_screen.dart';

void main() {
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

  Future<void> pumpCentre(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const PrivacyTrustCentreScreen(),
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
        MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
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

    testWidgets('settings still links to full privacy policy separately', (
      tester,
    ) async {
      await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
      await tester.pump();

      expect(find.text(ConsumerUiCopy.privacy), findsOneWidget);
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
