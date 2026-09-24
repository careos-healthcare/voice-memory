import 'package:archiveme_mobile/features/onboarding/first_session_evidence.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:archiveme_mobile/widgets/archive/view_evidence_inline_link.dart';
import 'package:flutter/material.dart';

/// First pattern after an import, with a reachable citation for each note.
class ImportedPatternCard extends StatelessWidget {
  const ImportedPatternCard({
    required this.model,
    super.key,
    this.onViewEvidence,
  });

  final ImportedPatternCardModel model;
  final VoidCallback? onViewEvidence;

  @override
  Widget build(BuildContext context) {
    return Card(
      key: const Key('imported_pattern_card'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              model.title,
              key: const Key('imported_pattern_title'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            for (final citation in model.citations) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                citation.quote,
                key: Key('imported_citation_${citation.entryId}'),
              ),
              Text(
                formatEvidenceTimestamp(citation.recordedAt),
                key: Key('imported_citation_time_${citation.entryId}'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            ViewEvidenceInlineLink(
              entryIds: model.entryIds,
              surface: 'onboarding_import_pattern',
              claimContext: model.title,
              onViewEvidence: onViewEvidence,
            ),
          ],
        ),
      ),
    );
  }
}
