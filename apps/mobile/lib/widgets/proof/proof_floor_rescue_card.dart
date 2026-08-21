import 'dart:async';

import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/beta_proof_feedback/beta_proof_feedback_copy.dart';
import 'package:archiveme_mobile/features/beta_proof_feedback/beta_proof_feedback_model.dart';
import 'package:archiveme_mobile/features/beta_proof_feedback/beta_proof_feedback_store.dart';
import 'package:archiveme_mobile/features/proof_floor_rescue/proof_floor_rescue_analytics.dart';
import 'package:archiveme_mobile/features/proof_floor_rescue/proof_floor_rescue_copy.dart';
import 'package:archiveme_mobile/features/proof_floor_rescue/proof_floor_rescue_model.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';

class ProofFloorRescueCard extends StatefulWidget {
  const ProofFloorRescueCard({
    required this.result, super.key,
    this.onPrimaryCta,
    this.onSecondaryCta,
    this.onChanged,
    this.onNotRelevantAnswered,
    this.store,
    this.skipPrefsLoad = false,
    this.initialAnswered = false,
    this.initialAnswerType,
  });

  const ProofFloorRescueCard.test({
    required this.result, super.key,
    this.onPrimaryCta,
    this.onSecondaryCta,
    this.onChanged,
    this.onNotRelevantAnswered,
    this.store,
    bool answered = false,
    BetaProofFeedbackType? answerType,
  }) : skipPrefsLoad = true,
       initialAnswered = answered,
       initialAnswerType = answerType;

  final ProofFloorRescueResult result;
  final VoidCallback? onPrimaryCta;
  final VoidCallback? onSecondaryCta;
  final VoidCallback? onChanged;
  final Future<void> Function()? onNotRelevantAnswered;
  final BetaProofFeedbackStore? store;
  final bool skipPrefsLoad;
  final bool initialAnswered;
  final BetaProofFeedbackType? initialAnswerType;

  @override
  State<ProofFloorRescueCard> createState() => _ProofFloorRescueCardState();
}

class _ProofFloorRescueCardState extends State<ProofFloorRescueCard> {
  var _trackedSeen = false;
  var _feedbackAnswered = false;

  @override
  void initState() {
    super.initState();
    if (widget.skipPrefsLoad) {
      _feedbackAnswered = widget.initialAnswered;
      return;
    }
    if (widget.result.showFeedbackOptions) {
      unawaited(_loadFeedbackState());
    }
  }

  Future<void> _loadFeedbackState() async {
    await BetaProofFeedbackStore.ensureLoaded();
    if (!mounted) return;
    setState(() {
      _feedbackAnswered = BetaProofFeedbackStore.isAnsweredToday(
        widget.result.surface,
      );
    });
  }

  void _trackSeenOnce() {
    if (_trackedSeen || !widget.result.shouldShow) return;
    if (widget.result.showFeedbackOptions && _feedbackAnswered) return;
    _trackedSeen = true;
    ProofFloorRescueAnalytics.seen(result: widget.result);
  }

  Future<void> _selectFeedback(BetaProofFeedbackType feedbackType) async {
    final store = widget.store ?? BetaProofFeedbackStore.instance();
    await store.saveAnswer(
      surface: widget.result.surface,
      feedbackType: feedbackType,
      entryCount: widget.result.entryCount,
    );
    ProofFloorRescueAnalytics.feedbackAnswered(
      result: widget.result,
      answerType: feedbackType,
    );
    if (feedbackType == BetaProofFeedbackType.notRelevant) {
      await widget.onNotRelevantAnswered?.call();
    }
    if (!mounted) return;
    setState(() => _feedbackAnswered = true);
    widget.onChanged?.call();
  }

  void _onPrimaryPressed() {
    ProofFloorRescueAnalytics.ctaTapped(
      result: widget.result,
      ctaType: switch (widget.result.state) {
        ProofFloorRescueState.waitForClearerEvidence =>
          ProofFloorRescueCtaType.saveIfReturns,
        ProofFloorRescueState.sharpenNextReturn =>
          ProofFloorRescueCtaType.saveNextReturn,
        ProofFloorRescueState.suppressThread =>
          ProofFloorRescueCtaType.continueThread,
        ProofFloorRescueState.needsSpecificFeedback =>
          ProofFloorRescueCtaType.continueThread,
      },
    );
    widget.onPrimaryCta?.call();
  }

  void _onSecondaryPressed() {
    ProofFloorRescueAnalytics.ctaTapped(
      result: widget.result,
      ctaType: switch (widget.result.state) {
        ProofFloorRescueState.waitForClearerEvidence =>
          ProofFloorRescueCtaType.notNow,
        ProofFloorRescueState.sharpenNextReturn => ProofFloorRescueCtaType.skip,
        _ => ProofFloorRescueCtaType.notNow,
      },
    );
    widget.onSecondaryCta?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.result.shouldShow) {
      return const SizedBox.shrink(key: Key('proof_floor_rescue_card_hidden'));
    }
    if (widget.result.showFeedbackOptions && _feedbackAnswered) {
      return const SizedBox.shrink(
        key: Key('proof_floor_rescue_card_answered'),
      );
    }

    _trackSeenOnce();

    final bodyStyle = ArchiveMobileTypography.explanationBody(
      context,
    ).copyWith(color: AppColors.textSecondary, height: 1.45);

    return Container(
      key: Key('proof_floor_rescue_card_${widget.result.state.analyticsValue}'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.result.title,
            key: const Key('proof_floor_rescue_title'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.result.body,
            key: const Key('proof_floor_rescue_body'),
            style: bodyStyle.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (widget.result.showFeedbackOptions) ...[
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              children: [
                for (final type in BetaProofFeedbackType.values)
                  ActionChip(
                    key: Key(
                      'proof_floor_rescue_feedback_${type.storageValue}',
                    ),
                    label: Text(BetaProofFeedbackCopy.labelFor(type)),
                    onPressed: () => unawaited(_selectFeedback(type)),
                  ),
              ],
            ),
          ] else ...[
            if (widget.result.primaryCta.isNotEmpty) ...[
              FilledButton(
                key: const Key('proof_floor_rescue_primary_cta'),
                onPressed: _onPrimaryPressed,
                child: Text(widget.result.primaryCta),
              ),
            ],
            if (widget.result.secondaryCta != null) ...[
              TextButton(
                key: const Key('proof_floor_rescue_secondary_cta'),
                onPressed: _onSecondaryPressed,
                child: Text(widget.result.secondaryCta!),
              ),
            ],
          ],
        ],
      ),
    );
  }
}