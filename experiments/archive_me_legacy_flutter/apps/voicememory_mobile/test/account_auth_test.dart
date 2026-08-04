import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/l10n/generated/app_localizations.dart';
import 'package:voicememory_mobile/l10n/generated/app_localizations_en.dart';
import 'package:voicememory_mobile/api/api_client.dart';
import 'package:voicememory_mobile/api/api_exceptions.dart';
import 'package:voicememory_mobile/auth/account_auth.dart';
import 'package:voicememory_mobile/models/journal_entry.dart';
import 'package:voicememory_mobile/models/session.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/screens/account_auth_screen.dart';
import 'package:voicememory_mobile/screens/settings_screen.dart';
import 'package:voicememory_mobile/services/activation_funnel_analytics.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/services/auth_service.dart';
import 'package:voicememory_mobile/storage/journal_store.dart';
import 'package:voicememory_mobile/storage/secure_storage.dart';
import 'package:voicememory_mobile/storage/session_cookie_store.dart';

const _testEmail = 'person@example.com';

/// Provider fake — records calls; no HTTP, no real backend.
class _FakeApi extends AuthApiClient {
  _FakeApi() : super(ApiTransport(baseUrl: 'http://test.invalid'));

  final List<String> sendCodeCalls = [];
  final List<String> verifyCalls = [];
  int signOutCalls = 0;
  Object? sendCodeError;
  Object? verifyError;

  @override
  Future<void> sendAuthCode(String email) async {
    final error = sendCodeError;
    if (error != null) throw error;
    sendCodeCalls.add(email);
  }

  @override
  Future<UserSession> verifyAuthCode({
    required String email,
    required String code,
  }) async {
    final error = verifyError;
    if (error != null) throw error;
    verifyCalls.add('$email|$code');
    setSessionCookie('vm_session=test-cookie');
    return UserSession(userId: 'u1', email: email);
  }

  @override
  Future<UserSession?> getSession() async => null;

  @override
  Future<void> signOut() async {
    signOutCalls++;
  }
}

/// In-memory secure storage — no platform channels.
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

final _l10n = AppLocalizationsEn();

