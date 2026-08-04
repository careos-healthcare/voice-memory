import '../../models/journal_entry.dart';
import '../explainable_conclusion/auditable_conclusion_trust_policy.dart';
import '../explainable_conclusion/auditable_personal_change_engine.dart';
import '../explainable_conclusion/change_dimensions.dart';
import '../explainable_conclusion/explainable_conclusion.dart';
import '../insight_feedback/insight_feedback_models.dart';
import 'change_thread.dart';
import 'change_thread_correction.dart';
import 'change_thread_identity.dart';

class ChangeThreadProjection {
  ChangeThreadProjection({
    required Iterable<ChangeThreadView> threads,
    required Iterable<ChangeEvent> ungroupedEvents,
    required this.policyVersion,
  }) : threads = List.unmodifiable(threads),
       ungroupedEvents = List.unmodifiable(ungroupedEvents);

  const ChangeThreadProjection.empty()
    : threads = const [],
      ungroupedEvents = const [],
      policyVersion = ChangeThreadProjector.policyVersion;

  /// Visible threads, most recently active first.
  final List<ChangeThreadView> threads;

  /// Findings ArchiveMe could not confidently place. They are kept as
  /// `unresolved` rather than pushed into a thread they may not belong to.
  final List<ChangeEvent> ungroupedEvents;

  final String policyVersion;

  List<ChangeEvent> get allEvents => [
    for (final view in threads) ...view.events,
    ...ungroupedEvents,
  ];

  ChangeThreadView? byId(String threadId) =>
      threads.where((view) => view.thread.threadId == threadId).firstOrNull;
}

/// Turns validated conclusions into stable threads the user can follow.
///
/// Every finding still has to clear the production trust policy first, so a
/// thread never contains a claim the exact-evidence validator or the semantic
/// gate would have refused. What this adds is continuity: the same recurring
/// issue lands on one thread instead of producing a fresh unrelated card each
/// time it comes back.
abstract final class ChangeThreadProjector {
  static const policyVersion = 'change_threads_v1';

