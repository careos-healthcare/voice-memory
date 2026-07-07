import 'dart:async';

import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/correction_memory/correction_memory_engine.dart';
import '../../features/current_relevance/current_relevance_model.dart';
import '../../features/proof_specificity_boost/proof_specificity_boost_analytics.dart';
import '../../features/proof_specificity_boost/proof_specificity_boost_copy.dart';
import '../../features/proof_specificity_boost/proof_specificity_boost_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Clarifies safe evidence anchors when proof feels too vague — no raw text.
class ProofSpecificityBoostCard extends StatefulWidget {
  const ProofSpecificityBoostCard({
    super.key,
    required this.result,
    required this.surface,
    required this.source,
    required this.hasConfirmedRepeat,
    required this.proofKey,
    this.onChanged,
    this.store,
    this.skipPrefsLoad = false,
    this.initialAnswer,
  });

  const ProofSpecificityBoostCard.test({
    super.key,
    required this.result,
    required this.surface,
    required this.source,
    required this.hasConfirmedRepeat,
    required this.proofKey,
    this.onChanged,
    this.store,
    this.initialAnswer,
  })  : skipPrefsLoad = true;

  final ProofSpecificityBoostResult result;
  final ProofSpecificityBoostSurface surface;
  final String source;
  final bool hasConfirmedRepeat;
  final String proofKey;
  final VoidCallback? onChanged;
  final ProofSpecificityBoostStore? store;
  final bool skipPrefsLoad;
  final ProofSpecificityBoostAnswerType? initialAnswer;

  @override
  State<ProofSpecificityBoostCard> createState() =>
      _ProofSpecificityBoostCardState();
}

class _ProofSpecificityBoostCardState extends State<ProofSpecificityBoostCard> {
  ProofSpecificityBoostAnswerType? _selectedAnswer;
  var _trackedSeen = false;

  @override
  void initState() {
    super.initState();
    _selectedAnswer = widget.initialAnswer ??
        (widget.skipPrefsLoad
            ? null
            : ProofSpecificityBoostStore.recordFor(widget.surface).answerType);
    if (!widget.skipPrefsLoad) {
      unawaited(_load());
    }
  }

  Future<void> _load() async {
    await ProofSpecificityBoostStore.ensureLoaded();
    if (!mounted) return;
    setState(() {
      _selectedAnswer ??=
          ProofSpecificityBoostStore.recordFor(widget.surface).answerType;
    });
  }

  void _trackSeenOnce() {
    if (_trackedSeen || _selectedAnswer != null) return;
    _trackedSeen = true;
    ProofSpecificityBoostAnalytics.seen(
      source: widget.source,
      surface: widget.surface,
      result: widget.result,
    );
  }

  Future<void> _selectAnswer(ProofSpecificityBoostAnswerType answerType) async {
    if (_selectedAnswer != null) return;

    final store = widget.store ?? ProofSpecificityBoostStore.instance();
    await store.saveAnswer(
      surface: widget.surface,
      answerType: answerType,
      entryCount: widget.result.entryCount,
    );

    ProofSpecificityBoostAnalytics.answered(
      source: widget.source,
      surface: widget.surface,
      answerType: answerType,
      result: widget.result,
    );

    if (!mounted) return;
    setState(() => _selectedAnswer = answerType);
    widget.onChanged?.call();

    if (answerType == ProofSpecificityBoostAnswerType.notRelevant &&
        widget.proofKey.isNotEmpty) {
      await CorrectionMemoryEngine.saveFromAnswer(
        proofKey: widget.proofKey,
        answer: CurrentRelevanceAnswer.notReally,
        entryCountAtCapture: widget.result.entryCount,
        hasConfirmedRepeat: widget.hasConfirmedRepeat,
        source: widget.source,
      );
    }
  }

  Key _optionKey(ProofSpecificityBoostAnswerType type) =>
      Key('proof_specificity_boost_${type.storageValue}');

  @override
  Widget build(BuildContext context) {
    _trackSeenOnce();

    final bodyStyle = ArchiveMobileTypography.explanationBody(context).copyWith(
      color: AppColors.textSecondary,
      height: 1.45,
    );
    final answered = _selectedAnswer;

    if (answered != null) {
      return Container(
        key: Key('proof_specificity_boost_answered_${widget.surface.name}'),
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration:
            VoiceMemoryCards.standard(background: const Color(0xFFF8FAF8)),
        child: Text(
          ProofSpecificityBoostCopy.followUpFor(answered),
          key: Key('proof_specificity_boost_follow_up_${answered.storageValue}'),
          style: bodyStyle.copyWith(color: AppColors.textPrimary),
        ),
      );
    }

    return Container(
      key: const Key('proof_specificity_boost_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: const Color(0xFFF8FAF8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            ProofSpecificityBoostCopy.title,
            key: const Key('proof_specificity_boost_title'),
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            ProofSpecificityBoostCopy.body,
            key: const Key('proof_specificity_boost_body'),
            style: bodyStyle,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            ProofSpecificityBoostCopy.evidenceHeading,
            key: const Key('proof_specificity_boost_evidence_heading'),
            style: ArchiveMobileTypography.cardLabel(context).copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          if (widget.result.usesFallbackEvidenceLine)
            Text(
              ProofSpecificityBoostCopy.fallbackAnchor,
              key: const Key('proof_specificity_boost_fallback_anchor'),
              style: bodyStyle.copyWith(color: AppColors.textPrimary),
            )
          else
            for (final anchor in widget.result.evidenceAnchors)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  anchor,
                  key: Key('proof_specificity_boost_anchor_${anchor.hashCode}'),
                  style: bodyStyle.copyWith(color: AppColors.textPrimary),
                ),
              ),
          const SizedBox(height: AppSpacing.sm),
          for (final row in ProofSpecificityBoostCopy.specificityRows)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                row,
                key: Key('proof_specificity_boost_row_${row.hashCode}'),
                style: bodyStyle,
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            ProofSpecificityBoostCopy.boundaryLine,
            key: const Key('proof_specificity_boost_boundary_line'),
            style: bodyStyle,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            ProofSpecificityBoostCopy.correctionPrompt,
            key: const Key('proof_specificity_boost_correction_prompt'),
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
              for (final type in ProofSpecificityBoostAnswerType.values)
                TextButton(
                  key: _optionKey(type),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    textStyle: const TextStyle(fontSize: 13),
                  ),
                  onPressed: () => unawaited(_selectAnswer(type)),
                  child: Text(ProofSpecificityBoostCopy.optionLabel(type)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
