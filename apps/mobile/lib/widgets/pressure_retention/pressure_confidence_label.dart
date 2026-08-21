import 'package:archiveme_mobile/design/archive_mobile_typography.dart';
import 'package:archiveme_mobile/features/pressure_retention/pressure_evidence_confidence.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Small, honest confidence chip shown on pressure insights.
class PressureConfidenceLabel extends StatelessWidget {
  const PressureConfidenceLabel({required this.confidence, super.key});

  final PressureEvidenceConfidence confidence;

  @override
  Widget build(BuildContext context) {
    final color = _color(confidence);
    return Container(
      key: const Key('pressure_confidence_label'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.insights_outlined, size: 14, color: color),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              confidence.label,
              style: ArchiveMobileTypography.responsiveHelper(
                context,
              ).copyWith(color: color, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Color _color(PressureEvidenceConfidence confidence) {
    switch (confidence) {
      case PressureEvidenceConfidence.needsMoreEvidence:
        return AppColors.textSecondary;
      case PressureEvidenceConfidence.earlySignal:
        return AppColors.accentSecondary;
      case PressureEvidenceConfidence.repeatingPattern:
        return AppColors.accentPrimary;
      case PressureEvidenceConfidence.strongPattern:
        return AppColors.warning;
    }
  }
}