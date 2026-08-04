import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/billing/archive_entitlement_reader.dart';
import 'package:voicememory_mobile/config/app_config.dart';
import 'package:voicememory_mobile/dev/visual_audit_overrides.dart';
import 'package:voicememory_mobile/features/onboarding/first_user_experience_copy.dart';
import 'package:voicememory_mobile/features/onboarding/first_user_experience_gates.dart';
import 'package:voicememory_mobile/features/voice_capture/microphone_permission_copy.dart';
import 'package:voicememory_mobile/features/trust/privacy_screen_copy.dart';
import 'package:voicememory_mobile/features/trust/terms_screen_copy.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/record/record_screen_framing_copy.dart';
import 'package:voicememory_mobile/router/app_router.dart';
import 'package:voicememory_mobile/screens/record_screen.dart';
import 'package:voicememory_mobile/screens/settings_screen.dart';
import 'package:voicememory_mobile/screens/terms_screen.dart';
import 'package:voicememory_mobile/security/privacy_copy_policy.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'package:voicememory_mobile/widgets/capture_entry_actions.dart';

import 'support/memory_pressure_stores.dart';

/// Consumer-visible copy sources scanned for internal deployment wording.
const _consumerVisibleCopyFiles = [
  'lib/product/consumer_ui_copy.dart',
  'lib/features/onboarding/first_user_experience_copy.dart',
  'lib/features/onboarding/first_60_second_state.dart',
  'lib/features/onboarding/record_return_pro_state.dart',
  'lib/features/record/daily_mirror_copy.dart',
  'lib/record/record_screen_framing_copy.dart',
  'lib/features/trust/privacy_screen_copy.dart',
  'lib/features/trust/terms_screen_copy.dart',
  'lib/screens/terms_screen.dart',
  'lib/screens/privacy_screen.dart',
  'lib/screens/about_screen.dart',
  'lib/screens/settings_screen.dart',
];

const _bannedConsumerPhrases = [
  'launch readiness',
  'vercel.app',
  'VoiceMemory',
  'CareOS',
];

List<String> _stringLiteralViolations(String path, String source) {
  final violations = <String>[];
  final literalPattern = RegExp(r"'([^']*)'");

  for (final line in source.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.startsWith('import ') || trimmed.startsWith('//')) continue;

    for (final match in literalPattern.allMatches(line)) {
      final value = match.group(1) ?? '';
      if (value.isEmpty || value.contains(r'$')) continue;
      final lower = value.toLowerCase();
      for (final banned in _bannedConsumerPhrases) {
        if (lower.contains(banned.toLowerCase())) {
          violations.add('$path: "$value" contains "$banned"');
        }
      }
    }
  }

  return violations;
}

void main() {
  group('FirstUserExperienceGates', () {
    test('empty first-run hides returning session survey', () {
      expect(
        FirstUserExperienceGates.showReturnSessionSurvey(
          loaded: true,
          entryCount: 0,
        ),
        isFalse,
      );
    });

    test(
      'returning session survey requires saved entries or explicit flag',
      () {
        expect(
          FirstUserExperienceGates.showReturnSessionSurvey(
            loaded: true,
            entryCount: 1,
          ),
          isTrue,
        );
        expect(
          FirstUserExperienceGates.showReturnSessionSurvey(
            loaded: true,
            entryCount: 0,
            explicitReturningSession: true,
          ),
          isTrue,
        );
      },
    );
  });

  group('empty first-run record screen', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('vm_first_user_');
      await AppServices.resetForTest(
        journalPath: '${tempDir.path}/journal.json',
        skipRevenueCat: true,
      );
      VisualAuditOverrides.setRecordPresentation(
        const RecordAuditPresentation(ui: RecordUiState.ready),
      );
    });

    tearDown(() {
      VisualAuditOverrides.setRecordPresentation(null);
    });

    Future<void> pumpEmptyRecord(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 2800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: RecordScreen(
              pressureCheckInStore: MemoryPressureCheckInStore(),
              suggestionAttributionStore: MemorySuggestionAttributionStore(),
              entitlementReader: FakeArchiveEntitlementReader(pro: false),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 400));
      });
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        if (find.byType(CaptureEntryActions).evaluate().isNotEmpty) return;
      }
    }

    testWidgets('does not show What brought you back today?', (tester) async {
      await pumpEmptyRecord(tester);
      expect(
        find.text(FirstUserExperienceCopy.returnSessionSurveyTitle),
        findsNothing,
      );
      expect(find.textContaining('What brought you back'), findsNothing);
    });

    testWidgets(
      'shows a clear voice capture path without competing capture CTAs',
      (tester) async {
        await pumpEmptyRecord(tester);
        expect(
          find.text(MicrophonePermissionCopy.requestMicrophoneCta),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('daily_archive_exercise_record_card')),
          findsNothing,
        );
        expect(find.byKey(const Key('daily_mirror_card')), findsNothing);
        expect(find.text(ConsumerUiCopy.recordOneMomentCta), findsNothing);
      },
    );
  });

  group('terms and trust copy', () {
    test('terms copy does not contain launch readiness', () {
      for (final line in TermsScreenCopy.all) {
        expect(line.toLowerCase(), isNot(contains('launch readiness')));
      }
      expect(TermsScreenCopy.lastUpdated, 'Last updated: June 2026');
    });

    test('consumer-visible copy does not contain vercel.app', () {
      final violations = <String>[];
      for (final path in _consumerVisibleCopyFiles) {
        final file = File(path);
        expect(file.existsSync(), isTrue, reason: 'missing $path');
        violations.addAll(
          _stringLiteralViolations(path, file.readAsStringSync()),
        );
      }
      expect(violations, isEmpty, reason: violations.join('\n'));
    });

    test(
      'privacy and legal copy avoids overclaiming encryption or therapy',
      () {
        final sources = [
          ...PrivacyScreenCopy.all,
          RecordScreenFramingCopy.firstRunPrivacyBody,
          FirstUserExperienceCopy.trustLine,
          PrivacyCopyPolicy.personalNotMedicalDisclaimer,
        ];
        for (final line in sources) {
          for (final reason in PrivacyCopyPolicy.violationsInLiteral(line)) {
            fail('"$line": $reason');
          }
          expect(
            line.toLowerCase(),
            isNot(contains('all journal data is encrypted')),
          );
          expect(
            line.toLowerCase(),
            isNot(contains('your journal is encrypted')),
          );
        }
        expect(
          PrivacyScreenCopy.doesNotDoBody.toLowerCase(),
          contains('not therapy'),
        );
      },
    );

    testWidgets('settings opens in-app terms route', (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/terms',
            builder: (context, state) => const TermsScreen(),
          ),
        ],
      );
      await tester.pumpWidget(
        MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text(ConsumerUiCopy.termsOfUse),
        300,
      );
      await tester.tap(find.text(ConsumerUiCopy.termsOfUse));
      await tester.pumpAndSettle();
      expect(find.byType(TermsScreen), findsOneWidget);
      expect(find.text(TermsScreenCopy.lastUpdated), findsOneWidget);
    });

    test('app config legal URLs avoid vercel.app', () {
      expect(AppConfig.privacyUrl, isNot(contains('vercel.app')));
      expect(AppConfig.termsRoute, '/terms');
    });

    test('app router includes terms route', () {
      expect(
        appRouter.configuration.routes.any((route) {
          if (route is GoRoute) return route.path == '/terms';
          return false;
        }),
        isTrue,
      );
    });
  });
}
