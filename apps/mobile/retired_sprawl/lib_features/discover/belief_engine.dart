import 'package:archiveme_mobile/design/archive_confidence_display.dart';
import 'package:archiveme_mobile/features/archive_evidence/archive_evidence.dart';
import 'package:archiveme_mobile/features/archive_state_object/archive_state_object.dart';
import 'package:archiveme_mobile/features/discover/discover_models.dart';
import 'package:archiveme_mobile/models/journal_entry.dart';

/// Current belief card for Discover Yourself.
class DiscoverBeliefEngine {
  const DiscoverBeliefEngine();

  DiscoverBeliefCard? build({
    required List<JournalEntry> entries,
    ArchiveStateObjectV3? state,
  }) {
    if (entries.isEmpty) return null;

    final eligible = archiveEligibleEvidenceEntries(entries);
    final sorted = [...eligible]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final beliefText =
        state?.belief?.trim() ??
        (eligible.isNotEmpty
            ? eligible.last.reflection.concreteObservation
            : null);
    if (beliefText == null || beliefText.isEmpty) {
      if (eligible.length < 2) return null;
      return DiscoverBeliefCard(
        statement:
            'Your archive is still gathering evidence from your recordings.',
        confidencePercent: 42,
        evidenceCount: eligible.length,
        firstObserved: sorted.first.createdAt,
        lastReinforced: sorted.last.createdAt,
        supportingEntries: sorted.reversed.take(5).toList(),
      );
    }

    final health = state?.health ?? ArchiveHealthV3.uncertain;
    final evidenceCount =
        state?.evidenceReflectionCount ??
        archiveEvidenceReflectionCount(entries);

    return DiscoverBeliefCard(
      statement: beliefText,
      confidencePercent: archiveConfidencePercent(
        health: health,
        evidenceReflectionCount: evidenceCount,
      ),
      evidenceCount: evidenceCount,
      firstObserved: sorted.isNotEmpty ? sorted.first.createdAt : null,
      lastReinforced: sorted.isNotEmpty ? sorted.last.createdAt : null,
      supportingEntries: sorted.reversed.take(8).toList(),
    );
  }
}