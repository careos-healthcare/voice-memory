import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../config/screenshot_mode.dart';
import '../design/archive_mobile_typography.dart';
import '../features/then_now/then_now_copy.dart';
import '../features/then_now/then_now_engine.dart';
import '../features/then_now/then_now_models.dart';
import '../services/app_services.dart';
import '../services/journal_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/pushed_screen_shell.dart';

/// Full Then vs Now screen — cautious summaries, no journal text.
class ThenVsNowScreen extends StatefulWidget {
  const ThenVsNowScreen({
    super.key,
    this.journalService,
    this.engine = const ThenNowEngine(),
    ThenNowResult? initialResult,
    this.weeklyReviewAvailable = false,
  }) : _initialResult = initialResult;

  final JournalService? journalService;
  final ThenNowEngine engine;
  final bool weeklyReviewAvailable;
  final ThenNowResult? _initialResult;

  @override
  State<ThenVsNowScreen> createState() => _ThenVsNowScreenState();
}

class _ThenVsNowScreenState extends State<ThenVsNowScreen> {
  ThenNowResult? _result;
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
          ThenNowInput(
            realSavedMomentCount: 0,
            usableEvidenceCount: 0,
            sampleMode: true,
          ),
        );
        _loading = false;
      });
      return;
    }

    final journal = widget.journalService ?? AppServices.instance.journal;
    final entries = await journal.loadAll();
    if (!mounted) return;
    setState(() {
      _result = widget.engine.buildFromJournal(
        entries: entries,
        weeklyReviewAvailable: widget.weeklyReviewAvailable,
      );
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PushedScreenShell(
      title: ThenNowCopy.eyebrow,
      fallbackRoute: ThenNowCopy.archiveHomeRoute,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              key: const Key('then_vs_now_screen'),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: _content(context, _result!),
            ),
    );
  }

  Widget _content(BuildContext context, ThenNowResult result) {
    if (!result.hasCard) {
      return _insufficientState(context, result);
    }
    return _comparisonState(context, result);
  }

  Widget _insufficientState(BuildContext context, ThenNowResult result) {
    final title = result.reasonId == ThenNowReasonId.noClearChange
        ? ThenNowCopy.noClearChangeTitle
        : ThenNowCopy.insufficientTitle;
    final body = result.whatThisMeans ??
        (result.reasonId == ThenNowReasonId.noClearChange
            ? ThenNowCopy.noClearChangeBody
            : ThenNowCopy.insufficientBody);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          key: const Key('then_vs_now_screen_insufficient_title'),
          style: ArchiveMobileTypography.listTitle(context),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          body,
          key: const Key('then_vs_now_screen_insufficient_body'),
          style: ArchiveMobileTypography.explanationBody(
            context,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          key: const Key('then_vs_now_screen_save_button'),
          onPressed: () => context.push(ThenNowCopy.recordRoute),
          child: const Text(ThenNowCopy.saveMomentCta),
        ),
      ],
    );
  }

  Widget _comparisonState(BuildContext context, ThenNowResult result) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          result.headline,
          key: const Key('then_vs_now_screen_headline'),
          style: ArchiveMobileTypography.listTitle(context),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          result.thenLabel,
          style: ArchiveMobileTypography.cardLabel(context),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          result.thenSummary,
          key: const Key('then_vs_now_screen_then_summary'),
          style: ArchiveMobileTypography.listSubtitle(context),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          result.nowLabel,
          style: ArchiveMobileTypography.cardLabel(context),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          result.nowSummary,
          key: const Key('then_vs_now_screen_now_summary'),
          style: ArchiveMobileTypography.listSubtitle(context),
        ),
        const SizedBox(height: AppSpacing.lg),
        Text(
          result.evidenceCountLabel,
          key: const Key('then_vs_now_screen_evidence'),
          style: ArchiveMobileTypography.explanationBody(
            context,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          result.cautionLabel,
          key: const Key('then_vs_now_screen_caution'),
          style: ArchiveMobileTypography.explanationBody(
            context,
            color: AppColors.textSecondary,
          ),
        ),
        if (result.whatThisMeans != null) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(
            'What this means',
            style: ArchiveMobileTypography.cardLabel(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            result.whatThisMeans!,
            key: const Key('then_vs_now_screen_what_this_means'),
            style: ArchiveMobileTypography.listSubtitle(context),
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        FilledButton(
          key: const Key('then_vs_now_screen_save_another_button'),
          onPressed: () => context.push(ThenNowCopy.recordRoute),
          child: const Text(ThenNowCopy.saveAnotherMomentCta),
        ),
        if (widget.weeklyReviewAvailable) ...[
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            key: const Key('then_vs_now_screen_weekly_review_button'),
            onPressed: () => context.push(
              ThenNowCopy.weeklyReviewRoute(
                weeklyReviewAvailable: widget.weeklyReviewAvailable,
              ),
            ),
            child: const Text(ThenNowCopy.reviewWeeklyArchiveCta),
          ),
        ],
      ],
    );
  }
}
