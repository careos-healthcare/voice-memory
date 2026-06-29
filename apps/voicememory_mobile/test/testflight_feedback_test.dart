import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/support/testflight_feedback_analytics.dart';
import 'package:voicememory_mobile/features/support/testflight_feedback_copy.dart';
import 'package:voicememory_mobile/features/support/testflight_feedback_launcher.dart';
import 'package:voicememory_mobile/screens/settings_screen.dart';
import 'package:voicememory_mobile/services/activation_funnel_analytics.dart';

void main() {
  tearDown(() {
    TestFlightFeedbackLauncher.launchUrlForTest = null;
    ActivationFunnelAnalytics.resetForTest();
  });

  group('TestFlightFeedbackLauncher', () {
    test('mailto uri includes email, subject, and body template', () {
      final uri = TestFlightFeedbackLauncher.mailtoUri();

      expect(uri.scheme, 'mailto');
      expect(uri.path, TestFlightFeedbackCopy.emailTo);
      expect(uri.query, isNotNull);
      expect(
        Uri.decodeQueryComponent(uri.query!),
        contains('subject=ArchiveMe TestFlight feedback'),
      );
      expect(
        Uri.decodeQueryComponent(uri.query!),
        contains('Hi ArchiveMe team'),
      );
      expect(
        Uri.decodeQueryComponent(uri.query!),
        contains('What felt clear'),
      );
      expect(
        Uri.decodeQueryComponent(uri.query!),
        contains('What felt confusing'),
      );
      expect(
        Uri.decodeQueryComponent(uri.query!),
        contains('What I expected to happen'),
      );
      expect(
        Uri.decodeQueryComponent(uri.query!),
        contains('Device'),
      );
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
    Future<void> pumpSettings(WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    testWidgets('shows Testing ArchiveMe and Send feedback row', (tester) async {
      await pumpSettings(tester);

      expect(find.text(TestFlightFeedbackCopy.settingsTitle), findsOneWidget);
      expect(find.text(TestFlightFeedbackCopy.settingsCta), findsOneWidget);
      expect(
        find.byKey(const Key('settings_testflight_feedback_tile')),
        findsOneWidget,
      );
    });

    testWidgets('tapping feedback opens email launcher with correct mailto',
        (tester) async {
      Uri? captured;
      TestFlightFeedbackLauncher.launchUrlForTest = (uri) async {
        captured = uri;
        return true;
      };

      await pumpSettings(tester);
      await tester.tap(find.byKey(const Key('settings_testflight_feedback_tile')));
      await tester.pump();

      expect(captured, isNotNull);
      expect(captured!.scheme, 'mailto');
      expect(captured!.path, TestFlightFeedbackCopy.emailTo);
      expect(
        Uri.decodeQueryComponent(captured!.query ?? ''),
        contains(TestFlightFeedbackCopy.emailSubject),
      );
      expect(
        Uri.decodeQueryComponent(captured!.query ?? ''),
        contains('What felt confusing'),
      );
    });

    testWidgets('failure path shows fallback snackbar', (tester) async {
      TestFlightFeedbackLauncher.launchUrlForTest = (_) async => false;

      await pumpSettings(tester);
      await tester.tap(find.byKey(const Key('settings_testflight_feedback_tile')));
      await tester.pump();

      expect(
        find.text(TestFlightFeedbackCopy.emailFallbackMessage),
        findsOneWidget,
      );
    });

    test('analytics records safe metadata only', () {
      final captured = <({String event, Map<String, Object> properties})>[];
      ActivationFunnelAnalytics.captureForTest(
        (event, properties) => captured.add((event: event, properties: properties)),
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
