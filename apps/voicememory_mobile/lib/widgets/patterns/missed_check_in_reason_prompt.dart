import 'package:flutter/material.dart';

import '../../features/trial/hook_diagnosis_model.dart';
import '../../features/trial/hook_diagnosis_store.dart';
import '../../features/trial/hook_diagnosis_tracker.dart';
import '../../features/tomorrow_return/tomorrow_check_in_model.dart';
import '../../product/consumer_ui_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_typography.dart';

/// Shown once when user returns after missing a due check-in.
class MissedCheckInReasonPrompt extends StatefulWidget {
  const MissedCheckInReasonPrompt({
    super.key,
    required this.checkIn,
    this.onAnswered,
  });

  final TomorrowCheckIn checkIn;
  final VoidCallback? onAnswered;

  @override
  State<MissedCheckInReasonPrompt> createState() =>
      _MissedCheckInReasonPromptState();
}

class _MissedCheckInReasonPromptState extends State<MissedCheckInReasonPrompt> {
  bool _answered = false;

  Future<void> _onReason(String reason) async {
    if (_answered) return;
    setState(() => _answered = true);
    HookDiagnosisTracker.trackMissedReason(
      checkInId: widget.checkIn.id,
      reason: reason,
    );
    await HookDiagnosisStore.instance()
        .markMissedReasonPromptShown(widget.checkIn.id);
    widget.onAnswered?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (_answered) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF5E6D3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ConsumerUiCopy.missedCheckInReasonTitle,
            style: VoiceMemoryTypography.bodyStyle(
              color: AppColors.textPrimary,
            ).copyWith(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _chip('I forgot', HookDiagnosisMissedReason.forgot),
              _chip('I did not care enough', HookDiagnosisMissedReason.didNotCare),
              _chip('It was confusing', HookDiagnosisMissedReason.confusing),
              _chip('Other', HookDiagnosisMissedReason.other),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, String reason) {
    return ActionChip(
      label: Text(label),
      onPressed: () => _onReason(reason),
      backgroundColor: Colors.white,
      side: const BorderSide(color: Color(0xFFF5E6D3)),
      labelStyle: VoiceMemoryTypography.bodyStyle(
        color: AppColors.textSecondary,
      ).copyWith(fontSize: 13),
    );
  }
}
