import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design/archive_mobile_spacing.dart';
import '../features/activation/archive_evidence_map.dart';
import '../features/activation/context_insights.dart';
import '../features/activation/archive_health_action_plan.dart';
import '../features/activation/archive_health_score.dart';
import '../features/activation/belief_evidence_trail.dart';
import '../features/activation/next_moment_prompt.dart';
import '../features/activation/weekly_archive_review.dart';
import '../features/review_ritual/view_ritual_copy.dart';
import '../features/pressure_retention/shareable_archive_proof_engine.dart';
import '../features/pressure_retention/shareable_archive_proof_model.dart';
import '../services/app_services.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/voicememory_typography.dart';
import '../widgets/archive/archive_evidence_map_card.dart';
import '../widgets/archive/context_insights_card.dart';
import '../widgets/archive/archive_health_action_plan_card.dart';
import '../widgets/archive/archive_health_card.dart';
import '../widgets/archive/weekly_archive_review_card.dart';
import '../widgets/record/next_moment_prompt_card.dart';
import '../widgets/consumer/consumer_screen_back_header.dart';
import '../widgets/pressure_retention/shareable_archive_proof_card.dart';

/// Full weekly archive review — strongest thread, change, evidence, uncertainty.
class WeeklyArchiveReviewScreen extends StatefulWidget {
  const WeeklyArchiveReviewScreen({super.key, this.previewReview});

  /// Test-only: skip async load and render this review.
  @visibleForTesting
  final WeeklyArchiveReview? previewReview;

  @override
  State<WeeklyArchiveReviewScreen> createState() =>
      _WeeklyArchiveReviewScreenState();
}

class _WeeklyArchiveReviewScreenState extends State<WeeklyArchiveReviewScreen> {
  WeeklyArchiveReview? _review;
  ShareableArchiveProof? _shareProof;
  NextMomentPrompt? _nextMomentPrompt;
  ArchiveHealthScore? _archiveHealth;
  ArchiveHealthActionPlan? _actionPlan;
  ContextInsights? _contextInsights;
  ArchiveEvidenceMap? _evidenceMap;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    final preview = widget.previewReview;
    if (preview != null) {
      _review = preview;
      _archiveHealth = ArchiveHealthScoreEngine.build(entries: const []);
      _actionPlan = ArchiveHealthActionPlanEngine.build(entries: const []);
      _contextInsights = ContextInsightsEngine.build(entries: const []);
      _evidenceMap = ArchiveEvidenceMapEngine.build(entries: const []);
      _loading = false;
      return;
    }
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final entries = await AppServices.instance.journal.loadAll();
    if (!mounted) return;
    setState(() {
      _review = WeeklyArchiveReviewEngine.build(entries: entries);
      _shareProof = const ShareableArchiveProofEngine().buildFromJournal(
        entries: entries,
      );
      _nextMomentPrompt = NextMomentPromptEngine.build(entries: entries);
      _archiveHealth = ArchiveHealthScoreEngine.build(entries: entries);
      _actionPlan = ArchiveHealthActionPlanEngine.build(entries: entries);
      _contextInsights = ContextInsightsEngine.build(entries: entries);
      _evidenceMap = ArchiveEvidenceMapEngine.build(entries: entries);
      _loading = false;
    });
  }

  void _goToRecord() {
    context.go('/record');
  }

  void _goToEvidence() {
    context.push(BeliefEvidenceNavigation.route);
  }

  void _handleNextMomentPrompt(NextMomentPromptAction action) {
    switch (action) {
      case NextMomentPromptAction.addMoment:
        _goToRecord();
      case NextMomentPromptAction.viewEvidence:
        _goToEvidence();
      case NextMomentPromptAction.viewReview:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.backgroundPrimary,
        body: SafeArea(
          child: Padding(
            padding: ArchiveMobileSpacing.pagePadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const ConsumerScreenBackHeader(),
                const SizedBox(height: AppSpacing.lg),
                const Center(child: CircularProgressIndicator()),
              ],
            ),
          ),
        ),
      );
    }

    final review = _review ?? WeeklyArchiveReview.insufficient();

    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: ArchiveMobileSpacing.pagePadding,
            children: [
              const ConsumerScreenBackHeader(),
              const SizedBox(height: AppSpacing.sm),
              Text(
                review.title,
                key: const Key('weekly_archive_review_screen_title'),
                style: VoiceMemoryTypography.headlineStyle(),
              ),
              if (review.subtitle case final subtitle?) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  subtitle,
                  key: const Key('weekly_archive_review_screen_subtitle'),
                  style: VoiceMemoryTypography.bodyStyle(),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              WeeklyArchiveReviewCard(
                review: review,
                onAddAnother: review.hasEnoughEvidence ? _goToRecord : null,
                onViewEvidence: review.hasEnoughEvidence ? _goToEvidence : null,
              ),
              if (review.hasEnoughEvidence) ...[
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton(
                  key: const Key('weekly_archive_review_screen_review_ritual_link'),
                  onPressed: () => context.push(ReviewRitualCopy.route),
                  child: const Text(ReviewRitualCopy.openReviewRitualCta),
                ),
              ],
              if (review.hasEnoughEvidence &&
                  (_archiveHealth?.showCard ?? false)) ...[
                const SizedBox(height: AppSpacing.lg),
                ArchiveHealthCard(score: _archiveHealth!),
              ],
              if (review.hasEnoughEvidence &&
                  (_actionPlan?.showCard ?? false)) ...[
                const SizedBox(height: AppSpacing.lg),
                ArchiveHealthActionPlanCard(
                  plan: _actionPlan!,
                  onPrimary: _goToRecord,
                  onSecondary: _actionPlan!.secondaryAction ==
                          ArchiveHealthActionPlanCta.viewEvidence
                      ? _goToEvidence
                      : null,
                ),
              ],
              if (review.hasEnoughEvidence &&
                  (_contextInsights?.showCard ?? false)) ...[
                const SizedBox(height: AppSpacing.lg),
                ContextInsightsCard(insights: _contextInsights!),
              ],
              if (review.hasEnoughEvidence &&
                  (_evidenceMap?.showCard ?? false)) ...[
                const SizedBox(height: AppSpacing.lg),
                ArchiveEvidenceMapCard(
                  map: _evidenceMap!,
                  onRowTap: (tagId) => context.push(
                    ArchiveEvidenceMapNavigation.contextPath(tagId),
                  ),
                ),
              ],
              if (_shareProof?.hasProof == true) ...[
                const SizedBox(height: AppSpacing.lg),
                ShareableArchiveProofCard(proof: _shareProof!),
              ],
              if (_nextMomentPrompt?.stage == NextMomentPromptStage.fivePlus) ...[
                const SizedBox(height: AppSpacing.lg),
                NextMomentPromptCard(
                  prompt: _nextMomentPrompt!,
                  onPrimary: () => _handleNextMomentPrompt(
                    _nextMomentPrompt!.primaryAction,
                  ),
                  onSecondary: () => _handleNextMomentPrompt(
                    _nextMomentPrompt!.secondaryAction,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
