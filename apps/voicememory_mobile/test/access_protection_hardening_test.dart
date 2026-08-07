import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/auth/account_auth.dart';
import 'package:voicememory_mobile/billing/subscription_copy.dart';
import 'package:voicememory_mobile/features/pro/pro_value_preview_copy.dart';
import 'package:voicememory_mobile/features/pro_value/pro_value_copy.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/api/api_client.dart';
import 'package:voicememory_mobile/models/session.dart';
import 'package:archiveme_research/screens/pro_value_preview_screen.dart';
import 'package:voicememory_mobile/screens/security_settings_screen.dart';
import 'package:voicememory_mobile/screens/settings_screen.dart';
import 'package:voicememory_mobile/security/app_lock_service.dart';
import 'package:voicememory_mobile/security/app_lock_settings.dart';
import 'package:voicememory_mobile/security/app_lock_store.dart';
import 'package:voicememory_mobile/security/archive_privacy_controls_copy.dart';
import 'package:voicememory_mobile/security/pin_hash.dart';
import 'package:voicememory_mobile/security/privacy_copy_policy.dart';
import 'package:voicememory_mobile/security/security_settings_copy.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/services/auth_service.dart';
import 'package:voicememory_mobile/storage/secure_storage.dart';
import 'package:voicememory_mobile/storage/session_cookie_store.dart';
import 'package:voicememory_mobile/theme/app_theme.dart';
import 'support/test_storage_sandbox.dart';

class _FakeApi extends ApiClient {
  _FakeApi() : super(baseUrl: 'http://test.invalid');

  @override
  Future<UserSession?> getSession() async => null;
}

class _MemorySecure extends SecureStorageService {
  final Map<String, String> values = {};

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> delete(String key) async => values.remove(key);
}

const _auditDocPath = 'docs/ACCESS_PROTECTION_AUDIT.md';
const _accountAuthScreenPath = 'lib/screens/account_auth_screen.dart';
const _authServicePath = 'lib/services/auth_service.dart';
const _appLockStorePath = 'lib/security/app_lock_store.dart';
const _pinHashPath = 'lib/security/pin_hash.dart';

const _forbiddenPurchaseCtas = ['Buy now', 'Subscribe now', 'Pro is active'];

const _forbiddenClinicalTerms = [
  'therapy',
  'diagnosis',
  'medical',
  'treatment',
];

const _privateSnippet = 'felt pressure at work before saying yes';

