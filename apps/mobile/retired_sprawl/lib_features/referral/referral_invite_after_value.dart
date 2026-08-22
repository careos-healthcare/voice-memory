import 'package:archiveme_mobile/features/memory/memory_scope_policy.dart';
import 'package:flutter/foundation.dart';

/// Referral Invite After Value — one calm, dismissible invite card shown
/// only after ArchiveMe has demonstrably shown value this session.
///
/// Guardrails by construction:
/// - Never before the first save, never with a single entry, never before
///   a real value moment, at most once per session.
/// - Suppressed for the session after a "Not quite" feedback response —
///   an invite right after doubt would be tone-deaf.
/// - The invite text is a compile-time constant: no snippets, notes,
///   terms, counts, or value-card content can enter it.
/// - Copy-to-clipboard only — no social feed, no public posting, no
///   rewards, no leaderboard.
abstract class ReferralInviteAfterValue {
  ReferralInviteAfterValue._();

  static const String title = 'Know someone who might use this?';
  static const String body =
      'You can invite them without sharing anything from your archive.';
  static const String ctaLabel = 'Copy invite';
  static const String dismissLabel = 'Not now';
  static const String copiedConfirmation = 'Invite copied.';

  // --- Referral proof moment ---
  // One fixed line above the invite body naming the kind of value moment
  // that earned the invite. Compile-time constants chosen only by the
  // stable source id — no archive content, snippets, counts, or source
  // terms can enter them.

  static const String defaultProofLine = 'ArchiveMe has started showing value.';
  static const String weeklyReviewProofLine =
      'Your weekly review showed what returned, faded, or changed.';
  static const String threadReturnProofLine =
      'ArchiveMe noticed a thread coming back.';
  static const String beliefDistanceProofLine =
      'ArchiveMe noticed a phrase pattern showing up again.';
  static const String proofCounterProofLine =
      'Your archive started connecting recordings.';
  static const String proRetentionProofLine =
      'Pro helped keep the archive connected over time.';

  /// Resolves the proof line for a stable referral source id. Unknown or
  /// empty sources fall back to the default line — no dynamic text exists.
  static String proofLineFor(String source) {
    switch (source) {
      case 'weekly_review':
        return weeklyReviewProofLine;
      case 'thread_return':
        return threadReturnProofLine;
      case 'belief_distance':
        return beliefDistanceProofLine;
      case 'proof_counter':
        return proofCounterProofLine;
      case 'pro_retention_yes':
        return proRetentionProofLine;
    }
    return defaultProofLine;
  }

  /// The default invite text — fixed copy only, never personalized.
  static const String inviteText =
      'I\u2019m testing ArchiveMe \u2014 it helps you record one small thing '
      'and notice what keeps returning, fading, or changing over time. It '
      'does not share your archive. Want to try it?';

  // Source-specific invite variants. Every one is a compile-time constant
  // describing only what the product does — never the user's archive. No
  // numbers, snippets, source terms, or raw user text can enter these.
  static const String weeklyReviewInviteText =
      'I\u2019m testing ArchiveMe. It helped me notice what returned, faded, '
      'or changed this week \u2014 without sharing my archive. Want to try '
      'it?';
  static const String threadReturnInviteText =
      'I\u2019m testing ArchiveMe. It helps you notice when the same thread '
      'keeps coming back \u2014 without sharing your archive. Want to try '
      'it?';
  static const String beliefDistanceInviteText =
      'I\u2019m testing ArchiveMe. It helps you notice belief-like phrases '
      'that keep showing up \u2014 without sharing your archive. Want to try '
      'it?';
  static const String proofCounterInviteText =
      'I\u2019m testing ArchiveMe. It helps you see when separate recordings '
      'start connecting \u2014 without sharing your archive. Want to try it?';
  static const String proRetentionInviteText =
      'I\u2019m testing ArchiveMe. It helps keep an archive of what returns, '
      'fades, and changes over time \u2014 without sharing anything private. '
      'Want to try it?';

  /// Resolves the invite text for a stable referral source id. Unknown or
  /// empty sources fall back to the default invite — there is no path that
  /// produces dynamic text.
  static String inviteTextFor(String source) {
    switch (source) {
      case 'weekly_review':
        return weeklyReviewInviteText;
      case 'thread_return':
        return threadReturnInviteText;
      case 'belief_distance':
        return beliefDistanceInviteText;
      case 'proof_counter':
        return proofCounterInviteText;
      case 'pro_retention_yes':
        return proRetentionInviteText;
    }
    return inviteText;
  }

