import 'dart:async';

import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../record/record_screen_framing_copy.dart';
import '../../services/capture_pipeline_service.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';
import '../capture_entry_actions.dart';
import 'record_how_it_works_sheet.dart';

/// One calm first-run card: promise, voice/type actions, and small links.
class RecordFirstRunScreenCard extends StatelessWidget {
  const RecordFirstRunScreenCard({
    super.key,
    required this.onRecord,
    required this.recordButtonLabel,
    this.recordButtonKey = const Key('capture_entry_record_cta'),
    this.typeCapturePrompt,
    this.onTextThoughtSaved,
    required this.onViewSampleExample,
  });

  final VoidCallback onRecord;
  final String? recordButtonLabel;
  final Key recordButtonKey;
  final String? typeCapturePrompt;
  final Future<void> Function(CapturePipelineResult result)? onTextThoughtSaved;
  final VoidCallback onViewSampleExample;

  @override
  Widget build(BuildContext context) {
    final titleStyle = ArchiveMobileTypography.responsiveSectionTitle(context);
    final bodyStyle = ArchiveMobileTypography.explanationBody(context).copyWith(
      color: AppColors.textPrimary,
      height: 1.45,
    );
    final supportingStyle =
        ArchiveMobileTypography.responsiveHelper(context).copyWith(
      color: AppColors.textSecondary,
      height: 1.4,
    );
    final linkStyle = const TextStyle(
      fontSize: 13,
      decoration: TextDecoration.underline,
    );

    return Container(
      key: const Key('record_first_run_screen_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: const Color(0xFFF6F4FF)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            RecordFirstRunPromiseCopy.title,
            key: const Key('record_first_run_promise_title'),
            style: titleStyle,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            RecordFirstRunPromiseCopy.body,
            key: const Key('record_first_run_promise_body'),
            style: bodyStyle,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            RecordFirstRunPromiseCopy.supportingLine,
            key: const Key('record_first_run_promise_supporting'),
            style: supportingStyle,
          ),
          const SizedBox(height: AppSpacing.md),
          CaptureEntryActions(
            onRecord: onRecord,
            recordButtonKey: recordButtonKey,
            recordButtonLabel: recordButtonLabel,
            typeCapturePrompt: typeCapturePrompt,
            onTextThoughtSaved: onTextThoughtSaved,
            pressureMomentPresentation: CapturePressureMomentPresentation.none,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            runSpacing: 2,
            children: [
              TextButton(
                key: const Key('record_see_example_link'),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: AppColors.textSecondary,
                ),
                onPressed: onViewSampleExample,
                child: Text(
                  RecordScreenFramingCopy.seeExampleLink,
                  style: linkStyle,
                ),
              ),
              Text(
                '·',
                style: supportingStyle,
              ),
              TextButton(
                key: const Key('capture_how_it_works_link'),
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  foregroundColor: AppColors.textSecondary,
                ),
                onPressed: () => unawaited(showRecordHowItWorksSheet(context)),
                child: Text(
                  RecordScreenFramingCopy.firstRunPrivacyLink,
                  style: linkStyle,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Small Pro positioning line below the first-run card.
class RecordFirstRunProLine extends StatelessWidget {
  const RecordFirstRunProLine({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      RecordFirstRunPromiseCopy.proLine,
      key: const Key('record_first_run_pro_line'),
      style: ArchiveMobileTypography.responsiveHelper(context).copyWith(
        color: AppColors.textSecondary,
        height: 1.4,
      ),
    );
  }
}
