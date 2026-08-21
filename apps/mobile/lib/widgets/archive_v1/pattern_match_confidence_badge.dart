import 'package:archiveme_mobile/features/pattern_match_quality/pattern_match_quality_model.dart';
import 'package:archiveme_mobile/theme/voicememory_colors.dart';
import 'package:flutter/material.dart';

/// Top-right confidence band badge for evidence-first insight cards.
class PatternMatchConfidenceBadge extends StatelessWidget {
  const PatternMatchConfidenceBadge({
    required this.band, super.key,
    this.compact = false,
  });

  final PatternMatchConfidenceBand band;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final palette = _paletteFor(band);

    return Container(
      key: Key('pattern_match_confidence_badge_${band.name}'),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: palette.background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: palette.border),
      ),
      child: Text(
        palette.label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: palette.foreground,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          fontSize: compact ? 11 : null,
        ),
      ),
    );
  }
}

class _ConfidencePalette {
  const _ConfidencePalette({
    required this.label,
    required this.background,
    required this.border,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color border;
  final Color foreground;
}

_ConfidencePalette _paletteFor(PatternMatchConfidenceBand band) {
  return switch (band) {
    PatternMatchConfidenceBand.weak => const _ConfidencePalette(
      label: 'Weak',
      background: VoiceMemoryColors.surfaceSecondary,
      border: VoiceMemoryColors.border,
      foreground: VoiceMemoryColors.textSecondary,
    ),
    PatternMatchConfidenceBand.emerging => _ConfidencePalette(
      label: 'Emerging',
      background: VoiceMemoryColors.discoveryGoldBackground,
      border: VoiceMemoryColors.blindSpotAmber.withValues(alpha: 0.45),
      foreground: VoiceMemoryColors.blindSpotAmber,
    ),
    PatternMatchConfidenceBand.solid => _ConfidencePalette(
      label: 'Solid',
      background: VoiceMemoryColors.beliefIndigo.withValues(alpha: 0.1),
      border: VoiceMemoryColors.beliefIndigo.withValues(alpha: 0.35),
      foreground: VoiceMemoryColors.beliefIndigo,
    ),
    PatternMatchConfidenceBand.strong => _ConfidencePalette(
      label: 'Strong',
      background: VoiceMemoryColors.success.withValues(alpha: 0.12),
      border: VoiceMemoryColors.success.withValues(alpha: 0.4),
      foreground: VoiceMemoryColors.success,
    ),
  };
}