import 'package:flutter/foundation.dart';

/// Pro Retention Check — one optional, two-tap question for Pro users who
/// have genuinely seen a Pro-value surface: is the connected archive still
/// useful?
///
/// Guardrails by construction:
/// - Pro users only, and only after a real Pro-value surface rendered
///   (weekly review, belief distance, thread return evidence, or a proof
///   counter with connected recordings).
/// - Optional, no text input, once per session, never tied to cancellation
///   flows — subscription manage/cancel information stays exactly where it
///   already is.
/// - Answers are stable ids only; no private content is ever collected.
abstract final class ProRetentionCheck {
  ProRetentionCheck._();

  static const String title = 'Is Pro helping?';
  static const String question = 'Is the connected archive still useful?';
  static const String yesLabel = 'Yes';
  static const String notYetLabel = 'Not yet';

  static const String yesAck =
      'Thanks \u2014 we\u2019ll keep the archive focused on what changes '
      'over time.';
  static const String notYetAck =
      'Thanks \u2014 we\u2019ll keep this clearer and lighter.';

  /// Set when the check renders; at most one appearance per session.
  static bool shownThisSession = false;

  /// The stable card_type id of the strongest Pro-value surface the user
  /// can currently see, or null when none exists. Never user text.
  static String? valueSurfaceCardType({
    required bool hasWeeklyReview,
    required bool hasBeliefDistance,
    required bool hasThreadReturnEvidence,
    required bool hasConnectedProofCounter,
  }) {
    if (hasWeeklyReview) return 'weekly_review';
    if (hasBeliefDistance) return 'belief_distance';
    if (hasThreadReturnEvidence) return 'thread_return';
    if (hasConnectedProofCounter) return 'proof_counter';
    return null;
  }

  /// Free users never see the check; Pro users see it only after a real
  /// Pro-value surface exists, at most once per session.
  static bool shouldShow({required bool isPro, required String? cardType}) =>
      isPro && cardType != null && !shownThisSession;

  @visibleForTesting
  static void resetSessionForTest() => shownThisSession = false;
}
