import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:voicememory_mobile/design/archive_mobile_spacing.dart';
import 'package:voicememory_mobile/design/archive_mobile_typography.dart';
import 'package:voicememory_mobile/design/archive_responsive_layout.dart';
import 'package:voicememory_mobile/features/loop_mode/loop_mode_coordinator.dart';
import 'package:voicememory_mobile/features/loop_mode/loop_mode_model.dart';
import 'package:voicememory_mobile/features/signal_archive/signal_archive_navigation.dart';
import 'package:voicememory_mobile/features/signal_journey/signal_journey_coordinator.dart';
import 'package:voicememory_mobile/features/signal_journey/signal_journey_engine.dart';
import 'package:voicememory_mobile/features/signal_journey/signal_journey_model.dart';
import 'package:voicememory_mobile/features/signal_journey/signal_journey_navigation.dart';
import 'package:voicememory_mobile/features/signal_archive/signal_corrections_engine.dart';
import 'package:voicememory_mobile/features/signal_review/signal_review_coordinator.dart';
import 'package:voicememory_mobile/features/signal_review/signal_review_model.dart';
import 'package:voicememory_mobile/features/signal_review/signal_review_navigation.dart';
import 'package:voicememory_mobile/features/post_save_insight/signal_feedback_model.dart';
import 'package:voicememory_mobile/features/post_save_insight/signal_feedback_store.dart';
import 'package:voicememory_mobile/services/app_services.dart';
import 'package:voicememory_mobile/product/consumer_ui_copy.dart';
import 'package:voicememory_mobile/theme/app_colors.dart';
import 'package:voicememory_mobile/theme/app_spacing.dart';
import 'package:voicememory_mobile/theme/voicememory_cards.dart';
import 'package:voicememory_mobile/widgets/signal/signal_corrections_card.dart';
import 'package:voicememory_mobile/widgets/signal/signal_review_card.dart';
import 'package:voicememory_mobile/widgets/prove_enough/prove_enough_retention_panel.dart';

class SignalJourneyScreen extends StatefulWidget {
  const SignalJourneyScreen({
    super.key,
    this.initialJourney,
    this.initialReview,
  });

  @visibleForTesting
  final SignalJourney? initialJourney;

  @visibleForTesting
  final SignalReview? initialReview;

  @override
  State<SignalJourneyScreen> createState() => _SignalJourneyScreenState();
}

class _SignalJourneyScreenState extends State<SignalJourneyScreen> {
  static const _engine = SignalJourneyEngine();

