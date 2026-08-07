import '../services/app_services.dart';
import '../storage/mobile_prefs_store.dart';
import 'paywall_rejection_reason.dart';
import 'paywall_session_tracker.dart';

/// Objection-specific reassurance copy for the next paywall visit, keyed by
/// the stable rejection reason id captured last time. Calm and factual —
/// never pressure, never a claim about the user's content.
abstract class PaywallObjectionFollowUpCopy {
  PaywallObjectionFollowUpCopy._();

  static const String notEnoughProofTitle = 'More proof before you decide';
  static const String notEnoughProofBody =
      'Your archive can now show connected recordings, returned threads, '
      'and exact evidence before you choose Pro.';

  static const String unclearProValueTitle = 'What Pro adds';
  static const String unclearProValueBody =
      'Free keeps today\u2019s save. Pro keeps the thread connected as it '
      'returns, fades, or changes.';

  static const String wantToTryLongerTitle = 'Try longer first';
  static const String wantToTryLongerBody =
      'Keep using ArchiveMe for free. Pro is for when you want the archive '
      'to keep connecting over time.';

  static const String tooExpensiveTitle = 'Only if the continuity is worth it';
  static const String tooExpensiveBody =
      'Your saves stay free. Pro adds the longer-term thread history.';

  static const String noMoreSubscriptionsTitle =
      'No pressure to add another subscription';
  static const String noMoreSubscriptionsBody =
      'Today\u2019s archive stays free. Pro is only for ongoing continuity, '
      'and you can manage it through the App Store.';

  static ({String title, String body}) forReason(
    PaywallRejectionReason reason,
  ) => switch (reason) {
    PaywallRejectionReason.notEnoughProof => (
      title: notEnoughProofTitle,
      body: notEnoughProofBody,
    ),
    PaywallRejectionReason.unclearProValue => (
      title: unclearProValueTitle,
      body: unclearProValueBody,
    ),
    PaywallRejectionReason.wantToTryLonger => (
      title: wantToTryLongerTitle,
      body: wantToTryLongerBody,
    ),
    PaywallRejectionReason.tooExpensive => (
      title: tooExpensiveTitle,
      body: tooExpensiveBody,
    ),
    PaywallRejectionReason.noMoreSubscriptions => (
      title: noMoreSubscriptionsTitle,
      body: noMoreSubscriptionsBody,
    ),
  };
}

/// Session and visibility gate for the follow-up block.
///
/// Guardrails by construction:
/// - Only a future paywall can show it: the stored reason is read once when
///   the paywall screen initializes, while capture happens later, during
///   dismissal — so the same flow that captured the reason never renders it.
/// - Never for Pro users, never without a stored reason, at most once per
///   app session.
class PaywallObjectionFollowUp {
  PaywallObjectionFollowUp({required PaywallSessionTracker sessionTracker})
    : _sessionTracker = sessionTracker;

  final PaywallSessionTracker _sessionTracker;

  bool shouldShow({
    required bool isPro,
    required PaywallRejectionReason? reason,
  }) => !isPro && reason != null && !_sessionTracker.objectionFollowUpShown;

  void markShown() => _sessionTracker.markShown();
}

/// Local persistence of the last paywall rejection — stable reason id,
/// timestamp, and optional paywall source id only. No user content, no
/// notes, no snippets; the payload is fixed-shape by construction.
class PaywallObjectionStore {
  PaywallObjectionStore({this._prefs, DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final MobilePrefsStore? _prefs;
  final DateTime Function() _now;

  static const String prefsKey = 'paywall_last_rejection';

  MobilePrefsStore? get _resolvedPrefs {
    if (_prefs != null) return _prefs;
    if (!AppServices.isInitialized) return null;
    return AppServices.instance.prefs;
  }

  /// Records the latest rejection, replacing any previous one.
  Future<void> recordRejection(
    PaywallRejectionReason reason, {
    String? source,
  }) async {
    final prefs = _resolvedPrefs;
    if (prefs == null) return;
    try {
      await prefs.writeMap(prefsKey, {
        'reason_id': reason.id,
        'created_at': _now().toIso8601String(),
        'source': ?source,
      });
    } catch (_) {
      // Persistence failures never surface — worst case the next paywall
      // shows no follow-up.
    }
  }

  /// The last captured reason, or null when none exists or the stored id is
  /// not one of the five stable reasons.
  Future<PaywallRejectionReason?> lastReason() async {
    final prefs = _resolvedPrefs;
    if (prefs == null) return null;
    try {
      final data = await prefs.readMap(prefsKey);
      final id = data?['reason_id'];
      return id is String ? PaywallRejectionReason.fromId(id) : null;
    } catch (_) {
      return null;
    }
  }
}
