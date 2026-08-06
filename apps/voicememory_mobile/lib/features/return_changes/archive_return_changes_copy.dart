import 'archive_return_changes_engine.dart';

/// Copy for the archive return-changes card — no pressure or certainty.
abstract final class ArchiveReturnChangesCopy {
  ArchiveReturnChangesCopy._();

  static const reviewChangesButton = 'Review changes';
  static const viewEvidenceMapButton = 'View evidence map';
  static const markSeenButton = 'Mark as seen';
  static const proPreviewLink =
      'Longer-term change history is where Pro becomes more useful.';

  static const newEvidenceTitle = 'Your archive has new evidence';
  static String newEvidenceBody(int count) =>
      'You added $count more moment${count == 1 ? '' : 's'} since your last review.';

  static const beliefUpdatedTitle = 'Your archive belief changed';
  static const beliefUpdatedBody =
      'ArchiveMe has more evidence to compare. Review what changed.';

  static const contextChangedTitle = 'Your evidence map changed';
  static const contextChangedBody =
      'Your moments now show up across more contexts.';

  static const weeklyReviewTitle = 'Your weekly review is ready';
  static const weeklyReviewBody =
      'ArchiveMe has enough evidence for a broader review.';

  static Iterable<String> allVisibleCopy() sync* {
    yield reviewChangesButton;
    yield viewEvidenceMapButton;
    yield markSeenButton;
    yield proPreviewLink;
    yield newEvidenceTitle;
    yield newEvidenceBody(1);
    yield newEvidenceBody(2);
    yield beliefUpdatedTitle;
    yield beliefUpdatedBody;
    yield contextChangedTitle;
    yield contextChangedBody;
    yield weeklyReviewTitle;
    yield weeklyReviewBody;
  }

  static String titleFor(ArchiveReturnChangeType type) => switch (type) {
    ArchiveReturnChangeType.newEvidence => newEvidenceTitle,
    ArchiveReturnChangeType.beliefUpdated => beliefUpdatedTitle,
    ArchiveReturnChangeType.contextChanged => contextChangedTitle,
    ArchiveReturnChangeType.weeklyReviewReady => weeklyReviewTitle,
  };

  static String bodyFor(ArchiveReturnChangeType type, {int newMoments = 1}) =>
      switch (type) {
        ArchiveReturnChangeType.newEvidence => newEvidenceBody(newMoments),
        ArchiveReturnChangeType.beliefUpdated => beliefUpdatedBody,
        ArchiveReturnChangeType.contextChanged => contextChangedBody,
        ArchiveReturnChangeType.weeklyReviewReady => weeklyReviewBody,
      };
}
