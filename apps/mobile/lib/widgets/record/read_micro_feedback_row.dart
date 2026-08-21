import 'package:archiveme_mobile/product/consumer_ui_copy.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Tiny optional feedback after user acts on a post-save read.
class ReadMicroFeedbackRow extends StatelessWidget {
  const ReadMicroFeedbackRow({
    required this.onUseful, required this.onNotQuite, super.key,
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