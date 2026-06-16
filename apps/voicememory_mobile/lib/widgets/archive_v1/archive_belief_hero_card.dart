import 'package:flutter/material.dart';

import '../../design/archive_relative_date.dart';
import '../../features/archive_v1/archive_v1_copy.dart';
import '../../features/archive_v1/archive_v1_models.dart';
import '../../theme/voicememory_colors.dart';
import '../../theme/voicememory_typography.dart';

/// Hero belief card — evidence-backed only.
class ArchiveBeliefHeroCard extends StatelessWidget {
  const ArchiveBeliefHeroCard({
    super.key,
    required this.belief,
    required this.onShowMeWhy,
    this.onOpenEvidenceTrail,
  });

  final ArchiveV1Belief belief;
  final VoidCallback onShowMeWhy;
  final VoidCallback? onOpenEvidenceTrail;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: ArchiveV1Copy.beliefHeroTitle,
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
                  ArchiveV1Copy.beliefHeroTitle,
                  style: VoiceMemoryTypography.sectionLabelStyle(
                    accent: VoiceMemoryColors.onPrimary.withValues(alpha: 0.88),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '"${belief.statement}"',
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
                _meta('Confidence', '${belief.confidencePercent}%'),
                _meta(
                  'Evidence',
                  '${belief.evidenceCount} '
                      '${belief.evidenceCount == 1 ? 'recording' : 'recordings'}',
                ),
                _meta(
                  'Updated',
                  formatArchiveRelativeUpdate(belief.lastUpdated),
                ),
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
                if (onOpenEvidenceTrail != null) ...[
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
