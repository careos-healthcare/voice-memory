import '../first_session/two_day_activation_engine.dart';

/// Invited User Day 2 Return Copy — makes the second visit match the reason
/// the user was invited. Pure copy + gating only: no AI, no new flows, no
/// referrer identity, no archive content. Renders inside the existing
/// 2-day return moment and never blocks recording.
abstract class InvitedDayTwoReturn {
  InvitedDayTwoReturn._();

  // Default (also any unknown source).
  static const String defaultTitle = 'Your second check';
  static const String defaultBody =
      'See whether your first recording returned, faded, or changed.';

  // weekly_review
  static const String weeklyReviewTitle = 'Start your own weekly thread';
  static const String weeklyReviewBody =
      'See whether your first recording is beginning to return, fade, or '
      'change.';

  // thread_return
  static const String threadReturnTitle = 'Check whether it came back';
  static const String threadReturnBody =
      'ArchiveMe can help notice whether the same thread is showing up again.';

  // belief_distance
  static const String beliefDistanceTitle = 'Check what keeps showing up';
  static const String beliefDistanceBody =
      'See whether a phrase or feeling from your first recording is '
      'appearing again.';

  // proof_counter
  static const String proofCounterTitle = 'Start connecting evidence';
  static const String proofCounterBody =
      'A second recording can help ArchiveMe compare what is beginning to '
      'connect.';

  // pro_retention_yes
  static const String proRetentionYesTitle = 'Build your own archive';
  static const String proRetentionYesBody =
      'See whether your first recording returned, faded, or changed.';

  /// Single optional CTA into the existing recording/check flow.
  static const String ctaLabel = 'Check now';

  static String titleFor(String source) => switch (source) {
    'weekly_review' => weeklyReviewTitle,
    'thread_return' => threadReturnTitle,
    'belief_distance' => beliefDistanceTitle,
    'proof_counter' => proofCounterTitle,
    'pro_retention_yes' => proRetentionYesTitle,
    _ => defaultTitle,
  };

  static String bodyFor(String source) => switch (source) {
    'weekly_review' => weeklyReviewBody,
    'thread_return' => threadReturnBody,
    'belief_distance' => beliefDistanceBody,
    'proof_counter' => proofCounterBody,
    'pro_retention_yes' => proRetentionYesBody,
    _ => defaultBody,
  };

  /// Visible only when a first-touch invite attribution exists and the
  /// existing 2-day engine says the user is at the Day 2 return moment —
  /// so never before the first save and never once Day 2 is complete.
  static bool shouldShow({
    required String? inviteSource,
    required TwoDayActivationStage stage,
  }) => inviteSource != null && stage == TwoDayActivationStage.dayTwoReturn;
}