  static ChangeThreadProjection project({
    required String archiveId,
    required List<JournalEntry> entries,
    required Iterable<ExplainableConclusion> conclusions,
    Iterable<InsightFeedbackRecord> feedback = const [],
    Iterable<ChangeThreadCorrection> corrections = const [],
    Iterable<ChangeThread> existingThreads = const [],
  }) {
    // Threads are archive-scoped. An entry stamped with another archive is
    // treated as absent, never merely hidden, so no thread can quote it.
    final owned = entries
        .where((entry) => _belongsTo(entry, archiveId))
        .toList(growable: false);
    final usable = owned
        .where((entry) => !entry.isArchived && !entry.isDeleted)
        .toList(growable: false);
    final transcripts = {
      for (final entry in usable) entry.id: entry.transcript,
    };
    // An app-authored placeholder (audio-only save, recovered recording) is
    // not the user's words. The ledger must never quote one as proof.
    final generatedTextEntryIds = owned
        .where(AuditablePersonalChangeEngine.holdsGeneratedPlaceholder)
        .map((entry) => entry.id)
        .toSet();
    final deletedEntryIds = owned
        .where((entry) => entry.isDeleted)
        .map((entry) => entry.id)
        .toSet();
    final entryThreadIds = {
      for (final entry in usable) entry.id: entry.archiveThreadId,
    };

    final drafts = <_EventDraft>[];
    final seen = <String>{};
    for (final candidate in conclusions) {
      if (!seen.add(candidate.id)) continue;
      final ranked = AuditableConclusionTrustPolicy.rankBest(
        candidates: [candidate],
        canonicalTranscripts: transcripts,
        feedback: feedback,
        entryThreadIds: entryThreadIds,
        deletedEntryIds: deletedEntryIds,
        generatedTextEntryIds: generatedTextEntryIds,
      );
      if (ranked == null) continue;
      final draft = _draftFor(ranked);
      if (draft != null) drafts.add(draft);
    }
    drafts.sort((a, b) {
      final byDate = a.occurredAt.compareTo(b.occurredAt);
      return byDate != 0 ? byDate : a.conclusion.id.compareTo(b.conclusion.id);
    });

    final threads = <String, ChangeThread>{
      for (final thread in existingThreads)
        if (thread.archiveId == archiveId) thread.threadId: thread,
    };
    final observedDimensions = <String, Set<ChangeDimension>>{};
    final events = <String, List<ChangeEvent>>{};
    final ungrouped = <ChangeEvent>[];

    for (final draft in drafts) {
      final resolution = ChangeThreadIdentity.resolve(
        threads: threads.values,
        subjectMarkers: draft.subjectMarkers,
        dimensions: draft.changedDimensions.toSet(),
        observedDimensions: observedDimensions,
      );
      if (draft.subjectMarkers.isEmpty || resolution.ambiguous) {
        ungrouped.add(
          draft.toEvent(threadId: '', status: ChangeThreadStatus.unresolved),
        );
        continue;
      }
      final matchedId = resolution.match?.threadId;
      final threadId =
          matchedId ?? ChangeThreadIdentity.mint(draft.subjectMarkers);
      final existing = threads[threadId];
      final status = _statusFor(
        draft,
        threadHasPriorEvents: events[threadId]?.isNotEmpty ?? false,
      );
      final event = draft.toEvent(threadId: threadId, status: status);
      events.putIfAbsent(threadId, () => []).add(event);
      observedDimensions
          .putIfAbsent(threadId, () => <ChangeDimension>{})
          .addAll(draft.changedDimensions);
      final subject = {
        ...?existing?.subjectRepresentation,
        ...draft.subjectMarkers,
      };
      threads[threadId] = ChangeThread(
        threadId: threadId,
        archiveId: archiveId,
        userEditableLabel: existing?.labelIsUserConfirmed == true
            ? existing!.userEditableLabel
            : ChangeThreadIdentity.labelFor(subject, fallback: threadId),
        subjectRepresentation: subject,
        // A comparison reaches back to its Then side, so the thread starts on
        // the earliest moment it actually quotes, not on the day it was drawn.
        firstObservedAt: existing == null
            ? draft.firstObservedAt
            : (existing.firstObservedAt.isBefore(draft.firstObservedAt)
                  ? existing.firstObservedAt
                  : draft.firstObservedAt),
        latestObservedAt: draft.occurredAt,
        currentStatus: status,
        evidenceEventIds: events[threadId]!
            .map((item) => item.eventId)
            .toList(growable: false),
        correctionState:
            existing?.correctionState ?? ChangeThreadCorrectionState.none,
        visibilityState:
            existing?.visibilityState ?? ChangeThreadVisibility.visible,
        policyVersion: policyVersion,
        labelIsUserConfirmed: existing?.labelIsUserConfirmed ?? false,
      );
    }

    // Threads that were carried in but produced no event this pass still
    // exist for the user; their history did not stop being true.
    for (final thread in threads.values) {
      events.putIfAbsent(thread.threadId, () => []);
    }

    return _applyCorrections(
      archiveId: archiveId,
      threads: threads,
      events: events,
      ungrouped: ungrouped,
      corrections: corrections,
    );
  }

  static bool _belongsTo(JournalEntry entry, String archiveId) =>
      entry.ownerArchiveId == archiveId;

  static _EventDraft? _draftFor(RankedAuditableConclusion ranked) {
    final conclusion = ranked.conclusion.value;
    final supporting = <String, TranscriptEvidenceCitation>{};
    for (final citation in conclusion.evidence) {
      if (citation.role == TranscriptEvidenceRole.supporting) {
        supporting.putIfAbsent(citation.entryId, () => citation);
      }
    }
    if (supporting.isEmpty) return null;
    final dates = supporting.values
        .map((citation) => citation.sourceCapturedAt)
        .whereType<DateTime>()
        .toList(growable: false);
    if (dates.length != supporting.length) return null;
    dates.sort();

    final shared = ranked.dimensions.sharedSubjectMarkers;
    final subject = shared.isNotEmpty
        ? shared
        : _sharedSubjectOf(supporting.values);
    return _EventDraft(
      conclusion: conclusion,
      evidence: supporting.values.toList(growable: false),
      subjectMarkers: subject,
      changedDimensions: ranked.dimensions.changed
          .map((movement) => movement.dimension)
          .toList(growable: false),
      directions: ranked.dimensions.changed
          .map((movement) => movement.direction)
          .toList(growable: false),
      occurredAt: dates.last.toUtc(),
      firstObservedAt: dates.first.toUtc(),
    );
  }

  /// What the cited moments are about when the comparison did not say.
  ///
  /// A single-source observation contributes its own markers; several sources
  /// must agree, so an unrelated pair contributes nothing and stays out of
  /// every thread.
  static Set<String> _sharedSubjectOf(
    Iterable<TranscriptEvidenceCitation> evidence,
  ) {
    Set<String>? shared;
    for (final citation in evidence) {
      final markers = ChangeDimensionReader.subjectMarkers(citation.quote);
      shared = shared == null ? markers : shared.intersection(markers);
    }
    return shared ?? const {};
  }

