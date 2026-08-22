import 'package:archiveme_mobile/features/memory/memory_connection_rules.dart';
import 'package:archiveme_mobile/features/memory/memory_control_model.dart';
import 'package:archiveme_mobile/features/memory/memory_scope.dart';
import 'package:archiveme_mobile/features/memory/memory_scope_policy.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter/foundation.dart';

/// Durable "Not important" demotion — lowers priority without deleting
/// entries or marking them unrelated.
abstract class NotImportantFeedback {
  NotImportantFeedback._();

  static final Set<String> _demotedCardTypes = <String>{};
  static final Set<String> _demotedEntryKeys = <String>{};

  static String _entryKey(MemoryCardType cardType, String entryId) =>
      '${cardType.id}|$entryId';

  static bool isDemoted(MemoryCardType cardType, {String? entryId}) {
    if (MemoryConnectionRules.isConfirmed(cardType.id)) return false;
    if (entryId != null &&
        _demotedEntryKeys.contains(_entryKey(cardType, entryId))) {
      return true;
    }
    return _demotedCardTypes.contains(cardType.id);
  }

  static void markNotImportant(MemoryCardType cardType, {String? entryId}) {
    _demotedCardTypes.add(cardType.id);
    if (entryId != null && entryId.isNotEmpty) {
      _demotedEntryKeys.add(_entryKey(cardType, entryId));
    }
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.memoryNotImportantSelected,
      cardType: cardType.id,
      memoryScope: MemoryScopePolicy.scope.id,
    );
    _persist();
  }

  /// Keep connected promotes this connection and clears not-important.
  static void clearDemotion(MemoryCardType cardType) {
    _demotedCardTypes.remove(cardType.id);
    _demotedEntryKeys.removeWhere((k) => k.startsWith('${cardType.id}|'));
    _persist();
  }

  static void applyLoaded({
    required Iterable<String> demotedCardTypes,
    required Iterable<String> demotedEntryKeys,
  }) {
    _demotedCardTypes
      ..clear()
      ..addAll(demotedCardTypes);
    _demotedEntryKeys
      ..clear()
      ..addAll(demotedEntryKeys);
  }

  static Map<String, dynamic> toJson() => {
    'demotedCardTypes': _demotedCardTypes.toList()..sort(),
    'demotedEntryKeys': _demotedEntryKeys.toList()..sort(),
  };

  static void _persist() {
    if (!AppServices.isInitialized) return;
    // ignore: discarded_futures
    NotImportantFeedbackStore.instance().saveCurrent();
  }

  static void resetPersistedState() {
    _demotedCardTypes.clear();
    _demotedEntryKeys.clear();
  }

  @visibleForTesting
  static void resetForTest() => resetPersistedState();
}

class NotImportantFeedbackStore {
  NotImportantFeedbackStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const _key = 'notImportantFeedback';

  static NotImportantFeedbackStore instance() =>
      NotImportantFeedbackStore(AppServices.instance.prefs);

  static NotImportantFeedbackStore forPrefs(MobilePrefsStore prefs) =>
      NotImportantFeedbackStore(prefs);

  Future<void> saveCurrent() async {
    await _prefs.writeMap(_key, NotImportantFeedback.toJson());
  }

  Future<void> ensureLoaded() async {
    final raw = await _prefs.readMap(_key);
    if (raw == null) return;
    NotImportantFeedback.applyLoaded(
      demotedCardTypes: (raw['demotedCardTypes'] as List<dynamic>? ?? [])
          .whereType<String>(),
      demotedEntryKeys: (raw['demotedEntryKeys'] as List<dynamic>? ?? [])
          .whereType<String>(),
    );
  }
}