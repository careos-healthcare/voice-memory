import 'package:flutter/material.dart';

import '../../../theme/app_spacing.dart';
import '../archive_intelligence_presentation.dart';
import 'archive_intelligence_section_shell.dart';

class ArchiveNextActionSection extends StatelessWidget {
  const ArchiveNextActionSection({
    super.key,
    required this.section,
    required this.onAction,
  });

  final ArchiveIntelligenceSection section;
  final ValueChanged<ArchiveIntelligenceAction> onAction;

  @override
  Widget build(BuildContext context) {
    return ArchiveIntelligenceSectionShell(
      key: const Key('archive_intelligence_next_action'),
      title: section.title,
      semanticIndex: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (section.headline case final headline?) ...[
            Text(headline, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: AppSpacing.xs),
          ],
          Text(section.body, style: Theme.of(context).textTheme.bodyLarge),
          if (section.action != ArchiveIntelligenceAction.none &&
              section.actionLabel != null) ...[
            const SizedBox(height: AppSpacing.md),
            FilledButton.icon(
              key: const Key('archive_intelligence_next_action_button'),
              onPressed: () => onAction(section.action),
              icon: const Icon(Icons.mic_none),
              label: Text(section.actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
