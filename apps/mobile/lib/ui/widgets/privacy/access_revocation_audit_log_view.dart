import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_models.dart';
import 'package:archiveme_mobile/features/privacy/privacy_security_control_center_copy.dart';
import 'package:archiveme_mobile/features/privacy/privacy_security_engagement_analytics.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Chronological immutable audit log for caregiver access events.
class AccessRevocationAuditLogView extends StatelessWidget {
  const AccessRevocationAuditLogView({
    required this.entries,
    super.key,
  });

  final List<AuditLogEntry> entries;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      key: const Key('access_revocation_audit_log_expansion'),
      tilePadding: EdgeInsets.zero,
      title: Text(
        PrivacySecurityControlCenterCopy.auditLogTitle,
        style: ArchiveMobileTypography.listTitle(context),
      ),
      onExpansionChanged: (expanded) {
        PrivacySecurityEngagementAnalytics.caregiverAuditLogExpanded(
          expanded: expanded,
        );
      },
      children: [
        if (entries.isEmpty)
          Text(
            PrivacySecurityControlCenterCopy.auditLogEmpty,
            key: const Key('access_revocation_audit_log_empty'),
            style: ArchiveMobileTypography.listSubtitle(context),
          )
        else
          ListView.separated(
            key: const Key('access_revocation_audit_log_list'),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: entries.length,
            separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
            itemBuilder: (context, index) {
              final entry = entries[index];
              return _AuditLogRow(entry: entry);
            },
          ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }
}

class _AuditLogRow extends StatelessWidget {
  const _AuditLogRow({required this.entry});

  final AuditLogEntry entry;

  @override
  Widget build(BuildContext context) {
    final timestamp =
        DateFormat.yMMMd().add_jm().format(entry.timestamp.toLocal());
    final action = PrivacySecurityControlCenterCopy.auditActionLabel(
      entry.action,
    );
    final resource = entry.resourceId?.trim().isNotEmpty == true
        ? entry.resourceId!.trim()
        : entry.resourceType;

    return Container(
      key: Key('audit_log_row_${entry.entryId}'),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            action,
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: 4),
          Text(
            '$timestamp · $resource',
            style: ArchiveMobileTypography.listSubtitle(context),
          ),
        ],
      ),
    );
  }
}
