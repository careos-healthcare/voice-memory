import '../../models/journal_entry.dart';
import '../explainable_conclusion/explainable_conclusion.dart';
import '../memory/memory_surfacing_mode.dart';
import '../memory/sensitive_surfacing_policy.dart';
import 'change_copy_numbers.dart';
import 'change_thread.dart';

/// Why a thread is being brought back into view.
enum ChangeResurfacingReason {
  firstAppeared,
  newMomentMayChange,
  userCorrected,
}

/// Why a thread was deliberately *not* brought back.
///
/// Each value maps to exactly one of the four gates in
/// [ChangeResurfacingPolicy.decide], so a refusal can always be attributed.
enum ChangeResurfacingRefusal {
  evidenceNotRelevant,
  sourceMissing,
  hiddenByUser,
  sensitivitySettings,
  nothingToSay,
}

/// One short line, bound to the exact moments that earn it.
class ChangeResurfacingNote {
  ChangeResurfacingNote({
    required this.threadId,
    required this.reason,
    required this.message,
    required Iterable<TranscriptEvidenceCitation> evidence,
  }) : evidence = List.unmodifiable(evidence),
       assert(threadId != ''),
       assert(message != ''),
       assert(
         evidence.isNotEmpty,
         'A resurfaced line must cite the moments behind it.',
       );

  final String threadId;
  final ChangeResurfacingReason reason;
  final String message;
  final List<TranscriptEvidenceCitation> evidence;

  Set<String> get sourceEntryIds =>
      evidence.map((citation) => citation.entryId).toSet();
}

class ChangeResurfacingDecision {
  const ChangeResurfacingDecision.shown(ChangeResurfacingNote this.note)
    : refusedBecause = null;

  const ChangeResurfacingDecision.refused(
    ChangeResurfacingRefusal this.refusedBecause,
  ) : note = null;

  final ChangeResurfacingNote? note;
  final ChangeResurfacingRefusal? refusedBecause;

  bool get isShown => note != null;
}

/// What the archive currently looks like, from the resurfacing gates' point of
/// view: which moments still exist, and how the user asked each to be treated.
class ChangeResurfacingContext {
  ChangeResurfacingContext({
    required Iterable<String> liveEntryIds,
    required Map<String, MemorySurfacingMode> surfacingModes,
    required this.now,
  }) : liveEntryIds = Set.unmodifiable(liveEntryIds),
       surfacingModes = Map.unmodifiable(surfacingModes);

  /// Builds the context from the archive's own moments. A deleted or archived
  /// moment is simply absent, so nothing can quote it.
  factory ChangeResurfacingContext.fromEntries(
    Iterable<JournalEntry> entries, {
    required DateTime now,
  }) {
    final live = entries.where(
      (entry) => !entry.isDeleted && !entry.isArchived,
    );
    return ChangeResurfacingContext(
      liveEntryIds: live.map((entry) => entry.id),
      surfacingModes: {
        for (final entry in live)
          entry.id: MemorySurfacingMode.fromEntry(entry),
      },
      now: now,
    );
  }

  final Set<String> liveEntryIds;
  final Map<String, MemorySurfacingMode> surfacingModes;
  final DateTime now;

  MemorySurfacingMode modeFor(String entryId) =>
      surfacingModes[entryId] ?? MemorySurfacingMode.normal;
}

/// Decides whether a thread may be surfaced again, and with which line.
///
/// This is evidence-based resurfacing, not nostalgia: nothing is shown for
/// being old, and every line names something the saved moments actually say.
abstract final class ChangeResurfacingPolicy {
  ChangeResurfacingPolicy._();

  /// Evidence older than this stops being a reason to interrupt the user.
  static const maximumEvidenceAge = Duration(days: 120);

  /// A finding counts as new — and so worth mentioning — for this long.
  static const newMomentWindow = Duration(days: 7);

  /// Below this age, "first appeared" would tell the user nothing they did
  /// not just live through.
  static const minimumThreadAge = Duration(days: 7);

