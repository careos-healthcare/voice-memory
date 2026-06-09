import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design/archive_mobile_spacing.dart';
import '../design/user_facing_date.dart';
import '../design/archive_mobile_typography.dart';
import '../design/archive_responsive_layout.dart';
import '../features/post_save_insight/selected_signal_model.dart';
import '../features/post_save_insight/signal_feedback_coordinator.dart';
import '../features/post_save_insight/signal_feedback_model.dart';
import '../features/post_save_insight/signal_feedback_store.dart';
import '../features/signal_journey/signal_journey_coordinator.dart';
import '../features/signal_review/signal_review_coordinator.dart';
import '../features/signal_review/signal_review_model.dart';
import '../features/signal_review/signal_review_navigation.dart';
import '../features/signal_archive/signal_archive_coordinator.dart';
import '../features/signal_archive/signal_archive_navigation.dart';
import '../features/signal_archive/signal_archive_snapshot.dart';
import '../product/consumer_ui_copy.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/voicememory_cards.dart';
import '../widgets/signal/signal_corrections_card.dart';
import '../widgets/signal/signal_review_card.dart';

class SignalDetailScreen extends StatefulWidget {
  const SignalDetailScreen({
    super.key,
    this.initialSnapshot,
    this.initialReview,
  });

  /// Test hook — skips async coordinator load when provided.
  @visibleForTesting
  final SignalArchiveSnapshot? initialSnapshot;

  @visibleForTesting
  final SignalReview? initialReview;

  @override
  State<SignalDetailScreen> createState() => _SignalDetailScreenState();
}

