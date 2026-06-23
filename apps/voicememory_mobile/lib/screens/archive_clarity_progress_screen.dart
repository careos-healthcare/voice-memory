import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/screenshot_mode.dart';
import '../design/archive_mobile_typography.dart';
import '../features/archive_evidence/archive_evidence_guard.dart';
import '../features/demo/sample_archive_mode.dart';
import '../features/archive_watchlist/archive_watchlist_store.dart';
import '../features/beta_feedback/beta_feedback_store.dart';
import '../features/archive_clarity/archive_clarity_copy.dart';
import '../features/then_now/then_now_copy.dart';
import '../features/archive_calendar/archive_calendar_copy.dart';
import '../features/archive_clarity/archive_clarity_engine.dart';
import '../features/archive_clarity/archive_clarity_models.dart';
import '../services/app_services.dart';
import '../services/journal_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/pushed_screen_shell.dart';
import '../widgets/insight_feedback_actions.dart';
import '../features/insight_feedback/insight_feedback_gates.dart';
import '../features/insight_feedback/insight_feedback_models.dart';

/// Full archive clarity progress screen — metadata only, no journal text.
class ArchiveClarityProgressScreen extends StatefulWidget {
  const ArchiveClarityProgressScreen({
    super.key,
    this.journalService,
    this.watchlistStore,
    this.engine = const ArchiveClarityEngine(),
    ArchiveClarityResult? initialResult,
    this.weeklyReviewAvailable = false,
  }) : _initialResult = initialResult;

  final JournalService? journalService;
  final ArchiveWatchlistStore? watchlistStore;
  final ArchiveClarityEngine engine;
  final bool weeklyReviewAvailable;
  final ArchiveClarityResult? _initialResult;

  @override
  State<ArchiveClarityProgressScreen> createState() =>
      _ArchiveClarityProgressScreenState();
}

class _ArchiveClarityProgressScreenState
    extends State<ArchiveClarityProgressScreen> {
  ArchiveClarityResult? _result;
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
          ArchiveClarityInput(
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
    final realEntriesList = SampleArchiveMode.excludeSampleEntries(entries);
    final realEntries = realEntriesList.length;
    final usable = ArchiveEvidenceGuard.eligibleReflectionCount(realEntriesList);
    if (!mounted) return;
    setState(() {
      _result = widget.engine.build(
        ArchiveClarityInput(
          realSavedMomentCount: realEntries,
          usableEvidenceCount: usable,
          hasWatchTheme: watchItems.isNotEmpty,
          betaFeedbackCaptured: BetaFeedbackStore.cached.hasResponse,
          weeklyReviewAvailable: widget.weeklyReviewAvailable,
        ),
      );
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PushedScreenShell(
      title: ArchiveClarityCopy.screenTitle,
      fallbackRoute: '/archive-belief',
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              key: const Key('archive_clarity_progress_screen'),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: _content(context, _result!),
            ),
    );
  }

  Widget _content(BuildContext context, ArchiveClarityResult result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          result.stageLabel,
          key: const Key('archive_clarity_progress_screen_stage'),
          style: ArchiveMobileTypography.listTitle(context),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          result.body,
          key: const Key('archive_clarity_progress_screen_body'),
          style: ArchiveMobileTypography.explanationBody(
            context,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          ArchiveClarityCopy.evidenceStrengthLabel,
          style: ArchiveMobileTypography.cardLabel(context),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          result.evidenceStrengthValue,
          key: const Key('archive_clarity_progress_screen_evidence'),
          style: ArchiveMobileTypography.listSubtitle(context),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          ArchiveClarityCopy.nextUsefulMomentLabel,
          style: ArchiveMobileTypography.cardLabel(context),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          result.nextStepText,
          key: const Key('archive_clarity_progress_screen_next'),
          style: ArchiveMobileTypography.listSubtitle(context),
        ),
        const SizedBox(height: AppSpacing.lg),
        InsightFeedbackActions(
          insightId: InsightFeedbackIds.archiveClarity,
          insightType: InsightFeedbackType.archiveClarity,
          sourceRoute: ArchiveClarityCopy.route,
          show: InsightFeedbackGates.showForArchiveClarity(
            hasInsight: result.stageLabel.isNotEmpty,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          key: const Key('archive_clarity_progress_screen_primary'),
          onPressed: () => context.push(result.primaryRoute),
          child: Text(result.primaryCtaLabel),
        ),
        if (result.isReviewReady) ...[
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            key: const Key('archive_clarity_progress_screen_then_vs_now'),
            onPressed: () => context.push(ThenNowCopy.route),
            child: const Text(ThenNowCopy.viewThenVsNowCta),
          ),
          OutlinedButton(
            key: const Key('archive_clarity_progress_screen_archive_calendar'),
            onPressed: () => context.push(ArchiveCalendarCopy.route),
            child: const Text(ArchiveCalendarCopy.openCalendarCta),
          ),
        ],
      ],
    );
  }
}
