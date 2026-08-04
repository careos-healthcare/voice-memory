import 'package:flutter/material.dart';

import '../../design/archive_mobile_typography.dart';
import '../../theme/app_colors.dart';

/// Gentle copy when governance blocks memory — shown sparingly.
abstract class MemoryGovernanceCopy {
  MemoryGovernanceCopy._();

  static const String noArchiveContextUsed = 'No archive context used';
  static const String keptSeparateHelper =
      'ArchiveMe kept this separate because it did not match the current entry.';
  static const String backgroundOnlyLabel = 'Related, but not used as a claim';

  static const List<String> all = [
    noArchiveContextUsed,
    keptSeparateHelper,
    backgroundOnlyLabel,
  ];
}

/// Optional gentle notice when governance blocked memory use.
class MemoryGovernanceNotice extends StatelessWidget {
  const MemoryGovernanceNotice({
    super.key,
    this.showHelper = false,
    this.backgroundOnly = false,
  });

  final bool showHelper;
  final bool backgroundOnly;

  @override
  Widget build(BuildContext context) {
    if (backgroundOnly) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          MemoryGovernanceCopy.backgroundOnlyLabel,
          key: const Key('memory_governance_background_label'),
          style: ArchiveMobileTypography.responsiveHelper(context).copyWith(
            color: AppColors.textSecondary,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            MemoryGovernanceCopy.noArchiveContextUsed,
            key: const Key('memory_governance_notice'),
            style: ArchiveMobileTypography.responsiveHelper(context).copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (showHelper) ...[
            const SizedBox(height: 2),
            Text(
              MemoryGovernanceCopy.keptSeparateHelper,
              style: ArchiveMobileTypography.responsiveHelper(
                context,
              ).copyWith(color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}
