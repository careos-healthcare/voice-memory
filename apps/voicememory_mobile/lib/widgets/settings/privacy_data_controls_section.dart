import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../design/archive_mobile_typography.dart';
import '../../security/local_privacy_data_controls.dart';
import '../../security/privacy_data_controls_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import 'privacy_data_controls_dialogs.dart';

class PrivacyDataControlsSection extends StatefulWidget {
  const PrivacyDataControlsSection({
    super.key,
    this.controls,
  });

  final LocalPrivacyDataControls? controls;

  @override
  State<PrivacyDataControlsSection> createState() =>
      _PrivacyDataControlsSectionState();
}

class _PrivacyDataControlsSectionState extends State<PrivacyDataControlsSection> {
  bool _resetTipsBusy = false;

  LocalPrivacyDataControls get _controls =>
      widget.controls ?? LocalPrivacyDataControls.instance();

  Future<void> _resetDismissedTips() async {
    if (_resetTipsBusy) return;
    final confirmed = await showResetDismissedTipsDialog(context);
    if (!confirmed || !mounted) return;

    setState(() => _resetTipsBusy = true);
    try {
      await _controls.resetDismissedTips();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(PrivacyDataControlsCopy.resetTipsDone),
        ),
      );
    } finally {
      if (mounted) setState(() => _resetTipsBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: Text(
            PrivacyDataControlsCopy.sectionTitle,
            key: const Key('privacy_data_controls_section_title'),
            style: ArchiveMobileTypography.cardLabel(
              context,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        ListTile(
          key: const Key('privacy_data_stays_on_device_tile'),
          contentPadding: EdgeInsets.zero,
          title: Text(
            PrivacyDataControlsCopy.dataStaysOnDeviceTitle,
            style: ArchiveMobileTypography.listTitle(context),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => showLocalDataStaysSheet(context),
        ),
        ListTile(
          key: const Key('privacy_data_view_sample_archive_tile'),
          contentPadding: EdgeInsets.zero,
          title: Text(
            PrivacyDataControlsCopy.viewSampleArchiveTitle,
            style: ArchiveMobileTypography.listTitle(context),
          ),
          subtitle: Text(
            PrivacyDataControlsCopy.viewSampleArchiveSubtitle,
            style: ArchiveMobileTypography.listSubtitle(context),
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/sample-archive'),
        ),
        ListTile(
          key: const Key('privacy_data_reset_dismissed_tips_tile'),
          contentPadding: EdgeInsets.zero,
          title: Text(
            PrivacyDataControlsCopy.resetDismissedTipsTitle,
            style: ArchiveMobileTypography.listTitle(context),
          ),
          subtitle: Text(
            PrivacyDataControlsCopy.resetDismissedTipsSubtitle,
            style: ArchiveMobileTypography.listSubtitle(context),
          ),
          trailing: _resetTipsBusy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.chevron_right),
          onTap: _resetTipsBusy ? null : _resetDismissedTips,
        ),
        const SizedBox(height: AppSpacing.sm),
      ],
    );
  }
}
