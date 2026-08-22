import 'dart:io';

import 'package:archiveme_mobile/features/privacy/on_device_processing_store.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_consent_store.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_purpose.dart';
import 'package:archiveme_mobile/security/remote_processing_consent_gate.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins the privacy-relevant state `AppServices.resetForTest` leaves behind.
///
/// Every "nothing was sent" assertion in the suite is only as good as the
/// starting state it runs from, and that state is not obvious from a call
/// site: `resetForTest` pre-grants remote-processing consent by default, while
/// the on-device-only veto is a static the harness never touches and which
/// resolves from the *host* platform. A suite can therefore believe it is
/// modelling a fresh install and be modelling neither half of it.
///
/// These cases exist so that changing either behaviour breaks here first, in a
/// file whose whole subject is the harness, rather than silently converting
/// consent assertions elsewhere into assertions about nothing.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;

  setUpAll(() {
    const connectivity = MethodChannel(
      'dev.fluttercommunity.plus/connectivity',
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(connectivity, (call) async {
      if (call.method == 'check') return ['wifi'];
      return null;
    });
  });

  setUp(() async {
    dir = Directory.systemTemp.createTempSync('vm_harness_baseline_');
  });

  tearDown(() async {
    await OnDeviceProcessingStore.resetForTest();
    if (dir.existsSync()) dir.deleteSync(recursive: true);
  });

  Future<void> reset({required bool grantConsent}) async {
    await AppServices.resetForTest(
      journalPath: '${dir.path}/journal.json',
      prefsPath: '${dir.path}/prefs.json',
      grantRemoteProcessingConsentByDefault: grantConsent,
    );
    // The harness does not reset this static, so a prior case in the same
    // file would otherwise leak its choice into the next one.
    await OnDeviceProcessingStore.resetForTest();
  }

  group('what the default harness grants', () {
    test('the default pre-grants both remote purposes', () async {
      await reset(grantConsent: true);
      final store = RemoteProcessingConsentStore(AppServices.instance.prefs);

      expect(await store.isConsentedNow(), isTrue);
      for (final purpose in RemoteProcessingPurpose.values) {
        expect(
          await store.isPurposeGrantedNow(purpose),
          isTrue,
          reason: '$purpose is granted before the test body runs',
        );
      }
    });

    test('opting out of the pre-grant models the real fresh install', () async {
      await reset(grantConsent: false);
      final store = RemoteProcessingConsentStore(AppServices.instance.prefs);

      expect(await store.isConsentedNow(), isFalse);
      for (final purpose in RemoteProcessingPurpose.values) {
        expect(await store.isPurposeGrantedNow(purpose), isFalse);
      }
    });
  });

  group('what the harness leaves the veto at', () {
    test('resetForTest never writes the on-device-only preference', () async {
      await reset(grantConsent: true);
      final probe = OnDeviceProcessingStoreForTest(AppServices.instance.prefs);

      expect(
        await probe.readExplicit(),
        isNull,
        reason: 'the harness makes no choice here, so the platform default '
            'decides and the host platform is what resolves it',
      );
    });

    test(
      'on the host platform the unset veto resolves to on, so the pre-granted '
      'consent still permits nothing',
      () async {
        await reset(grantConsent: true);
        final gate = RemoteProcessingConsentGate(
          RemoteProcessingConsentStore(AppServices.instance.prefs),
        );

        // Not an assertion about macOS specifically: `defaultEnabledFor` is
        // true for everything except Android, and the Dart test host is never
        // Android. Reading it through the same accessor the gate uses keeps
        // this honest if that rule ever changes.
        expect(OnDeviceProcessingStore.defaultEnabled, isTrue);
        expect(OnDeviceProcessingStore.enabled, isTrue);

        for (final purpose in RemoteProcessingPurpose.values) {
          final decision = await gate.evaluateFor(purpose);
          expect(
            decision.currentPermission,
            isTrue,
            reason: 'consent really was pre-granted',
          );
          expect(
            decision.permitted,
            isFalse,
            reason: 'and yet nothing may be sent, because the veto is on. A '
                'suite asserting zero remote calls from this starting state '
                'is measuring the veto, not consent.',
          );
        }
      },
    );

    test('clearing the veto is what makes the pre-grant bite', () async {
      await reset(grantConsent: true);
      await OnDeviceProcessingStore.setEnabled(false);
      final gate = RemoteProcessingConsentGate(
        RemoteProcessingConsentStore(AppServices.instance.prefs),
      );

      for (final purpose in RemoteProcessingPurpose.values) {
        expect(await gate.isPurposePermittedNow(purpose), isTrue);
      }
    });

    test('with the veto cleared, the two harness modes finally differ',
        () async {
      // The pair that shows the flag is load-bearing at all. Without clearing
      // the veto both arms answer "not permitted" and the flag is invisible.
      await reset(grantConsent: false);
      await OnDeviceProcessingStore.setEnabled(false);
      final unconsented = RemoteProcessingConsentGate(
        RemoteProcessingConsentStore(AppServices.instance.prefs),
      );
      expect(
        await unconsented.isPurposePermittedNow(
          RemoteProcessingPurpose.remoteTranscription,
        ),
        isFalse,
      );

      await reset(grantConsent: true);
      await OnDeviceProcessingStore.setEnabled(false);
      final consented = RemoteProcessingConsentGate(
        RemoteProcessingConsentStore(AppServices.instance.prefs),
      );
      expect(
        await consented.isPurposePermittedNow(
          RemoteProcessingPurpose.remoteTranscription,
        ),
        isTrue,
      );
    });
  });
}
