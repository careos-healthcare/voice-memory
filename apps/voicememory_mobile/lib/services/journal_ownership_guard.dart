/// P0 fix — cross-account archive leakage.
///
/// The on-device journal is a single shared file; historically nothing
/// tagged which signed-in account owned an entry, so signing out (which
/// deliberately keeps the local journal on-device) followed by a different
/// account signing in on the same device let [SyncService] upload the first
/// account's entries under the second account's session.
///
/// Splitting the on-device store per-account is tracked separately (see
/// week-1 data-integrity roadmap). As an immediate stop-gap this guard makes
/// sure that once a different account is detected on a device, any entry not
/// stamped with the *currently* signed-in account's id is permanently
/// excluded from outgoing sync — nothing is deleted or merged across the
/// account switch.
class JournalOwnershipGuard {
  const JournalOwnershipGuard();

  /// [MobilePrefsStore] key: the account id that currently owns this
  /// device's on-device journal.
  static const String ownerKeyPrefsKey = 'journalOwnerKey';

  /// [MobilePrefsStore] key: whether an account switch has ever been
  /// detected on this device (see [OwnershipReconciliation.migrationPending]).
  static const String migrationPendingPrefsKey =
      'journalOwnershipMigrationPending';

  /// Called once per sign-in (including a persisted session resumed at
  /// startup). Compares the account signing in against whichever account
  /// last claimed this device's local journal.
  OwnershipReconciliation reconcile({
    required String? storedOwnerKey,
    required bool migrationPending,
    required String signedInUserId,
  }) {
    if (signedInUserId.isEmpty) {
      return OwnershipReconciliation(
        ownerKey: storedOwnerKey,
        migrationPending: migrationPending,
      );
    }

    if (storedOwnerKey == null) {
      // Nothing has ever claimed this device's journal — safe to claim it
      // for the account signing in now; there is no other account to
      // conflict with.
      return OwnershipReconciliation(
        ownerKey: signedInUserId,
        migrationPending: migrationPending,
      );
    }

    if (storedOwnerKey == signedInUserId) {
      // Same account signing back in — no reconciliation needed.
      return OwnershipReconciliation(
        ownerKey: storedOwnerKey,
        migrationPending: migrationPending,
      );
    }

    // A different account just signed in on a device that already has
    // another account's local entries. Record the switch; never let the two
    // accounts' entries merge or sync into one another automatically.
    return OwnershipReconciliation(
      ownerKey: signedInUserId,
      migrationPending: true,
    );
  }

  /// Whether an entry stamped with [entryOwnerKey] may be uploaded under
  /// [currentUserId]'s session right now.
  bool isEligibleForSync({
    required String? entryOwnerKey,
    required String currentUserId,
    required bool migrationPending,
  }) {
    if (currentUserId.isEmpty) return false;
    if (entryOwnerKey == currentUserId) return true;
    if (migrationPending) return false;
    // No account switch has ever been detected on this device, so legacy or
    // guest-created entries with no owner stamp are still trusted.
    return entryOwnerKey == null;
  }
}

class OwnershipReconciliation {
  const OwnershipReconciliation({
    required this.ownerKey,
    required this.migrationPending,
  });

  /// The owner key that should now be persisted for this device's journal.
  final String? ownerKey;

  /// True once an account switch has ever been detected on this device.
  /// Sticky by design: it only clears via an explicit local-data reset, not
  /// automatically, so a returning foreign account can never quietly start
  /// syncing again.
  final bool migrationPending;
}