  static ChangeResurfacingDecision decide(
    ChangeThreadView view, {
    required ChangeResurfacingContext context,
  }) {
    // 1. The user has not hidden it.
    if (!_userHasNotHiddenIt(view.thread)) {
      return const ChangeResurfacingDecision.refused(
        ChangeResurfacingRefusal.hiddenByUser,
      );
    }

    final latest = view.events.isEmpty ? null : view.events.last;
    // 2. The evidence is relevant: there is a cited finding, and it is recent
    //    enough that bringing it up is still about the user's present.
    if (latest == null || !_evidenceIsRelevant(latest, context)) {
      return const ChangeResurfacingDecision.refused(
        ChangeResurfacingRefusal.evidenceNotRelevant,
      );
    }

    // 3. The source still exists.
    if (!_sourceStillExists(latest, context)) {
      return const ChangeResurfacingDecision.refused(
        ChangeResurfacingRefusal.sourceMissing,
      );
    }

    // 4. Sensitivity settings permit it.
    if (!_sensitivitySettingsPermit(latest, context)) {
      return const ChangeResurfacingDecision.refused(
        ChangeResurfacingRefusal.sensitivitySettings,
      );
    }

    final message = _messageFor(view, latest, context);
    if (message == null) {
      return const ChangeResurfacingDecision.refused(
        ChangeResurfacingRefusal.nothingToSay,
      );
    }
    return ChangeResurfacingDecision.shown(
      ChangeResurfacingNote(
        threadId: view.thread.threadId,
        reason: message.reason,
        message: message.text,
        evidence: latest.exactEvidence,
      ),
    );
  }

  static ChangeResurfacingNote? noteFor(
    ChangeThreadView view, {
    required ChangeResurfacingContext context,
  }) => decide(view, context: context).note;

  static bool _userHasNotHiddenIt(ChangeThread thread) =>
      thread.isVisible &&
      thread.correctionState != ChangeThreadCorrectionState.framingSuppressed;

  static bool _evidenceIsRelevant(
    ChangeEvent latest,
    ChangeResurfacingContext context,
  ) {
    final age = context.now.difference(latest.occurredAt);
    return !age.isNegative && age <= maximumEvidenceAge;
  }

  static bool _sourceStillExists(
    ChangeEvent latest,
    ChangeResurfacingContext context,
  ) => latest.sourceEntryIds.every(context.liveEntryIds.contains);

  static bool _sensitivitySettingsPermit(
    ChangeEvent latest,
    ChangeResurfacingContext context,
  ) => latest.sourceEntryIds.every(
    (entryId) =>
        SensitiveSurfacingPolicy.evaluate(
          mode: context.modeFor(entryId),
          surfaceType: MemorySurfaceType.threadReturn,
        ) ==
        SensitiveSurfacingOutcome.allowed,
  );

  static ({ChangeResurfacingReason reason, String text})? _messageFor(
    ChangeThreadView view,
    ChangeEvent latest,
    ChangeResurfacingContext context,
  ) {
    if (_wasCorrected(view.thread.correctionState) ||
        _wasCorrected(latest.correctionState)) {
      return (
        reason: ChangeResurfacingReason.userCorrected,
        text: 'You corrected this interpretation.',
      );
    }
    final sinceLatest = context.now.difference(latest.occurredAt);
    if (view.events.length > 1 &&
        !sinceLatest.isNegative &&
        sinceLatest <= newMomentWindow) {
      return (
        reason: ChangeResurfacingReason.newMomentMayChange,
        text: 'A new moment may change this thread.',
      );
    }
    final age = context.now.difference(view.thread.firstObservedAt);
    if (age >= minimumThreadAge) {
      return (
        reason: ChangeResurfacingReason.firstAppeared,
        text: 'This pattern first appeared ${_weeksAgo(age)}.',
      );
    }
    return null;
  }

  static bool _wasCorrected(ChangeThreadCorrectionState state) =>
      switch (state) {
        ChangeThreadCorrectionState.none => false,
        ChangeThreadCorrectionState.framingSuppressed => false,
        _ => true,
      };

  static String _weeksAgo(Duration age) {
    final weeks = age.inDays ~/ 7;
    return weeks <= 1 ? 'one week ago' : '${spelledCount(weeks)} weeks ago';
  }
}
