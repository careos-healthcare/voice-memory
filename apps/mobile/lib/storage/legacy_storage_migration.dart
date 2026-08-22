import 'dart:convert';
import 'dart:io';

import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/storage/account_namespace.dart';
import 'package:archiveme_mobile/storage/journal_store.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:archiveme_mobile/storage/private_data_encryption_key_store.dart';
import 'package:archiveme_mobile/storage/secure_storage.dart';
import 'package:flutter/foundation.dart';

/// Outcome of a single [LegacyStorageMigration.migrateIfNeeded] call.
class LegacyMigrationReport {
  const LegacyMigrationReport({
    required this.ran,
    required this.journalEntriesMigrated,
    required this.namespace,
  });

  /// True if this call actually performed (or re-performed) the relocation.
  /// False means either there was nothing legacy to relocate, or this
  /// namespace already completed the migration on a previous run.
  final bool ran;

  /// Number of journal entries (including tombstones) copied into the
  /// namespaced journal file. Zero if there was no legacy journal file.
  final int journalEntriesMigrated;

  final AccountNamespace namespace;

  @override
  String toString() =>
      'LegacyMigrationReport(ran: $ran, journalEntriesMigrated: '
      '$journalEntriesMigrated, namespace: ${namespace.key})';
}

/// One-time, idempotent relocation of the pre-namespacing shared on-disk
/// files — `journal_entries.json`/`.enc`, `mobile_prefs.json`,
/// `entitlements.json`, all directly under the app's documents directory —
/// into a per-account namespace directory (`accounts/<namespaceKey>/...`).
///
/// This exists purely so an identity that already had data on this device
/// *before* per-account namespacing shipped keeps seeing that data after the
/// upgrade — it is not the guest→account "should I import this?" decision
/// (see `AccountDataMigrationCoordinator` for that, a separate, later,
/// user-facing feature). This module never asks the user anything; it only
/// ever relocates a single identity's own prior data into its own new home.
///
/// ## Version marker
/// [currentVersion] is stamped into the *destination* namespace's own prefs
/// file under [versionPrefsKey] once migration for that namespace completes
/// successfully. Bump [currentVersion] if the migration logic itself ever
/// changes in a way that requires previously-migrated namespaces to be
/// reconsidered.
///
/// ## Preflight validation
/// Before doing anything, the three legacy files are checked for existence.
/// If none exist, this is a fresh namespace with nothing to relocate and the
/// call is a cheap no-op (the version marker is deliberately *not* stamped
/// in this case, so a legacy file appearing later — e.g. a stale write from
/// an in-flight upgrade — is still picked up on a subsequent call).
///
/// ## Atomic writes
/// The non-journal files (`mobile_prefs.json`, `entitlements.json`) are
/// written via a temp-file-then-rename so a reader (or a crash) never
/// observes a partially-written destination file. The journal file's
/// atomicity is provided by [JournalStore] itself (it already writes via
/// `EncryptedJsonFileStore`, which is not touched here).
///
/// ## Crash recovery / idempotency
/// The **only** signal this module trusts for "is this namespace already
/// migrated" is the version marker in the destination's own prefs — never
/// file-existence of the destination files, since a previous attempt could
/// have crashed after creating (but not fully populating, or not stamping)
/// those files. Every step below is safe to redo from scratch:
/// - Journal: [JournalStore.replaceAll] wholesale-replaces the destination
///   entries, so re-running with the same legacy source is a no-op change,
///   never a duplication.
/// - Prefs: legacy keys are merged into the destination using
///   put-if-absent semantics (a destination key that already exists — e.g.
///   written by a partially-completed previous attempt, or by the app
///   itself between attempts — is never clobbered), so re-running converges
///   rather than oscillates.
/// - Entitlements: a plain atomic overwrite of the destination from the
///   legacy source; entitlements are a fully-derived cache anyway (refreshed
///   from the server after sign-in), so redoing this is harmless.
/// The version marker is stamped **last**, after all three steps succeed —
/// so an interrupted migration always looks "not yet done" and safely redoes
/// on the next call rather than getting stuck half-migrated.
///
/// ## What happens to the old shared files
/// They are **left in place, untouched** — never deleted, never renamed.
/// Two reasons: (1) it keeps this module read-only with respect to the
/// legacy files, so a bug here can never destroy the only copy of a user's
/// data; (2) other namespaces (e.g. a second account that later signs in on
/// the same device, or the guest namespace) may still need to read those
/// same legacy files as *their own* relocation source the first time *they*
/// run this migration. Once every namespace that could plausibly need them
/// has migrated, the legacy files are simply inert and harmless to leave
/// behind; a future cleanup pass could safely delete them once all known
/// namespaces report `ran: false` with the marker present, but that cleanup
/// is out of scope here.
///
/// ## Diagnostics
/// [migrateIfNeeded] only ever logs entry *counts* and the (opaque, already
/// non-identifying) namespace key — never transcript content or any other
/// entry field.
abstract class LegacyStorageMigration {
  LegacyStorageMigration._();

