import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter/foundation.dart';

/// Locally revoked consent token IDs — blocks verification after revoke.
///
/// This is the single owner of [prefsKey]. `features/consent_audit/` used to
/// declare a byte-identical copy of this class; because static fields are
/// per-class, the two copies kept separate `_revoked` sets while persisting
/// whole-set snapshots to the same key, so a revoke through one silently
/// dropped revocations recorded by the other. That file now re-exports this
/// one, and [_persist] unions with whatever is already on disk so a partial
/// in-memory view can never shrink the stored set.
///
/// Reads fail closed. A stored blob that cannot be parsed is not the same
/// thing as an empty revocation list, and treating it as one is how a revoked
/// caregiver gets back in — see [_readFailed].
abstract final class ConsentRevocationStore {
  ConsentRevocationStore._();

  static const prefsKey = 'consent_revoked_tokens_v1';

  static final Set<String> _revoked = <String>{};
  static bool _loaded = false;

  /// Set when the stored blob was present but could not be read.
  ///
  /// While this is set, [isRevoked] answers true for every token. The two
  /// failure directions are not symmetric: denying on a store we cannot read
  /// costs a caregiver access the user did grant, and the user can grant it
  /// again; allowing on a store we cannot read hands a caregiver whose access
  /// was *withdrawn* a silent way back in, which is the failure this store
  /// exists to prevent. Process-lifetime only — a later well-formed read on a
  /// fresh launch resumes normal service.
  static bool _readFailed = false;

  /// Test seam for the persistence path.
  ///
  /// Booting [AppServices] needs platform-channel mocks, which would put the
  /// read-merge-write behaviour below out of reach of a plain unit test — and
  /// that behaviour is the fix for a bug that silently reinstated revoked
  /// access, so it has to stay covered.
  @visibleForTesting
  static MobilePrefsStore? debugPrefsOverride;

  static MobilePrefsStore? get _prefs =>
      debugPrefsOverride ??
      (AppServices.isInitialized ? AppServices.instance.prefs : null);

  static Future<void> ensureLoaded() async {
    if (_loaded) return;
    final prefs = _prefs;
    if (prefs == null) {
      _loaded = true;
      return;
    }
    final read = await _readPersistedIds(prefs);
    _revoked.addAll(read.ids);
    if (read.malformed) _readFailed = true;
    _loaded = true;
  }

  /// Whether the last read of the stored blob failed, so nothing is trusted.
  @visibleForTesting
  static bool get readFailed => _readFailed;

  static bool isRevoked(String tokenId) =>
      _readFailed || _revoked.contains(tokenId);

  static Future<void> revoke(String tokenId) async {
    _revoked.add(tokenId);
    await _persist();
  }

  /// Reads, unions, then writes.
  ///
  /// [ensureLoaded] marks itself done without reading anything when no prefs
  /// store is available yet, so the in-memory set is not always a superset of
  /// the file. Writing `_revoked` alone would then erase every stored
  /// revocation — reinstating access a user had already withdrawn.
  static Future<void> _persist() async {
    final prefs = _prefs;
    if (prefs == null) return;
    final stored = await _readPersistedIds(prefs);
    if (stored.malformed) _readFailed = true;
    final merged = <String>{...stored.ids, ..._revoked};
    _revoked.addAll(merged);
    await prefs.writeJsonMap(prefsKey, {'tokenIds': merged.toList()});
  }

  /// Reads the stored ids, separating "there is nothing recorded" from "there
  /// is something recorded that we cannot read".
  ///
  /// Collapsing the two is what made a corrupt blob look like an empty
  /// revocation list, which reinstates every grant the user had withdrawn.
  /// A map with no `tokenIds` field is the legitimately-empty shape —
  /// [resetForTest] writes exactly that — so it is not treated as damage.
  static Future<_PersistedIds> _readPersistedIds(MobilePrefsStore prefs) async {
    final blob = await prefs.readRawValue(prefsKey);
    if (blob == null) return const _PersistedIds.absent();
    if (blob is! Map) return const _PersistedIds.malformed();

    if (!blob.containsKey('tokenIds')) return const _PersistedIds.absent();
    final ids = blob['tokenIds'];
    if (ids is! List) return const _PersistedIds.malformed();

    // An entry that is not a string is a revocation we cannot match against a
    // token id — damage, rather than a shorter list. Counted by type rather
    // than by length so a duplicated id is not mistaken for one.
    return _PersistedIds(
      ids: ids.whereType<String>().toSet(),
      malformed: ids.any((entry) => entry is! String),
    );
  }

  static Future<void> resetForTest() async {
    _revoked.clear();
    _loaded = false;
    _readFailed = false;
    final prefs = _prefs;
    if (prefs != null) {
      await prefs.writeJsonMap(prefsKey, {});
    }
    debugPrefsOverride = null;
  }
}

/// The outcome of reading the stored revocation blob.
class _PersistedIds {
  const _PersistedIds({required this.ids, required this.malformed});

  const _PersistedIds.absent() : ids = const <String>{}, malformed = false;

  const _PersistedIds.malformed()
    : ids = const <String>{},
      malformed = true;

  /// Every id that could be read, which may be a subset when [malformed].
  final Set<String> ids;

  /// Whether something was stored that could not be read as a revocation list.
  final bool malformed;
}
