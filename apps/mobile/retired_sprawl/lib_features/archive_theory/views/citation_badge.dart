import 'package:archiveme_mobile/features/archive_theory/theory_tracker_models.dart';
import 'package:archiveme_mobile/theme/app_colors.dart';
import 'package:flutter/material.dart';

typedef CitationPlaybackCallback = void Function(TheoryEvidenceQuote quote);

/// Inline badge linking theory evidence to an exact audio timestamp.
class CitationBadge extends StatelessWidget {
  const CitationBadge({
    required this.quote,
    required this.onTap,
    super.key,
    this.compact = false,
  });

  final TheoryEvidenceQuote quote;
  final CitationPlaybackCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (!quote.hasCitationPlayback) return const SizedBox.shrink();

    final label = _formatTimestamp(quote.startTimestampMs!);

    return Semantics(
      button: true,
      label: 'Play source audio at $label',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onTap(quote),
          borderRadius: BorderRadius.circular(999),
          child: Ink(
            key: Key('citation_badge_${quote.chunkId ?? quote.entryId}'),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 8 : 10,
              vertical: compact ? 3 : 4,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: AppColors.warmBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.play_arrow_rounded,
                  size: compact ? 14 : 16,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 2),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(int milliseconds) {
    final totalSeconds = (milliseconds / 1000).floor();
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }
}
