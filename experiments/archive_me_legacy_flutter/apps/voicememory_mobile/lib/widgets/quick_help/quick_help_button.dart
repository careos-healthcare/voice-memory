import 'package:flutter/material.dart';

import '../../features/language/localized_copy.dart';
import '../../theme/app_colors.dart';
import 'quick_help_sheet.dart';

/// A quiet "Need help?" pill — the entry point to the Quick help sheet.
///
/// Deliberately understated: it is a safety valve for when the user is stuck,
/// not part of the main flow.
class QuickHelpButton extends StatelessWidget {
  const QuickHelpButton({
    super.key,
    this.languageCode = 'en',
    this.latestReflectionText,
    this.patternTitle,
    this.resultHint,
    this.nextCheck,
    required this.onStartRecording,
    this.onUseCheck,
    this.onShowPerspective,
    this.alignment = Alignment.center,
  });

  final String languageCode;
  final String? latestReflectionText;
  final String? patternTitle;
  final String? resultHint;
  final String? nextCheck;
  final Future<void> Function() onStartRecording;
  final Future<void> Function(String question)? onUseCheck;
  final VoidCallback? onShowPerspective;
  final AlignmentGeometry alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: TextButton.icon(
        onPressed: () => showQuickHelpSheet(
          context,
          languageCode: languageCode,
          latestReflectionText: latestReflectionText,
          patternTitle: patternTitle,
          resultHint: resultHint,
          nextCheck: nextCheck,
          onStartRecording: onStartRecording,
          onUseCheck: onUseCheck,
          onShowPerspective: onShowPerspective,
        ),
        icon: Icon(
          Icons.help_outline,
          size: 16,
          color: AppColors.textSecondary,
        ),
        label: Text(
          localized('needHelp', languageCode),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }
}
