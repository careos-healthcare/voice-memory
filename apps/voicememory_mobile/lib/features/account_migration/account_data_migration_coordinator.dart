import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

import '../../security/private_data_service.dart';
import '../../services/app_services.dart';
import '../../storage/account_namespace.dart';
import '../../storage/journal_store.dart';
import '../../storage/mobile_prefs_store.dart';
import '../../storage/secure_storage.dart';

/// Outcome of one [AccountDataMigrationCoordinator.migrateGuestDataIntoActiveAccount]
/// call.
enum MigrationOutcome {
  /// Guest entries were copied into the active account for the first time.
  migrated,

  /// A previous call already completed this exact [migrationId] — this
  /// call was a no-op that just returned the persisted prior result.
  alreadyMigrated,

  /// The guest namespace had nothing to copy.
  noGuestData,

  /// The active namespace *is* the guest namespace — migrating guest data
  /// "into" itself is meaningless, so nothing happened.
  notApplicable,
}

class MigrationResult {
  const MigrationResult({required this.outcome, required this.entriesCopied});

  final MigrationOutcome outcome;
  final int entriesCopied;

  bool get succeeded =>
      outcome == MigrationOutcome.migrated ||
      outcome == MigrationOutcome.alreadyMigrated;

  Map<String, dynamic> toJson() => {
    'outcome': outcome.name,
    'entriesCopied': entriesCopied,
  };

  factory MigrationResult.fromJson(Map<String, dynamic> json) {
    final outcomeName = json['outcome'] as String?;
    return MigrationResult(
      outcome: MigrationOutcome.values.firstWhere(
        (o) => o.name == outcomeName,
        orElse: () => MigrationOutcome.migrated,
      ),
      entriesCopied: (json['entriesCopied'] as num?)?.toInt() ?? 0,
    );
  }

  @override
  String toString() =>
      'MigrationResult(outcome: $outcome, entriesCopied: $entriesCopied)';
}

/// Offers a signed-in user the choice to bring data they created while
/// signed out (the guest namespace) into their now-active account
/// namespace.
///
/// This is a **separate, later, user-facing decision** from
/// `LegacyStorageMigration` (which silently relocates one identity's own
/// pre-namespacing data with no user choice involved) — this class always
/// asks first, or at minimum makes an explicit, persisted, re-visitable
/// choice.
///
/// ## Why there is no "source namespace" parameter
/// The source is *always* [AccountNamespace.guest] — hardcoded, not passed
/// in by any caller. This is deliberate and is the primary safety property
/// of this class: it makes migrating one signed-in account's data into a
/// *different* signed-in account structurally impossible to express through
/// this API, rather than merely guarded by a runtime check. There is
/// nothing to bypass because there is no parameter to bypass.
class AccountDataMigrationCoordinator {
  AccountDataMigrationCoordinator({
    required this.guestJournalStore,
    required this.activeJournalStore,
    required this.activePrefs,
    required this.activeNamespace,
  });

  final JournalStore guestJournalStore;
  final JournalStore activeJournalStore;
  final MobilePrefsStore activePrefs;

  /// The destination namespace this coordinator migrates guest data *into*.
  /// Safe to expose publicly — unlike a source namespace parameter (which
  /// deliberately does not exist on this class, see the class doc), knowing
  /// the destination carries none of the cross-account risk this class
  /// exists to prevent.
  final AccountNamespace activeNamespace;

  static const _decisionPrefsKey = 'guestMigrationDecision';
  static const _decisionKeptSeparate = 'kept_separate';
  static const _resultPrefsKeyPrefix = 'guestMigrationResult_';

  /// Builds a coordinator wired against [AppServices.instance]'s currently
  /// active account namespace, opening a dedicated read/write handle onto
  /// the guest namespace's own journal (independent of whichever namespace
  /// is presently active — the guest namespace need not be, and normally
  /// is not, the active one when this runs).
  static Future<AccountDataMigrationCoordinator> forActiveAccount({
    SecureStorageService? secureStorage,
  }) async {
    final services = AppServices.instance;
    final base = services.documentsBasePath;
    final guestStore = await JournalStore.open(
      '$base/accounts/${AccountNamespace.guest.key}/journal_entries.json',
      secureStorage: secureStorage ?? services.secureStorage,
      keyAlias: AccountNamespace.guest.key,
      // Mirrors `AppServices._openNamespacedStores`'s own choice: under
      // `flutter test` there is no platform secure-storage plugin, so the
      // default in-memory key store mints a fresh random key on every
      // `open()` call rather than persisting one per alias — encrypting
      // here would make a second `open()` of this same guest path within
      // one test unable to decrypt what the first call wrote.
      encryptAtRest: !Platform.environment.containsKey('FLUTTER_TEST'),
    );
    return AccountDataMigrationCoordinator(
      guestJournalStore: guestStore,
      activeJournalStore: services.journalStore,
      activePrefs: services.prefs,
      activeNamespace: services.activeNamespace,
    );
  }

