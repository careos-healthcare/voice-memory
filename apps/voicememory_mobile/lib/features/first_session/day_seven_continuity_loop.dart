/// Day 7 Continuity Loop — a calm reason to keep going after the Day 2
/// return, until the archive holds enough evidence to show weekly change.
///
/// Guardrails by construction:
/// - Nothing for brand-new users (0–1 entries) — the first-session surfaces
///   own that moment.
/// - Passive card only while evidence is building; the single CTA exists
///   only once the existing weekly review genuinely has something to show.
/// - No streaks, no obligation, no recurring nagging — the card simply
///   reflects where the archive is.
/// - Hidden at 7+ entries unless the weekly review exists — established
///   users never see building copy.
enum DaySevenContinuityStage {
  none,
  earlyThread,
  buildingArchive,
  weeklyReviewReady,
}

class DaySevenContinuityLoop {
  const DaySevenContinuityLoop({
    required this.stage,
    this.title = '',
    this.body = '',
    this.helper = '',
    this.ctaLabel = '',
  });

  static const DaySevenContinuityLoop none = DaySevenContinuityLoop(
    stage: DaySevenContinuityStage.none,
  );

  final DaySevenContinuityStage stage;
  final String title;
  final String body;

  /// Optional soft reassurance line; empty when the stage has none.
  final String helper;

  /// Non-empty only for [DaySevenContinuityStage.weeklyReviewReady].
  final String ctaLabel;

  bool get show => stage != DaySevenContinuityStage.none;

  bool get hasCta => ctaLabel.isNotEmpty;

  /// Stable stage id, safe to log. Never user text.
  String get stageId => switch (stage) {
    DaySevenContinuityStage.none => 'none',
    DaySevenContinuityStage.earlyThread => 'early_thread',
    DaySevenContinuityStage.buildingArchive => 'building_archive',
    DaySevenContinuityStage.weeklyReviewReady => 'weekly_review_ready',
  };
}

/// Pure, deterministic builder — no IO, no AI, no new archive claims. The
/// weekly review signal comes from the existing [WeeklyThreadReviewEngine]
/// output; this engine only decides which calm copy fits.
class DaySevenContinuityEngine {
  const DaySevenContinuityEngine();

  // --- 2 entries: the thread just connected. ---
  static const String earlyThreadTitle = 'Keep the thread visible';
  static const String earlyThreadBody =
      'One more recording this week can help ArchiveMe see what is '
      'returning, fading, or changing.';
  static const String earlyThreadHelper =
      'Only if it still feels worth checking.';

  // --- 3–6 entries: the archive can start comparing. ---
  static const String buildingTitle = 'Your archive is starting to compare';
  static const String buildingBody =
      'ArchiveMe has enough evidence to notice early movement. A few more '
      'recordings can make the weekly review clearer.';
  static const String buildingHelper = 'No need to record everything.';

  // --- Weekly review exists: the loop closed. ---
  static const String reviewReadyTitle = 'Your weekly review is ready';
  static const String reviewReadyBody =
      'See what returned, faded, or changed this week.';
  static const String reviewReadyCta = 'View weekly review';

  DaySevenContinuityLoop build({
    required int entryCount,
    required bool hasWeeklyReview,
  }) {
    // Brand-new users (0–1 entries) never see continuity copy.
    if (entryCount <= 1) return DaySevenContinuityLoop.none;

    // A real weekly review takes precedence at any count — the loop closed.
    if (hasWeeklyReview) {
      return const DaySevenContinuityLoop(
        stage: DaySevenContinuityStage.weeklyReviewReady,
        title: reviewReadyTitle,
        body: reviewReadyBody,
        ctaLabel: reviewReadyCta,
      );
    }

    if (entryCount == 2) {
      return const DaySevenContinuityLoop(
        stage: DaySevenContinuityStage.earlyThread,
        title: earlyThreadTitle,
        body: earlyThreadBody,
        helper: earlyThreadHelper,
      );
    }

    if (entryCount <= 6) {
      return const DaySevenContinuityLoop(
        stage: DaySevenContinuityStage.buildingArchive,
        title: buildingTitle,
        body: buildingBody,
        helper: buildingHelper,
      );
    }

    // 7+ entries without a weekly review: nothing — never building copy
    // for an established archive.
    return DaySevenContinuityLoop.none;
  }
}
