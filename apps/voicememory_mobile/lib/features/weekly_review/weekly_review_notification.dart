import 'weekly_review.dart';

/// A notification body that has never seen the user's words.
class WeeklyReviewNotification {
  const WeeklyReviewNotification({
    required this.reviewId,
    required this.title,
    required this.body,
  });

  final String reviewId;
  final String title;
  final String body;
}

/// Whether ArchiveMe may say a weekly review exists, and in what words.
///
/// The user opts in; nothing is sent otherwise. The title and body are fixed
/// constants, so no quote, statement, thread label, or date can reach the lock
/// screen — the notification says a review exists and nothing about its
/// contents.
abstract final class WeeklyReviewNotificationPolicy {
  WeeklyReviewNotificationPolicy._();

  /// Notifications stay off until the user turns them on.
  static const defaultOptedIn = false;

  static const title = 'Your week is ready';
  static const body = 'Open ArchiveMe when you want to look.';

  static WeeklyReviewNotification? notificationFor({
    required WeeklyReview? review,
    required bool userOptedIn,
    String? lastNotifiedReviewId,
  }) {
    if (!userOptedIn) return null;
    if (review == null) return null;
    // One notification per generated review, never a nudge for an old one.
    if (lastNotifiedReviewId == review.reviewId) return null;
    return WeeklyReviewNotification(
      reviewId: review.reviewId,
      title: title,
      body: body,
    );
  }

  /// True when [notification] carries none of [review]'s own words.
  ///
  /// The constants above already guarantee this; the check exists so a future
  /// edit that interpolates a statement or a quote fails a test rather than a
  /// user's lock screen.
  static bool carriesNoJournalText(
    WeeklyReviewNotification notification,
    WeeklyReview review,
  ) {
    final text = '${notification.title} ${notification.body}'.toLowerCase();
    for (final item in review.items) {
      for (final fragment in [
        item.statement,
        item.threadLabel,
        ...item.evidence.map((citation) => citation.quote),
      ]) {
        final trimmed = fragment.trim().toLowerCase();
        if (trimmed.isNotEmpty && text.contains(trimmed)) return false;
      }
    }
    return true;
  }
}
