import 'package:flutter/material.dart';

import '../design/archive_confidence_display.dart';
import '../design/warm_archive_copy.dart';
import '../design/user_facing_date.dart';
import '../features/archive_evidence/archive_evidence.dart';
import '../features/archive_state_object/archive_state_object.dart';
import '../models/journal_entry.dart';
import '../theme/voicememory_colors.dart';
import '../features/archive_explanations/explanation_models.dart';
import '../theme/voicememory_typography.dart';
import 'archive_why_button.dart';

/// North-star summary: what the archive currently believes about you.
class ArchiveBeliefSummaryBanner extends StatelessWidget {
  const ArchiveBeliefSummaryBanner({
    super.key,
    required this.entries,
    this.state,
  });

  final List<JournalEntry> entries;
  final ArchiveStateObjectV3? state;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    if (!archiveHasMinimumEvidence(entries)) return const SizedBox.shrink();

    final sorted = [...entries]..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final first = sorted.first.createdAt;
    final last = sorted.last.createdAt;
    final count = state?.evidenceReflectionCount ??
        archiveEvidenceReflectionCount(entries);

    final belief = state?.belief?.trim();
    final hasBelief = belief != null && belief.isNotEmpty;
    final health = state?.health ?? ArchiveHealthV3.uncertain;
    final confidencePct = archiveConfidencePercentLabel(
      health: health,
      evidenceReflectionCount: count,
    );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: VoiceMemoryColors.beliefGradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: VoiceMemoryColors.primaryIndigo.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            WarmArchiveCopy.beliefSectionTitle,
            style: VoiceMemoryTypography.sectionLabelStyle(
              accent: VoiceMemoryColors.onPrimary.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  hasBelief
                      ? '"$belief"'
                      : 'Your archive is still gathering evidence from your recordings.',
                  style: VoiceMemoryTypography.bodyStyle(color: VoiceMemoryColors.onPrimary).copyWith(
                    fontWeight: FontWeight.w500,
                    fontSize: 17,
                  ),
                ),
              ),
              if (hasBelief)
                ArchiveWhyButton(
                  ref: ArchiveInsightRef.belief(),
                  compact: true,
                ),
            ],
          ),
          const SizedBox(height: 14),
          _metaRow(WarmArchiveCopy.confidenceConcept, confidencePct),
          _metaRow(
            'Evidence',
            '$count ${count == 1 ? 'entry' : 'entries'}',
          ),
          _metaRow('First seen', formatUserFacingMonthYear(first)),
          _metaRow('Last reinforced', formatUserFacingDate(last)),
        ],
      ),
    );
  }

  Widget _metaRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(
        '$label: $value',
        style: VoiceMemoryTypography.secondaryStyle(
          color: VoiceMemoryColors.onPrimary.withValues(alpha: 0.88),
        ),
      ),
    );
  }
}
