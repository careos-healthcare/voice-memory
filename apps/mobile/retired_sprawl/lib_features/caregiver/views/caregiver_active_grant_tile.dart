import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_access_service.dart';
import 'package:archiveme_mobile/features/caregiver/caregiver_copy.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// One active caregiver grant with revoke action — testable without dashboard load.
class CaregiverActiveGrantTile extends StatelessWidget {
  const CaregiverActiveGrantTile({
    required this.grant,
    required this.onRevoke,
    super.key,
    this.isRevoking = false,
  });

  final CaregiverActiveGrant grant;
  final VoidCallback onRevoke;
  final bool isRevoking;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat.yMMMd().add_jm();
    final grantedLabel = dateFormat.format(grant.grantedAt.toLocal());
    final expiresLabel = grant.expiresAt == null
        ? null
        : dateFormat.format(grant.expiresAt!.toLocal());

    return Container(
      key: Key('caregiver_active_grant_${grant.tokenId}'),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            grant.caregiverId,
            key: Key('caregiver_active_grant_caregiver_${grant.tokenId}'),
            style: ArchiveMobileTypography.sectionTitle(context),
          ),
          if (grant.isCurrentSession) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              CaregiverCopy.currentSessionBadge,
              key: Key('caregiver_active_grant_current_session_${grant.tokenId}'),
              style: ArchiveMobileTypography.cardLabel(context),
            ),
          ],
          const SizedBox(height: AppSpacing.xs),
          Text('${CaregiverCopy.grantedAtLabel}: $grantedLabel'),
          if (expiresLabel != null)
            Text('${CaregiverCopy.expiresAtLabel}: $expiresLabel'),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            key: Key('caregiver_revoke_access_${grant.tokenId}'),
            onPressed: isRevoking ? null : onRevoke,
            child: isRevoking
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(CaregiverCopy.revokeAccessCta),
          ),
        ],
      ),
    );
  }
}
