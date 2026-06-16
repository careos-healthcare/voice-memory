import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design/archive_mobile_spacing.dart';
import '../design/archive_mobile_typography.dart';
import '../features/prove_enough/prove_enough_evidence_trail_navigation.dart';
import '../features/signal_archive/signal_archive_navigation.dart';
import '../features/retention/reminder_pre_prompt_coordinator.dart';
import '../features/signal_review/signal_review_coordinator.dart';
import '../widgets/retention/reminder_pre_prompt_sheet.dart';
import '../features/signal_review/signal_review_engine.dart';
import '../features/signal_review/signal_review_model.dart';
import '../features/signal_review/signal_review_navigation.dart';
import '../features/post_save_insight/signal_feedback_store.dart';
import '../features/post_save_insight/signal_feedback_model.dart';
import '../models/entitlement.dart';
import '../product/consumer_ui_copy.dart';
import '../product/loop_mode_copy.dart';
import '../services/app_services.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/voicememory_cards.dart';
import '../widgets/loop_mode/loop_paywall_teaser_card.dart';
import '../widgets/prove_enough/prove_enough_retention_panel.dart';
import '../widgets/prove_enough/loop_trigger_map_section.dart';

class SignalReviewScreen extends StatefulWidget {
  const SignalReviewScreen({super.key, this.initialReview});

  @visibleForTesting
  final SignalReview? initialReview;

  @override
  State<SignalReviewScreen> createState() => _SignalReviewScreenState();
}

class _SignalReviewScreenState extends State<SignalReviewScreen> {
  static const _engine = SignalReviewEngine();

