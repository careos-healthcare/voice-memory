import 'package:archiveme_mobile/models/journal_entry.dart';
import 'package:archiveme_mobile/models/reflection.dart';
import 'package:archiveme_mobile/router/v1_route_registry.dart';
import 'package:archiveme_mobile/screens/account_screen.dart';
import 'package:archiveme_mobile/screens/export_screen.dart';
import 'package:archiveme_mobile/screens/privacy_screen.dart';
import 'package:archiveme_mobile/screens/support_feedback_screen.dart';
import 'package:archiveme_mobile/security/account_privacy_controls_copy.dart';
import 'package:archiveme_mobile/security/privacy_data_controls_copy.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'support/localized_test_app.dart';
import 'support/test_storage_sandbox.dart';

JournalEntry _entry({required String id}) => JournalEntry(
  id: id,
  createdAt: DateTime(2026, 6, 1, 12),
  transcript: 'A long enough transcript to count as a saved reflection.',
  durationSeconds: 30,
  reflection: const Reflection(
    mood: 'neutral',
    emotionalIntensity: 2,
    recurringThemes: ['work'],
    exactLanguagePattern: '',
    concreteObservation: 'You mentioned pressure in this moment.',
    repeatedSignal: '',
  ),
);

void main() {
  late TestStorageSandbox sandbox;

  setUp(() async {
    sandbox = TestStorageSandbox.create();
    await AppServices.resetForTest(
      journalPath: sandbox.journalPath,
      skipRevenueCat: true,
    );
  });

  tearDown(() => sandbox.dispose());

  Future<void> pumpAccount(
    WidgetTester tester, {
    List<RouteBase>? extraRoutes,
  }) async {
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final routes = <RouteBase>[
      GoRoute(path: '/', builder: (context, state) => const AccountScreen()),
      GoRoute(
        path: V1RouteRegistry.exportPath,
        builder: (context, state) => const ExportScreen(),
      ),
      GoRoute(
        path: '/privacy',
        builder: (context, state) => const PrivacyScreen(),
      ),
      GoRoute(
        path: '/support-feedback',
        builder: (context, state) => const SupportFeedbackScreen(),
      ),
      ...?extraRoutes,
    ];

    final router = GoRouter(initialLocation: '/', routes: routes);
    await tester.pumpWidget(
      localizedMaterialAppRouter(routerConfig: router),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> settleUi(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  tearDown(() => sandbox.dispose());
  group('Account standard controls section', () {
    testWidgets('shows the six standard control buttons', (tester) async {
      await pumpAccount(tester);

      expect(
        find.text(AccountPrivacyControlsCopy.sectionTitle),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('account_privacy_controls_section')),
        findsOneWidget,
      );
      expect(find.text(AccountPrivacyControlsCopy.deleteEntry), findsOneWidget);
      expect(
        find.text(AccountPrivacyControlsCopy.correctEntry),
        findsOneWidget,
      );
      expect(find.text(AccountPrivacyControlsCopy.export), findsOneWidget);
      expect(
        find.text(AccountPrivacyControlsCopy.clearArchive),
        findsOneWidget,
      );
      expect(
        find.text(AccountPrivacyControlsCopy.privacyPolicy),
        findsOneWidget,
      );
      expect(find.text(AccountPrivacyControlsCopy.support), findsOneWidget);
    });

    testWidgets('clear archive opens confirmation dialog', (tester) async {
      await tester.runAsync(() async {
        await AppServices.instance.journalStore.save(_entry(id: 'keep-me'));
      });

      await pumpAccount(tester);

      await tester.tap(
        find.byKey(const Key('account_control_clear_archive_button')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.text(PrivacyDataControlsCopy.clearLocalArchiveConfirmTitle),
        findsOneWidget,
      );

      await tester.tap(find.text(PrivacyDataControlsCopy.cancel));
      await settleUi(tester);

      await tester.runAsync(() async {
        final entries = await AppServices.instance.journalStore.loadAll();
        expect(entries, hasLength(1));
      });
    });

    testWidgets('export opens canonical export screen', (tester) async {
      await pumpAccount(tester);

      await tester.tap(find.byKey(const Key('account_control_export_button')));
      await settleUi(tester);

      expect(find.byType(ExportScreen), findsOneWidget);
    });

    testWidgets('privacy policy opens privacy screen', (tester) async {
      await pumpAccount(tester);

      await tester.tap(
        find.byKey(const Key('account_control_privacy_policy_button')),
      );
      await settleUi(tester);

      expect(find.byType(PrivacyScreen), findsOneWidget);
    });

    testWidgets('support opens support screen', (tester) async {
      await pumpAccount(tester);

      await tester.tap(find.byKey(const Key('account_control_support_button')));
      await settleUi(tester);

      expect(find.byType(SupportFeedbackScreen), findsOneWidget);
    });

    testWidgets('delete entry opens saved moments sheet when entries exist', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await AppServices.instance.journalStore.save(_entry(id: 'entry-1'));
      });

      await pumpAccount(tester);

      await tester.tap(
        find.byKey(const Key('account_control_delete_entry_button')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Saved moments'), findsOneWidget);
    });
  });
}