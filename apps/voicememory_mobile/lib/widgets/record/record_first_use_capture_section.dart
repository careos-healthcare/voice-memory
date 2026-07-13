import 'package:flutter/material.dart';

import '../../record/record_screen_framing_copy.dart';
import '../../services/capture_pipeline_service.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';
import '../capture_entry_actions.dart';
import '../onboarding/first_proof_journey_strip_card.dart';
import '../security/archive_data_flow_sheet.dart';
import 'record_first_use_prompt_block.dart';

/// Single first-use capture block on Record — one primary path, no competing cards.
class RecordFirstUseCaptureSection extends StatelessWidget {
  const RecordFirstUseCaptureSection({
    super.key,
    required this.onRecord,
    required this.recordButtonLabel,
    this.recordButtonKey = const Key('capture_entry_record_cta'),
    this.typeCapturePrompt,
    this.onTextThoughtSaved,
    this.onLogPressureMoment,
    this.showFirstProofJourneyStrip = false,
    this.onViewSampleExample,
  });

  final VoidCallback onRecord;
  final String? recordButtonLabel;
  final Key recordButtonKey;
  final String? typeCapturePrompt;
  final Future<void> Function(CapturePipelineResult result)? onTextThoughtSaved;
  final VoidCallback? onLogPressureMoment;
  final bool showFirstProofJourneyStrip;
  final VoidCallback? onViewSampleExample;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('record_first_use_capture_section'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RecordFirstUsePromptBlock(
            hideLeadCopy: showFirstProofJourneyStrip,
          ),
          if (showFirstProofJourneyStrip) ...[
            const SizedBox(height: AppSpacing.xs),
            const FirstProofJourneyStripCard(),
          ],
          const SizedBox(height: AppSpacing.md),
          CaptureEntryActions(
            onRecord: onRecord,
            recordButtonKey: recordButtonKey,
            recordButtonLabel: recordButtonLabel,
            typeCapturePrompt: typeCapturePrompt,
            onTextThoughtSaved: onTextThoughtSaved,
            onLogPressureMoment: onLogPressureMoment,
            pressureMomentPresentation: CapturePressureMomentPresentation.textLink,
            onHowItWorks: () => showArchiveDataFlowSheet(context),
          ),
          if (onViewSampleExample != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                key: const Key('record_see_example_first_link'),
                onPressed: onViewSampleExample,
                child: const Text(RecordScreenFramingCopy.seeExampleFirstLink),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
