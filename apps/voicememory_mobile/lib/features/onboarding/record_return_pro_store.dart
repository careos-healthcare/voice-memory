import '../../services/app_services.dart';
import '../../storage/mobile_prefs_store.dart';
import 'first_60_second_store.dart';
import 'first_60_second_state.dart';
import 'first_save_loop_state.dart';
import 'first_save_loop_store.dart';
import 'record_return_pro_state.dart';

/// Prefs-backed persistence for the Record → Return → Pro loop.
class RecordReturnProStore {
  RecordReturnProStore({MobilePrefsStore? prefs}) : _prefs = prefs;

  static RecordReturnProStore instance() => RecordReturnProStore();

  static const String prefsKey = 'recordReturnPro';

  final MobilePrefsStore? _prefs;

  MobilePrefsStore? get _resolvedPrefs {
    if (_prefs != null) return _prefs;
    if (!AppServices.isInitialized) return null;
    return AppServices.instance.prefs;
  }

  Future<RecordReturnProState> load() async {
    final prefs = _resolvedPrefs;
    if (prefs == null) {
      return const RecordReturnProState(
        returnCueResolved: true,
        proBridgeResolved: true,
        changeStartSeen: true,
      );
    }
    try {
      final raw = await prefs.readMap(prefsKey);
      if (raw != null) return RecordReturnProState.fromJson(raw);

      // Carry forward from the first-save loop store.
      final firstSave = FirstSaveLoopState.fromJson(
        await prefs.readMap(FirstSaveLoopStore.prefsKey),
      );
      if (firstSave.returnCueResolved ||
          firstSave.proBridgeResolved ||
          firstSave.returnCueMethod != null) {
        return RecordReturnProState(
          returnCueResolved: firstSave.returnCueResolved,
          returnCueMethod: firstSave.returnCueMethod,
          proBridgeResolved: firstSave.proBridgeResolved,
        );
      }

      // Carry forward from the earlier first-60 store.
      final legacy = First60SecondState.fromJson(
        await prefs.readMap(First60SecondStore.prefsKey),
      );
      if (legacy.returnCueResolved || legacy.proBridgeResolved) {
        return RecordReturnProState(
          returnCueResolved: legacy.returnCueResolved,
          returnCueMethod: legacy.returnCueMethod,
          proBridgeResolved: legacy.proBridgeResolved,
        );
      }
      return const RecordReturnProState();
    } catch (_) {
      return const RecordReturnProState(
        returnCueResolved: true,
        proBridgeResolved: true,
        changeStartSeen: true,
      );
    }
  }

  Future<void> markEvidenceSeen() async {
    final current = await load();
    await _write(current.copyWith(evidenceSeen: true));
  }

  Future<void> markReturnCueResolved(String method) async {
    final current = await load();
    await _write(
      current.copyWith(returnCueResolved: true, returnCueMethod: method),
    );
  }

  Future<void> markProBridgeResolved() async {
    final current = await load();
    await _write(current.copyWith(proBridgeResolved: true));
  }

  Future<void> markChangeStartSeen() async {
    final current = await load();
    await _write(current.copyWith(changeStartSeen: true));
  }

  Future<void> markLoopStartedLogged() async {
    final current = await load();
    await _write(current.copyWith(loopStartedLogged: true));
  }

  Future<void> _write(RecordReturnProState state) async {
    final prefs = _resolvedPrefs;
    if (prefs == null) return;
    try {
      await prefs.writeMap(prefsKey, state.toJson());
    } catch (_) {}
  }
}
