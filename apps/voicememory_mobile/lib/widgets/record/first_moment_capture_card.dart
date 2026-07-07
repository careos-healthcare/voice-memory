import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../features/first_moment_capture/first_moment_capture_analytics.dart';
import '../../features/first_moment_capture/first_moment_capture_model.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Zero-entry first save card — typed or mic through existing capture flows.
class FirstMomentCaptureCard extends StatefulWidget {
  const FirstMomentCaptureCard({
    super.key,
    required this.result,
    required this.onSaveOneSentence,
    required this.onRecordInstead,
    required this.onExampleSelected,
  });

  const FirstMomentCaptureCard.test({
    super.key,
    required this.result,
    required this.onSaveOneSentence,
    required this.onRecordInstead,
    required this.onExampleSelected,
  });

  final FirstMomentCaptureResult result;
  final VoidCallback onSaveOneSentence;
  final VoidCallback onRecordInstead;
  final ValueChanged<String> onExampleSelected;

  @override
  State<FirstMomentCaptureCard> createState() => _FirstMomentCaptureCardState();
}

class _FirstMomentCaptureCardState extends State<FirstMomentCaptureCard> {
  var _trackedSeen = false;

  void _trackSeenOnce() {
    if (_trackedSeen) return;
    _trackedSeen = true;
    FirstMomentCaptureAnalytics.seen(result: widget.result);
  }

  void _handleSaveOneSentence() {
    FirstMomentCaptureAnalytics.ctaTapped(
      result: widget.result,
      actionType: FirstMomentCaptureActionType.saveOneSentence,
    );
    widget.onSaveOneSentence();
  }

  void _handleRecordInstead() {
    FirstMomentCaptureAnalytics.ctaTapped(
      result: widget.result,
      actionType: FirstMomentCaptureActionType.recordInstead,
    );
    widget.onRecordInstead();
  }

  void _handleExampleSelected(FirstMomentCaptureExample example) {
    FirstMomentCaptureAnalytics.exampleTapped(
      result: widget.result,
      exampleType: example.type,
    );
    widget.onExampleSelected(example.text);
  }

  @override
  Widget build(BuildContext context) {
    _trackSeenOnce();

    final bodyStyle = ArchiveMobileTypography.explanationBody(context).copyWith(
      color: AppColors.textSecondary,
      height: 1.45,
    );

    return Container(
      key: const Key('first_moment_capture_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: const Color(0xFFF8FAFC)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.result.title,
            key: const Key('first_moment_capture_title'),
            style: ArchiveMobileTypography.responsiveSectionTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.result.body,
            key: const Key('first_moment_capture_body'),
            style: bodyStyle.copyWith(color: AppColors.textPrimary),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.result.reassurance,
            key: const Key('first_moment_capture_reassurance'),
            style: bodyStyle,
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            widget.result.privacyLine,
            key: const Key('first_moment_capture_privacy'),
            style: bodyStyle,
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (final example in widget.result.examples)
                ActionChip(
                  key: Key('first_moment_capture_example_${example.type.name}'),
                  label: Text(example.text),
                  onPressed: () => _handleExampleSelected(example),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            key: const Key('first_moment_capture_save_one_sentence'),
            onPressed: _handleSaveOneSentence,
            child: Text(widget.result.primaryCta),
          ),
          const SizedBox(height: AppSpacing.xs),
          TextButton(
            key: const Key('first_moment_capture_record_instead'),
            onPressed: _handleRecordInstead,
            child: Text(widget.result.secondaryCta),
          ),
        ],
      ),
    );
  }
}
