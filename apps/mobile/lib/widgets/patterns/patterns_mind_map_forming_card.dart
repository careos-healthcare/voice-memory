import 'dart:async';

import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/design/archive_responsive_layout.dart';
import 'package:archiveme_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/theme/voicememory_cards.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Patterns tab fallback when moments exist but no belief card is ready yet.
class PatternsMindMapFormingCard extends StatelessWidget {
  const PatternsMindMapFormingCard({super.key});

  Future<void> _typeInstead(BuildContext context) async {
    await context.push('/quick-capture');
  }

  @override
  Widget build(BuildContext context) {
    final card = Container(
      key: const Key('patterns_mind_map_forming_card'),
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
            VisibleArchiveProofCopy.patternsMindMapFormingTitle,
            key: const Key('patterns_mind_map_forming_title'),
            style: ArchiveMobileTypography.responsivePageTitle(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            VisibleArchiveProofCopy.patternsMindMapFormingBody,
            key: const Key('patterns_mind_map_forming_body'),
            style: ArchiveMobileTypography.explanationBody(context),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 48,
            width: double.infinity,
            child: FilledButton(
              key: const Key('patterns_mind_map_forming_primary_cta'),
              onPressed: () => context.go('/record'),
              child: const Text(
                VisibleArchiveProofCopy.patternsMindMapFormingPrimaryCta,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 48,
            width: double.infinity,
            child: OutlinedButton.icon(
              key: const Key('patterns_mind_map_forming_type_instead_cta'),
              onPressed: () => unawaited(_typeInstead(context)),
              icon: const Icon(Icons.keyboard_outlined),
              label: const Text(VisibleArchiveProofCopy.typeInsteadCta),
            ),
          ),
        ],
      ),
    );

    return ArchiveResponsiveLayout.page(
      context: context,
      maxWidth: ArchiveResponsiveLayout.cardMaxWidth,
      child: card,
    );
  }
}