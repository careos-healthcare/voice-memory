import 'package:archiveme_mobile/core/config/v1_capability_registry.dart' show V1CapabilityRegistry;
import 'package:archiveme_mobile/features/recording/recording_dependencies.dart' show V1CapabilityRegistry;

/// Machine-readable privacy inventory — consumed by policy consistency tests.
///
/// Keep aligned with privacy screen copy, iOS PrivacyInfo.xcprivacy, Android
/// Data Safety documentation, and [V1CapabilityRegistry].
abstract final class PrivacyInventory {
  PrivacyInventory._();

  static const int schemaVersion = 1;

  static const Map<String, dynamic> document = {
    'schemaVersion': schemaVersion,
    'product': 'ArchiveMe Flutter mobile (V1)',
    'onDevice': {
      'journalEncryptedAtRest': true,
      'prefsEncryptedWhenEnabled': true,
      'recoveryAudioLocalOnlyUntilConsented': true,
      'encryptionKeyStorage': 'platform_secure_storage',
    },
    'remoteProcessing': {
      'requiresExplicitAccountScopedConsent': true,
      'consentStore': 'remote_processing_consent_v1',
      'categories': ['transcription', 'reflection_analysis'],
      'recoveryNeverBypassesConsent': true,
    },
    'sync': {
      'protocol': '/api/sync/manifest,/api/sync/pull,/api/sync/push',
      'journalTransport': 'encrypted_blob_only',
      'serverCanDecryptJournal': false,
      'legacyPlaintextMigration':
          'client_side_encrypt_then_mark_eligible_for_audit_deletion',
    },
    'analytics': {
      'includesJournalBodyText': false,
      'includesRawTranscripts': false,
      'includesFullFilesystemPathsInReleaseLogs': false,
    },
    'providers': {
      'transcription': 'cloud_speech_to_text',
      'reflectionAnalysis': 'cloud_llm',
      'billing': 'revenuecat_and_store',
      'crashDiagnostics': 'none_in_v1_release',
      'firebasePush': 'disabled_v1',
    },
    'retention': {
      'localUntilUserDeletes': true,
      'serverEncryptedBlobsUntilAccountDeletion': true,
      'legacyPlaintextDeletedOnlyAfterAuditedMigration': true,
    },
    'userControls': {
      'export': true,
      'localDeletion': true,
      'serverAccountDeletion': true,
      'consentWithdrawal': true,
      'subscriptionCancellationViaStore': true,
    },
    'nativePermissionsV1': {
      'microphone': true,
      'biometricLock': true,
      'internet': true,
      'notifications': false,
      'speechRecognition': true,
      'backgroundProcessing': false,
    },
  };
}