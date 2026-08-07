import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:voicememory_mobile/features/proof_admission/remote_processing_consent_store.dart';
import 'package:voicememory_mobile/security/remote_processing_consent_gate.dart';
import 'package:voicememory_mobile/storage/mobile_prefs_store.dart';

void main() {
  group('RemoteProcessingConsentGate', () {
    late Directory tempDir;
    late MobilePrefsStore prefs;
    late RemoteProcessingConsentGate gate;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('consent_gate_');
      prefs = await MobilePrefsStore.open('${tempDir.path}/prefs.json');
      gate = RemoteProcessingConsentGate.fromPrefs(prefs);
    });

    tearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('never consented — upload not permitted', () async {
      final decision = await gate.evaluate();
      expect(decision.permitted, isFalse);
      expect(decision.consentAtProcessingTime, isFalse);
      expect(decision.currentPermission, isFalse);
    });

    test('consent restored after withdrawal', () async {
      final store = RemoteProcessingConsentStore(prefs);
      await store.grant();
      expect((await gate.evaluate()).permitted, isTrue);

      await store.withdraw();
      expect((await gate.evaluate()).permitted, isFalse);

      await store.grant();
      final restored = await gate.evaluate();
      expect(restored.permitted, isTrue);
      expect(restored.consentAtProcessingTime, isTrue);
    });

    test('withdrawn while queued — recheck blocks upload', () async {
      final store = RemoteProcessingConsentStore(prefs);
      await store.grant();
      expect((await gate.isPermittedNow()), isTrue);

      await store.withdraw();
      expect((await gate.isPermittedNow()), isFalse);
    });
  });
}
