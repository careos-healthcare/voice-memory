import 'package:archiveme_mobile/features/sync/application/background_sync_state.dart';
import 'package:archiveme_mobile/features/sync/application/sync_status_provider.dart';
import 'package:archiveme_mobile/features/sync/presentation/sync_status_snapshot.dart';
import 'package:archiveme_mobile/features/settings/screens/security_settings_screen.dart';
import 'package:archiveme_mobile/features/settings/screens/settings_screen.dart';
import 'package:archiveme_mobile/security/app_lock_service.dart';
import 'package:archiveme_mobile/security/app_lock_settings.dart';
import 'package:archiveme_mobile/security/app_lock_store.dart';
import 'package:archiveme_mobile/security/archive_privacy_controls_copy.dart';
import 'package:archiveme_mobile/security/security_settings_copy.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:archiveme_mobile/services/auth_service.dart';
import 'package:archiveme_mobile/storage/secure_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_auth_api_client.dart';

class _FakeBiometrics implements BiometricAuthenticator {
  _FakeBiometrics() : isAvailable = false;

  bool isAvailable;

  @override
  Future<bool> available() async => isAvailable;

  @override
  Future<bool> authenticate(String reason) async => false;
}

class _MemorySecure extends SecureStorageService {
  final Map<String, String> values = {};

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

void main() {
  late MemoryAppLockStore memory;
  late _FakeBiometrics biometrics;
  late AppLockService appLock;
  late FakeAuthApiClient fakeAuth;
  late AuthService auth;

  setUp(() {
    ActivationFunnelAnalytics.resetForTest();
    ActivationFunnelAnalytics.captureForTest((_, _) {});
    memory = MemoryAppLockStore();
    biometrics = _FakeBiometrics();
    appLock = AppLockService(
      store: AppLockStore(store: memory),
      biometrics: biometrics,
    );
    fakeAuth = FakeAuthApiClient();
    final secure = _MemorySecure();
    auth = createTestAuthService(api: fakeAuth, secure: secure);
  });

  tearDown(ActivationFunnelAnalytics.resetForTest);

  /// `SecuritySettingsScreen` renders through `PushedScreenShell`, whose AppBar
  /// holds a `SyncStatusAppBarAction` — a `ConsumerWidget` — so every case here
  /// threw `Bad state: No ProviderScope found`, and the resulting ErrorWidget
  /// overflowed the AppBar's action Row by ~99,200px. Same treatment as
  /// `privacy_screen_test.dart`: the status is overridden rather than left to
  /// resolve, so the indicator stays hidden, contributes no text of its own to
  /// the copy assertions, and `networkConnectivityProvider` is never reached.
  Widget wrapSecurity(Widget child) => ProviderScope(
    overrides: [
      syncStatusProvider.overrideWithValue(
        const SyncStatusSnapshot(sync: BackgroundSyncState(), isOnline: true),
      ),
    ],
    child: child,
  );

  Future<void> pumpSecurity(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      wrapSecurity(
        MaterialApp(
          home: SecuritySettingsScreen(appLock: appLock, auth: auth),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  group('Privacy controls card', () {
    testWidgets('shows archive privacy trust controls at top', (tester) async {
      await pumpSecurity(tester);

      expect(
        find.byKey(const Key('archive_privacy_controls_card')),
        findsOneWidget,
      );
      expect(find.text(ArchivePrivacyControlsCopy.cardTitle), findsOneWidget);
      expect(find.text(ArchivePrivacyControlsCopy.lockTitle), findsWidgets);
      expect(find.text(ArchivePrivacyControlsCopy.exportTitle), findsOneWidget);
      expect(find.text(ArchivePrivacyControlsCopy.deleteTitle), findsOneWidget);
      expect(
        find.text(ArchivePrivacyControlsCopy.cloudSubtitle),
        findsOneWidget,
      );
    });
  });

  group('App lock section', () {
    testWidgets('shows Off status and hides PIN actions when disabled', (
      tester,
    ) async {
      await pumpSecurity(tester);

      expect(find.text(SecuritySettingsCopy.title), findsOneWidget);
      expect(find.text(SecuritySettingsCopy.subtitle), findsOneWidget);
      final status = tester.widget<ListTile>(
        find.byKey(const Key('security_app_lock_status')),
      );
      expect(
        (status.subtitle! as Text).data,
        contains(SecuritySettingsCopy.statusOff),
      );
      // Unavailable actions are hidden while the lock is off.
      expect(find.byKey(const Key('security_change_pin')), findsNothing);
      expect(find.byKey(const Key('security_turn_off_app_lock')), findsNothing);
      expect(find.byKey(const Key('security_biometrics_switch')), findsNothing);
    });

    testWidgets('shows On status with PIN actions when enabled', (
      tester,
    ) async {
      await appLock.enableWithPin('1234');
      await pumpSecurity(tester);

      final status = tester.widget<ListTile>(
        find.byKey(const Key('security_app_lock_status')),
      );
      expect(
        (status.subtitle! as Text).data,
        contains(SecuritySettingsCopy.statusOn),
      );
      expect(find.text(AppLockCopy.settingsChangePin), findsOneWidget);
      expect(find.text(AppLockCopy.settingsTurnOff), findsOneWidget);
    });

    testWidgets('biometrics switch is disabled without device hardware', (
      tester,
    ) async {
      await appLock.enableWithPin('1234');
      biometrics.isAvailable = false;
      await pumpSecurity(tester);

      final toggle = tester.widget<SwitchListTile>(
        find.byKey(const Key('security_biometrics_switch')),
      );
      expect(toggle.onChanged, isNull);
    });

    testWidgets('biometrics switch is usable with device hardware', (
      tester,
    ) async {
      await appLock.enableWithPin('1234');
      biometrics.isAvailable = true;
      await pumpSecurity(tester);

      final toggle = tester.widget<SwitchListTile>(
        find.byKey(const Key('security_biometrics_switch')),
      );
      expect(toggle.onChanged, isNotNull);
    });

    testWidgets('turn off app lock updates the status to Off', (tester) async {
      await appLock.enableWithPin('1234');
      await pumpSecurity(tester);

      await tester.tap(find.byKey(const Key('security_turn_off_app_lock')));
      await tester.pump();
      await tester.pump();

      final status = tester.widget<ListTile>(
        find.byKey(const Key('security_app_lock_status')),
      );
      expect(
        (status.subtitle! as Text).data,
        contains(SecuritySettingsCopy.statusOff),
      );
      expect(await appLock.isEnabled(), isFalse);
    });
  });

  group('Account section', () {
    testWidgets('signed out: Not signed in with sign-in actions only', (
      tester,
    ) async {
      await pumpSecurity(tester);

      expect(find.text(SecuritySettingsCopy.notSignedIn), findsOneWidget);
      expect(find.byKey(const Key('security_sign_in')), findsOneWidget);
      expect(find.byKey(const Key('security_create_account')), findsOneWidget);
      expect(find.byKey(const Key('security_sign_out')), findsNothing);
    });

    testWidgets('signed in: Signed in with sign-out only', (tester) async {
      fakeAuth.session = const UserSession(
        userId: 'u1',
        email: 'p@example.com',
      );
      await auth.refreshSession();
      await pumpSecurity(tester);

      expect(find.text(SecuritySettingsCopy.signedIn), findsOneWidget);
      expect(find.byKey(const Key('security_sign_out')), findsOneWidget);
      expect(find.byKey(const Key('security_sign_in')), findsNothing);
      expect(find.byKey(const Key('security_create_account')), findsNothing);
      // No private content — the email is not rendered here.
      expect(find.textContaining('@'), findsNothing);
    });

    testWidgets('sign out flips the status to Not signed in', (tester) async {
      fakeAuth.session = const UserSession(
        userId: 'u1',
        email: 'p@example.com',
      );
      await auth.refreshSession();
      await pumpSecurity(tester);

      await tester.tap(find.byKey(const Key('security_sign_out')));
      await tester.pump();
      await tester.pump();

      expect(fakeAuth.signOutCalls, 1);
      expect(find.text(SecuritySettingsCopy.notSignedIn), findsOneWidget);
    });
  });

  group('Data section', () {
    testWidgets('export, wipe, and delete remain visible; restore hidden when billing frozen', (
      tester,
    ) async {
      await pumpSecurity(tester);

      expect(
        find.byKey(const Key('security_restore_purchases')),
        findsNothing,
      );
      expect(find.text('Restore purchases'), findsNothing);
      expect(find.byKey(const Key('security_export')), findsOneWidget);
      expect(find.byKey(const Key('security_wipe_local')), findsOneWidget);
      expect(
        find.byKey(const Key('security_hide_app_switcher')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('security_delete')), findsOneWidget);
    });
  });

  group('Entry point', () {
    testWidgets('settings shows the Security tile', (tester) async {
      // `SettingsScreen` reaches the same `SyncStatusAppBarAction`, so it needs
      // the scope too — this case failed for the identical reason.
      await tester.pumpWidget(
        wrapSecurity(const MaterialApp(home: SettingsScreen())),
      );
      await tester.pump();

      // The Memory section above can grow after async loads — scroll
      // until the tile is built rather than relying on the initial fold.
      await tester.dragUntilVisible(
        find.byKey(const Key('settings_security_tile')),
        find.byType(ListView),
        const Offset(0, -120),
      );
      await tester.pump();

      expect(find.byKey(const Key('settings_security_tile')), findsOneWidget);
      expect(find.text(SecuritySettingsCopy.title), findsOneWidget);
    });
  });

  group('Copy safety', () {
    testWidgets('no false claims, banned words, or VoiceMemory on screen', (
      tester,
    ) async {
      for (final enabled in const [false, true]) {
        if (enabled) await appLock.enableWithPin('1234');
        await pumpSecurity(tester);

        final rendered = tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data ?? '')
            .join(' ')
            .toLowerCase();
        for (final banned in const [
          // No claims that are not implemented on this surface.
          'sync',
          'encrypt',
          // Banned words.
          'military-grade',
          'unbreakable',
          'impossible',
          'guaranteed',
          'therapy',
          'treatment',
          'diagnose',
          'voicememory',
        ]) {
          expect(
            rendered,
            isNot(contains(banned)),
            reason: 'security screen must not contain "$banned"',
          );
        }
      }
    });
  });
}