  SignalReview? _review;
  bool _loading = true;
  bool _busy = false;
  String? _banner;
  PremiumEntitlements? _entitlements;
  bool _showPaywallTeaser = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialReview != null) {
      _review = widget.initialReview;
      _loading = false;
      unawaited(_afterReviewLoaded(widget.initialReview!));
      return;
    }
    _load();
  }

  Future<void> _afterReviewLoaded(SignalReview review) async {
    await SignalReviewCoordinator.markViewed(review);
    await _refreshPaywallTeaser(review);
  }

  Future<void> _refreshPaywallTeaser(SignalReview review) async {
    PremiumEntitlements? entitlements = _entitlements;
    if (AppServices.isInitialized && entitlements == null) {
      entitlements = await AppServices.instance.billing.loadEntitlements();
    }
    final show = await SignalReviewCoordinator.shouldShowLoopPaywallTeaser(
      review: review,
      entitlements: entitlements,
    );
    if (!mounted) return;
    setState(() {
      _entitlements = entitlements;
      _showPaywallTeaser = show;
    });
  }

  Future<void> _load() async {
    final review = await SignalReviewCoordinator.loadForActiveJourney();
    if (!mounted) return;
    setState(() {
      _review = review;
      _loading = false;
    });
    if (review != null) {
      await _afterReviewLoaded(review);
    }
  }

  Future<void> _confirm() async {
    final review = _review;
    if (review == null || _busy) return;
    setState(() => _busy = true);
    final updated = await SignalReviewCoordinator.confirm(reviewId: review.id);
    if (!mounted) return;
    final banner = review.isLoopSpecificReview
        ? LoopModeCopy.reviewConfirmSaved
        : ConsumerUiCopy.signalReviewSavedPattern;
    setState(() {
      _review = updated;
      _banner = banner;
      _busy = false;
    });
    if (updated != null) {
      await _refreshPaywallTeaser(updated);
    }
    unawaited(
      maybeOfferReminderPrePrompt(
        context,
        trigger: ReminderPrePromptTrigger.signalReviewConfirmed,
        prompt: review.nextEvidencePrompt,
      ),
    );
  }

  Future<void> _keepWatching() async {
    final review = _review;
    if (review == null || _busy) return;
    setState(() => _busy = true);
    final updated = await SignalReviewCoordinator.keepWatching(
      reviewId: review.id,
    );
    if (!mounted) return;
    final banner = review.isLoopSpecificReview
        ? LoopModeCopy.reviewKeepWatchingSaved
        : ConsumerUiCopy.signalReviewWatchingSaved;
    setState(() {
      _review = updated;
      _banner = banner;
      _busy = false;
    });
    SignalReviewNavigation.recordNextEvidence(
      context,
      prompt: updated?.nextEvidencePrompt,
    );
  }

  Future<void> _showCorrectionSheet() async {
    final review = _review;
    if (review == null || _busy) return;

    final feedback = AppServices.isInitialized
        ? await SignalFeedbackStore.instance().loadAll()
        : <PostSaveSignalFeedback>[];

    final alternatives = _engine.correctionAlternatives(
      review: review,
      feedback: feedback,
    );
    if (!mounted) return;

    if (alternatives.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(ConsumerUiCopy.signalReviewNeedsMoreEvidence),
        ),
      );
      return;
    }

    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.backgroundPrimary,
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: ArchiveMobileSpacing.pagePadding,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  ConsumerUiCopy.signalReviewCorrectionTitle,
                  style: ArchiveMobileTypography.responsiveSectionTitle(ctx),
                ),
                const SizedBox(height: AppSpacing.md),
                for (final alt in alternatives)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, alt),
                      child: Text(alt, textAlign: TextAlign.center),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );

    if (picked == null || !mounted) return;
    setState(() => _busy = true);
    final updated = await SignalReviewCoordinator.correct(
      reviewId: review.id,
      alternativeTitle: picked,
    );
    if (!mounted) return;
    setState(() {
      _review = updated;
      _banner = ConsumerUiCopy.signalReviewSavedCorrection;
      _busy = false;
    });
  }

  Future<void> _dismissPaywallTeaser() async {
    await SignalReviewCoordinator.dismissLoopPaywallTeaser();
    if (!mounted) return;
    setState(() => _showPaywallTeaser = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final review = _review;
    if (review == null) {
      return _emptyState(context);
    }

    if (review.isLoopSpecificReview) {
      return _buildLoopBody(context, review);
    }

    return _buildGenericBody(context, review);
  }

  Widget _buildLoopBody(BuildContext context, SignalReview review) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: ArchiveMobileSpacing.pagePadding,
        children: [
          if (_banner != null) ...[
            _bannerCard(context, _banner!),
            const SizedBox(height: AppSpacing.lg),
          ],
          Text(
            review.loopTitle ?? LoopModeCopy.capacityReviewTitle,
            style: ArchiveMobileTypography.responsivePageTitle(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (review.reviewSubtitle?.trim().isNotEmpty == true)
            Text(
              review.reviewSubtitle!,
              style: ArchiveMobileTypography.responsiveBody(context),
            ),
          if (review.reviewConfidenceLabel?.trim().isNotEmpty == true) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              review.reviewConfidenceLabel!,
              style: ArchiveMobileTypography.cardLabel(context),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          if (review.needsMoreEvidence)
            Text(
              ConsumerUiCopy.signalReviewNeedsMoreEvidence,
              style: ArchiveMobileTypography.explanationBody(context),
            )
          else ...[
            _section(
              context,
              LoopModeCopy.reviewWhatRepeated,
              review.whatRepeated,
            ),
            _section(
              context,
              LoopModeCopy.reviewWhatItCost,
              review.whatItSeemedToCost ?? '',
            ),
            _section(
              context,
              review.isProveEnoughLoopReview
                  ? LoopModeCopy.reviewWhatTriggeredEffort
                  : LoopModeCopy.reviewWhatTriggeredYes,
              review.commonTrigger ?? '',
            ),
            _section(
              context,
              LoopModeCopy.reviewWhatChanged,
              review.whatChanged,
            ),
            _evidenceSection(context, review.evidenceLines),
            _section(
              context,
              LoopModeCopy.reviewProveWrong,
              review.whatWouldProveThisWrong ?? review.possibleContradictions,
            ),
            _recordNextSection(context, review),
          ],
          if (review.isProveEnoughLoopReview) ...[
            const SizedBox(height: AppSpacing.lg),
            LoopTriggerMapSection(),
          ],
          if (review.isProveEnoughLoopReview &&
              (review.isActionable ||
                  review.reviewStatus == SignalReviewStatus.watching)) ...[
            const SizedBox(height: AppSpacing.lg),
            ProveEnoughRetentionPanel(journeyId: review.journeyId),
          ],
          const SizedBox(height: AppSpacing.lg),
          if (review.isActionable) ...[
            FilledButton(
              onPressed: _busy ? null : _keepWatching,
              child: Text(LoopModeCopy.reviewKeepWatchingLoop),
            ),
            const SizedBox(height: AppSpacing.xs),
            OutlinedButton(
              onPressed: _busy ? null : _confirm,
              child: Text(LoopModeCopy.reviewFeelsRight),
            ),
            const SizedBox(height: AppSpacing.xs),
            OutlinedButton(
              onPressed: _busy ? null : _showCorrectionSheet,
              child: Text(LoopModeCopy.reviewCorrect),
            ),
            const SizedBox(height: AppSpacing.xs),
            OutlinedButton(
              onPressed: _busy
                  ? null
                  : () => SignalReviewNavigation.recordNextEvidence(
                      context,
                      prompt: review.nextEvidencePrompt,
                    ),
              child: Text(_recordNextCta(review)),
            ),
          ] else if (review.reviewStatus == SignalReviewStatus.confirmed) ...[
            OutlinedButton(
              onPressed: () => SignalReviewNavigation.recordNextEvidence(
                context,
                prompt: review.nextEvidencePrompt,
              ),
              child: Text(_recordNextCta(review)),
            ),
          ] else ...[
            OutlinedButton(
              onPressed: _busy ? null : _keepWatching,
              child: Text(LoopModeCopy.reviewKeepWatchingLoop),
            ),
          ],
          if (_showPaywallTeaser) ...[
            const SizedBox(height: AppSpacing.lg),
            LoopPaywallTeaserCard(
              shouldShow: _showPaywallTeaser,
              entitlements: _entitlements,
              loopModeId: review.loopModeId,
              onDismissed: _dismissPaywallTeaser,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGenericBody(BuildContext context, SignalReview review) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: ArchiveMobileSpacing.pagePadding,
        children: [
          if (_banner != null) ...[
            _bannerCard(context, _banner!),
            const SizedBox(height: AppSpacing.lg),
          ],
          Text(
            review.signalTitle,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _engine.statusLabel(review.reviewStatus),
            style: ArchiveMobileTypography.cardLabel(context),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (review.needsMoreEvidence)
            Text(
              ConsumerUiCopy.signalReviewNeedsMoreEvidence,
              style: ArchiveMobileTypography.explanationBody(context),
            )
          else ...[
            _section(
              context,
              ConsumerUiCopy.signalReviewWhatRepeated,
              review.whatRepeated,
            ),
            _section(
              context,
              ConsumerUiCopy.signalReviewWhatChanged,
              review.whatChanged,
            ),
            _evidenceSection(context, review.evidenceLines),
            _section(
              context,
              ConsumerUiCopy.signalReviewPossibleWrong,
              review.possibleContradictions,
            ),
            _section(
              context,
              ConsumerUiCopy.signalReviewWhatToWatchNext,
              review.whatToWatchNext,
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          if (review.isActionable) ...[
            FilledButton(
              onPressed: _busy ? null : _confirm,
              child: const Text(ConsumerUiCopy.signalReviewConfirmPattern),
            ),
            const SizedBox(height: AppSpacing.xs),
            OutlinedButton(
              onPressed: _busy ? null : _showCorrectionSheet,
              child: const Text(ConsumerUiCopy.signalReviewCorrectRead),
            ),
            const SizedBox(height: AppSpacing.xs),
            OutlinedButton(
              onPressed: _busy ? null : _keepWatching,
              child: const Text(ConsumerUiCopy.signalReviewKeepWatching),
            ),
          ] else if (review.reviewStatus == SignalReviewStatus.confirmed) ...[
            FilledButton(
              onPressed: () => SignalReviewNavigation.openPatterns(context),
              child: const Text(ConsumerUiCopy.signalReviewViewPattern),
            ),
            const SizedBox(height: AppSpacing.xs),
            OutlinedButton(
              onPressed: () => SignalReviewNavigation.recordNextEvidence(
                context,
                prompt: review.nextEvidencePrompt,
              ),
              child: const Text(ConsumerUiCopy.signalReviewRecordNext),
            ),
          ] else ...[
            OutlinedButton(
              onPressed: _busy ? null : _keepWatching,
              child: const Text(ConsumerUiCopy.signalReviewKeepWatching),
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          OutlinedButton(
            onPressed: _busy ? null : () => _openEvidenceTrail(context),
            child: const Text(ConsumerUiCopy.signalReviewViewTrail),
          ),
          const SizedBox(height: AppSpacing.xs),
          OutlinedButton(
            onPressed: () => SignalReviewNavigation.recordNextEvidence(
              context,
              prompt: review.nextEvidencePrompt,
            ),
            child: const Text(ConsumerUiCopy.signalReviewRecordNext),
          ),
        ],
      ),
    );
  }

  Future<void> _openEvidenceTrail(BuildContext context) async {
    final review = _review;
    if (review?.isProveEnoughLoopReview == true) {
      ProveEnoughEvidenceTrailNavigation.open(context);
      return;
    }

    PremiumEntitlements? entitlements;
    if (AppServices.isInitialized) {
      entitlements = await AppServices.instance.billing.loadEntitlements();
    }
    final gate = await SignalReviewCoordinator.shouldGatePremiumArchive(
      entitlements: entitlements,
    );
    if (!context.mounted) return;
    if (gate) {
      context.push('/pricing');
      return;
    }
    SignalArchiveNavigation.openEvidenceTrail(context);
  }

  Widget _emptyState(BuildContext context) {
    return Padding(
      padding: ArchiveMobileSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            ConsumerUiCopy.signalReviewEmptyTitle,
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            ConsumerUiCopy.signalReviewEmptyBody,
            style: ArchiveMobileTypography.explanationBody(context),
          ),
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: () => context.go('/record'),
            child: const Text(ConsumerUiCopy.signalReviewRecordMoment),
          ),
        ],
      ),
    );
  }

  Widget _bannerCard(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF0FFF4),
      ),
      child: Text(
        text,
        style: ArchiveMobileTypography.explanationBody(context),
      ),
    );
  }

  Widget _section(BuildContext context, String label, String body) {
    if (body.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: ArchiveMobileTypography.cardLabel(context)),
          const SizedBox(height: AppSpacing.xs),
          Text(body, style: ArchiveMobileTypography.explanationBody(context)),
        ],
      ),
    );
  }

  Widget _evidenceSection(BuildContext context, List<String> lines) {
    if (lines.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            LoopModeCopy.reviewEvidenceSoFar,
            style: ArchiveMobileTypography.cardLabel(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: VoiceMemoryCards.standard(
                  background: const Color(0xFFF8F9FC),
                ),
                child: Text(
                  line,
                  style: ArchiveMobileTypography.explanationBody(context),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _recordNextCta(SignalReview review) {
    if (review.isProveEnoughLoopReview) {
      return LoopModeCopy.reviewRecordNextProve;
    }
    return LoopModeCopy.reviewRecordNextYes;
  }

  List<String> _recordNextPrompts(SignalReview review) {
    if (review.isProveEnoughLoopReview) {
      return LoopModeCopy.proveEnoughReviewNextPrompts;
    }
    return LoopModeCopy.capacityReviewNextPrompts;
  }

  Widget _recordNextSection(BuildContext context, SignalReview review) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            LoopModeCopy.reviewRecordNext,
            style: ArchiveMobileTypography.cardLabel(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          for (final prompt in _recordNextPrompts(review))
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Text(
                '• $prompt',
                style: ArchiveMobileTypography.explanationBody(context),
              ),
            ),
        ],
      ),
    );
  }
}
