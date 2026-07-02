import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/trust/trust_reliability_copy.dart';
import '../../theme/app_theme.dart';

/// Small trust section for About — navigation only, no destructive actions.
class PrivacyTrustSection extends StatelessWidget {
  const PrivacyTrustSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          TrustReliabilityCopy.sectionTitle,
          key: const Key('privacy_trust_section_title'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        ListTile(
          key: const Key('privacy_trust_archive_private_tile'),
          contentPadding: EdgeInsets.zero,
          title: const Text(TrustReliabilityCopy.archivePrivateTitle),
          subtitle: const Text(
            TrustReliabilityCopy.archivePrivateSubtitle,
            style: TextStyle(color: AppTheme.muted, height: 1.4),
          ),
          trailing: const Icon(Icons.chevron_right, size: 18),
          onTap: () => context.push('/privacy'),
        ),
        ListTile(
          key: const Key('privacy_trust_reset_archive_tile'),
          contentPadding: EdgeInsets.zero,
          title: const Text(TrustReliabilityCopy.resetArchiveTitle),
          subtitle: const Text(
            TrustReliabilityCopy.resetArchiveSubtitle,
            style: TextStyle(color: AppTheme.muted, height: 1.4),
          ),
          trailing: const Icon(Icons.chevron_right, size: 18),
          onTap: () => context.push('/settings'),
        ),
        ListTile(
          key: const Key('privacy_trust_copy_reports_tile'),
          contentPadding: EdgeInsets.zero,
          title: const Text(TrustReliabilityCopy.copyPrivateReportsTitle),
          subtitle: const Text(
            TrustReliabilityCopy.copyPrivateReportsSubtitle,
            style: TextStyle(color: AppTheme.muted, height: 1.4),
          ),
        ),
        ListTile(
          key: const Key('privacy_trust_support_tile'),
          contentPadding: EdgeInsets.zero,
          title: const Text(TrustReliabilityCopy.supportAvailableTitle),
          subtitle: const Text(
            TrustReliabilityCopy.supportAvailableSubtitle,
            style: TextStyle(color: AppTheme.muted, height: 1.4),
          ),
          trailing: const Icon(Icons.chevron_right, size: 18),
          onTap: () => context.push('/support-feedback'),
        ),
      ],
    );
  }
}
