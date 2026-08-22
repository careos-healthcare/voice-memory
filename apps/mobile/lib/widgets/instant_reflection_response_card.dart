import 'package:archiveme_mobile/features/instant_reflection/instant_reflection_response.dart';
import 'package:archiveme_mobile/theme/voicememory_colors.dart';
import 'package:archiveme_mobile/theme/voicememory_typography.dart';
import 'package:flutter/material.dart';

/// Immediate post-save archive voice — before deeper discovery analysis.
class InstantReflectionResponseCard extends StatelessWidget {
  const InstantReflectionResponseCard({required this.response, super.key});

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