import 'dart:async';

import 'package:flutter/material.dart';

import '../../features/beta/archive_beta_mission_gate.dart';
import '../../design/archive_mobile_typography.dart';
import '../../features/beta_proof_feedback/beta_proof_feedback_analytics.dart';
import '../../features/beta_proof_feedback/beta_proof_feedback_copy.dart';
import '../../features/proof_relevance_repair/proof_relevance_repair_copy.dart';
import '../../features/beta_proof_feedback/beta_proof_feedback_engine.dart';
import '../../features/beta_proof_feedback/beta_proof_feedback_model.dart';
import '../../features/beta_proof_feedback/beta_proof_feedback_store.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Compact beta-only feedback row for high-value proof surfaces.
class BetaProofFeedbackRow extends StatefulWidget {
  const BetaProofFeedbackRow({
    super.key,
    required this.surface,
    required this.source,
    required this.entryCount,
    required this.hasConfirmedRepeat,
    required this.parentVisible,
    required this.isRecording,
    required this.isPostSaveDegraded,
    required this.whatChangedQuestionActive,
    required this.patternReviewInboxHasActiveItems,
    this.onChanged,
    this.onNotRelevantAnswered,
    this.store,
    this.skipPrefsLoad = false,
    this.initialAnswered = false,
  });

  const BetaProofFeedbackRow.test({
    super.key,
    required this.surface,
    required this.source,
    required this.entryCount,
    required this.hasConfirmedRepeat,
    required this.parentVisible,
    this.isRecording = false,
    this.isPostSaveDegraded = false,
    this.whatChangedQuestionActive = false,
    this.patternReviewInboxHasActiveItems = false,
    this.onChanged,
    this.onNotRelevantAnswered,
    this.store,
    bool answered = false,
  }) : skipPrefsLoad = true,
       initialAnswered = answered;

  final BetaProofFeedbackSurface surface;
  final String source;
  final int entryCount;
  final bool hasConfirmedRepeat;
  final bool parentVisible;
  final bool isRecording;
  final bool isPostSaveDegraded;
  final bool whatChangedQuestionActive;
  final bool patternReviewInboxHasActiveItems;
  final VoidCallback? onChanged;
  final Future<void> Function()? onNotRelevantAnswered;
  final BetaProofFeedbackStore? store;
  final bool skipPrefsLoad;
  final bool initialAnswered;

  @override
  State<BetaProofFeedbackRow> createState() => _BetaProofFeedbackRowState();
}

class _BetaProofFeedbackRowState extends State<BetaProofFeedbackRow> {
  var _answered = false;
  BetaProofFeedbackType? _selectedType;
  var _seenLogged = false;

  @override
  void initState() {
    super.initState();
    if (widget.skipPrefsLoad) {
      _answered = widget.initialAnswered;
      return;
    }
    unawaited(_load());
  }

  Future<void> _load() async {
    await BetaProofFeedbackStore.ensureLoaded();
    if (!mounted) return;
    setState(() {});
  }

  bool get _visible => BetaProofFeedbackEngine.shouldShow(
    surface: widget.surface,
    parentVisible: widget.parentVisible,
    entryCount: widget.entryCount,
    hasConfirmedRepeat: widget.hasConfirmedRepeat,
    isRecording: widget.isRecording,
    isPostSaveDegraded: widget.isPostSaveDegraded,
    whatChangedQuestionActive: widget.whatChangedQuestionActive,
    patternReviewInboxHasActiveItems: widget.patternReviewInboxHasActiveItems,
  );

  void _logSeenIfNeeded() {
    if (_seenLogged || _answered || !_visible) return;
    _seenLogged = true;
    BetaProofFeedbackAnalytics.seen(
      source: widget.source,
      surface: widget.surface,
      entryCount: widget.entryCount,
      hasConfirmedRepeat: widget.hasConfirmedRepeat,
    );
  }

  Future<void> _selectAnswer(BetaProofFeedbackType feedbackType) async {
    final store = widget.store ?? BetaProofFeedbackStore.instance();
    await store.saveAnswer(
      surface: widget.surface,
      feedbackType: feedbackType,
      entryCount: widget.entryCount,
    );
    BetaProofFeedbackAnalytics.answered(
      source: widget.source,
      surface: widget.surface,
      feedbackType: feedbackType,
      entryCount: widget.entryCount,
      hasConfirmedRepeat: widget.hasConfirmedRepeat,
    );
    if (feedbackType == BetaProofFeedbackType.notRelevant) {
      await widget.onNotRelevantAnswered?.call();
    }
    if (!mounted) return;
    setState(() {
      _answered = true;
      _selectedType = feedbackType;
    });
    widget.onChanged?.call();
  }

  Key _optionKey(BetaProofFeedbackType type) =>
      Key('beta_proof_feedback_${type.storageValue}');

  @override
  Widget build(BuildContext context) {
    if (!ArchiveBetaMissionGate.isEnabled || !widget.parentVisible) {
      return SizedBox.shrink(
        key: Key('beta_proof_feedback_hidden_${widget.surface.name}'),
      );
    }

    final helperStyle = ArchiveMobileTypography.responsiveHelper(
      context,
    ).copyWith(color: AppColors.textSecondary, height: 1.4);

    if (_answered) {
      return Padding(
        key: Key('beta_proof_feedback_thanks_${widget.surface.name}'),
        padding: const EdgeInsets.only(top: AppSpacing.xs),
        child: Text(
          BetaProofFeedbackCopy.responseFor(
            _selectedType ?? BetaProofFeedbackType.useful,
          ),
          key: const Key('beta_proof_feedback_thanks_message'),
          style: helperStyle.copyWith(color: AppColors.textPrimary),
        ),
      );
    }

    if (!_visible) {
      return SizedBox.shrink(
        key: Key('beta_proof_feedback_hidden_${widget.surface.name}'),
      );
    }

    _logSeenIfNeeded();

    return Padding(
      key: Key('beta_proof_feedback_row_${widget.surface.name}'),
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            BetaProofFeedbackCopy.question,
            key: const Key('beta_proof_feedback_question'),
            style: ArchiveMobileTypography.cardLabel(context).copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final type
                  in ProofRelevanceRepairCopy.relevanceFeedbackTypes)
                TextButton(
                  key: _optionKey(type),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                  onPressed: () => unawaited(_selectAnswer(type)),
                  child: Text(BetaProofFeedbackCopy.labelFor(type)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
