import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/config/app_config.dart';
import 'package:voicememory_mobile/features/support/support_feedback_copy.dart';
import 'package:voicememory_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:voicememory_mobile/router/app_router.dart';
import 'package:voicememory_mobile/screens/help_reviewer_guide_screen.dart';
import 'package:voicememory_mobile/screens/settings_screen.dart';
import 'package:voicememory_mobile/screens/support_feedback_screen.dart';
import 'package:voicememory_mobile/security/sensitive_screen_guard.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';

const _bannedWords = [
  'symptom',
  'mental health',
  'streak',
  'guilt',
  'you always',
  'pattern found',
  'certain',
  'must come back',
  'share to unlock',
];

void _expectNoBannedCopy(Iterable<String> visible) {
  for (final text in visible) {
    final lower = text.toLowerCase();
    for (final word in _bannedWords) {
      expect(
        lower,
        isNot(contains(word)),
        reason: 'must not contain "$word" in "$text"',
      );
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Support feedback copy', () {
    test('uses ArchiveMe branding and support URL', () {
      const visible = [
        SupportFeedbackCopy.screenTitle,
        SupportFeedbackCopy.settingsTitle,
        SupportFeedbackCopy.settingsSubtitle,
        SupportFeedbackCopy.sectionNeedHelpBody,
        SupportFeedbackCopy.sectionReportBody,
        SupportFeedbackCopy.sectionPrivacyBulletOne,
        SupportFeedbackCopy.sectionPrivacyBulletTwo,
        SupportFeedbackCopy.sectionTestingBulletTwo,
        SupportFeedbackCopy.checklistTitle,
      ];
      _expectNoBannedCopy(visible);
      for (final text in visible) {
        expect(text.toLowerCase(), isNot(contains('voicememory')));
        expect(text.toLowerCase(), isNot(contains('voice memory')));
      }
      expect(SupportFeedbackCopy.sectionNeedHelpBody, contains('ArchiveMe'));
      expect(SupportFeedbackCopy.supportUrl, AppConfig.supportUrl);
      expect(SupportFeedbackCopy.supportUrl, contains('archiveme-support'));
      expect(
        SupportFeedbackCopy.sectionTestingBulletOne,
        contains(VisibleArchiveProofCopy.typeInsteadCta),
      );
    });

    test('checklist includes privacy reminder and support URL', () {
      final checklist = SupportFeedbackCopy.buildChecklist();
      expect(checklist, contains(SupportFeedbackCopy.checklistTitle));
      expect(checklist, contains(SupportFeedbackCopy.sectionReportBody));
      expect(checklist, contains(SupportFeedbackCopy.sectionPrivacyBulletOne));
      expect(checklist, contains(SupportFeedbackCopy.supportUrl));
      expect(checklist, isNot(contains('sample_archive_')));
    });
  });

  group('Support feedback routing', () {
    test('route is registered and sensitive', () {
      final src = File('lib/router/app_router.dart').readAsStringSync();
      expect(src, contains("path: '/support-feedback'"));
      expect(SensitiveRoutes.isSensitiveRoute('/support-feedback'), isTrue);
      final routes = appRouter.configuration.routes;
      final hasRoute = routes.any(
        (route) => route is GoRoute && route.path == '/support-feedback',
      );
      expect(hasRoute, isTrue);
    });
  });

  group('Support feedback UI', () {
    testWidgets('Settings shows Support & feedback row', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const SettingsScreen(),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('settings_support_feedback_tile')),
        findsOneWidget,
      );
      expect(find.text(SupportFeedbackCopy.settingsTitle), findsOneWidget);
      expect(find.text(SupportFeedbackCopy.settingsSubtitle), findsOneWidget);
    });

    testWidgets('support route opens with required sections', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const SupportFeedbackScreen(),
        ),
      );
      await tester.pump();

      expect(find.byKey(const Key('support_feedback_screen')), findsOneWidget);
      expect(find.byKey(const Key('support_feedback_need_help')), findsOneWidget);
      expect(find.byKey(const Key('support_feedback_privacy')), findsOneWidget);
      expect(find.text(SupportFeedbackCopy.sectionPrivacyBulletOne), findsOneWidget);
      expect(find.byKey(const Key('support_feedback_open_support_page')), findsOneWidget);
      expect(find.byKey(const Key('support_feedback_copy_checklist')), findsOneWidget);
      expect(find.byKey(const Key('support_feedback_open_help_guide')), findsOneWidget);
      expect(find.byKey(const Key('support_feedback_open_sample_archive')), findsOneWidget);
    });

    testWidgets('settings row routes to support screen', (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/support-feedback',
            builder: (context, state) => const SupportFeedbackScreen(),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('settings_support_feedback_tile')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('support_feedback_screen')), findsOneWidget);
    });

    testWidgets('Help guide links to Support & feedback', (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const HelpReviewerGuideScreen(),
          ),
          GoRoute(
            path: '/support-feedback',
            builder: (context, state) => const SupportFeedbackScreen(),
          ),
        ],
      );

      await tester.binding.setSurfaceSize(const Size(390, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final link = find.byKey(const Key('help_reviewer_guide_support_feedback_link'));
      await tester.ensureVisible(link);
      await tester.tap(link);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('support_feedback_screen')), findsOneWidget);
    });

    testWidgets('copy support checklist writes checklist text', (tester) async {
      final calls = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          calls.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );

      await tester.binding.setSurfaceSize(const Size(390, 3000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const SupportFeedbackScreen(),
        ),
      );
      await tester.pump();

      final copyButton = find.byKey(const Key('support_feedback_copy_checklist'));
      await tester.ensureVisible(copyButton);
      await tester.tap(copyButton);
      await tester.pump();

      final copyCall = calls.firstWhere((c) => c.method == 'Clipboard.setData');
      expect((copyCall.arguments as Map)['text'], SupportFeedbackCopy.buildChecklist());
    });
  });
}
