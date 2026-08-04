import 'package:flutter/material.dart';

import '../../design/archive_relative_date.dart';
import '../../features/archive_theory/archive_theory_copy.dart';
import '../../features/archive_theory/archive_theory_models.dart';
import '../../features/archive_v1/archive_v1_copy.dart';
import '../../shared/ui/ai_explainability_card.dart';
import '../../theme/voicememory_colors.dart';
import '../../theme/voicememory_typography.dart';
import '../evidence_trail/why_am_i_seeing_this_button.dart';

/// Hero card for the archive's current theory — evidence-backed only.
class ArchiveTheoryHeroCard extends StatelessWidget {
  const ArchiveTheoryHeroCard({
    super.key,
    required this.theory,
    required this.onShowMeWhy,
    this.onOpenEvidenceTrail,
    this.onWhyAmISeeingThis,
  });

  final ArchiveCurrentTheory theory;
  final VoidCallback onShowMeWhy;
  final VoidCallback? onOpenEvidenceTrail;
  final VoidCallback? onWhyAmISeeingThis;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label: ArchiveTheoryCopy.heroTitle,
          button: true,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onShowMeWhy,
              borderRadius: BorderRadius.circular(20),
              child: Ink(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: VoiceMemoryColors.beliefGradient,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: VoiceMemoryColors.primaryIndigo.withValues(
                        alpha: 0.22,
                      ),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ArchiveTheoryCopy.heroTitle,
                      style: VoiceMemoryTypography.sectionLabelStyle(
                        accent: VoiceMemoryColors.onPrimary.withValues(
                          alpha: 0.88,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '"${theory.statement}"',
                      style:
                          VoiceMemoryTypography.bodyStyle(
                            color: VoiceMemoryColors.onPrimary,
                          ).copyWith(
                            fontSize: 17,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                    ),
                    const SizedBox(height: 14),
                    _meta(
                      ArchiveTheoryCopy.confidenceLabel,
                      '${theory.confidencePercent}%',
                    ),
                    _meta(
                      ArchiveTheoryCopy.evidenceLabel,
                      '${theory.evidenceCount} '
                      '${theory.evidenceCount == 1 ? 'recording' : 'recordings'}',
                    ),
                    _meta(
                      ArchiveTheoryCopy.counterEvidenceLabel,
                      '${theory.counterEvidenceCount} '
                      '${theory.counterEvidenceCount == 1 ? 'recording' : 'recordings'}',
                    ),
                    _meta(
                      ArchiveTheoryCopy.updatedLabel,
                      formatArchiveRelativeUpdate(theory.lastUpdated),
                    ),
                    if (!theory.isConfident) ...[
                      const SizedBox(height: 16),
                      _lowConfidencePanel(context),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      ArchiveV1Copy.showMeWhyCta,
                      style:
                          VoiceMemoryTypography.bodyStyle(
                            color: VoiceMemoryColors.onPrimary,
                          ).copyWith(
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                            decorationColor: VoiceMemoryColors.onPrimary,
                          ),
                    ),
                    if (onWhyAmISeeingThis != null) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: WhyAmISeeingThisButton(
                          onPressed: onWhyAmISeeingThis!,
                          compact: true,
                          onDark: true,
                        ),
                      ),
                    ] else if (onOpenEvidenceTrail != null) ...[
                      const SizedBox(height: 6),
                      GestureDetector(
                        onTap: onOpenEvidenceTrail,
                        child: Text(
                          ArchiveV1Copy.evidenceTrailCta,
                          style:
                              VoiceMemoryTypography.secondaryStyle(
                                color: VoiceMemoryColors.onPrimary.withValues(
                                  alpha: 0.85,
                                ),
                              ).copyWith(
                                decoration: TextDecoration.underline,
                                decorationColor: VoiceMemoryColors.onPrimary
                                    .withValues(alpha: 0.85),
                              ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        AiExplainabilityCard(explainability: theory.explainability),
      ],
    );
  }

  Widget _lowConfidencePanel(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VoiceMemoryColors.onPrimary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: VoiceMemoryColors.onPrimary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            ArchiveTheoryCopy.notYetConfident,
            style: VoiceMemoryTypography.bodyStyle(
              color: VoiceMemoryColors.onPrimary,
            ).copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            '${ArchiveTheoryCopy.confidenceLabel}: ${theory.confidencePercent}%',
            style: VoiceMemoryTypography.secondaryStyle(
              color: VoiceMemoryColors.onPrimary.withValues(alpha: 0.92),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            ArchiveTheoryCopy.needsMoreEvidenceBeforeStrong,
            style: VoiceMemoryTypography.secondaryStyle(
              color: VoiceMemoryColors.onPrimary.withValues(alpha: 0.92),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            ArchiveTheoryCopy.missingEvidenceHeading,
            style: VoiceMemoryTypography.sectionLabelStyle(
              accent: VoiceMemoryColors.onPrimary.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            theory.missingEvidenceMessage,
            style: VoiceMemoryTypography.secondaryStyle(
              color: VoiceMemoryColors.onPrimary.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            ArchiveTheoryCopy.strengthenHeading,
            style: VoiceMemoryTypography.sectionLabelStyle(
              accent: VoiceMemoryColors.onPrimary.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 6),
          for (final line in theory.strengthenEvidenceLines)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '· ',
                    style: VoiceMemoryTypography.secondaryStyle(
                      color: VoiceMemoryColors.onPrimary.withValues(alpha: 0.9),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      line,
                      style: VoiceMemoryTypography.secondaryStyle(
                        color: VoiceMemoryColors.onPrimary.withValues(
                          alpha: 0.9,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _meta(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        '$label: $value',
        style: VoiceMemoryTypography.secondaryStyle(
          color: VoiceMemoryColors.onPrimary.withValues(alpha: 0.9),
        ),
      ),
    );
  }
}
