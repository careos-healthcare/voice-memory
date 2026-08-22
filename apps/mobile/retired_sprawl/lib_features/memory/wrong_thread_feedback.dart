import 'package:archiveme_mobile/features/memory/memory_control_model.dart';
import 'package:archiveme_mobile/features/memory/memory_scope.dart';
import 'package:archiveme_mobile/features/memory/memory_scope_policy.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter/foundation.dart';

/// Wrong-thread feedback — durable rules so a card does not reconnect
/// to the wrong explicit thread. Thread ids only; names never logged.
abstract class WrongThreadFeedback {
  WrongThreadFeedback._();

  static final Set<String> _wrongPairs = <String>{};
  static final Set<String> _sessionSuppressed = <String>{};
  static final Map<String, String> _explicitThreadByCard = <String, String>{};

  static String _pairKey(MemoryCardType cardType, String threadId) =>
      '${cardType.id}|$threadId';

  static bool isWrongPair(MemoryCardType cardType, String? threadId) {
    if (threadId == null || threadId.isEmpty) return false;
    return _wrongPairs.contains(_pairKey(cardType, threadId));
  }

  static bool isSessionSuppressed(MemoryCardType cardType) =>
      _sessionSuppressed.contains(cardType.id);

  static String? explicitThreadFor(MemoryCardType cardType) =>
      _explicitThreadByCard[cardType.id];

  static void suppressSession(MemoryCardType cardType) {
    _sessionSuppressed.add(cardType.id);
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.memoryConnectionWrongThread,
      cardType: cardType.id,
      memoryScope: MemoryScopePolicy.scope.id,
    );
  }

  static void assignExplicitThread(MemoryCardType cardType, String threadId) {
    _explicitThreadByCard[cardType.id] = threadId;
    _sessionSuppressed.remove(cardType.id);
    _persist();
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.entryAssignedToThread,
      cardType: cardType.id,
      threadScope: 'existing_thread',
      memoryScope: MemoryScopePolicy.scope.id,
    );
  }

  static void markWrongPair(MemoryCardType cardType, String threadId) {
    _wrongPairs.add(_pairKey(cardType, threadId));
    _persist();
  }

  static void keepSeparate(MemoryCardType cardType, {String? threadId}) {
    suppressSession(cardType);
    if (threadId != null && threadId.isNotEmpty) {
      markWrongPair(cardType, threadId);
    }
  }

  static void applyLoaded({
    required Iterable<String> wrongPairs,
    Map<String, String> explicitThreadByCard = const {},
  }) {
    _wrongPairs
      ..clear()
      ..addAll(wrongPairs);
    _explicitThreadByCard
      ..clear()
      ..addAll(explicitThreadByCard);
  }

  static Map<String, dynamic> toJson() => {
    'wrongPairs': _wrongPairs.toList()..sort(),
    'explicitThreadByCard': Map<String, String>.from(_explicitThreadByCard),
  };

  static void _persist() {
    if (!AppServices.isInitialized) return;
    // ignore: discarded_futures
    WrongThreadFeedbackStore.instance().saveCurrent();
  }

  @visibleForTesting
  static void resetForTest() {
    _wrongPairs.clear();
    _sessionSuppressed.clear();
    _explicitThreadByCard.clear();
  }
}

class WrongThreadFeedbackStore {
  WrongThreadFeedbackStore(this._prefs);

  static const _key = 'wrongThreadFeedback';

  final MobilePrefsStore _prefs;

  static WrongThreadFeedbackStore instance() =>
      WrongThreadFeedbackStore(AppServices.instance.prefs);

  static WrongThreadFeedbackStore forPrefs(MobilePrefsStore prefs) =>
      WrongThreadFeedbackStore(prefs);

  Future<void> saveCurrent() async {
    await _prefs.writeMap(_key, WrongThreadFeedback.toJson());
  }

  Future<void> ensureLoaded() async {
    final raw = await _prefs.readMap(_key);
    if (raw == null) return;
    WrongThreadFeedback.applyLoaded(
      wrongPairs: (raw['wrongPairs'] as List<dynamic>? ?? [])
          .whereType<String>(),
      explicitThreadByCard:
          (raw['explicitThreadByCard'] as Map?)?.map(
            (key, value) => MapEntry('$key', '$value'),
          ) ??
          const {},
    );
  }
}