  // --- Invite attribution link ---

  /// The production invite landing URL. Single config constant — no other
  /// URL can be generated.
  static const String inviteBaseUrl = 'https://archiveme.app/invite';

  /// Fixed referral channel id appended to every invite link.
  static const String inviteRef = 'archive_invite';

  /// The only source ids that can ever appear in an invite link.
  static const Set<String> stableSources = {
    'weekly_review',
    'thread_return',
    'belief_distance',
    'proof_counter',
    'pro_retention_yes',
  };

  /// Clamps any source to the stable whitelist; everything else becomes
  /// `default`. No user id, entry count, timestamp, email, or any other
  /// personal data has a path into the link.
  static String linkSource(String source) =>
      stableSources.contains(source) ? source : 'default';

  /// The attribution link for a source — fixed base URL, fixed ref, and a
  /// whitelisted source id. Nothing dynamic can enter it.
  static String inviteLinkFor(String source) =>
      '$inviteBaseUrl?ref=$inviteRef&source=${linkSource(source)}';

  /// The full text written to the clipboard: the source-specific invite
  /// copy with the attribution link appended on its own line.
  static String copiedInviteTextFor(String source) =>
      '${inviteTextFor(source)}\n${inviteLinkFor(source)}';

  // --- Session state ---

  /// Set when the card renders; at most one appearance per session.
  static bool shownThisSession = false;

  /// Set when the user taps "Not now"; hides the card for the session.
  static bool dismissedThisSession = false;

  static String? _usefulYesSource;
  static bool _notQuiteThisSession = false;
  static bool _proRetentionYes = false;

  static final _Revision _revision = _Revision();

  /// Notifies when session value signals change, so an already-built
  /// surface can re-evaluate (e.g. show the card right after a useful-yes).
  static Listenable get changes => _revision;

  /// Called by the value-card feedback row. A useful-yes becomes a trigger
  /// source; a "Not quite" suppresses the invite for the session.
  static void recordValueFeedback({
    required String cardType,
    required bool useful,
  }) {
    if (useful) {
      _usefulYesSource ??= sourceForFeedbackCardType(cardType);
    } else {
      _notQuiteThisSession = true;
    }
    _revision.bump();
  }

  /// Called when a Pro user answers Yes on the Pro retention check.
  static void recordProRetentionYes() {
    _proRetentionYes = true;
    _revision.bump();
  }

  /// Maps a feedback-row card type to the referral's stable source id;
  /// unknown card types never become a trigger.
  static String? sourceForFeedbackCardType(String cardType) {
    switch (cardType) {
      case 'weekly_thread_review':
        return 'weekly_review';
      case 'thread_return_evidence':
        return 'thread_return';
      case 'belief_distance':
        return 'belief_distance';
      case 'archive_proof_counter':
        return 'proof_counter';
    }
    return null;
  }

  /// The stable source id of the strongest current value moment, or null
  /// when none exists yet. Explicit user signals win over passive ones.
  static String? sourceFor({
    required int entryCount,
    required bool hasWeeklyReview,
    required bool hasConnectedProofCounter,
  }) {
    if (entryCount <= 1) return null;
    if (_usefulYesSource != null) return _usefulYesSource;
    if (_proRetentionYes) return 'pro_retention_yes';
    if (hasWeeklyReview) return 'weekly_review';
    if (hasConnectedProofCounter) return 'proof_counter';
    return null;
  }

  static bool shouldShow({
    required int entryCount,
    required bool hasWeeklyReview,
    required bool hasConnectedProofCounter,
  }) =>
      // Memory off: referral proof moments ride on memory-based value
      // moments, so they never appear while connections are paused.
      MemoryScopePolicy.memoryClaimsAllowed &&
      !shownThisSession &&
      !dismissedThisSession &&
      !_notQuiteThisSession &&
      sourceFor(
            entryCount: entryCount,
            hasWeeklyReview: hasWeeklyReview,
            hasConnectedProofCounter: hasConnectedProofCounter,
          ) !=
          null;

  @visibleForTesting
  static void resetSessionForTest() {
    shownThisSession = false;
    dismissedThisSession = false;
    _usefulYesSource = null;
    _notQuiteThisSession = false;
    _proRetentionYes = false;
  }
}

class _Revision extends ChangeNotifier {
  void bump() => notifyListeners();
}