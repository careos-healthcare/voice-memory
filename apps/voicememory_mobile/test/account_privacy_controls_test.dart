import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/reflection.dart';
import 'package:voicememory_mobile/screens/account_screen.dart';
import 'package:voicememory_mobile/screens/export_screen.dart';
import 'package:voicememory_mobile/security/account_privacy_controls_copy.dart';
import 'package:voicememory_mobile/security/app_lock_service.dart';
import 'package:voicememory_mobile/security/app_lock_store.dart';
import 'package:voicememory_mobile/security/private_data_service.dart';
import 'package:voicememory_mobile/security/security_settings_copy.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';

class _NoBiometrics implements BiometricAuthenticator {
  @override
  Future<bool> available() async => false;

  @override
  Future<bool> authenticate(String reason) async => false;
}

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
  late Directory tempDir;
  late MemoryAppLockStore lockStore;
  late AppLockService appLock;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('vm_account_privacy_');
    await AppServices.resetForTest(
      journalPath: '${tempDir.path}/journal.json',
      skipRevenueCat: true,
    );
    lockStore = MemoryAppLockStore();
    appLock = AppLockService(
      store: AppLockStore(store: lockStore),
      biometrics: _NoBiometrics(),
    );
    AppLockService.instanceForTest = appLock;
  });

  tearDown(() {
    AppLockService.instanceForTest = null;
  });

  Future<void> pumpAccount(
    WidgetTester tester, {
    List<GoRoute>? extraRoutes,
  }) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final routes = <RouteBase>[
      GoRoute(
        path: '/',
        builder: (context, state) => const AccountScreen(),
      ),
      GoRoute(
        path: '/export',
        builder: (context, state) => const ExportScreen(),
      ),
      GoRoute(
        path: '/security',
        builder: (context, state) =>
            const Scaffold(body: Text('SECURITY_SETTINGS_MARKER')),
      ),
      if (extraRoutes != null) ...extraRoutes,
    ];

    final router = GoRouter(initialLocation: '/', routes: routes);
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  Future<void> settleUi(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  group('Account privacy controls section', () {
    testWidgets('shows Privacy and control section title', (tester) async {
      await pumpAccount(tester);

      expect(
        find.text(AccountPrivacyControlsCopy.sectionTitle),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('account_privacy_controls_section')),
        findsOneWidget,
      );
    });

    testWidgets('shows Protect this archive with Off when app lock disabled', (
      tester,
    ) async {
      await pumpAccount(tester);

      expect(find.text(AccountPrivacyControlsCopy.lockOff), findsOneWidget);
      expect(find.text(AccountPrivacyControlsCopy.lockOn), findsNothing);
    });

    testWidgets('shows Protect this archive with On when app lock enabled', (
      tester,
    ) async {
      await appLock.enableWithPin('1234');
      await pumpAccount(tester);

      expect(find.text(AccountPrivacyControlsCopy.lockOn), findsOneWidget);
      expect(find.text(AccountPrivacyControlsCopy.lockOff), findsNothing);
    });

    testWidgets('shows Export my archive row', (tester) async {
      await pumpAccount(tester);

      expect(find.text(AccountPrivacyControlsCopy.exportTitle), findsOneWidget);
      expect(
        find.byKey(const Key('account_privacy_export_row')),
        findsOneWidget,
      );
    });

    testWidgets('shows Delete my archive row', (tester) async {
      await pumpAccount(tester);

      expect(find.text(AccountPrivacyControlsCopy.deleteTitle), findsOneWidget);
      expect(
        find.byKey(const Key('account_privacy_delete_row')),
        findsOneWidget,
      );
    });

    testWidgets('delete opens confirmation and does not wipe on first tap', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await AppServices.instance.journalStore.save(_entry(id: 'keep-me'));
      });

      await pumpAccount(tester);

      await tester.tap(find.byKey(const Key('account_privacy_delete_row')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.text(SecuritySettingsCopy.wipeConfirmTitle),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('wipe_archive_confirm_field')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('wipe_archive_cancel')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.runAsync(() async {
        final entries = await AppServices.instance.journalStore.loadAll();
        expect(entries, hasLength(1));
        expect(entries.first.id, 'keep-me');
      });
    });

    testWidgets('export route is reachable from Account', (tester) async {
      await pumpAccount(tester);

      await tester.tap(find.byKey(const Key('account_privacy_export_row')));
      await settleUi(tester);

      expect(find.text('Export'), findsOneWidget);
      expect(
        find.text('Export and share JSON'),
        findsOneWidget,
      );
    });

    testWidgets('lock row opens security settings', (tester) async {
      await pumpAccount(tester);

      await tester.tap(find.byKey(const Key('account_privacy_lock_row')));
      await settleUi(tester);

      expect(find.text('SECURITY_SETTINGS_MARKER'), findsOneWidget);
    });

    testWidgets('security settings row opens security settings', (tester) async {
      await pumpAccount(tester);

      await tester.tap(find.byKey(const Key('account_privacy_security_row')));
      await settleUi(tester);

      expect(find.text('SECURITY_SETTINGS_MARKER'), findsOneWidget);
    });

    testWidgets('wipe confirm button alone does not delete without phrase', (
      tester,
    ) async {
      await tester.runAsync(() async {
        await AppServices.instance.journalStore.save(_entry(id: 'still-here'));
      });

      await pumpAccount(tester);

      await tester.tap(find.byKey(const Key('account_privacy_delete_row')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.tap(find.byKey(const Key('wipe_archive_confirm')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      await tester.runAsync(() async {
        final entries = await AppServices.instance.journalStore.loadAll();
        expect(entries, hasLength(1));
        expect(
          PrivateDataService.wipeConfirmationPhrase,
          'DELETE MY ARCHIVE',
        );
      });
    });
  });
}
