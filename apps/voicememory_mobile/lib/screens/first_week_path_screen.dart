import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/screenshot_mode.dart';
import '../design/archive_mobile_typography.dart';
import '../features/archive_watchlist/archive_watchlist_store.dart';
import '../features/beta_feedback/beta_feedback_store.dart';
import '../features/first_week_path/first_week_path_copy.dart';
import '../features/first_week_path/first_week_path_engine.dart';
import '../features/first_week_path/first_week_path_models.dart';
import '../features/todays_question/todays_question_copy.dart';
import '../features/review_ritual/view_ritual_copy.dart';
import '../features/milestone_share/milestone_share_copy.dart';
import '../services/app_services.dart';
import '../services/journal_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/pushed_screen_shell.dart';

/// Full first-week path screen — metadata only, no journal text.
class FirstWeekPathScreen extends StatefulWidget {
  const FirstWeekPathScreen({
    super.key,
    this.journalService,
    this.watchlistStore,
    this.engine = const FirstWeekPathEngine(),
    this.hasWeeklyReviewAvailable = false,
    FirstWeekPathResult? initialResult,
  }) : _initialResult = initialResult;

  final JournalService? journalService;
  final ArchiveWatchlistStore? watchlistStore;
  final FirstWeekPathEngine engine;
  final bool hasWeeklyReviewAvailable;
  final FirstWeekPathResult? _initialResult;

  @override
  State<FirstWeekPathScreen> createState() => _FirstWeekPathScreenState();
}

class _FirstWeekPathScreenState extends State<FirstWeekPathScreen> {
  FirstWeekPathResult? _result;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    if (widget._initialResult != null) {
      _result = widget._initialResult;
      _loading = false;
      return;
    }
    _load();
  }

  Future<void> _load() async {
    if (ScreenshotMode.enabled) {
      if (!mounted) return;
      setState(() {
        _result = widget.engine.build(
          FirstWeekPathInput(
            realSavedMomentCount: 0,
            hasWatchTheme: false,
            betaFeedbackCaptured: false,
            hasWeeklyReviewAvailable: false,
            sampleMode: true,
          ),
        );
        _loading = false;
      });
      return;
    }

    final journal = widget.journalService ?? AppServices.instance.journal;
    final watchlist =
        widget.watchlistStore ?? ArchiveWatchlistStore(AppServices.instance.prefs);
    await BetaFeedbackStore.ensureLoaded();
    final entries = await journal.loadAll();
    final watchItems = await watchlist.loadItems();
    if (!mounted) return;
    setState(() {
      _result = widget.engine.buildFromJournal(
        entries: entries,
        hasWatchTheme: watchItems.isNotEmpty,
        betaFeedbackCaptured: BetaFeedbackStore.cached.hasResponse,
        hasWeeklyReviewAvailable: widget.hasWeeklyReviewAvailable,
      );
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PushedScreenShell(
      title: FirstWeekPathCopy.screenTitle,
      fallbackRoute: '/archive-belief',
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              key: const Key('first_week_path_screen'),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: _content(context, _result!),
            ),
    );
  }

  Widget _content(BuildContext context, FirstWeekPathResult result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          result.progressLabel,
          key: const Key('first_week_path_screen_progress'),
          style: ArchiveMobileTypography.cardLabel(context),
        ),
        const SizedBox(height: AppSpacing.sm),
        if (result.rewardText.isNotEmpty) ...[
          Text(
            result.rewardText,
            key: const Key('first_week_path_screen_reward'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        Text(
          result.nextStepText,
          key: const Key('first_week_path_screen_next_step'),
          style: ArchiveMobileTypography.explanationBody(
            context,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            key: const Key('first_week_path_screen_primary_button'),
            onPressed: () => context.push(result.primaryRoute),
            child: Text(result.primaryCtaLabel),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            key: const Key('first_week_path_screen_todays_question_link'),
            onPressed: () => context.push(TodaysQuestionCopy.route),
            child: const Text(TodaysQuestionCopy.eyebrow),
          ),
        ),
        if (result.isComplete) ...[
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            key: const Key('first_week_path_screen_review_ritual_link'),
            onPressed: () => context.push(ReviewRitualCopy.route),
            child: const Text(ReviewRitualCopy.openReviewRitualCta),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            key: const Key('first_week_path_screen_milestone_share_link'),
            onPressed: () => context.push(MilestoneShareCopy.route),
            child: const Text(MilestoneShareCopy.openMilestoneCardsCta),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            FirstWeekPathCopy.completeBody,
            key: const Key('first_week_path_screen_complete_body'),
            style: ArchiveMobileTypography.explanationBody(
              context,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}
