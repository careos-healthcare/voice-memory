import '../../services/app_services.dart';
import '../../storage/mobile_prefs_store.dart';
import 'beta_feedback_models.dart';

/// Local-only beta feedback persistence — never uploads or touches journal data.
class BetaFeedbackStore {
  BetaFeedbackStore(this._prefs);

  static const prefsKey = 'archiveBetaFeedback';
  static const maxNoteLength = 240;

  final MobilePrefsStore _prefs;

  static BetaFeedbackState _cached = BetaFeedbackState.empty;
  static bool _loaded = false;

  static BetaFeedbackState get cached => _cached;

  static BetaFeedbackStore instance() =>
      BetaFeedbackStore(AppServices.instance.prefs);

  static Future<void> ensureLoaded() async {
    if (_loaded || !AppServices.isInitialized) return;
    _cached = await instance().load();
    _loaded = true;
  }

  Future<BetaFeedbackState> load() async {
    final raw = await _prefs.readMap(prefsKey);
    return BetaFeedbackState.fromJson(raw);
  }

  Future<void> save(BetaFeedbackState state) async {
    final next = state.copyWith(
      updatedAt: DateTime.now().toUtc(),
      note: _trimNote(state.note),
    );
    await _prefs.writeMap(prefsKey, next.toJson());
    _cached = next;
    _loaded = true;
  }

  Future<void> dismiss() async {
    final current = await load();
    await save(current.copyWith(dismissed: true));
  }

  Future<void> saveResponse({
    BetaFeedbackUsefulness? usefulness,
    BetaFeedbackClarity? clarity,
    String? note,
  }) async {
    final current = await load();
    await save(
      current.copyWith(
        usefulness: usefulness,
        clarity: clarity,
        note: _trimNote(note),
        dismissed: false,
      ),
    );
  }

  static String? _trimNote(String? note) {
    final trimmed = note?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    if (trimmed.length <= maxNoteLength) return trimmed;
    return trimmed.substring(0, maxNoteLength);
  }

  static Future<void> resetForTest() async {
    _cached = BetaFeedbackState.empty;
    _loaded = false;
    if (!AppServices.isInitialized) return;
    await AppServices.instance.prefs.writeMap(prefsKey, {});
  }
}