void main() {
  late List<({String event, Map<String, Object> properties})> captured;
  late _FakeApi api;
  late _MemorySecure secure;
  late AuthService auth;

  List<({String event, Map<String, Object> properties})> eventsNamed(
    String name,
  ) => captured.where((e) => e.event == name).toList();

  setUp(() {
    captured = [];
    ActivationFunnelAnalytics.resetForTest();
    ActivationFunnelAnalytics.captureForTest(
      (event, properties) =>
          captured.add((event: event, properties: properties)),
    );
    api = _FakeApi();
    secure = _MemorySecure();
    auth = AuthService(api, secure, SessionCookieStore(secure));
  });

  tearDown(ActivationFunnelAnalytics.resetForTest);

  Future<void> pumpAuth(WidgetTester tester, AccountAuthIntent intent) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: AccountAuthScreen(intent: intent, service: auth),
      ),
    );
    await tester.pump();
  }

  Future<void> enterEmailAndSubmit(WidgetTester tester, String email) async {
    await tester.enterText(
      find.byKey(const Key('account_auth_email_field')),
      email,
    );
    await tester.tap(find.byKey(const Key('account_auth_primary_cta')));
    await tester.pump();
  }

  group('Email validation', () {
    test('accepts plausible emails, rejects malformed input', () {
      expect(AccountAuth.isValidEmail('person@example.com'), isTrue);
      expect(AccountAuth.isValidEmail(' person@example.com '), isTrue);
      for (final bad in const [
        '',
        'person',
        'person@',
        '@example.com',
        'person@example',
        'person example@x.com',
      ]) {
        expect(
          AccountAuth.isValidEmail(bad),
          isFalse,
          reason: '"$bad" must fail',
        );
      }
    });

    testWidgets('create account rejects an invalid email before the provider', (
      tester,
    ) async {
      await pumpAuth(tester, AccountAuthIntent.createAccount);
      await enterEmailAndSubmit(tester, 'not-an-email');

      expect(find.text(_l10n.accountAuthInvalidEmail), findsOneWidget);
      expect(api.sendCodeCalls, isEmpty);
      final errors = eventsNamed(ActivationFunnelAnalytics.authErrorShown);
      expect(errors, hasLength(1));
      expect(errors.single.properties, {'error_type': 'invalid_email'});
    });
  });

  group('Passwordless provider', () {
    testWidgets('the flow has no password fields anywhere', (tester) async {
      for (final intent in AccountAuthIntent.values) {
        await pumpAuth(tester, intent);
        expect(find.text('Password'), findsNothing);
        expect(
          tester
              .widgetList<TextField>(find.byType(TextField))
              .where((f) => f.obscureText),
          isEmpty,
        );
      }
    });

    test('nothing password-shaped is ever stored locally', () async {
      await auth.sendAuthCode(_testEmail);
      await auth.verifyAuthCode(email: _testEmail, code: '123456');
      for (final entry in secure.values.entries) {
        expect(entry.key.toLowerCase(), isNot(contains('password')));
        expect(entry.value.toLowerCase(), isNot(contains('password')));
      }
    });
  });

  group('Create account flow', () {
    testWidgets(
      'valid email calls the provider and advances to the code step',
      (tester) async {
        await pumpAuth(tester, AccountAuthIntent.createAccount);
        expect(find.text(_l10n.accountAuthCreateTitle), findsOneWidget);
        expect(find.text(_l10n.accountAuthCreateBody), findsOneWidget);
        expect(find.text(_l10n.accountAuthPrivacyLine), findsOneWidget);
        expect(
          find.text(_l10n.accountAuthContinueWithoutAccount),
          findsOneWidget,
        );

        await enterEmailAndSubmit(tester, _testEmail);

        expect(api.sendCodeCalls, [_testEmail]);
        expect(find.text(_l10n.accountAuthCodeTitle), findsOneWidget);
        final started = eventsNamed(
          ActivationFunnelAnalytics.accountSignupStarted,
        );
        expect(started, hasLength(1));
        expect(started.single.properties, {'method': 'email_code'});

        await tester.enterText(
          find.byKey(const Key('account_auth_code_field')),
          '123456',
        );
        await tester.tap(find.byKey(const Key('account_auth_verify_cta')));
        await tester.pump();

        expect(api.verifyCalls, ['$_testEmail|123456']);
        final completed = eventsNamed(
          ActivationFunnelAnalytics.accountSignupCompleted,
        );
        expect(completed, hasLength(1));
        expect(completed.single.properties, {'method': 'email_code'});
      },
    );
  });

  group('Sign in flow', () {
    testWidgets('sign in calls the provider', (tester) async {
      await pumpAuth(tester, AccountAuthIntent.signIn);
      expect(find.text(_l10n.accountAuthSignInTitle), findsOneWidget);

      await enterEmailAndSubmit(tester, _testEmail);
      expect(api.sendCodeCalls, [_testEmail]);
      expect(
        eventsNamed(ActivationFunnelAnalytics.accountSigninStarted),
        hasLength(1),
      );

      await tester.enterText(
        find.byKey(const Key('account_auth_code_field')),
        '654321',
      );
      await tester.tap(find.byKey(const Key('account_auth_verify_cta')));
      await tester.pump();

      expect(api.verifyCalls, ['$_testEmail|654321']);
      expect(
        eventsNamed(ActivationFunnelAnalytics.accountSigninCompleted),
        hasLength(1),
      );
    });

    testWidgets('resend code calls the provider again (recovery path)', (
      tester,
    ) async {
      await pumpAuth(tester, AccountAuthIntent.signIn);
      await enterEmailAndSubmit(tester, _testEmail);
      expect(api.sendCodeCalls, hasLength(1));

      await tester.tap(find.byKey(const Key('account_auth_resend')));
      await tester.pump();

      expect(api.sendCodeCalls, hasLength(2));
      expect(find.text(_l10n.accountAuthCodeSent), findsOneWidget);
    });

    testWidgets('provider errors show calm copy with a stable id only', (
      tester,
    ) async {
      api.sendCodeError = ApiException(
        'Too many requests. Please wait a moment.',
        statusCode: 429,
      );
      await pumpAuth(tester, AccountAuthIntent.signIn);
      await enterEmailAndSubmit(tester, _testEmail);

      final status = tester.widget<Text>(
        find.byKey(const Key('account_auth_status')),
      );
      expect(status.data, isNotEmpty);
      expect(status.data, isNot(contains('ApiException')));
      expect(status.data, isNot(contains('429')));
      final errors = eventsNamed(ActivationFunnelAnalytics.authErrorShown);
      expect(errors, hasLength(1));
      expect(errors.single.properties, {'error_type': 'rate_limited'});
    });
  });

  group('Error id mapping', () {
    test('maps thrown errors to stable non-sensitive ids', () {
      expect(
        AccountAuth.errorTypeFor(BackendNotConfiguredException()),
        'backend_not_configured',
      );
      expect(AccountAuth.errorTypeFor(NetworkOfflineException()), 'offline');
      expect(
        AccountAuth.errorTypeFor(ApiException('x', statusCode: 401)),
        'invalid_code',
      );
      expect(
        AccountAuth.errorTypeFor(ApiException('x', statusCode: 429)),
        'rate_limited',
      );
      expect(
        AccountAuth.errorTypeFor(ApiException('x', statusCode: 500)),
        'server_error',
      );
      expect(AccountAuth.errorTypeFor(StateError('x')), 'unknown');
      final safe = RegExp(r'^[a-z0-9_]{1,40}$');
      for (final error in [
        BackendNotConfiguredException(),
        NetworkOfflineException(),
        ApiException('x', statusCode: 401),
        StateError('x'),
      ]) {
        expect(safe.hasMatch(AccountAuth.errorTypeFor(error)), isTrue);
      }
    });
  });

  group('Sign out', () {
    test(
      'ends the session, clears the cookie, and tracks the safe event',
      () async {
        await auth.verifyAuthCode(email: _testEmail, code: '123456');
        expect(auth.currentSession, isNotNull);

        await auth.signOut();

        expect(auth.currentSession, isNull);
        expect(api.signOutCalls, 1);
        expect(secure.values.containsKey('auth_cookie'), isFalse);
        final events = eventsNamed(ActivationFunnelAnalytics.accountSignout);
        expect(events, hasLength(1));
        expect(events.single.properties, {'method': 'email_code'});
      },
    );

    test('the local archive is not deleted on sign out', () async {
      final stamp = DateTime.now().microsecondsSinceEpoch;
      final store = await JournalStore.open(
        '/tmp/vm_account_auth_journal_$stamp.json',
      );
      await store.save(
        JournalEntry.fromJson({
          'id': 'entry-1',
          'createdAt': DateTime.now().toUtc().toIso8601String(),
          'transcript': 'kept locally',
          'durationSeconds': 5,
        }),
      );
      await auth.verifyAuthCode(email: _testEmail, code: '123456');

      await auth.signOut();

      final entries = await store.loadAll();
      expect(entries, hasLength(1));
      expect(entries.single.id, 'entry-1');
    });
  });

  group('Restore purchases stays available', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('vm_account_auth_');
      await AppServices.resetForTest(
        journalPath: '${tempDir.path}/journal.json',
        skipRevenueCat: true,
      );
    });

    testWidgets('settings still offers Restore purchases', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SettingsScreen(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.dragUntilVisible(
        find.text(ConsumerUiCopy.restorePurchases),
        find.byType(ListView),
        const Offset(0, -300),
      );
      await tester.pump();
      expect(find.text(ConsumerUiCopy.restorePurchases), findsOneWidget);
    });
  });

  group('Copy and analytics safety', () {
    test('no banned words or VoiceMemory in account copy', () {
      final copy = [
        _l10n.accountAuthCreateTitle,
        _l10n.accountAuthCreateBody,
        _l10n.accountAuthCreateCta,
        _l10n.accountAuthSignInTitle,
        _l10n.accountAuthSignInCta,
        _l10n.accountAuthEmailLabel,
        _l10n.accountAuthCodeTitle,
        _l10n.accountAuthCodeBody,
        _l10n.accountAuthCodeLabel,
        _l10n.accountAuthCodeCta,
        _l10n.accountAuthResendCode,
        _l10n.accountAuthCodeSent,
        _l10n.accountAuthContinueWithoutAccount,
        _l10n.accountAuthPrivacyLine,
        _l10n.accountAuthInvalidEmail,
        _l10n.accountAuthInvalidCode,
        _l10n.accountAuthSignOut,
        _l10n.accountAuthSignOutKeepsArchive,
      ].join(' ').toLowerCase();
      for (final banned in const [
        'weak',
        'failure',
        'problem',
        'must',
        'should',
        'therapy',
        'treatment',
        'diagnose',
        'voicememory',
        // No sync overclaims while sync is not the promise here.
        'cloud sync',
      ]) {
        expect(
          copy,
          isNot(contains(banned)),
          reason: 'account copy must not contain "$banned"',
        );
      }
    });

    testWidgets('no email, code, or password ever reaches analytics', (
      tester,
    ) async {
      // Full create flow + an error + sign out.
      await pumpAuth(tester, AccountAuthIntent.createAccount);
      await enterEmailAndSubmit(tester, _testEmail);
      await tester.enterText(
        find.byKey(const Key('account_auth_code_field')),
        '123456',
      );
      await tester.tap(find.byKey(const Key('account_auth_verify_cta')));
      await tester.pump();
      await auth.signOut();

      expect(captured, isNotEmpty);
      for (final e in captured) {
        expect(
          e.properties.keys.toSet().difference(const {'method', 'error_type'}),
          isEmpty,
          reason: '${e.event} carries a non-whitelisted key',
        );
        final flat = '${e.event} ${e.properties.values.join(' ')}'
            .toLowerCase();
        expect(flat, isNot(contains('@')));
        expect(flat, isNot(contains('password')));
        expect(flat, isNot(contains('person')));
        expect(flat, isNot(contains('example.com')));
        expect(flat, isNot(contains('123456')));
        expect(flat, isNot(contains('vm_session')));
      }
    });
  });
}
