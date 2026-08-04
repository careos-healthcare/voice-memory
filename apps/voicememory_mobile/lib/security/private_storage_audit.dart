import 'package:flutter/foundation.dart';

/// Describes how a storage backend holds potentially sensitive data.
class PrivateStorageAuditReport {
  const PrivateStorageAuditReport({
    required this.store,
    required this.backend,
    required this.sensitive,
    required this.encrypted,
    this.notes,
  });

  final String store;
  final String backend;
  final bool sensitive;
  final bool encrypted;
  final String? notes;
}

/// Read-only audit of where private archive data lives on device.
/// Never logs user text — only store names and encryption status.
abstract class PrivateStorageAudit {
  PrivateStorageAudit._();

  static const String logPrefix = 'ARCHIVEME_SECURITY_AUDIT:';

  /// Known storage backends in ArchiveMe.
  static List<PrivateStorageAuditReport> knownStores() => const [
    PrivateStorageAuditReport(
      store: 'JournalStore',
      backend: 'encrypted_json_file',
      sensitive: true,
      encrypted: true,
      notes: 'journal_entries.enc — AES-256-GCM; key in flutter_secure_storage',
    ),
    PrivateStorageAuditReport(
      store: 'MobilePrefsStore',
      backend: 'flutter_secure_storage',
      sensitive: true,
      encrypted: true,
      notes: 'archive metadata and cached insights; plaintext file migrated',
    ),
    PrivateStorageAuditReport(
      store: 'EntitlementCache',
      backend: 'json_file',
      sensitive: false,
      encrypted: false,
      notes: 'entitlements.json — billing tier only',
    ),
    PrivateStorageAuditReport(
      store: 'SecureStorageService',
      backend: 'flutter_secure_storage',
      sensitive: true,
      encrypted: true,
      notes: 'session cookie, device id, app lock credentials',
    ),
    PrivateStorageAuditReport(
      store: 'AppLockStore',
      backend: 'flutter_secure_storage',
      sensitive: true,
      encrypted: true,
      notes: 'PIN hash + salt only — never raw PIN',
    ),
    PrivateStorageAuditReport(
      store: 'CaptureTokenCache',
      backend: 'in_memory',
      sensitive: true,
      encrypted: false,
      notes: 'capture token — not persisted',
    ),
    PrivateStorageAuditReport(
      store: 'VoiceRecordings',
      backend: 'authenticated_encrypted_audio_vault',
      sensitive: true,
      encrypted: true,
      notes:
          'Retained audio uses chunked AES-256-GCM with opaque references; '
          'keys remain in platform secure storage',
    ),
    PrivateStorageAuditReport(
      store: 'ActiveCaptureWorkingFiles',
      backend: 'private_temporary_file',
      sensitive: true,
      encrypted: false,
      notes:
          'Plaintext exists only during active capture or a scoped decrypt lease; '
          'it is never referenced by new journal metadata',
    ),
    PrivateStorageAuditReport(
      store: 'OfflineDrafts',
      backend: 'encrypted_json_file',
      sensitive: true,
      encrypted: true,
      notes:
          '[draft] entries in encrypted journal + AES-256-GCM encrypted audio vault references',
    ),
    PrivateStorageAuditReport(
      store: 'TranscriptionLedger',
      backend: 'encrypted_audio_file_store',
      sensitive: true,
      encrypted: true,
      notes:
          'queued audio is authenticated ciphertext; scoped .working files are securely deleted',
    ),
    PrivateStorageAuditReport(
      store: 'CaptureApiRetryQueue',
      backend: 'encrypted_json_file',
      sensitive: true,
      encrypted: true,
      notes:
          'new transcription retries retain opaque journal audio vault references only',
    ),
    PrivateStorageAuditReport(
      store: 'EmergencyVaultStorage',
      backend: 'private_application_support_staging',
      sensitive: true,
      encrypted: false,
      notes:
          'short-lived crash-recovery PCM chunks; acknowledged chunks and privacy wipes delete them',
    ),
    PrivateStorageAuditReport(
      store: 'ArchiveFeatureStores',
      backend: 'flutter_secure_storage',
      sensitive: true,
      encrypted: true,
      notes: 'archive collections, packs, synthesis cache in MobilePrefsStore',
    ),
    PrivateStorageAuditReport(
      store: 'OnDeviceModelWeights',
      backend: 'application_support_file',
      sensitive: false,
      encrypted: false,
      notes:
          'llm_models/*/model.gguf — plaintext third-party model weights; '
          'excluded from backup; contains no user or archive data',
    ),
  ];

  static List<PrivateStorageAuditReport> sensitivePlaintextStores() =>
      knownStores().where((r) => r.sensitive && !r.encrypted).toList();

  /// Debug-only audit log — one line per store, no user content.
  static void logAuditReport() {
    if (!kDebugMode) return;
    for (final report in knownStores()) {
      debugPrint(
        '$logPrefix storage=${report.store} '
        'backend=${report.backend} '
        'sensitive=${report.sensitive} '
        'encrypted=${report.encrypted}'
        '${report.notes == null ? '' : ' notes=${report.notes}'}',
      );
    }
    debugPrint(
      '$logPrefix summary '
      'sensitivePlaintextCount=${sensitivePlaintextStores().length}',
    );
  }
}
