import 'package:flutter/material.dart';

import '../features/instant_reflection/instant_reflection_response.dart';
import '../theme/voicememory_colors.dart';
import '../theme/voicememory_typography.dart';

/// Immediate post-save archive voice — before deeper discovery analysis.
class InstantReflectionResponseCard extends StatelessWidget {
  const InstantReflectionResponseCard({
    super.key,
    required this.response,
  });

  final InstantReflectionResponse response;

  static const String sectionLabel = 'ARCHIVE RESPONSE';
  static const String leadQuote = 'I noticed something.';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          sectionLabel,
          style: VoiceMemoryTypography.sectionLabelStyle(
            accent: VoiceMemoryColors.primaryIndigo,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: VoiceMemoryColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: VoiceMemoryColors.primaryIndigo.withValues(alpha: 0.28),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                leadQuote,
                style: VoiceMemoryTypography.cardTitleStyle().copyWith(
                  fontStyle: FontStyle.italic,
                  color: VoiceMemoryColors.textSecondary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                response.bodyLine,
                style: VoiceMemoryTypography.bodyStyle().copyWith(
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
