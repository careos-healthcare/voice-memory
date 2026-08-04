import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design/archive_mobile_typography.dart';
import '../features/archive_watchlist/archive_watchlist_store.dart';
import '../features/beta_feedback/beta_feedback_store.dart';
import '../features/beta_invite/beta_invite_store.dart';
import '../features/insight_feedback/insight_feedback_store.dart';
import '../features/pro_interest/pro_interest_store.dart';
import '../features/pro_interest/pro_interest_copy.dart';
import '../features/then_now/then_now_copy.dart';
import '../features/archive_calendar/archive_calendar_copy.dart';
import '../features/insight_feedback/insight_feedback_copy.dart';
import '../features/milestone_share/milestone_share_copy.dart';
import '../features/beta_outcomes/beta_outcomes_copy.dart';
import '../features/beta_outcomes/beta_outcomes_engine.dart';
import '../features/beta_outcomes/beta_outcomes_models.dart';
import '../features/return_ritual/return_ritual_store.dart';
import '../features/share/archive_share_actions.dart';
import '../services/app_services.dart';
import '../services/journal_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../widgets/pushed_screen_shell.dart';

/// Local beta validation dashboard — read-only counts, no uploads.
class BetaOutcomesScreen extends StatefulWidget {
  const BetaOutcomesScreen({
    super.key,
    this.journalService,
    this.watchlistStore,
    this.returnRitualStore,
    this.engine = const BetaOutcomesEngine(),
  });

  final JournalService? journalService;
  final ArchiveWatchlistStore? watchlistStore;
  final ReturnRitualStore? returnRitualStore;
  final BetaOutcomesEngine engine;

  @override
  State<BetaOutcomesScreen> createState() => _BetaOutcomesScreenState();
}

