import 'package:archiveme_mobile/features/activation/activation_tracker.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

/// How the user returned for another recording moment.
enum ReturnSourceKind { reminder, widgetOrObjective, manual, unknown }

extension ReturnSourceKindIds on ReturnSourceKind {
  String get id => name;
}

/// Pending return attribution consumed on next recording.
class ReturnReasonCaptureStore {
  ReturnReasonCaptureStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const _pendingKey = 'returnReasonPending';
  static const _historyKey = 'returnReasonHistory';

  static ReturnReasonCaptureStore instance() =>
      ReturnReasonCaptureStore(AppServices.instance.prefs);

  Future<void> markPendingReminder() async {
    await _setPending(ReturnSourceKind.reminder);
  }

  Future<void> markPendingWidgetOrObjective() async {
    await _setPending(ReturnSourceKind.widgetOrObjective);
  }

  Future<void> _setPending(ReturnSourceKind source) async {
    await _prefs.writeMap(_pendingKey, {
      'source': source.id,
      'at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<ReturnSourceKind?> consumePending() async {
    final raw = await _prefs.readMap(_pendingKey);
    if (raw == null || raw.isEmpty) return null;
    await _prefs.writeMap(_pendingKey, {});
    return ReturnSourceKind.values.firstWhere(
      (e) => e.id == raw['source'],
      orElse: () => ReturnSourceKind.unknown,
    );
  }

  Future<void> recordReturn({
    required ReturnSourceKind source,
    required bool activeJourneyAtReturn,
    required int timeSinceLastMomentHours,
    required int reflectionCountAfter,
  }) async {
    final raw = await _prefs.readMap(_historyKey);
    final list = raw?['items'];
    final items = list is List
        ? List<Map<String, dynamic>>.from(list)
        : <Map<String, dynamic>>[];
    items.add({
      'source': source.id,
      'activeJourney': activeJourneyAtReturn,
      'hoursSinceLast': timeSinceLastMomentHours,
      'reflectionCount': reflectionCountAfter,
      'at': DateTime.now().toUtc().toIso8601String(),
    });
    await _prefs.writeMap(_historyKey, {'items': items});

    if (source == ReturnSourceKind.reminder) {
      ActivationTracker.trackReminderReturnRecorded();
    }
  }

  Future<int> reminderReturnCount() async {
    final raw = await _prefs.readMap(_historyKey);
    final list = raw?['items'];
    if (list is! List) return 0;
    return list
        .whereType<Map>()
        .where((e) => e['source'] == ReturnSourceKind.reminder.id)
        .length;
  }
}