import '../changes/change_resurfacing.dart';
import '../changes/change_thread.dart';
import '../changes/change_thread_projection.dart';
import '../memory/sensitive_surfacing_policy.dart';
import '../monetization/domain/access_policy_engine.dart';
import 'weekly_review.dart';
import 'weekly_review_access.dart';
import 'weekly_review_sufficiency.dart';

/// Builds at most one restrained weekly review from the Changes threads.
///
/// The engine never writes a sentence of its own about the user's life: every
/// item repeats a finding the thread already holds and carries that finding's
/// exact citations. It therefore cannot invent encouragement, advice, or a
/// milestone, because it has no vocabulary for any of them.
abstract final class WeeklyReviewEngine {
  WeeklyReviewEngine._();

  static WeeklyReviewOutcome build({
    required ChangeThreadProjection projection,
    required ChangeResurfacingContext archive,
    required EntitlementSnapshot entitlement,
    UsageSnapshot usage = const UsageSnapshot(),
  }) {
    // New generation follows the existing entitlement policy. A review that was
    // already generated is read through a different capability and is not
    // affected by this gate.
    final access = WeeklyReviewAccess.generation(
      entitlement: entitlement,
      usage: usage,
    );
    if (!access.allowed) {
      return const WeeklyReviewOutcome.withheld(
        shortfall: WeeklyReviewShortfall.generationNotPermitted,
        evidence: WeeklyReviewEvidence.none(),
      );
    }

    final windowEnd = archive.now.toUtc();
    final windowStart = windowEnd.subtract(WeeklyReviewSufficiency.window);
    final items = _selectItems(
      projection: projection,
      archive: archive,
      windowStart: windowStart,
      windowEnd: windowEnd,
    );
    final evidence = _measure(items);

    // The one place the sufficiency bar is enforced.
    final shortfall = WeeklyReviewSufficiency.shortfall(evidence);
    if (shortfall != null) {
      return WeeklyReviewOutcome.withheld(
        shortfall: shortfall,
        evidence: evidence,
      );
    }

    return WeeklyReviewOutcome.generated(
      WeeklyReview(
        reviewId: reviewIdFor(windowEnd),
        windowStart: windowStart,
        windowEnd: windowEnd,
        generatedAt: windowEnd,
        items: items,
      ),
    );
  }

  /// One review per week, addressed by the day the window closes, so
  /// regenerating the same week replaces it instead of stacking up.
  static String reviewIdFor(DateTime windowEnd) {
    final day = windowEnd.toUtc();
    final month = day.month.toString().padLeft(2, '0');
    final date = day.day.toString().padLeft(2, '0');
    return 'weekly_review_${day.year}_${month}_$date';
  }

  static WeeklyReviewEvidence _measure(List<WeeklyReviewItem> items) {
    final moments = {for (final item in items) ...item.sourceEntryIds};
    final days = <String>{};
    for (final item in items) {
      for (final citation in item.evidence) {
        final capturedAt =
            citation.sourceCapturedAt?.toUtc() ?? item.occurredAt;
        days.add('${capturedAt.year}-${capturedAt.month}-${capturedAt.day}');
      }
    }
    return WeeklyReviewEvidence(
      distinctSavedMoments: moments.length,
      distinctDays: days.length,
      itemCount: items.length,
    );
  }

  /// At most one item per kind, so the review stays a summary rather than a
  /// second copy of the Changes list.
  static List<WeeklyReviewItem> _selectItems({
    required ChangeThreadProjection projection,
    required ChangeResurfacingContext archive,
    required DateTime windowStart,
    required DateTime windowEnd,
  }) {
    final candidates = <WeeklyReviewItemKind, List<WeeklyReviewItem>>{};
    for (final view in projection.threads) {
      if (!view.thread.isVisible) continue;
      final eligible = view.events
          .where(
            (event) => _isEligible(
              event,
              archive: archive,
              windowStart: windowStart,
              windowEnd: windowEnd,
            ),
          )
          .toList(growable: false);
      if (eligible.isEmpty) continue;

      for (final event in eligible) {
        final kind = _kindFor(event.status);
        if (kind == null) continue;
        candidates
            .putIfAbsent(kind, () => [])
            .add(_itemFor(kind: kind, view: view, event: event));
      }

      final correctionKind = _correctionKindFor(view.thread.correctionState);
      if (correctionKind != null) {
        candidates
            .putIfAbsent(correctionKind, () => [])
            .add(
              _itemFor(kind: correctionKind, view: view, event: eligible.last),
            );
      }
    }

    return [
      for (final kind in WeeklyReviewItemKind.values)
        if (candidates[kind] case final list? when list.isNotEmpty)
          _strongest(list),
    ];
  }

  /// The item a kind is represented by: the widest evidence first, then the
  /// most recent, then a stable id so the same week always reads the same.
  static WeeklyReviewItem _strongest(List<WeeklyReviewItem> candidates) {
    final ordered = candidates.toList()
      ..sort((a, b) {
        final byMoments = b.sourceEntryIds.length.compareTo(
          a.sourceEntryIds.length,
        );
        if (byMoments != 0) return byMoments;
        final byDate = b.occurredAt.compareTo(a.occurredAt);
        if (byDate != 0) return byDate;
        return a.threadId.compareTo(b.threadId);
      });
    return ordered.first;
  }

  static WeeklyReviewItem _itemFor({
    required WeeklyReviewItemKind kind,
    required ChangeThreadView view,
    required ChangeEvent event,
  }) => WeeklyReviewItem(
    kind: kind,
    threadId: view.thread.threadId,
    threadLabel: view.thread.userEditableLabel,
    eventId: event.eventId,
    statement: event.statement,
    evidence: event.exactEvidence,
    occurredAt: event.occurredAt,
  );

  /// An event may be summarised only when it happened in the window, all of
  /// its sources still exist, and every source's surfacing choice allows a
  /// weekly review to mention it.
  static bool _isEligible(
    ChangeEvent event, {
    required ChangeResurfacingContext archive,
    required DateTime windowStart,
    required DateTime windowEnd,
  }) {
    final occurredAt = event.occurredAt.toUtc();
    if (occurredAt.isBefore(windowStart) || occurredAt.isAfter(windowEnd)) {
      return false;
    }
    return event.sourceEntryIds.every(
      (entryId) =>
          archive.liveEntryIds.contains(entryId) &&
          SensitiveSurfacingPolicy.evaluate(
                mode: archive.modeFor(entryId),
                surfaceType: MemorySurfaceType.weeklyReview,
              ) ==
              SensitiveSurfacingOutcome.allowed,
    );
  }

  static WeeklyReviewItemKind? _kindFor(ChangeThreadStatus status) =>
      switch (status) {
        ChangeThreadStatus.repeated => WeeklyReviewItemKind.repeated,
        ChangeThreadStatus.changed => WeeklyReviewItemKind.possibleChange,
        ChangeThreadStatus.weakened => WeeklyReviewItemKind.weakened,
        ChangeThreadStatus.strengthened => WeeklyReviewItemKind.strengthened,
        ChangeThreadStatus.unresolved => WeeklyReviewItemKind.unresolved,
        // A first sighting is not yet something that repeated or changed.
        ChangeThreadStatus.firstObserved => null,
      };

  static WeeklyReviewItemKind? _correctionKindFor(
    ChangeThreadCorrectionState state,
  ) => switch (state) {
    ChangeThreadCorrectionState.none => null,
    // A hidden thread is not in the projection, and a hidden framing is not
    // something to advertise back to the user.
    ChangeThreadCorrectionState.framingSuppressed => null,
    _ => WeeklyReviewItemKind.correction,
  };
}