  static ChangeThreadStatus _statusFor(
    _EventDraft draft, {
    required bool threadHasPriorEvents,
  }) => switch (draft.conclusion.kind) {
    ExplainableInsightKind.observation =>
      threadHasPriorEvents
          ? ChangeThreadStatus.repeated
          : ChangeThreadStatus.firstObserved,
    ExplainableInsightKind.pattern => ChangeThreadStatus.repeated,
    ExplainableInsightKind.change => _changeStatus(draft.directions),
  };

  static ChangeThreadStatus _changeStatus(List<DimensionDirection> directions) {
    if (directions.isEmpty) return ChangeThreadStatus.unresolved;
    final up = directions
        .where((direction) => direction == DimensionDirection.increased)
        .length;
    final down = directions
        .where((direction) => direction == DimensionDirection.decreased)
        .length;
    if (up > 0 && down == 0) return ChangeThreadStatus.strengthened;
    if (down > 0 && up == 0) return ChangeThreadStatus.weakened;
    if (up == 0 && down == 0) return ChangeThreadStatus.changed;
    return ChangeThreadStatus.unresolved;
  }

  static ChangeThreadProjection _applyCorrections({
    required String archiveId,
    required Map<String, ChangeThread> threads,
    required Map<String, List<ChangeEvent>> events,
    required List<ChangeEvent> ungrouped,
    required Iterable<ChangeThreadCorrection> corrections,
  }) {
    final working = Map<String, ChangeThread>.from(threads);
    final byThread = {
      for (final entry in events.entries)
        entry.key: List<ChangeEvent>.from(entry.value),
    };
    final loose = List<ChangeEvent>.from(ungrouped);
    final ordered = corrections.toList()..sort((a, b) => a.at.compareTo(b.at));

    for (final correction in ordered) {
      final target = working[correction.threadId];
      if (target == null) continue;
      switch (correction) {
        case RenameChangeThread(:final label):
          final trimmed = label.trim();
          if (trimmed.isEmpty) break;
          working[target.threadId] = target.copyWith(
            userEditableLabel: trimmed,
            correctionState: ChangeThreadCorrectionState.renamed,
            labelIsUserConfirmed: true,
          );
        case SplitChangeThread(:final eventIds, :final newLabel):
          final source = byThread[target.threadId] ?? const <ChangeEvent>[];
          final moved = source
              .where((event) => eventIds.contains(event.eventId))
              .toList(growable: false);
          final kept = source
              .where((event) => !eventIds.contains(event.eventId))
              .toList(growable: false);
          if (moved.isEmpty || kept.isEmpty) break;
          final movedSubject = {
            for (final event in moved)
              ...ChangeDimensionReader.subjectMarkers(event.nowEvidence.quote),
          };
          final splitId = _uniqueId(
            ChangeThreadIdentity.mint({...movedSubject, target.threadId}),
            working.keys,
          );
          byThread[target.threadId] = kept;
          byThread[splitId] = moved
              .map(
                (event) => event.copyWith(
                  threadId: splitId,
                  correctionState: ChangeThreadCorrectionState.split,
                ),
              )
              .toList(growable: false);
          working[target.threadId] = _resummarised(
            target.copyWith(correctionState: ChangeThreadCorrectionState.split),
            kept,
          );
          working[splitId] = _resummarised(
            ChangeThread(
              threadId: splitId,
              archiveId: archiveId,
              userEditableLabel: newLabel?.trim().isNotEmpty == true
                  ? newLabel!.trim()
                  : ChangeThreadIdentity.labelFor(
                      movedSubject,
                      fallback: splitId,
                    ),
              subjectRepresentation: movedSubject,
              firstObservedAt: moved.first.occurredAt,
              latestObservedAt: moved.last.occurredAt,
              currentStatus: moved.last.status,
              evidenceEventIds: moved.map((event) => event.eventId).toList(),
              correctionState: ChangeThreadCorrectionState.split,
              policyVersion: policyVersion,
              labelIsUserConfirmed: newLabel?.trim().isNotEmpty == true,
            ),
            byThread[splitId]!,
          );
        case MergeChangeThreads(:final intoThreadId):
          final into = working[intoThreadId];
          if (into == null || into.threadId == target.threadId) break;
          // Only merge threads that genuinely share a subject. A mis-tap must
          // not be able to fuse two unrelated histories into one card.
          final shared = into.subjectRepresentation.intersection(
            target.subjectRepresentation,
          );
          if (shared.isEmpty) break;
          final combined =
              [...?byThread[intoThreadId], ...?byThread[target.threadId]]
                  .map((event) => event.copyWith(threadId: intoThreadId))
                  .toList()
                ..sort((a, b) {
                  final byDate = a.occurredAt.compareTo(b.occurredAt);
                  return byDate != 0 ? byDate : a.eventId.compareTo(b.eventId);
                });
          byThread[intoThreadId] = combined;
          byThread.remove(target.threadId);
          working.remove(target.threadId);
          working[intoThreadId] = _resummarised(
            into.copyWith(
              subjectRepresentation: {
                ...into.subjectRepresentation,
                ...target.subjectRepresentation,
              },
              correctionState: ChangeThreadCorrectionState.merged,
            ),
            combined,
          );
        case SuppressChangeThreadFraming(:final eventId):
          if (eventId == null) {
            working[target.threadId] = target.copyWith(
              visibilityState: ChangeThreadVisibility.suppressed,
              correctionState: ChangeThreadCorrectionState.framingSuppressed,
            );
            break;
          }
          final remaining = (byThread[target.threadId] ?? const <ChangeEvent>[])
              .where((event) => event.eventId != eventId)
              .toList(growable: false);
          byThread[target.threadId] = remaining;
          working[target.threadId] = _resummarised(
            target.copyWith(
              correctionState: ChangeThreadCorrectionState.framingSuppressed,
            ),
            remaining,
          );
      }
    }

    final views =
        working.values
            .where(
              (thread) =>
                  thread.isVisible &&
                  (byThread[thread.threadId]?.isNotEmpty ?? false),
            )
            .map(
              (thread) => ChangeThreadView(
                thread: thread,
                events: byThread[thread.threadId]!,
              ),
            )
            .toList()
          ..sort((a, b) {
            final byDate = b.thread.latestObservedAt.compareTo(
              a.thread.latestObservedAt,
            );
            return byDate != 0
                ? byDate
                : a.thread.threadId.compareTo(b.thread.threadId);
          });

    return ChangeThreadProjection(
      threads: views,
      ungroupedEvents: loose,
      policyVersion: policyVersion,
    );
  }

