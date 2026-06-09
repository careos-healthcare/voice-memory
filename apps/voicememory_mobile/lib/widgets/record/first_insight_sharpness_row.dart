import 'package:flutter/material.dart';

import '../../product/consumer_ui_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';

/// First-use sharpness check after user acts on a post-save read.
class FirstInsightSharpnessRow extends StatelessWidget {
  const FirstInsightSharpnessRow({
    super.key,
    required this.onYesSpecific,
    required this.onTooGeneric,
    required this.onWrongAngle,
  });

  final VoidCallback onYesSpecific;
  final VoidCallback onTooGeneric;
  final VoidCallback onWrongAngle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          ConsumerUiCopy.firstInsightSharpnessQuestion,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize: 16,
                color: AppColors.textSecondary,
              ),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton(
          onPressed: onYesSpecific,
          child: const Text(ConsumerUiCopy.firstInsightSharpnessYes),
        ),
        const SizedBox(height: AppSpacing.xs),
        OutlinedButton(
          onPressed: onTooGeneric,
          child: const Text(ConsumerUiCopy.firstInsightSharpnessTooGeneric),
        ),
        const SizedBox(height: AppSpacing.xs),
        OutlinedButton(
          onPressed: onWrongAngle,
          child: const Text(ConsumerUiCopy.firstInsightSharpnessWrongAngle),
        ),
      ],
    );
  }
}