  /// Deterministic per guest→account pair, so the same pairing always
  /// resolves to the same idempotency key regardless of how many times the
  /// user signs in and out.
  static String deterministicMigrationId(AccountNamespace activeNamespace) {
    final digest = sha256.convert(utf8.encode('guest->${activeNamespace.key}'));
    return digest.toString();
  }

  /// True when there is guest data that plausibly hasn't been dealt with
  /// yet: the guest namespace has at least one entry, the active namespace
  /// is not itself the guest namespace, and the active namespace's own
  /// journal is still empty (the common "just signed in for the first time
  /// on this device" case this feature targets).
  Future<bool> hasMigratableGuestData() async {
    if (activeNamespace == AccountNamespace.guest) return false;
    final guestEntries = await guestJournalStore.loadAll();
    if (guestEntries.isEmpty) return false;
    final activeEntries = await activeJournalStore.loadAll();
    return activeEntries.isEmpty;
  }

  /// Whether the user already made (and persisted) a decision for this
  /// active namespace, so the prompt should not resurface. Returns `null`
  /// if no decision has ever been recorded here.
  Future<String?> recordedDecision() =>
      activePrefs.readString(_decisionPrefsKey);

  /// "Keep separate": guest data is left exactly where it is, untouched —
  /// this call does nothing except persist the choice so the migration
  /// prompt does not reappear for this active namespace.
  Future<void> recordKeptSeparateDecision() async {
    await activePrefs.writeString(_decisionPrefsKey, _decisionKeptSeparate);
  }

  /// Copies (never deletes) every guest entry, including tombstones, into
  /// the active account's journal. Idempotent via [migrationId]: a second
  /// call with the same id returns the first call's persisted result
  /// without copying anything again, so retrying after a crash or a
  /// duplicate user tap can never double-import.
  ///
  /// This alone is *not* a "Move" — the guest namespace is deliberately
  /// left intact after this returns, so a caller can verify the copy (e.g.
  /// re-read the active journal) before optionally calling
  /// [clearGuestDataAfterVerifiedMove] to complete a real move. A caller
  /// that instead wants "keep a copy in both places" simply never calls
  /// [clearGuestDataAfterVerifiedMove].
  Future<MigrationResult> migrateGuestDataIntoActiveAccount({
    required String migrationId,
  }) async {
    if (activeNamespace == AccountNamespace.guest) {
      return const MigrationResult(
        outcome: MigrationOutcome.notApplicable,
        entriesCopied: 0,
      );
    }

    final resultKey = '$_resultPrefsKeyPrefix$migrationId';
    final existing = await activePrefs.readJsonMap(resultKey);
    if (existing != null) {
      final prior = MigrationResult.fromJson(existing);
      return MigrationResult(
        outcome: prior.outcome == MigrationOutcome.migrated
            ? MigrationOutcome.alreadyMigrated
            : prior.outcome,
        entriesCopied: prior.entriesCopied,
      );
    }

    final guestEntries = await guestJournalStore.loadAllIncludingTombstones();
    if (guestEntries.isEmpty) {
      const result = MigrationResult(
        outcome: MigrationOutcome.noGuestData,
        entriesCopied: 0,
      );
      await activePrefs.writeJsonMap(resultKey, result.toJson());
      return result;
    }

    final activeEntries = await activeJournalStore.loadAllIncludingTombstones();
    final activeIds = activeEntries.map((e) => e.id).toSet();
    final merged = [
      ...activeEntries,
      ...guestEntries.where((g) => !activeIds.contains(g.id)),
    ];
    await activeJournalStore.replaceAll(merged);

    final verify = await activeJournalStore.loadAllIncludingTombstones();
    final expectedIds = {...activeIds, ...guestEntries.map((e) => e.id)};
    final verifyIds = verify.map((e) => e.id).toSet();
    if (verifyIds.length != expectedIds.length ||
        !verifyIds.containsAll(expectedIds)) {
      throw StateError(
        'AccountDataMigrationCoordinator: verification failed after copying '
        'guest data into namespace ${activeNamespace.key}.',
      );
    }

    final copiedCount = guestEntries
        .where((g) => !activeIds.contains(g.id))
        .length;
    final result = MigrationResult(
      outcome: MigrationOutcome.migrated,
      entriesCopied: copiedCount,
    );
    await activePrefs.writeJsonMap(resultKey, result.toJson());
    return result;
  }

  /// Completes a real "Move": clears the guest namespace's journal. Only
  /// ever call this *after* [migrateGuestDataIntoActiveAccount] has
  /// returned a successful result for the same data — this method itself
  /// does not re-verify anything, by design, so the caller controls
  /// exactly when the guest copy is considered safe to let go of.
  Future<void> clearGuestDataAfterVerifiedMove() async {
    await guestJournalStore.clearAll();
  }

  /// "Export first": produces a sanitized export of *only* the guest
  /// namespace's data (never the active account's), so the user can save a
  /// copy before deciding what to do with it. Reuses the existing sanitized
  /// export mechanism (see [PrivateDataService.buildSanitizedExport]).
  Future<ArchiveExportPayload> exportGuestData() {
    final exportService = PrivateDataService(journalStore: guestJournalStore);
    return exportService.buildSanitizedExport();
  }
}
