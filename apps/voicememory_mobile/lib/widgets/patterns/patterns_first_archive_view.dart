import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../design/archive_mobile_typography.dart';
import '../../design/archive_responsive_layout.dart';
import '../../features/archive_proof/archive_demo_preview_resolver.dart';
import '../../features/archive_proof/archive_proof_record_routes.dart';
import '../../models/journal_entry.dart';
import '../../product/consumer_ui_copy.dart';
import 'archive_demo_preview_card.dart';

/// Patterns tab — exactly one saved entry. Confirms the archive started and
/// nudges a second entry without zero-entry upload copy.
class PatternsFirstArchiveView extends StatelessWidget {
  const PatternsFirstArchiveView({
    super.key,
    this.fillViewport = false,
    this.savedEntryId,
    this.entries = const [],
  });

  final bool fillViewport;

  /// When set, shows a secondary action to open the saved entry detail.
  final String? savedEntryId;

  final List<JournalEntry> entries;

  @override
  Widget build(BuildContext context) {
    final gap = ArchiveResponsiveLayout.gap(context);
    final entryId = savedEntryId?.trim();
    final demo = const ArchiveDemoPreviewResolver().resolve(entries);

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          ConsumerUiCopy.patternsFirstEntrySavedTitle,
          style: ArchiveMobileTypography.responsivePageTitle(context),
        ),
        SizedBox(height: gap),
        Text(
          ConsumerUiCopy.patternsFirstEntrySavedBody,
          style: ArchiveMobileTypography.explanationBody(context),
        ),
        if (demo.shouldShow) ...[
          SizedBox(height: gap),
          ArchiveDemoPreviewCard(
            preview: demo,
            onRecordNext: () => context.go(
              ArchiveProofRecordRoutes.uri(
                guidedPromptNodeKey:
                    ArchiveProofRecordRoutes.changeTimelineNodeKey,
              ),
            ),
          ),
        ],
        SizedBox(height: gap),
        Text(
          ConsumerUiCopy.patternsFirstEntrySavedHelper,
          style: ArchiveMobileTypography.responsiveHelper(context),
        ),
        SizedBox(height: gap + 4),
        FilledButton(
          key: const Key('patterns_first_archive_record_another'),
          onPressed: () => context.go('/record'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: Text(
            ConsumerUiCopy.patternsFirstEntrySavedCta,
            style: ArchiveMobileTypography.responsiveCta(context),
          ),
        ),
        if (entryId != null && entryId.isNotEmpty) ...[
          const SizedBox(height: 8),
          TextButton(
            key: const Key('patterns_first_archive_view_saved_entry'),
            onPressed: () => context.push('/entry/$entryId'),
            child: Text(ConsumerUiCopy.patternsFirstEntryViewSavedCta),
          ),
        ],
      ],
    );

    final padded = ArchiveResponsiveLayout.page(
      context: context,
      maxWidth: ArchiveResponsiveLayout.cardMaxWidth,
      child: content,
    );

    return SingleChildScrollView(
      physics: fillViewport
          ? const AlwaysScrollableScrollPhysics()
          : const ClampingScrollPhysics(),
      child: padded,
    );
  }
}
