import '../activation/archive_evidence_map.dart';
import '../activation/weekly_archive_review.dart';
import 'archive_return_changes_copy.dart';
import 'archive_return_snapshot.dart';

enum ArchiveReturnChangeType {
  newEvidence,
  beliefUpdated,
  contextChanged,
  weeklyReviewReady,
}

/// Deterministic return card output from snapshot diff.
class ArchiveReturnChangesResult {
  const ArchiveReturnChangesResult({
    required this.type,
    required this.title,
    required this.body,
    required this.reviewRoute,
    required this.showProLine,
    this.newMomentsCount = 0,
  });

  final ArchiveReturnChangeType type;
  final String title;
  final String body;
  final String reviewRoute;
  final bool showProLine;
  final int newMomentsCount;
}

/// Compares last-seen and current archive metadata locally.
class ArchiveReturnChangesEngine {
  const ArchiveReturnChangesEngine();

  ArchiveReturnChangesResult? evaluate({
    required ArchiveReturnSnapshot? lastSeen,
    required ArchiveReturnSnapshot current,
  }) {
    if (current.entryCount < 2) return null;
    if (lastSeen == null) return null;

    final weeklyNew =
        current.weeklyReviewAvailable && !lastSeen.weeklyReviewAvailable;
    final beliefChanged = current.beliefSummaryHash.isNotEmpty &&
        lastSeen.beliefSummaryHash.isNotEmpty &&
        current.beliefSummaryHash != lastSeen.beliefSummaryHash;
    final newEvidence = current.entryCount > lastSeen.entryCount;
    final contextChanged = current.contextCount > lastSeen.contextCount;

    if (!weeklyNew && !beliefChanged && !newEvidence && !contextChanged) {
      return null;
    }

    final type = weeklyNew
        ? ArchiveReturnChangeType.weeklyReviewReady
        : beliefChanged
            ? ArchiveReturnChangeType.beliefUpdated
            : newEvidence
                ? ArchiveReturnChangeType.newEvidence
                : ArchiveReturnChangeType.contextChanged;

    final newMoments = newEvidence
        ? current.entryCount - lastSeen.entryCount
        : 0;

    return ArchiveReturnChangesResult(
      type: type,
      title: ArchiveReturnChangesCopy.titleFor(type),
      body: ArchiveReturnChangesCopy.bodyFor(
        type,
        newMoments: newMoments > 0 ? newMoments : 1,
      ),
      reviewRoute: _reviewRouteFor(type),
      showProLine: current.entryCount >= 5,
      newMomentsCount: newMoments,
    );
  }

  String _reviewRouteFor(ArchiveReturnChangeType type) => switch (type) {
        ArchiveReturnChangeType.weeklyReviewReady =>
          WeeklyArchiveReviewNavigation.route,
        ArchiveReturnChangeType.beliefUpdated => '/belief-changes',
        ArchiveReturnChangeType.newEvidence => '/archive-belief',
        ArchiveReturnChangeType.contextChanged => '/archive-belief',
      };
}
