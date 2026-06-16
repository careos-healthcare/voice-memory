import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/security/app_lock_gate.dart';
import 'package:voicememory_mobile/security/app_lock_service.dart';
import 'package:voicememory_mobile/security/app_lock_settings.dart';
import 'package:voicememory_mobile/security/app_lock_store.dart';
import 'package:voicememory_mobile/security/pin_hash.dart';
import 'package:voicememory_mobile/services/activation_funnel_analytics.dart';
import 'package:voicememory_mobile/widgets/security/app_lock_screen.dart';
import 'package:voicememory_mobile/widgets/security/setup_pin_screen.dart';

class _FakeBiometrics implements BiometricAuthenticator {
  _FakeBiometrics({this.isAvailable = false, this.result = false});

  bool isAvailable;
  bool result;
  int attempts = 0;

  @override
  Future<bool> available() async => isAvailable;

  @override
  Future<bool> authenticate(String reason) async {
    attempts++;
    return result;
  }
}

void main() {
  late List<({String event, Map<String, Object> properties})> captured;

  List<({String event, Map<String, Object> properties})> eventsNamed(
    String name,
  ) => captured.where((e) => e.event == name).toList();

  late MemoryAppLockStore memory;
  late _FakeBiometrics biometrics;
  late DateTime now;

  AppLockService buildService() => AppLockService(
    store: AppLockStore(store: memory),
    biometrics: biometrics,
    clock: () => now,
  );

  setUp(() {
    captured = [];
    ActivationFunnelAnalytics.resetForTest();
    ActivationFunnelAnalytics.captureForTest(
      (event, properties) =>
          captured.add((event: event, properties: properties)),
    );
    memory = MemoryAppLockStore();
    biometrics = _FakeBiometrics();
    now = DateTime(2026, 6, 11, 9);
  });

  tearDown(() {
    ActivationFunnelAnalytics.resetForTest();
    AppLockService.instanceForTest = null;
  });

  group('PIN hashing', () {
    test('accepts 4-6 digit PINs only', () {
      expect(PinHash.isValidPin('1234'), isTrue);
      expect(PinHash.isValidPin('123456'), isTrue);
      for (final bad in const ['123', '1234567', 'abcd', '12 4', '', '12a4']) {
        expect(PinHash.isValidPin(bad), isFalse, reason: '"$bad" must fail');
      }
    });

    test('hash is salted, deterministic, and never the raw PIN', () {
      final saltA = PinHash.generateSalt();
      final saltB = PinHash.generateSalt();
      expect(saltA, isNot(saltB));

      final hashA = PinHash.hash(pin: '1234', salt: saltA);
      expect(hashA, PinHash.hash(pin: '1234', salt: saltA));
      // Different salt → different hash for the same PIN.
      expect(hashA, isNot(PinHash.hash(pin: '1234', salt: saltB)));
      expect(hashA, isNot('1234'));
      expect(hashA, isNot(contains('1234')));
    });

    test('verify accepts the right PIN and rejects the wrong one', () {
      final salt = PinHash.generateSalt();
      final hash = PinHash.hash(pin: '4321', salt: salt);
      expect(
        PinHash.verify(pin: '4321', salt: salt, expectedHash: hash),
        isTrue,
      );
      expect(
        PinHash.verify(pin: '4322', salt: salt, expectedHash: hash),
        isFalse,
      );
    });
  });

  group('PIN setup and storage', () {
    test('setup stores hash + salt, never the raw PIN', () async {
      final service = buildService();
      expect(await service.enableWithPin('1234'), isTrue);

      expect(memory.values[AppLockStore.enabledKey], 'true');
      final hash = memory.values[AppLockStore.pinHashKey];
      final salt = memory.values[AppLockStore.pinSaltKey];
      expect(hash, isNotNull);
      expect(salt, isNotNull);
      // The stored hash is the derived value, not the PIN.
      expect(hash, PinHash.hash(pin: '1234', salt: salt!));
      // The raw PIN appears nowhere in storage.
      expect(memory.values.values, isNot(contains('1234')));
      expect(memory.values.keys, isNot(contains('1234')));
    });

    test('invalid PINs are rejected without touching storage', () async {
      final service = buildService();
      expect(await service.enableWithPin('12'), isFalse);
      expect(await service.enableWithPin('abcd12'), isFalse);
      expect(memory.values, isEmpty);
    });
  });

  group('Unlock rules', () {
    test('correct PIN unlocks; wrong PIN fails and stays locked', () async {
      await buildService().enableWithPin('1234');

      // A fresh session starts locked.
      final session = buildService();
      expect(await session.isLocked(), isTrue);

      expect(await session.verifyPin('9999'), isFalse);
      expect(await session.isLocked(), isTrue);
      final failed = eventsNamed(ActivationFunnelAnalytics.appLockFailed);
      expect(failed, hasLength(1));
      expect(failed.single.properties, {'method': 'pin'});

      expect(await session.verifyPin('1234'), isTrue);
      expect(await session.isLocked(), isFalse);
      final unlocked = eventsNamed(ActivationFunnelAnalytics.appLockUnlocked);
      expect(unlocked, hasLength(1));
      expect(unlocked.single.properties, {'method': 'pin'});
    });

    test('disable and change PIN require a successful unlock', () async {
      await buildService().enableWithPin('1234');

      final locked = buildService();
      expect(await locked.disable(), isFalse);
      expect(await locked.changePin('5678'), isFalse);
      expect(memory.values[AppLockStore.enabledKey], 'true');

      expect(await locked.verifyPin('1234'), isTrue);
      expect(await locked.changePin('5678'), isTrue);
      expect(await locked.verifyPin('5678'), isTrue);
      expect(await locked.disable(), isTrue);
      expect(memory.values, isEmpty);
      final disabled = eventsNamed(ActivationFunnelAnalytics.appLockDisabled);
      expect(disabled, hasLength(1));
      expect(disabled.single.properties, {'enabled': 'false'});
    });

    test('re-locks after the background timeout, not before', () async {
      final service = buildService();
      await service.enableWithPin('1234');
      expect(await service.isLocked(), isFalse);

      // Short background: stays unlocked.
      service.onAppBackgrounded();
      now = now.add(const Duration(minutes: 1));
      await service.onAppResumed();
      expect(await service.isLocked(), isFalse);

      // Long background: re-locks.
      service.onAppBackgrounded();
      now = now.add(const Duration(minutes: 2));
      await service.onAppResumed();
      expect(await service.isLocked(), isTrue);
    });
  });

  group('Biometric rules', () {
    test('ready only with PIN set, opt-in, and available hardware', () async {
      biometrics
        ..isAvailable = true
        ..result = true;
      final service = buildService();
      // No PIN yet — never ready, even with hardware and opt-in.
      await service.setBiometricsEnabled(true);
      expect(await service.biometricUnlockReady(), isFalse);

      await service.enableWithPin('1234');
      expect(await service.biometricUnlockReady(), isTrue);

      // No hardware — gracefully unavailable.
      biometrics.isAvailable = false;
      expect(await service.biometricUnlockReady(), isFalse);

      // Opt-out respected.
      biometrics.isAvailable = true;
      await service.setBiometricsEnabled(false);
      expect(await service.biometricUnlockReady(), isFalse);
    });

    test('success unlocks; failure falls back to PIN', () async {
      biometrics
        ..isAvailable = true
        ..result = false;
      final setup = buildService();
      await setup.enableWithPin('1234');
      await setup.setBiometricsEnabled(true);

      final session = buildService();
      expect(await session.attemptBiometricUnlock(), isFalse);
      expect(await session.isLocked(), isTrue);
      expect(biometrics.attempts, 1);
      expect(
        eventsNamed(ActivationFunnelAnalytics.biometricUnlockAttempted),
        hasLength(1),
      );
      expect(
        eventsNamed(ActivationFunnelAnalytics.biometricUnlockFailed),
        hasLength(1),
      );
      // PIN fallback still works.
      expect(await session.verifyPin('1234'), isTrue);
      expect(await session.isLocked(), isFalse);

      // A fresh locked session with working biometrics unlocks.
      biometrics.result = true;
      final session2 = buildService();
      expect(await session2.attemptBiometricUnlock(), isTrue);
      expect(await session2.isLocked(), isFalse);
      final succeeded = eventsNamed(
        ActivationFunnelAnalytics.biometricUnlockSucceeded,
      );
      expect(succeeded, hasLength(1));
      expect(succeeded.single.properties, {'method': 'biometric'});
    });
  });

  group('App lock gate', () {
    const privateProbe = 'PRIVATE ARCHIVE CONTENT PROBE';

    Future<void> pumpGate(WidgetTester tester, AppLockService service) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AppLockGate(
            service: service,
            child: const Scaffold(body: Text(privateProbe)),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    testWidgets('hides archive content behind the lock screen', (tester) async {
      await buildService().enableWithPin('1234');
      final session = buildService();
      await pumpGate(tester, session);

      expect(find.text(privateProbe), findsNothing);
      expect(find.byKey(const Key('app_lock_screen')), findsOneWidget);
      expect(find.text(AppLockCopy.lockTitle), findsOneWidget);
      expect(find.text(AppLockCopy.lockBody), findsOneWidget);
    });

    testWidgets('correct PIN reveals the content', (tester) async {
      await buildService().enableWithPin('1234');
      final session = buildService();
      await pumpGate(tester, session);

      await tester.enterText(
        find.byKey(const Key('app_lock_pin_field')),
        '1234',
      );
      await tester.tap(find.byKey(const Key('app_lock_unlock_cta')));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('app_lock_screen')), findsNothing);
      expect(find.text(privateProbe), findsOneWidget);
    });

    testWidgets('wrong PIN shows Try again and keeps content hidden', (
      tester,
    ) async {
      await buildService().enableWithPin('1234');
      final session = buildService();
      await pumpGate(tester, session);

      await tester.enterText(
        find.byKey(const Key('app_lock_pin_field')),
        '9999',
      );
      await tester.tap(find.byKey(const Key('app_lock_unlock_cta')));
      await tester.pump();
      await tester.pump();

      expect(find.byKey(const Key('app_lock_try_again')), findsOneWidget);
      expect(find.text(privateProbe), findsNothing);
    });

    testWidgets('content shows directly when the lock is off', (tester) async {
      await pumpGate(tester, buildService());
      expect(find.text(privateProbe), findsOneWidget);
      expect(find.byKey(const Key('app_lock_screen')), findsNothing);
    });

    testWidgets('biometric button only when available, opted in, PIN set', (
      tester,
    ) async {
      biometrics
        ..isAvailable = true
        ..result = false;
      final setup = buildService();
      await setup.enableWithPin('1234');
      await setup.setBiometricsEnabled(true);

      final session = buildService();
      await pumpGate(tester, session);
      expect(find.byKey(const Key('app_lock_biometric_cta')), findsOneWidget);

      // Biometric failure keeps the lock and the PIN path available.
      await tester.tap(find.byKey(const Key('app_lock_biometric_cta')));
      await tester.pump();
      expect(find.text(privateProbe), findsNothing);
      await tester.enterText(
        find.byKey(const Key('app_lock_pin_field')),
        '1234',
      );
      await tester.tap(find.byKey(const Key('app_lock_unlock_cta')));
      await tester.pump();
      await tester.pump();
      expect(find.text(privateProbe), findsOneWidget);
    });

    testWidgets('no biometric button without hardware', (tester) async {
      biometrics.isAvailable = false;
      final setup = buildService();
      await setup.enableWithPin('1234');
      await setup.setBiometricsEnabled(true);

      final session = buildService();
      await pumpGate(tester, session);
      expect(find.byKey(const Key('app_lock_screen')), findsOneWidget);
      expect(find.byKey(const Key('app_lock_biometric_cta')), findsNothing);
    });
  });

  group('PIN setup screen', () {
    Future<void> pumpSetup(WidgetTester tester, AppLockService service) async {
      await tester.pumpWidget(
        MaterialApp(home: SetupPinScreen(service: service)),
      );
      await tester.pump();
    }

    testWidgets('create + confirm enables the lock with hash + salt only', (
      tester,
    ) async {
      final service = buildService();
      await pumpSetup(tester, service);

      expect(find.text(AppLockCopy.setupTitle), findsOneWidget);
      expect(find.text(AppLockCopy.setupBody), findsOneWidget);
      expect(find.text(AppLockCopy.setupPrivacyLine), findsOneWidget);

      await tester.enterText(find.byKey(const Key('setup_pin_field')), '2468');
      await tester.tap(find.byKey(const Key('setup_pin_cta')));
      await tester.pump();
      expect(find.text(AppLockCopy.setupConfirmTitle), findsOneWidget);

      await tester.enterText(find.byKey(const Key('setup_pin_field')), '2468');
      await tester.tap(find.byKey(const Key('setup_pin_cta')));
      await tester.pump();
      await tester.pump();

      expect(await service.isEnabled(), isTrue);
      expect(memory.values.values, isNot(contains('2468')));
      expect(memory.values[AppLockStore.pinHashKey], isNotNull);
      expect(memory.values[AppLockStore.pinSaltKey], isNotNull);
    });

    testWidgets('a mismatched confirmation asks to try again', (tester) async {
      final service = buildService();
      await pumpSetup(tester, service);

      await tester.enterText(find.byKey(const Key('setup_pin_field')), '2468');
      await tester.tap(find.byKey(const Key('setup_pin_cta')));
      await tester.pump();
      await tester.enterText(find.byKey(const Key('setup_pin_field')), '1357');
      await tester.tap(find.byKey(const Key('setup_pin_cta')));
      await tester.pump();

      expect(find.byKey(const Key('setup_pin_mismatch')), findsOneWidget);
      expect(find.text(AppLockCopy.setupMismatch), findsOneWidget);
      // Back at the create step; nothing was stored.
      expect(find.text(AppLockCopy.setupTitle), findsOneWidget);
      expect(await service.isEnabled(), isFalse);
      expect(memory.values, isEmpty);
    });
  });

  group('Copy and analytics safety', () {
    test('no banned words or VoiceMemory in any app lock copy', () {
      final copy = [
        AppLockCopy.settingsTitle,
        AppLockCopy.settingsBody,
        AppLockCopy.settingsBiometricsLabel,
        AppLockCopy.settingsChangePin,
        AppLockCopy.settingsTurnOff,
        AppLockCopy.setupTitle,
        AppLockCopy.setupBody,
        AppLockCopy.setupConfirmTitle,
        AppLockCopy.setupPrivacyLine,
        AppLockCopy.setupMismatch,
        AppLockCopy.setupPinHint,
        AppLockCopy.setupContinueLabel,
        AppLockCopy.setupSaveLabel,
        AppLockCopy.lockTitle,
        AppLockCopy.lockBody,
        AppLockCopy.lockBiometricsLabel,
        AppLockCopy.lockTryAgain,
        AppLockCopy.lockUnlockLabel,
        AppLockCopy.biometricReason,
      ].join(' ').toLowerCase();
      for (final banned in const [
        'therapy',
        'treatment',
        'diagnose',
        'problem',
        'failure',
        'weak',
        'lazy',
        'must',
        'should',
        'military-grade',
        'unbreakable',
        // No false claims or fear either.
        'encrypt',
        'hacker',
        'voicememory',
      ]) {
        expect(
          copy,
          isNot(contains(banned)),
          reason: 'app lock copy must not contain "$banned"',
        );
      }
    });

    test(
      'analytics carry only method/enabled ids — never PIN, hash, salt',
      () async {
        biometrics
          ..isAvailable = true
          ..result = true;
        final service = buildService();
        await service.enableWithPin('1234');
        await service.setBiometricsEnabled(true);
        await service.verifyPin('9999');
        await service.verifyPin('1234');
        await service.attemptBiometricUnlock();
        await service.disable();

        final hash = PinHash.hash(pin: '1234', salt: PinHash.generateSalt());
        expect(captured, isNotEmpty);
        for (final e in captured) {
          expect(
            e.properties.keys.toSet().difference(const {'method', 'enabled'}),
            isEmpty,
            reason: '${e.event} carries a non-whitelisted key',
          );
          for (final value in e.properties.values) {
            expect(
              const {'pin', 'biometric', 'true', 'false'},
              contains(value),
              reason: '${e.event} carries unexpected value $value',
            );
          }
          final flat = '${e.event} ${e.properties.values.join(' ')}';
          expect(flat, isNot(contains('1234')));
          expect(flat, isNot(contains('9999')));
          expect(flat, isNot(contains(hash)));
        }
      },
    );
  });
}
