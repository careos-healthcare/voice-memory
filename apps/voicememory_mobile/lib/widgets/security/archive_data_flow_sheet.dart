import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../security/archive_privacy_controls_copy.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_spacing.dart';
import '../../theme/voicememory_cards.dart';

/// Plain-language explanation of what stays on device vs what may be sent.
Future<void> showArchiveDataFlowSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) {
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            0,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                ArchiveDataFlowCopy.sheetTitle,
                key: const Key('archive_data_flow_title'),
                style: ArchiveMobileTypography.responsiveSectionTitle(
                  sheetContext,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              for (final section in ArchiveDataFlowCopy.bodySections) ...[
                Text(
                  section,
                  key: Key('archive_data_flow_section_${section.hashCode}'),
                  style: ArchiveMobileTypography.body(sheetContext).copyWith(
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              const SizedBox(height: AppSpacing.xs),
              FilledButton(
                key: const Key('archive_data_flow_done'),
                onPressed: () => Navigator.of(sheetContext).pop(),
                child: const Text(ArchiveDataFlowCopy.doneLabel),
              ),
            ],
          ),
        ),
      );
    },
  );
}
