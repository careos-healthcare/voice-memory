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
      backend: 'json_file',
      sensitive: true,
      encrypted: false,
      notes: 'journal_entries.json in app documents — plaintext JSON',
    ),
    PrivateStorageAuditReport(
      store: 'MobilePrefsStore',
      backend: 'json_file',
      sensitive: true,
      encrypted: false,
      notes: 'mobile_prefs.json — archive metadata and cached insights',
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
      backend: 'temp_file',
      sensitive: true,
      encrypted: false,
      notes: 'vm_rec_*.m4a under system temp; paths referenced on entries',
    ),
    PrivateStorageAuditReport(
      store: 'OfflineDrafts',
      backend: 'json_file',
      sensitive: true,
      encrypted: false,
      notes: '[draft] entries in journal + localAudioPath',
    ),
    PrivateStorageAuditReport(
      store: 'ArchiveFeatureStores',
      backend: 'json_file',
      sensitive: true,
      encrypted: false,
      notes: 'archive collections, packs, synthesis cache in MobilePrefsStore',
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
