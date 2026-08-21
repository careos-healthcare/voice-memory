import 'package:archiveme_mobile/billing/archive_paywall_copy.dart';
import 'package:archiveme_mobile/billing/archive_paywall_stats.dart';
import 'package:archiveme_mobile/features/archive_v1/archive_v1_models.dart';
import 'package:archiveme_mobile/theme/voicememory_colors.dart';
import 'package:archiveme_mobile/theme/voicememory_typography.dart';
import 'package:archiveme_mobile/widgets/archive_paywall/archive_intelligence_proof_section.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Teaser before full archive paywall — theory visible, synthesis locked.
class ArchiveIntelligenceUpgradeCard extends StatelessWidget {
  const ArchiveIntelligenceUpgradeCard({
    required this.view, super.key,
    this.compact = false,
  });

  final ArchiveV1View view;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final stats = ArchivePaywallStats.fromEntries(
      entries: view.eligibleEntries,
      archiveV1: view,
    );

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: BoxDecoration(
        color: VoiceMemoryColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: VoiceMemoryColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ArchivePaywallVariantConfig.headline(
              ArchivePaywallVariantConfig.active,
            ),
            style: compact
                ? const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  )
                : VoiceMemoryTypography.sectionTitleStyle(),
          ),
          SizedBox(height: compact ? 6 : 8),
          ArchiveIntelligenceProofSection(
            stats: stats,
            surface: 'archive_intelligence_locked',
            compact: compact,
          ),
          if (stats.hasTheoryPreview) ...[
            const SizedBox(height: 10),
            Text(
              '"${stats.theoryStatement}"',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                height: 1.4,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
          SizedBox(height: compact ? 10 : 14),
          FilledButton(
            onPressed: () => context.push('/subscription'),
            child: const Text(ArchivePaywallCopy.primaryCta),
          ),
        ],
      ),
    );
  }
}