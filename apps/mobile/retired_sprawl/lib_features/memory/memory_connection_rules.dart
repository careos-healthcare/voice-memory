import 'package:archiveme_mobile/features/memory/memory_control_model.dart';
import 'package:archiveme_mobile/features/memory/memory_scope.dart';
import 'package:archiveme_mobile/features/memory/memory_scope_policy.dart';
import 'package:archiveme_mobile/features/memory/not_important_feedback.dart';
import 'package:archiveme_mobile/services/activation_funnel_analytics.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter/foundation.dart';

/// Per-card connection rules created by the inspect/edit controls:
///
/// - "Keep connected": the user confirmed this connection, so its
///   evidence may carry user-confirmed authority.
/// - "Treat future entries as new": a local rule so future similar
///   entries do not auto-connect on this card until the user changes it.
///
/// Rules only narrow or confirm what Memory Scope Controls already
/// allow — they never re-enable memory that scope turned off, and they
/// never delete or alter entries. Stable card-type ids only.
abstract class MemoryConnectionRules {
  MemoryConnectionRules._();

  static final Set<String> _confirmedCardTypes = <String>{};
  static final Set<String> _futureFreshCardTypes = <String>{};

  static bool isConfirmed(String cardTypeId) =>
      _confirmedCardTypes.contains(cardTypeId);

  static bool isFutureFresh(String cardTypeId) =>
      _futureFreshCardTypes.contains(cardTypeId);

  /// "Keep connected" — marks the card's connection user-confirmed.
  /// Clears any future-fresh rule for the same card: the newer choice
  /// wins.
  static void keepConnected(MemoryCardType cardType) {
    _confirmedCardTypes.add(cardType.id);
    _futureFreshCardTypes.remove(cardType.id);
    NotImportantFeedback.clearDemotion(cardType);
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.memoryKeepConnected,
      cardType: cardType.id,
      memoryScope: MemoryScopePolicy.scope.id,
    );
    _persist();
  }

  /// "Treat future entries as new" — future similar entries do not
  /// auto-connect on this card. Clears any confirmation for the card.
  static void treatFutureAsNew(MemoryCardType cardType) {
    _futureFreshCardTypes.add(cardType.id);
    _confirmedCardTypes.remove(cardType.id);
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.memoryFutureFreshRuleCreated,
      cardType: cardType.id,
      memoryScope: MemoryScopePolicy.scope.id,
    );
    _persist();
  }

  /// Loads persisted rules into the live session state.
  static void applyLoaded({
    required Iterable<String> confirmed,
    required Iterable<String> futureFresh,
  }) {
    _confirmedCardTypes
      ..clear()
      ..addAll(confirmed);
    _futureFreshCardTypes
      ..clear()
      ..addAll(futureFresh);
  }

  static Map<String, dynamic> toJson() => {
    'confirmed': _confirmedCardTypes.toList()..sort(),
    'futureFresh': _futureFreshCardTypes.toList()..sort(),
  };

  static void _persist() {
    if (!AppServices.isInitialized) return;
    // Fire-and-forget: the in-memory rules are authoritative this
    // session; the prefs copy restores them on next launch.
    // ignore: discarded_futures
    MemoryConnectionRuleStore.instance().saveCurrent();
  }

  @visibleForTesting
  static void resetForTest() {
    _confirmedCardTypes.clear();
    _futureFreshCardTypes.clear();
  }
}

/// Prefs persistence for [MemoryConnectionRules] — card-type ids only,
/// never entry ids, dates, or text.
class MemoryConnectionRuleStore {
  MemoryConnectionRuleStore(this._prefs);

  final MobilePrefsStore _prefs;

  static const _key = 'memoryConnectionRules';

  static MemoryConnectionRuleStore instance() =>
      MemoryConnectionRuleStore(AppServices.instance.prefs);

  static MemoryConnectionRuleStore forPrefs(MobilePrefsStore prefs) =>
      MemoryConnectionRuleStore(prefs);

  Future<void> saveCurrent() async {
    await _prefs.writeMap(_key, MemoryConnectionRules.toJson());
  }

  /// Loads persisted rules into the live session state.
  Future<void> ensureLoaded() async {
    final raw = await _prefs.readMap(_key);
    if (raw == null) return;
    MemoryConnectionRules.applyLoaded(
      confirmed: (raw['confirmed'] as List<dynamic>? ?? []).whereType<String>(),
      futureFresh: (raw['futureFresh'] as List<dynamic>? ?? [])
          .whereType<String>(),
    );
  }
}