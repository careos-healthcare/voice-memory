import 'package:archiveme_mobile/features/recording/evidence_indexing/evidence_indexing_controller.dart';
import 'package:archiveme_mobile/features/recording/evidence_indexing/evidence_indexing_copy.dart';
import 'package:archiveme_mobile/features/recording/evidence_indexing/evidence_indexing_models.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:archiveme_mobile/theme/voicememory_colors.dart';
import 'package:archiveme_mobile/theme/voicememory_typography.dart';
import 'package:flutter/material.dart';

/// Post-save transition showing live fact-ledger indexing.
class EvidenceIndexingView extends StatefulWidget {
  const EvidenceIndexingView({
    required this.controller, super.key,
    this.onInspectEvidenceTrail,
    this.onReturnToArchive,
  });

  final EvidenceIndexingController controller;
  final VoidCallback? onInspectEvidenceTrail;
  final VoidCallback? onReturnToArchive;

  @override
  State<EvidenceIndexingView> createState() => _EvidenceIndexingViewState();
}

class _EvidenceIndexingViewState extends State<EvidenceIndexingView> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant EvidenceIndexingView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      widget.controller.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;

    return Semantics(
      label: EvidenceIndexingCopy.title,
      child: Container(
        key: const Key('evidence_indexing_view'),
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: VoiceMemoryCards.standard(
          background: AppColors.backgroundSecondary,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              EvidenceIndexingCopy.title,
              style: VoiceMemoryTypography.cardTitleStyle(),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              _bodyForPhase(controller.phase),
              style: VoiceMemoryTypography.secondaryStyle().copyWith(
                height: 1.45,
              ),
            ),
            if (controller.stageLabel?.trim().isNotEmpty == true) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                controller.stageLabel!,
                style: VoiceMemoryTypography.metadataStyle(
                  color: VoiceMemoryColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: AppSpacing.sm),
            Text(
              EvidenceIndexingCopy.liveFeedLabel,
              style: VoiceMemoryTypography.sectionLabelStyle(
                
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            _LiveFeed(chips: controller.visibleChips, phase: controller.phase),
            if (controller.phase == EvidenceIndexingPhase.complete &&
                controller.committedAnchorCount > 0) ...[
              const SizedBox(height: AppSpacing.sm),
              _CompletionBanner(count: controller.committedAnchorCount),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('evidence_indexing_inspect_trail'),
                      onPressed: widget.onInspectEvidenceTrail,
                      child: const Text(EvidenceIndexingCopy.inspectEvidenceTrail),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: FilledButton(
                      key: const Key('evidence_indexing_return_archive'),
                      onPressed: widget.onReturnToArchive,
                      child: const Text(EvidenceIndexingCopy.returnToArchive),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _bodyForPhase(EvidenceIndexingPhase phase) {
    return switch (phase) {
      EvidenceIndexingPhase.listening => EvidenceIndexingCopy.listeningBody,
      EvidenceIndexingPhase.extracting ||
      EvidenceIndexingPhase.committing =>
        EvidenceIndexingCopy.extractingBody,
      EvidenceIndexingPhase.complete => EvidenceIndexingCopy.extractingBody,
      EvidenceIndexingPhase.skipped => EvidenceIndexingCopy.emptyBody,
    };
  }
}

class _LiveFeed extends StatelessWidget {
  const _LiveFeed({required this.chips, required this.phase});

  final List<EvidenceIndexingChip> chips;
  final EvidenceIndexingPhase phase;

  @override
  Widget build(BuildContext context) {
    if (chips.isEmpty) {
      return Container(
        key: const Key('evidence_indexing_live_feed_empty'),
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: VoiceMemoryColors.surfaceSecondary,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: VoiceMemoryColors.border),
        ),
        child: phase == EvidenceIndexingPhase.listening
            ? const Row(
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 10),
                  Expanded(child: Text(EvidenceIndexingCopy.listeningBody)),
                ],
              )
            : Text(
                EvidenceIndexingCopy.emptyBody,
                style: VoiceMemoryTypography.secondaryStyle(),
              ),
      );
    }

    return Container(
      key: const Key('evidence_indexing_live_feed'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: VoiceMemoryColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: VoiceMemoryColors.border),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var i = 0; i < chips.length; i++)
            _AnimatedEvidenceChip(
              key: Key('evidence_indexing_chip_$i'),
              chip: chips[i],
              index: i,
            ),
        ],
      ),
    );
  }
}

class _AnimatedEvidenceChip extends StatelessWidget {
  const _AnimatedEvidenceChip({
    required this.chip, required this.index, super.key,
  });

  final EvidenceIndexingChip chip;
  final int index;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 280 + (index * 60)),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Opacity(
          opacity: value.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: 0.92 + (0.08 * value),
            child: child,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: VoiceMemoryColors.primaryIndigo.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: VoiceMemoryColors.primaryIndigo.withValues(alpha: 0.28),
          ),
        ),
        child: Text(
          chip.displayText,
          style: VoiceMemoryTypography.bodyStyle(
            color: VoiceMemoryColors.primaryIndigo,
          ).copyWith(fontSize: 13, fontWeight: FontWeight.w600, height: 1.3),
        ),
      ),
    );
  }
}

class _CompletionBanner extends StatelessWidget {
  const _CompletionBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('evidence_indexing_completion_banner'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: VoiceMemoryColors.success.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: VoiceMemoryColors.success.withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        EvidenceIndexingCopy.completionBanner(count),
        style: VoiceMemoryTypography.bodyStyle().copyWith(
          fontWeight: FontWeight.w700,
          height: 1.35,
        ),
      ),
    );
  }
}