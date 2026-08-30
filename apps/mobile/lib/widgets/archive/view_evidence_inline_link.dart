import 'dart:async';

import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:archiveme_mobile/features/evidence_trail/evidence_trail_navigation.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:flutter/material.dart';

/// Compact "· View evidence" link — does not restyle the adjacent label.
class ViewEvidenceInlineLink extends StatelessWidget {
  const ViewEvidenceInlineLink({
    required this.entryIds,
    required this.surface,
    super.key,
    this.onViewEvidence,
  });

  final List<String> entryIds;
  final String surface;
  final VoidCallback? onViewEvidence;

  bool get _canView => onViewEvidence != null || entryIds.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    if (!_canView) return const SizedBox.shrink();

    return TextButton(
      onPressed: () => unawaited(
        openEvidenceTrailForSourceEntryIds(
          context,
          sourceEntryIds: entryIds,
          surface: surface,
          onViewEvidence: onViewEvidence,
        ),
      ),
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        '· ${VisibleArchiveProofCopy.beliefUpdateViewEvidenceCta}',
        style: ArchiveMobileTypography.responsiveHelper(context).copyWith(
          color: AppColors.accentPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
