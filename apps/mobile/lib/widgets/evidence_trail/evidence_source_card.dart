import 'package:archiveme_mobile/design/user_facing_date.dart';
import 'package:archiveme_mobile/features/evidence_trail/evidence_trail_models.dart';
import 'package:archiveme_mobile/features/retention/retention_analytics.dart';
import 'package:archiveme_mobile/theme/voicememory_colors.dart';
import 'package:archiveme_mobile/theme/voicememory_typography.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';

/// One recording excerpt in the evidence trail sheet.
class EvidenceSourceCard extends StatelessWidget {
  const EvidenceSourceCard({
    required this.source, required this.analyticsSurface, super.key,
  });

  final EvidenceTrailSource source;
  final String analyticsSurface;

  String get _roleLabel => switch (source.role) {
    EvidenceSourceRole.supporting => 'Supporting',
    EvidenceSourceRole.contradicting => 'Counter-evidence',
    EvidenceSourceRole.related => 'Related',
  };

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label:
          'Recording from ${formatUserFacingDate(source.recordedAt)}. $_roleLabel. ${source.excerpt}',
      child: Material(
        color: VoiceMemoryColors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: () {
            RetentionAnalytics.evidenceRecordOpened(surface: analyticsSurface);
            unawaited(context.push('/entry/${source.entryId}'));
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: VoiceMemoryColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        formatUserFacingDate(source.recordedAt),
                        style: VoiceMemoryTypography.secondaryStyle(
                          color: VoiceMemoryColors.textSecondary,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      _roleLabel,
                      style: VoiceMemoryTypography.secondaryStyle(
                        color: VoiceMemoryColors.primaryIndigo,
                      ).copyWith(fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  source.excerpt,
                  style: VoiceMemoryTypography.bodyStyle().copyWith(
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Open recording',
                  style: VoiceMemoryTypography.bodyStyle(
                    color: VoiceMemoryColors.primaryIndigo,
                  ).copyWith(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}