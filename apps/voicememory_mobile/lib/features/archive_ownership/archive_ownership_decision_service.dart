import 'dart:convert';

import '../../models/journal_entry.dart';
import '../../storage/journal_store.dart';
import '../../storage/secure_storage.dart';
import 'local_archive_identity.dart';

/// What the user chose to do with content this account has never owned.
enum ArchiveOwnershipDecision {
  undecided,
  keepSeparate,
  moveToAccount,
  deleted,
}

/// Progress of a "Move to this account" migration.
enum ArchiveMigrationState { none, preparing, copying, committed, failed }

/// Safe, countable description of unclaimed content. Never carries transcript
/// text, so it can be shown on a decision screen without leaking the content
/// the user has not yet agreed to associate with this account.
class UnclaimedArchiveSummary {
  const UnclaimedArchiveSummary({
    required this.sourceArchiveId,
    required this.ownerKind,
    required this.momentCount,
    required this.earliestAt,
    required this.latestAt,
  });

  final String sourceArchiveId;
  final LocalArchiveOwnerKind ownerKind;
  final int momentCount;
  final DateTime? earliestAt;
  final DateTime? latestAt;

  static const prompt =
      'This device contains private saved moments. They have not been added '
      'to this account.';
}

class ArchiveMigrationRecord {
  const ArchiveMigrationRecord({
    required this.sourceArchiveId,
    required this.targetArchiveId,
    required this.state,
    required this.migratedEntryIds,
  });

  final String sourceArchiveId;
  final String targetArchiveId;
  final ArchiveMigrationState state;
  final List<String> migratedEntryIds;

  bool get isResumable =>
      state == ArchiveMigrationState.preparing ||
      state == ArchiveMigrationState.copying;

  Map<String, Object?> toJson() => {
    'sourceArchiveId': sourceArchiveId,
    'targetArchiveId': targetArchiveId,
    'state': state.name,
    'migratedEntryIds': migratedEntryIds,
  };

  static ArchiveMigrationRecord? fromJson(Object? value) {
    if (value is! Map) return null;
    final json = Map<String, dynamic>.from(value);
    final source = json['sourceArchiveId']?.toString() ?? '';
    final target = json['targetArchiveId']?.toString() ?? '';
    final state = ArchiveMigrationState.values
        .where((item) => item.name == json['state'])
        .firstOrNull;
    if (source.isEmpty || target.isEmpty || state == null) return null;
    return ArchiveMigrationRecord(
      sourceArchiveId: source,
      targetArchiveId: target,
      state: state,
      migratedEntryIds: (json['migratedEntryIds'] as List? ?? const [])
          .map((item) => item.toString())
          .toList(growable: false),
    );
  }
}

class ArchiveMigrationResult {
  const ArchiveMigrationResult({
    required this.migratedCount,
    required this.alreadyPresentCount,
    required this.state,
  });

  final int migratedCount;
  final int alreadyPresentCount;
  final ArchiveMigrationState state;

  bool get committed => state == ArchiveMigrationState.committed;
}

typedef ArchiveStoreOpener =
    Future<JournalStore> Function(LocalArchiveIdentity identity);

/// Decides what happens to guest or legacy content when an account signs in.
///
/// Nothing is claimed automatically. Until the user answers, unclaimed content
/// stays in its own archive, is not rendered under the account, and cannot be
/// synced. Content that already belongs to a *different authenticated account*
/// is never offered here at all.
class ArchiveOwnershipDecisionService {
  ArchiveOwnershipDecisionService({
    required SecureStorageService secure,
    required ArchiveStoreOpener openStore,
  }) : _secure = secure,
       _openStore = openStore;

  static const _decisionPrefix = 'archive_ownership_decision_v1_';
  static const _migrationKey = 'archive_ownership_migration_v1';

  final SecureStorageService _secure;
  final ArchiveStoreOpener _openStore;

  /// Only ownerless content can be offered. Another account's archive is not a
  /// candidate under any circumstances.
  static bool isClaimable(LocalArchiveIdentity identity) =>
      identity.ownerKind == LocalArchiveOwnerKind.guest ||
      identity.ownerKind == LocalArchiveOwnerKind.legacyUnclaimed;

  Future<ArchiveOwnershipDecision> decisionFor(String sourceArchiveId) async {
    final raw = await _secure.read('$_decisionPrefix$sourceArchiveId');
    return ArchiveOwnershipDecision.values
            .where((item) => item.name == raw)
            .firstOrNull ??
        ArchiveOwnershipDecision.undecided;
  }

  /// The decision the user still owes, or null when nothing is pending.
  Future<UnclaimedArchiveSummary?> pendingDecision({
    required LocalArchiveIdentity account,
    required LocalArchiveIdentity candidate,
  }) async {
    if (account.ownerKind != LocalArchiveOwnerKind.authenticated) return null;
    if (!isClaimable(candidate)) return null;
    if (candidate.archiveId == account.archiveId) return null;
    if (await decisionFor(candidate.archiveId) !=
        ArchiveOwnershipDecision.undecided) {
      return null;
    }
    final store = await _openStore(candidate);
    final entries = await store.loadAll();
    if (entries.isEmpty) return null;
    final dates = entries.map((entry) => entry.createdAt).toList()..sort();
    return UnclaimedArchiveSummary(
      sourceArchiveId: candidate.archiveId,
      ownerKind: candidate.ownerKind,
      momentCount: entries.length,
      earliestAt: dates.first,
      latestAt: dates.last,
    );
  }

