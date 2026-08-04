import '../../services/app_services.dart';
import '../../storage/mobile_prefs_store.dart';
import 'first_60_second_state.dart';

/// Prefs-backed persistence for the first-60 loop. Local only.
///
/// Mirrors the [DayTwoReminderCoordinator] pattern: production resolves
/// prefs lazily through [AppServices]; tests inject a store directly.
/// Failures resolve conservatively (treated as already answered) so the
/// loop can never nag.
class First60SecondStore {
  First60SecondStore({this._prefs});

  static First60SecondStore instance() => First60SecondStore();

  /// Prefs key holding the serialized [First60SecondState].
  static const String prefsKey = 'first60Seconds';

  final MobilePrefsStore? _prefs;

  MobilePrefsStore? get _resolvedPrefs {
    if (_prefs != null) return _prefs;
    if (!AppServices.isInitialized) return null;
    return AppServices.instance.prefs;
  }

  Future<First60SecondState> load() async {
    final prefs = _resolvedPrefs;
    if (prefs == null) {
      // No persistence — resolve everything so nothing can re-ask.
      return const First60SecondState(
        returnCueResolved: true,
        proBridgeResolved: true,
        firstSaveLogged: true,
      );
    }
    try {
      return First60SecondState.fromJson(await prefs.readMap(prefsKey));
    } catch (_) {
      return const First60SecondState(
        returnCueResolved: true,
        proBridgeResolved: true,
        firstSaveLogged: true,
      );
    }
  }

  /// The return cue was answered — by [First60ReturnCueMethod] id.
  Future<void> markReturnCueResolved(String method) async {
    final current = await load();
    await _write(
      current.copyWith(returnCueResolved: true, returnCueMethod: method),
    );
  }

  /// The Pro bridge was answered — by [First60ProBridgeOutcome] id.
  Future<void> markProBridgeResolved() async {
    final current = await load();
    await _write(current.copyWith(proBridgeResolved: true));
  }

  /// The one-time first-save event fired.
  Future<void> markFirstSaveLogged() async {
    final current = await load();
    await _write(current.copyWith(firstSaveLogged: true));
  }

  Future<void> _write(First60SecondState state) async {
    final prefs = _resolvedPrefs;
    if (prefs == null) return;
    try {
      await prefs.writeMap(prefsKey, state.toJson());
    } catch (_) {
      // Persistence failures never surface; worst case the card is gone
      // for this session anyway.
    }
  }
}
