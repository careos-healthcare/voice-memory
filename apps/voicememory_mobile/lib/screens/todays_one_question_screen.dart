import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/screenshot_mode.dart';
import '../design/archive_mobile_typography.dart';
import '../features/archive_watchlist/archive_watchlist_store.dart';
import '../features/beta_feedback/beta_feedback_store.dart';
import '../features/todays_question/todays_question_copy.dart';
import '../features/todays_question/todays_question_engine.dart';
import '../features/todays_question/todays_question_models.dart';
import '../services/app_services.dart';
import '../services/journal_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/pushed_screen_shell.dart';

/// Full today's one question screen — no private journal text.
class TodaysOneQuestionScreen extends StatefulWidget {
  const TodaysOneQuestionScreen({
    super.key,
    this.journalService,
    this.watchlistStore,
    this.engine = const TodaysQuestionEngine(),
    TodaysQuestionResult? initialResult,
    this.weeklyReviewAvailable = false,
  }) : _initialResult = initialResult;

  final JournalService? journalService;
  final ArchiveWatchlistStore? watchlistStore;
  final TodaysQuestionEngine engine;
  final bool weeklyReviewAvailable;
  final TodaysQuestionResult? _initialResult;

  @override
  State<TodaysOneQuestionScreen> createState() =>
      _TodaysOneQuestionScreenState();
}

class _TodaysOneQuestionScreenState extends State<TodaysOneQuestionScreen> {
  TodaysQuestionResult? _result;
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
          TodaysQuestionInput(
            realSavedMomentCount: 0,
            usableEvidenceCount: 0,
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
        weeklyReviewAvailable: widget.weeklyReviewAvailable,
      );
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PushedScreenShell(
      title: TodaysQuestionCopy.eyebrow,
      fallbackRoute: TodaysQuestionCopy.recordRoute,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              key: const Key('todays_one_question_screen'),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: _content(context, _result!),
            ),
    );
  }

  Widget _content(BuildContext context, TodaysQuestionResult result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          result.questionText,
          key: const Key('todays_one_question_screen_question'),
          style: ArchiveMobileTypography.listTitle(context),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          result.helperText,
          key: const Key('todays_one_question_screen_helper'),
          style: ArchiveMobileTypography.explanationBody(
            context,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          key: const Key('todays_one_question_screen_record_button'),
          onPressed: () => context.pop(TodaysQuestionScreenAction.record),
          child: const Text(TodaysQuestionCopy.recordAnswerCta),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton(
          key: const Key('todays_one_question_screen_type_button'),
          onPressed: () => context.pop(TodaysQuestionScreenAction.type),
          child: const Text(TodaysQuestionCopy.typeAnswerCta),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextButton(
          key: const Key('todays_one_question_screen_back_button'),
          onPressed: () => context.pop(),
          child: const Text(TodaysQuestionCopy.backToRecordCta),
        ),
      ],
    );
  }
}

/// Actions returned from the full question screen.
enum TodaysQuestionScreenAction {
  record,
  type,
}
