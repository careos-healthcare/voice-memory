import 'dart:io';

import 'package:archiveme_mobile/features/proof_admission/remote_processing_consent_store.dart';
import 'package:archiveme_mobile/features/proof_admission/remote_processing_purpose.dart';
import 'package:archiveme_mobile/security/remote_processing_consent_gate.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter_test/flutter_test.dart';

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

    test('never consented — reflection upload not permitted', () async {
      final decision = await gate.evaluate();
      expect(decision.permitted, isFalse);
      expect(decision.purpose, RemoteProcessingPurpose.remoteReflection);
      expect(decision.consentAtProcessingTime, isFalse);
      expect(decision.currentPermission, isFalse);
    });

    test('never consented — transcription upload not permitted', () async {
      final decision = await gate.evaluateFor(
        RemoteProcessingPurpose.remoteTranscription,
      );
      expect(decision.permitted, isFalse);
      expect(decision.purpose, RemoteProcessingPurpose.remoteTranscription);
    });

    test('partial grant permits only the granted purpose', () async {
      final store = RemoteProcessingConsentStore(prefs);
      await store.grant(
        purposes: {RemoteProcessingPurpose.remoteTranscription},
      );

      expect(
        (await gate.evaluateFor(RemoteProcessingPurpose.remoteTranscription))
            .permitted,
        isTrue,
      );
      expect((await gate.evaluate()).permitted, isFalse);
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
      expect(await gate.isPermittedNow(), isTrue);

      await store.withdraw();
      expect(await gate.isPermittedNow(), isFalse);
    });
  });
}