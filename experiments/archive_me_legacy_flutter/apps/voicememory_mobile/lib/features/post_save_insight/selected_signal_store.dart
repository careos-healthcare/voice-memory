import '../../services/app_services.dart';
import '../../storage/mobile_prefs_store.dart';
import 'selected_signal_model.dart';

/// Persists the user's chosen signal for Patterns waiting-for-confirmation.
class SelectedSignalStore {
  SelectedSignalStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const _currentKey = 'selectedSignalCurrent';
  static const _historyKey = 'selectedSignalHistory';
  static const _maxHistory = 20;

  static SelectedSignalStore instance() =>
      SelectedSignalStore(AppServices.instance.prefs);

  Future<void> save(SelectedSignalRecord record) async {
    await _prefs.writeMap(_currentKey, record.toJson());
    final history = await loadHistory();
    final next = [
      record,
      ...history.where((r) => r.id != record.id),
    ].take(_maxHistory).toList();
    await _prefs.writeMap(_historyKey, {
      'items': next.map((r) => r.toJson()).toList(),
    });
  }

  Future<SelectedSignalRecord?> loadCurrent() async {
    final raw = await _prefs.readMap(_currentKey);
    return SelectedSignalRecord.fromJson(raw);
  }

  Future<List<SelectedSignalRecord>> loadHistory() async {
    final raw = await _prefs.readMap(_historyKey);
    if (raw == null) return const [];
    final list = raw['items'];
    if (list is! List) return const [];
    return list
        .map(
          (e) => SelectedSignalRecord.fromJson(
            e is Map<String, dynamic>
                ? e
                : (e is Map ? Map<String, dynamic>.from(e) : null),
          ),
        )
        .whereType<SelectedSignalRecord>()
        .toList();
  }

  Future<void> clearCurrent() async {
    await _prefs.writeMap(_currentKey, {});
  }
}
