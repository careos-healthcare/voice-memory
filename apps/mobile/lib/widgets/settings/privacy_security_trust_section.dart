import 'package:archiveme_mobile/core/config/v1_capability_registry.dart';
import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/privacy/privacy_security_trust_copy.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Surfaces the infrastructure guarantees already built in ArchiveMe.
///
/// The caregiver guarantee and its link read
/// `V1CapabilityRegistry.caregiverMonitoring` directly rather than taking a
/// constructor flag: this is the ship gate for third-party archive access, and
/// a caller must not be able to forget it the way `showOnDeviceLink` can be.
class PrivacySecurityTrustSection extends StatelessWidget {
  const PrivacySecurityTrustSection({
    super.key,
    this.onScrollToOnDeviceToggle,
    this.showOnDeviceLink = true,
  });

  /// Scrolls the settings list to the on-device processing toggle.
  final VoidCallback? onScrollToOnDeviceToggle;

  /// When false, hides the link to the on-device toggle (e.g. capability off).
  final bool showOnDeviceLink;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('privacy_security_trust_section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: Text(
            PrivacySecurityTrustCopy.sectionTitle,
            key: const Key('privacy_security_trust_section_title'),
            style: ArchiveMobileTypography.cardLabel(
              context,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        const _GuaranteeBlock(
          key: Key('privacy_security_trust_encrypted_block'),
          title: PrivacySecurityTrustCopy.encryptedAtRestTitle,
          body: PrivacySecurityTrustCopy.encryptedAtRestBody,
        ),
        const SizedBox(height: AppSpacing.sm),
        const _GuaranteeBlock(
          key: Key('privacy_security_trust_on_device_block'),
          title: PrivacySecurityTrustCopy.onDeviceProcessingTitle,
          body: PrivacySecurityTrustCopy.onDeviceProcessingBody,
        ),
        if (V1CapabilityRegistry.caregiverMonitoring) ...[
          const SizedBox(height: AppSpacing.sm),
          const _GuaranteeBlock(
            key: Key('privacy_security_trust_caregiver_block'),
            title: PrivacySecurityTrustCopy.caregiverAccessTitle,
            body: PrivacySecurityTrustCopy.caregiverAccessBody,
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        ListTile(
          key: const Key('privacy_security_trust_link_security'),
          contentPadding: EdgeInsets.zero,
          title: Text(
            PrivacySecurityTrustCopy.linkSecuritySettings,
            style: ArchiveMobileTypography.listTitle(context),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/security'),
        ),
        if (showOnDeviceLink)
          ListTile(
            key: const Key('privacy_security_trust_link_on_device'),
            contentPadding: EdgeInsets.zero,
            title: Text(
              PrivacySecurityTrustCopy.linkOnDeviceToggle,
              style: ArchiveMobileTypography.listTitle(context),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: onScrollToOnDeviceToggle,
          ),
        if (V1CapabilityRegistry.caregiverMonitoring)
          ListTile(
            key: const Key('privacy_security_trust_link_caregiver'),
            contentPadding: EdgeInsets.zero,
            title: Text(
              PrivacySecurityTrustCopy.linkCaregiverAccess,
              style: ArchiveMobileTypography.listTitle(context),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/caregiver-access'),
          ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }
}

class _GuaranteeBlock extends StatelessWidget {
  const _GuaranteeBlock({
    required this.title,
    required this.body,
    super.key,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: ArchiveMobileTypography.listTitle(context)),
        const SizedBox(height: 4),
        Text(
          body,
          style: ArchiveMobileTypography.listSubtitle(context),
        ),
      ],
    );
  }
}