  static ChangeThread _resummarised(
    ChangeThread thread,
    List<ChangeEvent> events,
  ) {
    if (events.isEmpty) {
      return thread.copyWith(evidenceEventIds: const []);
    }
    return thread.copyWith(
      firstObservedAt:
          events.first.thenEvidence.sourceCapturedAt?.toUtc() ??
          events.first.occurredAt,
      latestObservedAt: events.last.occurredAt,
      currentStatus: events.last.status,
      evidenceEventIds: events
          .map((event) => event.eventId)
          .toList(growable: false),
    );
  }

  static String _uniqueId(String candidate, Iterable<String> taken) {
    if (!taken.contains(candidate)) return candidate;
    var suffix = 2;
    while (taken.contains('${candidate}_$suffix')) {
      suffix++;
    }
    return '${candidate}_$suffix';
  }
}

class _EventDraft {
  const _EventDraft({
    required this.conclusion,
    required this.evidence,
    required this.subjectMarkers,
    required this.changedDimensions,
    required this.directions,
    required this.occurredAt,
    required this.firstObservedAt,
  });

  final ExplainableConclusion conclusion;
  final List<TranscriptEvidenceCitation> evidence;
  final Set<String> subjectMarkers;
  final List<ChangeDimension> changedDimensions;
  final List<DimensionDirection> directions;
  final DateTime occurredAt;
  final DateTime firstObservedAt;

  ChangeEvent toEvent({
    required String threadId,
    required ChangeThreadStatus status,
  }) => ChangeEvent(
    // One event per conclusion, so re-projecting an archive can never produce
    // the same finding twice.
    eventId: conclusion.id,
    threadId: threadId,
    conclusionKind: conclusion.kind,
    status: status,
    changedDimensions: changedDimensions,
    exactEvidence: evidence,
    occurredAt: occurredAt,
    confidenceBand: conclusion.confidenceBand,
    uncertainty: conclusion.uncertaintyNote,
    alternativeExplanation: conclusion.alternativeExplanation.statement,
    statement: conclusion.statement,
    correctionState: conclusion.correctionNote?.trim().isNotEmpty == true
        ? ChangeThreadCorrectionState.correctedByUser
        : ChangeThreadCorrectionState.none,
  );
}
