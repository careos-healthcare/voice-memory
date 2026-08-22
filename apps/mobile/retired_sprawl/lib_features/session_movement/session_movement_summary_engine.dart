import 'package:archiveme_mobile/features/archive_evidence/archive_evidence_guard.dart';
import 'package:archiveme_mobile/features/archive_theory/theory_tracker_engine.dart';
import 'package:archiveme_mobile/features/archive_theory/theory_tracker_models.dart';
import 'package:archiveme_mobile/features/session_movement/session_movement_copy.dart';
import 'package:archiveme_mobile/features/session_movement/session_movement_models.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Lightweight session movement builder (web [buildSessionMovementSummary] parity).
class SessionMovementSummaryEngine {
  const SessionMovementSummaryEngine({
    this.theoryEngine = const TheoryTrackerEngine(),
  });

  final TheoryTrackerEngine theoryEngine;

  Future<SessionMovementSummaryView?> build({
    required List<JournalEntry> entriesAfter,
    required TheorySnapshotStore snapshots, String? newEntryId,
  }) async {
    final eligible = ArchiveEvidenceGuard.eligibleEntries(
      entriesAfter,
      analyticsSource: 'session_movement_summary',
    );
    if (eligible.isEmpty) return null;

    final entriesBefore = newEntryId == null
        ? (eligible.length > 1 ? eligible.sublist(0, eligible.length - 1) : <JournalEntry>[])
        : eligible.where((e) => e.id != newEntryId).toList();

    final reportBefore = await theoryEngine.build(
      entries: entriesBefore,
      snapshots: TheorySnapshotStore(snapshots.prefs),
      persistSnapshots: false,
    );
    final reportAfter = await theoryEngine.build(
      entries: eligible,
      snapshots: snapshots,
    );

    final lead = reportAfter.all.isEmpty ? null : reportAfter.all.first;
    TrackedTheory? leadBefore;
    if (lead != null) {
      for (final t in reportBefore.all) {
        if (t.id == lead.id) {
          leadBefore = t;
          break;
        }
      }
    }

    if (lead != null && leadBefore != null && leadBefore.status != lead.status) {
      return _view(
        SessionMovementKind.beliefChanged,
        SessionMovementCopy.beliefChanged,
        'Status moved from ${leadBefore.status.name} to ${lead.status.name}.',
        '${leadBefore.status.name} → ${lead.status.name}',
        lead.id,
      );
    }

    if (lead != null &&
        lead.previousConfidence != null &&
        lead.confidenceDelta.abs() >= 1) {
      return _view(
        SessionMovementKind.confidenceMoved,
        SessionMovementCopy.confidenceMoved,
        'The archive re-weighted evidence for a working belief.',
        '${lead.previousConfidence}% → ${lead.confidence}%',
        lead.id,
      );
    }

    final beforeSupport = leadBefore?.supportingEvidenceCount ?? entriesBefore.length;
    final afterSupport = lead?.supportingEvidenceCount ?? eligible.length;
    if (afterSupport > beforeSupport) {
      return _view(
        SessionMovementKind.newEvidenceAdded,
        SessionMovementCopy.newEvidence,
        lead != null
            ? 'Supporting reflections for this thread: $beforeSupport → $afterSupport.'
            : 'Your archive now holds ${eligible.length} reflection${eligible.length == 1 ? '' : 's'} to compare.',
        lead != null ? '$beforeSupport → $afterSupport supporting reflections' : null,
        lead?.id,
      );
    }

    if (lead != null &&
        lead.contradictingEvidenceCount > (leadBefore?.contradictingEvidenceCount ?? 0)) {
      return _view(
        SessionMovementKind.contradictionAppeared,
        SessionMovementCopy.contradiction,
        'Your archive now contains evidence pointing in two directions.',
        null,
        lead.id,
      );
    }

    if (lead != null &&
        (lead.status == TheoryStatus.weakening || lead.confidenceDelta < 0)) {
      return _view(
        SessionMovementKind.beliefWeakened,
        SessionMovementCopy.beliefWeakened,
        'Recent reflections may pull against an earlier working view.',
        lead.previousConfidence != null
            ? '${lead.previousConfidence}% → ${lead.confidence}%'
            : lead.status.name,
        lead.id,
      );
    }

    if (lead != null &&
        (lead.status == TheoryStatus.strengthening || lead.confidenceDelta > 0)) {
      return _view(
        SessionMovementKind.beliefStrengthened,
        SessionMovementCopy.beliefStrengthened,
        'Repeated evidence may be reinforcing a working belief.',
        lead.previousConfidence != null
            ? '${lead.previousConfidence}% → ${lead.confidence}%'
            : lead.status.name,
        lead.id,
      );
    }

    return _view(
      SessionMovementKind.comparisonPoint,
      SessionMovementCopy.comparisonPoint,
      'Patterns are judged against your history, not a single mood.',
      eligible.length >= 2
          ? '${eligible.length} reflections in archive'
          : '1 reflection in archive',
      lead?.id,
    );
  }

  SessionMovementSummaryView _view(
    SessionMovementKind kind,
    String headline,
    String reason,
    String? detailLine,
    String? theoryId,
  ) {
    return SessionMovementSummaryView(
      id: 'sms-${DateTime.now().microsecondsSinceEpoch}',
      kind: kind,
      headline: headline,
      detailLine: detailLine,
      reason: reason,
      theoryId: theoryId,
    );
  }
}