class _BetaOutcomesScreenState extends State<BetaOutcomesScreen> {
  BetaOutcomesSnapshot? _snapshot;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final journal = widget.journalService ?? AppServices.instance.journal;
    final watchlist =
        widget.watchlistStore ??
        ArchiveWatchlistStore(AppServices.instance.prefs);
    final returnRitual =
        widget.returnRitualStore ??
        ReturnRitualStore(AppServices.instance.prefs);
    await BetaFeedbackStore.ensureLoaded();
    await ProInterestStore.ensureLoaded();
    await BetaInviteStore.ensureLoaded();
    await InsightFeedbackStore.ensureLoaded();
    final entries = await journal.loadAll();
    final watchItems = await watchlist.loadItems();
    final ritual = await returnRitual.load();
    if (!mounted) return;
    setState(() {
      _snapshot = widget.engine.buildFromJournal(
        entries: entries,
        watchThemesCount: watchItems.length,
        returnRitualSet: ritual?.isValid == true,
        feedbackState: BetaFeedbackStore.cached,
        proInterestState: ProInterestStore.cached,
        betaInviteCopyStats: BetaInviteStore.cached,
        hasWatchTheme: watchItems.isNotEmpty,
      );
      _loading = false;
    });
  }

  Future<void> _copySummary(BetaOutcomesSnapshot snapshot) async {
    final outcome = await ArchiveShareActions.copyShareText(
      context,
      text: BetaOutcomesCopy.buildSafeSummary(snapshot),
      showConfirmation: false,
    );
    if (!mounted) return;
    if (outcome == ArchiveShareOutcome.copied ||
        outcome == ArchiveShareOutcome.fallbackCopied) {
      ArchiveShareActions.showFeedback(context, BetaOutcomesCopy.summaryCopied);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return PushedScreenShell(
        title: BetaOutcomesCopy.screenTitle,
        fallbackRoute: '/support-feedback',
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final snapshot = _snapshot!;
    return PushedScreenShell(
      title: BetaOutcomesCopy.screenTitle,
      fallbackRoute: '/support-feedback',
      body: SingleChildScrollView(
        key: const Key('beta_outcomes_screen'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              BetaOutcomesCopy.subtitle,
              key: const Key('beta_outcomes_subtitle'),
              style: ArchiveMobileTypography.explanationBody(
                context,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              BetaOutcomesCopy.metricsSectionTitle,
              style: ArchiveMobileTypography.cardLabel(context),
            ),
            const SizedBox(height: AppSpacing.sm),
            _metricRow(
              context,
              key: const Key('beta_outcomes_first_week_path'),
              label: BetaOutcomesCopy.firstWeekPathProgressLabel,
              value: snapshot.firstWeekPathProgressLabel,
            ),
            _metricRow(
              context,
              key: const Key('beta_outcomes_archive_clarity'),
              label: BetaOutcomesCopy.archiveClarityStageLabel,
              value: snapshot.archiveClarityStageLabel,
            ),
            _metricRow(
              context,
              key: const Key('beta_outcomes_then_vs_now'),
              label: ThenNowCopy.betaOutcomesLabel,
              value: snapshot.thenVsNowAvailableLabel,
            ),
            _metricRow(
              context,
              key: const Key('beta_outcomes_archive_calendar'),
              label: ArchiveCalendarCopy.betaOutcomesLabel,
              value: snapshot.archiveCalendarAvailableLabel,
            ),
            _metricRow(
              context,
              key: const Key('beta_outcomes_insight_feedback'),
              label: InsightFeedbackCopy.betaOutcomesLabel,
              value: snapshot.insightFeedbackCapturedLabel,
            ),
            _metricRow(
              context,
              key: const Key('beta_outcomes_milestone_share'),
              label: MilestoneShareCopy.betaOutcomesLabel,
              value: snapshot.milestoneShareCountLabel,
            ),
            _metricRow(
              context,
              key: const Key('beta_outcomes_saved_moments'),
              label: BetaOutcomesCopy.savedMomentsLabel,
              value: '${snapshot.savedMomentCount}',
            ),
            _metricRow(
              context,
              key: const Key('beta_outcomes_usable_evidence'),
              label: BetaOutcomesCopy.usableEvidenceLabel,
              value: '${snapshot.usableEvidenceCount}',
            ),
            _metricRow(
              context,
              key: const Key('beta_outcomes_depth_level'),
              label: BetaOutcomesCopy.depthLevelLabel,
              value: snapshot.depthLevelLabel,
            ),
            _metricRow(
              context,
              key: const Key('beta_outcomes_watch_themes'),
              label: BetaOutcomesCopy.watchThemesLabel,
              value: '${snapshot.watchThemesCount}',
            ),
            _metricRow(
              context,
              key: const Key('beta_outcomes_return_ritual'),
              label: BetaOutcomesCopy.returnRitualLabel,
              value: snapshot.returnRitualSet
                  ? BetaOutcomesCopy.yesLabel
                  : BetaOutcomesCopy.noLabel,
            ),
            _metricRow(
              context,
              key: const Key('beta_outcomes_feedback_status'),
              label: BetaOutcomesCopy.feedbackStatusLabel,
              value: snapshot.feedbackStatusLabel,
            ),
            _metricRow(
              context,
              key: const Key('beta_outcomes_optional_note'),
              label: BetaOutcomesCopy.optionalNoteLabel,
              value: snapshot.optionalNotePresent
                  ? BetaOutcomesCopy.yesLabel
                  : BetaOutcomesCopy.noLabel,
            ),
            _metricRow(
              context,
              key: const Key('beta_outcomes_testimonial_copied'),
              label: BetaOutcomesCopy.testimonialCopiedLabel,
              value: snapshot.testimonialCopied
                  ? BetaOutcomesCopy.yesLabel
                  : BetaOutcomesCopy.noLabel,
            ),
            _metricRow(
              context,
              key: const Key('beta_outcomes_share_proof_ready'),
              label: BetaOutcomesCopy.shareProofReadyLabel,
              value: snapshot.shareProofReady
                  ? BetaOutcomesCopy.yesLabel
                  : BetaOutcomesCopy.noLabel,
            ),
            _metricRow(
              context,
              key: const Key('beta_outcomes_pro_interest_captured'),
              label: BetaOutcomesCopy.proInterestCapturedLabel,
              value: snapshot.proInterestCaptured
                  ? BetaOutcomesCopy.yesLabel
                  : BetaOutcomesCopy.noLabel,
            ),
            _metricRow(
              context,
              key: const Key('beta_outcomes_pro_interest_value_count'),
              label: BetaOutcomesCopy.proInterestValueCountLabel,
              value: '${snapshot.selectedProValueCount}',
            ),
            _metricRow(
              context,
              key: const Key('beta_outcomes_pro_interest_pricing'),
              label: BetaOutcomesCopy.proInterestPricingLabel,
              value: snapshot.proInterestPricingLabel,
            ),
            _metricRow(
              context,
              key: const Key('beta_outcomes_pro_interest_note_present'),
              label: BetaOutcomesCopy.proInterestNotePresentLabel,
              value: snapshot.proInterestNotePresent
                  ? BetaOutcomesCopy.yesLabel
                  : BetaOutcomesCopy.noLabel,
            ),
            _metricRow(
              context,
              key: const Key('beta_outcomes_beta_invite_copied'),
              label: BetaOutcomesCopy.betaInviteCopiedLabel,
              value: '${snapshot.betaInviteCopiedCount}',
            ),
            _metricRow(
              context,
              key: const Key('beta_outcomes_beta_invite_last_variant'),
              label: BetaOutcomesCopy.betaInviteLastVariantLabel,
              value: snapshot.betaInviteLastVariantLabel,
            ),
            _metricRow(
              context,
              key: const Key('beta_outcomes_beta_invite_task_copied'),
              label: BetaOutcomesCopy.betaInviteTaskCopiedLabel,
              value: snapshot.betaInviteTaskCopied
                  ? BetaOutcomesCopy.yesLabel
                  : BetaOutcomesCopy.noLabel,
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              BetaOutcomesCopy.interpretationSectionTitle,
              style: ArchiveMobileTypography.cardLabel(context),
            ),
            const SizedBox(height: AppSpacing.sm),
            for (var i = 0; i < snapshot.interpretations.length; i++)
              Padding(
                key: Key('beta_outcomes_interpretation_$i'),
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Text(
                  snapshot.interpretations[i],
                  style: ArchiveMobileTypography.explanationBody(
                    context,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('beta_outcomes_open_beta_feedback'),
                onPressed: () => context.push('/beta-feedback'),
                child: const Text(BetaOutcomesCopy.openBetaFeedbackButton),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: const Key('beta_outcomes_open_pro_interest'),
                onPressed: () => context.push('/pro-interest'),
                child: const Text(ProInterestCopy.openProInterestButton),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: const Key('beta_outcomes_open_beta_invite_pack'),
                onPressed: () => context.push('/beta-invite-pack'),
                child: const Text(BetaOutcomesCopy.openBetaInvitePackButton),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: const Key('beta_outcomes_copy_summary'),
                onPressed: () => _copySummary(snapshot),
                child: const Text(BetaOutcomesCopy.copySummaryButton),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: const Key('beta_outcomes_open_sample_archive'),
                onPressed: () => context.push('/sample-archive'),
                child: const Text(BetaOutcomesCopy.openSampleArchiveButton),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: const Key('beta_outcomes_add_moment'),
                onPressed: () => context.go('/record'),
                child: const Text(BetaOutcomesCopy.addMomentButton),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _metricRow(
    BuildContext context, {
    required Key key,
    required String label,
    required String value,
  }) {
    return Padding(
      key: key,
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: ArchiveMobileTypography.explanationBody(
                context,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: ArchiveMobileTypography.explanationBody(context),
            ),
          ),
        ],
      ),
    );
  }
}
