import 'package:archiveme_mobile/features/post_save/post_save_focused_actions_copy.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Compact post-save actions — evidence and Patterns live off the Record stack.
class PostSaveFocusedActionsBar extends StatelessWidget {
  const PostSaveFocusedActionsBar({
    required this.onViewEvidence, required this.onViewPatterns, required this.onAddOneMoreMoment, super.key,
    this.showViewEvidence = true,
  });

  final VoidCallback onViewEvidence;
  final VoidCallback onViewPatterns;
  final VoidCallback onAddOneMoreMoment;
  final bool showViewEvidence;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const Key('post_save_focused_actions_bar'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          key: const Key('post_save_add_one_more_moment_cta'),
          onPressed: onAddOneMoreMoment,
          child: const Text(PostSaveFocusedActionsCopy.addOneMoreMoment),
        ),
        const SizedBox(height: AppSpacing.xs),
        if (showViewEvidence) ...[
          OutlinedButton(
            key: const Key('post_save_view_evidence_cta'),
            onPressed: onViewEvidence,
            child: const Text(PostSaveFocusedActionsCopy.viewEvidence),
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        TextButton(
          key: const Key('post_save_view_patterns_cta'),
          onPressed: onViewPatterns,
          child: const Text(PostSaveFocusedActionsCopy.viewPatterns),
        ),
      ],
    );
  }
}