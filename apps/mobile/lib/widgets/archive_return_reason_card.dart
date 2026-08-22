import 'package:archiveme_mobile/features/return_reason/return_reason_models.dart';
import 'package:archiveme_mobile/services/product_analytics.dart';
import 'package:archiveme_mobile/theme/voicememory_colors.dart';
import 'package:archiveme_mobile/theme/voicememory_typography.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';

/// Top-of-Archive hook after leaving Discover — unfinished archive curiosity.
class ArchiveReturnReasonCard extends StatelessWidget {
  const ArchiveReturnReasonCard({
    required this.card, super.key,
    this.onDismiss,
  });

  final ReturnReasonCard card;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final c = card;
    return Semantics(
      label: c.leadLine,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: VoiceMemoryColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: VoiceMemoryColors.primaryIndigo.withValues(alpha: 0.25),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.auto_stories_outlined,
                  color: VoiceMemoryColors.primaryIndigo,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.leadLine,
                        style: VoiceMemoryTypography.sectionLabelStyle(
                          
                        ),
                      ),
                      const SizedBox(height: 10),
                      for (final line in c.bodyLines)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            line,
                            style: VoiceMemoryTypography.bodyStyle().copyWith(
                              height: 1.45,
                              fontWeight: line.startsWith('•')
                                  ? FontWeight.w500
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                      if (c.beliefQuote != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          '“${c.beliefQuote}”',
                          style: VoiceMemoryTypography.cardTitleStyle(),
                        ),
                      ],
                      if (c.kind == ReturnReasonKind.conflictingEvidence) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Continue recording.',
                          style: VoiceMemoryTypography.bodyStyle().copyWith(
                            height: 1.45,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (onDismiss != null)
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    tooltip: 'Dismiss',
                    onPressed: onDismiss,
                    visualDensity: VisualDensity.compact,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () {
                unawaited(ProductAnalytics.track('return_reason_record_tapped'));
                context.go('/record');
              },
              style: FilledButton.styleFrom(
                backgroundColor: VoiceMemoryColors.primaryIndigo,
                minimumSize: const Size(double.infinity, 44),
              ),
              child: const Text('Record'),
            ),
          ],
        ),
      ),
    );
  }
}