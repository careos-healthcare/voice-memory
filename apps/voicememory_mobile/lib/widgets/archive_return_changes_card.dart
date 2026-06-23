import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../design/archive_mobile_typography.dart';
import '../features/return_changes/archive_return_changes_copy.dart';
import '../features/return_changes/archive_return_changes_engine.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../theme/voicememory_cards.dart';

/// Compact card summarizing archive changes since last visit — no notifications.
class ArchiveReturnChangesCard extends StatelessWidget {
  const ArchiveReturnChangesCard({
    super.key,
    required this.result,
    required this.onMarkSeen,
  });

  final ArchiveReturnChangesResult result;
  final VoidCallback onMarkSeen;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('archive_return_changes_card_${result.type.name}'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: VoiceMemoryCards.standard(background: AppColors.surfaceAlt),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            result.title,
            key: Key('archive_return_changes_title_${result.type.name}'),
            style: ArchiveMobileTypography.listTitle(context),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            result.body,
            key: Key('archive_return_changes_body_${result.type.name}'),
            style: ArchiveMobileTypography.listSubtitle(context),
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            children: [
              FilledButton(
                key: const Key('archive_return_changes_review_button'),
                onPressed: () => context.push(result.reviewRoute),
                child: const Text(ArchiveReturnChangesCopy.reviewChangesButton),
              ),
              OutlinedButton(
                key: const Key('archive_return_changes_evidence_map_button'),
                onPressed: () => context.go('/archive-belief'),
                child: const Text(ArchiveReturnChangesCopy.viewEvidenceMapButton),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const Key('archive_return_changes_mark_seen_button'),
              onPressed: onMarkSeen,
              child: const Text(ArchiveReturnChangesCopy.markSeenButton),
            ),
          ),
          if (result.showProLine) ...[
            TextButton(
              key: const Key('archive_return_changes_pro_preview_link'),
              onPressed: () => context.push('/pro-preview'),
              child: const Text(ArchiveReturnChangesCopy.proPreviewLink),
            ),
          ],
        ],
      ),
    );
  }
}
