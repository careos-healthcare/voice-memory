import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/archive_proof/visible_archive_proof_copy.dart';
import '../../features/onboarding_future_value/onboarding_future_value_copy.dart';
import '../../services/capture_pipeline_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';
import '../capture_entry_actions.dart';

/// One calm first-run card: promise copy and exactly two capture actions.
class RecordFirstRunScreenCard extends StatelessWidget {
  const RecordFirstRunScreenCard({
    super.key,
    required this.onRecord,
    required this.recordButtonLabel,
    this.recordButtonKey = const Key('capture_entry_record_cta'),
    this.onTextThoughtSaved,
    this.minimalFirstRun = true,
    this.onFuturePreview,
  });

  final VoidCallback onRecord;
  final String? recordButtonLabel;
  final Key recordButtonKey;
  final Future<void> Function(CapturePipelineResult result)? onTextThoughtSaved;
  final bool minimalFirstRun;
  final VoidCallback? onFuturePreview;

  @override
  Widget build(BuildContext context) {
    final titleStyle = ArchiveMobileTypography.responsiveSectionTitle(context);
    final bodyStyle = ArchiveMobileTypography.explanationBody(
      context,
    ).copyWith(color: AppColors.textPrimary, height: 1.45);
    final supportingStyle = ArchiveMobileTypography.responsiveHelper(
      context,
    ).copyWith(color: AppColors.textSecondary, height: 1.4);

    return Container(
      key: const Key('record_first_run_screen_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(
        background: const Color(0xFFF6F4FF),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            VisibleArchiveProofCopy.firstRunRecordTitle,
            key: const Key('record_first_run_promise_title'),
            style: titleStyle,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            VisibleArchiveProofCopy.firstRunRecordBody,
            key: const Key('record_first_run_promise_body'),
            style: bodyStyle,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            VisibleArchiveProofCopy.firstRunRecordSupportingLine,
            key: const Key('record_first_run_promise_supporting'),
            style: supportingStyle,
          ),
          const SizedBox(height: AppSpacing.md),
          CaptureEntryActions(
            onRecord: onRecord,
            recordButtonKey: recordButtonKey,
            recordButtonLabel: recordButtonLabel,
            onTextThoughtSaved: onTextThoughtSaved,
            minimalFirstRun: minimalFirstRun,
          ),
          if (onFuturePreview != null) ...[
            const SizedBox(height: AppSpacing.xs),
            TextButton(
              key: const Key('record_first_run_future_preview'),
              onPressed: onFuturePreview,
              child: const Text(
                OnboardingFutureValueCopy.recordEntryAction,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
