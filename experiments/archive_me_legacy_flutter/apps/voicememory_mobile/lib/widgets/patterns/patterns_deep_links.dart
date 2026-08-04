import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../product/consumer_ui_copy.dart';
import '../../theme/app_spacing.dart';

/// Secondary navigation from Patterns — not in bottom nav.
class PatternsDeepLinks extends StatelessWidget {
  const PatternsDeepLinks({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton(
          onPressed: () => context.go('/archive-belief'),
          child: const Text(ConsumerUiCopy.viewAllPatterns),
        ),
        const SizedBox(height: AppSpacing.sm),
        OutlinedButton(
          onPressed: () => context.go('/belief-changes'),
          child: const Text(ConsumerUiCopy.seeWhatChanged),
        ),
      ],
    );
  }
}