  Future<void> keepSeparate(String sourceArchiveId) =>
      _writeDecision(sourceArchiveId, ArchiveOwnershipDecision.keepSeparate);

  /// Plain JSON of the unclaimed archive so the user can take it elsewhere
  /// without first associating it with this account.
  Future<String> exportUnclaimed(LocalArchiveIdentity candidate) async {
    _requireClaimable(candidate);
    final store = await _openStore(candidate);
    return store.exportJson();
  }

  Future<void> deleteUnclaimed(LocalArchiveIdentity candidate) async {
    _requireClaimable(candidate);
    final store = await _openStore(candidate);
    await store.clearAll();
    await _writeDecision(candidate.archiveId, ArchiveOwnershipDecision.deleted);
  }

  /// Moves every unclaimed moment into [account].
  ///
  /// Migration is idempotent by entry ID, records progress before it copies,
  /// and only marks the source decided once the target write has committed. An
  /// interrupted run resumes without producing duplicates, and a failure
  /// leaves the source archive intact and undecided.
  Future<ArchiveMigrationResult> moveToAccount({
    required LocalArchiveIdentity account,
    required LocalArchiveIdentity candidate,
    required bool confirmed,
  }) async {
    if (!confirmed) {
      throw StateError('Moving saved moments requires explicit confirmation.');
    }
    if (account.ownerKind != LocalArchiveOwnerKind.authenticated) {
      throw StateError('Only an authenticated account can adopt an archive.');
    }
    _requireClaimable(candidate);

    await _writeMigration(
      ArchiveMigrationRecord(
        sourceArchiveId: candidate.archiveId,
        targetArchiveId: account.archiveId,
        state: ArchiveMigrationState.preparing,
        migratedEntryIds: const [],
      ),
    );

    try {
      final source = await _openStore(candidate);
      final target = await _openStore(account);
      final sourceEntries = await source.loadAll(includeDeleted: true);
      final existingIds = (await target.loadAll(
        includeDeleted: true,
      )).map((entry) => entry.id).toSet();

      final migrated = <String>[];
      var alreadyPresent = 0;
      for (final entry in sourceEntries) {
        if (existingIds.contains(entry.id)) {
          alreadyPresent++;
          continue;
        }
        await _writeMigration(
          ArchiveMigrationRecord(
            sourceArchiveId: candidate.archiveId,
            targetArchiveId: account.archiveId,
            state: ArchiveMigrationState.copying,
            migratedEntryIds: migrated,
          ),
        );
        // Source dates, evidence IDs, audio references and feedback are
        // carried across untouched; only ownership changes.
        await target.save(_reowned(entry, account.archiveId));
        migrated.add(entry.id);
      }

      await source.clearAll();
      await _writeMigration(
        ArchiveMigrationRecord(
          sourceArchiveId: candidate.archiveId,
          targetArchiveId: account.archiveId,
          state: ArchiveMigrationState.committed,
          migratedEntryIds: migrated,
        ),
      );
      await _writeDecision(
        candidate.archiveId,
        ArchiveOwnershipDecision.moveToAccount,
      );
      return ArchiveMigrationResult(
        migratedCount: migrated.length,
        alreadyPresentCount: alreadyPresent,
        state: ArchiveMigrationState.committed,
      );
    } on Object {
      await _writeMigration(
        ArchiveMigrationRecord(
          sourceArchiveId: candidate.archiveId,
          targetArchiveId: account.archiveId,
          state: ArchiveMigrationState.failed,
          migratedEntryIds: const [],
        ),
      );
      rethrow;
    }
  }

  Future<ArchiveMigrationRecord?> pendingMigration() async {
    final raw = await _secure.read(_migrationKey);
    if (raw == null) return null;
    try {
      final record = ArchiveMigrationRecord.fromJson(jsonDecode(raw));
      return record?.isResumable == true ? record : null;
    } on FormatException {
      return null;
    }
  }

  /// Sync must stay closed while ownership is unsettled.
  Future<bool> mayResumeSync(LocalArchiveIdentity account) async {
    if (!account.maySync) return false;
    return (await pendingMigration()) == null;
  }

  static JournalEntry _reowned(JournalEntry entry, String archiveId) =>
      entry.copyWith(ownerArchiveId: archiveId);

  void _requireClaimable(LocalArchiveIdentity candidate) {
    if (!isClaimable(candidate)) {
      throw StateError(
        'Archive ${candidate.archiveId} belongs to another account and can '
        'never be offered for claiming.',
      );
    }
  }

  Future<void> _writeDecision(
    String sourceArchiveId,
    ArchiveOwnershipDecision decision,
  ) => _secure.write('$_decisionPrefix$sourceArchiveId', decision.name);

  Future<void> _writeMigration(ArchiveMigrationRecord record) =>
      _secure.write(_migrationKey, jsonEncode(record.toJson()));
}
