import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../security/privacy_data_controls_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

Future<void> showLocalDataStaysSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        AppSpacing.lg + MediaQuery.paddingOf(sheetContext).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            PrivacyDataControlsCopy.dataStaysOnDeviceTitle,
            key: const Key('privacy_data_stays_title'),
            style: ArchiveMobileTypography.responsiveSectionTitle(sheetContext),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            PrivacyDataControlsCopy.dataStaysOnDeviceBody,
            key: const Key('privacy_data_stays_body'),
            style: ArchiveMobileTypography.responsiveHelper(
              sheetContext,
            ).copyWith(color: AppColors.textPrimary, height: 1.45),
          ),
          const SizedBox(height: AppSpacing.md),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              key: const Key('privacy_data_stays_done'),
              onPressed: () => Navigator.of(sheetContext).pop(),
              child: const Text('Done'),
            ),
          ),
        ],
      ),
    ),
  );
}

Future<bool> showClearLocalArchiveDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: const Text(PrivacyDataControlsCopy.clearLocalArchiveConfirmTitle),
      content: const Text(PrivacyDataControlsCopy.clearLocalArchiveConfirmBody),
      actions: [
        TextButton(
          key: const Key('clear_local_archive_cancel'),
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text(PrivacyDataControlsCopy.cancel),
        ),
        FilledButton(
          key: const Key('clear_local_archive_confirm'),
          style: FilledButton.styleFrom(backgroundColor: AppColors.error),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text(PrivacyDataControlsCopy.clearArchiveConfirm),
        ),
      ],
    ),
  );
  return result ?? false;
}

Future<bool> showResetDismissedTipsDialog(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text(PrivacyDataControlsCopy.resetDismissedTipsConfirmTitle),
      content: const Text(
        PrivacyDataControlsCopy.resetDismissedTipsConfirmBody,
      ),
      actions: [
        TextButton(
          key: const Key('reset_dismissed_tips_cancel'),
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text(PrivacyDataControlsCopy.cancel),
        ),
        FilledButton(
          key: const Key('reset_dismissed_tips_confirm'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text(PrivacyDataControlsCopy.resetTipsConfirm),
        ),
      ],
    ),
  );
  return result ?? false;
}
