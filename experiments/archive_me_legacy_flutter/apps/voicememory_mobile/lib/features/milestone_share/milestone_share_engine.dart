import '../../models/journal_entry.dart';
import '../activation/weekly_archive_review.dart';
import '../archive_calendar/archive_calendar_engine.dart';
import '../archive_evidence/archive_evidence_guard.dart';
import '../demo/sample_archive_mode.dart';
import '../first_week_path/first_week_path_engine.dart';
import '../then_now/then_now_engine.dart';
import 'milestone_share_copy.dart';
import 'milestone_share_gates.dart';
import 'milestone_share_models.dart';

/// Builds share-safe milestone cards from local signals — no persistence.
class MilestoneShareEngine {
  const MilestoneShareEngine({
    this.thenNowEngine = const ThenNowEngine(),
    this.calendarEngine = const ArchiveCalendarEngine(),
  });

  final ThenNowEngine thenNowEngine;
  final ArchiveCalendarEngine calendarEngine;

  static const _milestoneRanks = {
    MilestoneShareId.firstSavedMoment: 1,
    MilestoneShareId.threeMomentsSaved: 2,
    MilestoneShareId.firstWatchThemeChosen: 3,
    MilestoneShareId.firstWeekPathComplete: 4,
    MilestoneShareId.firstWeeklyReview: 5,
    MilestoneShareId.firstRepeatingTheme: 6,
    MilestoneShareId.firstThenVsNowAvailable: 7,
    MilestoneShareId.archiveCalendarActive: 8,
  };

  MilestoneShareResult build(MilestoneShareInput input) {
    if (input.sampleMode) {
      return _sampleResult();
    }

    final cards = _availableCards(input);
    if (cards.isEmpty) {
      return MilestoneShareResult(
        cards: const [],
        primaryCard: null,
        totalAvailableCount: 0,
        isEmpty: true,
        showOnArchiveHome: false,
        hasCard: false,
        cardHeadline: MilestoneShareCopy.emptyTitle,
        cardSummary: MilestoneShareCopy.emptyBody,
        primaryCtaLabel: MilestoneShareCopy.emptyCta,
        primaryRoute: MilestoneShareCopy.recordRoute,
        emptyTitle: MilestoneShareCopy.emptyTitle,
        emptyBody: MilestoneShareCopy.emptyBody,
        emptyCtaLabel: MilestoneShareCopy.emptyCta,
        emptyCtaRoute: MilestoneShareCopy.recordRoute,
      );
    }

    final primary = _primaryCard(cards);
    final showOnArchiveHome = MilestoneShareGates.showOnArchiveHome(
      realSavedMomentCount: input.realSavedMomentCount,
      milestoneCount: cards.length,
      sampleMode: input.sampleMode,
    );

    return MilestoneShareResult(
      cards: cards,
      primaryCard: primary,
      totalAvailableCount: cards.length,
      isEmpty: false,
      showOnArchiveHome: showOnArchiveHome,
      hasCard: true,
      cardHeadline: primary?.title ?? MilestoneShareCopy.cardHeadline,
      cardSummary: primary?.body ?? MilestoneShareCopy.cardSummary,
      primaryCtaLabel: MilestoneShareCopy.openMilestoneCardsCta,
      primaryRoute: MilestoneShareCopy.route,
      emptyTitle: MilestoneShareCopy.emptyTitle,
      emptyBody: MilestoneShareCopy.emptyBody,
      emptyCtaLabel: MilestoneShareCopy.emptyCta,
      emptyCtaRoute: MilestoneShareCopy.recordRoute,
    );
  }

  MilestoneShareResult buildFromJournal({
    required List<JournalEntry> entries,
    required bool hasWatchTheme,
    bool sampleMode = false,
  }) {
    final realEntries = _realEntries(entries);
    final count = realEntries.length;
    final usable = ArchiveEvidenceGuard.eligibleReflectionCount(realEntries);
    final weeklyReview = WeeklyArchiveReviewEngine.build(entries: realEntries);
    final thenNow = thenNowEngine.buildFromJournal(entries: realEntries);
    final calendar = calendarEngine.buildFromJournal(entries: realEntries);

    return build(
      MilestoneShareInput(
        realSavedMomentCount: count,
        usableEvidenceCount: usable,
        firstWeekComplete: count >= FirstWeekPathEngine.totalSteps,
        hasWatchTheme: hasWatchTheme,
        weeklyReviewAvailable: weeklyReview.hasEnoughEvidence,
        weeklyReviewCompleted: false,
        hasRepeatingTheme: _hasRepeatingTheme(realEntries),
        thenVsNowAvailable: thenNow.hasCard && count >= 5,
        archiveCalendarActiveAcrossDays: calendar.activeDayCount >= 2,
        sampleMode: sampleMode,
      ),
    );
  }

