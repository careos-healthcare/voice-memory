import 'package:archiveme_mobile/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// Compact belief case file — full dossier on web archive-belief.
class BeliefDossierCompact extends StatelessWidget {
  const BeliefDossierCompact({
    super.key,
    this.beliefText,
    this.confidencePercent,
  });

  final String? beliefText;
  final int? confidencePercent;

  @override
  Widget build(BuildContext context) {
    if (beliefText == null || beliefText!.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      color: AppTheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Belief dossier',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.muted,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'This is the current case your archive can support.',
              style: TextStyle(
                color: AppTheme.muted,
                height: 1.45,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              beliefText!,
              style: const TextStyle(fontWeight: FontWeight.w500, height: 1.45),
            ),
            if (confidencePercent != null) ...[
              const SizedBox(height: 8),
              Text(
                'Confidence: $confidencePercent%',
                style: const TextStyle(color: AppTheme.muted, fontSize: 12),
              ),
            ],
            const SizedBox(height: 10),
            const Text(
              'What would change this belief?',
              style: TextStyle(fontSize: 12, color: AppTheme.muted),
            ),
            const SizedBox(height: 4),
            const Text(
              '— Contradicting evidence would reduce confidence.\n'
              '— More reflections in another area would change how far the archive generalizes.',
              style: TextStyle(
                color: AppTheme.muted,
                height: 1.45,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}