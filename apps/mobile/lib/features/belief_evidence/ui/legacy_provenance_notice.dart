import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/evidence_citation_card.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/evidence_citation_palette.dart';
import 'package:archiveme_mobile/features/belief_evidence/ui/legacy_provenance_copy.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Shown when a claim's entry exists and holds text, but the build that wrote
/// that text did not record where it came from.
///
/// Distinct from [UngroundedEvidenceNotice] because it reports a different
/// fact. That notice says the archive does not support the claim. This one
/// says the support may well be there and the app declines to present it as
/// the user's words. Rendering the same thing for both would tell a user their
/// entry is unsupported when the recording behind it is intact.
///
/// Styled as a quiet aside rather than a warning: no warning colour, no alert
/// icon, and a body-weight background. This is the resting state of every
/// entry written before provenance existed, so it has to look like a footnote,
/// not like a fault.
class LegacyProvenanceNotice extends StatelessWidget {
  const LegacyProvenanceNotice({super.key, this.recovery});

  /// The recover affordance, or an explanation of why it is not on offer.
  ///
  /// Passed in rather than built here so this widget stays free of consent,
  /// filesystem, and network concerns and can be rendered in any test.
  final Widget? recovery;

  static const Key noticeKey = Key('legacy_provenance_notice');
  static const Key titleKey = Key('legacy_provenance_notice_title');

  @override
  Widget build(BuildContext context) {
    final palette = EvidenceCitationPalette.of(context);
    final titleStyle = ArchiveMobileTypography.cardLabel(
      context,
      color: palette.unverifiedTitle,
    ).copyWith(fontWeight: FontWeight.w700);
    final bodyStyle = ArchiveMobileTypography.responsiveHelper(
      context,
      color: palette.unverifiedBody,
    );

    return Semantics(
      container: true,
      label: LegacyProvenanceCopy.semantics(recovery: ''),
      // The nested recover control keeps its own semantics; only the prose is
      // folded into the container label.
      explicitChildNodes: true,
      child: Container(
        key: LegacyProvenanceNotice.noticeKey,
        width: double.infinity,
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: palette.unverifiedBackground,
          borderRadius: BorderRadius.circular(EvidenceCitationMetrics.radius),
          border: Border.all(color: palette.unverifiedBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.history_edu_outlined,
                size: (titleStyle.fontSize ?? 14) + 4,
                color: palette.unverifiedIcon,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    LegacyProvenanceCopy.title,
                    key: LegacyProvenanceNotice.titleKey,
                    style: titleStyle,
                  ),
                  const SizedBox(height: 2),
                  Text(LegacyProvenanceCopy.body, style: bodyStyle),
                  const SizedBox(height: 4),
                  Text(LegacyProvenanceCopy.helper, style: bodyStyle),
                  if (recovery != null) ...[
                    const SizedBox(height: AppSpacing.xs),
                    recovery!,
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
