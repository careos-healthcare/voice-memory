import 'dart:async';

import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/archive_proof/visible_archive_proof_copy.dart';
import 'package:archiveme_mobile/features/evidence_trail/evidence_trail_navigation.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Compact "· View evidence" link — does not restyle the adjacent label.
///
/// Tap target matches [VerifiedSourceProofLink]: small visible text, 48pt
/// minimum hit area, and a screen-reader label that includes the claim.
class ViewEvidenceInlineLink extends StatelessWidget {
  const ViewEvidenceInlineLink({
    required this.entryIds,
    required this.surface,
    super.key,
    this.claimContext,
    this.onViewEvidence,
  });

  final List<String> entryIds;
  final String surface;

  /// Adjacent claim so VoiceOver/TalkBack can tell this link apart from
  /// another "View evidence" on the same screen.
  final String? claimContext;
  final VoidCallback? onViewEvidence;

  /// Matches the platform minimum so the link is reachable with a thumb even
  /// though its text is small.
  static const double minTapTarget = 48;

  bool get _canView => onViewEvidence != null || entryIds.isNotEmpty;

  String get _semanticsLabel {
    final cta = VisibleArchiveProofCopy.beliefUpdateViewEvidenceCta;
    final claim = claimContext?.trim();
    if (claim == null || claim.isEmpty) return cta;
    return '$cta. $claim';
  }

  @override
  Widget build(BuildContext context) {
    if (!_canView) return const SizedBox.shrink();

    return Semantics(
      button: true,
      label: _semanticsLabel,
      excludeSemantics: true,
      child: InkWell(
        onTap: () => unawaited(
          openEvidenceTrailForSourceEntryIds(
            context,
            sourceEntryIds: entryIds,
            surface: surface,
            onViewEvidence: onViewEvidence,
          ),
        ),
        borderRadius: BorderRadius.circular(999),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: ViewEvidenceInlineLink.minTapTarget,
          ),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: AppSpacing.xs,
              ),
              child: Text(
                '· ${VisibleArchiveProofCopy.beliefUpdateViewEvidenceCta}',
                style: ArchiveMobileTypography.responsiveHelper(context)
                    .copyWith(
                      color: AppColors.accentPrimary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
