import '../../services/app_services.dart';
import '../../storage/mobile_prefs_store.dart';
import 'loop_mode_model.dart';

/// Persists the active Loop Mode.
class LoopModeStore {
  LoopModeStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const _key = 'activeLoopMode';

  static LoopModeStore? _active() {
    if (!AppServices.isInitialized) return null;
    return LoopModeStore(AppServices.instance.prefs);
  }

  static LoopModeStore instance() {
    final active = _active();
    if (active == null) {
      throw StateError('AppServices not initialized');
    }
    return active;
  }

  Future<LoopMode?> load() async {
    final store = _active();
    if (store == null) return null;
    final raw = await store._prefs.readMap(_key);
    final mode = LoopMode.fromJson(raw);
    if (mode == null || !mode.active) return null;
    return mode;
  }

  Future<void> save(LoopMode mode) async {
    final store = _active();
    if (store == null) return;
    await store._prefs.writeMap(_key, mode.toJson());
  }

  Future<void> clear() async {
    final store = _active();
    if (store == null) return;
    await store._prefs.writeMap(_key, {});
  }
}
