import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../archive_intelligence_presentation.dart';
import 'archive_intelligence_section_shell.dart';

class WhatChangedSection extends StatelessWidget {
  const WhatChangedSection({super.key, required this.section});

  final ArchiveIntelligenceSection section;

  @override
  Widget build(BuildContext context) {
    return ArchiveIntelligenceSectionShell(
      key: const Key('archive_intelligence_what_changed'),
      title: section.title,
      semanticIndex: 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (section.headline case final headline?) ...[
            Text(headline, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
          ],
          Text(
            section.body,
            key: Key('archive_change_${section.state.name}'),
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: section.state == ArchiveIntelligenceSectionState.pending
                  ? AppColors.textSecondary
                  : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
