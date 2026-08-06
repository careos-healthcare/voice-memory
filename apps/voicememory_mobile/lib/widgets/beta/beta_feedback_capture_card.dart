import 'dart:async';

import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/beta_proof_feedback/beta_proof_feedback_model.dart';
import '../../features/beta_proof_feedback/beta_proof_feedback_store.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';
import '../../features/beta_feedback_capture/beta_feedback_capture_analytics.dart';
import '../../features/beta_feedback_capture/beta_feedback_capture_copy.dart';
import '../../features/beta_feedback_capture/beta_feedback_capture_engine.dart';
import '../../features/beta_feedback_capture/beta_feedback_capture_model.dart';
import '../../features/beta_feedback_capture/beta_feedback_capture_store.dart';

/// Compact beta-only feedback card — metadata answers, optional local text.
class BetaFeedbackCaptureCard extends StatefulWidget {
  const BetaFeedbackCaptureCard({
    super.key,
    required this.result,
    this.onChanged,
    this.compact = false,
    this.proofFeedbackSurface,
    this.store,
  });

  const BetaFeedbackCaptureCard.test({
    super.key,
    required this.result,
    this.onChanged,
    this.compact = false,
    this.proofFeedbackSurface,
    this.store,
  });

  final BetaFeedbackCaptureResult result;
  final VoidCallback? onChanged;
  final bool compact;
  final BetaProofFeedbackSurface? proofFeedbackSurface;
  final BetaFeedbackCaptureStore? store;

  @override
  State<BetaFeedbackCaptureCard> createState() =>
      _BetaFeedbackCaptureCardState();
}

class _BetaFeedbackCaptureCardState extends State<BetaFeedbackCaptureCard> {
  var _trackedSeen = false;
  var _resolved = false;
  final _followUpController = TextEditingController();

  @override
  void dispose() {
    _followUpController.dispose();
    super.dispose();
  }

  void _trackSeenOnce() {
    if (_trackedSeen || !widget.result.shouldShow || _resolved) return;
    _trackedSeen = true;
    BetaFeedbackCaptureAnalytics.seen(result: widget.result);
  }

  Future<void> _handleAnswer(String answerId) async {
    BetaFeedbackCaptureAnalytics.answered(
      result: widget.result,
      answerId: answerId,
    );
    final freeText = _followUpController.text.trim();
    final store = widget.store ?? BetaFeedbackCaptureStore.instance();
    await store.saveAnswer(
      moment: widget.result.moment,
      answerId: answerId,
      entryCount: widget.result.entryCount,
      source: widget.result.source,
      freeTextLocal: freeText.isEmpty ? null : freeText,
    );
    if (widget.result.moment == BetaFeedbackCaptureMoment.afterTimelineProof &&
        widget.proofFeedbackSurface != null) {
      final proofType = BetaFeedbackCaptureEngine.proofFeedbackTypeForAnswer(
        answerId,
      );
      if (proofType != null) {
        await BetaProofFeedbackStore.instance().saveAnswer(
          surface: widget.proofFeedbackSurface!,
          feedbackType: proofType,
          entryCount: widget.result.entryCount,
        );
      }
    }
    if (!mounted) return;
    setState(() => _resolved = true);
    widget.onChanged?.call();
  }

  Future<void> _handleDismiss() async {
    BetaFeedbackCaptureAnalytics.dismissed(result: widget.result);
    if (widget.store != null) {
      await widget.store!.dismissMomentForDay(widget.result.moment);
    } else {
      await BetaFeedbackCaptureStore.dismissForDay(widget.result.moment);
    }
    if (!mounted) return;
    setState(() => _resolved = true);
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_resolved || !widget.result.shouldShow) {
      return const SizedBox.shrink(
        key: Key('beta_feedback_capture_card_hidden'),
      );
    }

    _trackSeenOnce();

    final bodyStyle = ArchiveMobileTypography.explanationBody(
      context,
    ).copyWith(color: AppColors.textSecondary, height: 1.45);

    return Container(
      key: const Key('beta_feedback_capture_card'),
      width: double.infinity,
      padding: EdgeInsets.all(widget.compact ? AppSpacing.sm : AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.result.title,
            key: const Key('beta_feedback_capture_title'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          SizedBox(height: widget.compact ? AppSpacing.xs : AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final option in widget.result.options)
                OutlinedButton(
                  key: Key('beta_feedback_capture_option_${option.id}'),
                  onPressed: () => unawaited(_handleAnswer(option.id)),
                  child: Text(option.label),
                ),
            ],
          ),
          if (widget.result.followUpPlaceholder != null) ...[
            SizedBox(height: widget.compact ? AppSpacing.xs : AppSpacing.sm),
            TextField(
              key: const Key('beta_feedback_capture_follow_up'),
              controller: _followUpController,
              decoration: InputDecoration(
                hintText: widget.result.followUpPlaceholder,
                isDense: true,
              ),
              style: bodyStyle,
              maxLines: 2,
            ),
          ],
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: const Key('beta_feedback_capture_dismiss'),
              onPressed: () => unawaited(_handleDismiss()),
              child: Text(BetaFeedbackCaptureCopy.dismissCta),
            ),
          ),
        ],
      ),
    );
  }
}
