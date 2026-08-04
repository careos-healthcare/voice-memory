import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/memory/memory_scope.dart';
import '../../features/memory/memory_scope_policy.dart';
import '../../features/trust/pro_trust_copy.dart';
import '../../services/activation_funnel_analytics.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Pro value clarity — soft bridge after repeat value on record or archive.
/// Never interrupts recording; dismissible once per session.
class ProValueClarityCard extends StatelessWidget {
  const ProValueClarityCard({
    super.key,
    required this.entryCount,
    required this.source,
    required this.onSeePro,
    required this.onNotNow,
  });

  final int entryCount;
  final String source;
  final VoidCallback onSeePro;
  final VoidCallback onNotNow;

  @override
  Widget build(BuildContext context) {
    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.proValueClaritySeen,
      entryCount: entryCount,
      source: source,
      stage: ProTrustStage.proClarity,
      memoryScope: MemoryScopePolicy.scope.id,
      oncePerSession: true,
    );

    final bulletStyle = ArchiveMobileTypography.responsiveHelper(
      context,
    ).copyWith(color: AppColors.textSecondary);

    return Container(
      key: const Key('pro_value_clarity_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            ProTrustCopy.proTitle,
            key: const Key('pro_value_clarity_title'),
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            ProTrustCopy.proBody,
            key: const Key('pro_value_clarity_body'),
            style: ArchiveMobileTypography.body(
              context,
            ).copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text('• ${ProTrustCopy.proBulletFind}', style: bulletStyle),
          Text('• ${ProTrustCopy.proBulletExport}', style: bulletStyle),
          Text('• ${ProTrustCopy.proBulletContext}', style: bulletStyle),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  key: const Key('pro_value_clarity_not_now'),
                  onPressed: () {
                    ActivationFunnelAnalytics.track(
                      ActivationFunnelAnalytics.proValueClarityDismissed,
                      entryCount: entryCount,
                      source: source,
                      stage: ProTrustStage.proClarity,
                      memoryScope: MemoryScopePolicy.scope.id,
                    );
                    onNotNow();
                  },
                  child: const Text(ProTrustCopy.proSecondary),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(
                child: FilledButton(
                  key: const Key('pro_value_clarity_see_pro'),
                  onPressed: () {
                    ActivationFunnelAnalytics.track(
                      ActivationFunnelAnalytics.proValueClarityTapped,
                      entryCount: entryCount,
                      source: source,
                      stage: ProTrustStage.proClarity,
                      memoryScope: MemoryScopePolicy.scope.id,
                    );
                    onSeePro();
                  },
                  child: const Text(ProTrustCopy.proCta),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