  SignalJourney? _journey;
  SignalReview? _review;
  LoopMode? _activeLoop;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialJourney != null) {
      _journey = widget.initialJourney;
      _review = widget.initialReview;
      _loading = false;
      return;
    }
    _load();
  }

  Future<void> _load() async {
    final journey = await SignalJourneyCoordinator.loadActive();
    SignalReview? review;
    LoopMode? activeLoop;
    if (journey != null && journey.isConfirmed) {
      review = await SignalReviewCoordinator.loadForActiveJourney();
    }
    activeLoop = await LoopModeCoordinator.loadActive();
    if (!mounted) return;
    setState(() {
      _journey = journey;
      _review = review;
      _activeLoop = activeLoop;
      _loading = false;
    });
  }

  Future<void> _markNotMe() async {
    final journey = _journey;
    if (journey == null || _busy) return;
    setState(() => _busy = true);
    await SignalJourneyCoordinator.onSignalRejected(
      signalId: journey.signalId,
      readId: journey.readId,
      categoryId: journey.categoryId,
      signalTitle: journey.signalTitle,
    );
    await _load();
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _archive() async {
    if (_busy) return;
    setState(() => _busy = true);
    await SignalJourneyCoordinator.archiveActive();
    await _load();
    if (mounted) setState(() => _busy = false);
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
    final journey = _journey;
    if (journey == null) return _emptyState(context);

    return FutureBuilder<List<PostSaveSignalFeedback>>(
      future: AppServices.isInitialized
          ? SignalFeedbackStore.instance().loadAll()
          : Future.value(const []),
      builder: (context, snapshot) {
        final corrections = const SignalCorrectionsEngine().build(
          feedback: snapshot.data ?? const [],
          currentSignal: null,
        );
        return RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: ArchiveMobileSpacing.pagePadding,
            children: [
              Text(
                ConsumerUiCopy.signalJourneyDetailTitle,
                style: ArchiveMobileTypography.archiveSurfaceTitle(context),
              ),
              const SizedBox(height: AppSpacing.lg),
              _header(context, journey),
              const SizedBox(height: AppSpacing.lg),
              _section(
                context,
                ConsumerUiCopy.signalJourneyEvidenceSoFar,
                journey.evidenceSummary ??
                    '${journey.supportingCount} supporting moment(s) saved.',
              ),
              _section(
                context,
                ConsumerUiCopy.signalJourneyWouldConfirm,
                journey.wouldConfirm ?? '',
              ),
              _section(
                context,
                ConsumerUiCopy.signalJourneyWouldChallenge,
                journey.wouldChallenge ?? '',
              ),
              _section(
                context,
                ConsumerUiCopy.signalJourneyRecordNext,
                journey.nextPrompt,
              ),
              if (_activeLoop?.isProveEnough == true) ...[
                const SizedBox(height: AppSpacing.lg),
                ProveEnoughRetentionPanel(journeyId: journey.id),
              ],
              if (_review != null && _review!.isShowable) ...[
                const SizedBox(height: AppSpacing.lg),
                SignalReviewCard(
                  review: _review!,
                  onConfirm: () async {
                    await SignalReviewCoordinator.confirm(
                      reviewId: _review!.id,
                    );
                    if (!mounted) return;
                    await _load();
                  },
                  onCorrect: () =>
                      SignalReviewNavigation.openFullReview(context),
                  onKeepWatching: () async {
                    await SignalReviewCoordinator.keepWatching(
                      reviewId: _review!.id,
                    );
                    if (!mounted) return;
                    await _load();
                  },
                ),
              ],
              if (corrections.hasCorrections) ...[
                SignalCorrectionsCard(corrections: corrections),
                const SizedBox(height: AppSpacing.lg),
              ],
              _actions(context, journey),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        );
      },
    );
  }

  Widget _emptyState(BuildContext context) {
    final gap = ArchiveResponsiveLayout.gap(context);
    return Padding(
      padding: ArchiveMobileSpacing.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            ConsumerUiCopy.signalJourneyEmptyTitle,
            style: ArchiveMobileTypography.archiveSurfaceTitle(context),
          ),
          SizedBox(height: gap),
          Text(
            ConsumerUiCopy.signalJourneyEmptyBody,
            style: ArchiveMobileTypography.explanationBody(context),
          ),
          SizedBox(height: gap),
          FilledButton(
            onPressed: () => context.go('/record'),
            child: Text(ConsumerUiCopy.signalDetailRecordMoment),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, SignalJourney journey) {
    final gap = ArchiveResponsiveLayout.gap(context);
    return Container(
      width: double.infinity,
      padding: ArchiveResponsiveLayout.cardInsets(context),
      decoration: VoiceMemoryCards.standard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            journey.signalTitle,
            style: ArchiveMobileTypography.listTitle(context),
          ),
          SizedBox(height: gap),
          Text(
            _engine.statusLabel(journey.status),
            style: ArchiveMobileTypography.cardLabel(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            _engine.progressLabel(journey),
            style: ArchiveMobileTypography.explanationBody(context),
          ),
        ],
      ),
    );
  }

  Widget _section(BuildContext context, String label, String body) {
    if (body.trim().isEmpty) return const SizedBox.shrink();
    final gap = ArchiveResponsiveLayout.gap(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Container(
        width: double.infinity,
        padding: ArchiveResponsiveLayout.cardInsets(context),
        decoration: VoiceMemoryCards.standard(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: ArchiveMobileTypography.cardLabel(context)),
            SizedBox(height: gap),
            Text(body, style: ArchiveMobileTypography.explanationBody(context)),
          ],
        ),
      ),
    );
  }

  Widget _actions(BuildContext context, SignalJourney journey) {
    final gap = ArchiveResponsiveLayout.gap(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          onPressed: _busy
              ? null
              : () => SignalJourneyNavigation.recordNextEvidence(
                  context,
                  prompt: journey.nextPrompt,
                ),
          child: Text(ConsumerUiCopy.signalJourneyRecordEvidence),
        ),
        SizedBox(height: gap),
        OutlinedButton(
          onPressed: _busy ? null : _markNotMe,
          child: Text(ConsumerUiCopy.signalDetailMarkNotMe),
        ),
        const SizedBox(height: AppSpacing.xs),
        OutlinedButton(
          onPressed: _busy ? null : _archive,
          child: Text(ConsumerUiCopy.signalJourneyArchiveSignal),
        ),
        const SizedBox(height: AppSpacing.xs),
        OutlinedButton(
          onPressed: () => SignalArchiveNavigation.openEvidenceTrail(context),
          child: Text(ConsumerUiCopy.signalDetailViewEvidenceTrail),
        ),
      ],
    );
  }
}
