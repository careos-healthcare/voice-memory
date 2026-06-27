import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/archive_proof/visible_archive_proof_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Zero-entry Patterns tab — one clear preview of what the mind map will show.
class PatternsEmptyArchivePreviewCard extends StatelessWidget {
  const PatternsEmptyArchivePreviewCard({super.key});

  Future<void> _typeInstead(BuildContext context) async {
    await context.push('/quick-capture');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('patterns_empty_archive_preview_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F9F4),
        borderRadius: BorderRadius.circular(VoiceMemoryCards.radius),
        border: Border.all(
          color: AppColors.accentPrimary.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: VoiceMemoryCards.standard().boxShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            VisibleArchiveProofCopy.patternsMindMapEmptyTitle,
            key: const Key('patterns_mind_map_empty_title'),
            style: ArchiveMobileTypography.responsivePageTitle(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            VisibleArchiveProofCopy.patternsMindMapEmptyBody,
            key: const Key('patterns_mind_map_empty_body'),
            style: ArchiveMobileTypography.explanationBody(context),
          ),
          const SizedBox(height: AppSpacing.md),
          _PreviewRow(
            label: VisibleArchiveProofCopy.patternsMindMapPreviewPatternsLabel,
            value: VisibleArchiveProofCopy.patternsMindMapPreviewPatternsValue,
          ),
          const SizedBox(height: AppSpacing.sm),
          _PreviewRow(
            label: VisibleArchiveProofCopy.patternsMindMapPreviewChangesLabel,
            value: VisibleArchiveProofCopy.patternsMindMapPreviewChangesValue,
          ),
          const SizedBox(height: AppSpacing.sm),
          _PreviewRow(
            label: VisibleArchiveProofCopy.patternsMindMapPreviewWatchLabel,
            value: VisibleArchiveProofCopy.patternsMindMapPreviewWatchValue,
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 48,
            width: double.infinity,
            child: FilledButton(
              key: const Key('patterns_mind_map_empty_primary_cta'),
              onPressed: () => context.go('/record'),
              child: Text(VisibleArchiveProofCopy.patternsMindMapEmptyPrimaryCta),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 48,
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const Key('patterns_mind_map_empty_type_instead_cta'),
              onPressed: () => unawaited(_typeInstead(context)),
              icon: const Icon(Icons.keyboard_outlined),
              label: Text(VisibleArchiveProofCopy.typeInsteadCta),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: ArchiveMobileTypography.cardLabel(context),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: ArchiveMobileTypography.body(context),
        ),
      ],
    );
  }
}
