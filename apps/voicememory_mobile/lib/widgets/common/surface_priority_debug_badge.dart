import 'package:flutter/material.dart';

import '../../config/developer_settings_gate.dart';
import '../../features/surface_priority/surface_priority_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Debug-only summary of which cards won each priority slot.
class SurfacePriorityDebugBadge extends StatelessWidget {
  const SurfacePriorityDebugBadge({super.key, required this.result});

  final SurfacePriorityResult result;

  @override
  Widget build(BuildContext context) {
    if (!result.shouldShowDebugSummary) {
      return const SizedBox.shrink();
    }
    if (!DeveloperSettingsGate.canShowDeveloperSettings) {
      return const SizedBox.shrink();
    }

    final lines = <String>[
      'surface=${result.surface.name}',
      if (result.guidanceSlot != null) 'guidance=${result.guidanceSlot!.name}',
      if (result.proofSlot != null) 'proof=${result.proofSlot!.name}',
      if (result.correctionSlot != null)
        'correction=${result.correctionSlot!.name}',
      if (result.reportSlot != null) 'report=${result.reportSlot!.name}',
      if (result.proSlot != null) 'pro=${result.proSlot!.name}',
      'visible=${result.visibleCardCount}',
      'suppressed=${result.suppressedCardCount}',
    ];

    return Container(
      key: const Key('surface_priority_debug_badge'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Text(
        lines.join(' · '),
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}
