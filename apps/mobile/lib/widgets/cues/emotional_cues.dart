import 'package:archiveme_mobile/features/evidence_weighting/evidence_weighting_model.dart';
import 'package:archiveme_mobile/theme/app_spacing.dart';
import 'package:flutter/material.dart';

/// Borderless type for a hesitation cue. The label sits back; the line is stark.
class HesitationSignalCue extends StatelessWidget {
  const HesitationSignalCue({
    required this.label,
    required this.line,
    super.key,
    this.note,
    this.labelKey,
    this.lineKey,
    this.noteKey,
  });

  final String label;
  final String line;
  final String? note;
  final Key? labelKey;
  final Key? lineKey;
  final Key? noteKey;

  @override
  Widget build(BuildContext context) {
    final ink = Theme.of(context).colorScheme.onSurface;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            key: labelKey,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.6,
              height: 1.3,
              color: ink.withValues(alpha: 0.42),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            line,
            key: lineKey,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.3,
              height: 1.25,
              color: ink,
            ),
          ),
          if (note != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              note!,
              key: noteKey,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                height: 1.45,
                color: ink.withValues(alpha: 0.62),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Borderless type for an emotional-weight cue. Stronger states read darker.
class EmotionalWeightCue extends StatelessWidget {
  const EmotionalWeightCue({
    required this.label,
    required this.line,
    required this.state,
    super.key,
    this.labelKey,
    this.lineKey,
  });

  final String label;
  final String line;
  final EvidenceWeightState state;
  final Key? labelKey;
  final Key? lineKey;

  static double opacityFor(EvidenceWeightState state) => switch (state) {
    EvidenceWeightState.fresh => 1,
    EvidenceWeightState.repeated => 0.92,
    EvidenceWeightState.needsFreshProof => 0.78,
    EvidenceWeightState.fading => 0.58,
    EvidenceWeightState.softened => 0.5,
    EvidenceWeightState.oldSignal => 0.4,
  };

  @override
  Widget build(BuildContext context) {
    final ink = Theme.of(context).colorScheme.onSurface;
    final emphasis = opacityFor(state);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            key: labelKey,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.3,
              height: 1.25,
              color: ink.withValues(alpha: emphasis),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            line,
            key: lineKey,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              height: 1.45,
              color: ink.withValues(alpha: emphasis * 0.72),
            ),
          ),
        ],
      ),
    );
  }
}
