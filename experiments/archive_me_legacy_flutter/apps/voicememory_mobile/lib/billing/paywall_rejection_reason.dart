import 'package:flutter/foundation.dart';

/// Why a user backed out of the Pro paywall — the five purchase blockers we
/// want to size. Ids are stable snake_case, safe to log; labels are the
/// consumer-facing option text.
enum PaywallRejectionReason {
  notEnoughProof(id: 'not_enough_proof', label: 'Not enough proof yet'),
  tooExpensive(id: 'too_expensive', label: 'Too expensive'),
  noMoreSubscriptions(
    id: 'no_more_subscriptions',
    label: 'I do not want another subscription',
  ),
  unclearProValue(
    id: 'unclear_pro_value',
    label: 'I am not sure what Pro adds',
  ),
  wantToTryLonger(id: 'want_to_try_longer', label: 'I want to try longer');

  const PaywallRejectionReason({required this.id, required this.label});

  /// Stable id, safe to log/persist. Never user text.
  final String id;

  final String label;

  static PaywallRejectionReason? fromId(String? id) {
    if (id == null) return null;
    for (final reason in PaywallRejectionReason.values) {
      if (reason.id == id) return reason;
    }
    return null;
  }
}

/// Consumer copy for the one-tap rejection prompt.
abstract class PaywallRejectionPromptCopy {
  PaywallRejectionPromptCopy._();

  static const String title = 'What held you back?';
  static const String subtitle = 'One tap helps us make ArchiveMe clearer.';
  static const String skipLabel = 'Not today';
  static const String thanksLine =
      'Thanks \u2014 we\u2019ll keep improving this.';
}

/// Session gate for the rejection prompt: shown at most once per app session,
/// never to Pro users (which also covers the just-purchased state).
abstract class PaywallRejectionCapture {
  PaywallRejectionCapture._();

  static bool promptShownThisSession = false;

  static bool shouldPrompt({required bool isPro}) =>
      !isPro && !promptShownThisSession;

  @visibleForTesting
  static void resetSessionForTest() {
    promptShownThisSession = false;
  }
}
