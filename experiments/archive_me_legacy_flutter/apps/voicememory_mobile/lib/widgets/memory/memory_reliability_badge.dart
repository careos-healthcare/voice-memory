import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/memory/memory_reliability_check.dart';
import '../../features/memory/memory_scope.dart';
import '../../features/memory/memory_scope_policy.dart';
import '../../services/activation_funnel_analytics.dart';
import '../../theme/app_colors.dart';

/// Cautious reliability label for memory-used cards.
class MemoryReliabilityBadge extends StatelessWidget {
  const MemoryReliabilityBadge({super.key, required this.state, this.cardType});

  final MemoryReliabilityState state;
  final String? cardType;

  @override
  Widget build(BuildContext context) {
    if (state == MemoryReliabilityState.enoughEvidence ||
        state == MemoryReliabilityState.blocked) {
      return const SizedBox.shrink();
    }

    ActivationFunnelAnalytics.track(
      ActivationFunnelAnalytics.memoryReliabilityChecked,
      cardType: cardType,
      memoryScope: MemoryScopePolicy.scope.id,
      reliabilityState: state.id,
      oncePerSession: true,
    );

    final helper = state.helper;
    return Padding(
      key: Key('memory_reliability_badge_${state.id}'),
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            state.label,
            style: ArchiveMobileTypography.responsiveHelper(context).copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (helper != null) ...[
            const SizedBox(height: 2),
            Text(
              helper,
              style: ArchiveMobileTypography.responsiveHelper(
                context,
              ).copyWith(color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}
