import 'dart:io';

import '../../auth/guest_first_auth.dart';
import '../../features/archive_ownership/archive_ownership_decision_service.dart';
import '../../features/archive_ownership/local_archive_identity.dart';
import '../auth_service.dart';
import 'core_services.dart';
import 'v1_composition_config.dart';

typedef AccountScopeResetter =
    Future<void> Function(LocalArchiveIdentity identity);

final class AccountServices {
  AccountServices._(
    this.auth,
    this._identityStore,
    this._legacyJournalPath,
    this._resetters,
    this._activeIdentity,
  );

  final AuthService auth;
  final LocalArchiveIdentityStore _identityStore;
  final String _legacyJournalPath;
  final List<AccountScopeResetter> _resetters;
  LocalArchiveIdentity _activeIdentity;
  bool _switching = false;

  String? get activeAccountId => _activeIdentity.authenticatedSubjectId;
  LocalArchiveIdentity get activeArchiveIdentity => _activeIdentity;

  static Future<AccountServices> create(
    CoreServices core,
    V1CompositionConfig config,
  ) async {
    final auth = AuthService(
      core.authApi,
      core.secureStorage,
      core.sessionCookies,
    );
    if (!config.testMode) {
      await auth.loadPersistedSession();
      await GuestFirstAuth(
        core.prefs,
      ).markGuestModeStartedIfNeeded(isSignedIn: auth.currentSession != null);
    }
    final legacyJournalPath =
        config.journalPath ?? '${config.basePath}/journal_entries.json';
    final identityStore = LocalArchiveIdentityStore(core.secureStorage);
    final identity = await identityStore.resolve(
      authenticatedSubjectId: auth.currentSession?.userId,
      legacyOwnerlessArchiveExists: await File(legacyJournalPath).exists(),
    );
    return AccountServices._(
      auth,
      identityStore,
      legacyJournalPath,
      <AccountScopeResetter>[],
      identity,
    );
  }

  void registerAccountScopedReset(AccountScopeResetter resetter) {
    if (_resetters.contains(resetter)) {
      throw StateError('Account-scoped resetter registered twice.');
    }
    _resetters.add(resetter);
  }

  void installAuthLifecycle() {
    auth.onSignedIn = () => resetAccountScope(auth.currentSession?.userId);
    auth.onSignedOut = () => resetAccountScope(null);
  }

  Future<void> adoptRecoveredArchive(String accountId, String archiveId) async {
    if (_switching ||
        !_activeIdentity.maySync ||
        _activeIdentity.authenticatedSubjectId != accountId) {
      throw StateError('Account changed during archive recovery.');
    }
    if (_activeIdentity.archiveId == archiveId) return;
    _switching = true;
    final previous = _activeIdentity;
    try {
      final recovered = await _identityStore.adoptAuthenticatedArchive(
        authenticatedSubjectId: accountId,
        archiveId: archiveId,
      );
      _activeIdentity = recovered;
      for (final resetter in _resetters) {
        await resetter(recovered);
      }
    } on Object {
      _activeIdentity = previous;
      await _identityStore.adoptAuthenticatedArchive(
        authenticatedSubjectId: accountId,
        archiveId: previous.archiveId,
      );
      rethrow;
    } finally {
      _switching = false;
    }
  }

  /// Account switch order: the new identity becomes authoritative *before*
  /// any module re-opens a store, so no resetter can briefly read the previous
  /// owner's scope while it rebuilds.
  Future<void> resetAccountScope(String? accountId) async {
    if (_switching) {
      throw StateError('Recursive account-scoped reset detected.');
    }
    _switching = true;
    final previous = _activeIdentity;
    try {
      final identity = await _identityStore.resolve(
        authenticatedSubjectId: accountId,
        legacyOwnerlessArchiveExists: await File(_legacyJournalPath).exists(),
      );
      _activeIdentity = identity;
      for (final resetter in _resetters) {
        await resetter(identity);
      }
    } on Object {
      _activeIdentity = previous;
      rethrow;
    } finally {
      _switching = false;
    }
  }

  /// Guest or legacy content this account has not been asked about yet.
  ///
  /// Returns null when there is nothing to decide. Nothing is ever claimed as
  /// a side effect of signing in.
  Future<UnclaimedArchiveSummary?> pendingOwnershipDecision(
    ArchiveOwnershipDecisionService decisions,
  ) async {
    final account = _activeIdentity;
    if (account.ownerKind != LocalArchiveOwnerKind.authenticated) return null;
    for (final candidate in await _identityStore.unclaimedArchives()) {
      final pending = await decisions.pendingDecision(
        account: account,
        candidate: candidate,
      );
      if (pending != null) return pending;
    }
    return null;
  }
}
