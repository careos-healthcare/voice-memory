import 'package:flutter/material.dart';

import '../../product/consumer_ui_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// Tiny optional feedback after user acts on a post-save read.
class ReadMicroFeedbackRow extends StatelessWidget {
  const ReadMicroFeedbackRow({
    super.key,
    required this.onUseful,
    required this.onNotQuite,
  });

  final VoidCallback onUseful;
  final VoidCallback onNotQuite;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          ConsumerUiCopy.readMicroFeedbackQuestion,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontSize: 16,
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onUseful,
                child: const Text(ConsumerUiCopy.readMicroFeedbackUseful),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: OutlinedButton(
                onPressed: onNotQuite,
                child: const Text(ConsumerUiCopy.readMicroFeedbackNotQuite),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
