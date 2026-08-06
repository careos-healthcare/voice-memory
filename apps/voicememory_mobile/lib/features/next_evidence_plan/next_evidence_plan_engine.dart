import '../../models/journal_entry.dart';
import '../activation/archive_evidence_map.dart';
import '../archive_watchlist/archive_watchlist_copy.dart';
import '../archive_watchlist/archive_watchlist_models.dart';
import '../moment_quality/moment_quality_engine.dart';
import '../moment_quality/moment_quality_models.dart';
import 'next_evidence_plan_copy.dart';
import 'next_evidence_plan_gates.dart';
import 'next_evidence_plan_models.dart';

/// Builds a local next-evidence plan from archive signals — no persistence.
class NextEvidencePlanEngine {
  const NextEvidencePlanEngine({
    this.momentQualityEngine = const MomentQualityEngine(),
  });

  final MomentQualityEngine momentQualityEngine;

  NextEvidencePlanTeaser buildTeaser() => const NextEvidencePlanTeaser(
    title: NextEvidencePlanCopy.starterTitle,
    body: NextEvidencePlanCopy.starterBody,
  );

  NextEvidencePlanResult build({
    required List<JournalEntry> entries,
    required List<ArchiveWatchlistItem> watchlistItems,
    String? returnRitualPhrase,
  }) {
    final saved = _realEntries(entries);
    final savedCount = saved.length;
    final evidenceMap = ArchiveEvidenceMapEngine.build(entries: saved);
    final primaryWatchlist = watchlistItems.isNotEmpty
        ? watchlistItems.first
        : null;
    final watchLabel = primaryWatchlist?.resolveLabel(
      ArchiveWatchlistCopy.presets,
    );

    final body = _primaryBody(savedCount: savedCount, watchLabel: watchLabel);

    final watchlistLine = watchLabel != null
        ? NextEvidencePlanCopy.watchingForLine(watchLabel)
        : null;

    final ritualLine =
        returnRitualPhrase != null && returnRitualPhrase.trim().isNotEmpty
        ? NextEvidencePlanCopy.returnRitualLine(returnRitualPhrase.trim())
        : null;

    final secondaryLine = _secondaryLine(
      entries: saved,
      evidenceMap: evidenceMap,
    );

    return NextEvidencePlanResult(
      title: NextEvidencePlanCopy.cardTitle,
      body: body,
      watchlistLine: watchlistLine,
      returnRitualLine: ritualLine,
      secondaryLine: secondaryLine,
      primaryActionLabel: NextEvidencePlanCopy.addMomentAction,
      primaryActionRoute: NextEvidencePlanCopy.addMomentRoute,
      showReviewWatchlistAction: watchlistItems.isNotEmpty,
      showProLine: NextEvidencePlanGates.showProLine(
        entryCount: savedCount,
        watchThemeCount: watchlistItems.length,
      ),
    );
  }

  static String _primaryBody({
    required int savedCount,
    required String? watchLabel,
  }) {
    if (watchLabel != null && watchLabel.isNotEmpty) {
      return NextEvidencePlanCopy.watchlistPlanBody(watchLabel);
    }
    if (savedCount <= 1) {
      return NextEvidencePlanCopy.oneEntryBody;
    }
    if (savedCount == 2) {
      return NextEvidencePlanCopy.twoEntriesBody;
    }
    if (savedCount <= 4) {
      return NextEvidencePlanCopy.beliefTestBody;
    }
    return NextEvidencePlanCopy.weeklyReviewBody;
  }

  String? _secondaryLine({
    required List<JournalEntry> entries,
    required ArchiveEvidenceMap evidenceMap,
  }) {
    final recent = _mostRecent(entries);
    if (recent != null) {
      final quality = momentQualityEngine.evaluate(recent.transcript);
      if (quality.level == MomentQualityLevel.veryShort) {
        return NextEvidencePlanCopy.extraDetailSuggestion;
      }
    }
    if (evidenceMap.untaggedLine != null ||
        evidenceMap.thinContextsLine != null) {
      return NextEvidencePlanCopy.contextImprovementSuggestion;
    }
    return null;
  }

  static List<JournalEntry> _realEntries(List<JournalEntry> entries) =>
      entries
          .where(
            (e) =>
                e.transcript.trim().isNotEmpty &&
                !e.transcript.startsWith('[draft]'),
          )
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  static JournalEntry? _mostRecent(List<JournalEntry> entries) {
    if (entries.isEmpty) return null;
    return entries.reduce((a, b) => a.createdAt.isAfter(b.createdAt) ? a : b);
  }
}
