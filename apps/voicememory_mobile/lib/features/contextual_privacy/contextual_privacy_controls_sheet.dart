import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/archive_controls/archive_control_copy.dart';
import '../../features/contextual_privacy/contextual_privacy_analytics.dart';
import '../../features/privacy_trust/privacy_trust_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Quick access to archive controls and the Privacy & Trust Centre.
abstract final class ContextualPrivacyControlsSheet {
  ContextualPrivacyControlsSheet._();

  static Future<void> show(
    BuildContext context, {
    required String source,
    Future<void> Function()? onDeleteMoment,
    Future<void> Function()? onRemoveFromPattern,
  }) {
    ContextualPrivacyAnalytics.controlsOpened(source: source);
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: Column(
            key: const Key('contextual_privacy_controls_sheet'),
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                PrivacyTrustCopy.yourControlsHeading,
                key: const Key('contextual_privacy_controls_heading'),
                style: ArchiveMobileTypography.responsiveSectionTitle(
                  sheetContext,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              if (onDeleteMoment != null)
                ListTile(
                  key: const Key('contextual_privacy_control_delete_moment'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    ArchiveControlCopy.deleteMomentButton,
                    style: ArchiveMobileTypography.listTitle(sheetContext),
                  ),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await onDeleteMoment();
                  },
                ),
              if (onRemoveFromPattern != null)
                ListTile(
                  key: const Key(
                    'contextual_privacy_control_remove_from_pattern',
                  ),
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    ArchiveControlCopy.excludeFromPatternButton,
                    style: ArchiveMobileTypography.listTitle(sheetContext),
                  ),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await onRemoveFromPattern();
                  },
                ),
              ListTile(
                key: const Key('contextual_privacy_control_privacy_centre'),
                contentPadding: EdgeInsets.zero,
                title: Text(
                  PrivacyTrustCopy.title,
                  style: ArchiveMobileTypography.listTitle(sheetContext),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  sheetContext.push('/privacy-trust-centre');
                },
              ),
              const SizedBox(height: AppSpacing.xs),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  key: const Key('contextual_privacy_controls_done'),
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: const Text('Done'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
