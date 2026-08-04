import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../archive_intelligence_presentation.dart';
import 'archive_intelligence_section_shell.dart';

class ArchiveReasoningSection extends StatelessWidget {
  const ArchiveReasoningSection({super.key, required this.section});

  final ArchiveIntelligenceSection section;

  @override
  Widget build(BuildContext context) {
    return ArchiveIntelligenceSectionShell(
      key: const Key('archive_intelligence_reasoning'),
      title: section.title,
      semanticIndex: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (section.headline case final headline?) ...[
            Text(headline, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
          ],
          Text(section.body, style: Theme.of(context).textTheme.bodyLarge),
          if (section.confidenceExplanation case final explanation?) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              explanation,
              key: const Key('archive_confidence_explanation'),
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}
