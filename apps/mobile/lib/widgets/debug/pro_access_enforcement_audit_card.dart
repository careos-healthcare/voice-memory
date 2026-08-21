import 'package:archiveme_mobile/config/developer_settings_gate.dart';
import 'package:archiveme_mobile/features/pro_access_enforcement/pro_access_enforcement_audit.dart';
import 'package:archiveme_mobile/features/pro_access_enforcement/pro_access_enforcement_audit_copy.dart';
import 'package:archiveme_mobile/features/pro_access_enforcement/pro_access_enforcement_audit_v2.dart';
import 'package:archiveme_mobile/features/pro_access_enforcement/pro_access_enforcement_audit_v2_copy.dart';
import 'package:archiveme_mobile/features/pro_access_enforcement/pro_access_enforcement_audit_v3.dart';
import 'package:archiveme_mobile/features/pro_access_enforcement/pro_access_enforcement_audit_v3_copy.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Developer-only Pro access enforcement dashboard.
class ProAccessEnforcementAuditCard extends StatelessWidget {
  const ProAccessEnforcementAuditCard({
    required this.dashboard, super.key,
    this.storeReadinessBridge,
  });

  final ProAccessEnforcementDashboard dashboard;
  final ProAccessEnforcementStoreReadinessBridge? storeReadinessBridge;

  @override
  Widget build(BuildContext context) {
    if (!DeveloperSettingsGate.canShowDeveloperSettings) {
      return const SizedBox.shrink(
        key: Key('pro_access_enforcement_audit_hidden'),
      );
    }

    return Container(
      key: const Key('pro_access_enforcement_audit_card'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            dashboard.headline,
            key: const Key('pro_access_enforcement_audit_title'),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            dashboard.body,
            key: const Key('pro_access_enforcement_audit_body'),
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          if (storeReadinessBridge != null) ...[
            Text(
              '${ProAccessEnforcementAuditV3Copy.bridgeSectionTitle}: '
              '${storeReadinessBridge!.alignmentLabel}',
              key: const Key('pro_access_enforcement_audit_bridge'),
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: storeReadinessBridge!.aligned
                    ? AppColors.textPrimary
                    : AppColors.warning,
              ),
            ),
            if (storeReadinessBridge!.misalignedTagCount > 0)
              Text(
                '${storeReadinessBridge!.misalignedTagCount} billing step tags misaligned',
                style: const TextStyle(color: AppTheme.muted, fontSize: 12),
              ),
            const SizedBox(height: 8),
          ],
          Text(
            '${ProAccessEnforcementAuditV2Copy.decisionLabel}: ${dashboard.decisionLabel}',
            key: const Key('pro_access_enforcement_audit_decision'),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color:
                  dashboard.decision ==
                      ProAccessEnforcementAuditDecision.productionBlocked
                  ? AppColors.warning
                  : AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            dashboard.message,
            style: const TextStyle(
              color: AppTheme.muted,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${dashboard.productionBlockerCount} ${ProAccessEnforcementAuditV2Copy.blockerSummary} · '
            '${dashboard.documentedGapCount} ${ProAccessEnforcementAuditV2Copy.gapSummary}',
            key: const Key('pro_access_enforcement_audit_summary'),
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            'RevenueCat live: ${dashboard.revenueCatConfigured ? 'yes' : 'no'} · '
            'Pro active: ${dashboard.proEntitlementActive ? 'yes' : 'no'} · '
            'App lock: ${dashboard.appLockEnabled ? 'on' : 'off'}',
            key: const Key('pro_access_enforcement_audit_runtime'),
            style: const TextStyle(color: AppTheme.muted, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Text(
            ProAccessEnforcementAuditV2Copy.sectionTitle,
            key: const Key('pro_access_enforcement_audit_section_title'),
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          for (final row in dashboard.rows) ...[
            _EnforcementTile(row: row),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }
}

class _EnforcementTile extends StatelessWidget {
  const _EnforcementTile({required this.row});

  final ProAccessEnforcementDashboardRow row;

  @override
  Widget build(BuildContext context) {
    final color = switch (row.classification) {
      ProAccessEnforcementClassification.productionBlocker => AppColors.warning,
      ProAccessEnforcementClassification.notEnforcedYet => AppTheme.muted,
      ProAccessEnforcementClassification.acceptableForTestFlight =>
        AppTheme.muted,
      _ => AppColors.textPrimary,
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                row.label,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              Text(
                row.detailLabel,
                style: const TextStyle(color: AppTheme.muted, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          row.classificationLabel,
          textAlign: TextAlign.end,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}