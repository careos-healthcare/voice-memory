import '../../models/journal_entry.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import '../beta_feedback/beta_feedback_engine.dart';
import '../demo/sample_archive_mode.dart';
import 'then_now_copy.dart';
import 'then_now_gates.dart';
import 'then_now_models.dart';

/// Builds cautious Then vs Now comparisons from local theme counts.
class ThenNowEngine {
  const ThenNowEngine();

  static const earlyPreviewMinEntries = 5;
  static const comparisonMinEntries = 7;
  static const minRepeatedThemeEntries = 2;

  ThenNowResult build(ThenNowInput input) {
    if (input.sampleMode) {
      return _screenshotPreview();
    }

    final count = input.realSavedMomentCount;
    if (count <= 4) {
      return ThenNowResult.empty;
    }

    if (count <= 6) {
      return _earlyPreview(input);
    }

    final theme = input.selectedTheme;
    if (theme == null || theme.trim().isEmpty) {
      return ThenNowResult(
        hasCard: false,
        headline: ThenNowCopy.noClearChangeTitle,
        thenLabel: ThenNowCopy.thenLabel,
        thenSummary: '',
        nowLabel: ThenNowCopy.nowLabel,
        nowSummary: '',
        evidenceCountLabel: ThenNowCopy.evidenceCountLabel(
          earlierCount: input.earlierMomentCount,
          newerCount: input.newerMomentCount,
          total: count,
        ),
        helperText: ThenNowCopy.helperText,
        cautionLabel: ThenNowCopy.cautionLabel,
        primaryCtaLabel: ThenNowCopy.saveMomentCta,
        primaryRoute: ThenNowCopy.recordRoute,
        secondaryCtaLabel: ThenNowCopy.reviewChangeCta,
        secondaryRoute: ThenNowCopy.route,
        reasonId: ThenNowReasonId.noClearChange,
        showOnArchiveHome: false,
        whatThisMeans: ThenNowCopy.noClearChangeBody,
      );
    }

    return _themeComparison(input, theme);
  }

  ThenNowResult buildFromJournal({
    required List<JournalEntry> entries,
    bool weeklyReviewAvailable = false,
    bool sampleMode = false,
  }) {
    final realEntries = SampleArchiveMode.excludeSampleEntries(entries);
    final count = BetaFeedbackEngine.realEntryCountFor(realEntries);
    final usable = ArchiveEvidenceGuard.eligibleReflectionCount(realEntries);
    final split = _splitThemes(realEntries);

    return build(
      ThenNowInput(
        realSavedMomentCount: count,
        usableEvidenceCount: usable,
        sampleMode: sampleMode,
        earlierThemeCounts: split.earlierThemeCounts,
        newerThemeCounts: split.newerThemeCounts,
        selectedTheme: _selectTheme(split),
        earlierMomentCount: split.earlierMomentCount,
        newerMomentCount: split.newerMomentCount,
      ),
    );
  }

  static ThenNowResult _screenshotPreview() => ThenNowResult(
    hasCard: false,
    headline: ThenNowCopy.screenshotHeadline,
    thenLabel: ThenNowCopy.thenLabel,
    thenSummary: ThenNowCopy.screenshotThenSummary,
    nowLabel: ThenNowCopy.nowLabel,
    nowSummary: ThenNowCopy.screenshotNowSummary,
    evidenceCountLabel: ThenNowCopy.evidenceCountLabel(
      earlierCount: 1,
      newerCount: 1,
      total: 2,
    ),
    helperText: ThenNowCopy.helperText,
    cautionLabel: ThenNowCopy.cautionLabel,
    primaryCtaLabel: ThenNowCopy.reviewChangeCta,
    primaryRoute: ThenNowCopy.route,
    secondaryCtaLabel: ThenNowCopy.saveAnotherMomentCta,
    secondaryRoute: ThenNowCopy.recordRoute,
    reasonId: ThenNowReasonId.themeComparison,
    showOnArchiveHome: false,
  );

  static ThenNowResult _earlyPreview(ThenNowInput input) {
    return ThenNowResult(
      hasCard: true,
      headline: ThenNowCopy.earlyHeadline,
      thenLabel: ThenNowCopy.thenLabel,
      thenSummary: ThenNowCopy.earlyThenSummary,
      nowLabel: ThenNowCopy.nowLabel,
      nowSummary: ThenNowCopy.earlyNowSummary,
      evidenceCountLabel: ThenNowCopy.evidenceCountLabel(
        earlierCount: input.earlierMomentCount,
        newerCount: input.newerMomentCount,
        total: input.realSavedMomentCount,
      ),
      helperText: ThenNowCopy.helperText,
      cautionLabel: ThenNowCopy.cautionLabel,
      primaryCtaLabel: ThenNowCopy.reviewChangeCta,
      primaryRoute: ThenNowCopy.route,
      secondaryCtaLabel: ThenNowCopy.saveAnotherMomentCta,
      secondaryRoute: ThenNowCopy.recordRoute,
      reasonId: ThenNowReasonId.earlyPreview,
      showOnArchiveHome: ThenNowGates.showOnArchiveHome(
        hasCard: true,
        sampleMode: false,
      ),
      whatThisMeans: ThenNowCopy.earlyWhatThisMeans,
    );
  }

