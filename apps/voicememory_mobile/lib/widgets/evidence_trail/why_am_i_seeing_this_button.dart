import 'package:flutter/material.dart';

import '../../features/archive_explanations/explanation_models.dart';
import '../../features/archive_state_object/archive_state_object.dart';
import '../../features/evidence_trail/evidence_trail_navigation.dart';
import '../../models/journal_entry.dart';
import '../../theme/voicememory_colors.dart';
import '../../theme/voicememory_typography.dart';

/// Opens Evidence Trail V1 for an insight ref or custom trail opener.
class WhyAmISeeingThisButton extends StatelessWidget {
  const WhyAmISeeingThisButton({
    super.key,
    required this.onPressed,
    this.compact = false,
    this.onDark = false,
  });

  final VoidCallback onPressed;
  final bool compact;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        minimumSize: Size(compact ? 44 : 48, compact ? 36 : 44),
        padding: compact
            ? const EdgeInsets.symmetric(horizontal: 8)
            : const EdgeInsets.symmetric(horizontal: 12),
        foregroundColor: onDark
            ? VoiceMemoryColors.onPrimary
            : VoiceMemoryColors.primaryIndigo,
      ),
      child: Text(
        kWhyAmISeeingThisLabel,
        style: VoiceMemoryTypography.bodyStyle(
          color: onDark
              ? VoiceMemoryColors.onPrimary
              : VoiceMemoryColors.primaryIndigo,
        ).copyWith(
          fontWeight: FontWeight.w600,
          fontSize: compact ? 12 : 14,
        ),
        textAlign: TextAlign.start,
      ),
    );
  }
}

/// Standard insight ref → evidence sheet.
class WhyAmISeeingThisForInsight extends StatelessWidget {
  const WhyAmISeeingThisForInsight({
    super.key,
    required this.ref,
    this.entries,
    this.state,
    this.surface = 'insight',
    this.askPrompt,
    this.askCitedEntryIds,
    this.compact = false,
  });

  final ArchiveInsightRef ref;
  final List<JournalEntry>? entries;
  final ArchiveStateObjectV3? state;
  final String surface;
  final String? askPrompt;
  final List<String>? askCitedEntryIds;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return WhyAmISeeingThisButton(
      compact: compact,
      onPressed: () => openEvidenceTrailForInsight(
        context,
        ref: ref,
        entries: entries,
        state: state,
        surface: surface,
        askPrompt: askPrompt,
        askCitedEntryIds: askCitedEntryIds,
      ),
    );
  }
}
