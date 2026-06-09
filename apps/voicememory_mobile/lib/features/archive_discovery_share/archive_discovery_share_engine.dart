import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence.dart';
import '../archive_v1/archive_v1_models.dart';
import 'archive_discovery_share_card_model.dart';
import 'archive_discovery_share_moments.dart';
import 'archive_discovery_share_types.dart';

/// Builds screenshot-safe share cards from existing archive engines.
abstract final class ArchiveDiscoveryShareEngine {
  ArchiveDiscoveryShareEngine._();

  static const int maxCards = 5;

  static List<ArchiveDiscoveryShareCardModel> build({
    required List<JournalEntry> entries,
    ArchiveV1View? archiveV1,
  }) {
    final eligible = archiveEligibleEvidenceEntries(entries);
    final out = <ArchiveDiscoveryShareCardModel>[];

    if (archiveV1 != null) {
      _addContradictions(out, archiveV1);
      _addBeliefChanges(out, archiveV1);
      _addSurprises(out, archiveV1);
      _addChangeDetected(out, archiveV1);
    }

    _addPatterns(out, eligible);
    _addMilestones(out, eligible.length);

    if (out.isEmpty && eligible.isNotEmpty) {
      out.add(
        ArchiveDiscoveryShareCardModel(
          id: 'pattern-growing',
          type: ArchiveDiscoveryShareCardType.patternDiscovery,
          insight:
              '${eligible.length} reflections are building your archive.',
          evidenceRecordingCount: eligible.length,
        ),
      );
    }

    return out.take(maxCards).toList();
  }

  static void _addContradictions(
    List<ArchiveDiscoveryShareCardModel> out,
    ArchiveV1View v1,
  ) {
    for (final c in v1.contradictions.take(1)) {
      final card = ArchiveDiscoveryShareMoments.fromContradiction(c);
      if (card != null) out.add(card);
    }
  }

  static void _addBeliefChanges(
    List<ArchiveDiscoveryShareCardModel> out,
    ArchiveV1View v1,
  ) {
    final thenNow = v1.thenNow;
    if (thenNow != null) {
      final card = ArchiveDiscoveryShareMoments.fromThenNow(thenNow);
      if (card != null) {
        out.add(card);
        return;
      }
    }

    for (final w in v1.changeFeed.beliefsWeakened.take(1)) {
      final card = ArchiveDiscoveryShareMoments.fromBeliefWeakened(w);
      if (card != null) out.add(card);
    }
  }

  static void _addSurprises(
    List<ArchiveDiscoveryShareCardModel> out,
    ArchiveV1View v1,
  ) {
    for (final s in v1.surprises.observations.take(1)) {
      final card = ArchiveDiscoveryShareMoments.fromSurprise(s);
      if (card != null) out.add(card);
    }
  }

  static void _addChangeDetected(
    List<ArchiveDiscoveryShareCardModel> out,
    ArchiveV1View v1,
  ) {
    final feed = v1.changeFeed;
    if (!feed.hasBaseline || !feed.hasChanges) return;

    if (feed.themesIncreasing.isNotEmpty) {
      final t = feed.themesIncreasing.first;
      out.add(
        ArchiveDiscoveryShareCardModel(
          id: 'change-theme-up-${t.label}',
          type: ArchiveDiscoveryShareCardType.changeDetected,
          insight:
              '"${t.label}" is showing up more often in recent recordings.',
          evidenceRecordingCount: t.mentionsNow,
        ),
      );
      return;
    }

    if (feed.themesDecreasing.isNotEmpty) {
      final t = feed.themesDecreasing.first;
      out.add(
        ArchiveDiscoveryShareCardModel(
          id: 'change-theme-down-${t.label}',
          type: ArchiveDiscoveryShareCardType.changeDetected,
          insight: '"${t.label}" is appearing less often than before.',
          evidenceRecordingCount: t.mentionsAtReview,
        ),
      );
      return;
    }

    if (feed.newReflectionCount >= 2) {
      out.add(
        ArchiveDiscoveryShareCardModel(
          id: 'change-new-reflections',
          type: ArchiveDiscoveryShareCardType.changeDetected,
          insight:
              '${feed.newReflectionCount} new recordings since your last archive review.',
          evidenceRecordingCount: feed.newReflectionCount,
        ),
      );
    }
  }

  static void _addPatterns(
    List<ArchiveDiscoveryShareCardModel> out,
    List<JournalEntry> eligible,
  ) {
    final themeCounts = <String, int>{};
    for (final e in eligible) {
      for (final t in e.reflection.recurringThemes) {
        final k = t.trim().toLowerCase();
        if (k.length < 2) continue;
        themeCounts[k] = (themeCounts[k] ?? 0) + 1;
      }
    }
    if (themeCounts.isEmpty) return;
    final top = themeCounts.entries.reduce((a, b) => a.value >= b.value ? a : b);
    if (top.value < 3) return;
    out.add(
      ArchiveDiscoveryShareCardModel(
        id: 'pattern-${top.key}',
        type: ArchiveDiscoveryShareCardType.patternDiscovery,
        insight:
            '"${top.key}" has appeared ${top.value} times in your archive.',
        evidenceRecordingCount: top.value,
      ),
    );
  }

  static void _addMilestones(List<ArchiveDiscoveryShareCardModel> out, int count) {
    const milestones = [200, 100, 50];
    for (final m in milestones) {
      if (count >= m) {
        out.add(
          ArchiveDiscoveryShareCardModel(
            id: 'milestone-$m',
            type: ArchiveDiscoveryShareCardType.milestone,
            insight: 'You crossed $m recordings in your archive.',
            evidenceRecordingCount: count,
          ),
        );
        return;
      }
    }
  }
}
