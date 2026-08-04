import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../theme/app_spacing.dart';
import '../archive_intelligence_presentation.dart';
import 'archive_intelligence_section_shell.dart';

class SupportingMomentsSection extends StatelessWidget {
  const SupportingMomentsSection({
    super.key,
    required this.section,
    required this.onOpenMoment,
  });

  final ArchiveIntelligenceSection section;
  final ValueChanged<String> onOpenMoment;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);
    return ArchiveIntelligenceSectionShell(
      key: const Key('archive_intelligence_supporting_moments'),
      title: section.title,
      semanticIndex: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            section.body,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: section.moments.isEmpty
                  ? AppColors.textSecondary
                  : AppColors.textPrimary,
            ),
          ),
          for (final moment in section.moments) ...[
            const SizedBox(height: AppSpacing.sm),
            Semantics(
              button: true,
              label:
                  '${localizations.formatMediumDate(moment.occurredAt)}. '
                  '${moment.excerpt}',
              hint: moment.hasAudio
                  ? 'Open the source transcript and available audio'
                  : 'Open the source transcript',
              child: ListTile(
                key: ValueKey('archive_evidence_${moment.id}'),
                contentPadding: EdgeInsets.zero,
                title: Text(
                  moment.excerpt,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  localizations.formatMediumDate(moment.occurredAt),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => onOpenMoment(moment.entryId),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
