import '../../services/app_services.dart';
import '../../storage/mobile_prefs_store.dart';
import 'pro_interest_models.dart';

/// Local-only Pro interest persistence — never uploads or touches journal data.
class ProInterestStore {
  ProInterestStore(this._prefs);

  static const prefsKey = 'archiveProInterestSignal';
  static const maxNoteLength = 240;

  final MobilePrefsStore _prefs;

  static ProInterestState _cached = ProInterestState.empty;
  static bool _loaded = false;

  static ProInterestState get cached => _cached;

  static ProInterestStore instance() =>
      ProInterestStore(AppServices.instance.prefs);

  static Future<void> ensureLoaded() async {
    if (_loaded || !AppServices.isInitialized) return;
    _cached = await instance().load();
    _loaded = true;
  }

  Future<ProInterestState> load() async {
    final raw = await _prefs.readMap(prefsKey);
    return ProInterestState.fromJson(raw);
  }

  Future<void> save(ProInterestState state) async {
    final now = DateTime.now().toUtc();
    final next = state.copyWith(
      note: _trimNote(state.note),
      createdAt: state.createdAt ?? now,
      updatedAt: now,
    );
    await _prefs.writeMap(prefsKey, next.toJson());
    _cached = next;
    _loaded = true;
  }

  Future<void> saveInterest({
    required List<ProInterestValueId> selectedValueIds,
    ProInterestPricingIntentId? pricingIntentId,
    String? note,
    String? sourceRoute,
  }) async {
    final current = await load();
    await save(
      current.copyWith(
        selectedValueIds: selectedValueIds,
        pricingIntentId: pricingIntentId,
        clearPricingIntent: pricingIntentId == null,
        note: _trimNote(note),
        sourceRoute: sourceRoute,
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
    _cached = ProInterestState.empty;
    _loaded = false;
    if (!AppServices.isInitialized) return;
    await AppServices.instance.prefs.writeMap(prefsKey, {});
  }
}
