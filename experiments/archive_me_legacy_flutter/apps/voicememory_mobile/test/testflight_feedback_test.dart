import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/features/beta/archive_beta_mission_gate.dart';
import 'package:voicememory_mobile/features/beta_test_script/beta_test_script_copy.dart';
import 'package:voicememory_mobile/features/beta/tester_mission_copy.dart';
import 'package:voicememory_mobile/features/support/testflight_feedback_analytics.dart';
import 'package:voicememory_mobile/features/support/testflight_feedback_copy.dart';
import 'package:voicememory_mobile/features/support/testflight_feedback_launcher.dart';
import 'package:voicememory_mobile/screens/settings_screen.dart';
import 'package:voicememory_mobile/screens/testing_archiveme_screen.dart';
import 'package:voicememory_mobile/services/activation_funnel_analytics.dart';
import 'package:voicememory_mobile/services/app_services.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('vm_testflight_feedback_');
    await AppServices.resetForTest(
      journalPath: '${tempDir.path}/journal.json',
      skipRevenueCat: true,
    );
  });

  tearDown(() {
    TestFlightFeedbackLauncher.launchUrlForTest = null;
    ActivationFunnelAnalytics.resetForTest();
    ArchiveBetaMissionGate.resetForTest();
  });

  group('TestFlightFeedbackLauncher', () {
    test('mailto uri includes email, subject, and body template', () {
      final uri = TestFlightFeedbackLauncher.mailtoUri();

      expect(uri.scheme, 'mailto');
      expect(uri.path, TestFlightFeedbackCopy.emailTo);
      expect(uri.query, isNotNull);
      expect(
        Uri.decodeQueryComponent(uri.query),
        contains('subject=ArchiveMe TestFlight feedback'),
      );
      expect(
        Uri.decodeQueryComponent(uri.query),
        contains('Hi ArchiveMe team'),
      );
      expect(Uri.decodeQueryComponent(uri.query), contains('What felt clear'));
      expect(
        Uri.decodeQueryComponent(uri.query),
        contains('What felt confusing'),
      );
      expect(
        Uri.decodeQueryComponent(uri.query),
        contains('What I expected to happen'),
      );
      expect(Uri.decodeQueryComponent(uri.query), contains('Device'));
    });

    test('openFeedbackEmail uses injected launcher', () async {
      Uri? captured;
      TestFlightFeedbackLauncher.launchUrlForTest = (uri) async {
        captured = uri;
        return true;
      };

      final opened = await TestFlightFeedbackLauncher.openFeedbackEmail();

      expect(opened, isTrue);
      expect(captured, isNotNull);
      expect(captured!.path, TestFlightFeedbackCopy.emailTo);
    });
  });

  group('SettingsScreen TestFlight feedback', () {
    GoRouter router() => GoRouter(
      routes: [
        GoRoute(path: '/', builder: (context, state) => const SettingsScreen()),
        GoRoute(
          path: '/testing-archiveme',
          builder: (context, state) => const TestingArchiveMeScreen(),
        ),
      ],
    );

    Future<void> pumpSettings(
      WidgetTester tester, {
      required bool betaMissionEnabled,
    }) async {
      ArchiveBetaMissionGate.enabledOverride = betaMissionEnabled;
      await tester.pumpWidget(MaterialApp.router(routerConfig: router()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    Future<void> scrollToTestFlightTile(WidgetTester tester) async {
      await tester.dragUntilVisible(
        find.byKey(const Key('settings_testflight_feedback_tile')),
        find.byType(ListView),
        const Offset(0, -120),
      );
      await tester.pump();
    }

    testWidgets('shows Testing ArchiveMe row when beta mission enabled', (
      tester,
    ) async {
      await pumpSettings(tester, betaMissionEnabled: true);
      await scrollToTestFlightTile(tester);

      expect(find.text(BetaTestScriptCopy.settingsTileTitle), findsOneWidget);
      expect(find.text(BetaTestScriptCopy.settingsTileBody), findsOneWidget);
      expect(
        find.byKey(const Key('settings_testflight_feedback_tile')),
        findsOneWidget,
      );
    });

    testWidgets('hidden when beta mission disabled', (tester) async {
      await pumpSettings(tester, betaMissionEnabled: false);

      expect(find.text(BetaTestScriptCopy.settingsTileTitle), findsNothing);
      expect(
        find.byKey(const Key('settings_testflight_feedback_tile')),
        findsNothing,
      );
    });

    testWidgets('tapping row opens Testing ArchiveMe guide screen', (
      tester,
    ) async {
      await pumpSettings(tester, betaMissionEnabled: true);
      await scrollToTestFlightTile(tester);
      await tester.tap(
        find.byKey(const Key('settings_testflight_feedback_tile')),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('testing_archiveme_screen')), findsOneWidget);
      expect(find.text(TesterMissionCopy.mission), findsOneWidget);
      for (final step in TesterMissionCopy.steps) {
        expect(find.textContaining(step), findsOneWidget);
      }
      expect(find.text(TesterMissionCopy.feedbackQuestion), findsOneWidget);
    });

    testWidgets(
      'send feedback from guide opens email launcher with correct mailto',
      (tester) async {
        Uri? captured;
        TestFlightFeedbackLauncher.launchUrlForTest = (uri) async {
          captured = uri;
          return true;
        };

        await pumpSettings(tester, betaMissionEnabled: true);
        await scrollToTestFlightTile(tester);
        await tester.tap(
          find.byKey(const Key('settings_testflight_feedback_tile')),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byKey(const Key('testing_archiveme_send_feedback')),
          100,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(
          find.byKey(const Key('testing_archiveme_send_feedback')),
        );
        await tester.pump();

        expect(captured, isNotNull);
        expect(captured!.scheme, 'mailto');
        expect(captured!.path, TestFlightFeedbackCopy.emailTo);
        expect(
          Uri.decodeQueryComponent(captured!.query),
          contains(TestFlightFeedbackCopy.emailSubject),
        );
        expect(
          Uri.decodeQueryComponent(captured!.query),
          contains('What felt confusing'),
        );
      },
    );

    testWidgets('failure path shows fallback snackbar', (tester) async {
      TestFlightFeedbackLauncher.launchUrlForTest = (_) async => false;

      await pumpSettings(tester, betaMissionEnabled: true);
      await scrollToTestFlightTile(tester);
      await tester.tap(
        find.byKey(const Key('settings_testflight_feedback_tile')),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('testing_archiveme_send_feedback')),
        100,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(
        find.byKey(const Key('testing_archiveme_send_feedback')),
      );
      await tester.pump();

      expect(
        find.text(TestFlightFeedbackCopy.emailFallbackMessage),
        findsOneWidget,
      );
    });

    test('analytics records safe metadata only', () {
      final captured = <({String event, Map<String, Object> properties})>[];
      ActivationFunnelAnalytics.captureForTest(
        (event, properties) =>
            captured.add((event: event, properties: properties)),
      );

      TestFlightFeedbackAnalytics.tapped(surface: 'settings');

      expect(captured, hasLength(1));
      expect(captured.single.event, TestFlightFeedbackAnalytics.tappedEvent);
      expect(captured.single.properties['source'], 'settings');
      expect(
        captured.single.properties.values
            .map((value) => value.toString())
            .join(' ')
            .toLowerCase(),
        isNot(contains('transcript')),
      );
    });
  });
}
