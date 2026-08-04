import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/l10n/generated/app_localizations_en.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/config/app_config.dart';
import 'package:voicememory_mobile/features/privacy_trust/privacy_trust_copy.dart';
import 'package:voicememory_mobile/features/trust/privacy_screen_copy.dart';
import 'package:voicememory_mobile/features/trust/pro_trust_copy.dart';
import 'package:voicememory_mobile/onboarding/onboarding_pages.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/router/app_router.dart';
import 'package:voicememory_mobile/widgets/account/privacy_trust_centre_screen.dart';
import 'package:voicememory_mobile/screens/privacy_screen.dart';
import 'package:voicememory_mobile/screens/settings_screen.dart';
import 'package:voicememory_mobile/services/activation_funnel_analytics.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';

class _Event {
  const _Event(this.name, this.properties);
  final String name;
  final Map<String, Object> properties;
}

final List<_Event> _events = [];

const _bannedWords = [
  'ChatGPT',
  'VoiceMemory',
  'voicememory',
  'voice memory',
  'OpenAI processing',
  'train OpenAI',
  'train our models',
];

final _l10n = AppLocalizationsEn();

void main() {
  setUp(() {
    _events.clear();
    ActivationFunnelAnalytics.resetForTest();
    ActivationFunnelAnalytics.captureForTest(
      (event, properties) => _events.add(_Event(event, properties)),
    );
  });

  tearDown(ActivationFunnelAnalytics.resetForTest);

  Future<void> pumpPrivacy(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: const PrivacyScreen()),
    );
    await tester.pump();
  }

  group('Privacy screen copy', () {
    testWidgets('contains ArchiveMe', (tester) async {
      await pumpPrivacy(tester);
      expect(find.textContaining('ArchiveMe'), findsWidgets);
    });

    testWidgets('does not contain VoiceMemory', (tester) async {
      await pumpPrivacy(tester);
      expect(find.textContaining('VoiceMemory'), findsNothing);
    });

    testWidgets('does not contain ChatGPT', (tester) async {
      await pumpPrivacy(tester);
      expect(find.textContaining('ChatGPT'), findsNothing);
    });

    testWidgets('does not use OpenAI processing as a section title', (
      tester,
    ) async {
      await pumpPrivacy(tester);
      expect(find.text('OpenAI processing'), findsNothing);
      expect(find.text(PrivacyScreenCopy.aiProcessingTitle), findsOneWidget);
    });

    testWidgets('contains AI transcription and analysis', (tester) async {
      await pumpPrivacy(tester);
      expect(find.text(PrivacyScreenCopy.aiProcessingTitle), findsOneWidget);
    });

    testWidgets('explains transcription/analysis without hiding processing', (
      tester,
    ) async {
      await pumpPrivacy(tester);
      expect(find.text(PrivacyScreenCopy.aiProcessingBody), findsOneWidget);
      expect(find.text(PrivacyScreenCopy.aiProcessingBody), findsOneWidget);
    });

    testWidgets('contains memory control labels', (tester) async {
      await pumpPrivacy(tester);
      final body = tester.widget<Text>(
        find.text(PrivacyScreenCopy.controlsBody),
      );
      for (final label in [
        'Hypothetical',
        'Not about me',
        'Sensitive',
        'Do not surface',
        'Preserve original',
        'Keep separate',
        'Treat as new',
      ]) {
        expect(body.data, contains(label));
      }
    });

    testWidgets('app bar does not show VoiceMemory brand', (tester) async {
      await pumpPrivacy(tester);
      expect(find.textContaining('VoiceMemory'), findsNothing);
      expect(find.text(PrivacyScreenCopy.screenTitle), findsOneWidget);
    });

    testWidgets('processing providers section is collapsed by default', (
      tester,
    ) async {
      await pumpPrivacy(tester);
      expect(
        find.byKey(const Key('privacy_processing_providers')),
        findsOneWidget,
      );
      expect(
        find.text(PrivacyScreenCopy.processingProvidersBody),
        findsNothing,
      );
      await tester.ensureVisible(
        find.byKey(const Key('privacy_processing_providers')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('privacy_processing_providers')));
      await tester.pumpAndSettle();
      expect(
        find.text(PrivacyScreenCopy.processingProvidersBody),
        findsOneWidget,
      );
    });
  });

  group('Consumer-facing copy guardrails', () {
    test('settings/about/paywall/onboarding strings avoid VoiceMemory', () {
      final copy = [
        ConsumerUiCopy.privacy,
        ConsumerUiCopy.accountPrivacyNote,
        ConsumerUiCopy.paywallHeadline,
        OnboardingPages.pages.single.title,
        OnboardingPages.pages.single.body,
        AppConfig.appName,
        _l10n.accountAuthPrivacyLine,
        ...ProTrustCopy.all,
        ...PrivacyScreenCopy.all,
      ].join(' ').toLowerCase();

      expect(copy, isNot(contains('voicememory')));
      expect(copy, isNot(contains('voice memory')));
      for (final banned in _bannedWords) {
        expect(copy, isNot(contains(banned.toLowerCase())));
      }
    });

    test('privacy copy banned-word sweep', () {
      for (final line in PrivacyScreenCopy.all) {
        final lower = line.toLowerCase();
        for (final banned in _bannedWords) {
          expect(lower, isNot(contains(banned.toLowerCase())));
        }
      }
    });
  });

  group('Analytics and routes', () {
    test('analytics payloads contain no private content', () {
      ActivationFunnelAnalytics.track(
        ActivationFunnelAnalytics.detailsOpened,
        source: 'privacy',
      );
      for (final event in _events) {
        for (final value in event.properties.values) {
          final lower = value.toString().toLowerCase();
          expect(lower, isNot(contains('hypothetical transcript')));
          expect(lower, isNot(contains('secret')));
        }
      }
    });

    testWidgets('settings opens in-app privacy trust centre route', (
      tester,
    ) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/privacy-trust-centre',
            builder: (context, state) => const PrivacyTrustCentreScreen(),
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
      );
      await tester.pumpAndSettle();
      final privacy = find.text(PrivacyTrustCopy.title);
      await tester.scrollUntilVisible(
        privacy,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(privacy);
      await tester.pumpAndSettle();
      expect(find.byType(PrivacyTrustCentreScreen), findsOneWidget);
    });

    test('app router includes privacy route', () {
      expect(
        appRouter.configuration.routes.any((route) {
          if (route is GoRoute) return route.path == '/privacy';
          return false;
        }),
        isTrue,
      );
    });
  });
}
