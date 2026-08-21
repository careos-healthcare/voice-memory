import 'package:archiveme_mobile/design/user_facing_date.dart';
import 'package:archiveme_mobile/features/archive_discovery_share/archive_discovery_share_moments.dart';
import 'package:archiveme_mobile/features/archive_v1/archive_v1_copy.dart';
import 'package:archiveme_mobile/features/archive_v1/archive_v1_models.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:archiveme_mobile/theme/voicememory_colors.dart';
import 'package:archiveme_mobile/theme/voicememory_typography.dart';
import 'package:archiveme_mobile/widgets/archive_discovery_share/share_discovery_button.dart';
import 'package:flutter/material.dart';

/// Then → Now belief comparison.
class ArchiveBeliefEvolutionThenNow extends StatelessWidget {
  const ArchiveBeliefEvolutionThenNow({required this.thenNow, super.key});

  final ArchiveV1ThenNow thenNow;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          ArchiveV1Copy.evolutionSectionTitle,
          style: VoiceMemoryTypography.sectionLabelStyle(
            
          ),
        ),
        const SizedBox(height: 12),
        _BeliefPhase(
          label: ArchiveV1Copy.thenLabel,
          belief: thenNow.thenBelief,
        ),
        const SizedBox(height: 12),
        Icon(
          Icons.arrow_downward,
          color: VoiceMemoryColors.primaryIndigo.withValues(alpha: 0.7),
          size: 20,
        ),
        const SizedBox(height: 12),
        _BeliefPhase(label: ArchiveV1Copy.nowLabel, belief: thenNow.nowBelief),
        const SizedBox(height: 14),
        if (!thenNow.hasDistinctEvolution)
          const Text(
            'Your archive is still forming a clear before-and-after story. '
            'Keep recording — a sharper shift will appear when beliefs diverge.',
            style: TextStyle(color: AppTheme.muted, fontSize: 13, height: 1.45),
          ),
        if (thenNow.firstEvidenceAt != null) ...[
          const SizedBox(height: 8),
          Text(
            'First evidence: ${formatUserFacingDate(thenNow.firstEvidenceAt!)}',
            style: const TextStyle(color: AppTheme.muted, fontSize: 12),
          ),
        ],
        if (thenNow.latestEvidenceAt != null)
          Text(
            'Latest evidence: ${formatUserFacingDate(thenNow.latestEvidenceAt!)}',
            style: const TextStyle(color: AppTheme.muted, fontSize: 12),
          ),
        Text(
          'Supporting recordings: ${thenNow.supportingEvidenceCount}',
          style: const TextStyle(color: AppTheme.muted, fontSize: 12),
        ),
        if (ArchiveDiscoveryShareMoments.fromThenNow(thenNow)
            case final shareCard?) ...[
          const SizedBox(height: 8),
          ShareDiscoveryButton(
            card: shareCard,
            surface: 'archive_theory_change',
          ),
        ],
      ],
    );
  }
}

class _BeliefPhase extends StatelessWidget {
  const _BeliefPhase({required this.label, required this.belief});

  final String label;
  final String belief;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VoiceMemoryColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: VoiceMemoryColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              letterSpacing: 0.9,
              fontWeight: FontWeight.w700,
              color: AppTheme.muted,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '"$belief"',
            style: const TextStyle(
              fontSize: 15,
              height: 1.45,
              fontWeight: FontWeight.w500,
              color: AppTheme.foreground,
            ),
          ),
        ],
      ),
    );
  }
}