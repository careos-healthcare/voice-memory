import 'package:archiveme_mobile/design/archive_relative_date.dart';
import 'package:archiveme_mobile/features/archive_theory/archive_theory_copy.dart';
import 'package:archiveme_mobile/features/archive_theory/archive_theory_models.dart';
import 'package:archiveme_mobile/features/archive_v1/archive_v1_copy.dart';
import 'package:archiveme_mobile/theme/voicememory_colors.dart';
import 'package:archiveme_mobile/theme/voicememory_typography.dart';
import 'package:archiveme_mobile/widgets/archive_v1/archive_display_titles.dart';
import 'package:archiveme_mobile/widgets/evidence_trail/why_am_i_seeing_this_button.dart';
import 'package:flutter/material.dart';

/// Short life-pattern card. Scores and counts stay in Technical Reasoning.
class ArchiveTheoryHeroCard extends StatelessWidget {
  const ArchiveTheoryHeroCard({
    required this.theory,
    required this.onShowMeWhy,
    super.key,
    this.onOpenEvidenceTrail,
    this.onWhyAmISeeingThis,
    this.technicalActions = const [],
  });

  final ArchiveCurrentTheory theory;
  final VoidCallback onShowMeWhy;
  final VoidCallback? onOpenEvidenceTrail;
  final VoidCallback? onWhyAmISeeingThis;

  /// Math, scores, and share tools. Hidden until Technical Reasoning opens.
  final List<Widget> technicalActions;

  @override
  Widget build(BuildContext context) {
    final bullets = _bullets(theory);
    const onPrimary = VoiceMemoryColors.onPrimary;
    return Semantics(
      label: ArchiveDomainKey.theories.displayTitle,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: Ink(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: VoiceMemoryColors.beliefGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: VoiceMemoryColors.primaryIndigo.withValues(alpha: 0.22),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: onShowMeWhy,
                borderRadius: BorderRadius.circular(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            ArchiveTheoryCopy.heroTitle,
                            style: VoiceMemoryTypography.sectionLabelStyle(
                              accent: onPrimary.withValues(alpha: 0.88),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StrengthBadge(theory: theory),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      theory.statement,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style:
                          VoiceMemoryTypography.bodyStyle(
                            color: onPrimary,
                          ).copyWith(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            height: 1.35,
                          ),
                    ),
                    const SizedBox(height: 12),
                    for (final line in bullets) _bullet(line),
                    const SizedBox(height: 8),
                    Text(
                      ArchiveV1Copy.showMeWhyCta,
                      style:
                          VoiceMemoryTypography.bodyStyle(
                            color: onPrimary,
                          ).copyWith(
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                            decorationColor: onPrimary,
                          ),
                    ),
                  ],
                ),
              ),
              Theme(
                data: Theme.of(context).copyWith(
                  dividerColor: Colors.transparent,
                ),
                child: ExpansionTile(
                  key: const Key('technical_reasoning_drawer'),
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: const EdgeInsets.only(bottom: 8),
                  iconColor: onPrimary,
                  collapsedIconColor: onPrimary,
                  title: Text(
                    'Technical Reasoning',
                    style: VoiceMemoryTypography.secondaryStyle(
                      color: onPrimary.withValues(alpha: 0.9),
                    ),
                  ),
                  children: [
                    _meta(
                      ArchiveTheoryCopy.confidenceLabel,
                      '${theory.confidencePercent}%',
                    ),
                    _meta(
                      ArchiveTheoryCopy.evidenceLabel,
                      '${theory.evidenceCount}',
                    ),
                    _meta(
                      ArchiveTheoryCopy.counterEvidenceLabel,
                      '${theory.counterEvidenceCount}',
                    ),
                    _meta(
                      ArchiveTheoryCopy.updatedLabel,
                      formatArchiveRelativeUpdate(theory.lastUpdated),
                    ),
                    if (!theory.isConfident) _lowConfidencePanel(),
                    for (final action in technicalActions) ...[
                      const SizedBox(height: 8),
                      action,
                    ],
                  ],
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
                          color: onPrimary.withValues(alpha: 0.85),
                        ).copyWith(
                          decoration: TextDecoration.underline,
                          decorationColor: onPrimary.withValues(alpha: 0.85),
                        ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _bullet(String line) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
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
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: VoiceMemoryTypography.secondaryStyle(
                color: VoiceMemoryColors.onPrimary.withValues(alpha: 0.92),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _lowConfidencePanel() {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            theory.missingEvidenceMessage,
            style: VoiceMemoryTypography.secondaryStyle(
              color: VoiceMemoryColors.onPrimary.withValues(alpha: 0.9),
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

class _StrengthBadge extends StatelessWidget {
  const _StrengthBadge({required this.theory});

  final ArchiveCurrentTheory theory;

  @override
  Widget build(BuildContext context) {
    final label = theory.isConfident ? 'Steady' : 'Forming';
    return Container(
      key: const Key('theory_strength_badge'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: VoiceMemoryColors.onPrimary.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: VoiceMemoryTypography.sectionLabelStyle(
          accent: VoiceMemoryColors.onPrimary,
        ),
      ),
    );
  }
}

List<String> _bullets(ArchiveCurrentTheory theory) {
  final lines = theory.strengthenEvidenceLines
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .take(2)
      .toList();
  if (lines.length >= 2) return lines;
  final fallback = <String>[
    if (lines.isNotEmpty) lines.first,
    '${theory.evidenceCount} supporting ${theory.evidenceCount == 1 ? 'moment' : 'moments'}',
    if (theory.counterEvidenceCount > 0)
      '${theory.counterEvidenceCount} that may not fit',
  ];
  return fallback.take(2).toList();
}