  static const currentVersion = 1;
  static const versionPrefsKey = 'legacyStorageMigrationVersion';

  static Future<LegacyMigrationReport> migrateIfNeeded({
    required String base,
    required AccountNamespace namespace,
    SecureStorageService? secureStorage,
    // The signed-in account this [namespace] belongs to, when known — used
    // *only* in-memory to filter which legacy entries are safe to relocate
    // into this namespace (see `_migrateJournal`); never persisted or
    // logged. Omit for the guest namespace (there is no account to filter
    // by) or when the caller genuinely does not know it yet.
    String? ownerUserId,
    // Test-only escape hatch: production always resolves the legacy key
    // via [SecureStorageService], which persists the same key across
    // however many times `JournalStore.open` is called for the legacy
    // path. Under `flutter test`, the default in-memory key store used
    // instead (see `JournalStore._defaultKeyStore`) is *not* shared across
    // separate `open()` calls, so a test that seeds a legacy file and then
    // exercises this migration in two separate calls needs to hand both
    // the same key store explicitly.
    PrivateDataEncryptionKeyStore? legacyKeyStoreForTest,
    PrivateDataEncryptionKeyStore? destKeyStoreForTest,
  }) async {
    final legacyPrefsFile = File('$base/mobile_prefs.json');
    final legacyEntitlementsFile = File('$base/entitlements.json');
    final legacyJournalPlaintext = File('$base/journal_entries.json');
    final legacyJournalEncrypted = File('$base/journal_entries.enc');

    final hasLegacyPrefs = await legacyPrefsFile.exists();
    final hasLegacyEntitlements = await legacyEntitlementsFile.exists();
    final hasLegacyJournal =
        await legacyJournalPlaintext.exists() ||
        await legacyJournalEncrypted.exists();

    if (!hasLegacyPrefs && !hasLegacyEntitlements && !hasLegacyJournal) {
      return LegacyMigrationReport(
        ran: false,
        journalEntriesMigrated: 0,
        namespace: namespace,
      );
    }

    final destDir = '$base/accounts/${namespace.key}';
    final destPrefsPath = '$destDir/mobile_prefs.json';
    final destEntitlementsPath = '$destDir/entitlements.json';
    final destJournalPath = '$destDir/journal_entries.json';

    // Opening the destination prefs file both creates the namespace
    // directory (idempotently) and gives us the single source of truth for
    // "has this namespace already completed this migration version".
    final destPrefs = await MobilePrefsStore.open(destPrefsPath);
    final existingVersion = int.tryParse(
      (await destPrefs.readString(versionPrefsKey)) ?? '',
    );
    if (existingVersion != null && existingVersion >= currentVersion) {
      return LegacyMigrationReport(
        ran: false,
        journalEntriesMigrated: 0,
        namespace: namespace,
      );
    }

    var journalEntriesMigrated = 0;
    if (hasLegacyJournal) {
      journalEntriesMigrated = await _migrateJournal(
        base: base,
        destJournalPath: destJournalPath,
        namespace: namespace,
        ownerUserId: ownerUserId,
        secureStorage: secureStorage,
        legacyKeyStoreForTest: legacyKeyStoreForTest,
        destKeyStoreForTest: destKeyStoreForTest,
      );
    }

    if (hasLegacyPrefs) {
      await _mergeLegacyPrefsIntoDestination(
        legacyPrefsFile: legacyPrefsFile,
        destPrefs: destPrefs,
      );
    }

    if (hasLegacyEntitlements) {
      await _atomicCopy(legacyEntitlementsFile, File(destEntitlementsPath));
    }

    // Stamped last and deliberately overwrites whatever was there —
    // completion is binary, not incremental.
    await destPrefs.writeString(versionPrefsKey, '$currentVersion');

    AppLogger.debug(
      'LegacyStorageMigration: relocated legacy storage into namespace '
      '${namespace.key} (journalEntries=$journalEntriesMigrated, '
      'prefs=$hasLegacyPrefs, entitlements=$hasLegacyEntitlements)',
    );

    return LegacyMigrationReport(
      ran: true,
      journalEntriesMigrated: journalEntriesMigrated,
      namespace: namespace,
    );
  }