void main() {
  late String auditDoc;
  late String accountAuthScreenSource;
  late String authServiceSource;
  late String appLockStoreSource;
  late String pinHashSource;

  setUpAll(() {
    auditDoc = File(_auditDocPath).readAsStringSync();
    accountAuthScreenSource = File(_accountAuthScreenPath).readAsStringSync();
    authServiceSource = File(_authServicePath).readAsStringSync();
    appLockStoreSource = File(_appLockStorePath).readAsStringSync();
    pinHashSource = File(_pinHashPath).readAsStringSync();
  });

  group('ACCESS_PROTECTION_AUDIT.md', () {
    test('exists and documents passwordless auth and anti-sharing limits', () {
      expect(File(_auditDocPath).existsSync(), isTrue);
      expect(auditDoc.toLowerCase(), contains('passwordless'));
      expect(auditDoc.toLowerCase(), contains('email'));
      expect(auditDoc.toLowerCase(), contains('revenuecat'));
      expect(auditDoc.toLowerCase(), contains('purchases are unavailable'));
      expect(
        auditDoc.toLowerCase(),
        anyOf(contains('anti-sharing'), contains('family sharing')),
      );
      expect(auditDoc.toLowerCase(), contains('server entitlement'));
    });
  });

  group('Account auth — passwordless', () {
    test('uses email-code method with no password field copy', () {
      expect(AccountAuth.method, 'email_code');
      expect(AccountAuthCopy.emailLabel, 'Email');
      expect(AccountAuthCopy.codeLabel, 'Code');
      expect(AccountAuthCopy.resendCode, 'Resend code');
      expect(AccountAuthCopy.continueWithoutAccount, isNotEmpty);
      expect(accountAuthScreenSource.toLowerCase(), contains('passwordless'));
      expect(accountAuthScreenSource, isNot(contains("labelText: 'Password'")));
      expect(
        accountAuthScreenSource,
        isNot(contains('TextInputType.visiblePassword')),
      );
    });

    test('create and sign-in flows use email-code copy', () {
      expect(AccountAuthCopy.createCta, 'Create account');
      expect(AccountAuthCopy.signInCta, 'Sign in');
      expect(AccountAuthCopy.codeBody, contains('sign-in code'));
      expect(AccountAuthCopy.codeSent, contains('Code sent'));
    });

    test('sign out keeps local archive', () {
      expect(AccountAuthCopy.signOutKeepsArchive, contains('keeps'));
      expect(authServiceSource, contains('Never touches'));
      expect(authServiceSource, contains('the local journal'));
    });

    test('account timing does not require login before recording', () {
      expect(
        AccountAuthCopy.accountTimingNote.toLowerCase(),
        contains('without an account'),
      );
      expect(AccountAuthCopy.continueWithoutAccount, isNotEmpty);
    });
  });

  group('App lock — local protection', () {
    test('Protect this archive copy is exposed in settings surfaces', () {
      expect(PrivacyCopyPolicy.lockArchiveMe, 'Protect this archive');
      expect(AppLockCopy.settingsTitle, 'Protect this archive');
      expect(
        AppLockCopy.settingsBody.toLowerCase(),
        contains('protects the archive on this device'),
      );
      expect(SecuritySettingsCopy.appLockSection, 'Protect this archive');
      expect(
        ArchivePrivacyControlsCopy.lockSubtitle.toLowerCase(),
        contains('pin'),
      );
    });

    test('PIN is hashed — store has no raw PIN API', () {
      expect(appLockStoreSource, contains('pinHash'));
      expect(appLockStoreSource, contains('pinSalt'));
      expect(appLockStoreSource, isNot(contains('savePin(')));
      expect(pinHashSource.toLowerCase(), contains('raw pin'));
      expect(
        PinHash.hash(pin: '1234', salt: PinHash.generateSalt()),
        isNot('1234'),
      );
    });

    test('biometric is optional with PIN fallback in copy', () {
      expect(AppLockCopy.settingsBiometricsLabel, isNotEmpty);
      expect(AppLockCopy.lockBiometricsLabel, isNotEmpty);
      expect(AppLockCopy.lockBody, contains('PIN'));
      expect(AppLockCopy.relockTimeoutNote, contains('2 minutes'));
    });
  });

  group('Pro / RevenueCat gates', () {
    test('Pro Preview does not claim Pro is active', () {
      for (final line in ProValueCopy.allVisibleCopy()) {
        expect(line, isNot(contains('Pro is active')));
      }
      expect(
        ProValuePreviewCopy.accountRestoreNote.toLowerCase(),
        contains('create an account later'),
      );
      expect(
        ProValuePreviewCopy.purchaseUnavailable.toLowerCase(),
        contains('not available'),
      );
    });

    test('Restore purchases does not require Pro to already be active', () {
      expect(ConsumerUiCopy.restorePurchases, 'Restore purchases');
      expect(
        SubscriptionCopy.temporarilyUnavailable.toLowerCase(),
        contains('not available'),
      );
    });
  });

  group('Consumer copy safety', () {
    Iterable<String> authAndLockCopy() sync* {
      yield AccountAuthCopy.createTitle;
      yield AccountAuthCopy.createBody;
      yield AccountAuthCopy.signInTitle;
      yield AccountAuthCopy.codeBody;
      yield AccountAuthCopy.resendCode;
      yield AccountAuthCopy.privacyLine;
      yield AccountAuthCopy.signOutKeepsArchive;
      yield AccountAuthCopy.accountTimingNote;
      yield AppLockCopy.settingsTitle;
      yield AppLockCopy.settingsBody;
      yield AppLockCopy.setupBody;
      yield AppLockCopy.setupPrivacyLine;
      yield SecuritySettingsCopy.subtitle;
      yield ArchivePrivacyControlsCopy.lockSubtitle;
      yield* ProValueCopy.allVisibleCopy();
    }

    test('no forbidden purchase CTAs in access surfaces', () {
      final joined = authAndLockCopy().join('\n');
      for (final cta in _forbiddenPurchaseCtas) {
        expect(joined, isNot(contains(cta)));
      }
    });

    test('no clinical language in access copy', () {
      final lower = authAndLockCopy().join(' ').toLowerCase();
      for (final term in _forbiddenClinicalTerms) {
        expect(lower, isNot(contains(term)), reason: 'must not contain $term');
      }
    });

    test('no private journal text in auth or app-lock copy', () {
      for (final text in authAndLockCopy()) {
        expect(text.toLowerCase(), isNot(contains(_privateSnippet)));
      }
    });
  });

  group('Settings / Security routing', () {
    late TestStorageSandbox sandbox;

    late AppLockService appLock;
    late AuthService auth;

    setUp(() async {
      sandbox = TestStorageSandbox.create();
      await AppServices.resetForTest(
        journalPath: sandbox.journalPath,
        skipRevenueCat: true,
      );
      final memory = MemoryAppLockStore();
      appLock = AppLockService(
        store: AppLockStore(store: memory),
        biometrics: const NoBiometricAuthenticator(),
      );
      final secure = _MemorySecure();
      auth = AuthService(_FakeApi(), secure, SessionCookieStore(secure));
    });

    tearDown(() => sandbox.dispose());

    testWidgets('Settings exposes Security route', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light(), home: const SettingsScreen()),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      await tester.dragUntilVisible(
        find.byKey(const Key('settings_security_tile')),
        find.byType(ListView),
        const Offset(0, -300),
      );
      await tester.pump();

      expect(find.byKey(const Key('settings_security_tile')), findsOneWidget);
      expect(find.text(SecuritySettingsCopy.title), findsOneWidget);
    });

    testWidgets('Security screen renders Protect this archive section', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: SecuritySettingsScreen(appLock: appLock, auth: auth),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text(SecuritySettingsCopy.appLockSection), findsWidgets);
      expect(find.byKey(const Key('security_app_lock_status')), findsOneWidget);
      expect(
        find.byKey(const Key('security_restore_purchases')),
        findsOneWidget,
      );
    });

    testWidgets('Pro Preview shows account restore note', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const ProValuePreviewScreen(),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('pro_value_preview_account_restore')),
        findsOneWidget,
      );
      expect(find.text(ProValuePreviewCopy.accountRestoreNote), findsOneWidget);
    });
  });
}
