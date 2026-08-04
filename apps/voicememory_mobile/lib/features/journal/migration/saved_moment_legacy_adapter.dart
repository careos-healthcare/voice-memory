/// Read-only, one-way adapter for journal payloads written before the V1
/// saved-moment aggregate. Canonical payloads are never converted back.
abstract final class SavedMomentLegacyAdapter {
  static const adapterId = 'journal_entry_to_saved_moment_v1';
  static const canonicalSchemaVersion = 2;

  /// The owner value written before archives existed. A row carrying this
  /// value has no real owner yet and may be adopted by the archive that opens
  /// it. Any other value names a real archive and is never rewritten.
  static const legacyUnscopedArchiveId = 'local';

  /// True when [payload] names an archive other than [ownerArchiveId].
  ///
  /// Adoption is deliberately one-way and only from the ownerless legacy
  /// sentinel. Re-stamping an owned row would let whichever account happens to
  /// be signed in take over another account's saved moments.
  static bool belongsToAnotherArchive(
    Map<String, dynamic> payload, {
    required String ownerArchiveId,
  }) {
    final declared = payload['ownerArchiveId']?.toString().trim() ?? '';
    if (declared.isEmpty || declared == legacyUnscopedArchiveId) return false;
    return declared != ownerArchiveId;
  }

  static Map<String, dynamic> migrate(
    Map<String, dynamic> legacy, {
    required String ownerArchiveId,
    required DateTime migratedAt,
  }) {
    if (belongsToAnotherArchive(legacy, ownerArchiveId: ownerArchiveId)) {
      return Map<String, dynamic>.from(legacy);
    }
    if ((legacy['schemaVersion'] as num?)?.toInt() == canonicalSchemaVersion &&
        legacy['ownerArchiveId'] == ownerArchiveId) {
      return Map<String, dynamic>.from(legacy);
    }
    final createdAt =
        DateTime.tryParse(legacy['createdAt']?.toString() ?? '')?.toUtc() ??
        migratedAt.toUtc();
    final serverUpdatedAt = DateTime.tryParse(
      legacy['_serverUpdatedAt']?.toString() ?? '',
    )?.toUtc();
    final hasAudio =
        legacy['localAudioVaultRef'] != null ||
        legacy['localAudioPath'] != null;
    return <String, dynamic>{
      ...legacy,
      'ownerArchiveId': ownerArchiveId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': (serverUpdatedAt ?? createdAt).toIso8601String(),
      'source': hasAudio ? 'voice' : 'migrated',
      'schemaVersion': canonicalSchemaVersion,
      'migration': {
        'fromSchemaVersion': (legacy['schemaVersion'] as num?)?.toInt() ?? 0,
        'migratedAt': migratedAt.toUtc().toIso8601String(),
        'adapter': adapterId,
      },
    };
  }
}
