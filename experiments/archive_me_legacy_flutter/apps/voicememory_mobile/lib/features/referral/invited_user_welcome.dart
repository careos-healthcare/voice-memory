import 'package:flutter/foundation.dart';

import '../../product/core_product_vision.dart';

/// Invited User Welcome — one lightweight, dismissible welcome card for
/// users whose install carries a first-touch invite attribution. Tailors
/// the framing to the value moment that triggered the invite.
///
/// Guardrails by construction:
/// - Only a locally persisted `ref=archive_invite` first touch can show it.
/// - Only before the first save; gone forever once an entry exists.
/// - At most once per session; "Not now" hides it.
/// - The referrer is never identified — no name, no id, no hint.
/// - All copy is cautious ("can help notice") — never a promise that the
///   app will definitely find anything.
abstract class InvitedUserWelcome {
  InvitedUserWelcome._();

  static const String defaultTitle = 'You were invited to try ArchiveMe';
  static const String defaultBody = CoreProductVision.valueProposition;

  static const String weeklyReviewTitle =
      'You were invited after a weekly review';
  static const String weeklyReviewBody =
      '${CoreProductVision.valueProposition} Start with one small recording.';

  static const String threadReturnTitle =
      'You were invited because a thread came back';
  static const String threadReturnBody =
      '${CoreProductVision.valueProposition} Start with one small recording.';

  static const String beliefDistanceTitle =
      'You were invited because something kept showing up';
  static const String beliefDistanceBody =
      '${CoreProductVision.valueProposition} Start with one small recording.';

  static const String proofCounterTitle =
      'You were invited after recordings started connecting';
  static const String proofCounterBody =
      '${CoreProductVision.valueProposition} Start with one small recording.';

  static const String proRetentionTitle =
      'You were invited by someone using ArchiveMe';
  static const String proRetentionBody =
      '${CoreProductVision.valueProposition} Start with one small recording.';

  static const String ctaLabel = 'Record one small thing';
  static const String dismissLabel = 'Not now';

  /// Title for a stable invite source id; unknown sources get the default.
  static String titleFor(String source) {
    switch (source) {
      case 'weekly_review':
        return weeklyReviewTitle;
      case 'thread_return':
        return threadReturnTitle;
      case 'belief_distance':
        return beliefDistanceTitle;
      case 'proof_counter':
        return proofCounterTitle;
      case 'pro_retention_yes':
        return proRetentionTitle;
    }
    return defaultTitle;
  }

  /// Body for a stable invite source id; unknown sources get the default.
  static String bodyFor(String source) {
    switch (source) {
      case 'weekly_review':
        return weeklyReviewBody;
      case 'thread_return':
        return threadReturnBody;
      case 'belief_distance':
        return beliefDistanceBody;
      case 'proof_counter':
        return proofCounterBody;
      case 'pro_retention_yes':
        return proRetentionBody;
    }
    return defaultBody;
  }

  // --- Session state ---

  /// Set when the card surfaces; at most one appearance per session.
  static bool shownThisSession = false;

  /// Set when the welcome CTA started the current recording — attributes
  /// the very first save to the welcome card.
  static bool startedFromWelcomeThisSession = false;

  /// The attribution source of the welcome shown this session, for the
  /// first-save attribution event. Stable id only.
  static String? sessionSource;

  /// Eligible only before the first save and once per session. The
  /// attribution requirement is enforced by the caller (the card is only
  /// loaded when a first-touch attribution exists).
  static bool shouldShow({required int entryCount}) =>
      entryCount == 0 && !shownThisSession;

  @visibleForTesting
  static void resetSessionForTest() {
    shownThisSession = false;
    startedFromWelcomeThisSession = false;
    sessionSource = null;
  }
}