  static Future<int> _migrateJournal({
    required String base,
    required String destJournalPath,
    required AccountNamespace namespace,
    String? ownerUserId,
    SecureStorageService? secureStorage,
    PrivateDataEncryptionKeyStore? legacyKeyStoreForTest,
    PrivateDataEncryptionKeyStore? destKeyStoreForTest,
  }) async {
    final legacyStore = await JournalStore.open(
      '$base/journal_entries.json',
      secureStorage: secureStorage,
      keyStore: legacyKeyStoreForTest,
    );
    final legacyEntries = await legacyStore.loadAllIncludingTombstones();

    // The pre-namespacing journal was a single file shared by every account
    // that ever signed in on this device (`JournalOwnershipGuard`'s ownerKey
    // stamp was, until now, only ever enforced at *sync* time — never at
    // local-storage time). Relocating the file verbatim into every namespace
    // that happens to migrate would hand each account's private entries to
    // every other account that later signs in on the same device: a direct
    // violation of the isolation this namespacing work exists to provide.
    // An entry is only ever relocated into [namespace] when it plausibly
    // belongs there: it is unowned (predates ownership stamping, or was
    // created while signed out — the same "no conflict recorded yet, so
    // trust it" rule `JournalOwnershipGuard.reconcile` already applied), or
    // its `ownerKey` matches [ownerUserId] exactly. An entry stamped with a
    // *different* account's id is left behind in the legacy file, untouched,
    // exactly as before.
    final migratable = legacyEntries
        .where((e) => e.ownerKey == null || e.ownerKey == ownerUserId)
        .toList();

    final destStore = await JournalStore.open(
      destJournalPath,
      secureStorage: secureStorage,
      keyAlias: namespace.key,
      keyStore: destKeyStoreForTest,
    );
    await destStore.replaceAll(migratable);

    final verify = await destStore.loadAllIncludingTombstones();
    final migratableIds = migratable.map((e) => e.id).toSet();
    final verifyIds = verify.map((e) => e.id).toSet();
    if (verify.length != migratable.length ||
        migratableIds.length != verifyIds.length ||
        !migratableIds.containsAll(verifyIds)) {
      throw StateError(
        'LegacyStorageMigration: journal verification failed for namespace '
        '${namespace.key} — expected ${migratable.length} entries, '
        'found ${verify.length} after write-back.',
      );
    }
    return migratable.length;
  }

  static Future<void> _mergeLegacyPrefsIntoDestination({
    required File legacyPrefsFile,
    required MobilePrefsStore destPrefs,
  }) async {
    Map<String, dynamic> legacyMap;
    try {
      final raw = await legacyPrefsFile.readAsString();
      legacyMap = raw.trim().isEmpty
          ? <String, dynamic>{}
          : jsonDecode(raw) as Map<String, dynamic>;
    } catch (_, stackTrace) { // ignore: silent_catch_audit — legacy migration best-effort cleanup
      // Corrupt legacy prefs — nothing safe to relocate, but this must not
      // block journal/entitlements migration or crash the app.
      return;
    }
    if (legacyMap.isEmpty) return;

    for (final entry in legacyMap.entries) {
      if (entry.key == versionPrefsKey) continue;
      final existing = await destPrefs.readJsonMap(entry.key);
      if (existing != null) continue;
      final existingString = await destPrefs.readString(entry.key);
      if (existingString != null) continue;
      final existingBool = await destPrefs.readBool(entry.key);
      if (existingBool != null) continue;
      final value = entry.value;
      if (value is Map) {
        await destPrefs.writeJsonMap(
          entry.key,
          Map<String, dynamic>.from(value),
        );
      } else if (value is bool) {
        await destPrefs.writeBool(entry.key, value);
      } else if (value is String) {
        await destPrefs.writeString(entry.key, value);
      }
      // Other legacy value shapes (lists, numbers) predate namespacing and
      // are not part of any currently-known prefs key; skipped rather than
      // guessed at.
    }
  }

  static Future<void> _atomicCopy(File source, File destination) async {
    if (!await destination.parent.exists()) {
      await destination.parent.create(recursive: true);
    }
    final bytes = await source.readAsBytes();
    final tmp = File('${destination.path}.tmp');
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(destination.path);
  }
}