  static List<MilestoneShareCard> _availableCards(MilestoneShareInput input) {
    final cards = <MilestoneShareCard>[];

    void add(MilestoneShareId id, {String? evidenceCountLabel}) {
      cards.add(_cardFor(id, input, evidenceCountLabel: evidenceCountLabel));
    }

    if (input.realSavedMomentCount >= 1) {
      add(
        MilestoneShareId.firstSavedMoment,
        evidenceCountLabel: '${input.realSavedMomentCount} moment saved',
      );
    }
    if (input.realSavedMomentCount >= 3) {
      add(
        MilestoneShareId.threeMomentsSaved,
        evidenceCountLabel: '${input.realSavedMomentCount} moments saved',
      );
    }
    if (input.hasWatchTheme) {
      add(MilestoneShareId.firstWatchThemeChosen);
    }
    if (input.firstWeekComplete) {
      add(MilestoneShareId.firstWeekPathComplete);
    }
    if (input.weeklyReviewAvailable || input.weeklyReviewCompleted) {
      add(MilestoneShareId.firstWeeklyReview);
    }
    if (input.hasRepeatingTheme) {
      add(MilestoneShareId.firstRepeatingTheme);
    }
    if (input.thenVsNowAvailable) {
      add(MilestoneShareId.firstThenVsNowAvailable);
    }
    if (input.archiveCalendarActiveAcrossDays) {
      add(MilestoneShareId.archiveCalendarActive);
    }

    cards.sort((a, b) => a.rank.compareTo(b.rank));
    return cards;
  }

  static MilestoneShareCard? _primaryCard(List<MilestoneShareCard> cards) {
    if (cards.isEmpty) return null;
    return cards.reduce(
      (current, next) => next.rank > current.rank ? next : current,
    );
  }

  static MilestoneShareCard _cardFor(
    MilestoneShareId id,
    MilestoneShareInput input, {
    String? evidenceCountLabel,
  }) {
    final copy = MilestoneShareCopy.cardFor(id);
    return MilestoneShareCard(
      milestoneId: id,
      title: copy.title,
      body: copy.body,
      safeShareText: copy.share,
      proofLabel: copy.proof,
      ctaLabel: copy.cta,
      ctaRoute: copy.route,
      isShareable: true,
      evidenceCountLabel: evidenceCountLabel ?? copy.proof,
      createdFromCountsOnly: true,
      rank: _milestoneRanks[id] ?? 0,
    );
  }

  static bool _hasRepeatingTheme(List<JournalEntry> entries) {
    final counts = <String, int>{};
    for (final entry in entries) {
      for (final raw in entry.reflection.recurringThemes) {
        final theme = raw.trim().toLowerCase();
        if (theme.isEmpty) continue;
        counts[theme] = (counts[theme] ?? 0) + 1;
        if (counts[theme]! >= 2) return true;
      }
    }
    return false;
  }

  static List<JournalEntry> _realEntries(List<JournalEntry> entries) =>
      SampleArchiveMode.excludeSampleEntries(entries)
          .where(
            (e) =>
                e.transcript.trim().isNotEmpty &&
                !e.transcript.startsWith('[draft]'),
          )
          .toList();

  MilestoneShareResult _sampleResult() {
    final card = _cardFor(
      MilestoneShareId.threeMomentsSaved,
      const MilestoneShareInput(
        realSavedMomentCount: 3,
        usableEvidenceCount: 3,
        firstWeekComplete: false,
        hasWatchTheme: false,
        weeklyReviewAvailable: false,
        hasRepeatingTheme: false,
        thenVsNowAvailable: false,
        archiveCalendarActiveAcrossDays: false,
        sampleMode: true,
      ),
    );
    return MilestoneShareResult(
      cards: [card],
      primaryCard: card,
      totalAvailableCount: 1,
      isEmpty: false,
      showOnArchiveHome: false,
      hasCard: true,
      cardHeadline: MilestoneShareCopy.eyebrow,
      cardSummary: MilestoneShareCopy.screenshotCardSummary,
      primaryCtaLabel: MilestoneShareCopy.openMilestoneCardsCta,
      primaryRoute: MilestoneShareCopy.route,
      emptyTitle: MilestoneShareCopy.emptyTitle,
      emptyBody: MilestoneShareCopy.emptyBody,
      emptyCtaLabel: MilestoneShareCopy.emptyCta,
      emptyCtaRoute: MilestoneShareCopy.recordRoute,
    );
  }
}
