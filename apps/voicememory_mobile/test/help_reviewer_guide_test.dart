import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/features/demo/sample_archive_entries.dart';
import 'package:voicememory_mobile/features/help/help_reviewer_guide_copy.dart';
import 'package:voicememory_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:voicememory_mobile/router/app_router.dart';
import 'package:voicememory_mobile/screens/help_reviewer_guide_screen.dart';
import 'package:voicememory_mobile/screens/sample_archive_screen.dart';
import 'package:voicememory_mobile/screens/settings_screen.dart';
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
  group('Help reviewer guide copy', () {
    test('uses ArchiveMe and explains testing paths safely', () {
      final visible = [
        HelpReviewerGuideCopy.screenTitle,
        HelpReviewerGuideCopy.settingsTitle,
        HelpReviewerGuideCopy.settingsSubtitle,
        HelpReviewerGuideCopy.sectionWhatBulletOne,
        HelpReviewerGuideCopy.sectionTypeInsteadBulletOne,
        HelpReviewerGuideCopy.sectionQuickValueBulletOne,
        HelpReviewerGuideCopy.sectionQuickValueBulletFive,
        HelpReviewerGuideCopy.sectionPrivacyBulletTwo,
        HelpReviewerGuideCopy.sectionExpectationsBulletOne,
        HelpReviewerGuideCopy.sectionExpectationsBulletTwo,
        HelpReviewerGuideCopy.sectionExpectationsBulletThree,
      ];
      _expectNoBannedCopy(visible);
      for (final text in visible) {
        expect(text.toLowerCase(), isNot(contains('voicememory')));
        expect(text.toLowerCase(), isNot(contains('voice memory')));
      }
      expect(
        HelpReviewerGuideCopy.sectionTypeInsteadBulletOne,
        contains(VisibleArchiveProofCopy.typeInsteadCta),
      );
    });

    test('does not expose sample transcripts in guide copy', () {
      for (final entry in SampleArchiveEntries.build()) {
        for (final section in HelpReviewerGuideCopy.sections) {
          for (final bullet in section.bullets) {
            expect(bullet, isNot(contains(entry.transcript)));
            expect(bullet, isNot(contains(entry.id)));
          }
        }
      }
    });
  });

  group('Help reviewer guide routing', () {
    test('route is registered and sensitive', () {
      final src = File('lib/router/app_router.dart').readAsStringSync();
      expect(src, contains("path: '/help-reviewer-guide'"));
      expect(
        SensitiveRoutes.isSensitiveRoute('/help-reviewer-guide'),
        isTrue,
      );
      final routes = appRouter.configuration.routes;
      final hasRoute = routes.any(
        (route) => route is GoRoute && route.path == '/help-reviewer-guide',
      );
      expect(hasRoute, isTrue);
    });
  });

  group('Help reviewer guide UI', () {
    testWidgets('Settings shows Help & reviewer guide row', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const SettingsScreen(),
        ),
      );
      await tester.pump();

      expect(
        find.byKey(const Key('settings_help_reviewer_guide_tile')),
        findsOneWidget,
      );
      expect(find.text(HelpReviewerGuideCopy.settingsTitle), findsOneWidget);
      expect(find.text(HelpReviewerGuideCopy.settingsSubtitle), findsOneWidget);
    });

    testWidgets('help route opens with required guidance', (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const HelpReviewerGuideScreen(),
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

      expect(find.byKey(const Key('help_reviewer_guide_screen')), findsOneWidget);
      expect(find.text(HelpReviewerGuideCopy.sectionWhatTitle), findsOneWidget);
      expect(
        find.text(HelpReviewerGuideCopy.sectionTypeInsteadBulletOne),
        findsOneWidget,
      );
      expect(
        find.text(HelpReviewerGuideCopy.sectionPrivacyBulletTwo),
        findsOneWidget,
      );
      expect(
        find.text(HelpReviewerGuideCopy.sectionQuickValueBulletFive),
        findsOneWidget,
      );
      expect(
        find.text(HelpReviewerGuideCopy.sectionExpectationsBulletOne),
        findsOneWidget,
      );
      expect(
        find.text(HelpReviewerGuideCopy.sectionExpectationsBulletTwo),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('help_reviewer_guide_open_sample_archive')),
        findsOneWidget,
      );
    });

    testWidgets('settings row routes to help guide', (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/help-reviewer-guide',
            builder: (context, state) => const HelpReviewerGuideScreen(),
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

      await tester.tap(find.byKey(const Key('settings_help_reviewer_guide_tile')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('help_reviewer_guide_screen')), findsOneWidget);
    });

    testWidgets('sample archive links to help guide', (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const SampleArchiveScreen(),
          ),
          GoRoute(
            path: '/help-reviewer-guide',
            builder: (context, state) => const HelpReviewerGuideScreen(),
          ),
        ],
      );

      await tester.binding.setSurfaceSize(const Size(390, 3600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final link = find.byKey(const Key('sample_archive_help_guide_link'));
      await tester.scrollUntilVisible(
        link,
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await tester.tap(link, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byKey(const Key('help_reviewer_guide_screen')), findsOneWidget);
    });
  });
}
