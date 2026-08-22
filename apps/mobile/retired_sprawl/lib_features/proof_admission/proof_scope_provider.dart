import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/account_namespace.dart';

/// Supplies the identity a piece of proof/evidence/correction state is
/// scoped to right now: which account namespace (or opaque guest identity)
/// and which archive. Production code must obtain scope from here — no
/// production constructor may silently fall back to a global constant
/// identity. Test-only code may still use fixed fixture scopes directly.
abstract class ProofScopeProvider {
  String get activeOwnerScope;
  String get activeArchiveScope;
}

/// The production [ProofScopeProvider]: derives both scopes from whichever
/// [AccountNamespace] `AppServices` currently has active.
///
/// The guest namespace keeps the exact legacy literals
/// (`'local_owner_v1'` / `'local_archive_v1'`) so evidence and corrections
/// already on disk from before per-account scoping existed keep resolving to
/// the same scope they were written under. A signed-in namespace gets its
/// own derived scope for both dimensions.
///
/// Both dimensions — not just the owner — vary by account. `ArchiveCorrection`
/// records (see `archive_correction.dart`) carry no owner field at all, so
/// `archiveScope` is the *only* axis that can isolate one account's
/// correction memory from another's; leaving it fixed across accounts would
/// mean `ArchiveCorrectionStore.switchArchive` — which no-ops when the scope
/// string does not actually change — would never fire on a real account
/// switch, and stale in-memory corrections from the outgoing account would
/// keep influencing confidence scoring for the incoming one. There is no
/// other "which archive" concept in this codebase (no multi-archive feature
/// per account), so `archiveScope` here is doing double duty as both "which
/// local archive" and "which account", and both must move together.
///
/// Falls back to the guest literals when `AppServices` has not been
/// initialized yet (e.g. a unit test constructing a service directly without
/// bringing up the whole app), matching the previous hardcoded behavior
/// exactly for anything that never wires up account namespacing at all.
class AppServicesProofScopeProvider implements ProofScopeProvider {
  const AppServicesProofScopeProvider();

  /// Matches the legacy `ProofDisplayGate.defaultOwnerScope` /
  /// `ArchiveCorrectionStore.defaultArchiveScope` literals exactly. Declared
  /// locally (rather than imported from those files) to avoid a needless
  /// import cycle; keeping the literal identical is what backward
  /// compatibility with existing on-disk guest data requires, not sharing the
  /// constant's storage location.
  static const String guestOwnerScope = 'local_owner_v1';
  static const String guestArchiveScope = 'local_archive_v1';

  static String ownerScopeForNamespace(AccountNamespace namespace) =>
      namespace == AccountNamespace.guest
      ? guestOwnerScope
      : 'account_${namespace.key}';

  static String archiveScopeForNamespace(AccountNamespace namespace) =>
      namespace == AccountNamespace.guest
      ? guestArchiveScope
      : 'account_${namespace.key}_archive';

  @override
  String get activeOwnerScope => AppServices.isInitialized
      ? ownerScopeForNamespace(AppServices.instance.activeNamespace)
      : guestOwnerScope;

  @override
  String get activeArchiveScope => AppServices.isInitialized
      ? archiveScopeForNamespace(AppServices.instance.activeNamespace)
      : guestArchiveScope;
}