import '../../services/app_services.dart';
import '../../storage/mobile_prefs_store.dart';
import 'memory_scope.dart';
import 'memory_scope_policy.dart';

/// Persistent memory-scope setting, backed by the same on-device prefs
/// file as other ArchiveMe local state.
///
/// The stored choice is the user's and only the user's: nothing in the
/// app ever writes a scope the user did not pick, so "Memory off" can
/// never silently re-enable. Default is [MemoryScope.automatic] until a
/// mode is explicitly chosen.
class MemoryScopeStore {
  MemoryScopeStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const _key = 'memoryScope';

  static MemoryScopeStore instance() =>
      MemoryScopeStore(AppServices.instance.prefs);

  static MemoryScopeStore forPrefs(MobilePrefsStore prefs) =>
      MemoryScopeStore(prefs);

  /// The persisted scope; [MemoryScope.automatic] when never chosen.
  Future<MemoryScope> load() async {
    final raw = await _prefs.readMap(_key);
    return MemoryScopeId.fromId(raw?['scope'] as String?) ??
        MemoryScope.automatic;
  }

  /// Persists an explicit user choice and applies it to the live policy.
  Future<void> save(MemoryScope scope) async {
    await _prefs.writeMap(_key, {'scope': scope.id});
    MemoryScopePolicy.scope = scope;
  }

  /// Loads the persisted scope into the live policy. Call before any
  /// surface that builds connection claims.
  Future<MemoryScope> ensureLoaded() async {
    final scope = await load();
    MemoryScopePolicy.scope = scope;
    return scope;
  }
}
