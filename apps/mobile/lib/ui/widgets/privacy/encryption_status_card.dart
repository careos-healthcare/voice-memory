import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/privacy/privacy_security_control_center_copy.dart';
import 'package:archiveme_mobile/security/sqlite/secure_sqlite_lock_service.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Displays SQLCipher encryption status with an active badge when enabled.
class EncryptionStatusCard extends StatelessWidget {
  const EncryptionStatusCard({super.key});

  @override
  Widget build(BuildContext context) {
    final encryptionActive = SecureSqliteLockService.encryptionEnabled;

    return Container(
      key: const Key('encryption_status_card'),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  encryptionActive
                      ? PrivacySecurityControlCenterCopy.encryptionActiveLabel
                      : PrivacySecurityControlCenterCopy.encryptionInactiveLabel,
                  key: const Key('encryption_status_title'),
                  style: ArchiveMobileTypography.listTitle(context),
                ),
              ),
              if (encryptionActive)
                Container(
                  key: const Key('encryption_status_active_badge'),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.success),
                  ),
                  child: Text(
                    PrivacySecurityControlCenterCopy.encryptionActiveBadge,
                    style: ArchiveMobileTypography.cardLabel(context).copyWith(
                      color: AppColors.success,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            PrivacySecurityControlCenterCopy.encryptionBody,
            style: ArchiveMobileTypography.listSubtitle(context),
          ),
        ],
      ),
    );
  }
}
