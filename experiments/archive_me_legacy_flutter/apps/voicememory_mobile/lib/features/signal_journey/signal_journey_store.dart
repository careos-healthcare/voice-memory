import '../../services/app_services.dart';
import '../../storage/mobile_prefs_store.dart';
import 'signal_journey_model.dart';

/// Persists the active signal journey and completed history.
class SignalJourneyStore {
  SignalJourneyStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const _activeKey = 'signalJourneyActive';
  static const _historyKey = 'signalJourneyHistory';
  static const _completedCountKey = 'signalJourneyCompletedCount';
  static const _maxHistory = 20;

  static SignalJourneyStore instance() =>
      SignalJourneyStore(AppServices.instance.prefs);

  Future<void> saveActive(SignalJourney journey) async {
    await _prefs.writeMap(_activeKey, journey.toJson());
  }

  Future<SignalJourney?> loadActive() async {
    final raw = await _prefs.readMap(_activeKey);
    return SignalJourney.fromJson(raw);
  }

  Future<void> clearActive() async {
    await _prefs.writeMap(_activeKey, {});
  }

  Future<void> archiveToHistory(SignalJourney journey) async {
    final history = await loadHistory();
    final next = [
      journey.copyWith(status: SignalJourneyStatus.archived),
      ...history.where((j) => j.id != journey.id),
    ].take(_maxHistory).toList();
    await _prefs.writeMap(_historyKey, {
      'items': next.map((j) => j.toJson()).toList(),
    });
    if (journey.status == SignalJourneyStatus.confirmedPattern) {
      final count = await completedJourneyCount();
      await _prefs.writeMap(_completedCountKey, {'count': count + 1});
    }
  }

  Future<List<SignalJourney>> loadHistory() async {
    final raw = await _prefs.readMap(_historyKey);
    if (raw == null) return const [];
    final list = raw['items'];
    if (list is! List) return const [];
    return list
        .map(
          (e) => SignalJourney.fromJson(
            e is Map<String, dynamic>
                ? e
                : (e is Map ? Map<String, dynamic>.from(e) : null),
          ),
        )
        .whereType<SignalJourney>()
        .toList();
  }

  Future<int> completedJourneyCount() async {
    final raw = await _prefs.readMap(_completedCountKey);
    return (raw?['count'] as num?)?.toInt() ?? 0;
  }
}