class _SignalDetailScreenState extends State<SignalDetailScreen> {
  SignalArchiveSnapshot? _snapshot;
  SignalReview? _review;
  PostSaveSignalAction? _latestFeedback;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialSnapshot != null) {
      _snapshot = widget.initialSnapshot;
      _review = widget.initialReview;
      _loading = false;
      return;
    }
    _load();
  }

  Future<void> _load() async {
    final snapshot = await SignalArchiveCoordinator.load();
    SignalReview? review;
    final journey = await SignalJourneyCoordinator.loadActive();
    if (journey != null && journey.isConfirmed) {
      review = await SignalReviewCoordinator.loadForActiveJourney();
    }
    PostSaveSignalAction? latest;
    final signal = snapshot.selectedSignal;
    if (signal != null) {
      final feedback = await SignalFeedbackStore.instance().loadAll();
      for (final row in feedback.reversed) {
        if (row.signalTitle == signal.title ||
            row.categoryId == signal.categoryId) {
          latest = row.action;
          break;
        }
      }
    }
    if (!mounted) return;
    setState(() {
      _snapshot = snapshot;
      _review = review;
      _latestFeedback = latest;
      _loading = false;
    });
  }

  Future<void> _markNotMe(SelectedSignalRecord signal) async {
    if (_busy) return;
    setState(() => _busy = true);
    await SignalFeedbackCoordinator.track(
      action: PostSaveSignalAction.rejected,
      signalId: signal.id,
      signalTitle: signal.title,
      entryId: signal.entryId,
      categoryId: signal.categoryId,
    );
    await SignalJourneyCoordinator.onSignalRejected(
      signalId: signal.id,
      readId: signal.readId,
      categoryId: signal.categoryId,
      signalTitle: signal.title,
      entryId: signal.entryId,
    );
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
    final snapshot = _snapshot!;
    final signal = snapshot.selectedSignal;
    if (signal == null) return _emptyState(context);

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: ArchiveMobileSpacing.pagePadding,
        children: [
          Text(
            ConsumerUiCopy.signalDetailPageTitle,
            style: ArchiveMobileTypography.archiveSurfaceTitle(context),
          ),
          const SizedBox(height: AppSpacing.lg),
          _SignalHeader(signal: signal),
          const SizedBox(height: AppSpacing.lg),
          _section(
            context,
            ConsumerUiCopy.signalDetailThinksMayBe,
            signal.mightMean?.trim().isNotEmpty == true
                ? signal.mightMean!
                : signal.whySuggested ?? signal.title,
          ),
          _section(
            context,
            ConsumerUiCopy.signalDetailEvidenceSoFar,
            signal.evidenceUsed?.trim().isNotEmpty == true
                ? signal.evidenceUsed!
                : (signal.evidenceChips.isNotEmpty
                    ? signal.evidenceChips.join(' · ')
                    : ConsumerUiCopy.postSaveInsightEvidenceFromMoment),
          ),
          _section(
            context,
            ConsumerUiCopy.signalDetailWouldConfirm,
            signal.wouldConfirm ?? snapshot.evidenceTrail.clarityPrompt,
          ),
          _section(
            context,
            ConsumerUiCopy.signalDetailWouldProveWrong,
            signal.wouldContradict ?? ConsumerUiCopy.patternHypothesisProveWrong,
          ),
          _section(
            context,
            ConsumerUiCopy.signalDetailRecordNext,
            signal.nextPrompt,
          ),
          const SizedBox(height: AppSpacing.md),
          _FeedbackState(action: _latestFeedback),
          const SizedBox(height: AppSpacing.lg),
          SignalCorrectionsCard(corrections: snapshot.corrections),
          if (_review != null && _review!.isShowable) ...[
            const SizedBox(height: AppSpacing.lg),
            SignalReviewCard(
              review: _review!,
              onConfirm: () async {
                await SignalReviewCoordinator.confirm(reviewId: _review!.id);
                if (!mounted) return;
                await _load();
              },
              onCorrect: () => SignalReviewNavigation.openFullReview(context),
              onKeepWatching: () async {
                await SignalReviewCoordinator.keepWatching(reviewId: _review!.id);
                if (!mounted) return;
                await _load();
              },
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          _actions(context, signal),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
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
            ConsumerUiCopy.signalDetailEmptyTitle,
            style: ArchiveMobileTypography.archiveSurfaceTitle(context),
          ),
          SizedBox(height: gap),
          Text(
            ConsumerUiCopy.signalDetailEmptyBody,
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

  Widget _actions(BuildContext context, SelectedSignalRecord signal) {
    final gap = ArchiveResponsiveLayout.gap(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          onPressed: _busy
              ? null
              : () => SignalArchiveNavigation.recordNextEvidence(
                    context,
                    prompt: signal.nextPrompt,
                  ),
          child: Text(ConsumerUiCopy.postSaveInsightRecordNextEvidence),
        ),
        SizedBox(height: gap),
        OutlinedButton(
          onPressed: _busy
              ? null
              : () => context.go('/record'),
          child: Text(ConsumerUiCopy.postSaveInsightAnotherAngle),
        ),
        const SizedBox(height: AppSpacing.xs),
        OutlinedButton(
          onPressed: () => SignalArchiveNavigation.openEvidenceTrail(context),
          child: Text(ConsumerUiCopy.signalDetailViewEvidenceTrail),
        ),
        const SizedBox(height: AppSpacing.xs),
        OutlinedButton(
          onPressed: _busy ? null : () => _markNotMe(signal),
          child: Text(ConsumerUiCopy.signalDetailMarkNotMe),
        ),
      ],
    );
  }
}

class _SignalHeader extends StatelessWidget {
  const _SignalHeader({required this.signal});

  final SelectedSignalRecord signal;

  @override
  Widget build(BuildContext context) {
    final gap = ArchiveResponsiveLayout.gap(context);
    return Container(
      width: double.infinity,
      padding: ArchiveResponsiveLayout.cardInsets(context),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFFFFBF5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(signal.title, style: ArchiveMobileTypography.listTitle(context)),
          if (signal.strengthLabel.isNotEmpty) ...[
            SizedBox(height: gap),
            Text(
              signal.strengthLabel,
              style: ArchiveMobileTypography.cardLabel(context),
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          Text(
            formatUserFacingDate(signal.savedAt),
            style: ArchiveMobileTypography.responsiveBody(context),
          ),
        ],
      ),
    );
  }
}

class _FeedbackState extends StatelessWidget {
  const _FeedbackState({required this.action});

  final PostSaveSignalAction? action;

  @override
  Widget build(BuildContext context) {
    final gap = ArchiveResponsiveLayout.gap(context);
    final labels = <String>[
      ConsumerUiCopy.signalDetailFeedbackTrue,
      ConsumerUiCopy.signalDetailFeedbackNotMe,
      ConsumerUiCopy.signalDetailFeedbackAnother,
    ];
    String? active;
    switch (action) {
      case PostSaveSignalAction.accepted:
      case PostSaveSignalAction.abChoiceA:
      case PostSaveSignalAction.abChoiceB:
        active = ConsumerUiCopy.signalDetailFeedbackTrue;
      case PostSaveSignalAction.rejected:
      case PostSaveSignalAction.abChoiceNeither:
        active = ConsumerUiCopy.signalDetailFeedbackNotMe;
      case PostSaveSignalAction.anotherAngleShown:
        active = ConsumerUiCopy.signalDetailFeedbackAnother;
      default:
        active = null;
    }

    return Container(
      width: double.infinity,
      padding: ArchiveResponsiveLayout.cardInsets(context),
      decoration: VoiceMemoryCards.standard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ConsumerUiCopy.signalDetailFeedbackLabel,
            style: ArchiveMobileTypography.cardLabel(context),
          ),
          SizedBox(height: gap),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: labels.map((label) {
              final selected = label == active;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.accentPrimary.withValues(alpha: 0.12)
                      : AppColors.backgroundSecondary,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: selected
                        ? AppColors.accentPrimary
                        : AppColors.backgroundSecondary,
                  ),
                ),
                child: Text(
                  label,
                  style: ArchiveMobileTypography.explanationBody(context).copyWith(
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
