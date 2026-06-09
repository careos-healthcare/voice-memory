import '../../services/app_services.dart';
import '../../storage/mobile_prefs_store.dart';
import '../activation/activation_tracker.dart';
import 'interpretation_quality_signal_model.dart';

/// Persists interpretation quality signals for trial/debug readout.
class InterpretationQualityStore {
  InterpretationQualityStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const _key = 'interpretationQualitySignals';
  static const _microFeedbackKey = 'readMicroFeedback';

  static InterpretationQualityStore? _active() {
    if (!AppServices.isInitialized) return null;
    return InterpretationQualityStore(AppServices.instance.prefs);
  }

  static InterpretationQualityStore instance() {
    final active = _active();
    if (active == null) {
      throw StateError('AppServices not initialized');
    }
    return active;
  }

  static Future<List<InterpretationQualitySignal>> loadAll() async {
    final store = _active();
    if (store == null) return const [];
    final raw = await store._prefs.readMap(_key);
    final list = raw?['items'];
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((e) => InterpretationQualitySignal.fromJson(
              Map<String, dynamic>.from(e),
            ))
        .toList();
  }

  static Future<void> append(InterpretationQualitySignal signal) async {
    final store = _active();
    if (store == null) return;
    final items = await loadAll();
    final next = [...items, signal];
    await store._prefs.writeMap(_key, {
      'items': next.map((s) => s.toJson()).toList(),
    });
    store._trackCounts(signal);
  }

  static Future<void> markNextPromptUsed(String readId) async {
    final store = _active();
    if (store == null) return;
    final items = await loadAll();
    if (items.isEmpty) return;
    final updated = items.map((s) {
      if (s.readId != readId) return s;
      return InterpretationQualitySignal(
        readId: s.readId,
        readTitle: s.readTitle,
        specificityLevel: s.specificityLevel,
        strengthLabel: s.strengthLabel,
        evidenceCount: s.evidenceCount,
        userAction: s.userAction,
        timeToActionSeconds: s.timeToActionSeconds,
        createdAt: s.createdAt,
        source: s.source,
        nextPromptUsed: true,
        qualityLabel: s.qualityLabel,
      );
    }).toList();
    await store._prefs.writeMap(_key, {
      'items': updated.map((s) => s.toJson()).toList(),
    });
  }

  static Future<int> strongCount() async {
    final items = await loadAll();
    return items
        .where((s) => s.qualityLabel == InterpretationQualityLabel.strong)
        .length;
  }

  static Future<int> weakCount() async {
    final items = await loadAll();
    return items
        .where((s) => s.qualityLabel == InterpretationQualityLabel.weak)
        .length;
  }

  static Future<void> markSharpnessWeakness({required String readId}) async {
    final store = _active();
    if (store == null) return;
    await recordMicroFeedback(readId: readId, useful: false);
    ActivationTracker.trackInterpretationWeak();
  }

  static Future<void> markSharpnessMismatch({required String readId}) async {
    final store = _active();
    if (store == null) return;
    await recordMicroFeedback(readId: readId, useful: false);
    ActivationTracker.trackInterpretationWeak();
  }

  static Future<void> recordMicroFeedback({
    required String readId,
    required bool useful,
  }) async {
    final store = _active();
    if (store == null) return;
    final raw = await store._prefs.readMap(_microFeedbackKey);
    final list = raw?['items'];
    final items =
        list is List ? List<Map<String, dynamic>>.from(list) : <Map<String, dynamic>>[];
    items.add({
      'readId': readId,
      'useful': useful,
      'at': DateTime.now().toUtc().toIso8601String(),
    });
    await store._prefs.writeMap(_microFeedbackKey, {'items': items});
    if (useful) {
      ActivationTracker.trackReadUsefulTapped();
    } else {
      ActivationTracker.trackReadNotQuiteTapped();
    }
  }

  static Future<bool> microFeedbackShownFor(String readId) async {
    final store = _active();
    if (store == null) return false;
    final raw = await store._prefs.readMap(_microFeedbackKey);
    final list = raw?['shown'];
    if (list is! List) return false;
    return list.contains(readId);
  }

  static Future<void> markMicroFeedbackShown(String readId) async {
    final store = _active();
    if (store == null) return;
    final raw = await store._prefs.readMap(_microFeedbackKey);
    final list = raw?['shown'];
    final shown = list is List ? List<String>.from(list) : <String>[];
    if (!shown.contains(readId)) shown.add(readId);
    await store._prefs.writeMap(_microFeedbackKey, {
      'shown': shown,
      'items': raw?['items'],
    });
  }

  void _trackCounts(InterpretationQualitySignal signal) {
    if (signal.qualityLabel == InterpretationQualityLabel.strong) {
      ActivationTracker.trackInterpretationStrong();
    } else if (signal.qualityLabel == InterpretationQualityLabel.weak) {
      ActivationTracker.trackInterpretationWeak();
    }
  }
}
