import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/screenshot_mode.dart';
import '../design/archive_mobile_typography.dart';
import '../features/archive_watchlist/archive_watchlist_store.dart';
import '../features/beta_feedback/beta_feedback_store.dart';
import '../features/daily_archive_exercise/daily_archive_exercise_copy.dart';
import '../features/daily_archive_exercise/daily_archive_exercise_engine.dart';
import '../features/daily_archive_exercise/daily_archive_exercise_models.dart';
import '../features/todays_question/todays_question_copy.dart';
import '../services/app_services.dart';
import '../services/journal_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/pushed_screen_shell.dart';

/// Full daily archive exercise screen — no journal text.
class DailyArchiveExerciseScreen extends StatefulWidget {
  const DailyArchiveExerciseScreen({
    super.key,
    this.journalService,
    this.watchlistStore,
    this.engine = const DailyArchiveExerciseEngine(),
    this._initialResult,
  });

  final JournalService? journalService;
  final ArchiveWatchlistStore? watchlistStore;
  final DailyArchiveExerciseEngine engine;
  final DailyArchiveExerciseResult? _initialResult;

  @override
  State<DailyArchiveExerciseScreen> createState() =>
      _DailyArchiveExerciseScreenState();
}

class _DailyArchiveExerciseScreenState
    extends State<DailyArchiveExerciseScreen> {
  DailyArchiveExerciseResult? _result;
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
          DailyArchiveExerciseInput(
            realSavedMomentCount: 0,
            hasWatchTheme: false,
            betaFeedbackCaptured: false,
            sampleMode: true,
          ),
        );
        _loading = false;
      });
      return;
    }

    final journal = widget.journalService ?? AppServices.instance.journal;
    final watchlist =
        widget.watchlistStore ??
        ArchiveWatchlistStore(AppServices.instance.prefs);
    await BetaFeedbackStore.ensureLoaded();
    final entries = await journal.loadAll();
    final watchItems = await watchlist.loadItems();
    if (!mounted) return;
    setState(() {
      _result = widget.engine.buildFromJournal(
        entries: entries,
        hasWatchTheme: watchItems.isNotEmpty,
        betaFeedbackCaptured: BetaFeedbackStore.cached.hasResponse,
      );
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PushedScreenShell(
      title: DailyArchiveExerciseCopy.screenTitle,
      fallbackRoute: '/archive-belief',
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              key: const Key('daily_archive_exercise_screen'),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: _content(context, _result!),
            ),
    );
  }

  Widget _content(BuildContext context, DailyArchiveExerciseResult result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          result.title,
          key: const Key('daily_archive_exercise_screen_title'),
          style: ArchiveMobileTypography.listTitle(context),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          result.prompt,
          key: const Key('daily_archive_exercise_screen_prompt'),
          style: ArchiveMobileTypography.explanationBody(
            context,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          result.hint,
          key: const Key('daily_archive_exercise_screen_hint'),
          style: ArchiveMobileTypography.explanationBody(
            context,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            key: const Key('daily_archive_exercise_screen_primary_button'),
            onPressed: () => context.push(result.primaryRoute),
            child: Text(result.primaryCtaLabel),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            key: const Key(
              'daily_archive_exercise_screen_todays_question_link',
            ),
            onPressed: () => context.push(TodaysQuestionCopy.route),
            child: const Text(TodaysQuestionCopy.eyebrow),
          ),
        ),
      ],
    );
  }
}
