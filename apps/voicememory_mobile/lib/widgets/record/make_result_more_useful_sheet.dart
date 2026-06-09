import 'package:flutter/material.dart';

import '../../features/activation/activation_tracker.dart';
import '../../product/consumer_ui_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_typography.dart';

/// One refinement option in the "Make this more useful" sheet.
class MakeResultMoreUsefulOption {
  const MakeResultMoreUsefulOption(this.label, this.reason);

  final String label;

  /// The not-useful reason used to rebuild the takeaway.
  final String reason;
}

/// Lets the user say what would make the result more useful, then refines the
/// takeaway. Each option maps to a not-useful reason the takeaway engine uses.
abstract final class MakeResultMoreUsefulSheet {
  MakeResultMoreUsefulSheet._();

  static const Color _warmSurface = Color(0xFFFFFBF5);

  static const List<MakeResultMoreUsefulOption> options = [
    MakeResultMoreUsefulOption(
      ConsumerUiCopy.makeResultMoreUsefulMoreSpecific,
      'too_vague',
    ),
    MakeResultMoreUsefulOption(
      ConsumerUiCopy.makeResultMoreUsefulMoreAccurate,
      'not_accurate',
    ),
    MakeResultMoreUsefulOption(
      ConsumerUiCopy.makeResultMoreUsefulMoreNextStep,
      'already_knew_this',
    ),
    MakeResultMoreUsefulOption(
      ConsumerUiCopy.makeResultMoreUsefulEasier,
      'confusing',
    ),
  ];

  /// Opens the sheet and returns the selected not-useful reason, or null when
  /// dismissed. Tracks the open and the selection.
  static Future<String?> show(BuildContext context) async {
    ActivationTracker.trackMakeResultMoreUsefulTapped();
    final reason = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: _warmSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ConsumerUiCopy.makeResultMoreUsefulSheetTitle,
                style:
                    VoiceMemoryTypography.cardTitleStyle().copyWith(fontSize: 16),
              ),
              const SizedBox(height: AppSpacing.sm),
              for (final option in options)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    option.label,
                    style: VoiceMemoryTypography.bodyStyle(
                      color: AppColors.textPrimary,
                    ).copyWith(fontSize: 15, height: 1.4),
                  ),
                  onTap: () =>
                      Navigator.of(sheetContext).pop(option.reason),
                ),
            ],
          ),
        ),
      ),
    );
    if (reason != null) {
      ActivationTracker.trackMakeResultMoreUsefulReasonSelected();
    }
    return reason;
  }
}
