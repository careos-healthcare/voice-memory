import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../record/record_screen_framing_copy.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_colors.dart';
import '../security/archive_data_flow_sheet.dart';

/// Subtle first-run privacy line under the empty archive card — count 0 only.
class RecordFirstRunPrivacyReassurance extends StatelessWidget {
  const RecordFirstRunPrivacyReassurance({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const Key('record_first_run_privacy_reassurance'),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            RecordScreenFramingCopy.firstRunPrivacyTitle,
            key: const Key('record_first_run_privacy_title'),
            style: ArchiveMobileTypography.responsiveHelper(context).copyWith(
              color: VoiceMemoryColors.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            RecordScreenFramingCopy.firstRunPrivacyBody,
            key: const Key('record_first_run_privacy_body'),
            style: ArchiveMobileTypography.responsiveHelper(context).copyWith(
              color: VoiceMemoryColors.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          TextButton(
            key: const Key('record_first_run_privacy_link'),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: VoiceMemoryColors.textSecondary,
            ),
            onPressed: () => showArchiveDataFlowSheet(context),
            child: Text(
              RecordScreenFramingCopy.firstRunPrivacyLink,
              style: ArchiveMobileTypography.responsiveHelper(context).copyWith(
                fontSize: 12,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
