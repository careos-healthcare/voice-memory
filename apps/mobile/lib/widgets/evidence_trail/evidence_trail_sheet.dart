import 'package:archiveme_mobile/features/evidence_trail/evidence_trail_models.dart';
import 'package:archiveme_mobile/theme/voicememory_colors.dart';
import 'package:archiveme_mobile/theme/voicememory_typography.dart';
import 'package:archiveme_mobile/widgets/evidence_trail/evidence_source_card.dart';
import 'package:flutter/material.dart';

/// Mobile-first bottom sheet — recording excerpts, dates, confidence factors.
class EvidenceTrailSheet extends StatelessWidget {
  const EvidenceTrailSheet({
    required this.payload, required this.surface, super.key,
    this.onOpenFullExplanation,
  });

  final EvidenceTrailPayload payload;
  final String surface;
  final VoidCallback? onOpenFullExplanation;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Material(
          color: VoiceMemoryColors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: VoiceMemoryColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Evidence',
                        style: VoiceMemoryTypography.pageTitleStyle().copyWith(
                          fontSize: 18,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      tooltip: 'Close',
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.fromLTRB(20, 0, 20, 24 + bottomInset),
                  children: [
                    Text(
                      payload.title,
                      style: VoiceMemoryTypography.cardTitleStyle(),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      payload.whySummary,
                      style: VoiceMemoryTypography.bodyStyle(
                        color: VoiceMemoryColors.textSecondary,
                      ).copyWith(height: 1.45),
                    ),
                    const SizedBox(height: 16),
                    _metricsRow(),
                    if (payload.confidenceFactors.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        'CONFIDENCE FACTORS',
                        style: VoiceMemoryTypography.sectionLabelStyle(
                          
                        ),
                      ),
                      const SizedBox(height: 8),
                      for (final f in payload.confidenceFactors)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 2,
                                child: Text(
                                  f.label,
                                  style: VoiceMemoryTypography.secondaryStyle(
                                    color: VoiceMemoryColors.textSecondary,
                                  ),
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  f.value,
                                  style: VoiceMemoryTypography.bodyStyle()
                                      .copyWith(fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                    const SizedBox(height: 16),
                    Text(
                      'RECORDING EXCERPTS',
                      style: VoiceMemoryTypography.sectionLabelStyle(
                        
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (!payload.hasSources)
                      Text(
                        'Not enough linked recordings yet. Add another reflection '
                        'with a bit more detail.',
                        style: VoiceMemoryTypography.bodyStyle(
                          color: VoiceMemoryColors.textSecondary,
                        ),
                      )
                    else
                      for (final source in payload.sources)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: EvidenceSourceCard(
                            source: source,
                            analyticsSurface: surface,
                          ),
                        ),
                    if (onOpenFullExplanation != null) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: onOpenFullExplanation,
                        child: const Text('See full explanation'),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _metricsRow() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VoiceMemoryColors.surfaceSecondary,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: VoiceMemoryColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _metric('Evidence count', '${payload.evidenceCount}'),
          ),
          if (payload.confidencePercent != null)
            Expanded(
              child: _metric('Confidence', '${payload.confidencePercent}%'),
            ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: VoiceMemoryTypography.secondaryStyle(
            color: VoiceMemoryColors.textSecondary,
          ).copyWith(fontSize: 11),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: VoiceMemoryTypography.cardTitleStyle().copyWith(fontSize: 16),
        ),
      ],
    );
  }
}