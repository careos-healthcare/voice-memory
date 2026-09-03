import 'package:archiveme_mobile/core/utils/app_logger.dart';
import 'package:archiveme_mobile/services/app_services.dart';
import 'package:archiveme_mobile/storage/mobile_prefs_store.dart';
import 'package:flutter/foundation.dart';

/// A pending purchase intent: a previous purchase start that never
/// completed. Carries only stable ids — never user content.
class PendingPurchaseIntent {
  const PendingPurchaseIntent({this.source, this.plan});

  /// Paywall source id of the original purchase start, when known.
  final String? source;

  /// Stable plan id (`monthly` / `yearly`), when known.
  final String? plan;
}

/// Purchase Intent Return Cue — a calm, dismissible reminder for users who
/// started a purchase but did not complete it, shown on a later visit.
///
/// Guardrails by construction:
/// - Only a pending intent (started, never completed) can show it.
/// - Never in the same session that started a purchase — cancelling the
///   App Store sheet never triggers an immediate nudge.
/// - Never for Pro users, at most once per session, always dismissible,
///   never blocking free use.
abstract class PurchaseIntentReturnCue {
  PurchaseIntentReturnCue._();

  static const String title = 'Still want Pro to continue this?';
  static const String body =
      'Your saves stay free. Pro keeps the thread connected over time.';
  static const String ctaLabel = 'See Pro';
  static const String dismissLabel = 'Not now';

  /// True once the cue rendered (or was dismissed) this session.
  static bool shownThisSession = false;

  /// True once this session fired a purchase start — suppresses the cue in
  /// the same flow that just showed the App Store sheet.
  static bool purchaseStartedThisSession = false;

  static bool shouldShow({
    required bool isPro,
    required bool hasPendingIntent,
  }) =>
      !isPro &&
      hasPendingIntent &&
      !shownThisSession &&
      !purchaseStartedThisSession;

  @visibleForTesting
  static void resetSessionForTest() {
    shownThisSession = false;
    purchaseStartedThisSession = false;
  }
}

/// Local persistence of the latest purchase intent — timestamp, stable
/// source/plan ids, and the completed flag only. No user content; the
/// payload is fixed-shape by construction.
class PurchaseIntentStore {
  PurchaseIntentStore({this._prefs, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final MobilePrefsStore? _prefs;
  final DateTime Function() _now;

  static const String prefsKey = 'purchase_intent';

  /// Stable-id shape — anything else is dropped on read and write.
  static final RegExp _safeValue = RegExp(r'^[a-z0-9_]{1,40}$');

  MobilePrefsStore? get _resolvedPrefs {
    if (_prefs != null) return _prefs;
    if (!AppServices.isInitialized) return null;
    return AppServices.instance.prefs;
  }

  /// Records a purchase start, replacing any previous intent.
  Future<void> recordPurchaseStarted({String? source, String? plan}) async {
    final prefs = _resolvedPrefs;
    if (prefs == null) return;
    try {
      await prefs.writeMap(prefsKey, {
        'last_purchase_started_at': _now().toIso8601String(),
        if (source != null && _safeValue.hasMatch(source)) 'source': source,
        if (plan != null && _safeValue.hasMatch(plan)) 'plan': plan,
        'completed': false,
      });
    } on Exception catch (e, stackTrace) {
      AppLogger.error('Unhandled error caught', error: e, stackTrace: stackTrace);
      // Persistence failures never surface; worst case no cue later.
    }
  }

  /// Marks the latest intent as completed — the cue never shows again for
  /// it.
  Future<void> recordPurchaseCompleted() async {
    final prefs = _resolvedPrefs;
    if (prefs == null) return;
    try {
      final data = await prefs.readMap(prefsKey) ?? <String, dynamic>{};
      await prefs.writeMap(prefsKey, {...data, 'completed': true});
    } on Exception catch (e, stackTrace) {
      AppLogger.error('Unhandled error caught', error: e, stackTrace: stackTrace);
      // Same as above — fail quietly.
    }
  }

  /// The pending intent, or null when none exists, the purchase completed,
  /// or the stored record is malformed.
  Future<PendingPurchaseIntent?> pendingIntent() async {
    final prefs = _resolvedPrefs;
    if (prefs == null) return null;
    try {
      final data = await prefs.readMap(prefsKey);
      if (data == null) return null;
      if (data['completed'] != false) return null;
      if (data['last_purchase_started_at'] is! String) return null;
      final source = data['source'];
      final plan = data['plan'];
      return PendingPurchaseIntent(
        source: source is String && _safeValue.hasMatch(source) ? source : null,
        plan: plan is String && _safeValue.hasMatch(plan) ? plan : null,
      );
    } on Exception catch (_, stackTrace) {
      return null;
    }
  }
}