  static ThenNowResult _themeComparison(ThenNowInput input, String theme) {
    final thenCount = input.earlierThemeCounts[theme] ?? 0;
    final nowCount = input.newerThemeCounts[theme] ?? 0;
    final thenSummary = thenCount > nowCount
        ? ThenNowCopy.thenMoreOften
        : nowCount > thenCount
        ? ThenNowCopy.thenLessOften
        : ThenNowCopy.thenAppeared;
    final nowSummary = thenCount > nowCount
        ? ThenNowCopy.nowShifting
        : nowCount > thenCount
        ? ThenNowCopy.nowAppearingMore
        : ThenNowCopy.nowStillAppears;

    return ThenNowResult(
      hasCard: true,
      headline: ThenNowCopy.comparisonHeadline,
      thenLabel: ThenNowCopy.thenLabel,
      thenSummary: thenSummary,
      nowLabel: ThenNowCopy.nowLabel,
      nowSummary: nowSummary,
      evidenceCountLabel:
          '${ThenNowCopy.themeEvidenceLabel(theme)} · ${ThenNowCopy.evidenceCountLabel(earlierCount: input.earlierMomentCount, newerCount: input.newerMomentCount, total: input.realSavedMomentCount)}',
      helperText: ThenNowCopy.helperText,
      cautionLabel: ThenNowCopy.cautionLabel,
      primaryCtaLabel: ThenNowCopy.reviewChangeCta,
      primaryRoute: ThenNowCopy.route,
      secondaryCtaLabel: ThenNowCopy.saveAnotherMomentCta,
      secondaryRoute: ThenNowCopy.recordRoute,
      reasonId: ThenNowReasonId.themeComparison,
      showOnArchiveHome: ThenNowGates.showOnArchiveHome(
        hasCard: true,
        sampleMode: false,
      ),
      whatThisMeans: ThenNowCopy.comparisonWhatThisMeans,
    );
  }

  static _ThenNowThemeSplit _splitThemes(List<JournalEntry> realEntries) {
    final eligible = ArchiveEvidenceGuard.eligibleEntries(realEntries);
    if (eligible.isEmpty) {
      return const _ThenNowThemeSplit(
        earlierThemeCounts: {},
        newerThemeCounts: {},
        earlierMomentCount: 0,
        newerMomentCount: 0,
      );
    }

    final splitAt = eligible.length ~/ 2;
    final earlier = eligible.sublist(0, splitAt.clamp(1, eligible.length));
    final newer = eligible.sublist(splitAt.clamp(1, eligible.length));

    return _ThenNowThemeSplit(
      earlierThemeCounts: _themeCountsFor(earlier),
      newerThemeCounts: _themeCountsFor(newer),
      earlierMomentCount: earlier.length,
      newerMomentCount: newer.length,
    );
  }

  static Map<String, int> _themeCountsFor(List<JournalEntry> entries) {
    final counts = <String, int>{};
    for (final entry in entries) {
      final themes = entry.reflection.recurringThemes;
      for (final raw in themes) {
        final theme = raw.trim().toLowerCase();
        if (theme.isEmpty) continue;
        counts[theme] = (counts[theme] ?? 0) + 1;
      }
    }
    return counts;
  }

  static String? _selectTheme(_ThenNowThemeSplit split) {
    final totals = <String, int>{};
    for (final entry in split.earlierThemeCounts.entries) {
      totals[entry.key] = (totals[entry.key] ?? 0) + entry.value;
    }
    for (final entry in split.newerThemeCounts.entries) {
      totals[entry.key] = (totals[entry.key] ?? 0) + entry.value;
    }

    String? bestTheme;
    var bestScore = 0;
    for (final entry in totals.entries) {
      if (entry.value < minRepeatedThemeEntries) continue;
      final inEarlier = split.earlierThemeCounts.containsKey(entry.key);
      final inNewer = split.newerThemeCounts.containsKey(entry.key);
      if (!inEarlier || !inNewer) continue;
      if (entry.value > bestScore) {
        bestScore = entry.value;
        bestTheme = entry.key;
      }
    }
    return bestTheme;
  }
}

class _ThenNowThemeSplit {
  const _ThenNowThemeSplit({
    required this.earlierThemeCounts,
    required this.newerThemeCounts,
    required this.earlierMomentCount,
    required this.newerMomentCount,
  });

  final Map<String, int> earlierThemeCounts;
  final Map<String, int> newerThemeCounts;
  final int earlierMomentCount;
  final int newerMomentCount;
}
