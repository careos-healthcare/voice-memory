import 'dart:async';

import 'package:archiveme_mobile/features/beta_analytics/beta_analytics_consent_boundary.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';

/// Whether the customer has affirmatively allowed product analytics collection.
///
/// Deliberately a separate concept from `RemoteProcessingConsentStore`, because
/// [BetaAnalyticsConsentBoundary] already documents the split: remote-processing
/// consent governs what the capture pipeline may upload for transcription and
/// reflection, and it says in terms that "Product analytics (this registry) is
/// not part of remote processing consent". Folding analytics into that store
/// would mean a customer who opts into transcription has silently opted into
/// telemetry, and one who declines transcription could never enable it.
///
/// The default is [undecided], which is not granted. That matters more than it
/// looks: Firebase Analytics collection is enabled by default by the platform
/// manifest, so `ProductAnalytics` has to pass a concrete `false` to turn it
/// off. Absence of a decision is treated as a refusal, never as permission.
class ProductAnalyticsConsentState {
  const ProductAnalyticsConsentState({
    required this.granted,
    required this.decidedAt,
    required this.policyVersion,
  });

  factory ProductAnalyticsConsentState.fromJson(Map<String, dynamic> json) {
    final decidedAtRaw = json['decidedAt'];
    return ProductAnalyticsConsentState(
      granted: json['granted'] == true,
      decidedAt: decidedAtRaw is String
          ? DateTime.tryParse(decidedAtRaw)?.toUtc()
          : null,
      policyVersion: json['policyVersion'] is int
          ? json['policyVersion'] as int
          : ProductAnalyticsConsentStore.currentPolicyVersion,
    );
  }

  /// No decision recorded yet — collection stays off.
  static const ProductAnalyticsConsentState undecided =
      ProductAnalyticsConsentState(
        granted: false,
        decidedAt: null,
        policyVersion: ProductAnalyticsConsentStore.currentPolicyVersion,
      );

  final bool granted;
  final DateTime? decidedAt;
  final int policyVersion;

  /// Whether a decision was ever recorded, for settings and audit surfaces.
  bool get isDecided => decidedAt != null;

  Map<String, dynamic> toJson() => {
    'granted': granted,
    'decidedAt': decidedAt?.toUtc().toIso8601String(),
    'policyVersion': policyVersion,
  };
}

/// Per-namespace store for [ProductAnalyticsConsentState].
///
/// Shaped after `RemoteProcessingConsentStore` on purpose — same prefs-backed
/// JSON map, same `current`/`grant`/`withdraw` surface, same change stream — so
/// there is nothing new to learn at the call site.
class ProductAnalyticsConsentStore {
  ProductAnalyticsConsentStore(this._prefs);

  static const String prefsKey = 'product_analytics_consent_v1';
  static const int currentPolicyVersion = 1;

  final MobilePrefsStore _prefs;

  final StreamController<ProductAnalyticsConsentState> _changes =
      StreamController<ProductAnalyticsConsentState>.broadcast();

  /// Emits after every grant or withdrawal, so `ProductAnalytics` can apply a
  /// change immediately instead of waiting for the next launch.
  Stream<ProductAnalyticsConsentState> get onChanged => _changes.stream;

  Future<ProductAnalyticsConsentState> current() async {
    try {
      final raw = await _prefs.readJsonMap(prefsKey);
      if (raw == null) return ProductAnalyticsConsentState.undecided;
      return ProductAnalyticsConsentState.fromJson(raw);
    } catch (_) {
      // Fail closed: an unreadable decision is not a granted one.
      return ProductAnalyticsConsentState.undecided;
    }
  }

  /// The single question callers should ask. Never throws, and never returns
  /// true for a missing or malformed record.
  Future<bool> isGrantedNow() async => (await current()).granted;

  Future<ProductAnalyticsConsentState> grant({DateTime? now}) =>
      _write(granted: true, now: now);

  Future<ProductAnalyticsConsentState> withdraw({DateTime? now}) =>
      _write(granted: false, now: now);

  Future<ProductAnalyticsConsentState> _write({
    required bool granted,
    DateTime? now,
  }) async {
    final state = ProductAnalyticsConsentState(
      granted: granted,
      decidedAt: (now ?? DateTime.now()).toUtc(),
      policyVersion: currentPolicyVersion,
    );
    await _prefs.writeJsonMap(prefsKey, state.toJson());
    if (_changes.hasListener) _changes.add(state);
    return state;
  }
}
