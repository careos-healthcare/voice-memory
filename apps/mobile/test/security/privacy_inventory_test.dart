import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/security/privacy_copy_policy.dart';
import 'package:archiveme_mobile/security/privacy_inventory.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('privacy inventory matches V1 capability registry', () {
    final native = PrivacyInventory.document['nativePermissionsV1'] as Map;
    expect(native['microphone'], V1CapabilityRegistry.microphone);
    expect(native['notifications'], V1CapabilityRegistry.notifications);
    expect(native['speechRecognition'], V1CapabilityRegistry.speechRecognition);
  });

  test('privacy inventory documents encrypted sync and no server decrypt', () {
    final sync = PrivacyInventory.document['sync'] as Map;
    expect(sync['journalTransport'], 'encrypted_blob_only');
    expect(sync['serverCanDecryptJournal'], isFalse);
  });

  test('privacy contract promises align with inventory remote processing', () {
    final remote = PrivacyInventory.document['remoteProcessing'] as Map;
    expect(remote['requiresExplicitAccountScopedConsent'], isTrue);
    expect(
      PrivacyCopyPolicy.canonicalPromises,
      contains(PrivacyCopyPolicy.journalNotUploadedWithoutConsent),
    );
  });
}