import 'dart:async';

import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/caregiver_grant/caregiver_grant_copy.dart';
import 'package:archiveme_mobile/features/caregiver_grant/caregiver_grant_flow.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Settings card that starts the caregiver access grant flow.
///
/// Self-gating on [V1CapabilityRegistry.caregiverMonitoring] (compile-time
/// default off, `caregiver_feature_flags.dart:14`) so the Settings insertion is
/// a single unconditional line, matching how the existing caregiver tile is
/// gated at `settings_screen.dart:272`.
class CaregiverEntryPoint extends StatelessWidget {
  const CaregiverEntryPoint({super.key, this.onSetUpAccess});

  static const Key cardKey = Key('caregiver_grant_entry_point_card');
  static const Key actionKey = Key('caregiver_grant_entry_point_action');

  /// Overrides opening the flow. Tests use it; Settings does not need it.
  final VoidCallback? onSetUpAccess;

  bool get _enabled => V1CapabilityRegistry.caregiverMonitoring;

  void _open(BuildContext context) {
    final override = onSetUpAccess;
    if (override != null) {
      override();
      return;
    }
    unawaited(CaregiverGrantFlow.start(context));
  }

  @override
  Widget build(BuildContext context) {
    if (!_enabled) return const SizedBox.shrink();

    // No Semantics container around the card: wrapping it merges the subtitle
    // into the title's node, so a screen reader reads the whole paragraph as
    // one heading. Title, subtitle, and button stay separate nodes.
    return Container(
      key: cardKey,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // container: true gives the heading its own node. Without it the
          // header flag lands on the enclosing node, which also absorbs the
          // subtitle, so the whole paragraph gets announced as a heading.
          Semantics(
            header: true,
            container: true,
            child: Text(
              CaregiverGrantCopy.entryTitle,
              style: ArchiveMobileTypography.listTitle(context),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            CaregiverGrantCopy.entrySubtitle,
            style: ArchiveMobileTypography.listSubtitle(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: FilledButton(
                key: actionKey,
                onPressed: () => _open(context),
                child: const Text(CaregiverGrantCopy.entryAction),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
