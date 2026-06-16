import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../services/activation_funnel_analytics.dart';
import '../../services/app_services.dart';
import 'invite_attribution.dart';
import 'referral_invite_after_value.dart';

/// Invite Funnel Metrics — the invited-user mirror of the core funnel:
/// copied invite → attributed open → first save → Day 2 → value moment →
/// Pro bridge → paywall → purchase.
///
/// Rules by construction:
/// - Every invited event fires only when a locally persisted first-touch
///   invite attribution exists; without it this whole module is silent.
/// - Invited events are additive — the normal funnel events are untouched.
/// - Payloads carry only the whitelisted keys (`source`, `entry_count`,
///   `stage`, `card_type`) with stable ids. The invite URL, referrer
///   identity, and archive content have no path in.
abstract class InviteFunnelMetrics {
  InviteFunnelMetrics._();

  static const String invitedAppOpened =
      ActivationFunnelAnalytics.invitedAppOpened;
  static const String invitedRecordCtaTapped =
      ActivationFunnelAnalytics.invitedRecordCtaTapped;
  static const String invitedFirstSave =
      ActivationFunnelAnalytics.invitedFirstSave;
  static const String invitedDay2ReturnSeen =
      ActivationFunnelAnalytics.invitedDay2ReturnSeen;
  static const String invitedValueMomentSeen =
      ActivationFunnelAnalytics.invitedValueMomentSeen;
  static const String invitedProBridgeTapped =
      ActivationFunnelAnalytics.invitedProBridgeTapped;
  static const String invitedPaywallSeen =
      ActivationFunnelAnalytics.invitedPaywallSeen;
  static const String invitedPurchaseStarted =
      ActivationFunnelAnalytics.invitedPurchaseStarted;
  static const String invitedPurchaseCompleted =
      ActivationFunnelAnalytics.invitedPurchaseCompleted;

  /// The only card_type ids an invited value-moment event can carry.
  static const Set<String> stableCardTypes = {
    'thread_return',
    'belief_distance',
    'weekly_review',
    'proof_counter',
  };

  static InviteAttributionStore? _storeOverride;
  static String? _cachedSource;
  static bool _loaded = false;
  static final Set<String> _firedThisSession = <String>{};

  /// The first-touch invite source (`weekly_review` … `default`), or null
  /// when no invite attribution exists. Cached after the first read.
  static Future<String?> currentSource() async {
    if (_loaded) return _cachedSource;
    final store =
        _storeOverride ??
        (AppServices.isInitialized ? InviteAttributionStore() : null);
    if (store == null) return null;
    final attribution = await store.firstTouch();
    _cachedSource = attribution == null
        ? null
        : ReferralInviteAfterValue.linkSource(attribution.source);
    _loaded = true;
    return _cachedSource;
  }

  /// Normalizes a host card id to a stable invited card_type. Accepts both
  /// the stable ids and the existing value-card feedback ids; anything
  /// else returns null and the event is dropped.
  static String? normalizeCardType(String cardType) {
    if (stableCardTypes.contains(cardType)) return cardType;
    return ReferralInviteAfterValue.sourceForFeedbackCardType(cardType);
  }

  // --- Funnel hooks (all additive, all attribution-gated) ---

  static void appOpened() => _trackInvited(invitedAppOpened, once: true);

  static void recordCtaTapped({int? entryCount}) =>
      _trackInvited(invitedRecordCtaTapped, entryCount: entryCount);

  /// The very first save of an invited user — at most once.
  static void firstSave() =>
      _trackInvited(invitedFirstSave, entryCount: 1, once: true);

  /// The existing Day 2 return stage rendered for an invited user.
  static void dayTwoReturnSeen() =>
      _trackInvited(invitedDay2ReturnSeen, stage: 'day_2', once: true);

  /// Any value card rendered for an invited user — once per card type per
  /// session, stable card_type only.
  static void valueMomentSeen(String cardType) {
    final normalized = normalizeCardType(cardType);
    if (normalized == null) return;
    _trackInvited(invitedValueMomentSeen, cardType: normalized, once: true);
  }

  static void proBridgeTapped(String cardType) {
    _trackInvited(
      invitedProBridgeTapped,
      cardType: normalizeCardType(cardType),
    );
  }

  static void paywallSeen() => _trackInvited(invitedPaywallSeen, once: true);

  static void purchaseStarted() => _trackInvited(invitedPurchaseStarted);

  static void purchaseCompleted() => _trackInvited(invitedPurchaseCompleted);

  /// Fires [event] with the invite source when attribution exists. Sync
  /// when the source is already cached so widget builds emit immediately;
  /// otherwise resolves first and then emits.
  static void _trackInvited(
    String event, {
    int? entryCount,
    String? stage,
    String? cardType,
    bool once = false,
  }) {
    if (_loaded) {
      _emit(
        event,
        entryCount: entryCount,
        stage: stage,
        cardType: cardType,
        once: once,
      );
      return;
    }
    unawaited(
      currentSource().then(
        (_) => _emit(
          event,
          entryCount: entryCount,
          stage: stage,
          cardType: cardType,
          once: once,
        ),
      ),
    );
  }

  static void _emit(
    String event, {
    int? entryCount,
    String? stage,
    String? cardType,
    bool once = false,
  }) {
    final source = _cachedSource;
    if (source == null) return;
    if (once && !_firedThisSession.add('$event|${cardType ?? ''}')) return;
    ActivationFunnelAnalytics.track(
      event,
      source: source,
      entryCount: entryCount,
      stage: stage,
      cardType: cardType,
    );
  }

  /// Injects an attribution store for tests (bypasses AppServices).
  @visibleForTesting
  static void overrideStoreForTest(InviteAttributionStore? store) {
    _storeOverride = store;
  }

  @visibleForTesting
  static void resetForTest() {
    _storeOverride = null;
    _cachedSource = null;
    _loaded = false;
    _firedThisSession.clear();
  }
}
