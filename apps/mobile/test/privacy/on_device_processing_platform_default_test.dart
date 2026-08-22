import 'dart:io';

import 'package:archiveme_mobile/features/privacy/on_device_processing_store.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_consent_store.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_purpose.dart';
import 'package:archiveme_mobile/security/remote_processing_consent_gate.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// A consent store whose reads fail, so the gate's fail-closed path is real
/// rather than asserted from its source.
class _UnreadableConsentStore extends RemoteProcessingConsentStore {
  _UnreadableConsentStore(super.prefs);

  @override
  Future<RemoteProcessingConsentState> current() async {
    throw const FileSystemException('prefs unreadable');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late MobilePrefsStore prefs;
  late OnDeviceProcessingStoreForTest storeForTest;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('on_device_default_');
    prefs = await MobilePrefsStore.open('${tempDir.path}/prefs.json');
    storeForTest = OnDeviceProcessingStoreForTest(prefs);
    await OnDeviceProcessingStore.resetForTest();
  });

  tearDown(() async {
    await OnDeviceProcessingStore.resetForTest();
    if (tempDir.existsSync()) await tempDir.delete(recursive: true);
  });

  group('platform-conditional default', () {
    test('an unset preference resolves to on for iOS', () {
      OnDeviceProcessingStore.debugPlatformOverride = 'ios';
      expect(OnDeviceProcessingStore.hasExplicitPreference, isFalse);
      expect(OnDeviceProcessingStore.enabled, isTrue);
      expect(OnDeviceProcessingStore.defaultEnabledFor('ios'), isTrue);
    });

    test('an unset preference resolves to off for Android', () {
      OnDeviceProcessingStore.debugPlatformOverride = 'android';
      expect(OnDeviceProcessingStore.hasExplicitPreference, isFalse);
      expect(
        OnDeviceProcessingStore.enabled,
        isFalse,
        reason: 'Android has no local transcription path to fall back to',
      );
      expect(OnDeviceProcessingStore.defaultEnabledFor('android'), isFalse);
    });

    test('an explicitly set preference is untouched on both platforms',
        () async {
      for (final platform in ['ios', 'android']) {
        for (final choice in [true, false]) {
          await OnDeviceProcessingStore.resetForTest();
          OnDeviceProcessingStore.debugPlatformOverride = platform;
          await OnDeviceProcessingStore.setEnabled(choice);

          expect(OnDeviceProcessingStore.hasExplicitPreference, isTrue);
          expect(
            OnDeviceProcessingStore.enabled,
            choice,
            reason: 'explicit $choice on $platform must survive the default',
          );
        }
      }
    });

    test('storage distinguishes unset from explicitly set to on', () async {
      expect(
        await storeForTest.readExplicit(),
        isNull,
        reason: 'no key written yet',
      );

      await storeForTest.setEnabled(true);
      expect(await storeForTest.readExplicit(), isTrue);

      await storeForTest.setEnabled(false);
      expect(await storeForTest.readExplicit(), isFalse);
    });

    test('the platform default is only consulted when nothing is stored',
        () async {
      OnDeviceProcessingStore.debugPlatformOverride = 'android';
      expect(OnDeviceProcessingStore.enabled, isFalse);

      // The same install, having chosen on-device-only before this version.
      await OnDeviceProcessingStore.setEnabled(true);
      expect(OnDeviceProcessingStore.enabled, isTrue);

      // And the Android default cannot claw it back.
      expect(OnDeviceProcessingStore.defaultEnabled, isFalse);
      expect(OnDeviceProcessingStore.enabled, isTrue);
    });
  });

  group('fail closed', () {
    test('the fail-closed value is on, independent of the platform default',
        () {
      OnDeviceProcessingStore.debugPlatformOverride = 'android';
      expect(OnDeviceProcessingStore.defaultEnabled, isFalse);
      expect(
        OnDeviceProcessingStore.failClosedEnabled,
        isTrue,
        reason: 'reusing the Android default here would fail open',
      );
    });

    test('a gate read error permits nothing, even with consent granted',
        () async {
      await RemoteProcessingConsentStore(prefs).grant();
      await OnDeviceProcessingStore.setEnabled(false);

      final gate = RemoteProcessingConsentGate(_UnreadableConsentStore(prefs));
      for (final purpose in RemoteProcessingPurpose.values) {
        expect(await gate.isPurposePermittedNow(purpose), isFalse);
      }
    });
  });
}
