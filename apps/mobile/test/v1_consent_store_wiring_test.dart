import 'dart:io';

import 'package:archiveme_mobile/features/privacy/on_device_processing_store.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_consent_store.dart';
import 'package:archiveme_mobile/security/remote_processing_consent_gate.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // The gate composes consent with "Never send to server", which defaults to
  // on. These cases are about store wiring, so take that veto out of the way.
  setUp(() async {
    await OnDeviceProcessingStore.resetForTest();
    await OnDeviceProcessingStore.setEnabled(false);
  });

  tearDown(OnDeviceProcessingStore.resetForTest);

  test('consent gate and pipeline share one store instance on AppServices', () {
    final wiring = File('lib/services/app_services.dart').readAsStringSync();
    expect(wiring, contains('s.remoteProcessingConsentStore ='));
    expect(wiring, contains('consentStore: s.remoteProcessingConsentStore'));
    expect(
      wiring,
      contains(
        'RemoteProcessingConsentGate(\n      s.remoteProcessingConsentStore',
      ),
    );
  });

  test(
    'RemoteProcessingConsentGate.fromPrefs delegates to shared store type',
    () async {
      final dir = await Directory.systemTemp.createTemp('consent_gate_');
      final prefs = await MobilePrefsStore.open('${dir.path}/prefs.json');
      final store = RemoteProcessingConsentStore(prefs);
      await store.grant();

      final gate = RemoteProcessingConsentGate(store);
      expect(await gate.isPermittedNow(), isTrue);

      final gateFromPrefs = RemoteProcessingConsentGate.fromPrefs(prefs);
      expect(await gateFromPrefs.isPermittedNow(), isTrue);
    },
  );
}